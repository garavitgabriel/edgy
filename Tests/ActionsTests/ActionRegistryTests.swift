import EdgyCore
import Foundation
import Testing

@testable import Actions

// Every test here runs against recording mocks. Nothing touches real audio, display, media keys,
// HUD, haptics or Shortcuts.

@Suite struct DispatchTests {
  @Test func volumeSlideSetsOutputVolume() throws {
    let h = Harness()
    try h.slide("audio.volume", 0.25, phase: .began)
    #expect(h.audio.setVolumeCalls == [0.75])
    #expect(h.display.setCalls.isEmpty)
  }

  @Test func brightnessSlideSetsBrightness() throws {
    let h = Harness()
    try h.slide("display.brightness", -0.25, phase: .began)
    #expect(h.display.setCalls == [0.25])
    #expect(h.audio.setVolumeCalls.isEmpty)
  }

  @Test func muteTogglesOutputMute() throws {
    let h = Harness()
    try h.trigger("audio.mute")
    try h.trigger("audio.mute")
    #expect(h.audio.setMutedCalls == [true, false])
  }

  @Test func micMuteTogglesInputMute() throws {
    let h = Harness()
    try h.trigger("mic.mute")
    try h.trigger("mic.mute")
    #expect(h.audio.setInputMutedCalls == [true, false])
    #expect(h.audio.setMutedCalls.isEmpty)
  }

  @Test func mediaKeysDispatch() throws {
    let h = Harness()
    try h.trigger("media.playPause")
    try h.trigger("media.next")
    try h.trigger("media.previous")
    #expect(h.media.keys == [.playPause, .next, .previous])
  }

  @Test func shortcutRunsByName() throws {
    let h = Harness()
    try h.trigger("shortcut.run", ["name": "Focus Mode"])
    #expect(h.shortcuts.ran == ["Focus Mode"])
  }
}

@Suite struct ErrorTests {
  @Test func shortcutWithoutNameIsMissingParameter() {
    let h = Harness()
    #expect(throws: ActionError.missingParameter("shortcut.run", name: "name")) {
      try h.trigger("shortcut.run")
    }
    #expect(throws: ActionError.missingParameter("shortcut.run", name: "name")) {
      try h.trigger("shortcut.run", ["name": ""])
    }
    #expect(h.shortcuts.ran.isEmpty)
  }

  @Test func unknownIDIsUnknownAction() {
    let h = Harness()
    #expect(throws: ActionError.unknownAction("app.launch")) { try h.trigger("app.launch") }
    #expect(throws: ActionError.unknownAction("app.launch")) { try h.slide("app.launch", 0.1) }
  }

  @Test func triggerToContinuousIsWrongInputShape() {
    let h = Harness()
    #expect(throws: ActionError.wrongInputShape("audio.volume")) { try h.trigger("audio.volume") }
    #expect(throws: ActionError.wrongInputShape("display.brightness")) { try h.trigger("display.brightness") }
    #expect(h.audio.setVolumeCalls.isEmpty)
  }

  @Test func deltaToTriggerIsWrongInputShape() {
    let h = Harness()
    #expect(throws: ActionError.wrongInputShape("media.next")) { try h.slide("media.next", 0.1) }
    #expect(h.media.keys.isEmpty)
  }

  @Test func missingDisplayIsUnavailable() {
    let h = Harness()
    h.display.isAvailable = false
    #expect(throws: ActionError.unavailable("display.brightness", reason: "no built-in display")) {
      try h.slide("display.brightness", 0.1, phase: .began)
    }
    #expect(h.display.setCalls.isEmpty)
  }

  @Test func outputFailureIsUnavailable() {
    let h = Harness()
    h.audio.failure = OutputError("no default output device")
    #expect(throws: ActionError.unavailable("audio.volume", reason: "no default output device")) {
      try h.slide("audio.volume", 0.1, phase: .began)
    }
  }
}

