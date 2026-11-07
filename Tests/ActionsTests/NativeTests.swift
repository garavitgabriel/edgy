import CoreGraphics
import Displays
import EdgyCore
import Foundation
import Testing

@testable import Actions

// v0.3: native level keys, display routing, availability, and the new actions. Every test runs
// against recording mocks: no key events, level changes, display writes or window moves reach the
// real system.

private let external = DisplayInfo(id: 7, name: "Desk Monitor", kind: .thirdParty, brightnessControllable: true)
private let stubborn = DisplayInfo(
  id: 9, name: "Old Monitor", kind: .thirdParty, brightnessControllable: false,
  reason: "Old Monitor doesn't answer brightness requests over its cable.")
private let panel = DisplayInfo(id: 1, name: "Built-in Display", kind: .builtIn, brightnessControllable: true)

@Suite struct FineStepTests {
  @Test func upSlideIsFineVolumeUpPresses() throws {
    let h = Harness(settings: .with(hud: .native), levelKeys: true)
    try h.slide("audio.volume", 0.25, phase: .began)  // 0.5 → 0.75: 16 fine steps
    #expect(h.levelKeys.presses == [.init(key: .volumeUp, count: 16, fine: true)])
  }

  @Test func downSlideIsFineVolumeDownPresses() throws {
    let h = Harness(settings: .with(hud: .native), levelKeys: true)
    try h.slide("audio.volume", -0.125, phase: .began)  // 0.5 → 0.375: 8 fine steps
    #expect(h.levelKeys.presses == [.init(key: .volumeDown, count: 8, fine: true)])
  }

