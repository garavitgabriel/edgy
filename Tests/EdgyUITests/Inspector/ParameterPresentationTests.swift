import EdgyCore
import EdgyRuntime
import Foundation
import Testing

@testable import EdgyUI

/// The optional presentation fields on `ActionParameter` (helpText, unit, zeroLabel, fallback),
/// covered with fake descriptors: no catalog action uses them yet.
@MainActor @Suite struct ParameterPresentationTests {
  private func field(_ parameter: ActionParameter, value: String?, model: SettingsModel) -> NumberParameterField {
    var binding = Binding(zone: .edge(.right), gesture: .longPress, action: "media.next")
    binding.parameters[parameter.key] = value
    return NumberParameterField(
      model: model, row: InspectorRow(binding: binding, source: nil), key: parameter.key, range: 0...2000,
      fallback: parameter.defaultValue.flatMap(Double.init) ?? 0, format: .plain, parameter: parameter)
  }

  @Test func unitFollowsTheValue() {
    let stepMM = ActionParameter(
      key: "stepMM", kind: .number(4...20), required: false, defaultValue: "8", displayName: "Distance per app",
      // Batch 26 ruling (Switch Apps opens on travel): was "Slide this far to move one app."
      helpText: "Slide this far to open the switcher and move one app.", unit: "mm")
    #expect(NumberParameterField.label(8, format: .plain, parameter: stepMM) == "8 mm")
    #expect(NumberParameterField.label(12.5, format: .plain, parameter: stepMM) == "12.5 mm")
    // Batch 26 ruling: #expect(stepMM.helpText == "Slide this far to move one app.")
    #expect(stepMM.helpText == "Slide this far to open the switcher and move one app.")
  }

  @Test func zeroReadsAsItsLabel() {
    let keepOpen = ActionParameter(
      key: "keepOpenMS", kind: .number(0...1000), required: false, defaultValue: "400",
      displayName: "Keep open between strokes", unit: "ms", zeroLabel: "Off")
    #expect(NumberParameterField.label(0, format: .plain, parameter: keepOpen) == "Off")
    #expect(NumberParameterField.label(400, format: .plain, parameter: keepOpen) == "400 ms")
  }

  @Test func fallbackReadsDefaultFromTheRealSettingUntilChanged() {
    var config = PreviewFixtures.demoConfig
    config.gestures.longPressMS = 650
    let model = InspectorFixtures.model(config: config)
    let holdMS = ActionParameter(
      key: "holdMS", kind: .number(100...1500), required: false, displayName: "Press time", unit: "ms",
      fallback: .longPressMS)
    let absent = field(holdMS, value: nil, model: model)
    #expect(absent.baseValue == 650)
    #expect(absent.valueText(650, isAbsent: true) == "Default (650 ms)")
    let changed = field(holdMS, value: "900", model: model)
    #expect(changed.valueText(900, isAbsent: false) == "900 ms")
  }

  @Test func unknownInfoCodesFallBackToTheirDetail() {
    let note = ValidationIssue(.info, .settingOutOfRange, detail: "Something to know here.")
    #expect(IssueCopy.note(for: note) == "Something to know here.")
    let warning = ValidationIssue(.warning, .settingOutOfRange, detail: "x")
    #expect(IssueCopy.note(for: warning) == nil)
    #expect(
      IssueCopy.slideAndSwipes == "Quick slides can look like swipes here, so swipes need a clearer flick on this edge."
    )
  }

  @Test func rowMenusGreyOutWhatDoesntApply() {
    #expect(RowMenu.items(for: .inherited).map(\.enabled) == [true, true, false])
    #expect(RowMenu.items(for: .turnedOff).map(\.enabled) == [true, false, true])
    #expect(RowMenu.items(for: nil).map(\.title) == ["Change action…", "Remove gesture"])
  }

  @Test func theTapNoteOffersItsFixAndOpeningAMenuSelectsTheRow() {
    let model = InspectorFixtures.model(config: InspectorFixtures.configWithBottomTap)
    let rows = model.inspectorRows(for: .edge(.bottom))
    let notes = model.interactionNotes(for: .edge(.bottom), rows: rows)
    #expect(notes.count == 1)
    #expect(notes.first?.fix == .useLongPress(BindingKey(zone: .edge(.bottom), gesture: .tap)))
    let swipe = BindingKey(zone: .edge(.bottom), gesture: .swipe(.left))
    model.apply(.openMenu(swipe))
    #expect(model.selectedZone == .edge(.bottom))
    #expect(model.inspectorDrafts.openMenu == swipe)
  }
}
