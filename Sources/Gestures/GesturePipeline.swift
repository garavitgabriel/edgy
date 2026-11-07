import EdgyCore

/// The real gesture pipeline: zone classification, misfire defense and recognizers.
///
/// Pure and deterministic. All time comes from frame timestamps; all state is walked in sorted
/// order, so the same frames and settings always give the same output.
///
/// Event conventions:
/// - Slides emit `.began` (delta 0), any number of `.changed`, then `.ended` (delta 0) on lift or
///   `.cancelled` when misfire defense revokes the claim.
/// - Tap, double-tap and swipe emit exactly one event, phase `.ended`.
/// - Long-press emits `.began` the moment the hold is recognized (while the finger is down), then
///   exactly one of `.ended` (a member lifts) or `.cancelled` (misfire defense takes the touch away:
///   palm, extra fingers). The fingers stay claimed from `.began` until then. Once a hold has
///   begun the touch is frozen: no swipe, no slide output, no off-axis rejection. `reset()` emits
///   nothing; whoever resets (the engine) owns closing any hold it was told about.
/// - The first tap emits `.tap`; a second tap in the same zone within the double-tap window emits
///   `.doubleTap` instead of a second `.tap`.
/// - In a zone of `context.doubleTapZones` the first tap is held back instead (see `PendingTap`):
///   it is emitted once the double-tap window passes with no second tap, or dropped when the second
///   tap turns it into a `.doubleTap`. Elsewhere taps fire at once.
/// - A physical click (`frame.buttonDown`) rejects every live candidate with `.physicalClick`
///   (cancelling a claimed slide or hold, as a palm does). Rejected fingers stay not-ours until lift.
final class GesturePipeline: GestureRecognizing, DeferredGestureFlushing {
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

  /// Drops every touch and every pending tap.
  func reset() {
    devices = [:]
  }

  var nextFlushDeadline: Double? {
    // A device with fingers down keeps sending frames, and `process` releases what is due.
    devices.values.filter(\.tracks.isEmpty).flatMap(\.pendingTaps).map(\.deadline).min()
  }

  func flush(now: Double) -> GestureOutput {
    var events: [GestureEvent] = []
    for id in devices.keys.sorted() {
      guard var state = devices[id], state.tracks.isEmpty else { continue }
      events += state.releasePendingTaps(now: now, tuning: tuning)
      devices[id] = state
    }
    let claimed = devices.values.flatMap { $0.candidates.filter(\.claims).flatMap(\.members) }
    return GestureOutput(events: events, claimedContactIDs: Set(claimed))
  }
}

/// A single tap held back because its zone also has a double-tap bound.
struct PendingTap: Sendable {
  /// The `.tap` exactly as it would have fired at lift (position and timestamp of the lift).
  let event: GestureEvent
  let liftTime: Double
  /// `liftTime` + the double-tap window: a second touch in the zone born by then may still pair.
  let deadline: Double
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
  /// Where it landed, millimetres.
  let origin: Point2D
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
  /// Taps waiting for a possible double-tap, in lift order.
  var pendingTaps: [PendingTap] = []

  /// Whether a live candidate in `pending`'s zone could still end as the second tap of a
  /// double-tap: born inside the window, not yet anything else, still short and still enough.
  func mayPair(_ pending: PendingTap, now: Double, tuning: Tuning) -> Bool {
    candidates.contains {
      $0.zone == pending.event.zone && $0.birthTime >= pending.liftTime && $0.birthTime <= pending.deadline
        && !$0.longPressFired && ($0.phase == .pending || ($0.phase == .sliding && !$0.slide.emittedMotion))
        && now - $0.birthTime <= tuning.tapMaxDurationS && $0.maxTravel <= tuning.tapMaxTravelMM
    }
  }

  /// Releases the pending taps that are due: the window has passed and nothing may still pair, or
  /// (`settled`) something else already happened in the zone, which makes the earlier tap final.
  mutating func releasePendingTaps(now: Double, tuning: Tuning, settled: Set<Zone> = []) -> [GestureEvent] {
    let due = pendingTaps.map {
      settled.contains($0.event.zone) || (now > $0.deadline && !mayPair($0, now: now, tuning: tuning))
    }
    let released = zip(pendingTaps, due).filter(\.1).map(\.0.event)
    pendingTaps = zip(pendingTaps, due).filter { !$0.1 }.map(\.0)
    return released
  }
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
  /// The number behind each rejection in `rejections`, when one means something.
  var measures: [Int32: RejectionMeasure] = [:]

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
    // Lifts are settled first: a click needs a finger pressing, so a button that goes down as a
    // finger lifts (tap-to-click reports its click after the lift) does not undo that tap.
    if frame.buttonDown {
      rejectForPhysicalClick()
    }
    enforceContactCount()
    for key in state.candidates.map(\.key) {
      advance(key)
    }
    reportDriftIntoZones()
    releasePendingTaps()
    let claimed = Set(state.candidates.filter(\.claims).flatMap(\.members))
    return GestureOutput(
      events: events, claimedContactIDs: claimed, rejections: rejections, rejectionMeasures: measures)
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

