import Actions
import AppKit
import EdgyCore
import EdgyRuntime
import Foundation
import SwiftUI
import Testing

@testable import EdgyUI

/// Batch 29 (BRIEF § Your own name and icon, § Key sequences): the pad tab, the zone icons and the
/// mini mirror's hover line read a binding's custom name and icon; a key sequence reads "⌃B, N".
@MainActor
@Suite(.serialized)
struct Batch29MirrorTests {
  static let folder = "batch-29"

  /// The push-to-talk binding the brief names "Dictate", with the Dictation icon.
  static let dictate = EdgyCore.Binding(
    zone: .corner(.bottomRight), gesture: .longPress, action: BuiltInAction.keyboardHold,
    parameters: ["keys": "fn"])

  private func model(_ extra: [EdgyCore.Binding]) -> SettingsModel {
    var config = PreviewFixtures.demoConfig
    config.defaultProfile.bindings += extra
    return PreviewFixtures.model(config: config)
  }

  /// Names `binding`'s slot on Default through the editor (one undo step, as the inspector does).
  private func named(_ binding: EdgyCore.Binding, name: String?, icon: ActionID?, extra: [EdgyCore.Binding] = []) throws
    -> SettingsModel
  {
    let model = model([binding] + extra)
    try model.editor.setNameAndIcon(binding.key, in: .default, name: name, icon: icon)
    return model
  }

  private func zone(_ model: SettingsModel, _ zone: Zone, mini: Bool = false) throws -> MirrorZone {
    try #require(model.mirrorZones(forApp: nil, unavailableAsUnmapped: mini).first { $0.zone == zone })
  }

  private func pad(_ model: SettingsModel) -> MirrorPad {
    MirrorPad(
      geometry: MirrorGeometry(
        sensorSizeMM: PreviewFixtures.externalPad.sensorSizeMM, settings: model.editor.config.gestures,
        pointsPerMM: Tokens.mirrorPointsPerMM), zones: model.mirrorZones(forApp: nil), selected: nil)
  }

  private func shootPad(_ model: SettingsModel, _ name: String) throws {
    let urls = try Snapshot.write(
      PadMirrorView(model: model).padding(28).background(Tokens.windowTint), folder: Self.folder, name: name)
    #expect(urls.count == 2)
  }

  private func shootMini(_ model: SettingsModel, _ name: String, hover: Zone? = nil) throws {
    model.simulate(WindowFixtures.status())
    let view = MiniMirrorView(model: model, frontmostApp: nil).hovering(hover)
      .hoverLineWidth(PopoverMetrics.width - 2 * PopoverMetrics.inset)
      .padding(16).frame(width: PopoverMetrics.width).background(Tokens.windowTint)
    #expect(try Snapshot.write(view, folder: Self.folder, name: name).count == 2)
  }

  // MARK: Pad tab

  @Test func padTabUsesTheCustomNameInEveryForm() throws {
    let model = try named(Self.dictate, name: "Dictate", icon: BuiltInAction.dictation)
    let corner = try zone(model, .corner(.bottomRight))
    #expect(corner.label == "Dictate")
    // The custom name replaces the short-form rule: no "fn", no "Hold Keys" short name.
    #expect(corner.labelForms == ["Dictate"])
    let fit = pad(model).fittedLabel(corner, placement: pad(model).labelPlacement(corner))
    #expect(fit.text == "Dictate")
    #expect(fit.clipWidth == nil)
    try shootPad(model, "pad-tab-custom-short")
  }

  @Test func longCustomNameFadesAndNeverEllipsis() throws {
    let long = "Whole-team standup memo"  // 23 characters, inside the 24 cap
    let model = try named(Self.dictate, name: long, icon: nil)
    let corner = try zone(model, .corner(.bottomRight))
    #expect(corner.labelForms == [long])
    let mirror = pad(model)
    let fit = mirror.fittedLabel(corner, placement: mirror.labelPlacement(corner))
    #expect(fit.text == long)
    // Before critique 29 design answer 3 (corner tabs grow to 40% of their edge), this name clipped:
    // #expect(fit.clipWidth != nil)
    #expect(fit.clipWidth == nil)
    #expect(!fit.text.contains("…"))
    // A name wider than 40% of the edge still fades, never "…".
    let wide = String(repeating: "W", count: SettingsEditor.customNameLimit)
    let wideModel = try named(Self.dictate, name: wide, icon: nil)
    let wideCorner = try zone(wideModel, .corner(.bottomRight))
    let wideFit = pad(wideModel).fittedLabel(wideCorner, placement: pad(wideModel).labelPlacement(wideCorner))
    #expect(wideFit.text == wide)
    #expect(wideFit.clipWidth != nil)
    #expect(!wideFit.text.contains("…"))
    try shootPad(model, "pad-tab-custom-long")
  }

