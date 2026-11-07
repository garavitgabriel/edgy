import EdgyCore
import Foundation
import Testing

@testable import EdgyRuntime

/// Drives an engine with frames that carry contacts and records what the feed delivers. Feed
/// handlers run on the engine's own test queue, so flushing it twice makes delivery synchronous.
final class FeedHarness {
  let h: EngineHarness
  let updates = Locked<[LiveFeedUpdate]>([])
  private(set) var token: UUID?
  private var n: Int32 = 0

  init(config: EdgyConfig = .defaults, catalog: [ActionDescriptor] = [], observe: Bool = true) throws {
    h = try EngineHarness(config: config, catalog: catalog)
    if observe { subscribe() }
  }

  func subscribe() {
    let updates = updates
    token = h.engine.observeFeed(on: h.queue) { updates.value.append($0) }
  }

  static func contact(_ id: Int32, x: Double, y: Double) -> TouchContact {
    TouchContact(
      id: id, state: .touching, position: Point2D(x: x, y: y), velocity: Vector2D(dx: 0, dy: 0), majorAxisMM: 8,
      minorAxisMM: 7, angle: 0, size: 1, density: 1)
  }

  /// One 120 Hz frame with these contacts and this recognizer output.
  func frame(_ contacts: [TouchContact] = [], _ output: GestureOutput = GestureOutput()) {
    h.queue.sync { h.recognizer.script.append(output) }
    n += 1
    h.touch.emit(TouchFrame(deviceID: Sample.device.id, timestamp: Double(n) / 120, frameNumber: n, contacts: contacts))
    h.queue.sync {}
    h.queue.sync {}
  }

  var touchFrames: [LiveTouchFrame] { updates.value.compactMap(\.touches) }
  var decisions: [LiveDecision] { updates.value.flatMap(\.decisions) }
}

enum HoldSetup {
  static let corner = Zone.corner(.topLeft)
  static var config: EdgyConfig {
    var config = EdgyConfig.defaults
    config.defaultProfile.bindings.append(Binding(zone: corner, gesture: .longPress, action: "keyboard.hold"))
    return config
  }
  static let catalog = MachineCatalog.descriptors
  static func event(_ phase: GestureEvent.Phase) -> GestureEvent { Sample.event(corner, .longPress, phase: phase) }
}

@Suite struct LiveFeedTests {
  static let finger = FeedHarness.contact(1, x: 0.5, y: 0.5)

  @Test func touchesAreThrottledTo60HzOnTheDeviceClock() throws {
    let f = try FeedHarness()
    for _ in 0..<10 { f.frame([Self.finger]) }
    #expect(f.touchFrames.count == 5)
    let times = f.touchFrames.map(\.timestamp)
    #expect(zip(times, times.dropFirst()).allSatisfy { $1 - $0 >= Engine.feedTouchInterval - 1e-9 })
  }

  @Test func liftSendsOneEmptyFrameSoTheMirrorClears() throws {
    let f = try FeedHarness()
    f.frame([Self.finger])
    f.frame([])
    f.frame([])
    #expect(f.touchFrames.map(\.touches.count) == [1, 0])
  }

  @Test func hoveringContactsAreNotShown() throws {
    let f = try FeedHarness()
    var hover = Self.finger
    hover.state = .hovering
    f.frame([hover])
    #expect(f.updates.value.isEmpty)
  }

  @Test func touchStatesFollowClaimsAndStickyRejections() throws {
    let f = try FeedHarness()
    let a = FeedHarness.contact(1, x: 0.98, y: 0.5)
    let b = FeedHarness.contact(2, x: 0.5, y: 0.5)
    let c = FeedHarness.contact(3, x: 0.3, y: 0.3)
    f.frame([a, b, c], GestureOutput(claimedContactIDs: [1], rejections: [(2, .palm)]))
    f.frame([a, b, c], GestureOutput(claimedContactIDs: [1]))
    f.frame([a, b, c], GestureOutput(claimedContactIDs: [1]))
    let states = f.touchFrames.map { $0.touches.map(\.state) }
    #expect(states == [[.claimed, .rejected, .down], [.claimed, .rejected, .down]])
    #expect(f.touchFrames[0].touches[0].position == Point2D(x: 0.98, y: 0.5))
  }

