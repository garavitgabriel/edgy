import EdgyCore
import Foundation
import Testing

@testable import EdgyRuntime

@Suite struct RouterTests {
  let actions = FakeActions()
  let logger = RecordingLogger()
  var router: Router { Router(actions: actions, logger: logger) }

  static let appID = "com.example.player"
  static var config: EdgyConfig {
    var config = EdgyConfig.defaults
    config.appProfiles[appID] = Profile(bindings: [
      Binding(zone: .edge(.right), gesture: .slide, action: "display.brightness", parameters: ["sensitivity": "2"])
    ])
    config.appProfiles["com.example.game"] = Profile(
      bindings: [Binding(zone: .edge(.right), gesture: .slide, action: "audio.volume")], disabled: true)
    return config
  }

  @Test func defaultProfileUsedWhenNoAppProfileMatches() {
    router.route(
      Sample.event(.edge(.right), .slide, phase: .changed, delta: 0.1), config: Self.config,
      frontmostBundleID: "com.example.other")

    #expect(actions.performed.map(\.id) == ["audio.volume"])
  }

  @Test func appProfileReplacesDefault() {
    router.route(
      Sample.event(.edge(.right), .slide, phase: .changed, delta: 0.1), config: Self.config,
      frontmostBundleID: Self.appID)

    #expect(actions.performed.map(\.id) == ["display.brightness"])
    #expect(actions.performed.first?.frontmostBundleID == Self.appID)
  }

  @Test func disabledProfileDropsEverything() {
    router.route(
      Sample.event(.edge(.right), .slide, phase: .changed, delta: 0.1), config: Self.config,
      frontmostBundleID: "com.example.game")

    #expect(actions.performed.isEmpty)
  }

  @Test func slideBecomesDeltaWithPhase() {
    let router = self.router
    for (phase, delta) in [(GestureEvent.Phase.began, 0.0), (.changed, 0.25), (.changed, -0.1), (.ended, 0.0)] {
      router.route(
        Sample.event(.edge(.right), .slide, phase: phase, delta: delta), config: .defaults, frontmostBundleID: nil)
    }

    #expect(
      actions.performed.map(\.input) == [
        .delta(0, phase: .began), .delta(0.25, phase: .changed), .delta(-0.1, phase: .changed),
        .delta(0, phase: .ended),
      ])
  }

  @Test func doubleTapBecomesExactlyOneTrigger() {
    let router = self.router
    // Recognizer that reports only the completed gesture.
    router.route(Sample.event(.corner(.topRight), .doubleTap, phase: .ended), config: .defaults, frontmostBundleID: nil)
    #expect(actions.performed.map(\.input) == [.trigger])
    #expect(actions.performed.map(\.id) == ["audio.mute"])

    // Recognizer that reports began + ended for one gesture: still a single trigger.
    router.route(
      Sample.event(.corner(.topLeft), .doubleTap, phase: .began), config: .defaults, frontmostBundleID: nil)
    router.route(
      Sample.event(.corner(.topLeft), .doubleTap, phase: .ended), config: .defaults, frontmostBundleID: nil)
    #expect(actions.performed.map(\.id) == ["audio.mute", "mic.mute"])
  }

  @Test func cancelledDiscreteGestureDoesNotFire() {
    router.route(
      Sample.event(.edge(.bottom), .doubleTap, phase: .cancelled), config: .defaults, frontmostBundleID: nil)

    #expect(actions.performed.isEmpty)
  }

  @Test func unmatchedGestureIsIgnored() {
    let router = self.router
    router.route(Sample.event(.edge(.top), .slide, phase: .changed), config: .defaults, frontmostBundleID: nil)
    router.route(Sample.event(.edge(.right), .longPress), config: .defaults, frontmostBundleID: nil)
    router.route(
      Sample.event(.edge(.right, segment: 1, segments: 2), .slide), config: .defaults, frontmostBundleID: nil)

    #expect(actions.performed.isEmpty)
    #expect(logger.errors.isEmpty)
  }

  @Test func bindingParametersAreForwarded() {
    var config = EdgyConfig.defaults
    config.defaultProfile.bindings.append(
      Binding(zone: .corner(.bottomLeft), gesture: .longPress, action: "shortcut.run", parameters: ["name": "Focus"]))

    router.route(Sample.event(.corner(.bottomLeft), .longPress), config: config, frontmostBundleID: "com.example.x")

    #expect(
      actions.performed == [
        PerformedAction(
          id: "shortcut.run", input: .trigger, frontmostBundleID: "com.example.x", parameters: ["name": "Focus"])
      ])
  }

  @Test func actionErrorIsSwallowedAndLogged() {
    actions.errorToThrow = ActionError.unavailable("display.brightness", reason: "no built-in display")

    router.route(
      Sample.event(.edge(.left), .slide, phase: .changed, delta: 0.1), config: .defaults, frontmostBundleID: nil)

    #expect(actions.performed.count == 1)
    #expect(logger.errors.count == 1)
    #expect(logger.errors.first?.contains("display.brightness") == true)
  }
}
