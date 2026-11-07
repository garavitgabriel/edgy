import Actions
import EdgyCore
import EdgyRuntime
import Foundation
import Testing

@testable import EdgyUI

@MainActor
struct WindowTabTests {
  @Test func tabsAreDefaultThenAppsAlphabetically() {
    let model = PreviewFixtures.model()
    #expect(model.profileTabs() == [.default, .app(PreviewFixtures.huddle), .app(PreviewFixtures.wayfare)])
    #expect(model.profileTabs().map { model.tabName($0) } == ["Default", "Huddle", "Wayfare"])
  }

  @Test func tabOrderUsesInstalledAppNames() {
    let model = PreviewFixtures.model()
    let apps = [InstalledApp(name: "Aardvark", bundleID: PreviewFixtures.wayfare, path: "/x", isRunning: false)]
    #expect(model.profileTabs(apps: apps) == [.default, .app(PreviewFixtures.wayfare), .app(PreviewFixtures.huddle)])
  }

  @Test func appNameFallsBackToTheBundleIDsLastPart() {
    #expect(WindowCopy.appName(for: "com.example.wayfare", in: []) == "Wayfare")
    #expect(WindowCopy.appName(for: "com.example.wayfare", in: FakeApps.list) == "Wayfare")
    #expect(WindowCopy.appName(for: "solo", in: []) == "Solo")
  }

  @Test func switchOnDefaultIsGlobalEnabled() {
    let model = PreviewFixtures.model()
    #expect(model.topSwitch() == TopSwitch(label: "Enabled", isOn: true))
    model.setTopSwitch(false)
    #expect(model.editor.config.app.enabled == false)
    #expect(model.topSwitch().isOn == false)
  }

  @Test func switchOnAppTabIsOnInThatApp() {
    let model = PreviewFixtures.model()
    model.selectProfile(.app(PreviewFixtures.wayfare))
    #expect(model.topSwitch() == TopSwitch(label: "On in Wayfare", isOn: true))
    model.setTopSwitch(false)
    #expect(model.editor.config.appProfiles[PreviewFixtures.wayfare]?.disabled == true)
    #expect(model.editor.config.app.enabled, "the global switch is untouched")

    model.selectProfile(.app(PreviewFixtures.huddle))
    #expect(model.topSwitch() == TopSwitch(label: "On in Huddle", isOn: false))
    #expect(model.isProfileOff(.app(PreviewFixtures.huddle)))
  }

  @Test func selectingATabClosesThePicker() {
    let model = PreviewFixtures.model()
    model.picking = PickerTarget(zone: .edge(.bottom), gesture: .tap)
    model.selectProfile(.app(PreviewFixtures.wayfare))
    #expect(model.picking == nil)
  }
}

@MainActor
struct AppProfileFlowTests {
  @Test func addDefaultWithChangesCreatesAnInheritingProfileAndSelectsIt() throws {
    let model = PreviewFixtures.model()
    try model.addAppProfile(bundleID: WindowFixtures.quillpad, startingFrom: .defaultWithChanges)
    let profile = try #require(model.editor.config.appProfiles[WindowFixtures.quillpad])
    #expect(profile.inheritsDefault && profile.bindings.isEmpty && !profile.disabled)
    #expect(model.selectedProfile == .app(WindowFixtures.quillpad))
  }

  @Test func addACopyOfDefaultCopiesTheBindings() throws {
    let model = PreviewFixtures.model()
    try model.addAppProfile(bundleID: WindowFixtures.quillpad, startingFrom: .copyOfDefault)
    let profile = try #require(model.editor.config.appProfiles[WindowFixtures.quillpad])
    #expect(!profile.inheritsDefault)
    #expect(profile.bindings == model.editor.config.defaultProfile.bindings)
    #expect(model.isLegacyProfile(.app(WindowFixtures.quillpad)))
  }

