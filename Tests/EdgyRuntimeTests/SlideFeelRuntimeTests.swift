import EdgyCore
import Foundation
import Testing

@testable import EdgyRuntime

// Batch 20 in the runtime: slide motion to actions, per-binding hold time, the pointer guard
// released once a hold has begun, the `slideAndSwipes` note, and legacy `step`.

/// Records every context it is handed.
private final class MotionRecorder: ActionPerforming {
  var available: [ActionDescriptor] = [
    ActionDescriptor(id: "audio.volume", shape: .continuous, displayName: "Volume", category: .sound),
    ActionDescriptor(id: "media.next", shape: .trigger, displayName: "Next Track", category: .media),
  ]
  private(set) var contexts: [ActionContext] = []
  func perform(_ id: ActionID, input: ActionInput, context: ActionContext) throws { contexts.append(context) }
}

private let right = Zone.edge(.right)

private func config(_ bindings: [Binding]) -> EdgyConfig {
  var config = EdgyConfig.defaults
  config.defaultProfile.bindings = bindings
  config.appProfiles = [:]
  return config
}

@Suite struct RouterMotionTests {
  @Test func slidesCarryTheirMotionInMillimetres() {
    let actions = MotionRecorder()
    let router = Router(actions: actions, logger: RecordingLogger())
    let cfg = config([Binding(zone: right, gesture: .slide, action: "audio.volume")])
    let event = GestureEvent(
      zone: right, kind: .slide, fingers: 1, phase: .changed, delta: 0.05, position: 0.5, timestamp: 12.5,
      deviceID: 7, zoneLengthMM: 120, atEnd: 0)
    router.route(event, config: cfg, frontmostBundleID: nil)
    var resting = event
    resting.delta = 0
    resting.atEnd = 1
    router.route(resting, config: cfg, frontmostBundleID: nil)
    #expect(
      actions.contexts.map(\.motion) == [
        SlideMotion(deltaMM: 6, timestamp: 12.5, atEnd: 0), SlideMotion(deltaMM: 0, timestamp: 12.5, atEnd: 1),
      ])
  }

  @Test func discreteGesturesAndUnknownLengthsCarryNoMotion() {
    let actions = MotionRecorder()
    let router = Router(actions: actions, logger: RecordingLogger())
    let cfg = config([
      Binding(zone: right, gesture: .slide, action: "audio.volume"),
      Binding(zone: right, gesture: .tap, action: "media.next"),
    ])
    router.route(Sample.event(right, .tap), config: cfg, frontmostBundleID: nil)
    router.route(Sample.event(right, .slide, phase: .changed, delta: 0.1), config: cfg, frontmostBundleID: nil)
    #expect(actions.contexts.count == 2)
    #expect(actions.contexts.allSatisfy { $0.motion == nil })
  }
}

@Suite struct HoldTimeTests {
  static let catalog = [
    ActionDescriptor(
      id: "keyboard.hold", shape: .hold, displayName: "Hold Keys", category: .keyboard,
      parameters: [
        ActionParameter(key: "keys", kind: .keyCombo, required: true, displayName: "Keys"),
        ActionParameter(
          key: "holdMS", kind: .number(100...1500), required: false, defaultValue: "300",
          displayName: "Hold before it starts"),
      ]),
    ActionDescriptor(id: "media.next", shape: .trigger, displayName: "Next Track", category: .media),
  ]

  @Test func holdKeysUsesItsOwnDefault() {
    let profile = Profile(bindings: [Binding(zone: right, gesture: .longPress, action: "keyboard.hold")])
    #expect(Engine.longPressTimes(in: profile, catalog: Self.catalog) == [right: 300])
  }

  @Test func aBindingsHoldMSWins() {
    let profile = Profile(bindings: [
      Binding(zone: right, gesture: .longPress, action: "keyboard.hold", parameters: ["holdMS": "180"]),
      Binding(zone: .corner(.topLeft), gesture: .longPress, action: "media.next", parameters: ["holdMS": "900"]),
    ])
    #expect(Engine.longPressTimes(in: profile, catalog: Self.catalog) == [right: 180, .corner(.topLeft): 900])
  }

  @Test func otherLongPressesKeepTheGlobalTimeUnlessSet() {
    let unset = Profile(bindings: [Binding(zone: right, gesture: .longPress, action: "media.next")])
    #expect(Engine.longPressTimes(in: unset, catalog: Self.catalog) == nil)
    let bad = Profile(bindings: [
      Binding(zone: right, gesture: .longPress, action: "media.next", parameters: ["holdMS": "5"])
    ])
    #expect(Engine.longPressTimes(in: bad, catalog: Self.catalog) == nil)
    let tap = Profile(bindings: [
      Binding(zone: right, gesture: .tap, action: "media.next", parameters: ["holdMS": "300"])
    ])
    #expect(Engine.longPressTimes(in: tap, catalog: Self.catalog) == nil)
  }

  @Test func aDisabledProfileHasNoHoldTimes() {
    let profile = Profile(
      bindings: [Binding(zone: right, gesture: .longPress, action: "keyboard.hold")], disabled: true)
    #expect(Engine.longPressTimes(in: profile, catalog: Self.catalog) == nil)
  }

  @Test func theEngineHandsTheTimesToTheRecognizer() throws {
    let h = try EngineHarness(
      config: config([Binding(zone: right, gesture: .longPress, action: "keyboard.hold", parameters: ["keys": "fn"])]),
      catalog: Self.catalog)
    h.step()
    #expect(h.recognizer.contexts.last?.longPressMSByZone == [right: 300])
  }
}

