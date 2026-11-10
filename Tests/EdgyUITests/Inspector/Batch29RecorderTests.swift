import Actions
import AppKit
import EdgyCore
import EdgyRuntime
import Foundation
import SwiftUI
import Testing

@testable import EdgyUI

/// Batch 29 items 6, 7 and 10: key sequences in the recorder ("+ Then…", ⌫ removes the last step,
/// Esc cancels only the step being recorded) and "Use Escape" (BRIEF § Key-combo recorder). The
/// recorder is the fake from `InspectorFixtures`; nothing here touches the real keyboard.
@MainActor
@Suite(.serialized)
struct Batch29RecorderTests {
  static let folder = "batch-29"

  final class Box {
    var values: [String] = []
    var combos: [KeyCombo] = []
  }

  private func controller(
    hold: Bool = false, clock: TestClock = TestClock(), recorder: FakeRecorder = FakeRecorder()
  ) -> (KeyRecorderController, Box) {
    let box = Box()
    let c = KeyRecorderController(
      recorder: recorder, isHold: hold, now: { clock.now },
      commitValue: { combo, value in
        box.combos.append(combo)
        box.values.append(value)
      })
    return (c, box)
  }

  private func isValid(_ value: String) -> Bool {
    ConfigValidator.checkKeys(value, allowsSequence: true, hold: false) == nil
  }

  private func keyParameters(_ action: ActionID) throws -> [ActionParameter] {
    let descriptor = try #require(InspectorFixtures.model().editor.validator.descriptor(for: action))
    return descriptor.parameters.filter { $0.kind == .keyCombo }
  }

  // MARK: Which fields take a sequence

  @Test func onlyKeyboardShortcutKeysTakeASequence() throws {
    let shortcut = try keyParameters("keyboard.shortcut")
    #expect(shortcut.map(\.key) == ["keys"])
    #expect(KeyRecorderController.allowsSequence(action: "keyboard.shortcut", parameter: "keys"))
    // Hold Keys: one combo, never "+ Then…".
    let hold = try keyParameters("keyboard.hold")
    #expect(!hold.isEmpty)
    for parameter in hold {
      let allows = KeyRecorderController.allowsSequence(action: "keyboard.hold", parameter: parameter.key)
      #expect(!allows)
      #expect(!KeyRecorderController.showsThen(stored: "fn", allowsSequence: allows, isRecording: false))
      #expect(!KeyRecorderField.showsUseEscape(allowsSequence: allows, isRecording: true))
    }
    // Even if asked, the field turns sequences off on a hold action.
    let field = KeyRecorderField(stored: "fn", isHold: true, allowsSequence: true, recorder: nil) { _ in }
    #expect(!field.allowsSequence)
    // Slide to Repeat Keys: one combo each way.
    let repeatKeys = try keyParameters("keyboard.slideSteps")
    #expect(Set(repeatKeys.map(\.key)) == ["upKeys", "downKeys"])
    for parameter in repeatKeys {
      #expect(!KeyRecorderController.allowsSequence(action: "keyboard.slideSteps", parameter: parameter.key))
    }
  }

  // MARK: "+ Then…"

  @Test func oneStepShowsThen() {
    #expect(KeyRecorderController.showsThen(stored: "ctrl+b", allowsSequence: true, isRecording: false))
    #expect(KeyRecorderField.thenLabel == "+ Then…")
    #expect(KeyRecorderField.thenTooltip == "Send another shortcut after this one")
  }

  @Test func thenHiddenWhenEmptyWhileRecordingAndAtFourSteps() {
    #expect(!KeyRecorderController.showsThen(stored: nil, allowsSequence: true, isRecording: false))
    #expect(!KeyRecorderController.showsThen(stored: "", allowsSequence: true, isRecording: false))
    #expect(!KeyRecorderController.showsThen(stored: "ctrl+b", allowsSequence: true, isRecording: true))
    #expect(KeyRecorderController.showsThen(stored: "ctrl+b n x", allowsSequence: true, isRecording: false))
    #expect(!KeyRecorderController.showsThen(stored: "ctrl+b n x y", allowsSequence: true, isRecording: false))
  }

