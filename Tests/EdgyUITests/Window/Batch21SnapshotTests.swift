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

  /// `icon`: the bundle ships its own `.icns` (Edgy's exported icon stands in for a real app's).
  /// Without it the bundle is iconless and must draw the Open App tile (critique 22 must-fix).
  static func app(_ name: String, _ bundleID: String, running: Bool, icon: Bool = false) -> InstalledApp {
    let url = root.appendingPathComponent("\(name).app")
    let contents = url.appendingPathComponent("Contents")
    let resources = contents.appendingPathComponent("Resources")
    try? FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
    var plist: [String: String] = [
      "CFBundleIdentifier": bundleID, "CFBundleName": name, "CFBundlePackageType": "APPL",
    ]
    let icns = resources.appendingPathComponent("AppIcon.icns")
    try? FileManager.default.removeItem(at: icns)
    if icon {
      plist["CFBundleIconFile"] = "AppIcon"
      try? FileManager.default.copyItem(
        at: Snapshot.repoRoot.appendingPathComponent("docs/design/assets/AppIcon.icns"), to: icns)
    }
    (plist as NSDictionary).write(to: contents.appendingPathComponent("Info.plist"), atomically: true)
    return InstalledApp(name: name, bundleID: bundleID, path: url.path, isRunning: running)
  }

  static var list: [InstalledApp] {
    [
      app("Wayfare", PreviewFixtures.wayfare, running: true, icon: true),
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
      .withExportedAppIcon()
    let urls = try Snapshot.write(view, folder: Self.folder, name: name, size: SettingsWindowView.minimumSize)
    #expect(urls.count == 2)
  }

  // MARK: The window in each state

  @Test func windowDefault() throws {
    let model = PreviewFixtures.model()
    model.selectedZone = .edge(.right)
    // Selecting a zone opens no binding by itself (critique 21, design answer 4): collapsed.
    #expect(model.openBinding(in: .edge(.right), rows: model.inspectorRows(for: .edge(.right))) == nil)
    try window(model, "window-default")
  }

  /// The original batch-21 fixture, kept: render A's state with the right edge's slide opened as
  /// if clicked (a click opens it; selecting alone doesn't, which `windowDefault` asserts).
  @Test func windowDefaultWithTheSlideClickedOpen() throws {
    let model = PreviewFixtures.model()
    model.selectedZone = .edge(.right)
    model.inspectorDrafts.open = InspectorDrafts.Key(
      profile: .default, binding: BindingKey(zone: .edge(.right), gesture: .slide))
    #expect(
      model.openBinding(in: .edge(.right), rows: model.inspectorRows(for: .edge(.right)))
        == BindingKey(zone: .edge(.right), gesture: .slide))
    try window(model, "window-default-slide-open")
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
    // One frame, two fingers: a pointer touch mid-pad (never drawn) and a claim on the right edge
    // (drawn), so the shot proves the filter rather than showing an idle pad (critique 21 S5).
    model.simulate(
      LiveFeedUpdate(
        touches: LiveTouchFrame(
          deviceID: MirrorFixtures.pad.id, timestamp: 1,
          touches: [
            LiveTouch(id: 1, position: Point2D(x: 0.5, y: 0.5), state: .down),
            LiveTouch(id: 2, position: Point2D(x: 0.975, y: 0.6), state: .claimed),
          ]),
        decisions: []))
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
    // the shot is taken with the finger down. A pad must be attached: the mini draws touches only
    // for a device (critique 21 must-fix 2: the old shot had none, so it matched popover-normal).
    model.simulate(WindowFixtures.status())
    model.simulate(MirrorFixtures.touch(0.975, 0.55, .claimed))
    #expect(!model.liveTouches.isEmpty)
    try popover("popover-last-touch", model: model)
  }

  @Test func popoverUnavailableZoneIsUnmapped() throws {
    var config = PreviewFixtures.demoConfig
    // On a mapped zone, so the change shows (critique 21: bottom-left was already pass-through).
    // The right edge's only binding becomes an unavailable action, so it draws as a hairline.
    config.defaultProfile.bindings.removeAll {
      if case .edge(.right, _, _) = $0.zone { return true }
      return false
    }
    config.defaultProfile.bindings.append(
      Binding(zone: .edge(.right), gesture: .doubleTap, action: "keyboard.backlightToggle"))
    let model = InspectorFixtures.model(config: config)
    #expect(!model.editor.availability(of: "keyboard.backlightToggle").isUsable)
    #expect(
      model.mirrorZones(forApp: nil, unavailableAsUnmapped: true).first { $0.zone == .edge(.right) }?.style == .unmapped
    )
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