  /// The button is down: whatever is on the pad is pressing, dragging or selecting. Every live
  /// candidate is rejected (claimed slides and holds are cancelled); its fingers are `finished`,
  /// so they never become a candidate again before they lift. A finger that lands while the button
  /// is down becomes a candidate in `birth` and is rejected here in the same frame.
  mutating func rejectForPhysicalClick() {
    for key in state.candidates.map(\.key) {
      rejectCandidate(key, .physicalClick)
    }
  }

  /// Emits the taps that stopped waiting, ahead of this frame's events (they happened earlier).
  mutating func releasePendingTaps() {
    guard !state.pendingTaps.isEmpty else { return }
    // Anything but a dwell claim (which may still lift as the second tap) settles the zone.
    let settled = Set(
      events.filter { $0.kind != .doubleTap && !($0.kind == .slide && $0.phase == .began) }.map(\.zone))
    events.insert(contentsOf: state.releasePendingTaps(now: now, tuning: tuning, settled: settled), at: 0)
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
    let measure = palmMeasure(contact)
    if track.role == .member, let key = candidateKey(containing: contact.id) {
      rejectCandidate(key, .palm, measure: measure)
    } else {
      rejectTrack(contact.id, .palm, measure: measure)
    }
  }

  mutating func birth(_ contact: TouchContact, at position: Point2D) {
    state.tracks[contact.id] = Track(
      id: contact.id, birthTime: now, origin: position, position: position, role: .outside)
    if isPalm(contact) {
      state.tracks[contact.id]?.isPalm = true
      rejectTrack(contact.id, .palm, measure: palmMeasure(contact))
      return
    }
    guard let resolved = geometry.resolve(at: position, enabled: context.enabledZones) else { return }
    let region = resolved.region
    guard let zone = resolved.zone else {
      rejectTrack(contact.id, .disabledZone)
      return
    }
    if typingNow {
      rejectTrack(contact.id, .typing, measure: typingMeasure)
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
  /// revoked only by a contact that landed together with it (a multi-finger touch), by 3+
  /// contacts, or by another contact that moves (`foreignMotionMM`: someone is using the pointer).
  mutating func enforceContactCount() {
    let active = state.tracks.values.filter { !$0.isPalm }
    guard active.count > fingerLimit else { return }
    for key in state.candidates.map(\.key) {
      guard let candidate = candidate(key) else { continue }
      let measure = RejectionMeasure(measured: Double(active.count), limit: Double(fingerLimit), unit: .fingers)
      if !candidate.claims {
        rejectCandidate(key, .tooManyContacts, measure: measure)
        continue
      }
      let landedTogether = active.contains {
        !candidate.members.contains($0.id) && abs($0.birthTime - candidate.birthTime) <= tuning.multiFingerWindowS
      }
      let othersMoving = active.contains {
        !candidate.members.contains($0.id) && distance($0.position, $0.origin) > tuning.foreignMotionMM
      }
      if active.count >= 3 || landedTogether || othersMoving {
        rejectCandidate(key, .tooManyContacts, measure: measure)
      }
    }
  }

  /// Start-in-zone only: a touch that landed outside and slides into a mapped zone is reported once.
  mutating func reportDriftIntoZones() {
    for id in state.tracks.keys.sorted() {
      guard let track = state.tracks[id], track.role == .outside, !track.isPalm,
        geometry.resolve(at: track.position, enabled: context.enabledZones)?.zone != nil
      else { continue }
      rejectTrack(id, .startedOutsideZone, measure: outsideMeasure(track))
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
      rejectCandidate(key, .typing, measure: typingMeasure)
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
      rejectCandidate(
        candidate.key, .offAxisMotion,
        measure: RejectionMeasure(measured: candidate.maxTravel, limit: tuning.cornerMaxTravelMM, unit: .mm))
      return
    }
    if now - candidate.birthTime >= timing.longPress && candidate.maxTravel <= tuning.longPressMaxTravelMM {
      fireLongPress(candidate.key)
    }
  }

  mutating func advanceEdge(_ candidate: Candidate, edge: Zone.Edge, travel: Double) {
    // A hold that has begun owns the touch until lift: motion no longer becomes a swipe, slide
    // output or an off-axis rejection (each would strand or contradict the hold).
    guard !candidate.longPressFired else { return }
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
        rejectCandidate(candidate.key, .tooFast, measure: swipeTimeMeasure(candidate, elapsed: elapsed))
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
      if inward > 0 {
        rejectCandidate(candidate.key, .systemGestureHandoff)
      } else {
        rejectCandidate(
          candidate.key, .offAxisMotion,
          measure: RejectionMeasure(measured: abs(inward), limit: tuning.perpendicularDecideMM, unit: .mm))
      }
      return
    }
    if travel >= tuning.diagonalDecideMM {
      rejectCandidate(
        candidate.key, .offAxisMotion,
        measure: RejectionMeasure(measured: travel, limit: tuning.diagonalDecideMM, unit: .mm))
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
    emit(state.candidates[index], .longPress, phase: .began, deltaMM: 0)
  }

  mutating func setPhase(_ key: Int, _ phase: Candidate.Phase) {
    guard let index = index(of: key) else { return }
    state.candidates[index].phase = phase
  }

  /// A member lifted: the candidate is over. Decide what it was.
  mutating func finish(_ candidate: Candidate) {
    let elapsed = now - candidate.birthTime
    let tapLike = elapsed <= tuning.tapMaxDurationS && candidate.maxTravel <= tuning.tapMaxTravelMM
    if candidate.longPressFired {
      if candidate.phase == .sliding { emit(candidate, .slide, phase: .ended, deltaMM: 0) }
      emit(candidate, .longPress, phase: .ended, deltaMM: 0)
      return
    }
    switch candidate.phase {
    case .sliding:
      if !candidate.slide.emittedMotion && tapLike {
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
        let (reason, measure) = failedSwipe(candidate, elapsed: elapsed)
        for member in candidate.members { rejectLifted(member, reason, measure: measure) }
      }
    case .pending:
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
      // The double-tap replaces the first tap if it is still held back.
      state.pendingTaps.removeAll { $0.event.zone == candidate.zone }
      emit(candidate, .doubleTap, phase: .ended, deltaMM: 0)
    } else {
      state.lastTap[candidate.zone] = now
      let tap = event(candidate, .tap, phase: .ended, deltaMM: 0)
      if waitsForDoubleTap(candidate.zone) {
        state.pendingTaps.append(PendingTap(event: tap, liftTime: now, deadline: now + timing.doubleTapWindow))
      } else {
        events.append(tap)
      }
    }
  }

  /// Taps wait in the zones with a double-tap bound. The context doesn't say which zones have a
  /// tap bound, so the wait set is `doubleTapZones` itself; where no tap is bound the router drops
  /// the delayed tap, so the wait costs nothing there. `nil` → no zone waits.
  func waitsForDoubleTap(_ zone: Zone) -> Bool {
    context.doubleTapZones?.contains(zone) ?? false
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

  /// Why a swipe candidate that lifted didn't make a swipe, and the number behind it:
  /// - more travel across the edge than along it → `offAxisMotion` (across vs along, mm);
  /// - it took longer than the swipe time limit → `tooFast` (elapsed vs limit, ms; the reason's
  ///   name is historical: the touch was fast enough to be a swipe candidate, then too slow to lift);
  /// - it didn't travel far enough along the edge → `tooFast` (along vs `swipeMinTravelMM`, mm);
  /// - otherwise (along won, but not by `axisDominance`) → `tooFast` with no measure.
  func failedSwipe(_ candidate: Candidate, elapsed: Double) -> (RejectionReason, RejectionMeasure?) {
    guard case .edge(let edge) = candidate.region else { return (.tooFast, nil) }
    let along = abs(geometry.along(edge, candidate.current) - geometry.along(edge, candidate.origin))
    let inward = abs(geometry.inward(edge, from: candidate.origin, to: candidate.current))
    if inward > along {
      return (.offAxisMotion, RejectionMeasure(measured: inward, limit: along, unit: .mm))
    }
    if elapsed > swipeLimit(candidate) {
      return (.tooFast, swipeTimeMeasure(candidate, elapsed: elapsed))
    }
    if along < tuning.swipeMinTravelMM {
      return (.tooFast, RejectionMeasure(measured: along, limit: tuning.swipeMinTravelMM, unit: .mm))
    }
    return (.tooFast, nil)
  }

  // MARK: - Measures

  /// How long a swipe candidate stayed down against the swipe time limit.
  func swipeTimeMeasure(_ candidate: Candidate, elapsed: Double) -> RejectionMeasure {
    RejectionMeasure(measured: elapsed * 1000, limit: swipeLimit(candidate) * 1000, unit: .ms)
  }

  /// Time since the last key press against `typingSuppressionMS`.
  var typingMeasure: RejectionMeasure? {
    guard let seconds = context.secondsSinceLastKeyPress else { return nil }
    return RejectionMeasure(measured: seconds * 1000, limit: context.settings.typingSuppressionMS, unit: .ms)
  }

  /// The axis that crossed its palm limit: the major axis against `palmMajorAxisMM`, else the minor
  /// axis against the fixed round-blob limit. A contact judged by size or density alone (unitless
  /// device readings) gets no measure.
  func palmMeasure(_ contact: TouchContact) -> RejectionMeasure? {
    if contact.majorAxisMM > context.settings.palmMajorAxisMM {
      return RejectionMeasure(measured: contact.majorAxisMM, limit: context.settings.palmMajorAxisMM, unit: .mm)
    }
    if contact.minorAxisMM > tuning.palmMinorAxisMM {
      return RejectionMeasure(measured: contact.minorAxisMM, limit: tuning.palmMinorAxisMM, unit: .mm)
    }
    return nil
  }

  /// How far in from the physical edge the touch landed, against the region it drifted into: the
  /// edge strip's depth (`edgeWidthMM`) or the corner square's side (`cornerSizeMM`).
  func outsideMeasure(_ track: Track) -> RejectionMeasure? {
    guard let region = geometry.resolve(at: track.position, enabled: context.enabledZones)?.region else { return nil }
    let fromLeft = track.origin.x
    let fromRight = geometry.width - track.origin.x
    let fromBottom = track.origin.y
    let fromTop = geometry.height - track.origin.y
    switch region {
    case .edge(let edge):
      let depth: Double
      switch edge {
      case .left: depth = fromLeft
      case .right: depth = fromRight
      case .bottom: depth = fromBottom
      case .top: depth = fromTop
      }
      return RejectionMeasure(measured: depth, limit: geometry.edgeWidth, unit: .mm)
    case .corner(let corner):
      let across: Double
      switch corner {
      case .topLeft: across = max(fromLeft, fromTop)
      case .topRight: across = max(fromRight, fromTop)
      case .bottomLeft: across = max(fromLeft, fromBottom)
      case .bottomRight: across = max(fromRight, fromBottom)
      }
      return RejectionMeasure(measured: across, limit: geometry.cornerSize, unit: .mm)
    }
  }

  // MARK: - Rejection + output

  /// Revoke a candidate: cancel its slide if one is live, and reject each of its fingers.
  mutating func rejectCandidate(_ key: Int, _ reason: RejectionReason, measure: RejectionMeasure? = nil) {
    guard let index = index(of: key) else { return }
    let candidate = state.candidates.remove(at: index)
    if candidate.phase == .sliding {
      emit(candidate, .slide, phase: .cancelled, deltaMM: 0)
    }
    if candidate.longPressFired {
      emit(candidate, .longPress, phase: .cancelled, deltaMM: 0)
    }
    for member in candidate.members {
      rejectTrack(member, reason, measure: measure)
    }
  }

  /// Reject a contact at most once; it stops participating but still counts until it lifts.
  mutating func rejectTrack(_ id: Int32, _ reason: RejectionReason, measure: RejectionMeasure? = nil) {
    guard var track = state.tracks[id], !track.rejected else { return }
    track.rejected = true
    track.role = .finished
    state.tracks[id] = track
    record(id, reason, measure)
  }

  mutating func record(_ id: Int32, _ reason: RejectionReason, _ measure: RejectionMeasure?) {
    rejections.append((contactID: id, reason: reason))
    if let measure { measures[id] = measure }
  }

  /// Reject a member of a candidate that just ended because a finger lifted.
  mutating func rejectLifted(_ id: Int32, _ reason: RejectionReason, measure: RejectionMeasure? = nil) {
    if state.tracks[id] != nil {
      rejectTrack(id, reason, measure: measure)
    } else {
      record(id, reason, measure)
    }
  }

  mutating func emit(_ candidate: Candidate, _ kind: GestureKind, phase: GestureEvent.Phase, deltaMM: Double) {
    events.append(event(candidate, kind, phase: phase, deltaMM: deltaMM))
  }

  func event(_ candidate: Candidate, _ kind: GestureKind, phase: GestureEvent.Phase, deltaMM: Double) -> GestureEvent {
    GestureEvent(
      zone: candidate.zone, kind: kind, fingers: candidate.members.count, phase: phase,
      delta: deltaMM / geometry.zoneLength(candidate.zone),
      position: geometry.position(in: candidate.zone, at: candidate.current),
      timestamp: now, deviceID: frame.deviceID)
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
