import Actions
import AppKit
import EdgyCore
import EdgyRuntime
import SwiftUI
import Testing

@testable import EdgyUI

/// Batch 33: critique 29 should-fixes on the inspector and the Name and Icon popover.
@MainActor
@Suite(.serialized)
struct Batch33InspectorTests {
  static let folder = "batch-33"
  static let slot = BindingKey(zone: .corner(.bottomRight), gesture: .longPress)

  func model(_ binding: EdgyCore.Binding) -> SettingsModel {
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
    #expect(try Snapshot.write(framed, folder: Self.folder, name: name).count == 2)
  }

  // MARK: Should-fix 3 / design answer 4: each drawing once

  @Test func identicalDrawingsShareOneCellNamingBoth() throws {
    let model = model(
      EdgyCore.Binding(
        zone: .corner(.bottomRight), gesture: .longPress, action: "keyboard.hold", parameters: ["keys": "fn"]))
    let groups = NameAndIconPopover.groups(model: model)
    let all = groups.flatMap(\.ids)
    #expect(all.count == Set(all).count)
    // No two cells draw the same thing.
    for (i, a) in all.enumerated() {
      for b in all[(i + 1)...] { #expect(ActionIcons.drawing(for: a) != ActionIcons.drawing(for: b), "\(a) \(b)") }
    }
    let brightness = BuiltInAction.keyboardBacklight
    let toggle = ActionID("keyboard.backlightToggle")
    #expect(all.contains(brightness) != all.contains(toggle), "exactly one cell for the shared drawing")
    let cell = NameAndIconPopover.cell(for: toggle, in: groups)
    #expect(NameAndIconPopover.cell(for: brightness, in: groups) == cell)
    let sharing = NameAndIconPopover.sharing(cell, in: groups)
    #expect(Set(sharing) == [brightness, toggle])
    #expect(
      NameAndIconPopover.tooltip(sharing, model: model)
        == sharing.map { model.actionName($0) }.joined(separator: " and "))
    #expect(NameAndIconPopover.tooltip(sharing, model: model).contains(" and "))
  }

  // MARK: Should-fix 2: the selection in view on open

  @Test func selectedIconIsAGridCell() throws {
    let model = model(
      EdgyCore.Binding(
        zone: .corner(.bottomRight), gesture: .longPress, action: "keyboard.hold", parameters: ["keys": "fn+space"]))
    let groups = NameAndIconPopover.groups(model: model)
    // The ringed cell (the scroll target) exists in the grid, far below the first group.
    let target = NameAndIconPopover.cell(for: "keyboard.hold", in: groups)
    #expect(groups.flatMap(\.ids).contains(target))
    #expect(groups.first?.ids.contains(target) == false)
    #expect(NameAndIconPopover.rows(Array(repeating: ActionID("a"), count: 23)).map(\.count) == [10, 10, 3])
    try shot(
      NameAndIconPopover(model: model, row: try row(model)), "name-and-icon-scrolled-to-selection", width: 320,
      height: 420)
  }

  // MARK: Should-fix 4: the field keeps its place

  @Test func fieldKeepsItsWidthWhenThenHides() throws {
    // Before the owner ruling 2026-11-10 ("+ Then…" became "Add another key" on its own line under
    // the field, so nothing sits beside the field any more), this measured the reserved width
    // beside it:
    // func width(_ keys: String, sequence: Bool) -> CGFloat {
    //   let view = KeyRecorderField(stored: keys, isHold: false, allowsSequence: sequence, recorder: nil) { _ in }
    //   return NSHostingView(rootView: view).fittingSize.width
    // }
    // func trailing(_ keys: String) -> CGFloat { width(keys, sequence: true) - width(keys, sequence: false) }
    // let two = trailing("ctrl+b n")
    // let four = trailing("ctrl+b n cmd+k x")
    // let thenWidth = NSHostingView(
    //   rootView: QuietTextButton(title: KeyRecorderField.thenLabel, tooltip: "") {}
    // ).fittingSize.width
    // #expect(four >= thenWidth, "the hidden button still holds its width")
    // #expect(abs(two - four) <= 0.5, "two \(two), four \(four)")
    // Now: the field's real frame in the row, with the button showing (two steps) or hidden (four).
    func field(_ keys: String) throws -> CGRect {
      let view = LabeledParameter(label: "Keys", labelWidth: 80) {
        KeyRecorderField(stored: keys, isHold: false, allowsSequence: true, recorder: nil) { _ in }
      }
      return try #require(Batch34RecorderTests.Laid(view).frames[.field])
    }
    let two = try field("ctrl+b n")
    let four = try field("ctrl+b n cmd+k x")
    #expect(abs(two.minX - four.minX) <= 0.5, "two \(two.minX), four \(four.minX)")
    #expect(abs(two.width - four.width) <= 0.5, "two \(two.width), four \(four.width)")
  }

  // MARK: Should-fix 1: one alignment for sub-lines

  @Test func overriddenShortcutRowSubLinesShot() throws {
    var config = PreviewFixtures.demoConfig
    let key = BindingKey(zone: .edge(.bottom), gesture: .swipe(.left))
    config.appProfiles[PreviewFixtures.wayfare]?.bindings.removeAll { $0.key == key }
    config.appProfiles[PreviewFixtures.wayfare]?.bindings.append(
      EdgyCore.Binding(
        zone: .edge(.bottom), gesture: .swipe(.left), action: "keyboard.shortcut",
        parameters: ["keys": "cmd+shift+leftbracket"]))
    let model = InspectorFixtures.model(config: config)
    model.selectedProfile = .app(PreviewFixtures.wayfare)
    model.selectedZone = .edge(.bottom)
    try shot(InspectorView(model: model), "inspector-overridden-shortcut-sub-lines", height: 420)
  }
}
