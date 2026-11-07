import EdgyCore
import Foundation
import Testing

@testable import EdgyRuntime

/// A push-to-talk style binding: hold the bottom-left corner to hold a key.
enum HoldSample {
  static let holdID: ActionID = "keyboard.hold"
  static let zone = Zone.corner(.bottomLeft)
  static let catalog = [
    ActionDescriptor(id: holdID, shape: .hold, displayName: "Hold Keys", category: .keyboard),
    ActionDescriptor(id: "shortcut.run", shape: .trigger, displayName: "Run Shortcut", category: .shortcuts),
  ]
  static let parameters = ["keys": "fn"]
  static let otherApp = "com.example.other"

  static var config: EdgyConfig {
    var config = EdgyConfig.defaults
    config.defaultProfile.bindings.append(
      Binding(zone: zone, gesture: .longPress, action: holdID, parameters: parameters))
    // Another app whose profile neither binds the hold nor is enabled.
    config.appProfiles[otherApp] = Profile(bindings: [], disabled: true)
    return config
  }

  static func event(_ phase: GestureEvent.Phase) -> GestureEvent {
    Sample.event(zone, .longPress, phase: phase)
  }

  static let down = PerformedAction(
    id: holdID, input: .press(down: true), frontmostBundleID: nil, parameters: parameters)
  static let up = PerformedAction(
    id: holdID, input: .press(down: false), frontmostBundleID: nil, parameters: parameters)
}

@Suite struct RouterHoldTests {
  let actions = FakeActions()
  let logger = RecordingLogger()

  func makeRouter() -> Router {
    actions.available = HoldSample.catalog
    return Router(actions: actions, logger: logger)
  }

  @Test func holdPressesAtBeganAndReleasesAtLift() {
    let router = makeRouter()
    router.route(HoldSample.event(.began), config: HoldSample.config, frontmostBundleID: nil)
    #expect(actions.performed == [HoldSample.down])
    #expect(actions.feedbacks == [.actionFired])
    #expect(router.hasPendingHolds)
    router.route(HoldSample.event(.ended), config: HoldSample.config, frontmostBundleID: nil)
    #expect(actions.performed == [HoldSample.down, HoldSample.up])
    #expect(actions.feedbacks == [.actionFired])
    #expect(!router.hasPendingHolds)
  }

  @Test func cancelledHoldReleases() {
    let router = makeRouter()
    router.route(HoldSample.event(.began), config: HoldSample.config, frontmostBundleID: nil)
    router.route(HoldSample.event(.cancelled), config: HoldSample.config, frontmostBundleID: nil)
    #expect(actions.performed == [HoldSample.down, HoldSample.up])
  }

  @Test func resetReleasesAndTheLaterLiftDoesNothing() {
    let router = makeRouter()
    router.route(HoldSample.event(.began), config: HoldSample.config, frontmostBundleID: nil)
    router.reset()
    #expect(actions.performed == [HoldSample.down, HoldSample.up])
    router.route(HoldSample.event(.ended), config: HoldSample.config, frontmostBundleID: nil)
    #expect(actions.performed == [HoldSample.down, HoldSample.up])
    #expect(logger.errors.isEmpty)
  }

  @Test func liftUnderAnotherProfileReleasesWithTheOriginalContext() {
    // The frontmost app changed mid-hold to one whose profile is disabled and binds nothing.
    let router = makeRouter()
    router.route(HoldSample.event(.began), config: HoldSample.config, frontmostBundleID: nil)
    router.route(HoldSample.event(.ended), config: HoldSample.config, frontmostBundleID: HoldSample.otherApp)
    #expect(actions.performed == [HoldSample.down, HoldSample.up])
  }

  @Test func liftAfterTheBindingWasRemovedStillReleases() {
    let router = makeRouter()
    router.route(HoldSample.event(.began), config: HoldSample.config, frontmostBundleID: nil)
    router.route(HoldSample.event(.ended), config: .defaults, frontmostBundleID: nil)
    #expect(actions.performed == [HoldSample.down, HoldSample.up])
  }

  @Test func replacingTheRegistryReleasesOnTheOldOne() {
    let router = makeRouter()
    router.route(HoldSample.event(.began), config: HoldSample.config, frontmostBundleID: nil)
    let replacement = FakeActions()
    replacement.available = HoldSample.catalog
    router.replaceActions(replacement)
    #expect(actions.performed == [HoldSample.down, HoldSample.up])
    router.route(HoldSample.event(.ended), config: HoldSample.config, frontmostBundleID: nil)
    #expect(replacement.performed.isEmpty)
  }

  @Test func failedPressIsStillReleased() {
    let router = makeRouter()
    actions.errorToThrow = ActionError.unavailable(HoldSample.holdID, reason: "test")
    router.route(HoldSample.event(.began), config: HoldSample.config, frontmostBundleID: nil)
    router.route(HoldSample.event(.ended), config: HoldSample.config, frontmostBundleID: nil)
    #expect(actions.performed.map(\.input) == [.press(down: true), .press(down: false)])
    #expect(actions.feedbacks.isEmpty)
    #expect(logger.errors.count == 2)
  }