@Suite struct ValueMappingTests {
  @Test func clampsAtTop() throws {
    let h = Harness()
    h.audio.volume = 0.9
    try h.slide("audio.volume", 0.5, phase: .began)
    try h.slide("audio.volume", 0.5)
    #expect(h.audio.setVolumeCalls == [1.0])
    #expect(h.audio.volume == 1.0)
  }

  @Test func clampsAtBottom() throws {
    let h = Harness()
    h.display.level = 0.1
    try h.slide("display.brightness", -0.5, phase: .began)
    try h.slide("display.brightness", -0.5)
    #expect(h.display.setCalls == [0.0])
  }

  @Test func sensitivityScalesDelta() throws {
    let h = Harness()
    try h.slide("audio.volume", 0.125, phase: .began, ["sensitivity": "2"])
    try h.slide("audio.volume", -0.125, ["sensitivity": "0.5"])
    #expect(h.audio.setVolumeCalls == [0.75, 0.6875])
  }

  @Test func invalidSensitivityFallsBackToDefault() throws {
    let h = Harness()
    try h.slide("audio.volume", 0.125, phase: .began, ["sensitivity": "loud"])
    #expect(h.audio.setVolumeCalls == [0.625])
  }

  @Test func slideAccumulatesWithinSession() throws {
    let h = Harness()
    try h.slide("audio.volume", 0.0625, phase: .began)
    h.audio.volume = 0.2  // the system re-quantizes; the slide keeps its own level
    try h.slide("audio.volume", 0.0625)
    try h.slide("audio.volume", 0.0625, phase: .ended)
    #expect(h.audio.setVolumeCalls == [0.5625, 0.625, 0.6875])
    // A new slide starts from the system value again.
    try h.slide("audio.volume", 0.0625, phase: .began)
    #expect(h.audio.setVolumeCalls.last == 0.75)
  }

  @Test func raisingVolumeWhileMutedUnmutes() throws {
    let h = Harness()
    h.audio.muted = true
    try h.slide("audio.volume", -0.0625, phase: .began)
    #expect(h.audio.setMutedCalls.isEmpty)
    try h.slide("audio.volume", 0.0625)
    #expect(h.audio.setMutedCalls == [false])
  }
}

@Suite struct HapticTests {
  @Test func tickOnEverySixteenthCrossed() throws {
    let h = Harness()
    try h.slide("audio.volume", 0.25, phase: .began)  // 0.5 → 0.75: four boundaries
    #expect(h.haptics.ticks == 4)
    // Small moves inside one step: nothing until the next boundary.
    try h.slide("audio.volume", 0.03)
    try h.slide("audio.volume", 0.03)
    #expect(h.haptics.ticks == 4)
    try h.slide("audio.volume", 0.03)  // 0.84 crosses 0.8125
    #expect(h.haptics.ticks == 5)
    try h.slide("audio.volume", -0.1)  // 0.84 → 0.74: crosses 0.8125 and 0.75
    #expect(h.haptics.ticks == 7)
    #expect(h.haptics.strongTicks == 0)
  }

  @Test func strongTickAtTopReplacesEndTick() throws {
    let h = Harness()
    h.audio.volume = 0.875
    try h.slide("audio.volume", 0.5, phase: .began)  // 0.875 → 1: boundaries 0.9375 and 1
    #expect(h.haptics.ticks == 1)
    #expect(h.haptics.strongTicks == 1)
    // Pushing past the end while pinned is silent.
    try h.slide("audio.volume", 0.2)
    #expect(h.haptics.ticks == 1)
    #expect(h.haptics.strongTicks == 1)
  }

  @Test func strongTickAtBottom() throws {
    let h = Harness()
    h.display.level = 0.1
    try h.slide("display.brightness", -0.5, phase: .began)  // 0.1 → 0: boundaries 0.0625 and 0
    #expect(h.haptics.ticks == 1)
    #expect(h.haptics.strongTicks == 1)
    try h.slide("display.brightness", -0.5)
    #expect(h.haptics.strongTicks == 1)
  }