@Suite struct HoldPointerGuardTests {
  static let hold = HoldSample.event

  @Test func aSlideClaimStillEngagesTheGuard() throws {
    let h = try EngineHarness()
    h.step(GestureOutput(claimedContactIDs: [1]))
    h.step(GestureOutput())
    #expect(h.guardCalls == ["engage", "release"])
  }

  @Test func theGuardIsReleasedTheFrameAHoldBegins() throws {
    // A dwell claim (guard on), then the hold begins on the same, still finger: guard off, and it
    // stays off for the rest of the hold while the touch is still claimed.
    let h = try EngineHarness(config: HoldSample.config, catalog: HoldSample.catalog)
    h.step(GestureOutput(claimedContactIDs: [1]))
    h.step(GestureOutput(events: [Self.hold(.began)], claimedContactIDs: [1]))
    h.step(GestureOutput(claimedContactIDs: [1]))
    #expect(h.guardCalls == ["engage", "release"])
    h.step(GestureOutput(claimedContactIDs: [1]))
    h.step(GestureOutput(events: [Self.hold(.ended)]))
    #expect(h.guardCalls == ["engage", "release"])
  }

  @Test func theNextClaimAfterTheHoldEngagesAgain() throws {
    let h = try EngineHarness(config: HoldSample.config, catalog: HoldSample.catalog)
    h.step(GestureOutput(events: [Self.hold(.began)], claimedContactIDs: [1]))
    h.step(GestureOutput(events: [Self.hold(.cancelled)]))
    h.step(GestureOutput(claimedContactIDs: [2]))
    #expect(h.guardCalls == ["engage"])
  }

  @Test func aResetForgetsAHeldPress() throws {
    let h = try EngineHarness(config: HoldSample.config, catalog: HoldSample.catalog)
    h.step(GestureOutput(events: [Self.hold(.began)], claimedContactIDs: [1]))
    h.engine.pause()
    h.engine.resume()
    // The recognizer was reset with the hold open; the next claim must still engage the guard.
    h.step(GestureOutput(claimedContactIDs: [3]))
    #expect(h.guardCalls == ["engage"])
  }
}

@Suite struct SlideAndSwipesNoteTests {
  let validator = ConfigValidator(catalog: FakeCatalog.descriptors)

  func notes(_ bindings: [Binding]) -> [ValidationIssue] {
    validator.validate(config(bindings)).filter { $0.code == .slideAndSwipes }
  }

  @Test func aSlideAndASwipeOnOneEdgeGetANoteOnTheSwipe() {
    let found = notes([
      Binding(zone: right, gesture: .slide, action: "audio.volume"),
      Binding(zone: right, gesture: .swipe(.up), action: "media.next"),
    ])
    #expect(found.count == 1)
    #expect(found.first?.severity == .info)
    #expect(found.first?.binding == BindingKey(zone: right, gesture: .swipe(.up)))
  }

  @Test func overlappingSegmentsCountAndSeparateEdgesDoNot() {
    #expect(
      notes([
        Binding(zone: .edge(.right, segment: 1, segments: 2), gesture: .slide, action: "audio.volume"),
        Binding(zone: right, gesture: .swipe(.down), action: "media.next"),
      ]).count == 1)
    #expect(
      notes([
        Binding(zone: .edge(.right, segment: 0, segments: 2), gesture: .slide, action: "audio.volume"),
        Binding(zone: .edge(.right, segment: 1, segments: 2), gesture: .swipe(.down), action: "media.next"),
      ]).isEmpty)
    #expect(
      notes([
        Binding(zone: .edge(.left), gesture: .slide, action: "audio.volume"),
        Binding(zone: right, gesture: .swipe(.down), action: "media.next"),
      ]).isEmpty)
  }

  @Test func doNothingDoesNotCount() {
    #expect(
      notes([
        Binding(zone: right, gesture: .slide, action: .doNothing),
        Binding(zone: right, gesture: .swipe(.up), action: "media.next"),
      ]).isEmpty)
  }
}

@Suite struct BatchTwentyParameterValidationTests {
  let validator = ConfigValidator(
    catalog: FakeCatalog.descriptors + [
      ActionDescriptor(id: "apps.switcher", shape: .continuous, displayName: "Switch Apps", category: .apps)
    ])

  func issues(_ binding: Binding) -> [ValidationIssue] { validator.validate(binding, in: .default) }

  @Test func aLegacyStepIsNeverUnknown() {
    #expect(issues(Binding(zone: right, gesture: .slide, action: "apps.switcher", parameters: ["step": "0.1"])).isEmpty)
  }

  @Test func holdMSIsCheckedOnLongPresses() {
    let ok = Binding(zone: right, gesture: .longPress, action: "media.next", parameters: ["holdMS": "300"])
    let tooLong = Binding(zone: right, gesture: .longPress, action: "media.next", parameters: ["holdMS": "9000"])
    #expect(issues(ok).isEmpty)
    #expect(issues(tooLong).map(\.code) == [.numberOutOfRange])
  }

  @Test func holdMSOnATapIsUnknown() {
    let tap = Binding(zone: right, gesture: .tap, action: "media.next", parameters: ["holdMS": "300"])
    #expect(issues(tap).map(\.code) == [.unknownParameter])
  }

  @Test func thePressTimeSpecIsBriefsCopy() {
    let spec = ConfigValidator.pressTimeParameter
    #expect(spec.displayName == "Press time")
    #expect(spec.helpText == "How long to press before it runs.")
    #expect(spec.unit == "ms")
    #expect(spec.fallback == .longPressMS)
    #expect(spec.kind == .number(100...1500))
  }
}