  @Test func sensitivityScalesFineSteps() throws {
    let h = Harness(settings: .with(hud: .native), levelKeys: true)
    try h.slide("audio.volume", 0.125, phase: .began, ["sensitivity": "2"])
    try h.slide("audio.volume", -0.125, ["sensitivity": "0.5"])
    #expect(
      h.levelKeys.presses == [
        .init(key: .volumeUp, count: 16, fine: true), .init(key: .volumeDown, count: 4, fine: true),
      ])
  }

  @Test func partialStepsAccumulateAcrossUpdates() throws {
    let h = Harness(settings: .with(hud: .native), levelKeys: true)
    try h.slide("audio.volume", 0.01, phase: .began)  // 32.64/64: no boundary yet
    #expect(h.levelKeys.presses.isEmpty)
    for _ in 0..<3 { try h.slide("audio.volume", 0.01) }  // 33.28, 33.92, 34.56
    #expect(h.levelKeys.netFineSteps == 2)
  }

  @Test func reversingPressesTheOtherKey() throws {
    let h = Harness(settings: .with(hud: .native), levelKeys: true)
    try h.slide("audio.volume", 0.25, phase: .began)
    try h.slide("audio.volume", -0.25)
    #expect(h.levelKeys.presses.map(\.key) == [.volumeUp, .volumeDown])
    #expect(h.levelKeys.netFineSteps == 0)
  }

  @Test func fineStepRule() {
    #expect(FineSteps.presses(from: 0.5, to: 0.75) == 16)
    #expect(FineSteps.presses(from: 0.75, to: 0.5) == -16)
    #expect(FineSteps.presses(from: 0.5, to: 0.51) == 0)
    #expect(FineSteps.presses(from: 0.51, to: 0.52) == 1)
    #expect(FineSteps.presses(from: 0.9, to: 1) == 7)
    #expect(FineSteps.presses(from: 0.1, to: 0) == -7)
    #expect(FineSteps.perRange == 64)
    #expect(FineSteps.perTick == 4)
    #expect(FineSteps.perRange / Double(FineSteps.perTick) == LevelStep.steps)
  }

  @Test func oneTickPerFourFineSteps() throws {
    let h = Harness(settings: .with(hud: .native), levelKeys: true)
    try h.slide("audio.volume", 0.25, phase: .began)
    #expect(h.levelKeys.netFineSteps == 16)
    #expect(h.haptics.ticks == 16 / FineSteps.perTick)
    #expect(h.haptics.strongTicks == 0)
  }

  @Test func limitClickAtTop() throws {
    let h = Harness(settings: .with(hud: .native), levelKeys: true)
    h.audio.volume = 0.9  // the start level is read back through CoreAudio
    try h.slide("audio.volume", 0.5, phase: .began)
    #expect(h.levelKeys.presses == [.init(key: .volumeUp, count: 7, fine: true)])
    #expect(h.haptics.strongTicks == 1)
    #expect(h.haptics.ticks == 1)  // 15/16 crossed; the 16/16 tick became the click
  }

  @Test func limitClickAtBottom() throws {
    let h = Harness(settings: .with(hud: .native), levelKeys: true)
    h.audio.volume = 0.1
    try h.slide("audio.volume", -0.5, phase: .began)
    #expect(h.levelKeys.presses == [.init(key: .volumeDown, count: 7, fine: true)])
    #expect(h.haptics.strongTicks == 1)
  }

  @Test func nothingWhenAlreadyPinned() throws {
    let h = Harness(settings: .with(hud: .native), levelKeys: true)
    h.audio.volume = 1
    try h.slide("audio.volume", 0.2, phase: .began)
    try h.slide("audio.volume", 0.2)
    #expect(h.levelKeys.presses.isEmpty)
    #expect(h.haptics.ticks == 0 && h.haptics.strongTicks == 0)
  }

  @Test func keyPathNeverSetsLevelsOrShowsTheLegacyHUD() throws {
    let h = Harness(settings: .with(hud: .native), levelKeys: true)
    try h.slide("audio.volume", 0.25, phase: .began)
    try h.slide("display.brightness", -0.25, phase: .began)
    #expect(h.audio.setVolumeCalls.isEmpty)
    #expect(h.display.setCalls.isEmpty)
    #expect(h.hud.shown.isEmpty)
  }

  @Test func builtInBrightnessIsFineBrightnessPresses() throws {
    let h = Harness(settings: .with(hud: .native), levelKeys: true)
    try h.slide("display.brightness", 0.125, phase: .began)
    try h.slide("display.brightness", -0.25)
    #expect(
      h.levelKeys.presses == [
        .init(key: .brightnessUp, count: 8, fine: true), .init(key: .brightnessDown, count: 16, fine: true),
      ])
  }
}

@Suite struct LevelFallbackTests {
  @Test func keysFailingFallsBackToCoreAudioAndLegacyHUD() throws {
    let h = Harness(settings: .with(hud: .native), levelKeys: false)
    try h.slide("audio.volume", 0.25, phase: .began)
    #expect(h.audio.setVolumeCalls == [0.75])
    #expect(h.hud.shown == [.init(kind: .volume(muted: false, headphones: false), level: 0.75)])
  }

  @Test func keysFailingMidSlideFallsBackFromTheSessionLevel() throws {
    let h = Harness(settings: .with(hud: .native), levelKeys: true)
    try h.slide("audio.volume", 0.125, phase: .began)
    h.levelKeys.works = false
    try h.slide("audio.volume", 0.125)
    #expect(h.levelKeys.netFineSteps == 8)
    #expect(h.audio.setVolumeCalls == [0.75])
  }

  @Test func hudNoneSetsVolumeSilentlyWithoutKeys() throws {
    let h = Harness(settings: .with(hud: .none), levelKeys: true)
    try h.slide("audio.volume", 0.25, phase: .began)
    #expect(h.levelKeys.presses.isEmpty)
    #expect(h.audio.setVolumeCalls == [0.75])
    #expect(h.hud.shown.isEmpty)
  }