  @Test func rejectionIsReportedOnceWithTheZoneItLandedIn() throws {
    let f = try FeedHarness()
    // Sample device is 160 × 100 mm; x 0.98 is 3.2 mm from the right edge (default strip 8 mm).
    let onRight = FeedHarness.contact(4, x: 0.98, y: 0.5)
    f.frame([onRight], GestureOutput(rejections: [(4, .typing)]))
    f.frame([onRight], GestureOutput(rejections: [(4, .typing)]))
    let middle = FeedHarness.contact(5, x: 0.5, y: 0.5)
    f.frame([middle], GestureOutput(rejections: [(5, .palm), (6, .startedOutsideZone)]))
    #expect(
      f.decisions == [
        .rejected(contactID: 4, zone: .edge(.right), reason: .typing, deviceID: Sample.device.id),
        .rejected(contactID: 5, zone: nil, reason: .palm, deviceID: Sample.device.id),
      ])
  }

  @Test func aRejectedFingerThatLiftsCanBeReportedAgainNextTime() throws {
    let f = try FeedHarness()
    f.frame([Self.finger], GestureOutput(rejections: [(1, .palm)]))
    f.frame([])
    f.frame([Self.finger], GestureOutput(rejections: [(1, .palm)]))
    #expect(f.decisions.count == 2)
  }

  @Test func decisionsAreNeverThrottled() throws {
    let f = try FeedHarness()
    let tap = Sample.event(.corner(.topRight), .doubleTap)
    for _ in 0..<4 { f.frame([Self.finger], GestureOutput(events: [tap])) }
    #expect(f.decisions.filter { if case .recognized = $0 { return true } else { return false } }.count == 4)
    #expect(f.decisions.filter { if case .actionRan = $0 { return true } else { return false } }.count == 4)
    #expect(f.touchFrames.count == 2)
  }

  @Test func recognizedAndRanAreMappedFromOutputAndRouter() throws {
    let f = try FeedHarness()
    let slide = Zone.edge(.right)
    f.frame(
      [],
      GestureOutput(events: [
        Sample.event(slide, .slide, phase: .began), Sample.event(slide, .slide, phase: .changed, delta: 0.1),
      ]))
    f.frame([], GestureOutput(events: [Sample.event(slide, .slide, phase: .ended)]))
    f.frame([], GestureOutput(events: [Sample.event(.edge(.top), .tap)]))
    let id = Sample.device.id
    #expect(
      f.decisions == [
        .recognized(zone: slide, kind: .slide, phase: .began, deviceID: id),
        .actionRan("audio.volume", zone: slide, kind: .slide),
        .recognized(zone: slide, kind: .slide, phase: .ended, deviceID: id),
        // Unbound gestures are still recognized; nothing runs.
        .recognized(zone: .edge(.top), kind: .tap, phase: .ended, deviceID: id),
      ])
  }

  @Test func failuresAndUnavailableActionsAreReported() throws {
    let f = try FeedHarness()
    let mute = Zone.corner(.topRight)
    f.h.actions.errorToThrow = ActionError.unavailable("audio.mute", reason: "no output device")
    f.frame([], GestureOutput(events: [Sample.event(mute, .doubleTap)]))
    f.h.actions.errorToThrow = ActionError.missingParameter("audio.mute", name: "x")
    f.frame([], GestureOutput(events: [Sample.event(mute, .doubleTap)]))
    let actionDecisions = f.decisions.filter { if case .recognized = $0 { return false } else { return true } }
    #expect(actionDecisions.count == 2)
    #expect(
      actionDecisions[0] == .actionUnavailable("audio.mute", zone: mute, kind: .doubleTap, reason: "no output device"))
    guard case .actionFailed("audio.mute", mute, .doubleTap, let message) = actionDecisions[1] else {
      Issue.record("expected actionFailed, got \(actionDecisions[1])")
      return
    }
    #expect(message.contains("missingParameter"))
  }

  @Test func noObserverMeansNoFeedWork() throws {
    let f = try FeedHarness(observe: false)
    f.frame([Self.finger], GestureOutput(events: [Sample.event(.edge(.top), .tap)], rejections: [(1, .palm)]))
    f.h.queue.sync {
      #expect(!f.h.engine.feed.isActive)
      #expect(f.h.engine.feed.decisions.isEmpty)
      #expect(f.h.engine.feed.landing.isEmpty)
      #expect(f.h.engine.feed.rejected.isEmpty)
    }
    #expect(f.updates.value.isEmpty)
  }

  @Test func removingTheLastObserverStopsAndClearsTheFeed() throws {
    let f = try FeedHarness()
    f.frame([Self.finger], GestureOutput(rejections: [(1, .palm)]))
    let before = f.updates.value.count
    f.h.engine.removeFeedObserver(try #require(f.token))
    f.frame([Self.finger], GestureOutput(events: [Sample.event(.corner(.topRight), .doubleTap)]))
    #expect(f.updates.value.count == before)
    f.h.queue.sync {
      #expect(f.h.engine.feed.rejected.isEmpty && f.h.engine.feed.lastSent.isEmpty)
    }
    // The action still ran: the feed only observes.
    #expect(f.h.actions.performed.map(\.id) == ["audio.mute"])
  }

  @Test func everyObserverGetsEachUpdate() throws {
    let f = try FeedHarness()
    let second = Locked(0)
    f.h.engine.observeFeed(on: f.h.queue) { _ in second.value += 1 }
    f.frame([Self.finger])
    #expect(f.updates.value.count == 1)
    #expect(second.value == 1)
  }

  @Test func pausedEngineFeedsNothing() throws {
    let f = try FeedHarness()
    f.h.engine.pause()
    f.frame([Self.finger], GestureOutput(rejections: [(1, .palm)]))
    #expect(f.updates.value.isEmpty)
  }
}

