import CoreGraphics
import EdgyCore
import EdgyRuntime
import Foundation
import Testing

@testable import EdgyUI

/// Batch 22: § Split control — names, the info note (from `SplitPlan`), one undo step, the hover
/// preview the mirror reads, hidden on corners and app tabs.
@MainActor @Suite struct SplitControlTests {
  private func name(_ id: ActionID) -> String {
    ["audio.volume": "Volume", "display.brightness": "Brightness", "audio.mute": "Mute"][id.rawValue] ?? id.rawValue
  }

  private func binding(_ zone: Zone, _ action: ActionID, _ gesture: GestureKind = .slide) -> EdgyCore.Binding {
    EdgyCore.Binding(zone: zone, gesture: gesture, action: action)
  }

  @Test func accessibilityNamesAreBRIEFs() {
    #expect((1...4).map(SplitNaming.accessibilityName(parts:)) == ["Whole edge", "2 parts", "3 parts", "4 parts"])
  }

  @Test func headingsReadTopToBottomAndLeftToRight() {
    // The runtime counts side edges bottom to top; headings read top to bottom.
    #expect(SplitNaming.heading(edge: .right, segment: 1, segments: 2) == "Upper half")
    #expect(SplitNaming.heading(edge: .right, segment: 0, segments: 2) == "Lower half")
    #expect(SplitNaming.heading(edge: .left, segment: 2, segments: 3) == "Top third")
    #expect(SplitNaming.heading(edge: .left, segment: 1, segments: 3) == "Middle third")
    #expect(SplitNaming.heading(edge: .left, segment: 0, segments: 3) == "Bottom third")
    #expect(SplitNaming.heading(edge: .bottom, segment: 0, segments: 2) == "Left half")
    #expect(SplitNaming.heading(edge: .top, segment: 3, segments: 4) == "Part 4")
    #expect(SplitNaming.heading(edge: .right, segment: 3, segments: 4) == "Part 1")
    let order = SplitNaming.readingOrder(edge: .right, segments: 2)
    #expect(order == [.edge(.right, segment: 1, segments: 2), .edge(.right, segment: 0, segments: 2)])
  }

  @Test func noteSaysWhatSplitPlanDoes() {
    let whole = [binding(.edge(.right), "audio.volume")]
    // Before the ruling (critique 22, design answer 3: the first part keeps the bindings, the others start empty), splitting copied, and the note said so:
    // #expect(SplitNaming.note(bindings: whole, edge: .right, from: 1, to: 2, name: name) == "Both halves keep Volume.")
    // #expect(
    //   SplitNaming.note(bindings: whole, edge: .right, from: 1, to: 3, name: name) == "All three thirds keep Volume.")
    #expect(
      SplitNaming.note(bindings: whole, edge: .right, from: 1, to: 2, name: name)
        == "Upper half keeps Volume; lower half starts empty.")
    // BRIEF § Split control's own example, word for word.
    #expect(
      SplitNaming.note(bindings: whole, edge: .right, from: 1, to: 3, name: name)
        == "Upper third keeps Volume; the other two start empty.")
    let bottom = [binding(.edge(.bottom), "audio.mute", .tap)]
    #expect(
      SplitNaming.note(bindings: bottom, edge: .bottom, from: 1, to: 2, name: name)
        == "Left half keeps Mute; right half starts empty.")
    // Fewer parts: the first part's bindings stay, the rest are named as dropped before the click.
    let thirds = [
      binding(.edge(.right, segment: 2, segments: 3), "audio.volume"),
      binding(.edge(.right, segment: 1, segments: 3), "display.brightness"),
    ]
    #expect(
      SplitNaming.note(bindings: thirds, edge: .right, from: 3, to: 2, name: name)
        == "Upper half keeps Volume; lower half starts empty; Brightness is dropped.")
    // Only the top third mapped; going to halves, the upper half keeps it.
    let top = [binding(.edge(.right, segment: 2, segments: 3), "audio.volume")]
    #expect(
      SplitNaming.note(bindings: top, edge: .right, from: 3, to: 2, name: name)
        == "Upper half keeps Volume; lower half starts empty.")
    // Merging keeps the binding at the middle of the edge and says what drops.
    let halves = [
      binding(.edge(.right, segment: 1, segments: 2), "audio.volume"),
      binding(.edge(.right, segment: 0, segments: 2), "display.brightness"),
    ]
    #expect(
      SplitNaming.note(bindings: halves, edge: .right, from: 2, to: 1, name: name)
        == "The whole edge keeps Volume; Brightness is dropped.")
    // Nothing on the edge, or no change: no note.
    #expect(SplitNaming.note(bindings: [], edge: .right, from: 1, to: 2, name: name) == nil)
    #expect(SplitNaming.note(bindings: whole, edge: .right, from: 1, to: 1, name: name) == nil)
    #expect(SplitNaming.note(bindings: whole, edge: .left, from: 1, to: 2, name: name) == nil)
  }

  @Test func splitIsOneUndoStep() throws {
    let model = PreviewFixtures.model()
    let before = model.editor.config
    let right = model.editor.config.defaultProfile.bindings.filter {
      if case .edge(.right, _, _) = $0.zone { return true }
      return false
    }
    #expect(!right.isEmpty)
    model.selectedZone = .edge(.right)
    model.split(.edge(.right), into: 2)
    #expect(model.splitCount(for: model.selectedZone!) == 2)
    #expect(model.editor.config != before)
    #expect(try model.editor.undo())
    #expect(model.editor.config == before)
  }

  @Test func noteComesFromTheOpenProfile() {
    let model = PreviewFixtures.model()
    let right = model.editor.config.defaultProfile.bindings.filter {
      if case .edge(.right, _, _) = $0.zone { return true }
      return false
    }
    let note = model.splitNote(for: .edge(.right), parts: 2)
    #expect(note == SplitNaming.note(bindings: right, edge: .right, from: 1, to: 2) { model.actionName($0) })
    // Before the ruling (critique 22, design answer 3: the first part keeps the bindings, the others start empty):
    // #expect(note?.hasPrefix("Both halves keep") == true)
    #expect(note?.hasPrefix("Upper half keeps") == true)
    #expect(note?.hasSuffix("lower half starts empty.") == true)
    #expect(model.splitNote(for: .corner(.topLeft), parts: 2) == nil)
  }

  @Test func hoverIsSharedWithTheMirrorPerModel() {
    let model = PreviewFixtures.model()
    #expect(model.splitPreview.hover == nil)
    model.splitPreview.hover = SplitPreview.Hover(edge: .right, parts: 3)
    #expect(model.splitPreview.hover == SplitPreview.Hover(edge: .right, parts: 3))
    #expect(PreviewFixtures.model().splitPreview.hover == nil)
  }
}