  @Test func twoStepsDisplayAsKeycapGroups() {
    #expect(KeyComboText.display("ctrl+b n") == "⌃ B, N")
  }

  @Test func thenRecordsTheNextStepAfterTheEarlierOnes() {
    let recorder = FakeRecorder()
    let (c, box) = controller(recorder: recorder)
    c.start(after: "ctrl+b")
    #expect(c.isRecording && recorder.starts == 1)
    c.handle(.listening(held: [.shift]))
    #expect(c.phase == .recording(held: [.shift]))
    c.handle(.recorded(KeyCombo(modifiers: [], key: "n")))
    #expect(c.phase == .idle)
    #expect(box.values == ["ctrl+b n"])
    #expect(isValid("ctrl+b n"))
    // Up to four; the fourth hides the button and a fifth can't start.
    c.start(after: "ctrl+b n")
    c.handle(.recorded(KeyCombo(modifiers: [.cmd], key: "k")))
    c.start(after: "ctrl+b n cmd+k")
    c.handle(.recorded(KeyCombo(modifiers: [], key: "x")))
    #expect(box.values.last == "ctrl+b n cmd+k x")
    #expect(isValid("ctrl+b n cmd+k x"))
    c.start(after: "ctrl+b n cmd+k x")
    #expect(!c.isRecording && recorder.starts == 3)
  }

  @Test func clickingTheFieldReRecordsTheWholeValue() {
    let (c, box) = controller()
    c.start()
    c.handle(.recorded(KeyCombo(modifiers: [.cmd], key: "k")))
    #expect(box.values == ["cmd+k"])
  }

  // MARK: ⌫ and Esc

  @Test func deleteRemovesTheLastStep() {
    #expect(KeyRecorderController.removingLastStep("ctrl+b n") == "ctrl+b")
    #expect(KeyRecorderController.removingLastStep("ctrl+b n cmd+k x") == "ctrl+b n cmd+k")
    #expect(isValid("ctrl+b n cmd+k"))
  }

  @Test func deleteOnOneStepClears() {
    #expect(KeyRecorderController.removingLastStep("ctrl+b") == nil)
    #expect(KeyRecorderController.removingLastStep("ctrl+opt+space") == nil)
    #expect(KeyRecorderController.removingLastStep(nil) == nil)
  }

  @Test func escWhileRecordingStepTwoKeepsStepOne() {
    let (c, box) = controller()
    c.start(after: "ctrl+b")
    c.handle(.cancelled)
    #expect(c.phase == .idle && box.values.isEmpty)
    #expect(c.base == nil)
    // The base doesn't leak into the next plain recording.
    c.start()
    c.handle(.recorded(KeyCombo(modifiers: [], key: "n")))
    #expect(box.values == ["n"])
  }

  @Test func aModifierOnlyStepIsRefused() {
    let clock = TestClock()
    let (c, box) = controller(clock: clock)
    c.start(after: "ctrl+b")
    c.handle(.listening(held: [.ctrl]))
    clock.advance(1)
    c.handle(.recorded(KeyCombo(modifiers: [.ctrl])!))
    #expect(box.values.isEmpty)
    #expect(c.error == "Add a key. Modifiers alone work only on Hold Keys.")
    #expect(c.phase == .idle && c.base == nil)
    c.start()
    c.handle(.recorded(KeyCombo(modifiers: [.cmd], key: "k")))
    #expect(box.values == ["cmd+k"])
  }

  // MARK: Use Escape (item 10)

