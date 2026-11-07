import AppKit
import EdgyCore
import EdgyRuntime
import Foundation
import SwiftUI
import Testing

@testable import EdgyUI

extension View {
  /// Batch 25 injected the exported app icon for the title bar. Since batch 27 the title bar
  /// draws the bundled `mark-edgy.pdf` (BRIEF § Window identity (a), the owner's ink-mark ruling),
  /// which the test host has too, so there is nothing left to inject; kept so window shots read
  /// the same.
  func withExportedAppIcon() -> some View { self }
}

/// Batch 22 phase B shots in `docs/design/build-shots/batch-22/`, light and dark: picker clarity,
/// the Split control, window identity and Advanced…, the mini mirror's icons and hover line, and
/// the batch-20 parameter shots the chief asked for.
@MainActor
@Suite(.serialized)
struct Batch22SnapshotTests {
  static let folder = "batch-22"

  private func window(_ model: SettingsModel, _ name: String) throws {
    let view = SettingsWindowView(model: model, apps: IconApps.list).withExportedAppIcon()
    try Snapshot.write(view, folder: Self.folder, name: name, size: SettingsWindowView.minimumSize)
  }

  private func picker(
    _ model: SettingsModel, _ name: String, query: String = "", showOthers: Bool = false, height: CGFloat = 420
  ) throws {
    let view = ActionPickerView(model: model, query: query, showOthers: showOthers)
      .frame(width: PickerPlacement.width, height: height, alignment: .topLeading)
      .background(Tokens.windowTint)
    try Snapshot.write(view, folder: Self.folder, name: name)
  }