  /// Without a custom name, Hold Keys reads its keys (BRIEF § Bindings that name their target).
  @Test func noCustomNameReadsTheTarget() throws {
    let model = model([Self.dictate])
    let corner = try zone(model, .corner(.bottomRight))
    #expect(corner.label == "fn")
    #expect(corner.labelForms == ["fn"])
    #expect(corner.symbol == BuiltInAction.keyboardHold)
    #expect(corner.zoneIcon == .action(BuiltInAction.keyboardHold))
  }

  @Test func aCustomNamedMemberNeverJoinsAPair() {
    let catalog = PreviewFixtures.model().mirrorCatalog
    let previous = EdgyCore.Binding(zone: .edge(.bottom), gesture: .swipe(.left), action: BuiltInAction.previous)
    var next = EdgyCore.Binding(zone: .edge(.bottom), gesture: .swipe(.right), action: BuiltInAction.next)
    #expect(ZoneLabel.text(for: [previous, next], catalog: catalog) == "Tracks")
    next.customName = "Skip"
    #expect(ZoneLabel.text(for: [previous, next], catalog: catalog) == "Previous Track and Skip")
    #expect(ZoneLabel.shorterForms(for: [previous, next], catalog: catalog).allSatisfy { $0.hasSuffix("Skip") })
  }

  @Test func sequenceShowsItsShortValueOnThePadTab() throws {
    let shortcut = EdgyCore.Binding(
      zone: .corner(.bottomLeft), gesture: .doubleTap, action: BuiltInAction.keyboardShortcut,
      parameters: ["keys": "ctrl+b n"])
    // Before critique 29 must-fix 1, BRIEF "How a key combo is written": no space inside a combo:
    // #expect(ZoneLabel.shortValue(for: shortcut) == "⌃ B, N")
    #expect(ZoneLabel.shortValue(for: shortcut) == "⌃B, N")
    let model = model([shortcut])
    let corner = try zone(model, .corner(.bottomLeft))
    // Before critique 29 must-fix 1, BRIEF "How a key combo is written": no space inside a combo:
    // #expect(corner.labelForms.contains("⌃ B, N"))
    #expect(corner.labelForms.contains("⌃B, N"))
    let mirror = pad(model)
    // Before critique 29 must-fix 1, BRIEF "How a key combo is written": no space inside a combo:
    // #expect(mirror.fittedLabel(corner, placement: mirror.labelPlacement(corner)).text == "⌃ B, N")
    #expect(mirror.fittedLabel(corner, placement: mirror.labelPlacement(corner)).text == "⌃B, N")
    try shootPad(model, "pad-tab-sequence")
  }

  // MARK: Zone icons

  @Test func zoneIconsDrawTheCustomIcon() throws {
    let model = try named(Self.dictate, name: "Dictate", icon: BuiltInAction.dictation)
    let full = try zone(model, .corner(.bottomRight))
    #expect(full.symbol == BuiltInAction.dictation)
    let mini = try zone(model, .corner(.bottomRight), mini: true)
    #expect(mini.symbol == BuiltInAction.dictation)
    #expect(mini.icons == [.action(BuiltInAction.dictation)])
    // The real action stays: pairs and short names are read from it, never from the icon.
    #expect(mini.actions == [BuiltInAction.keyboardHold])
    try shootMini(model, "mini-mirror-custom-icon")
  }

  @Test func sideBarIconsDrawTheCustomIcon() throws {
    let tap = EdgyCore.Binding(zone: .edge(.top), gesture: .tap, action: BuiltInAction.playPause)
    let model = try named(tap, name: nil, icon: BuiltInAction.dictation)
    let top = try zone(model, .edge(.top), mini: true)
    #expect(top.icons.first == .action(BuiltInAction.dictation))
    #expect(top.actions == [BuiltInAction.playPause])
  }

