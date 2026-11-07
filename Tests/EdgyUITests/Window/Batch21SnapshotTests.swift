import Actions
import AppKit
import EdgyCore
import EdgyRuntime
import Foundation
import SwiftUI
import Testing

@testable import EdgyUI

/// Invented apps whose bundles exist on disk, so app marks and icons draw. Each is an empty `.app`
/// folder in the test's temporary directory (the system gives it the generic app icon); nothing
/// outside the temp folder is touched, and no real product's icon is shown.
@MainActor
enum IconApps {
  static let root = FileManager.default.temporaryDirectory.appendingPathComponent("edgy-batch21-apps")

  static func app(_ name: String, _ bundleID: String, running: Bool) -> InstalledApp {
    let url = root.appendingPathComponent("\(name).app")
    let contents = url.appendingPathComponent("Contents")
    try? FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
    let plist: [String: String] = [
      "CFBundleIdentifier": bundleID, "CFBundleName": name, "CFBundlePackageType": "APPL",
    ]
    (plist as NSDictionary).write(to: contents.appendingPathComponent("Info.plist"), atomically: true)
    return InstalledApp(name: name, bundleID: bundleID, path: url.path, isRunning: running)
  }

  static var list: [InstalledApp] {
    [
      app("Wayfare", PreviewFixtures.wayfare, running: true),
      app("Huddle", PreviewFixtures.huddle, running: false),
      app("Quillpad", "com.example.quillpad", running: true),
      app("Ledgerly", "com.example.ledgerly", running: false),
    ]
  }
}

/// Batch 21's integrated shots in `docs/design/build-shots/batch-21/`, light and dark.
@MainActor
@Suite(.serialized)
struct Batch21SnapshotTests {
  static let folder = "batch-21"
  static let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

  private func window(
    _ model: SettingsModel, conditions: WindowConditions = .normal, _ name: String
  ) throws {
    let view = SettingsWindowView(model: model, apps: IconApps.list).environment(\.windowConditions, conditions)
    let urls = try Snapshot.write(view, folder: Self.folder, name: name, size: SettingsWindowView.minimumSize)
    #expect(urls.count == 2)
  }

  // MARK: The window in each state

  @Test func windowDefault() throws {
    let model = PreviewFixtures.model()
    model.selectedZone = .edge(.right)
    // Render A shows the right edge's slide open (as if clicked).
    model.inspectorDrafts.open = InspectorDrafts.Key(
      profile: .default, binding: BindingKey(zone: .edge(.right), gesture: .slide))
    try window(model, "window-default")
  }

  @Test func windowLiveTouchOnTheRightEdge() throws {
    let model = PreviewFixtures.model()
    model.selectedZone = .edge(.right)
    model.simulate(MirrorFixtures.touch(0.975, 0.68, .claimed))
    try window(model, "window-live-right")
  }

  @Test func windowPickerOnTheBottomEdge() throws {
    let model = PreviewFixtures.model()
    model.selectedZone = .edge(.bottom)
    model.picking = PickerTarget(zone: .edge(.bottom), gesture: .tap)
    try window(model, "window-picker-bottom")
  }

  @Test func wayfareTab() throws {
    let model = PreviewFixtures.model()
    model.selectProfile(.app(PreviewFixtures.wayfare))
    model.selectedZone = .edge(.bottom)
    try window(model, "tab-wayfare")
  }

  @Test func huddleOff() throws {
    let model = PreviewFixtures.model()
    model.selectProfile(.app(PreviewFixtures.huddle))
    try window(model, "tab-huddle-off")
  }

  @Test func paused() throws {
    let model = PreviewFixtures.model()
    model.simulate(WindowFixtures.status(paused: true, pausedUntil: Date().addingTimeInterval(47 * 60 + 30)))
    try window(model, "state-paused")
  }

  @Test func noTrackpad() throws {
    let model = PreviewFixtures.model()
    model.selectedZone = .edge(.right)
    model.simulate(WindowFixtures.status(devices: []))
    try window(model, "state-no-trackpad")
  }

  @Test func disabled() throws {
    var config = PreviewFixtures.demoConfig
    config.app.enabled = false
    let model = PreviewFixtures.model(config: config)
    model.selectedZone = .edge(.right)
    try window(model, "state-disabled")
  }

  @Test func brokenConfig() throws {
    let model = PreviewFixtures.model()
    model.selectedZone = .edge(.right)
    let problem = ConfigProblem(
      EdgyRuntime.ConfigProblem(message: "Unexpected character 'x' around line 14, column 3.", line: 14))
    try window(model, conditions: WindowConditions(configProblem: problem), "issue-broken-config")
  }

  @Test func advanced() throws {
    try Snapshot.write(AdvancedSettingsView(model: PreviewFixtures.model()), folder: Self.folder, name: "advanced")
  }

