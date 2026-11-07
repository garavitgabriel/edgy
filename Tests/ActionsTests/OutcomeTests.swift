import Displays
import EdgyCore
import Testing

@testable import Actions

// `performReporting` outcomes and the honest-external-brightness rules. Mocks only.

private let desk = DisplayInfo(
  id: 7, name: "Desk 34", kind: .thirdParty, brightnessControllable: true, key: "4c2d-7154-9")
private let studio = DisplayInfo(
  id: 8, name: "Studio", kind: .appleExternal, brightnessControllable: true, key: "610-ae2e")

private func report(
  _ h: Harness, _ id: ActionID, _ input: ActionInput, _ parameters: [String: String] = [:]
) throws -> ActionOutcome? {
  try h.registry.performReporting(
    id, input: input, context: ActionContext(frontmostBundleID: nil, parameters: parameters))
}

/// A harness whose brightness slides land on `display` (the active display).
private func externalHarness(_ display: DisplayInfo = desk, settings: AppSettings = .defaults) -> Harness {
  let h = Harness(settings: settings)
  h.display.isAvailable = false
  h.displays.list = [display]
  h.displays.active = display.id
  h.displays.levels = [display.id: 0.5]
  return h
}

@Suite struct LevelOutcomeTests {
  @Test func volumeReportsTheLevelAfterTheChangeAndTheSystemHUD() throws {
    let h = Harness(levelKeys: true)
    h.audio.volume = 0.5
    let began = try report(h, "audio.volume", .delta(0, phase: .began))
    let changed = try report(h, "audio.volume", .delta(0.25, phase: .changed))
    #expect(began == ActionOutcome(level: 0.5, systemHUDShown: true))
    #expect(changed == ActionOutcome(level: 0.75, systemHUDShown: true))
  }

  @Test func volumeWithTheHUDOffReportsNoSystemHUD() throws {
    let h = Harness(settings: .with(hud: .none))
    h.audio.volume = 0.2
    _ = try report(h, "audio.volume", .delta(0, phase: .began))
    let outcome = try report(h, "audio.volume", .delta(-0.5, phase: .changed))
    #expect(outcome == ActionOutcome(level: 0, systemHUDShown: false))
  }

  @Test func pinnedVolumeStillReportsItsLevel() throws {
    let h = Harness(levelKeys: true)
    h.audio.volume = 1
    _ = try report(h, "audio.volume", .delta(0, phase: .began))
    #expect(try report(h, "audio.volume", .delta(0.3, phase: .changed))?.level == 1)
  }

  @Test func builtInBrightnessReportsLevelAndHUD() throws {
    let h = Harness(levelKeys: true)
    h.display.level = 0.4
    _ = try report(h, "display.brightness", .delta(0, phase: .began))
    let outcome = try report(h, "display.brightness", .delta(0.1, phase: .changed))
    #expect(outcome?.systemHUDShown == true)
    #expect(abs((outcome?.level ?? 0) - 0.5) < 1e-9)
    #expect(outcome?.detail == nil)
  }

  @Test func keyboardBacklightReportsLevelWithoutHUD() throws {
    let h = Harness()
    h.backlight.current = 0.6
    _ = try report(h, "keyboard.backlight", .delta(0, phase: .began))
    let outcome = try report(h, "keyboard.backlight", .delta(-0.2, phase: .changed))
    #expect(abs((outcome?.level ?? 0) - 0.4) < 1e-9)
    #expect(outcome?.systemHUDShown == false)
  }

  @Test func externalBrightnessNamesTheDisplay() throws {
    var settings = AppSettings.defaults
    settings.confirmedDisplays = [desk.key]
    let h = externalHarness(settings: settings)
    _ = try report(h, "display.brightness", .delta(0, phase: .began))
    let outcome = try report(h, "display.brightness", .delta(0.25, phase: .changed))
    #expect(outcome == ActionOutcome(level: 0.75, detail: "Desk 34", systemHUDShown: false))
  }

  @Test func appleExternalDisplayIsNeverChecked() throws {
    let h = externalHarness(studio)
    let outcome = try report(h, "display.brightness", .delta(0, phase: .began))
    #expect(outcome?.detail == "Studio")
  }

  @Test func plainPerformStillWorksAndReportsNothingExtra() throws {
    let h = Harness()
    h.audio.volume = 0.5
    try h.slide("audio.volume", 0, phase: .began)
    try h.slide("audio.volume", 0.1)
    #expect(abs(h.audio.volume - 0.6) < 1e-9)
  }
}

