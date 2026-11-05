import EdgyCore

/// The real gesture pipeline: zone classification, misfire defense and recognizers.
///
/// Pure and deterministic. All time comes from frame timestamps; all state is walked in sorted
/// order, so the same frames and settings always give the same output.
///
/// Event conventions:
/// - Slides emit `.began` (delta 0), any number of `.changed`, then `.ended` (delta 0) on lift or
///   `.cancelled` when misfire defense revokes the claim.
/// - Discrete gestures (tap, double-tap, long-press, swipe) emit exactly one event, phase `.ended`.
/// - The first tap emits `.tap`; a second tap in the same zone within the double-tap window emits
///   `.doubleTap` instead of a second `.tap`. (There are no timers, so a tap cannot be delayed.)
final class GesturePipeline: GestureRecognizing {
  let tuning: Tuning
  private var devices: [UInt64: DeviceState] = [:]

  init(tuning: Tuning = .standard) {
    self.tuning = tuning
  }

  func process(_ frame: TouchFrame, device: TouchDeviceInfo, context: GestureContext) -> GestureOutput {
    var step = FrameStep(
      frame: frame, geometry: ZoneGeometry(device: device, settings: context.settings), context: context,
      timing: Timing(context.settings), tuning: tuning, state: devices[frame.deviceID] ?? DeviceState())
    let output = step.run()
    devices[frame.deviceID] = step.state
    return output
  }

  func reset() {
    devices = [:]
  }
}

/// One finger (or palm) seen on the sensor.
struct Track: Sendable {
  enum Role: Sendable {
    /// Landed outside every zone; watched only so drifting into a zone can be reported.
    case outside
    /// Belongs to a live gesture candidate.
    case member
    /// Rejected, or left over from a finished gesture; still counts as a contact until it lifts.
    case finished
  }

  let id: Int32
  let birthTime: Double
  /// Last position, millimetres.
  var position: Point2D
  var role: Role
  var isPalm = false
  var rejected = false
}

/// The live state of the slide output stage (dead band + rest detection).
struct SlideOutput: Sendable {
  /// Along-axis position (mm) of the last emitted output.
  var anchor = 0.0
  /// False while at rest: output resumes only after moving `deadBandMM` from `anchor`.
  var moving = false
  var restReference = 0.0
  var restSince = 0.0
  var emittedMotion = false
}

/// A touch (one or more fingers) that started in a mapped zone and may become a gesture.
struct Candidate: Sendable {
  enum Phase: Sendable {
    case pending
    case swipe
    case sliding
  }

  let key: Int
  let zone: Zone
  let region: Region
  let birthTime: Double
  var members: [Int32]
  /// Centroid at landing (or when the last finger joined), millimetres.
  var origin: Point2D
  /// Latest centroid, millimetres.
  var current: Point2D
  var maxTravel = 0.0
  var phase = Phase.pending
  var slide = SlideOutput()
  var longPressFired = false

  /// Whether this candidate owns its fingers (the pointer guard should be engaged): a slide, a
  /// swipe in flight, or a fired long-press.
  var claims: Bool { phase == .sliding || phase == .swipe || longPressFired }
}

struct DeviceState: Sendable {
  var tracks: [Int32: Track] = [:]
  /// In creation order.
  var candidates: [Candidate] = []
  var nextKey = 0
  /// Lift time of the last unpaired tap per zone.
  var lastTap: [Zone: Double] = [:]
}

/// Processing of one frame against one device's state.
struct FrameStep {
  let frame: TouchFrame
  let geometry: ZoneGeometry
  let context: GestureContext
  let timing: Timing
  let tuning: Tuning
  var state: DeviceState
  var events: [GestureEvent] = []
  var rejections: [(contactID: Int32, reason: RejectionReason)] = []

  var now: Double { frame.timestamp }

  /// Most simultaneous contacts a gesture may involve. Three or more always belong to the system.
  func slideAllowed(_ candidate: Candidate) -> Bool {
    context.slideZones?.contains(candidate.zone) ?? true
  }

  func swipeLimit(_ candidate: Candidate) -> Double {
    slideAllowed(candidate) ? tuning.swipeMaxDurationS : tuning.swipeOnlyMaxDurationS
  }

  var fingerLimit: Int { min(max(context.settings.fingers, 1), 2) }