  private func inspector(_ model: SettingsModel, _ name: String, open: BindingKey? = nil) throws {
    if let open { model.inspectorDrafts.open = InspectorDrafts.Key(profile: model.selectedProfile, binding: open) }
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

  // MARK: Picker clarity

  @Test func pickerAtCatalogScaleWithTheBoundCheckmark() throws {
    let model = InspectorFixtures.model()
    model.selectedZone = .edge(.right)
    model.picking = PickerTarget(zone: .edge(.right), gesture: .slide)
    try picker(model, "picker-slide-bound-checkmark")
    let tap = InspectorFixtures.model()
    tap.selectedZone = .edge(.bottom)
    tap.picking = PickerTarget(zone: .edge(.bottom), gesture: .doubleTap)
    // The whole catalog for a double-tap (unavailable and limited rows with their sub-lines).
    try picker(tap, "picker-catalog-scale", showOthers: true, height: 1500)
  }

  @Test func pickerSearchedEmptyAndDisclosure() throws {
    let model = InspectorFixtures.model()
    model.picking = PickerTarget(zone: .edge(.bottom), gesture: .tap)
    try picker(model, "picker-searched", query: "half")
    try picker(model, "picker-empty-search", query: "xyz")
    // A search that reaches the disclosure: it opens, chevron down (critique 15 S7).
    try picker(model, "picker-searched-disclosure", query: "volume")
  }

  @Test func pickerDoNothingOnAnAppTab() throws {
    let model = InspectorFixtures.model()
    model.selectedProfile = .app(PreviewFixtures.wayfare)
    model.picking = PickerTarget(zone: .edge(.bottom), gesture: .doubleTap)
    try picker(model, "picker-app-tab-do-nothing", height: 1300)
  }

  @Test func pickerOnASideEdgeClearsTheCornerTabs() throws {
    let model = PreviewFixtures.model()
    model.selectedZone = .edge(.left)
    model.picking = PickerTarget(zone: .edge(.left), gesture: .slide)
    try window(model, "window-picker-left-edge")
  }

  // MARK: Split control

  @Test func splitControlEveryOrientationAndCount() throws {
    let model = PreviewFixtures.model()
    let sheet = VStack(alignment: .leading, spacing: 14) {
      ForEach([Zone.Edge.right, .bottom], id: \.self) { edge in
        ForEach(1...4, id: \.self) { count in
          SplitControl(model: model, zone: .edge(edge, segment: 0, segments: count), enabled: true)
        }
      }
    }
    .padding(20).background(Tokens.windowTint)
    try Snapshot.write(sheet, folder: Self.folder, name: "split-control")
  }

  @Test func splitHoverPreviewAndNote() throws {
    let model = PreviewFixtures.model()
    model.selectedZone = .edge(.right)
    model.splitPreview.hover = SplitPreview.Hover(edge: .right, parts: 3)
    try window(model, "window-split-hover")
    let bottom = PreviewFixtures.model()
    bottom.selectedZone = .edge(.bottom)
    bottom.splitPreview.hover = SplitPreview.Hover(edge: .bottom, parts: 2)
    try window(bottom, "window-split-hover-bottom")
  }

  @Test func splitEdgeGroupsBySegment() throws {
    var config = PreviewFixtures.demoConfig
    config.defaultProfile.bindings.removeAll {
      if case .edge(.right, _, _) = $0.zone { return true }
      return false
    }
    config.defaultProfile.bindings.append(
      EdgyCore.Binding(zone: .edge(.right, segment: 1, segments: 2), gesture: .slide, action: "audio.volume"))
    let model = PreviewFixtures.model(config: config)
    model.selectedZone = .edge(.right, segment: 1, segments: 2)
    try window(model, "window-split-grouped")
  }

  // MARK: Window identity and Advanced…

  @Test func advancedButtonIdleAndHover() throws {
    let sheet = HStack(spacing: 24) {
      AdvancedButton {}
      AdvancedButton(action: {}, forceHover: true)
    }
    .padding(20).background(Tokens.windowTint)
    try Snapshot.write(sheet, folder: Self.folder, name: "advanced-button")
    let model = PreviewFixtures.model()
    model.selectedZone = .edge(.right)
    try window(model, "window-identity")
  }

  // MARK: Mini mirror (bone 10)

  @Test func miniMirrorIconsOnEveryMappedZone() throws {
    let owner = config([
      EdgyCore.Binding(zone: .edge(.right), gesture: .slide, action: "audio.volume"),
      EdgyCore.Binding(zone: .edge(.left), gesture: .slide, action: "display.brightness"),
      EdgyCore.Binding(zone: .edge(.bottom), gesture: .slide, action: "apps.switcher"),
      EdgyCore.Binding(zone: .corner(.topLeft), gesture: .doubleTap, action: "mic.mute"),
      EdgyCore.Binding(zone: .corner(.topRight), gesture: .doubleTap, action: "audio.mute"),
    ])
    try mini(InspectorFixtures.model(config: owner), "mini-icons-every-zone")
    // Two icons along one bar (the bottom edge's three bindings show the first two).
    try mini(InspectorFixtures.model(), "mini-two-icons")
    try mini(InspectorFixtures.model(config: MirrorFixtures.splitConfig), "mini-split-edge")
    let unavailable = config([
      EdgyCore.Binding(zone: .edge(.right), gesture: .slide, action: "keyboard.backlight"),
      EdgyCore.Binding(zone: .edge(.left), gesture: .slide, action: "display.brightness"),
    ])
    try mini(InspectorFixtures.model(config: unavailable), "mini-unavailable-zone")
    try mini(InspectorFixtures.model(), "mini-hover-line", hover: .edge(.bottom))
  }

  @Test func miniHoverLineCopy() {
    let model = InspectorFixtures.model()
    let bottom = model.mirrorZones(forApp: nil, unavailableAsUnmapped: true).first { $0.zone == .edge(.bottom) }
    // Before the ruling (critique 22, design answer 1: the hover line shortens the zone name):
    // #expect(MiniMirrorView.hoverLine(bottom) == "Bottom edge: Previous Track, Next Track, Play/Pause")
    #expect(MiniMirrorView.hoverLine(bottom) == "Bottom: Previous Track, Next Track, Play/Pause")
    #expect(MiniMirrorView.hoverLine(nil) == "")
    #expect(bottom?.actions.count == 3)
  }

  // MARK: Late items: slide orientation, strip alignment, menu hover wash

  @Test func slideIconFollowsTheEdge() throws {
    #expect(GestureIcon.turnsSideways(.slide, on: .edge(.top)))
    #expect(GestureIcon.turnsSideways(.slide, on: .edge(.bottom, segment: 1, segments: 2)))
    #expect(!GestureIcon.turnsSideways(.slide, on: .edge(.left)))
    #expect(!GestureIcon.turnsSideways(.slide, on: nil))
    #expect(!GestureIcon.turnsSideways(.tap, on: .edge(.top)))
    let model = InspectorFixtures.model(
      config: config([
        EdgyCore.Binding(zone: .edge(.top), gesture: .slide, action: "audio.volume"),
        EdgyCore.Binding(zone: .edge(.right), gesture: .slide, action: "display.brightness"),
      ]))
    model.selectedZone = .edge(.top)
    try inspector(model, "inspector-top-edge-slide")
  }

  @Test func brokenConfigStripButtonsTopAlign() throws {
    let strip = WindowStripView(
      symbol: "exclamationmark.circle",
      text:
        "config.json has an error on line 14, column 3: Unexpected character 'x'. Edgy kept the last working settings."
    ) {
      HStack(spacing: 12) {
        TextAction(title: "Open config file") {}
        TextAction(title: "Replace with current settings") {}
      }
    }
    .frame(width: 760).background(Tokens.windowTint)
    try Snapshot.write(strip, folder: Self.folder, name: "strip-broken-config-wrapped")
  }

  @Test func menuRowHoverWash() throws {
    let rows = VStack(spacing: 0) {
      ForEach(Array(MenuRow.allCases.enumerated()), id: \.offset) { index, row in
        MenuRowButton(row: row, perform: {}, forceHover: index == 1)
      }
    }
    .padding(8).frame(width: 320).background(Tokens.windowTint)
    try Snapshot.write(rows, folder: Self.folder, name: "popover-menu-hover-wash")
  }

  // MARK: Batch-20 parameter shots (chief's list) and critique 15 S2

  @Test func holdKeysOpen() throws {
    let model = InspectorFixtures.model(
      config: config([
        EdgyCore.Binding(zone: .edge(.bottom), gesture: .longPress, action: "keyboard.hold", parameters: ["keys": "fn"])
      ]))
    model.selectedZone = .edge(.bottom)
    try inspector(model, "inspector-hold-keys-open", open: BindingKey(zone: .edge(.bottom), gesture: .longPress))
  }

  @Test func longPressDefaultAndChanged() throws {
    let base = InspectorFixtures.model(
      config: config([EdgyCore.Binding(zone: .corner(.topRight), gesture: .longPress, action: "audio.mute")]))
    base.selectedZone = .corner(.topRight)
    try inspector(base, "inspector-press-time-default", open: BindingKey(zone: .corner(.topRight), gesture: .longPress))
    let changed = InspectorFixtures.model(
      config: config([
        EdgyCore.Binding(
          zone: .corner(.topRight), gesture: .longPress, action: "audio.mute", parameters: ["holdMS": "800"])
      ]))
    changed.selectedZone = .corner(.topRight)
    try inspector(
      changed, "inspector-press-time-changed", open: BindingKey(zone: .corner(.topRight), gesture: .longPress))
  }

  @Test func switchAppsKeepOpenOffAndChangedSlider() throws {
    let model = InspectorFixtures.model(
      config: config([
        Binding(
          zone: .edge(.bottom), gesture: .slide, action: "apps.switcher",
          parameters: ["keepOpenMS": "0", "stepMM": "12"])
      ]))
    model.selectedZone = .edge(.bottom)
    try inspector(model, "inspector-switch-apps-keep-open-off", open: BindingKey(zone: .edge(.bottom), gesture: .slide))
  }

  @Test func repeatKeysOpen() throws {
    let model = InspectorFixtures.model(
      config: config([
        Binding(
          zone: .edge(.right), gesture: .slide, action: "keyboard.slideSteps",
          parameters: ["upKeys": "up", "downKeys": "down"])
      ]))
    model.selectedZone = .edge(.right)
    try inspector(model, "inspector-repeat-keys-open", open: BindingKey(zone: .edge(.right), gesture: .slide))
  }

  @Test func slideAndSwipesNote() throws {
    let model = InspectorFixtures.model(
      config: config([
        EdgyCore.Binding(zone: .edge(.right), gesture: .slide, action: "audio.volume"),
        EdgyCore.Binding(zone: .edge(.right), gesture: .swipe(.up), action: "system.missionControl"),
      ]))
    model.selectedZone = .edge(.right)
    try inspector(model, "inspector-slide-and-swipes-note")
  }
}