  @Test func hudNoneSetsBrightnessSilentlyWithoutKeys() throws {
    let h = Harness(settings: .with(hud: .none), levelKeys: true)
    try h.slide("display.brightness", 0.25, phase: .began)
    #expect(h.levelKeys.presses.isEmpty)
    #expect(h.display.setCalls == [0.75])
    #expect(h.hud.shown.isEmpty)
  }

  @Test func muteUsesTheMuteKey() throws {
    let h = Harness(settings: .with(hud: .native), levelKeys: true)
    try h.trigger("audio.mute")
    #expect(h.levelKeys.presses == [.init(key: .mute, count: 1, fine: false)])
    #expect(h.audio.setMutedCalls.isEmpty)
    #expect(h.hud.shown.isEmpty)
  }

  @Test func muteFallsBackWhenTheKeyFails() throws {
    let h = Harness(settings: .with(hud: .native), levelKeys: false)
    try h.trigger("audio.mute")
    #expect(h.audio.setMutedCalls == [true])
    #expect(h.hud.shown == [.init(kind: .volume(muted: true, headphones: false), level: 0)])
  }

  @Test func muteWithHUDNoneIsSilentCoreAudio() throws {
    let h = Harness(settings: .with(hud: .none), levelKeys: true)
    try h.trigger("audio.mute")
    #expect(h.levelKeys.presses.isEmpty)
    #expect(h.audio.setMutedCalls == [true])
    #expect(h.hud.shown.isEmpty)
  }
}

@Suite struct BrightnessRoutingTests {
  @Test func builtInActiveUsesTheBuiltInPath() throws {
    let h = Harness(settings: .with(hud: .native), levelKeys: true)
    h.displays.list = [panel, external]
    h.displays.active = panel.id
    try h.slide("display.brightness", 0.125, phase: .began)
    #expect(h.levelKeys.presses == [.init(key: .brightnessUp, count: 8, fine: true)])
    #expect(h.displays.setCalls.isEmpty)
  }

  @Test func controllableExternalGoesThroughDisplays() throws {
    let h = Harness(settings: .with(hud: .native), levelKeys: true)
    h.displays.list = [external]
    h.displays.active = external.id
    h.displays.levels[external.id] = 0.5
    try h.slide("display.brightness", 0.25, phase: .began)
    try h.slide("display.brightness", 0.5)
    #expect(h.displays.setCalls == [0.75, 1.0])
    #expect(h.displays.setTargets == [7, 7])
    #expect(h.haptics.ticks == 4 + 3)
    #expect(h.haptics.strongTicks == 1)
    #expect(h.levelKeys.presses.isEmpty)
    #expect(h.display.setCalls.isEmpty)
    #expect(h.hud.shown.isEmpty)
  }