@MainActor @Suite struct PickerClarityTests {
  @Test func emptyStateCopyIsBRIEFs() {
    #expect(PickerCatalog.noMatches("xyz") == "No actions match \u{201C}xyz\u{201D}.")
    #expect(PickerCatalog.noMatches("  ") == nil)
    let model = InspectorFixtures.model()
    let none = PickerCatalog(
      groups: model.editor.catalogByCategory, gesture: .tap, query: "xyz", isAppTab: false,
      availability: model.editor.availability(of:))
    #expect(none.isEmpty)
    let some = PickerCatalog(
      groups: model.editor.catalogByCategory, gesture: .tap, query: "half", isAppTab: false,
      availability: model.editor.availability(of:))
    #expect(!some.isEmpty)
    // Search keeps the headers of groups that still have matches, and only those.
    #expect(some.sections.map(\.title) == ["Windows"])
  }

  @Test func rowRhythm() {
    #expect(PickerRow.height == 28 && PickerRow.tallHeight == 44 && PickerRow.iconColumn == 24)
    #expect(PickerGroupHeader.above == 14 && PickerGroupHeader.below == 4)
  }

  @Test func heightIsCappedByThePadInterior() {
    #expect(PickerPlacement.height(interiorHeight: 260) == 260)
    #expect(PickerPlacement.height(interiorHeight: 900) == 420)
  }

  /// A side-edge picker centres on its anchor but clears the corner tiles and their tabs, and gets
  /// shorter when the band between them is shorter than the picker.
  @Test func sideEdgePickerClearsCornerTilesAndTabs() {
    let container = CGRect(x: 0, y: 0, width: 900, height: 600)
    let rightBar = CGRect(x: 600, y: 140, width: 30, height: 300)
    let topRightTile = CGRect(x: 595, y: 90, width: 40, height: 40)
    let topRightTab = CGRect(x: 540, y: 123, width: 80, height: 26)
    let bottomRightTile = CGRect(x: 595, y: 450, width: 40, height: 40)
    let bottomRightTab = CGRect(x: 540, y: 431, width: 80, height: 26)
    let result = PickerPlacement.place(
      anchor: rightBar, zone: .edge(.right), avoiding: [topRightTile, topRightTab, bottomRightTile, bottomRightTab],
      size: CGSize(width: 320, height: 420), in: container)
    #expect(result.side == .left)
    let clearance = PickerPlacement.zoneClearance
    #expect(result.frame.minY >= topRightTab.maxY + clearance - 0.01)
    #expect(result.frame.maxY <= bottomRightTab.minY - clearance + 0.01)
    #expect(result.frame.height < 420)
    #expect(abs(result.frame.midY - rightBar.midY) < 1)
  }
}