  var typingNow: Bool {
    guard let seconds = context.secondsSinceLastKeyPress else { return false }
    return seconds < timing.typingSuppression
  }

  mutating func run() -> GestureOutput {
    let down = frame.contacts.filter { Self.isDown($0.state) }.sorted { $0.id < $1.id }
    let downIDs = Set(down.map(\.id))
    for id in state.tracks.keys.sorted() where !downIDs.contains(id) {
      lift(id)
    }
    for contact in down {
      observe(contact)
    }
    enforceContactCount()
    for key in state.candidates.map(\.key) {
      advance(key)
    }
    reportDriftIntoZones()
    let claimed = Set(state.candidates.filter(\.claims).flatMap(\.members))
    return GestureOutput(events: events, claimedContactIDs: claimed, rejections: rejections)
  }

  static func isDown(_ state: TouchContact.State) -> Bool {
    switch state {
    case .starting, .touching, .unknown: return true
    case .hovering, .lifting, .leaving: return false
    }
  }

  func isPalm(_ contact: TouchContact) -> Bool {
    contact.majorAxisMM > context.settings.palmMajorAxisMM
      || contact.minorAxisMM > tuning.palmMinorAxisMM
      || contact.size >= tuning.palmSize
      || (contact.size >= tuning.palmSoftSize && contact.density < tuning.palmMaxDensity)
  }

  // MARK: - Contacts

  mutating func observe(_ contact: TouchContact) {
    let position = geometry.millimetres(contact.position)
    guard var track = state.tracks[contact.id] else {
      birth(contact, at: position)
      return
    }
    track.position = position
    let becamePalm = !track.isPalm && isPalm(contact)
    if becamePalm { track.isPalm = true }
    state.tracks[contact.id] = track
    guard becamePalm else { return }
    if track.role == .member, let key = candidateKey(containing: contact.id) {
      rejectCandidate(key, .palm)
    } else {
      rejectTrack(contact.id, .palm)
    }
  }

  mutating func birth(_ contact: TouchContact, at position: Point2D) {
    state.tracks[contact.id] = Track(id: contact.id, birthTime: now, position: position, role: .outside)
    if isPalm(contact) {
      state.tracks[contact.id]?.isPalm = true
      rejectTrack(contact.id, .palm)
      return
    }
    guard let region = geometry.region(at: position) else { return }
    guard let zone = geometry.zone(for: region, at: position, enabled: context.enabledZones) else {
      rejectTrack(contact.id, .disabledZone)
      return
    }
    if typingNow {
      rejectTrack(contact.id, .typing)
      return
    }
    state.tracks[contact.id]?.role = .member
    if fingerLimit > 1,
      let index = state.candidates.firstIndex(where: {
        $0.zone == zone && $0.phase == .pending && !$0.longPressFired && $0.members.count < fingerLimit
          && now - $0.birthTime <= tuning.multiFingerWindowS
      })
    {
      var candidate = state.candidates[index]
      candidate.members.append(contact.id)
      candidate.members.sort()
      candidate.origin = centroid(of: candidate.members)
      candidate.current = candidate.origin
      candidate.maxTravel = 0
      state.candidates[index] = candidate
      return
    }
    state.candidates.append(
      Candidate(
        key: state.nextKey, zone: zone, region: region, birthTime: now, members: [contact.id],
        origin: position, current: position))
    state.nextKey += 1
  }

  mutating func lift(_ id: Int32) {
    guard let track = state.tracks.removeValue(forKey: id), track.role == .member,
      let index = state.candidates.firstIndex(where: { $0.members.contains(id) })
    else { return }
    let candidate = state.candidates.remove(at: index)
    for member in candidate.members where member != id {
      state.tracks[member]?.role = .finished
    }
    finish(candidate)
  }

  /// More contacts than the gesture allows → reject. A gesture that already owns its fingers is
  /// revoked only by a contact that landed together with it (a multi-finger touch) or by 3+ contacts.
  mutating func enforceContactCount() {
    let active = state.tracks.values.filter { !$0.isPalm }
    guard active.count > fingerLimit else { return }
    for key in state.candidates.map(\.key) {
      guard let candidate = candidate(key) else { continue }
      if !candidate.claims {
        rejectCandidate(key, .tooManyContacts)
        continue
      }
      let landedTogether = active.contains {
        !candidate.members.contains($0.id) && abs($0.birthTime - candidate.birthTime) <= tuning.multiFingerWindowS
      }
      if active.count >= 3 || landedTogether {
        rejectCandidate(key, .tooManyContacts)
      }
    }
  }

