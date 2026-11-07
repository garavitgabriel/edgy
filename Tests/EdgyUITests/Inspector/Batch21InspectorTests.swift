import Actions
import EdgyCore
import EdgyRuntime
import Foundation
import Testing

@testable import EdgyUI

/// Batch 21: one open binding, the pending row, parameter rows and names.
@MainActor
struct Batch21InspectorTests {
  var catalog: [ActionDescriptor] { makeLiveActionRegistry(settings: .defaults).available }

  func descriptor(_ id: ActionID) -> ActionDescriptor? { catalog.first { $0.id == id } }

  // MARK: One open binding

  @Test func noBindingIsOpenUntilOneIsClicked() {
    let model = InspectorFixtures.model()
    let rows = model.inspectorRows(for: .edge(.bottom))
    #expect(rows.count == 3)
    #expect(model.openBinding(in: .edge(.bottom), rows: rows) == nil)
  }

  @Test func clickingARowOpensItAndClosesTheOther() {
    let model = InspectorFixtures.model()
    let zone = Zone.edge(.bottom)
    let rows = model.inspectorRows(for: zone)
    model.openRow(rows[0].id)
    // While its picker is open, nothing is open; dismissing the picker leaves the clicked row open.
    #expect(model.openBinding(in: zone, rows: rows) == nil)
    model.picking = nil
    #expect(model.openBinding(in: zone, rows: rows) == rows[0].id)
    model.openRow(rows[1].id)
    model.picking = nil
    #expect(model.openBinding(in: zone, rows: rows) == rows[1].id)
  }

  @Test func theBindingJustSetFromThePickerIsOpen() {
    let model = InspectorFixtures.model()
    let zone = Zone.edge(.bottom)
    model.picking = PickerTarget(zone: zone, gesture: .tap)
    model.choose("audio.mute", zone: zone, gesture: .tap)
    let rows = model.inspectorRows(for: zone)
    #expect(model.openBinding(in: zone, rows: rows) == BindingKey(zone: zone, gesture: .tap))
  }

  @Test func aBindingWithAnEmptyRequiredParameterOpensByItself() {
    let model = InspectorFixtures.model()
    let zone = Zone.corner(.bottomLeft)
    model.choose("app.open", zone: zone, gesture: .doubleTap)  // a draft: "Needs an app"
    model.inspectorDrafts.open = nil
    model.choose("audio.mute", zone: zone, gesture: .tap)
    model.inspectorDrafts.open = nil
    let rows = model.inspectorRows(for: zone)
    #expect(model.openBinding(in: zone, rows: rows) == BindingKey(zone: zone, gesture: .doubleTap))
  }

  @Test func inheritedRowsNeverOpen() {
    let model = InspectorFixtures.model()
    model.selectedProfile = .app(PreviewFixtures.wayfare)
    let zone = Zone.edge(.right)
    let rows = model.inspectorRows(for: zone)
    #expect(rows.first?.source == .inherited)
    model.openRow(rows[0].id)
    model.picking = nil
    #expect(model.openBinding(in: zone, rows: rows) == nil)
  }

  @Test func addGestureOpensNothing() {
    let model = InspectorFixtures.model()
    let zone = Zone.edge(.bottom)
    model.picking = PickerTarget(zone: zone, gesture: .tap)
    #expect(model.openBinding(in: zone, rows: model.inspectorRows(for: zone)) == nil)
  }

  // MARK: Names and rows

  @Test func pickerEllipsisOnlyForARequiredParameter() throws {
    #expect(ActionNaming.pickerName(try #require(descriptor("audio.volume"))) == "Volume")
    #expect(ActionNaming.pickerName(try #require(descriptor("keyboard.backlight"))) == "Keyboard Brightness")
    #expect(ActionNaming.pickerName(try #require(descriptor("app.open"))) == "Open App…")
    #expect(ActionNaming.pickerName(try #require(descriptor("keyboard.shortcut"))) == "Keyboard Shortcut…")
  }

  @Test func longPressGetsPressTimeAndHoldKeysPutsLetGoAfterLast() throws {
    let ids = { (id: ActionID, gesture: GestureKind) in
      ParameterEditor.editors(for: self.descriptor(id), gesture: gesture).map(\.id)
    }
    #expect(ids("media.next", .longPress) == ["holdMS", "haptics"])
    #expect(ids("media.next", .tap) == ["haptics"])
    #expect(ids("keyboard.hold", .longPress) == ["keys", "holdMS", "maxSeconds", "haptics"])
    let hold = try #require(descriptor("keyboard.hold"))
    let maxSeconds = try #require(hold.parameters.first { $0.key == "maxSeconds" })
    #expect(ActionNaming.parameterLabel(maxSeconds, action: hold.id) == "Let go after")
    #expect(ActionNaming.parameterHelp(maxSeconds) == "If a lift is missed, the keys come back up after this long.")
  }

  @Test func onOffIsACheckboxAndLabelsAreSentenceCase() throws {
    let volume = try #require(descriptor("audio.volume"))
    let speedUp = try #require(volume.parameters.first { $0.key == "speedUp" })
    #expect(ActionNaming.isOnOff(speedUp))
    #expect(ParameterEditor.action(speedUp).columnLabel(action: volume.id) == nil)
    #expect(ActionNaming.sentenceCase("Shortcut Name") == "Shortcut name")
    #expect(ActionNaming.sentenceCase("File or Folder") == "File or folder")
    #expect(ActionNaming.sentenceCase("URL") == "URL")
    #expect(ActionNaming.sentenceCase("Up / Right Keys") == "Up / right keys")
  }

  @Test func oneLabelColumnPerBindingNeverPastTheCap() {
    let short = ParameterRowsView.labelWidth(["URL"])
    let long = ParameterRowsView.labelWidth(["Keep open between strokes", "Distance per app"])
    #expect(short < long)
    #expect(long <= ParameterRowsView.maxLabelWidth)
  }

  @Test func disclosureChevronFollowsTheSearch() {
    #expect(ActionPickerView.othersExpanded(showOthers: false, query: "key"))
    #expect(!ActionPickerView.othersExpanded(showOthers: false, query: " "))
    #expect(ActionPickerView.othersExpanded(showOthers: true, query: ""))
  }

  @Test func configProblemWrapsTheRuntimeOneAndNamesTheLineOnce() {
    let runtime = EdgyRuntime.ConfigProblem(message: "Unexpected character 'x' around line 14, column 3.", line: 14)
    let problem = ConfigProblem(runtime)
    #expect(problem.problem == runtime)
    #expect(problem.line == 14)
    #expect(
      problem.sentence
        == "config.json has an error on line 14, column 3: Unexpected character ‘x’. Edgy kept the last working settings."
    )
    let fromApp = ConfigProblem(fileName: "edgy.json", line: 2, message: "Missing value")
    #expect(fromApp.problem == EdgyRuntime.ConfigProblem(message: "Missing value", line: 2))
    #expect(fromApp.sentence == "edgy.json has an error on line 2: Missing value. Edgy kept the last working settings.")
  }
}
