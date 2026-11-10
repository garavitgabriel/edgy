import Actions
import EdgyCore
import EdgyRuntime
import Testing

@testable import EdgyUI

/// Batch 33 fix 1: one formatter. For one binding, the recorder field, the pad tab, the inspector
/// sub-line, the hover line and the plate all read the exact string `KeyComboText.text` writes.
@MainActor
@Suite(.serialized)
struct Batch33ComboTests {
  nonisolated static let cases: [String] = ["ctrl+b n", "cmd+shift+4", "fn+ctrl+b", "ctrl+opt+left", "opt+escape"]

  @Test(arguments: cases)
  func everySurfaceReadsTheOneFormatter(_ keys: String) throws {
    let expected = try #require(KeyComboText.text(steps: ConfigValidator.keySteps(keys)))
    let binding = EdgyCore.Binding(
      zone: .corner(.bottomLeft), gesture: .doubleTap, action: BuiltInAction.keyboardShortcut,
      parameters: ["keys": keys])
    var config = PreviewFixtures.demoConfig
    config.defaultProfile.bindings.removeAll { $0.zone == .corner(.bottomLeft) }
    config.defaultProfile.bindings.append(binding)
    let model = PreviewFixtures.model(config: config)

    // 1. The recorder field.
    #expect(KeyRecorderField.text(keys) == expected)
    // 2. The pad tab (the label and the form the pad draws).
    let zone = try #require(model.mirrorZones(forApp: nil).first { $0.zone == .corner(.bottomLeft) })
    #expect(zone.label == expected)
    let pad = MirrorPad(
      geometry: MirrorGeometry(
        sensorSizeMM: PreviewFixtures.externalPad.sensorSizeMM, settings: model.editor.config.gestures,
        pointsPerMM: Tokens.mirrorPointsPerMM), zones: model.mirrorZones(forApp: nil), selected: nil)
    #expect(pad.fittedLabel(zone, placement: pad.labelPlacement(zone)).text == expected)
    // 3. The inspector sub-line.
    #expect(BindingRowView.realAction(binding, model: model) == "Keyboard Shortcut: \(expected)")
    // 4. The hover line.
    #expect(MiniMirrorView.hoverLine(zone) == "Bottom-left: \(expected)")
    // 5. The plates, run and dry run.
    let context = PlateContext(bindings: [binding])
    let ran = plate(
      .actionRan(BuiltInAction.keyboardShortcut, zone: .corner(.bottomLeft), kind: .doubleTap), context: context)
    #expect(ran?.title == "Pressed \(expected)")
    let dry = plate(
      .wouldRun(BuiltInAction.keyboardShortcut, zone: .corner(.bottomLeft), kind: .doubleTap), context: context,
      dryRun: true)
    #expect(dry?.title == "Would press \(expected)")
  }

  /// The hold plate's text comes from the action's outcome, written by the same formatter.
  @Test func holdPlateReadsTheOutcomeOfTheOneFormatter() {
    let hold = EdgyCore.Binding(
      zone: .corner(.bottomRight), gesture: .longPress, action: BuiltInAction.keyboardHold,
      parameters: ["keys": "fn+space"])
    let detail = KeyCombo("fn+space").map(KeyComboText.text)
    #expect(detail == "fn Space")
    let held = plate(
      .actionRan(
        BuiltInAction.keyboardHold, zone: .corner(.bottomRight), kind: .longPress,
        outcome: ActionOutcome(detail: detail)),
      context: PlateContext(bindings: [hold]))
    #expect(held?.title == "Holding fn Space")
  }

  /// No field text is a combo with a space after a modifier symbol, and arrows are arrows.
  @Test func heldModifiersWhileRecordingUseTheFormatter() {
    #expect(KeyComboText.held([.ctrl, .opt]) == "⌃⌥")
    #expect(KeyComboText.held([.fn, .ctrl]) == "fn ⌃")
    #expect(KeyComboText.held([]) == "")
    #expect(KeyRecorderField.text("left") == "←")
    #expect(KeyRecorderField.text("") == nil)
  }
}