@Suite struct FeedZoneGeometryTests {
  let device = Sample.device  // 160 × 100 mm
  let settings = GestureSettings.defaults  // edge 8 mm, corner 12 mm

  func zone(_ x: Double, _ y: Double, _ enabled: Set<Zone>) -> Zone? {
    LiveFeedState.zone(at: Point2D(x: x, y: y), device: device, settings: settings, enabled: enabled)
  }

  @Test func mappedCornerWinsInsideItsSquare() {
    #expect(zone(0.02, 0.98, [.corner(.topLeft), .edge(.left)]) == .corner(.topLeft))
    // An unmapped corner falls through to the edge strip.
    #expect(zone(0.02, 0.98, [.edge(.left)]) == .edge(.left))
  }

  @Test func segmentsSplitAlongTheEdge() {
    let thirds: Set<Zone> = [.edge(.bottom, segment: 0, segments: 3), .edge(.bottom, segment: 2, segments: 3)]
    #expect(zone(0.2, 0.02, thirds) == .edge(.bottom, segment: 0, segments: 3))
    #expect(zone(0.5, 0.02, thirds) == nil)
    #expect(zone(0.9, 0.02, thirds) == .edge(.bottom, segment: 2, segments: 3))
  }

  @Test func outsideEveryStripIsNoZone() {
    #expect(zone(0.5, 0.5, [.edge(.left), .edge(.right), .edge(.top), .edge(.bottom)]) == nil)
  }
}

@Suite struct TestModeTests {
  @Test func testModeRunsNothingButReportsAndTicks() throws {
    let f = try FeedHarness()
    f.h.engine.setTestMode(true)
    let mute = Zone.corner(.topRight)
    f.frame([], GestureOutput(events: [Sample.event(mute, .doubleTap)]))
    #expect(f.h.actions.performed.isEmpty)
    #expect(f.h.actions.feedbacks == [.gestureCaught])
    #expect(f.decisions.last == .wouldRun("audio.mute", zone: mute, kind: .doubleTap))
  }