  @Test func secondBeganWithoutAnEndReleasesTheFirst() {
    let router = makeRouter()
    router.route(HoldSample.event(.began), config: HoldSample.config, frontmostBundleID: nil)
    router.route(HoldSample.event(.began), config: HoldSample.config, frontmostBundleID: nil)
    router.route(HoldSample.event(.ended), config: HoldSample.config, frontmostBundleID: nil)
    #expect(
      actions.performed.map(\.input) == [
        .press(down: true), .press(down: false), .press(down: true), .press(down: false),
      ])
  }

  @Test func triggerOnLongPressFiresOnceAtBeganNotAtLift() {
    let router = makeRouter()
    var config = EdgyConfig.defaults
    config.defaultProfile.bindings.append(
      Binding(zone: .corner(.bottomRight), gesture: .longPress, action: "shortcut.run", parameters: ["name": "Focus"]))
    for phase in [GestureEvent.Phase.began, .ended] {
      router.route(
        Sample.event(.corner(.bottomRight), .longPress, phase: phase), config: config, frontmostBundleID: nil)
    }
    #expect(actions.performed.map(\.input) == [.trigger])
    #expect(!router.hasPendingHolds)
  }

  @Test func holdActionOnAnotherGestureIsRefused() {
    let router = makeRouter()
    var config = EdgyConfig.defaults
    config.defaultProfile.bindings.append(
      Binding(zone: .corner(.bottomRight), gesture: .tap, action: HoldSample.holdID))
    router.route(Sample.event(.corner(.bottomRight), .tap), config: config, frontmostBundleID: nil)
    #expect(actions.performed.isEmpty)
    #expect(logger.errors.count == 1)
  }
}

/// Every engine path that drops in-flight gestures must send the pending `down: false`.
@Suite struct EngineHoldPairingTests {
  func harness() throws -> EngineHarness {
    try EngineHarness(config: HoldSample.config, catalog: HoldSample.catalog)
  }

  func began(_ h: EngineHarness) {
    h.step(GestureOutput(events: [HoldSample.event(.began)], claimedContactIDs: [1]))
    #expect(h.actions.performed == [HoldSample.down])
  }

  @Test func normalLift() throws {
    let h = try harness()
    began(h)
    h.step(GestureOutput(claimedContactIDs: [1]))
    h.step(GestureOutput(events: [HoldSample.event(.ended)]))
    #expect(h.actions.performed == [HoldSample.down, HoldSample.up])
    #expect(h.guardCalls == ["engage", "release"])
  }

  @Test func cancelled() throws {
    let h = try harness()
    began(h)
    h.step(GestureOutput(events: [HoldSample.event(.cancelled)]))
    #expect(h.actions.performed == [HoldSample.down, HoldSample.up])
  }

  @Test func pauseReleases() throws {
    let h = try harness()
    began(h)
    h.engine.pause()
    #expect(h.actions.performed == [HoldSample.down, HoldSample.up])
    h.engine.resume()
    h.step(GestureOutput(events: [HoldSample.event(.ended)]))
    #expect(h.actions.performed == [HoldSample.down, HoldSample.up])
  }

  @Test func configReloadReleases() throws {
    let h = try harness()
    began(h)
    h.engine.apply(HoldSample.config)
    #expect(h.actions.performed == [HoldSample.down, HoldSample.up])
    #expect(h.recognizer.resetCount == 1)
  }

  @Test func frontmostAppChangeReleasesBeforeTheNextFrameIsRouted() throws {
    let h = try harness()
    began(h)
    h.step(GestureOutput(claimedContactIDs: [1]))
    #expect(h.actions.performed == [HoldSample.down])
    h.frontmost.bundleID.value = HoldSample.otherApp
    h.step(GestureOutput(claimedContactIDs: [1]))
    #expect(h.actions.performed == [HoldSample.down, HoldSample.up])
    h.step(GestureOutput(events: [HoldSample.event(.ended)]))
    #expect(h.actions.performed == [HoldSample.down, HoldSample.up])
  }

  @Test func frontmostAppChangeWithoutAHoldDoesNothing() throws {
    let h = try harness()
    h.step()
    h.frontmost.bundleID.value = HoldSample.otherApp
    h.step()
    #expect(h.actions.performed.isEmpty)
  }

  @Test func stopReleases() throws {
    let h = try harness()
    began(h)
    h.engine.stop()
    #expect(h.actions.performed == [HoldSample.down, HoldSample.up])
    #expect(h.guardCalls == ["engage", "release"])
  }

  @Test func replacingActionsReleasesOnTheOldRegistry() throws {
    let h = try harness()
    began(h)
    let replacement = FakeActions()
    replacement.available = HoldSample.catalog
    h.engine.replaceActions(replacement)
    #expect(h.actions.performed == [HoldSample.down, HoldSample.up])
    #expect(replacement.performed.isEmpty)
  }
}
