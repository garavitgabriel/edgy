import Actions
import EdgyCore
import EdgyRuntime
import Foundation
import Testing

@testable import EdgyUI

/// The real catalog (reading it performs nothing).
@MainActor let overlayCatalog: [ActionID: ActionDescriptor] = Dictionary(
  makeLiveActionRegistry(settings: .defaults).available.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

@MainActor
func plate(
  _ decision: LiveDecision, context: PlateContext = PlateContext(), dryRun: Bool = false
) -> PlateContent? {
  PlateContent.from(decision, catalog: overlayCatalog, context: context, dryRun: dryRun)
}

@MainActor
func rejectionText(
  _ reason: RejectionReason, _ measure: RejectionMeasure?, zone: Zone? = .edge(.right),
  context: PlateContext = PlateContext()
) -> String? {
  plate(.rejected(contactID: 1, zone: zone, reason: reason, deviceID: 1, measure: measure), context: context)?.title
}

// MARK: Numbers

@Test func numbersUseOneDecimalOnlyUnderTenAndNotWhole() {
  #expect(PlateNumber.text(3.0) == "3")
  #expect(PlateNumber.text(2.5) == "2.5")
  #expect(PlateNumber.text(3.42) == "3.4")
  #expect(PlateNumber.text(9.96) == "10")
  #expect(PlateNumber.text(21.3) == "21")
  #expect(PlateNumber.text(410.4) == "410")
  #expect(PlateNumber.percent(0.64) == "64%")
  #expect(PlateNumber.percent(1.2) == "100%")
}

// MARK: Rejections: BRIEF bone 4's table, row by row

@MainActor @Suite struct RejectionCopyTests {
  @Test func palmMajorAxis() {
    #expect(rejectionText(.palm, .init(measured: 21, limit: 18, unit: .mm)) == "Ignored: palm, 21 mm wide, limit 18 mm")
  }

  @Test func palmMinorAxisRoundContact() {
    #expect(
      rejectionText(.palm, .init(measured: 15, limit: 14, unit: .mm)) == "Ignored: palm, 15 mm across, limit 14 mm")
  }

  @Test func palmFollowsTheConfiguredMajorLimit() {
    let context = PlateContext(palmMajorAxisMM: 22)
    #expect(
      rejectionText(.palm, .init(measured: 24, limit: 22, unit: .mm), context: context)
        == "Ignored: palm, 24 mm wide, limit 22 mm")
  }

  @Test func palmSizeOnlyHasNoNumber() {
    #expect(rejectionText(.palm, nil) == "Ignored: palm")
  }

  @Test func typing() {
    #expect(
      rejectionText(.typing, .init(measured: 200, limit: 500, unit: .ms))
        == "Ignored: typing, last key 200 ms ago, limit 500 ms")
  }

  @Test func tooManyContacts() {
    #expect(
      rejectionText(.tooManyContacts, .init(measured: 2, limit: 1, unit: .fingers)) == "Ignored: 2 fingers, set to 1")
  }

  @Test func offAxisCorner() {
    #expect(
      rejectionText(.offAxisMotion, .init(measured: 3.4, limit: 3, unit: .mm), zone: .corner(.topLeft))
        == "Ignored: moved 3.4 mm before the long-press, limit 3 mm")
  }

  @Test func offAxisEdgeOutward() {
    #expect(
      rejectionText(.offAxisMotion, .init(measured: 2.8, limit: 2.5, unit: .mm))
        == "Ignored: moved 2.8 mm toward the edge, limit 2.5 mm")
  }

  @Test func offAxisEdgeDiagonal() {
    #expect(
      rejectionText(.offAxisMotion, .init(measured: 3.4, limit: 3, unit: .mm))
        == "Ignored: no clear direction, moved 3.4 mm, limit 3 mm")
  }

  @Test func offAxisSwipeThatVeered() {
    #expect(
      rejectionText(.offAxisMotion, .init(measured: 9, limit: 5, unit: .mm), zone: .edge(.bottom))
        == "Ignored: swipe veered, 9 mm across, 5 mm along")
  }

  @Test func tooFastHeldTooLong() {
    #expect(
      rejectionText(.tooFast, .init(measured: 410, limit: 350, unit: .ms))
        == "Ignored: swipe too slow, 410 ms, limit 350 ms")
  }

  @Test func tooFastTooShort() {
    #expect(
      rejectionText(.tooFast, .init(measured: 4, limit: 6, unit: .mm)) == "Ignored: swipe too short, 4 mm, needs 6 mm")
  }

  @Test func tooFastNoClearAxis() {
    #expect(rejectionText(.tooFast, nil) == "Ignored: swipe had no clear direction")
  }

  @Test func systemGestureClickAndDisabledZone() {
    #expect(rejectionText(.systemGestureHandoff, nil) == "Ignored: system gesture")
    #expect(rejectionText(.physicalClick, nil) == "Ignored: click")
    #expect(rejectionText(.disabledZone, nil) == "Ignored: nothing mapped here")
  }

  @Test func edgyOffInThisApp() {
    let context = PlateContext(offInApp: "Huddle")
    #expect(rejectionText(.disabledZone, nil, context: context) == "Ignored: Edgy is off in Huddle")
  }

  @Test func startedOutsideAZoneIsNeverShown() {
    #expect(rejectionText(.startedOutsideZone, .init(measured: 25, limit: 8, unit: .mm)) == nil)
  }

  @Test func rejectionPlateIsOneLineWithTheStruckMark() throws {
    let content = try #require(plate(.rejected(contactID: 1, zone: .edge(.left), reason: .physicalClick, deviceID: 1)))
    #expect(content.mark == .rejected)
    #expect(content.detail == nil)
    #expect(content.zone == .edge(.left))
    #expect(content.isTestModeOnly)
  }

  @Test func offInAppComesFromTheFrontmostDisabledProfile() {
    let model = PreviewFixtures.model()
    model.frontmostBundleID = PreviewFixtures.huddle
    #expect(PlateContext.current(model: model).offInApp == "Huddle")
    model.frontmostBundleID = PreviewFixtures.wayfare
    #expect(PlateContext.current(model: model).offInApp == nil)
  }
}