  @Test func notControllableIsUnavailableWithTheDisplaysReason() {
    let h = Harness()
    h.displays.list = [panel, stubborn]
    h.displays.active = stubborn.id
    #expect(throws: ActionError.unavailable("display.brightness", reason: stubborn.reason!)) {
      try h.slide("display.brightness", 0.1, phase: .began)
    }
    #expect(h.display.setCalls.isEmpty)
    #expect(h.displays.setCalls.isEmpty)
  }

  @Test func notControllableWithoutReasonNamesTheDisplay() {
    let h = Harness()
    h.displays.list = [DisplayInfo(id: 3, name: "Projector", kind: .thirdParty, brightnessControllable: false)]
    h.displays.active = 3
    #expect(
      throws: ActionError.unavailable("display.brightness", reason: "Projector doesn't accept brightness control")
    ) {
      try h.slide("display.brightness", 0.1, phase: .began)
    }
  }

  @Test func targetIsKeptForTheWholeSlide() throws {
    let h = Harness(settings: .with(hud: .native), levelKeys: true)
    h.displays.list = [panel, external]
    h.displays.active = external.id
    h.displays.levels[external.id] = 0.5
    try h.slide("display.brightness", 0.125, phase: .began)
    h.displays.active = panel.id  // pointer moves to the laptop mid-slide
    try h.slide("display.brightness", 0.125)
    #expect(h.displays.setTargets == [7, 7])
    #expect(h.levelKeys.presses.isEmpty)
    // The next slide starts on the display now under the pointer.
    try h.slide("display.brightness", 0.125, phase: .began)
    #expect(h.levelKeys.presses.map(\.key) == [.brightnessUp])
  }

  @Test func unknownActiveDisplayFallsBackToTheBuiltInPanel() throws {
    let h = Harness()
    h.displays.active = nil
    try h.slide("display.brightness", 0.25, phase: .began)
    #expect(h.display.setCalls == [0.75])
    h.display.isAvailable = false
    #expect(throws: ActionError.unavailable("display.brightness", reason: "no built-in display")) {
      try h.slide("display.brightness", 0.1, phase: .began)
    }
  }

  @Test func builtInPanelUnreachableLocallyGoesThroughDisplays() throws {
    let h = Harness()
    h.display.isAvailable = false
    h.displays.list = [panel]
    h.displays.active = panel.id
    h.displays.levels[panel.id] = 0.5
    try h.slide("display.brightness", 0.25, phase: .began)
    #expect(h.displays.setTargets == [panel.id])
  }

  @Test func displayErrorsSurfaceTheirReason() {
    let h = Harness()
    h.displays.list = [external]
    h.displays.active = external.id
    h.displays.failure = .failed(7, reason: "the monitor stopped answering")
    #expect(throws: ActionError.unavailable("display.brightness", reason: "the monitor stopped answering")) {
      try h.slide("display.brightness", 0.1, phase: .began)
    }
  }
}

@Suite struct AvailabilityTests {
  typealias Copy = ActionRegistry.AvailabilityCopy

  /// Every catalog id on a MacBook (built-in panel, backlit keyboard, nothing plugged in).
  @Test func tableForEveryCatalogID() {
    let h = Harness()
    let limited: [String: String] = [
      "spaces.left": Copy.spaceLeft, "spaces.right": Copy.spaceRight, "system.lockScreen": Copy.lockScreen,
      "system.dictation": Copy.dictation,
    ]
    #expect(h.registry.available.count == 34)
    for descriptor in h.registry.available {
      let id = descriptor.id.rawValue
      let expected: ActionAvailability = limited[id].map { .limited(reason: $0) } ?? .available
      #expect(h.registry.availability(of: descriptor.id) == expected, "\(id)")
    }
    // Mission Control and friends ask the Dock directly: no shortcut caveat.
    #expect(h.registry.availability(of: "system.missionControl") == .available)
  }

  @Test func limitedCopyNamesTheShortcut() {
    #expect(Copy.spaceLeft.contains("Control–Left Arrow"))
    #expect(Copy.spaceRight.contains("Control–Right Arrow"))
    #expect(Copy.lockScreen.contains("Control–Command–Q"))
  }

  @Test func macWithoutDisplayOrBacklight() {
    let h = Harness()
    h.display.isAvailable = false
    h.backlight.isAvailable = false
    #expect(h.registry.availability(of: "display.brightness") == .unavailable(reason: Copy.noBrightnessNoMonitor))
    let noBacklight = ActionAvailability.unavailable(reason: ActionRegistry.noBacklightReason)
    #expect(h.registry.availability(of: "keyboard.backlight") == noBacklight)
    #expect(h.registry.availability(of: "keyboard.backlightToggle") == noBacklight)
    #expect(h.registry.availability(of: "audio.volume") == .available)
  }

  @Test func oneOrSeveralMonitorsThatRefuse() {
    let h = Harness()
    h.display.isAvailable = false
    h.displays.list = [stubborn]
    #expect(h.registry.availability(of: "display.brightness") == .unavailable(reason: Copy.noBrightnessOneMonitor))
    h.displays.list = [stubborn, DisplayInfo(id: 10, name: "TV", kind: .thirdParty, brightnessControllable: false)]
    #expect(h.registry.availability(of: "display.brightness") == .unavailable(reason: Copy.noBrightnessMonitors))
  }