  // MARK: Hover line

  @Test func hoverLineReadsTheCustomName() throws {
    let model = try named(Self.dictate, name: "Dictate", icon: BuiltInAction.dictation)
    let corner = try zone(model, .corner(.bottomRight), mini: true)
    #expect(MiniMirrorView.hoverLine(corner) == "Bottom-right: Dictate")
    // Narrow: the custom name is never swapped for a short name.
    #expect(MiniMirrorView.hoverLineForms(corner) == ["Bottom-right: Dictate"])
    let plain = try zone(self.model([Self.dictate]), .corner(.bottomRight), mini: true)
    #expect(MiniMirrorView.hoverLine(plain) == "Bottom-right: fn")
    try shootMini(model, "hover-line-custom-name", hover: .corner(.bottomRight))
  }

  // MARK: Bindings that name their target (add-on item 11)

  static let quillpad = "com.example.quillpad"

  private func appPaths() -> [String: String] {
    Dictionary(IconApps.list.map { ($0.bundleID, $0.path) }, uniquingKeysWith: { first, _ in first })
  }

  private func shootPadWithApps(_ model: SettingsModel, _ name: String) throws {
    let view = PadMirrorView(model: model).padding(28).background(Tokens.windowTint)
      .environment(\.mirrorAppPaths, appPaths())
    #expect(try Snapshot.write(view, folder: Self.folder, name: name).count == 2)
  }

  private func config(replacing zones: [Zone], with bindings: [EdgyCore.Binding]) -> SettingsModel {
    var config = PreviewFixtures.demoConfig
    config.defaultProfile.bindings.removeAll { zones.contains($0.zone) }
    config.defaultProfile.bindings += bindings
    return PreviewFixtures.model(config: config)
  }

  /// The bug: a left-edge double-tap on Keyboard Shortcut ⌃Tab read "Keyboard Shortcut" (its keys
  /// were only a shorter form, used when the full name didn't fit), while a corner on fn Space read
  /// its keys. A Keyboard Shortcut always shows its keys, on edges too.
  @Test func edgeShortcutShowsItsKeys() throws {
    let edge = EdgyCore.Binding(
      zone: .edge(.left), gesture: .doubleTap, action: BuiltInAction.keyboardShortcut,
      parameters: ["keys": "ctrl+tab"])
    let corner = EdgyCore.Binding(
      zone: .corner(.topLeft), gesture: .longPress, action: BuiltInAction.keyboardHold,
      parameters: ["keys": "fn+space"])
    let model = config(replacing: [.edge(.left), .corner(.topLeft)], with: [edge, corner])
    let left = try zone(model, .edge(.left))
    // Before critique 29 must-fix 1, BRIEF "How a key combo is written": no space inside a combo:
    // #expect(left.label == "⌃ Tab")
    #expect(left.label == "⌃Tab")
    #expect(!left.labelForms.contains("Keyboard Shortcut"))
    let mirror = pad(model)
    // Before critique 29 must-fix 1, BRIEF "How a key combo is written": no space inside a combo:
    // #expect(mirror.fittedLabel(left, placement: mirror.labelPlacement(left)).text == "⌃ Tab")
    #expect(mirror.fittedLabel(left, placement: mirror.labelPlacement(left)).text == "⌃Tab")
    #expect(try zone(model, .corner(.topLeft)).label == "fn Space")
    try shootPad(model, "pad-shortcut-edge-and-corner")
  }