  @Test func useEscapeCommitsEscapeAndEndsRecording() {
    let recorder = FakeRecorder()
    let (c, box) = controller(recorder: recorder)
    #expect(KeyRecorderField.escapeLabel == "Use Escape")
    #expect(KeyRecorderField.escapeTooltip == "Record the Escape key itself")
    #expect(KeyRecorderField.showsUseEscape(allowsSequence: true, isRecording: true))
    #expect(!KeyRecorderField.showsUseEscape(allowsSequence: true, isRecording: false))
    c.start()
    c.useEscape()
    #expect(c.phase == .idle && recorder.cancels == 1)
    #expect(box.values == ["escape"])
    #expect(KeyComboText.display("escape") == "Esc")
    // As a sequence step.
    c.start(after: "ctrl+b")
    c.useEscape()
    #expect(box.values.last == "ctrl+b escape")
    #expect(isValid("ctrl+b escape"))
    #expect(KeyComboText.display("ctrl+b escape") == "⌃ B, Esc")
    // Idle: nothing.
    c.useEscape()
    #expect(box.values.count == 2)
  }

  @Test func escWithModifiersRecordsAsToday() {
    let (c, box) = controller()
    c.start()
    c.handle(.recorded(KeyCombo(modifiers: [.opt], key: "escape")))
    #expect(box.values == ["opt+escape"])
  }

  /// Return, Tab, Space and Delete record directly: the controller commits them, and the field
  /// swallows key presses while recording (so Space or Return can't press the field, Tab can't
  /// move focus and Delete can't clear) and for a moment after the commit.
  @Test func bareReturnTabSpaceDeleteRecordDirectly() {
    for key in ["return", "tab", "space", "delete"] {
      let clock = TestClock()
      let (c, box) = controller(clock: clock)
      c.start(after: "ctrl+b")
      #expect(c.swallowsKeys)
      c.handle(.recorded(KeyCombo(modifiers: [], key: key)))
      #expect(box.values == ["ctrl+b \(key)"], "\(key)")
      #expect(isValid("ctrl+b \(key)"))
      #expect(c.phase == .idle)
      // The key that committed still reaches the focused field: it's swallowed.
      #expect(c.swallowsKeys, "\(key)")
      clock.advance(KeyRecorderController.swallowAfterCommit)
      #expect(!c.swallowsKeys, "\(key)")
    }
    #expect(!KeyRecorderController(recorder: nil, isHold: false, commit: { _ in }).swallowsKeys)
  }

  // MARK: Shots

  private func config(keys: String?) -> EdgyConfig {
    var binding = EdgyCore.Binding(zone: .edge(.left), gesture: .tap, action: "keyboard.shortcut")
    if let keys { binding.parameters["keys"] = keys }
    var config = PreviewFixtures.demoConfig
    config.defaultProfile.bindings = [binding]
    return config
  }

  private func inspector(keys: String, _ name: String) throws {
    let model = InspectorFixtures.model(config: config(keys: keys), recorder: FakeRecorder())
    model.selectedZone = .edge(.left)
    model.inspectorDrafts.open = InspectorDrafts.Key(
      profile: model.selectedProfile, binding: BindingKey(zone: .edge(.left), gesture: .tap))
    let view = InspectorView(model: model).frame(width: 360, height: 420, alignment: .top)
      .background(Tokens.padTop.opacity(0.35)).background(Tokens.windowTint)
    #expect(try Snapshot.write(view, folder: Self.folder, name: name).count == 2)
  }

  @Test func recorderStepShots() throws {
    try inspector(keys: "ctrl+b", "recorder-one-step")
    try inspector(keys: "ctrl+b n", "recorder-two-steps")
    try inspector(keys: "ctrl+b n cmd+k x", "recorder-four-steps")
    try inspector(keys: "ctrl+b escape", "recorder-escape-recorded")
  }

  @Test func recorderUseEscapeShot() throws {
    let fake = FakeRecorder()
    let clock = TestClock()
    let controller = KeyRecorderController(
      recorder: fake, isHold: false, now: { clock.now }, commitValue: { _, _ in })
    controller.start(after: "ctrl+b")
    let view = LabeledParameter(label: "Keys", labelWidth: 80) {
      KeyRecorderField(
        stored: "ctrl+b", isHold: false, allowsSequence: true, recorder: fake, controller: controller
      ) { _ in }
    }
    .padding(16).frame(width: 340, alignment: .leading).background(Tokens.windowTint)
    #expect(try Snapshot.write(view, folder: Self.folder, name: "recorder-use-escape").count == 2)
  }
}