  @Test func addEmptyMapsNothing() throws {
    let model = PreviewFixtures.model()
    try model.addAppProfile(bundleID: WindowFixtures.quillpad, startingFrom: .empty)
    let profile = try #require(model.editor.config.appProfiles[WindowFixtures.quillpad])
    #expect(!profile.inheritsDefault && profile.bindings.isEmpty)
  }

  @Test func addingAnExistingProfileThrowsAndChangesNothing() {
    let model = PreviewFixtures.model()
    let before = model.editor.config
    #expect(throws: (any Error).self) {
      try model.addAppProfile(bundleID: PreviewFixtures.wayfare, startingFrom: .empty)
    }
    #expect(model.editor.config == before)
  }

  @Test func removeDropsTheProfileAndReturnsToDefault() {
    let model = PreviewFixtures.model()
    model.selectProfile(.app(PreviewFixtures.wayfare))
    model.removeAppProfile(bundleID: PreviewFixtures.wayfare)
    #expect(model.editor.config.appProfiles[PreviewFixtures.wayfare] == nil)
    #expect(model.selectedProfile == .default)
  }

  @Test func resetClearsOverridesAndTurnsTheAppBackOn() {
    let model = PreviewFixtures.model()
    model.resetAppProfile(bundleID: PreviewFixtures.wayfare)
    #expect(model.editor.config.appProfiles[PreviewFixtures.wayfare]?.bindings.isEmpty == true)
    model.resetAppProfile(bundleID: PreviewFixtures.huddle)
    #expect(model.editor.config.appProfiles[PreviewFixtures.huddle]?.disabled == false)
  }

  @Test func followDefaultConvertsALegacyProfileWithoutChangingWhatItDoes() {
    let model = PreviewFixtures.model(config: WindowFixtures.legacyConfig)
    let ref = ProfileRef.app(WindowFixtures.quillpad)
    let before = model.editor.config.profile(for: WindowFixtures.quillpad)
    #expect(model.isLegacyProfile(ref))
    model.followDefault(bundleID: WindowFixtures.quillpad)
    #expect(!model.isLegacyProfile(ref))
    #expect(model.editor.config.appProfiles[WindowFixtures.quillpad]?.inheritsDefault == true)
    #expect(Set(model.editor.config.profile(for: WindowFixtures.quillpad).bindings) == Set(before.bindings))
  }

  @Test func addAppListShowsRunningThenAllAlphabeticallyAndFilters() {
    let sections = AddAppView.sections(FakeApps.list, matching: "")
    #expect(sections.running.map(\.name) == ["Quillpad", "Wayfare"])
    #expect(sections.all.map(\.name) == ["Huddle", "Ledgerly", "Quillpad", "Tidepool", "Wayfare"])
    let filtered = AddAppView.sections(FakeApps.list, matching: "tide")
    #expect(filtered.running.isEmpty && filtered.all.map(\.name) == ["Tidepool"])
  }

  @Test func startFromCopyIsBRIEFsCopyWordForWord() {
    #expect(AppProfileStart.allCases.map(\.title) == ["Default, with changes", "A copy of Default", "Empty"])
    #expect(
      AppProfileStart.allCases.map(\.detail) == [
        "Follows Default; change only what's different.", "Starts the same, then goes its own way.",
        "Nothing mapped until you add it.",
      ])
  }
}

@MainActor
struct WindowStateTests {
  let problem = ConfigProblem(line: 14, message: "expected ',' after a value")

  @Test func precedenceFollowsTheBrief() {
    var config = PreviewFixtures.demoConfig
    config.app.enabled = false
    let status = WindowStatus.resolve(
      conditions: WindowConditions(accessibility: .denied, configProblem: problem),
      engine: WindowFixtures.status(devices: [], paused: true, testMode: true), config: config, tab: .default)
    #expect(status.states == [.brokenConfig, .noAccessibility, .noTrackpad, .paused, .disabled, .testMode])
    #expect(status.top == .brokenConfig)
    #expect(status.strip == .brokenConfig(problem))
    #expect(status.padLine == nil, "no trackpad: the mirror says it, nothing else on the pad")
    #expect(status.isReadOnly)
  }