  /// Start-in-zone only: a touch that landed outside and slides into a mapped zone is reported once.
  mutating func reportDriftIntoZones() {
    for id in state.tracks.keys.sorted() {
      guard let track = state.tracks[id], track.role == .outside, !track.isPalm,
        let region = geometry.region(at: track.position),
        geometry.zone(for: region, at: track.position, enabled: context.enabledZones) != nil
      else { continue }
      rejectTrack(id, .startedOutsideZone)
    }
  }

  // MARK: - Candidates

  mutating func advance(_ key: Int) {
    guard let index = index(of: key) else { return }
    var candidate = state.candidates[index]
    candidate.current = centroid(of: candidate.members)
    let travel = distance(candidate.current, candidate.origin)
    candidate.maxTravel = max(candidate.maxTravel, travel)
    state.candidates[index] = candidate

    if !candidate.claims && typingNow {
      rejectCandidate(key, .typing)
      return
    }
    switch candidate.region {
    case .corner: advanceCorner(candidate)
    case .edge(let edge): advanceEdge(candidate, edge: edge, travel: travel)
    }
  }

  /// Corners recognize taps, double-taps and long-presses only.
  mutating func advanceCorner(_ candidate: Candidate) {
    guard !candidate.longPressFired else { return }
    if candidate.maxTravel > tuning.cornerMaxTravelMM {
      rejectCandidate(candidate.key, .offAxisMotion)
      return
    }
    if now - candidate.birthTime >= timing.longPress && candidate.maxTravel <= tuning.longPressMaxTravelMM {
      fireLongPress(candidate.key)
    }
  }

  mutating func advanceEdge(_ candidate: Candidate, edge: Zone.Edge, travel: Double) {
    let elapsed = now - candidate.birthTime
    switch candidate.phase {
    case .sliding:
      updateSlide(candidate.key, edge: edge)
      if let updated = self.candidate(candidate.key), !updated.longPressFired, !updated.slide.emittedMotion,
        elapsed >= timing.longPress, updated.maxTravel <= tuning.longPressMaxTravelMM
      {
        fireLongPress(candidate.key)
      }
    case .swipe:
      if elapsed > swipeLimit(candidate) {
        rejectCandidate(candidate.key, .tooFast)
      }
    case .pending:
      advancePendingEdge(candidate, edge: edge, travel: travel, elapsed: elapsed)
    }
  }

  /// The intent gate: claim on dwell or clearly along-axis motion, hand inward motion to the system,
  /// reject other off-axis motion, and divert fast flicks to the swipe recognizer.
  mutating func advancePendingEdge(_ candidate: Candidate, edge: Zone.Edge, travel: Double, elapsed: Double) {
    let along = geometry.along(edge, candidate.current) - geometry.along(edge, candidate.origin)
    let inward = geometry.inward(edge, from: candidate.origin, to: candidate.current)
    let slideFingersMatch = candidate.members.count == fingerLimit && slideAllowed(candidate)

    if abs(along) >= tuning.alongClaimMM && abs(along) >= tuning.axisDominance * abs(inward) {
      let speed = abs(along) / max(elapsed, tuning.minimumIntervalS)
      if speed >= tuning.flickSpeedMMPerS || !slideAllowed(candidate) {
        setPhase(candidate.key, .swipe)
      } else if slideFingersMatch {
        // Anchor at the landing point so the motion that earned the claim is emitted right away.
        beginSlide(candidate.key, anchor: geometry.along(edge, candidate.origin), moving: true)
        updateSlide(candidate.key, edge: edge)
      }
      return
    }
    if abs(inward) >= tuning.perpendicularDecideMM && abs(inward) > abs(along) {
      rejectCandidate(candidate.key, inward > 0 ? .systemGestureHandoff : .offAxisMotion)
      return
    }
    if travel >= tuning.diagonalDecideMM {
      rejectCandidate(candidate.key, .offAxisMotion)
      return
    }
    if slideFingersMatch && candidate.maxTravel <= tuning.stillRadiusMM && elapsed >= timing.dwell {
      beginSlide(candidate.key, anchor: geometry.along(edge, candidate.current), moving: false)
      return
    }
    if !candidate.longPressFired && elapsed >= timing.longPress
      && candidate.maxTravel <= tuning.longPressMaxTravelMM
    {
      fireLongPress(candidate.key)
    }
  }