  /// The three levels on one binding: the action's own, then the target, then the custom name.
  @Test func precedenceOnTabsAndIcons() throws {
    let catalog = PreviewFixtures.model().mirrorCatalog
    let empty = EdgyCore.Binding(zone: .corner(.topRight), gesture: .doubleTap, action: BuiltInAction.openApp)
    // Action level (parameter still empty): the needs-a-parameter "…" and the action's icon.
    #expect(ZoneLabel.name(for: empty, catalog: catalog) == "Open App…")
    #expect(BindingNaming.icon(empty).icon == .action(BuiltInAction.openApp))
    // Target level: the app's name and its mark.
    var app = empty
    app.parameters = ["bundleID": Self.quillpad]
    let model = config(replacing: [.corner(.topRight)], with: [app])
    let corner = try zone(model, .corner(.topRight))
    #expect(corner.label == "Quillpad")
    #expect(corner.zoneIcon == .app(bundleID: Self.quillpad))
    #expect(corner.symbol == BuiltInAction.openApp)
    // Custom level: the custom name and icon win over the target.
    try model.editor.setNameAndIcon(app.key, in: .default, name: "Notes", icon: BuiltInAction.dictation)
    let named = try zone(model, .corner(.topRight))
    #expect(named.label == "Notes")
    #expect(named.zoneIcon == .action(BuiltInAction.dictation))
    // No target: the action's own name and icon.
    let mic = try zone(model, .corner(.topLeft))
    #expect(mic.zoneIcon == .action(mic.actions[0]))
  }

  @Test func twoOpenAppCornersReadTheirApps() throws {
    let wayfare = EdgyCore.Binding(
      zone: .corner(.topRight), gesture: .doubleTap, action: BuiltInAction.openApp,
      parameters: ["bundleID": PreviewFixtures.wayfare])
    let quillpad = EdgyCore.Binding(
      zone: .corner(.bottomLeft), gesture: .doubleTap, action: BuiltInAction.openApp,
      parameters: ["bundleID": Self.quillpad])
    let model = config(replacing: [.corner(.topRight), .corner(.bottomLeft)], with: [wayfare, quillpad])
    #expect(try zone(model, .corner(.topRight)).label == "Wayfare")
    #expect(try zone(model, .corner(.bottomLeft)).label == "Quillpad")
    try shootPadWithApps(model, "pad-two-open-app-corners")
  }

  @Test func urlAndFileTabsReadHostAndFile() throws {
    let url = EdgyCore.Binding(
      zone: .corner(.bottomLeft), gesture: .doubleTap, action: BuiltInAction.openURL,
      parameters: ["url": "https://www.example.com/plans"])
    let file = EdgyCore.Binding(
      zone: .corner(.bottomRight), gesture: .doubleTap, action: BuiltInAction.openFile,
      parameters: ["path": "~/Documents/report.pdf"])
    let model = config(replacing: [.corner(.bottomLeft), .corner(.bottomRight)], with: [url, file])
    let left = try zone(model, .corner(.bottomLeft))
    #expect(left.label == "example.com")
    #expect(left.zoneIcon == .action(BuiltInAction.openURL))
    let right = try zone(model, .corner(.bottomRight))
    #expect(right.label == "report.pdf")
    #expect(right.zoneIcon == .action(BuiltInAction.openFile))
    try shootPad(model, "pad-url-and-file-tabs")
  }

  @Test func hoverLineAndMiniMirrorWithAnApp() throws {
    let wayfare = EdgyCore.Binding(
      zone: .corner(.topRight), gesture: .doubleTap, action: BuiltInAction.openApp,
      parameters: ["bundleID": PreviewFixtures.wayfare])
    let quillpad = EdgyCore.Binding(
      zone: .corner(.bottomLeft), gesture: .doubleTap, action: BuiltInAction.openApp,
      parameters: ["bundleID": Self.quillpad])
    let model = config(replacing: [.corner(.topRight), .corner(.bottomLeft)], with: [wayfare, quillpad])
    let corner = try zone(model, .corner(.topRight), mini: true)
    #expect(MiniMirrorView.hoverLine(corner) == "Top-right: Wayfare")
    #expect(corner.icons == [.app(bundleID: PreviewFixtures.wayfare)])
    let other = try zone(model, .corner(.bottomLeft), mini: true)
    #expect(MiniMirrorView.hoverLine(other) == "Bottom-left: Quillpad")
    model.simulate(WindowFixtures.status())
    let view = MiniMirrorView(model: model, frontmostApp: nil).hovering(.corner(.topRight))
      .hoverLineWidth(PopoverMetrics.width - 2 * PopoverMetrics.inset)
      .padding(16).frame(width: PopoverMetrics.width).background(Tokens.windowTint)
      .environment(\.mirrorAppPaths, appPaths())
    #expect(try Snapshot.write(view, folder: Self.folder, name: "mini-mirror-app-mark").count == 2)
  }
}
