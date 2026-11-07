import Actions
import AppKit
import EdgyCore
import EdgyRuntime
import Foundation
import SwiftUI
import Testing

@testable import EdgyUI

/// Batch 27 (critique 25, the Edgy mark, findable Hold Keys): tests and shots in
/// `docs/design/build-shots/batch-27/`, light and dark.
@MainActor
@Suite(.serialized)
struct Batch27SnapshotTests {
  static let folder = "batch-27"

  private func window(_ model: SettingsModel, _ name: String) throws {
    let view = SettingsWindowView(model: model, apps: IconApps.list)
    #expect(try Snapshot.write(view, folder: Self.folder, name: name, size: SettingsWindowView.minimumSize).count == 2)
  }

  private func picker(_ model: SettingsModel, _ name: String, query: String = "", height: CGFloat) throws {
    let view = ActionPickerView(model: model, query: query)
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

  private func config(_ bindings: [EdgyCore.Binding]) -> EdgyConfig {
    var config = PreviewFixtures.demoConfig
    config.defaultProfile.bindings = bindings
    return config
  }

  // MARK: 2. Critique 25 should-fix 3: the selection after a split

  /// Whole right edge → thirds, after the click: the upper third (the part that keeps the
  /// bindings) is selected and its rows are in the inspector.
  @Test func splitSelectsFirstPartShot() throws {
    let model = PreviewFixtures.model()
    model.selectedZone = .edge(.right)
    model.split(.edge(.right), into: 3)
    #expect(model.selectedZone == .edge(.right, segment: 2, segments: 3))
    #expect(!model.inspectorRows(for: model.selectedZone!).isEmpty)
    try window(model, "split-selects-first-part")
  }

  /// Critique 25 should-fix 1: the "real icon" app is a mid-tone icon, not Edgy's own cream one.
  @Test func realIconFixtureIsMidTone() throws {
    let wayfare = try #require(IconApps.list.first { $0.name == "Wayfare" })
    #expect(AppMark.hasIcon(wayfare.path))
    let icon = try #require(AppMark.icon(wayfare.path))
    let rep = try #require(
      icon.bestRepresentation(for: NSRect(x: 0, y: 0, width: 64, height: 64), context: nil, hints: nil))
    let bitmap = NSBitmapImageRep(cgImage: try #require(rep.cgImage(forProposedRect: nil, context: nil, hints: nil)))
    let centre = try #require(
      bitmap.colorAt(x: bitmap.pixelsWide / 4, y: bitmap.pixelsHigh / 2)?.usingColorSpace(.deviceRGB))
    // Mid-tone: clearly darker than the window's cream and clearly lighter than `ink`.
    #expect(centre.brightnessComponent > 0.3 && centre.brightnessComponent < 0.75, "\(centre)")
    let model = PreviewFixtures.model()
    model.selectedZone = .edge(.right)
    try window(model, "window-app-marks")
  }

  // MARK: 3. The Edgy mark (BRIEF § Window identity (a))