@Suite struct OtherOutcomeTests {
  @Test func holdReportsTheComboAsTheUserReadsIt() throws {
    let h = Harness()
    #expect(try report(h, "keyboard.hold", .press(down: true), ["keys": "fn"]) == ActionOutcome(detail: "fn"))
    _ = try report(h, "keyboard.hold", .press(down: false), ["keys": "fn"])
    #expect(
      try report(h, "keyboard.hold", .press(down: true), ["keys": "ctrl+opt+space"])?.detail == "⌃⌥ Space")
    _ = try report(h, "keyboard.hold", .press(down: false))
  }

  @Test func holdReleaseNeverNeedsItsParameters() throws {
    let h = Harness()
    _ = try report(h, "keyboard.hold", .press(down: true), ["keys": "fn"])
    // The binding's parameters are gone by the time the finger lifts: the release still works.
    #expect(try report(h, "keyboard.hold", .press(down: false)) == ActionOutcome())
  }

  @Test func appSwitcherReportsNoLevelAndTheSystemUI() throws {
    let h = Harness()
    // Batch 26 ruling (the switcher opens on one step of travel, never on contact): nothing shows on `.began`; the outcome comes with the opening step.
    // Before: let outcome = try report(h, "apps.switcher", .delta(0, phase: .began))
    #expect(try report(h, "apps.switcher", .delta(0, phase: .began)) == nil)
    let outcome = try report(h, "apps.switcher", .delta(0.1, phase: .changed))
    #expect(outcome == ActionOutcome(level: nil, detail: nil, systemHUDShown: true))
    _ = try report(h, "apps.switcher", .delta(0, phase: .ended))
  }

  @Test func triggersReportNothing() throws {
    let h = Harness()
    #expect(try report(h, "media.playPause", .trigger) == nil)
    #expect(try report(h, "audio.mute", .trigger) == nil)
    #expect(
      try report(h, "keyboard.slideSteps", .delta(0, phase: .began), ["upKeys": "up", "downKeys": "down"]) == nil)
  }

  @Test func displayTextOrdersModifiersLikeTheSystem() {
    #expect(KeyCombo("cmd+shift+4")?.displayText == "⇧⌘ 4")
    #expect(KeyCombo("ctrl+opt")?.displayText == "⌃⌥")
    #expect(KeyCombo("fn+ctrl")?.displayText == "fn⌃")
    #expect(KeyCombo("f5")?.displayText == "F5")
    #expect(KeyCombo("a")?.displayText == "A")
  }
}

@Suite struct HonestBrightnessTests {
  typealias Copy = ActionRegistry.AvailabilityCopy

  @Test func unconfirmedMonitorAsksForACheck() throws {
    let h = externalHarness()
    let outcome = try report(h, "display.brightness", .delta(0, phase: .began))
    let parsed = DisplayCheckRequest.parse(outcome?.detail ?? "")
    #expect(parsed.name == "Desk 34")
    #expect(parsed.request == DisplayCheckRequest(key: "4c2d-7154-9"))
    #expect(outcome?.detail == "Desk 34" + DisplayCheckRequest.marker + "4c2d-7154-9")
  }

  @Test func checkStopsAfterThreeAsks() throws {
    for asks in 0...4 {
      var settings = AppSettings.defaults
      settings.displayCheckAsks = [desk.key: asks]
      let h = externalHarness(settings: settings)
      let detail = try report(h, "display.brightness", .delta(0, phase: .began))?.detail ?? ""
      #expect((DisplayCheckRequest.parse(detail).request != nil) == (asks < 3), "asks \(asks)")
    }
  }

  @Test func confirmedMonitorIsNeverChecked() throws {
    var settings = AppSettings.defaults
    settings.confirmedDisplays = [desk.key]
    let h = externalHarness(settings: settings)
    #expect(try report(h, "display.brightness", .delta(0, phase: .began))?.detail == "Desk 34")
  }

  @Test func settingsAppliedLiveStopTheCheck() throws {
    let h = externalHarness()
    var settings = AppSettings.defaults
    settings.confirmedDisplays = [desk.key]
    h.registry.apply(settings: settings)
    #expect(try report(h, "display.brightness", .delta(0, phase: .began))?.detail == "Desk 34")
  }

  @Test func turnedOffMonitorIsSkipped() throws {
    var settings = AppSettings.defaults
    settings.unresponsiveDisplays = [desk.key]
    let h = externalHarness(settings: settings)
    #expect(throws: ActionError.unavailable("display.brightness", reason: "Turned off for this display.")) {
      try h.slide("display.brightness", 0, phase: .began)
    }
    #expect(h.displays.setCalls.isEmpty)
  }

  @Test func turnedOffMonitorAloneMakesBrightnessUnavailable() {
    var settings = AppSettings.defaults
    settings.unresponsiveDisplays = [desk.key]
    let h = externalHarness(settings: settings)
    #expect(h.registry.availability(of: "display.brightness") == .unavailable(reason: Copy.turnedOffForDisplay))
  }

  @Test func turnedOffMonitorBesideTheBuiltInPanelLeavesBrightnessAvailable() {
    var settings = AppSettings.defaults
    settings.unresponsiveDisplays = [desk.key]
    let h = externalHarness(settings: settings)
    h.display.isAvailable = true
    #expect(h.registry.availability(of: "display.brightness") == .available)
  }

  @Test func unconfirmedMonitorIsLimitedWithTheCopy() {
    let h = externalHarness()
    #expect(h.registry.availability(of: "display.brightness") == .limited(reason: Copy.mayNotRespond))
    #expect(Copy.mayNotRespond == "May not respond: some monitors accept brightness commands without applying them.")
  }

  @Test func confirmingTheMonitorMakesBrightnessAvailable() {
    let h = externalHarness()
    #expect(h.registry.availability(of: "display.brightness") == .limited(reason: Copy.mayNotRespond))
    var settings = AppSettings.defaults
    settings.confirmedDisplays = [desk.key]
    h.registry.apply(settings: settings)
    #expect(h.registry.availability(of: "display.brightness") == .available)
  }

  @Test func appleExternalDisplayIsNotLimited() {
    let h = externalHarness(studio)
    #expect(h.registry.availability(of: "display.brightness") == .available)
  }

  @Test func markerRoundTripsAndPlainNamesPassThrough() {
    #expect(DisplayCheckRequest.parse("Desk 34") == ("Desk 34", nil))
    let detail = DisplayCheckRequest.detail(name: "Desk 34", request: DisplayCheckRequest(key: "k"))
    #expect(DisplayCheckRequest.parse(detail) == ("Desk 34", DisplayCheckRequest(key: "k")))
    // EdgyRuntime's `DisplayCheckDetail.marker` must be this exact string.
    #expect(DisplayCheckRequest.marker == "\u{1E}displayCheck:")
  }
}