// MARK: Runs

@MainActor @Suite struct RunCopyTests {
  @Test func volumeSlideWithTheSystemHUDIsATestModePlate() throws {
    let content = try #require(
      plate(
        .actionRan(
          BuiltInAction.volume, zone: .edge(.right), kind: .slide,
          outcome: ActionOutcome(level: 0.64, systemHUDShown: true))))
    #expect(content.kind == .ran)
    #expect(content.mark == .recognized)
    #expect(content.title == "Volume 64%")
    #expect(content.detail == "Right edge, slide")
  }

  @Test func externalBrightnessIsALevelPlateOnItsDisplay() throws {
    let content = try #require(
      plate(
        .actionUpdated(
          BuiltInAction.brightness, zone: .edge(.left), kind: .slide,
          outcome: ActionOutcome(level: 0.4, detail: "Desk 34"))))
    #expect(content.kind == .level)
    #expect(content.mark == .level(0.4))
    #expect(content.title == "Brightness 40%")
    #expect(content.detail == "Desk 34")
    #expect(content.displayName == "Desk 34")
    #expect(!content.isTestModeOnly)
  }

  @Test func keyboardBacklightLevelPlate() throws {
    let content = try #require(
      plate(
        .actionRan(
          BuiltInAction.keyboardBacklight, zone: .edge(.left), kind: .slide, outcome: ActionOutcome(level: 0.6))))
    #expect(content.kind == .level)
    #expect(content.title == "Keyboard 60%")
    #expect(content.detail == "Built-in keyboard")
    #expect(content.displayName == nil)
  }

  /// Critique 18 ruling 5: the keyboard plate names the device; an external keyboard by its name.
  @Test func keyboardPlateNamesAnExternalKeyboard() throws {
    let content = try #require(
      plate(
        .actionRan(
          BuiltInAction.keyboardBacklight, zone: .edge(.left), kind: .slide,
          outcome: ActionOutcome(level: 0.6, detail: "Studio Keys"))))
    #expect(content.title == "Keyboard 60%")
    #expect(content.detail == "Studio Keys")
  }

  @Test func noLevelPlateWhenTheSystemHUDShowed() throws {
    let content = try #require(
      plate(
        .actionRan(
          BuiltInAction.brightness, zone: .edge(.left), kind: .slide,
          outcome: ActionOutcome(level: 0.4, systemHUDShown: true))))
    #expect(content.kind == .ran)
    #expect(content.isTestModeOnly)
  }

  @Test func noLevelPlateInDryRun() throws {
    let content = try #require(
      plate(
        .actionRan(
          BuiltInAction.brightness, zone: .edge(.left), kind: .slide,
          outcome: ActionOutcome(level: 0.4, detail: "Desk 34")
        ), dryRun: true))
    #expect(content.kind != .level)
    #expect(plate(.displayCheckDue(key: "4c2d-7154-9", name: "Desk 34"), dryRun: true) == nil)
  }

  @Test func triggerUsesThePadSpelling() throws {
    let content = try #require(plate(.actionRan(BuiltInAction.playPause, zone: .edge(.bottom), kind: .doubleTap)))
    #expect(content.title == "Play/Pause")
    #expect(content.detail == "Bottom edge, double-tap")
  }

  @Test func parameterRunsNameWhatTheyDid() throws {
    let context = PlateContext(
      bindings: [
        Binding(
          zone: .corner(.bottomRight), gesture: .doubleTap, action: BuiltInAction.openApp,
          parameters: ["bundleID": "com.example.quillpad"]),
        Binding(
          zone: .edge(.top), gesture: .tap, action: BuiltInAction.keyboardShortcut, parameters: ["keys": "cmd+shift+4"]),
      ], appNames: ["com.example.quillpad": "Quillpad"])
    #expect(
      plate(.actionRan(BuiltInAction.openApp, zone: .corner(.bottomRight), kind: .doubleTap), context: context)?.title
        == "Opened Quillpad")
    #expect(
      plate(.actionRan(BuiltInAction.keyboardShortcut, zone: .edge(.top), kind: .tap), context: context)?.title
        == "Pressed ⇧⌘ 4")
  }

  @Test func splitEdgeNamesItsPart() {
    #expect(
      plate(.actionRan(BuiltInAction.mute, zone: .edge(.right, segment: 1, segments: 2), kind: .tap))?.detail
        == "Right edge, upper half, tap")
  }

  @Test func failuresSayTheActionDidNotRun() throws {
    let failed = try #require(
      plate(.actionFailed(BuiltInAction.mute, zone: .edge(.top), kind: .tap, message: "boom")))
    #expect(failed.title == "Mute didn't run")
    #expect(failed.mark == .none)
    let unavailable = try #require(
      plate(
        .actionUnavailable(
          BuiltInAction.keyboardBacklight, zone: .edge(.left), kind: .slide, reason: "Needs a backlit keyboard")))
    #expect(unavailable.title == "Keyboard Brightness can't run here")
    #expect(unavailable.detail == "Needs a backlit keyboard")
  }

  @Test func gesturePhasesHaveNoPlateOfTheirOwn() {
    #expect(plate(.recognized(zone: .edge(.right), kind: .slide, phase: .ended, deviceID: 1)) == nil)
  }
}

