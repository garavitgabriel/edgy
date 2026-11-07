import AppKit
import EdgyCore
import EdgyRuntime
import Foundation
import SwiftUI
import Testing

@testable import EdgyUI

/// Batch 25 (critiques 22 and 24): tests and shots in `docs/design/build-shots/batch-25/`,
/// light and dark.
@MainActor
@Suite(.serialized)
struct Batch25SnapshotTests {
  static let folder = "batch-25"
  static let now = Date(timeIntervalSince1970: 1_800_000_000)

  private func window(_ model: SettingsModel, conditions: WindowConditions = .normal, _ name: String) throws {
    let view = SettingsWindowView(model: model, apps: IconApps.list).environment(\.windowConditions, conditions)
      .withExportedAppIcon()
    #expect(try Snapshot.write(view, folder: Self.folder, name: name, size: SettingsWindowView.minimumSize).count == 2)
  }

  private func popover(_ name: String, model: SettingsModel) throws {
    let state = MenuBarState()
    state.now = { Self.now }
    state.accessibility = .granted
    state.installedApps = IconApps.list
    #expect(
      try Snapshot.write(MenuPopoverView(model: model).environment(state), folder: Self.folder, name: name).count == 2)
  }

  private func picker(_ model: SettingsModel, _ name: String, height: CGFloat = 420) throws {
    let view = ActionPickerView(model: model)
      .frame(width: PickerPlacement.width, height: height, alignment: .topLeading)
      .background(Tokens.windowTint)
    try Snapshot.write(view, folder: Self.folder, name: name)
  }

  private func inspector(_ model: SettingsModel, _ name: String, open: BindingKey) throws {
    model.inspectorDrafts.open = InspectorDrafts.Key(profile: model.selectedProfile, binding: open)
    let view = InspectorView(model: model).frame(width: 360, height: 640, alignment: .top)
      .background(Tokens.padTop.opacity(0.35)).background(Tokens.windowTint)
    try Snapshot.write(view, folder: Self.folder, name: name)
  }

  private func mini(_ model: SettingsModel, _ name: String, hover: Zone? = nil) throws {
    model.simulate(WindowFixtures.status())
    let view = MiniMirrorView(model: model, frontmostApp: nil).hovering(hover)
      .padding(16).frame(width: 320).background(Tokens.windowTint)
    try Snapshot.write(view, folder: Self.folder, name: name)
  }

  private func config(_ bindings: [EdgyCore.Binding]) -> EdgyConfig {
    var config = PreviewFixtures.demoConfig
    config.defaultProfile.bindings = bindings
    return config
  }

  // MARK: 1. App marks (critique 22 must-fix)

  @Test func onlyABundleWithItsOwnIconHasAMark() throws {
    let list = IconApps.list
    let real = try #require(list.first { $0.name == "Wayfare" })
    let iconless = try #require(list.first { $0.name == "Huddle" })
    #expect(AppMark.hasIcon(real.path))
    #expect(AppMark.icon(real.path) != nil)
    #expect(!AppMark.hasIcon(iconless.path))
    #expect(AppMark.icon(iconless.path) == nil)
    #expect(!AppMark.hasIcon(nil))
    #expect(!AppMark.hasIcon("/nonexistent/Nothing.app"))
    // An Info.plist that names an icon the bundle doesn't ship: the system would draw its
    // generic icon, so it counts as none.
    let broken = IconApps.root.appendingPathComponent("Broken.app/Contents")
    try FileManager.default.createDirectory(at: broken, withIntermediateDirectories: true)
    let plist: NSDictionary = ["CFBundleIdentifier": "com.example.broken", "CFBundleIconFile": "Missing"]
    plist.write(to: broken.appendingPathComponent("Info.plist"), atomically: true)
    #expect(!AppMark.hasIcon(broken.deletingLastPathComponent().path))
  }

  @Test func marksOnTabsChipsAndAddApp() throws {
    let model = PreviewFixtures.model()
    model.selectedZone = .edge(.right)
    // Tabs: Wayfare's real icon, Huddle's Open App tile.
    try window(model, "window-app-marks")
    // Chips: the same two in the popover.
    try popover("popover-app-marks", model: PreviewFixtures.model())
    let add = AddAppView(model: PreviewFixtures.model(), apps: IconApps.list) {}
      .frame(width: 320, height: 360).background(Tokens.windowTint)
    try Snapshot.write(add, folder: Self.folder, name: "add-app-marks")
  }

  // MARK: 2. Critique 22 should-fixes

  @Test func checkboxHelpersIndentToTheLabelWithSpaceAfter() throws {
    let model = InspectorFixtures.model(
      config: config([
        Binding(
          zone: .edge(.bottom), gesture: .slide, action: "apps.switcher",
          parameters: ["keepOpenMS": "0", "stepMM": "12"])
      ]))
    model.selectedZone = .edge(.bottom)
    try inspector(model, "inspector-switch-apps-keep-open-off", open: BindingKey(zone: .edge(.bottom), gesture: .slide))
    let keys = InspectorFixtures.model(
      config: config([
        Binding(
          zone: .edge(.right), gesture: .slide, action: "keyboard.slideSteps",
          parameters: ["upKeys": "up", "downKeys": "down"])
      ]))
    keys.selectedZone = .edge(.right)
    try inspector(keys, "inspector-repeat-keys-open", open: BindingKey(zone: .edge(.right), gesture: .slide))
    #expect(LabeledParameter<EmptyView>.helperSpacing == 8)
  }

  @Test func splitPreviewFadesTheEdgeLabels() throws {
    let model = PreviewFixtures.model()
    model.selectedZone = .edge(.bottom)
    model.splitPreview.hover = SplitPreview.Hover(edge: .bottom, parts: 2)
    try window(model, "window-split-hover-bottom")
    let geometry = MirrorGeometry(
      sensorSizeMM: MirrorGeometry.defaultSensorSizeMM, settings: model.editor.config.gestures,
      pointsPerMM: Tokens.mirrorPointsPerMM)
    let pad = MirrorPad(
      geometry: geometry, zones: [], selected: nil, touches: [], faded: false, dashedOutline: false,
      showsLabels: true, message: nil, splitPreview: SplitPreview.Hover(edge: .bottom, parts: 2))
    #expect(pad.splitPreviewHides(.edge(.bottom)))
    #expect(pad.splitPreviewHides(.edge(.bottom, segment: 1, segments: 2)))
    #expect(!pad.splitPreviewHides(.edge(.right)))
    #expect(!pad.splitPreviewHides(.corner(.bottomLeft)))
  }

  @Test func pickerListEndsWithAnInsetAndFade() throws {
    let model = PreviewFixtures.model()
    model.selectedZone = .edge(.left)
    model.picking = PickerTarget(zone: .edge(.left), gesture: .slide)
    try window(model, "window-picker-left-edge")
    #expect(PickerScrollEdge.inset == 12 && PickerScrollEdge.fade == 12)
  }

  @Test func readOnlyEnabledIsInk2() throws {
    let model = PreviewFixtures.model()
    model.selectedZone = .edge(.right)
    let problem = ConfigProblem(
      EdgyRuntime.ConfigProblem(message: "Unexpected character 'x' around line 14, column 3.", line: 14))
    try window(model, conditions: WindowConditions(configProblem: problem), "issue-broken-config")
  }

  /// Should-fix 6b: the wrapped strip from the shipping window, not a hand-built copy.
  @Test func brokenConfigStripWrappedFromTheWindow() throws {
    let model = PreviewFixtures.model()
    model.selectedZone = .edge(.right)
    let problem = ConfigProblem(
      EdgyRuntime.ConfigProblem(
        message:
          "Unexpected character 'x' around line 14, column 3, inside the bindings list of the Default profile.",
        line: 14))
    try window(model, conditions: WindowConditions(configProblem: problem), "strip-broken-config-wrapped")
  }

  /// Should-fix 6a: the hover wash over the rows the popover really shows.
  @Test func menuRowHoverWashOnTheVisibleRows() throws {
    let visible = MenuRow.visible(paused: false)
    #expect(!visible.contains(.openConfigFile) && !visible.contains(.reloadConfig))
    let rows = VStack(spacing: 0) {
      ForEach(Array(visible.enumerated()), id: \.offset) { index, row in
        MenuRowButton(row: row, perform: {}, forceHover: index == 1)
      }
    }
    .padding(8).frame(width: 320).background(Tokens.windowTint)
    try Snapshot.write(rows, folder: Self.folder, name: "popover-menu-hover-wash")
  }

  @Test func miniContactKeepsTheEdgeIcon() throws {
    let model = PreviewFixtures.model()
    model.simulate(WindowFixtures.status())
    model.simulate(MirrorFixtures.touch(0.975, 0.55, .claimed))
    try popover("popover-last-touch", model: model)
  }

  /// Should-fix 7, NOT SHOT before: two icons stacked on a side edge, and the sideways slide icon
  /// in a top/bottom edge's "Add gesture…" list.
  @Test func notShotItems() throws {
    let side = InspectorFixtures.model(
      config: config([
        EdgyCore.Binding(zone: .edge(.right), gesture: .slide, action: "audio.volume"),
        EdgyCore.Binding(zone: .edge(.right), gesture: .doubleTap, action: "audio.mute"),
      ]))
    try mini(side, "mini-two-icons-side-edge")
    let bottom = InspectorFixtures.model(
      config: config([EdgyCore.Binding(zone: .edge(.bottom), gesture: .tap, action: "media.playPause")]))
    bottom.selectedZone = .edge(.bottom)
    bottom.picking = PickerTarget(zone: .edge(.bottom), gesture: nil)
    #expect(bottom.unmappedGestures(for: .edge(.bottom)).contains(.slide))
    try picker(bottom, "picker-add-gesture-bottom-edge", height: 240)
  }

  // MARK: 3. Design answers 1 and 2

  @Test func miniHoverLineUsesShortZoneNames() throws {
    let model = InspectorFixtures.model()
    let bottom = model.mirrorZones(forApp: nil, unavailableAsUnmapped: true).first { $0.zone == .edge(.bottom) }
    // Before the ruling (critique 22, design answer 1: short zone names, full content width):
    // #expect(MiniMirrorView.hoverLine(bottom) == "Bottom edge: Previous Track, Next Track, Play/Pause")
    #expect(MiniMirrorView.hoverLine(bottom) == "Bottom: Previous Track, Next Track, Play/Pause")
    #expect(MiniMirrorView.hoverLine(bottom, width: 288) == "Bottom: Previous Track, Next Track, Play/Pause")
    // Too narrow for the full names: the pad tabs' short names.
    #expect(MiniMirrorView.hoverLine(bottom, width: 150) == "Bottom: Tracks, Play/Pause")
    #expect(MiniMirrorView.shortZoneName(.edge(.left)) == "Left")
    #expect(MiniMirrorView.shortZoneName(.corner(.topLeft)) == "Top-left")
    #expect(MiniMirrorView.shortZoneName(.edge(.right, segment: 1, segments: 2)) == "Right, upper")
    #expect(MiniMirrorView.shortZoneName(.edge(.bottom, segment: 0, segments: 3)) == "Bottom, left")
    #expect(MiniMirrorView.shortZoneName(.edge(.top, segment: 1, segments: 4)) == "Top, quarter 2")
    try mini(model, "mini-hover-line", hover: .edge(.bottom))
  }

  @Test func pickerOrderIsTheIconTable() throws {
    let model = InspectorFixtures.model()
    func titles(_ gesture: GestureKind, query: String = "") -> [String: [ActionID]] {
      let catalog = PickerCatalog(
        groups: model.editor.catalogByCategory, gesture: gesture, query: query, isAppTab: false,
        availability: model.editor.availability(of:))
      return Dictionary(uniqueKeysWithValues: catalog.sections.map { ($0.title, $0.items.map(\.id)) })
    }
    let taps = titles(.tap)
    #expect(taps["Sound"] == ["audio.mute", "mic.mute"])
    #expect(taps["Media"] == ["media.playPause", "media.next", "media.previous"])
    let slides = titles(.slide)
    #expect(slides["Sound"]?.first == "audio.volume")
    #expect(
      slides["Display"] == ["display.brightness", "keyboard.backlight"].filter { slides["Display"]!.contains($0) })
    // Search keeps the order.
    #expect(titles(.tap, query: "track")["Media"] == ["media.next", "media.previous"])
    #expect(titles(.tap, query: "mute")["Sound"] == ["audio.mute", "mic.mute"])
    let picking = InspectorFixtures.model()
    picking.picking = PickerTarget(zone: .edge(.bottom), gesture: .tap)
    try picker(picking, "picker-icon-table-order", height: 900)
  }

  @Test func splitNoteBeforeTheClick() throws {
    let model = PreviewFixtures.model()
    model.selectedZone = .edge(.right)
    model.splitPreview.hover = SplitPreview.Hover(edge: .right, parts: 3)
    #expect(model.splitNote(for: .edge(.right), parts: 3)?.hasSuffix("the other two start empty.") == true)
    try window(model, "window-split-hover-right-thirds")
  }
}