  @Test func addAppWithIcons() throws {
    let model = PreviewFixtures.model()
    let apps = IconApps.list
    try Snapshot.write(
      AddAppView(model: model, apps: apps).background(WindowMaterial()), folder: Self.folder, name: "add-app-step1")
    try Snapshot.write(
      AddAppView(model: model, apps: apps, step: .startFrom(apps[2])).background(WindowMaterial()),
      folder: Self.folder, name: "add-app-step2")
  }

  /// The longest parameter labels at the real inspector width: one line each, never mid-word.
  @Test func longParameterLabelsAtTheRealWidth() throws {
    var config = PreviewFixtures.demoConfig
    config.defaultProfile.bindings.append(Binding(zone: .edge(.top), gesture: .slide, action: "apps.switcher"))
    let model = PreviewFixtures.model(config: config)
    model.selectedZone = .edge(.top)
    model.inspectorDrafts.open = InspectorDrafts.Key(
      profile: .default, binding: BindingKey(zone: .edge(.top), gesture: .slide))
    try window(model, "inspector-long-labels")
  }

  // MARK: Mirrors

  @Test func presetWindowsAndMinimal() throws {
    for (name, config) in [("preset-windows", Presets.windows), ("preset-minimal", Presets.minimal)] {
      try Snapshot.write(
        PresetMirrorView(config: config).padding(16).background(Tokens.windowTint), folder: Self.folder, name: name)
    }
  }

  @Test func pointerTouchInTheMiddleIsNotDrawn() throws {
    let model = PreviewFixtures.model()
    model.simulate(MirrorFixtures.touch(0.5, 0.5, .down))
    try Snapshot.write(
      PadMirrorView(model: model).padding(28).background(Tokens.windowTint), folder: Self.folder,
      name: "pad-pointer-touch-hidden")
  }

  // MARK: Popover at its real size

  private func popover(_ name: String, model: SettingsModel, state: MenuBarState = MenuBarState()) throws {
    state.now = { Self.now }
    if state.accessibility == .unknown { state.accessibility = .granted }
    if state.installedApps.isEmpty { state.installedApps = IconApps.list }
    let urls = try Snapshot.write(MenuPopoverView(model: model).environment(state), folder: Self.folder, name: name)
    #expect(urls.count == 2)
  }

  @Test func popoverNormalAndChips() throws {
    try popover("popover-normal", model: PreviewFixtures.model())
    let live = PreviewFixtures.model()
    live.frontmostBundleID = PreviewFixtures.wayfare
    try popover("popover-app-chip-live", model: live)
  }

  @Test func popoverDisabledFadesOnce() throws {
    var config = PreviewFixtures.demoConfig
    config.app.enabled = false
    try popover("popover-disabled", model: PreviewFixtures.model(config: config))
  }

  @Test func popoverLastTouch() throws {
    let model = PreviewFixtures.model()
    // The contact where it landed on the right edge. The mirror keeps it after the lift by holding
    // the last frame in its own state while on screen; a headless snapshot builds a fresh view, so
    // the shot is taken with the finger down.
    model.simulate(MirrorFixtures.touch(0.975, 0.55, .claimed))
    try popover("popover-last-touch", model: model)
  }

  @Test func popoverUnavailableZoneIsUnmapped() throws {
    var config = PreviewFixtures.demoConfig
    config.defaultProfile.bindings.append(
      Binding(zone: .corner(.bottomLeft), gesture: .doubleTap, action: "keyboard.backlightToggle"))
    let model = InspectorFixtures.model(config: config)
    model.simulate(
      EngineStatus(
        running: true, paused: false, pausedUntil: nil, enabled: true, devices: [PreviewFixtures.externalPad]))
    try popover("popover-unavailable-unmapped", model: model)
  }

  @Test func popoverPausedPlusTestMode() throws {
    let model = PreviewFixtures.model()
    model.simulate(
      EngineStatus(
        running: true, paused: true, pausedUntil: Self.now.addingTimeInterval(47 * 60 + 20), enabled: true,
        devices: [PreviewFixtures.externalPad], testMode: true))
    let state = MenuBarState()
    state.setTestMode(true, model: model)
    try popover("popover-paused-test-mode", model: model, state: state)
    #expect(state.glyphState(model: model) == .paused)
  }

  @Test func popoverNoAccessibilityPlusBrokenConfig() throws {
    let model = PreviewFixtures.model()
    let state = MenuBarState()
    state.accessibility = .denied
    state.configProblem = ConfigProblem(
      EdgyRuntime.ConfigProblem(message: "Unexpected character 'x' around line 14, column 3.", line: 14))
    try popover("popover-no-access-broken-config", model: model, state: state)
    #expect(PopoverTop.resolve(state: state, model: model) == .brokenConfig(state.configProblem!))
  }
}