  @Test func connectingAControllableMonitorFlipsTheCache() {
    let h = Harness()
    h.display.isAvailable = false
    #expect(!h.registry.availability(of: "display.brightness").isUsable)
    h.displays.list = [external]
    #expect(h.registry.availability(of: "display.brightness") == .available)
    h.displays.list = []
    #expect(!h.registry.availability(of: "display.brightness").isUsable)
  }

  @Test func mixedMonitorsAreLimitedByName() {
    let h = Harness()
    h.display.isAvailable = false
    h.displays.list = [external, stubborn]
    #expect(
      h.registry.availability(of: "display.brightness")
        == .limited(reason: "Works on Desk Monitor; Old Monitor doesn't accept brightness control."))
    h.display.isAvailable = true
    #expect(
      h.registry.availability(of: "display.brightness")
        == .limited(
          reason: "Works on the built-in display and Desk Monitor; Old Monitor doesn't accept brightness control."))
  }

  @Test func appleExternalCounts() {
    let h = Harness()
    h.display.isAvailable = false
    h.displays.list = [DisplayInfo(id: 4, name: "Studio", kind: .appleExternal, brightnessControllable: true)]
    #expect(h.registry.availability(of: "display.brightness") == .available)
  }

  @Test func unknownIDIsUnavailable() {
    #expect(Harness().registry.availability(of: "nope.nothing") == .unavailable(reason: Copy.unknownAction))
  }
}

@Suite struct AppSwitcherTests {
  static let id: ActionID = "apps.switcher"

