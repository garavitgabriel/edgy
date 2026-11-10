import EdgyCore
import EdgyRuntime
import SwiftUI
import Testing

@testable import EdgyUI

// Batch 29, item 2: "Name and Icon…" in the row's "…" menu, its popover, and the row with a custom
// name (BRIEF § Binding parameters → "Your own name and icon for a binding"). Fixtures only.

@MainActor
@Suite(.serialized) struct Batch29InspectorTests {
  static let folder = "batch-29"
  static let slot = BindingKey(zone: .corner(.bottomRight), gesture: .longPress)
  static let hold = EdgyCore.Binding(
    zone: .corner(.bottomRight), gesture: .longPress, action: "keyboard.hold", parameters: ["keys": "fn+space"])

  func model(_ binding: EdgyCore.Binding = hold) -> SettingsModel {
    var config = PreviewFixtures.demoConfig
    config.defaultProfile.bindings.removeAll { $0.zone == .corner(.bottomRight) }
    config.defaultProfile.bindings.append(binding)
    let model = InspectorFixtures.model(config: config)
    model.selectedZone = .corner(.bottomRight)
    return model
  }

  func row(_ model: SettingsModel) throws -> InspectorRow {
    try #require(model.inspectorRows(for: Self.slot.zone).first { $0.id == Self.slot })
  }

  func shot(_ view: some View, _ name: String, width: CGFloat = 360, height: CGFloat = 220) throws {
    let framed = view.frame(width: width, height: height, alignment: .top)
      .background(Tokens.padTop.opacity(0.35)).background(Tokens.windowTint)
    try Snapshot.write(framed, folder: Self.folder, name: name)
  }

  @Test func menuOffersNameAndIcon() {
    #expect(RowMenu.items(for: nil).map(\.title).contains("Name and Icon…"))
    #expect(RowMenu.items(for: .overridden).first { $0.title == "Name and Icon…" }?.enabled == true)
    #expect(RowMenu.items(for: .turnedOff).first { $0.title == "Name and Icon…" }?.enabled == false)
  }

  @Test func popoverSavesNameAndIconAsOneStepAndResets() throws {
    let model = model()
    let row = try row(model)
    model.setNameAndIcon(row, name: "  Dictate ", icon: "system.dictation")
    let named = try self.row(model)
    #expect(named.binding.customName == "Dictate")
    #expect(named.binding.customIcon == "system.dictation")
    #expect(try model.editor.undo())
    #expect(try self.row(model).binding.customName == nil)
    #expect(try model.editor.redo())
    model.setNameAndIcon(named, name: nil, icon: nil)
    #expect(try self.row(model).binding.customName == nil)
    #expect(try self.row(model).binding.customIcon == nil)
  }

  @Test func keepIconLeavesTheCurrentIcon() throws {
    let model = model()
    model.setNameAndIcon(try row(model), name: "A", icon: "system.dictation")
    model.setNameAndIcon(try row(model), name: "B", icon: nil, keepIcon: true)
    #expect(try row(model).binding.customName == "B")
    #expect(try row(model).binding.customIcon == "system.dictation")
  }

  @Test func iconGridIsGroupedLikeThePickerAndOnlyDrawnIcons() throws {
    let groups = NameAndIconPopover.groups(model: model())
    let titles = groups.map(\.title)
    let pickerOrder = ["Sound", "Display", "Media", "System", "Windows", "Apps", "Keyboard", "Shortcuts"]
    #expect(titles == pickerOrder.filter { titles.contains($0) })
    #expect(titles.first == "Sound")
    let all = groups.flatMap(\.ids)
    #expect(!all.contains(.doNothing))
    #expect(all.allSatisfy { ActionIcons.has($0) })
    #expect(all.contains("system.dictation"))
    let keyboard = try #require(groups.first { $0.title == "Keyboard" })
    #expect(keyboard.ids.first == "keyboard.shortcut", "icon-table order, like the picker")
    #expect(NameAndIconPopover.width <= 320)
    #expect(NameAndIconPopover.cell == 28)
    #expect(NameAndIconPopover.iconSize == 16)
  }

  @Test func rowSubLineNamesTheRealActionAndParameter() throws {
    let model = model()
    #expect(BindingRowView.realAction(try row(model).binding, model: model) == "Hold Keys: fn Space")
    let shortcut = EdgyCore.Binding(
      zone: .corner(.bottomRight), gesture: .longPress, action: "keyboard.shortcut", parameters: ["keys": "ctrl+b n"])
    #expect(BindingRowView.realAction(shortcut, model: model) == "Keyboard Shortcut: ⌃ B, N")
    let empty = EdgyCore.Binding(zone: .corner(.bottomRight), gesture: .longPress, action: "keyboard.hold")
    #expect(BindingRowView.realAction(empty, model: model) == "Hold Keys: Needs keys")
    let mute = EdgyCore.Binding(zone: .corner(.bottomRight), gesture: .tap, action: "audio.mute")
    #expect(BindingRowView.realAction(mute, model: model) == "Mute")
  }

  @Test func renamingAnInheritedRowOnAnAppTabMakesAnOverrideWithRevert() throws {
    let model = model()
    let app = "com.example.wayfare"
    if model.editor.config.appProfiles[app] == nil { try model.editor.addAppProfile(bundleID: app) }
    try model.editor.revertToDefault(Self.slot, forApp: app)
    model.selectedProfile = .app(app)
    let inherited = try row(model)
    #expect(inherited.source == .inherited)
    model.setNameAndIcon(inherited, name: "Dictate", icon: nil)
    let overridden = try row(model)
    #expect(overridden.source == .overridden)
    #expect(overridden.binding.customName == "Dictate")
    #expect(overridden.binding.action == "keyboard.hold")
    model.revert(overridden)
    #expect(try row(model).source == .inherited)
    #expect(try row(model).binding.customName == nil)
  }

  // MARK: Shots

  @Test func popoverEmptyShot() throws {
    let model = model()
    try shot(NameAndIconPopover(model: model, row: try row(model)), "name-and-icon-empty", width: 320, height: 420)
  }

  @Test func popoverSetShot() throws {
    let model = model()
    model.setNameAndIcon(try row(model), name: "Dictate", icon: "system.dictation")
    try shot(NameAndIconPopover(model: model, row: try row(model)), "name-and-icon-set", width: 320, height: 440)
  }

  @Test func rowWithSubLineShot() throws {
    let model = model()
    model.setNameAndIcon(try row(model), name: "Dictate", icon: "system.dictation")
    try shot(InspectorView(model: model), "inspector-row-custom-name")
  }
}