  mutating func beginSlide(_ key: Int, anchor: Double, moving: Bool) {
    guard let index = index(of: key) else { return }
    state.candidates[index].phase = .sliding
    state.candidates[index].slide = SlideOutput(
      anchor: anchor, moving: moving, restReference: anchor, restSince: now, emittedMotion: false)
    emit(state.candidates[index], .slide, phase: .began, deltaMM: 0)
  }

  /// Dead band + rest detection: a slide at rest stays silent until it moves `deadBandMM`; a moving
  /// slide emits every frame until it holds within `restEpsilonMM` for `restDurationS`.
  mutating func updateSlide(_ key: Int, edge: Zone.Edge) {
    guard let index = index(of: key) else { return }
    var candidate = state.candidates[index]
    let along = geometry.along(edge, candidate.current)
    var delta: Double?
    if candidate.slide.moving {
      if abs(along - candidate.slide.restReference) > tuning.restEpsilonMM {
        candidate.slide.restReference = along
        candidate.slide.restSince = now
      } else if now - candidate.slide.restSince >= tuning.restDurationS {
        candidate.slide.moving = false
      }
      if candidate.slide.moving && along != candidate.slide.anchor {
        delta = along - candidate.slide.anchor
      }
    } else if abs(along - candidate.slide.anchor) >= tuning.deadBandMM {
      delta = along - candidate.slide.anchor
      candidate.slide.moving = true
      candidate.slide.restReference = along
      candidate.slide.restSince = now
    }
    if delta != nil {
      candidate.slide.anchor = along
      candidate.slide.emittedMotion = true
    }
    state.candidates[index] = candidate
    if let delta {
      emit(candidate, .slide, phase: .changed, deltaMM: delta)
    }
  }

  mutating func fireLongPress(_ key: Int) {
    guard let index = index(of: key),
      context.longPressZones?.contains(state.candidates[index].zone) ?? true
    else { return }
    state.candidates[index].longPressFired = true
    emit(state.candidates[index], .longPress, phase: .ended, deltaMM: 0)
  }

  mutating func setPhase(_ key: Int, _ phase: Candidate.Phase) {
    guard let index = index(of: key) else { return }
    state.candidates[index].phase = phase
  }

  /// A member lifted: the candidate is over. Decide what it was.
  mutating func finish(_ candidate: Candidate) {
    let elapsed = now - candidate.birthTime
    let tapLike = elapsed <= tuning.tapMaxDurationS && candidate.maxTravel <= tuning.tapMaxTravelMM
    switch candidate.phase {
    case .sliding:
      if !candidate.slide.emittedMotion && !candidate.longPressFired && tapLike {
        // A dwell claim that never moved and lifted quickly was really a tap.
        emit(candidate, .slide, phase: .cancelled, deltaMM: 0)
        tap(candidate)
      } else {
        emit(candidate, .slide, phase: .ended, deltaMM: 0)
      }
    case .swipe:
      if let direction = swipeDirection(candidate, elapsed: elapsed) {
        emit(candidate, .swipe(direction), phase: .ended, deltaMM: 0)
      } else {
        let reason: RejectionReason = isPerpendicularDominant(candidate) ? .offAxisMotion : .tooFast
        for member in candidate.members { rejectLifted(member, reason) }
      }
    case .pending:
      guard !candidate.longPressFired else { return }
      if let direction = swipeDirection(candidate, elapsed: elapsed),
        isFlick(candidate, elapsed: elapsed) || !slideAllowed(candidate)
      {
        emit(candidate, .swipe(direction), phase: .ended, deltaMM: 0)
      } else if tapLike {
        tap(candidate)
      }
    }
  }