  @Test func testModeSlideTicksAndReportsOncePerSlide() throws {
    let f = try FeedHarness()
    f.h.engine.setTestMode(true)
    let right = Zone.edge(.right)
    f.frame([], GestureOutput(events: [Sample.event(right, .slide, phase: .began)]))
    for _ in 0..<5 { f.frame([], GestureOutput(events: [Sample.event(right, .slide, phase: .changed, delta: 0.05)])) }
    f.frame([], GestureOutput(events: [Sample.event(right, .slide, phase: .ended)]))
    #expect(f.h.actions.performed.isEmpty)
    #expect(f.h.actions.feedbacks == [.gestureCaught])
    #expect(f.decisions.filter { if case .wouldRun = $0 { return true } else { return false } }.count == 1)
  }

  @Test func testModeHoldPressesAndReleasesNothing() throws {
    let f = try FeedHarness(config: HoldSetup.config, catalog: HoldSetup.catalog)
    f.h.engine.setTestMode(true)
    f.frame([], GestureOutput(events: [HoldSetup.event(.began)]))
    f.frame([], GestureOutput(events: [HoldSetup.event(.ended)]))
    #expect(f.h.actions.performed.isEmpty)
    #expect(f.h.actions.feedbacks == [.gestureCaught])
    #expect(f.decisions.contains(.wouldRun("keyboard.hold", zone: HoldSetup.corner, kind: .longPress)))
  }

  @Test func turningTestModeOnMidHoldReleasesTheHeldKey() throws {
    let h = try EngineHarness(config: HoldSetup.config, catalog: HoldSetup.catalog)
    h.step(GestureOutput(events: [HoldSetup.event(.began)]))
    h.engine.setTestMode(true)
    h.step(GestureOutput(events: [HoldSetup.event(.ended)]))
    #expect(h.actions.performed.map(\.input) == [.press(down: true), .press(down: false)])
  }

  @Test func turningTestModeOffMidHoldIsSafe() throws {
    let h = try EngineHarness(config: HoldSetup.config, catalog: HoldSetup.catalog)
    h.engine.setTestMode(true)
    h.step(GestureOutput(events: [HoldSetup.event(.began)], claimedContactIDs: [1]))
    h.engine.setTestMode(false)
    h.step(GestureOutput(events: [HoldSetup.event(.ended)]))
    // No down was sent in Test Mode, so no up may follow; the recognizer was reset and the
    // pointer guard is not held (batch 20: a begun hold never holds it; was ["engage", "release"]).
    #expect(h.actions.performed.isEmpty)
    #expect(h.recognizer.resetCount == 2)
    #expect(h.guardCalls == [])
  }

  @Test func turningTestModeOffMidSlideDoesNotResumeIt() throws {
    let h = try EngineHarness()
    let right = Zone.edge(.right)
    h.engine.setTestMode(true)
    h.step(GestureOutput(events: [Sample.event(right, .slide, phase: .began)]))
    h.engine.setTestMode(false)
    h.step(GestureOutput(events: [Sample.event(.corner(.topRight), .doubleTap)]))
    #expect(h.actions.performed.map(\.id) == ["audio.mute"])
  }

  @Test func testModeIsInStatusAndNotPersistedInConfig() throws {
    let h = try EngineHarness()
    let seen = Locked<[Bool]>([])
    h.engine.onStatusChange { seen.value.append($0.testMode) }
    h.engine.setTestMode(true)
    h.engine.setTestMode(true)
    #expect(h.engine.status.testMode)
    #expect(h.engine.isTestMode)
    h.engine.apply(.defaults)
    #expect(h.engine.isTestMode)
    h.engine.setTestMode(false)
    #expect(seen.value == [true, false])
  }

  @Test func testModeSurvivesARegistrySwap() throws {
    let h = try EngineHarness()
    h.engine.setTestMode(true)
    let swapped = FakeActions()
    h.engine.replaceActions(swapped)
    h.step(GestureOutput(events: [Sample.event(.corner(.topRight), .doubleTap)]))
    #expect(swapped.performed.isEmpty)
    #expect(swapped.feedbacks == [.gestureCaught])
  }
}