  @Test func titleBarIsTheInkMark() throws {
    #expect(WindowIdentity.width == 26 && WindowIdentity.height == 18)
    #expect(WindowIdentity.width == Tokens.titleMarkWidth && WindowIdentity.height == Tokens.titleMarkHeight)
    #expect(WindowMetrics.titleBarLeading == WindowMetrics.trafficLightsTrailing + Tokens.titleIconLeading)
    #expect(WindowIdentity.label == "Edgy")
    let mark = try #require(WindowIdentity.mark, "mark-edgy.pdf ships in the EdgyUI bundle")
    #expect(!mark.isTemplate)
    // The 16:11 V3 drawing, filling the 26 × 18 frame.
    #expect(abs(mark.size.width / mark.size.height - 16.0 / 11.0) < 0.01)
    // The bundled mark is the exported asset, byte for byte.
    let exported = try Data(contentsOf: Snapshot.repoRoot.appendingPathComponent("docs/design/assets/mark-edgy.pdf"))
    let bundled = try #require(
      Bundle.module.url(forResource: "mark-edgy", withExtension: "pdf", subdirectory: "Assets"))
    #expect(try Data(contentsOf: bundled) == exported)
    let model = PreviewFixtures.model()
    model.selectedZone = .edge(.right)
    try window(model, "window-identity")
    // Zoomed on the title bar: the window's own top row, cropped to the leading half.
    let bar = SettingsWindowView(model: model, apps: IconApps.list)
      .frame(
        width: SettingsWindowView.minimumSize.width, height: SettingsWindowView.minimumSize.height,
        alignment: .topLeading
      )
      .frame(width: 520, height: WindowMetrics.tabBarHeight, alignment: .topLeading)
      .clipped()
      .scaleEffect(2, anchor: .topLeading)
      .frame(width: 1040, height: 2 * WindowMetrics.tabBarHeight, alignment: .topLeading)
    try Snapshot.write(bar, folder: Self.folder, name: "title-bar-zoom")
  }

  // MARK: 4. Hold Keys, findable

  @Test func holdKeysSubLineDescribesUse() throws {
    let model = InspectorFixtures.model()
    let catalog = PickerCatalog(
      groups: model.editor.catalogByCategory, gesture: .longPress, isAppTab: false,
      availability: { _ in .available })
    let hold = try #require(catalog.selectable.first { $0.id == "keyboard.hold" })
    #expect(hold.subtitle == "Hold any app's shortcut while your finger rests")
    // It's the only available action with a sub-line.
    #expect(catalog.selectable.filter { $0.subtitle != nil }.map(\.id) == ["keyboard.hold"])
    // An unavailable or limited reason still wins.
    let limited = PickerCatalog(
      groups: model.editor.catalogByCategory, gesture: .longPress, isAppTab: false,
      availability: { $0 == "keyboard.hold" ? .limited(reason: "Needs Accessibility.") : .available })
    #expect(limited.selectable.first { $0.id == "keyboard.hold" }?.subtitle == "Needs Accessibility.")
    let unavailable = PickerCatalog(
      groups: model.editor.catalogByCategory, gesture: .longPress, isAppTab: false,
      availability: { $0 == "keyboard.hold" ? .unavailable(reason: "Not on this Mac.") : .available })
    #expect(unavailable.selectable.first { $0.id == "keyboard.hold" }?.subtitle == "Not on this Mac.")

    model.selectedZone = .edge(.left)
    model.picking = PickerTarget(zone: .edge(.left), gesture: .longPress)
    try picker(model, "picker-hold-keys-subline", height: 1100)
  }

  @Test func searchFindsHoldKeysByUse() throws {
    let model = InspectorFixtures.model()
    for query in ["hold", "push to talk", "talk", "dictation", "voice", "Talk", "Push to"] {
      let catalog = PickerCatalog(
        groups: model.editor.catalogByCategory, gesture: .longPress, query: query, isAppTab: false,
        availability: { _ in .available })
      #expect(catalog.selectable.contains { $0.id == "keyboard.hold" }, "\(query)")
    }
    // A word it isn't about doesn't find it.
    let other = PickerCatalog(
      groups: model.editor.catalogByCategory, gesture: .longPress, query: "volume", isAppTab: false,
      availability: { _ in .available })
    #expect(!other.selectable.contains { $0.id == "keyboard.hold" })

    model.selectedZone = .edge(.left)
    model.picking = PickerTarget(zone: .edge(.left), gesture: .longPress)
    try picker(model, "picker-search-talk", query: "talk", height: 300)
  }

  @Test func holdKeysEmptyHintUnderTheRecorder() throws {
    let keys = try #require(
      InspectorFixtures.model().editor.validator.descriptor(for: "keyboard.hold")?.parameters.first {
        $0.kind == .keyCombo
      })
    let empty = Binding(zone: .edge(.left), gesture: .longPress, action: "keyboard.hold")
    #expect(
      HoldKeysHint.text(keys, in: empty)
        == "Press the shortcut your app uses while held. For a key like fn alone, hold it a second, then let go.")
    var set = empty
    set.parameters[keys.key] = "fn"
    #expect(HoldKeysHint.text(keys, in: set) == nil)
    // Only Hold Keys gets it.
    let shortcut = Binding(zone: .edge(.left), gesture: .tap, action: "keyboard.shortcut")
    #expect(HoldKeysHint.text(keys, in: shortcut) == nil)

    let model = InspectorFixtures.model(config: config([empty]))
    model.selectedZone = .edge(.left)
    try inspector(model, "inspector-hold-keys-empty", open: BindingKey(zone: .edge(.left), gesture: .longPress))
    let fn = InspectorFixtures.model(config: config([set]))
    fn.selectedZone = .edge(.left)
    try inspector(fn, "inspector-hold-keys-fn", open: BindingKey(zone: .edge(.left), gesture: .longPress))
  }
}