  @Test func fullLifecycle() throws {
    let h = Harness()
    try h.slide(Self.id, 0, phase: .began)
    #expect(h.keyboard.events == ["cmd down", "cmd+tab down", "cmd+tab up"])
    #expect(h.keyboard.heldModifiers == [.cmd])
    try h.slide(Self.id, 0.25)  // two steps of 0.1 (0.05 carried)
    try h.slide(Self.id, -0.15)  // pays off the carry, then one step back
    try h.slide(Self.id, 0, phase: .ended)
    #expect(
      h.keyboard.events == [
        "cmd down", "cmd+tab down", "cmd+tab up",
        "cmd+tab down", "cmd+tab up", "cmd+tab down", "cmd+tab up",
        "shift+cmd+tab down", "shift+cmd+tab up",
        "cmd up",
      ])
    #expect(h.keyboard.allReleased)
  }

  @Test func cancelSendsEscapeThenReleases() throws {
    let h = Harness()
    try h.slide(Self.id, 0, phase: .began)
    try h.slide(Self.id, 0, phase: .cancelled)
    #expect(Array(h.keyboard.events.suffix(3)) == ["cmd+escape down", "cmd+escape up", "cmd up"])
    #expect(h.keyboard.allReleased)
  }

  @Test func newBeganWithoutEndCancelsTheOldSessionFirst() throws {
    let h = Harness()
    try h.slide(Self.id, 0, phase: .began)
    try h.slide(Self.id, 0, phase: .began)
    #expect(
      h.keyboard.events == [
        "cmd down", "cmd+tab down", "cmd+tab up",
        "cmd+escape down", "cmd+escape up", "cmd up",
        "cmd down", "cmd+tab down", "cmd+tab up",
      ])
    try h.slide(Self.id, 0, phase: .ended)
    #expect(h.keyboard.allReleased)
  }

  @Test func errorMidSlideReleasesTheModifier() throws {
    let h = Harness()
    try h.slide(Self.id, 0, phase: .began)
    h.keyboard.failOnEvent = "shift+cmd+tab down"
    #expect(throws: ActionError.unavailable(Self.id, reason: "key event failed")) {
      try h.slide(Self.id, -0.1)
    }
    #expect(h.keyboard.allReleased)
    #expect(h.keyboard.events.last == "cmd up")
    // The rest of that gesture does nothing; it can't re-press command.
    try h.slide(Self.id, 0.3)
    try h.slide(Self.id, 0, phase: .ended)
    #expect(h.keyboard.events.last == "cmd up")
    #expect(h.keyboard.allReleased)
  }

  @Test func errorOpeningTheSwitcherReleasesTheModifier() {
    let h = Harness()
    h.keyboard.failOnEvent = "cmd+tab down"
    #expect(throws: ActionError.unavailable(Self.id, reason: "key event failed")) {
      try h.slide(Self.id, 0, phase: .began)
    }
    #expect(h.keyboard.allReleased)
    #expect(h.keyboard.events == ["cmd down", "cmd+escape down", "cmd+escape up", "cmd up"])
  }

  @Test func commandFailingToGoDownLeavesNoSession() throws {
    let h = Harness()
    h.keyboard.failOnEvent = "cmd down"
    #expect(throws: ActionError.unavailable(Self.id, reason: "key event failed")) {
      try h.slide(Self.id, 0, phase: .began)
    }
    try h.slide(Self.id, 0.3)
    try h.slide(Self.id, 0, phase: .cancelled)
    #expect(h.keyboard.events.isEmpty)
    #expect(h.keyboard.allReleased)
  }

  @Test func badStepPressesNothing() {
    let h = Harness()
    #expect(throws: ActionError.missingParameter(Self.id, name: "step")) {
      try h.slide(Self.id, 0, phase: .began, ["step": "0.01"])
    }
    #expect(h.keyboard.events.isEmpty)
  }

  @Test func stepAndSensitivityScaleTravel() throws {
    let h = Harness()
    try h.slide(Self.id, 0, phase: .began, ["step": "0.2", "sensitivity": "2"])
    try h.slide(Self.id, 0.2, ["step": "0.2", "sensitivity": "2"])  // 0.4 of travel → two tabs
    #expect(h.keyboard.events.filter { $0 == "cmd+tab down" }.count == 3)
  }

  @Test func oneTickPerTab() throws {
    let h = Harness()
    try h.slide(Self.id, 0, phase: .began)
    try h.slide(Self.id, 0.3)
    #expect(h.haptics.ticks == 3)
  }

  @Test func updatesWithoutASessionDoNothing() throws {
    let h = Harness()
    try h.slide(Self.id, 0.5)
    try h.slide(Self.id, 0, phase: .ended)
    try h.slide(Self.id, 0, phase: .cancelled)
    #expect(h.keyboard.events.isEmpty)
  }

  @Test func triggerIsWrongInputShape() {
    #expect(throws: ActionError.wrongInputShape(Self.id)) { try Harness().trigger(Self.id) }
  }
}

@Suite struct HoldKeyTests {
  static let id: ActionID = "keyboard.hold"
  static let keys = ["keys": "opt+ctrl+space"]