  @Test func accessibilityStripShowsOnlyWhenDeniedAndGoesWhenGranted() {
    let config = PreviewFixtures.demoConfig
    let engine = WindowFixtures.status()
    let denied = WindowStatus.resolve(
      conditions: WindowConditions(accessibility: .denied), engine: engine, config: config, tab: .default)
    #expect(denied.strip == .noAccessibility && !denied.isReadOnly)
    for state in [PermissionState.granted, .unknown] {
      let other = WindowStatus.resolve(
        conditions: WindowConditions(accessibility: state), engine: engine, config: config, tab: .default)
      #expect(other.strip == nil)
    }
  }

  @Test func pausedOutranksOffInAppOnThePad() {
    let until = Date(timeIntervalSince1970: 1000)
    let engine = WindowFixtures.status(paused: true, pausedUntil: until)
    let tab = ProfileRef.app(PreviewFixtures.huddle)
    let paused = WindowStatus.resolve(conditions: .normal, engine: engine, config: PreviewFixtures.demoConfig, tab: tab)
    #expect(paused.padLine == .paused(until: until) && paused.fadesMirror && !paused.hidesInspector)
    let off = WindowStatus.resolve(
      conditions: .normal, engine: WindowFixtures.status(), config: PreviewFixtures.demoConfig, tab: tab)
    #expect(off.padLine == .offInApp(bundleID: PreviewFixtures.huddle) && off.hidesInspector && !off.fadesMirror)
  }

  @Test func disabledAndTestModeAddNoWindowLine() {
    var config = PreviewFixtures.demoConfig
    config.app.enabled = false
    let status = WindowStatus.resolve(
      conditions: .normal, engine: WindowFixtures.status(testMode: true), config: config, tab: .default)
    #expect(status.states == [.disabled, .testMode])
    #expect(status.strip == nil && status.padLine == nil && !status.isReadOnly)
  }

  @Test func mouseOnlyCountsAsNoTrackpad() {
    let mouse = TouchDeviceInfo(id: 9, kind: .mouse, sensorSizeMM: Size2D(width: 60, height: 100), familyID: 0)
    let status = WindowStatus.resolve(
      conditions: .normal, engine: WindowFixtures.status(devices: [mouse]), config: PreviewFixtures.demoConfig,
      tab: .default)
    #expect(status.states == [.noTrackpad])
  }

  @Test func pausedCopyCountsWholeMinutes() {
    let now = Date(timeIntervalSince1970: 0)
    #expect(WindowCopy.paused(until: now.addingTimeInterval(47 * 60 + 30), now: now) == "Paused, 47 min left")
    #expect(WindowCopy.paused(until: now.addingTimeInterval(60), now: now) == "Paused, 1 min left")
    #expect(WindowCopy.paused(until: now.addingTimeInterval(59), now: now) == "Paused, less than a minute left")
    #expect(WindowCopy.paused(until: nil, now: now) == "Paused")
  }

  @Test func brokenConfigSentenceIsBRIEFs() {
    #expect(
      problem.sentence
        == "config.json has an error on line 14: expected ',' after a value. Edgy kept the last working settings.")
  }

  @Test func overlapLineNamesBothPartsAndShowSelectsTheOther() throws {
    let model = PreviewFixtures.model(config: WindowFixtures.overlapConfig)
    model.selectedZone = .edge(.right)
    let note = try #require(model.selectedZoneOverlap)
    #expect(note.text == "Whole edge and upper half both use Slide.")
    #expect(note.other == .edge(.right, segment: 1, segments: 2))
    model.selectedZone = .edge(.left)
    #expect(model.selectedZoneOverlap == nil)
  }

  @Test func partNamesFollowTheEdgeAxis() {
    #expect(WindowCopy.partName(.edge(.left, segment: 0, segments: 2)) == "lower half")
    #expect(WindowCopy.partName(.edge(.bottom, segment: 2, segments: 3)) == "right third")
    #expect(WindowCopy.partName(.edge(.right, segment: 3, segments: 4)) == "top quarter")
    #expect(WindowCopy.gestureName(.swipe(.up)) == "Swipe up")
  }
}