  mutating func tap(_ candidate: Candidate) {
    if let last = state.lastTap[candidate.zone], candidate.birthTime >= last,
      candidate.birthTime - last <= timing.doubleTapWindow
    {
      state.lastTap[candidate.zone] = nil
      emit(candidate, .doubleTap, phase: .ended, deltaMM: 0)
    } else {
      state.lastTap[candidate.zone] = now
      emit(candidate, .tap, phase: .ended, deltaMM: 0)
    }
  }

  func swipeDirection(_ candidate: Candidate, elapsed: Double) -> SwipeDirection? {
    guard case .edge(let edge) = candidate.region, elapsed <= swipeLimit(candidate) else { return nil }
    let along = geometry.along(edge, candidate.current) - geometry.along(edge, candidate.origin)
    let inward = geometry.inward(edge, from: candidate.origin, to: candidate.current)
    guard abs(along) >= tuning.swipeMinTravelMM, abs(along) >= tuning.axisDominance * abs(inward) else {
      return nil
    }
    switch edge {
    case .left, .right: return along > 0 ? .up : .down
    case .top, .bottom: return along > 0 ? .right : .left
    }
  }

  func isFlick(_ candidate: Candidate, elapsed: Double) -> Bool {
    guard case .edge(let edge) = candidate.region else { return false }
    let along = geometry.along(edge, candidate.current) - geometry.along(edge, candidate.origin)
    return abs(along) / max(elapsed, tuning.minimumIntervalS) >= tuning.flickSpeedMMPerS
  }

  func isPerpendicularDominant(_ candidate: Candidate) -> Bool {
    guard case .edge(let edge) = candidate.region else { return false }
    let along = geometry.along(edge, candidate.current) - geometry.along(edge, candidate.origin)
    let inward = geometry.inward(edge, from: candidate.origin, to: candidate.current)
    return abs(inward) > abs(along)
  }

  // MARK: - Rejection + output

  /// Revoke a candidate: cancel its slide if one is live, and reject each of its fingers.
  mutating func rejectCandidate(_ key: Int, _ reason: RejectionReason) {
    guard let index = index(of: key) else { return }
    let candidate = state.candidates.remove(at: index)
    if candidate.phase == .sliding {
      emit(candidate, .slide, phase: .cancelled, deltaMM: 0)
    }
    for member in candidate.members {
      rejectTrack(member, reason)
    }
  }

  /// Reject a contact at most once; it stops participating but still counts until it lifts.
  mutating func rejectTrack(_ id: Int32, _ reason: RejectionReason) {
    guard var track = state.tracks[id], !track.rejected else { return }
    track.rejected = true
    track.role = .finished
    state.tracks[id] = track
    rejections.append((contactID: id, reason: reason))
  }

  /// Reject a member of a candidate that just ended because a finger lifted.
  mutating func rejectLifted(_ id: Int32, _ reason: RejectionReason) {
    if state.tracks[id] != nil {
      rejectTrack(id, reason)
    } else {
      rejections.append((contactID: id, reason: reason))
    }
  }

  mutating func emit(_ candidate: Candidate, _ kind: GestureKind, phase: GestureEvent.Phase, deltaMM: Double) {
    events.append(
      GestureEvent(
        zone: candidate.zone, kind: kind, fingers: candidate.members.count, phase: phase,
        delta: deltaMM / geometry.zoneLength(candidate.zone),
        position: geometry.position(in: candidate.zone, at: candidate.current),
        timestamp: now, deviceID: frame.deviceID))
  }

  // MARK: - Lookup

  func index(of key: Int) -> Int? {
    state.candidates.firstIndex { $0.key == key }
  }

  func candidate(_ key: Int) -> Candidate? {
    index(of: key).map { state.candidates[$0] }
  }

  func candidateKey(containing id: Int32) -> Int? {
    state.candidates.first { $0.members.contains(id) }?.key
  }

  func centroid(of members: [Int32]) -> Point2D {
    let points = members.compactMap { state.tracks[$0]?.position }
    guard !points.isEmpty else { return Point2D(x: 0, y: 0) }
    let count = Double(points.count)
    return Point2D(
      x: points.reduce(0) { $0 + $1.x } / count,
      y: points.reduce(0) { $0 + $1.y } / count)
  }

  func distance(_ a: Point2D, _ b: Point2D) -> Double {
    let dx = a.x - b.x
    let dy = a.y - b.y
    return (dx * dx + dy * dy).squareRoot()
  }
}