  @Test func downPressesModifiersThenKeyAndUpReleasesInReverse() throws {
    let h = Harness()
    try h.press(Self.id, down: true, Self.keys)
    #expect(h.keyboard.events == ["ctrl down", "opt down", "ctrl+opt+space down"])
    #expect(h.keyboard.heldKeys == ["space"])
    try h.press(Self.id, down: false, Self.keys)
    #expect(
      h.keyboard.events == [
        "ctrl down", "opt down", "ctrl+opt+space down", "ctrl+opt+space up", "opt up", "ctrl up",
      ])
    #expect(h.keyboard.allReleased)
  }

  @Test func secondDownReleasesFirst() throws {
    let h = Harness()
    try h.press(Self.id, down: true, ["keys": "f13"])
    try h.press(Self.id, down: true, ["keys": "f14"])
    #expect(h.keyboard.events == ["f13 down", "f13 up", "f14 down"])
    try h.press(Self.id, down: false)
    #expect(h.keyboard.allReleased)
  }

  @Test func upWithoutDownDoesNothing() throws {
    let h = Harness()
    try h.press(Self.id, down: false, Self.keys)
    #expect(h.keyboard.events.isEmpty)
  }

  @Test func upNeverNeedsTheParameters() throws {
    let h = Harness()
    try h.press(Self.id, down: true, Self.keys)
    try h.press(Self.id, down: false, ["keys": "cmd+banana"])
    #expect(h.keyboard.allReleased)
  }

  @Test func missingKeysOnDownHoldsNothing() {
    let h = Harness()
    #expect(throws: ActionError.missingParameter(Self.id, name: "keys")) {
      try h.press(Self.id, down: true)
    }
    #expect(h.keyboard.events.isEmpty)
  }

  @Test func failureDuringDownReleasesWhatWentDown() {
    let h = Harness()
    h.keyboard.failOnEvent = "ctrl+opt+space down"
    #expect(throws: ActionError.unavailable(Self.id, reason: "key event failed")) {
      try h.press(Self.id, down: true, Self.keys)
    }
    #expect(h.keyboard.allReleased)
    #expect(h.keyboard.events.suffix(2) == ["opt up", "ctrl up"])
  }

  @Test func wrongShapesAreRejected() {
    let h = Harness()
    #expect(throws: ActionError.wrongInputShape(Self.id)) { try h.trigger(Self.id, Self.keys) }
    #expect(throws: ActionError.wrongInputShape(Self.id)) { try h.slide(Self.id, 0.1, phase: .began, Self.keys) }
    #expect(throws: ActionError.wrongInputShape("audio.mute")) { try h.press("audio.mute", down: true) }
    #expect(throws: ActionError.wrongInputShape("audio.volume")) { try h.press("audio.volume", down: true) }
    #expect(h.keyboard.events.isEmpty)
  }
}

@Suite struct DictationTests {
  @Test func togglesDictation() throws {
    let h = Harness()
    try h.trigger("system.dictation")
    try h.trigger("system.dictation")
    #expect(h.dictation.toggles == 2)
  }

  @Test func failureIsUnavailable() {
    let h = Harness()
    h.dictation.failure = OutputError("no permission")
    #expect(throws: ActionError.unavailable("system.dictation", reason: "no permission")) {
      try h.trigger("system.dictation")
    }
  }
}

@Suite struct KeyboardBacklightTests {
  @Test func slideMapsTheLevelWithHaptics() throws {
    let h = Harness()
    try h.slide("keyboard.backlight", 0.25, phase: .began)
    try h.slide("keyboard.backlight", 0.5)
    #expect(h.backlight.setCalls == [0.75, 1.0])
    #expect(h.haptics.ticks == 4 + 3)
    #expect(h.haptics.strongTicks == 1)
    #expect(h.hud.shown.isEmpty)
  }

  @Test func toggleRemembersTheLastNonZeroLevel() throws {
    let h = Harness()
    h.backlight.current = 0.3
    try h.trigger("keyboard.backlightToggle")
    #expect(h.backlight.current == 0)
    try h.trigger("keyboard.backlightToggle")
    #expect(h.backlight.setCalls == [0, 0.3])
  }

  @Test func slidesUpdateTheToggleMemory() throws {
    let h = Harness()
    try h.slide("keyboard.backlight", 0.25, phase: .began)  // 0.75
    try h.slide("keyboard.backlight", -1, phase: .changed)  // off
    try h.trigger("keyboard.backlightToggle")
    #expect(h.backlight.current == 0.75)
  }

  @Test func toggleOnWithNothingRememberedUsesTheDefault() throws {
    let h = Harness()
    h.backlight.current = 0
    try h.trigger("keyboard.backlightToggle")
    #expect(h.backlight.current == ActionRegistry.defaultBacklightLevel)
  }