  @Test func stepsAndLimitsAreSeparatePreferences() throws {
    var settings = AppSettings.defaults
    settings.hapticEvents = [.slideLimits]
    let h = Harness(settings: settings)
    h.audio.volume = 0.875
    try h.slide("audio.volume", 0.5, phase: .began)  // crosses 0.9375 and reaches 1
    #expect(h.haptics.ticks == 0)
    #expect(h.haptics.strongTicks == 1)
  }

  @Test func perBindingOverrideSilencesSlideHaptics() throws {
    let h = Harness()
    try h.slide("audio.volume", 0.25, phase: .began, ["haptics": "off"])
    #expect(h.haptics.ticks == 0 && h.haptics.strongTicks == 0)
  }

  @Test func gestureFeedbackFollowsPreferences() {
    var settings = AppSettings.defaults
    settings.hapticEvents = [.actionFired]
    let h = Harness(settings: settings)
    let context = ActionContext(frontmostBundleID: nil, parameters: [:])
    h.registry.feedback(.gestureCaught, context: context)
    #expect(h.haptics.ticks == 0)
    h.registry.feedback(.actionFired, context: context)
    #expect(h.haptics.strongTicks == 1)
    h.registry.apply(settings: .with(haptics: false))
    h.registry.feedback(.actionFired, context: context)
    #expect(h.haptics.strongTicks == 1)
  }

  @Test func strengthsComeFromSettingsAndApplyLive() throws {
    var settings = AppSettings.defaults
    settings.hapticTickStrength = 2
    settings.hapticClickStrength = 5
    let h = Harness(settings: settings)
    h.audio.volume = 0.875
    try h.slide("audio.volume", 0.5, phase: .began)  // one step tick (2) then the end bump (5)
    #expect(Set(h.haptics.strengths) == [2, 5])
    settings.hapticTickStrength = 4
    h.registry.apply(settings: settings)
    h.registry.feedback(.gestureCaught, context: ActionContext(frontmostBundleID: nil, parameters: [:]))
    #expect(h.haptics.strengths.last == 4)
  }

  @Test func noHapticsWhenDisabled() throws {
    let h = Harness(settings: .with(haptics: false))
    try h.slide("audio.volume", 0.5, phase: .began)
    #expect(h.haptics.ticks == 0)
    #expect(h.haptics.strongTicks == 0)
    #expect(h.audio.setVolumeCalls == [1.0])
  }

  @Test func levelStepRule() {
    #expect(
      LevelStep.apply(delta: 0.25, sensitivity: 1, to: 0.5) == LevelStep(level: 0.75, ticks: 4, strongTick: false))
    #expect(LevelStep.apply(delta: 0.01, sensitivity: 1, to: 0.99) == LevelStep(level: 1, ticks: 0, strongTick: true))
    #expect(LevelStep.apply(delta: -0.01, sensitivity: 1, to: 0.01) == LevelStep(level: 0, ticks: 0, strongTick: true))
    #expect(LevelStep.apply(delta: 1, sensitivity: 1, to: 0) == LevelStep(level: 1, ticks: 15, strongTick: true))
    #expect(LevelStep.apply(delta: -1, sensitivity: 1, to: 1) == LevelStep(level: 0, ticks: 15, strongTick: true))
    #expect(LevelStep.apply(delta: 0.5, sensitivity: 1, to: 1) == LevelStep(level: 1, ticks: 0, strongTick: false))
  }
}