@MainActor
struct FooterAndAdvancedTests {
  @Test func footerTogglesWriteAppSettings() {
    let model = PreviewFixtures.model()
    model.setHaptics(false)
    model.setLaunchAtLogin(true)
    model.setHUD(.none)
    let app = model.editor.config.app
    #expect(!app.haptics && app.launchAtLogin && app.hud == HUDMode.none)
  }

  @Test(arguments: GestureField.allCases)
  func advancedWritesEachFieldWithinRange(field: GestureField) {
    let model = PreviewFixtures.model()
    let mid = (field.range.lowerBound + field.range.upperBound) / 2
    model.setGesture(field, to: mid)
    #expect(model.gestureValue(field) == mid)
    model.setGesture(field, to: field.range.upperBound * 10 + 1)
    #expect(model.gestureValue(field) == field.range.upperBound)
    model.setGesture(field, to: -1)
    #expect(model.gestureValue(field) == field.range.lowerBound)
  }

  @Test func advancedWritesFingersHapticEventsAndStrengths() {
    let model = PreviewFixtures.model()
    model.setFingers(2)
    #expect(model.editor.config.gestures.fingers == 2)
    model.setFingers(5)
    #expect(model.editor.config.gestures.fingers == GestureSettingsLimits.fingers.upperBound)

    model.setHapticEvent(.slideSteps, on: false)
    #expect(!model.editor.config.app.hapticEvents.contains(.slideSteps))
    model.setHapticEvent(.slideSteps, on: true)
    #expect(model.editor.config.app.hapticEvents == Set(HapticEvent.allCases))

    model.setTickStrength(3)
    model.setClickStrength(99)
    #expect(model.editor.config.app.hapticTickStrength == 3)
    #expect(model.editor.config.app.hapticClickStrength == AppSettings.hapticStrengthRange.upperBound)
  }

  @Test func sliderDragIsOneUndoStep() throws {
    let model = PreviewFixtures.model()
    model.continuousEdit(GestureField.edgeWidthMM.rawValue, began: true)
    for width in [9.0, 10, 11, 12] { model.setGesture(.edgeWidthMM, to: width) }
    model.continuousEdit(GestureField.edgeWidthMM.rawValue, began: false)
    #expect(model.gestureValue(.edgeWidthMM) == 12)
    #expect(try model.editor.undo())
    #expect(model.gestureValue(.edgeWidthMM) == GestureSettings.defaults.edgeWidthMM)
  }

  @Test func outOfRangeNoteQuotesTheFileAndTheValueUsed() {
    var config = PreviewFixtures.demoConfig
    config.gestures.edgeWidthMM = 90
    let model = PreviewFixtures.model(config: config)
    #expect(model.outOfRangeNote(.edgeWidthMM) == "The config file said 90 mm; using 20 mm.")
    #expect(model.outOfRangeNote(.cornerSizeMM) == nil)
  }

  @Test func minimumSizeFitsTheLargerPadToScale() {
    let size = SettingsWindowView.minimumSize
    let pad = WindowMetrics.largestPadMM
    #expect(size.width >= pad.width * Tokens.mirrorPointsPerMM + WindowMetrics.inspectorWidth)
    #expect(
      size.height >= pad.height * Tokens.mirrorPointsPerMM + WindowMetrics.tabBarHeight + WindowMetrics.footerHeight)
  }
}