  @Test func noBacklightIsUnavailable() {
    let h = Harness()
    h.backlight.isAvailable = false
    let error = ActionError.unavailable("keyboard.backlight", reason: ActionRegistry.noBacklightReason)
    #expect(throws: error) { try h.slide("keyboard.backlight", 0.1, phase: .began) }
    #expect(throws: ActionError.unavailable("keyboard.backlightToggle", reason: ActionRegistry.noBacklightReason)) {
      try h.trigger("keyboard.backlightToggle")
    }
    #expect(h.backlight.setCalls.isEmpty)
  }
}

@Suite struct FullScreenSnapTests {
  static let leftHalf = CGRect(x: 0, y: 25, width: 720, height: 875)
  static let rightHalf = CGRect(x: 720, y: 25, width: 720, height: 875)

  @Test func normalWindowsSnapAtOnce() throws {
    let h = Harness()
    try h.trigger("window.leftHalf")
    #expect(h.windows.log == ["setFrame"])
    #expect(h.waiter.waits == 0)
  }

  @Test func exitThenWaitThenSnap() throws {
    let h = Harness()
    h.windows.enterFullScreen()
    try h.trigger("window.leftHalf")
    #expect(h.windows.log == ["exitFullScreen"])
    #expect(h.waiter.waits == 1)
    #expect(h.waiter.pending.first?.timeout == ActionRegistry.fullScreenExitTimeout)
    // Still animating: polling doesn't finish the wait.
    #expect(!h.waiter.poll())
    #expect(h.windows.setFrames.isEmpty)
    h.windows.finishLeavingFullScreen()
    #expect(h.waiter.poll())
    #expect(h.windows.log == ["exitFullScreen", "setFrame"])
    // Snapped on the desktop Space's visible frame, not the full-screen one.
    #expect(h.windows.setFrames == [Self.leftHalf])
  }

  @Test func timeoutDropsTheSnap() throws {
    let h = Harness()
    h.windows.enterFullScreen()
    try h.trigger("window.leftHalf")
    h.waiter.timeOut()
    #expect(h.windows.setFrames.isEmpty)
    // The next attempt starts over.
    try h.trigger("window.leftHalf")
    #expect(h.windows.log == ["exitFullScreen", "exitFullScreen"])
    #expect(h.waiter.waits == 2)
  }

  @Test func restoreGoesToTheFrameAfterFullScreenNotBackIntoIt() throws {
    let h = Harness()
    h.windows.enterFullScreen()
    try h.trigger("window.leftHalf")
    h.windows.finishLeavingFullScreen()
    h.waiter.poll()
    try h.trigger("window.restore")
    #expect(h.windows.setFrames == [Self.leftHalf, h.windows.frameAfterFullScreen])
    #expect(h.windows.window?.isFullScreen == false)
    #expect(h.windows.log.filter { $0 == "exitFullScreen" }.count == 1)
  }

  @Test func minimizeExitsFirst() throws {
    let h = Harness()
    h.windows.enterFullScreen()
    try h.trigger("window.minimize")
    #expect(h.windows.minimized.isEmpty)
    h.windows.finishLeavingFullScreen()
    h.waiter.poll()
    #expect(h.windows.log == ["exitFullScreen", "minimize"])
  }

  @Test func aSecondSnapWhileLeavingReplacesTheFirst() throws {
    let h = Harness()
    h.windows.enterFullScreen()
    try h.trigger("window.leftHalf")
    try h.trigger("window.rightHalf")
    #expect(h.windows.log == ["exitFullScreen"])
    #expect(h.waiter.waits == 1)
    h.windows.finishLeavingFullScreen()
    h.waiter.poll()
    #expect(h.windows.setFrames == [Self.rightHalf])
  }

  @Test func windowGoneAfterTheWaitIsLoggedNotThrown() throws {
    let h = Harness()
    h.windows.enterFullScreen()
    try h.trigger("window.leftHalf")
    h.windows.finishLeavingFullScreen()
    let done = h.waiter.pending.first?.done
    h.windows.window = nil
    done?(true)
    #expect(h.windows.setFrames.isEmpty)
  }
}