@Suite struct HUDTests {
  @Test func nativeHUDShowsEachChange() throws {
    let h = Harness(settings: .with(hud: .native))
    h.audio.headphones = true
    try h.slide("audio.volume", 0.1, phase: .began)
    try h.slide("display.brightness", -0.1, phase: .began)
    #expect(
      h.hud.shown == [
        .init(kind: .volume(muted: false, headphones: true), level: 0.6),
        .init(kind: .brightness, level: 0.4),
      ])
  }

  @Test func nativeHUDShowsMute() throws {
    let h = Harness(settings: .with(hud: .native))
    try h.trigger("audio.mute")
    #expect(h.hud.shown == [.init(kind: .volume(muted: true, headphones: false), level: 0)])
  }

  @Test func noHUDWhenModeIsNone() throws {
    let h = Harness(settings: .with(hud: .none))
    try h.slide("audio.volume", 0.1, phase: .began)
    try h.slide("display.brightness", 0.1, phase: .began)
    try h.trigger("audio.mute")
    #expect(h.hud.shown.isEmpty)
    #expect(h.audio.setVolumeCalls == [0.6])
  }

  @Test func settingsChangesApplyLive() throws {
    let h = Harness(settings: .with(hud: .none))
    try h.slide("audio.volume", 0.1, phase: .began)
    h.registry.settings.hud = .native
    try h.slide("audio.volume", 0.1)
    #expect(h.hud.shown.count == 1)
  }

  @Test func noHUDWhenNothingChanges() throws {
    let h = Harness()
    h.audio.volume = 1
    try h.slide("audio.volume", 0.1, phase: .began)
    #expect(h.hud.shown.isEmpty)
    #expect(h.audio.setVolumeCalls.isEmpty)
  }
}

@Suite struct RegistryShapeTests {
  /// v0.1's eight actions keep their ids and shapes (and must stay in the catalog).
  @Test func availableKeepsTheOriginalEightActions() {
    let h = Harness()
    let shapes = Dictionary(uniqueKeysWithValues: h.registry.available.map { ($0.id.rawValue, $0.shape) })
    let original: [String: ActionDescriptor.Shape] = [
      "audio.volume": .continuous,
      "audio.mute": .trigger,
      "display.brightness": .continuous,
      "mic.mute": .trigger,
      "media.playPause": .trigger,
      "media.next": .trigger,
      "media.previous": .trigger,
      "shortcut.run": .trigger,
    ]
    for (id, shape) in original { #expect(shapes[id] == shape, "\(id)") }
    #expect(h.registry.available.allSatisfy { !$0.displayName.isEmpty })
  }
}

/// Guard: the registry under test is wired to mocks only, and no test source builds a live registry.
@Suite struct NoLiveOutputsGuard {
  @Test func testRegistryHoldsOnlyMocks() {
    let r = Harness().registry
    #expect(r.audio is MockAudioOutput)
    #expect(r.display is MockBrightnessOutput)
    #expect(r.media is MockMediaKeyOutput)
    #expect(r.hud is MockHUDOutput)
    #expect(r.haptics is MockHapticOutput)
    #expect(r.shortcuts is MockShortcutRunner)
    #expect(r.keyboard is MockKeyboardOutput)
    #expect(r.workspace is MockWorkspaceOutput)
    #expect(r.windows is MockWindowOutput)
    #expect(r.system is MockSystemOutput)
  }

  @Test func noTestSourceCallsTheLiveFactory() throws {
    let dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
      .filter { $0.pathExtension == "swift" }
    #expect(!files.isEmpty)
    let banned = [
      "makeLive" + "ActionRegistry", "Live" + "AudioOutput", "Live" + "HUDOutput", "Live" + "KeyboardOutput",
      "Live" + "WorkspaceOutput", "Live" + "WindowOutput", "Live" + "SystemOutput", "Live" + "MediaKeyOutput",
      "Live" + "BrightnessOutput", "Live" + "HapticOutput", "Live" + "ShortcutRunner",
    ]
    for file in files {
      let text = try String(contentsOf: file, encoding: .utf8)
      for word in banned {
        #expect(!text.contains(word), "\(file.lastPathComponent) references \(word)")
      }
    }
  }
}