// MARK: Dry run ("Would…")

@MainActor @Suite struct DryRunCopyTests {
  let context = PlateContext(
    bindings: [
      Binding(
        zone: .corner(.bottomRight), gesture: .doubleTap, action: BuiltInAction.openApp,
        parameters: ["bundleID": "com.example.quillpad"]),
      Binding(
        zone: .edge(.bottom), gesture: .longPress, action: BuiltInAction.keyboardHold, parameters: ["keys": "fn"]),
    ], appNames: ["com.example.quillpad": "Quillpad"])

  @Test func continuous() throws {
    let content = try #require(plate(.wouldRun(BuiltInAction.volume, zone: .edge(.right), kind: .slide)))
    #expect(content.title == "Would set Volume")
    #expect(content.detail == "Right edge, slide")
    #expect(content.mark == .wouldRun)
  }

  @Test func trigger() {
    let content = plate(.wouldRun(BuiltInAction.playPause, zone: .edge(.bottom), kind: .doubleTap))
    #expect(content?.title == "Would run Play/Pause")
    #expect(content?.detail == "Bottom edge, double-tap")
  }

  @Test func withAParameter() {
    let content = plate(
      .wouldRun(BuiltInAction.openApp, zone: .corner(.bottomRight), kind: .doubleTap), context: context)
    #expect(content?.title == "Would open Quillpad")
    #expect(content?.detail == "Bottom-right corner, double-tap")
  }

  @Test func holdThenRelease() throws {
    let held = try #require(
      plate(.wouldRun(BuiltInAction.keyboardHold, zone: .edge(.bottom), kind: .longPress), context: context))
    #expect(held.title == "Would hold fn")
    #expect(held.detail == "Bottom edge, long-press")
    #expect(held.mark == .wouldRun)
    #expect(held.released(cancelled: false)?.title == "Would release fn")
  }

  @Test func rejectionIsUnchanged() {
    #expect(
      plate(
        .rejected(
          contactID: 1, zone: .edge(.right), reason: .palm, deviceID: 1,
          measure: .init(measured: 21, limit: 18, unit: .mm)), dryRun: true)?.title
        == "Ignored: palm, 21 mm wide, limit 18 mm")
  }
}

// MARK: Holds

@MainActor @Suite struct HoldCopyTests {
  @Test func holdingThenReleased() throws {
    let held = try #require(
      plate(
        .actionRan(
          BuiltInAction.keyboardHold, zone: .edge(.bottom), kind: .longPress, outcome: ActionOutcome(detail: "fn"))))
    #expect(held.kind == .holding)
    #expect(held.title == "Holding fn")
    #expect(held.detail == "Bottom edge, long-press")
    #expect(held.mark == .recognized)
    #expect(held.released(cancelled: false)?.title == "Released fn")
    #expect(held.released(cancelled: true)?.title == "Released fn, finger left the zone")
  }

  @Test func holdKeysFallBackToTheBinding() {
    let context = PlateContext(bindings: [
      Binding(
        zone: .edge(.bottom), gesture: .longPress, action: BuiltInAction.keyboardHold, parameters: ["keys": "ctrl+opt"])
    ])
    #expect(
      plate(.actionRan(BuiltInAction.keyboardHold, zone: .edge(.bottom), kind: .longPress), context: context)?.title
        == "Holding ⌃⌥")
  }

  @Test func onlyHoldsRelease() {
    let run = PlateContent(kind: .ran, mark: .recognized, title: "Mute")
    #expect(run.released(cancelled: false) == nil)
  }
}

@MainActor @Test func displayCheckPlate() throws {
  let content = try #require(plate(.displayCheckDue(key: "4c2d-7154-9", name: "Desk 34")))
  #expect(content.kind == .displayCheck(key: "4c2d-7154-9"))
  #expect(content.title == "Did this screen change brightness?")
  #expect(content.displayName == "Desk 34")
  #expect(!content.isTestModeOnly)
}
