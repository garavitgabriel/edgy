import EdgyCore
import Foundation
import Testing

@testable import EdgyRuntime

// Batch 29: the user's own name and icon for a binding (BRIEF § Binding parameters → "Your own
// name and icon for a binding") and key sequences (§ Key-combo recorder → "Key sequences"). Fakes
// and temp files only.

@MainActor
@Suite struct NameAndIconEditorTests {
  static let slot = BindingKey(zone: .corner(.topRight), gesture: .doubleTap)
  static let appID = "com.example.wayfare"

  func binding(_ h: EditorHarness, _ ref: ProfileRef = .default) -> Binding? {
    h.editor.profile(ref)?.bindings.first { $0.key == Self.slot }
  }

  @Test func nameIsTrimmedAndCappedAt24Characters() throws {
    #expect(SettingsEditor.customName("  Dictate \n", actionName: "Mute") == "Dictate")
    let long = String(repeating: "a", count: 30)
    #expect(SettingsEditor.customName(long, actionName: "Mute") == String(repeating: "a", count: 24))
    #expect(SettingsEditor.customName("abcdefghijklmnopqrstuvw  xyz", actionName: nil) == "abcdefghijklmnopqrstuvw")
    let h = try EditorHarness()
    try h.editor.setNameAndIcon(Self.slot, in: .default, name: "  " + long + " ", icon: nil)
    #expect(binding(h)?.customName?.count == 24)
  }

  @Test func emptyOrTheActionsOwnNameSavesAsNil() throws {
    #expect(SettingsEditor.customName("   ", actionName: "Mute") == nil)
    #expect(SettingsEditor.customName("", actionName: "Mute") == nil)
    #expect(SettingsEditor.customName(nil, actionName: "Mute") == nil)
    #expect(SettingsEditor.customName(" Mute ", actionName: "Mute") == nil)
    let h = try EditorHarness()
    let action = try #require(binding(h)?.action)
    let own = try #require(h.editor.validator.descriptor(for: action)?.displayName)
    try h.editor.setNameAndIcon(Self.slot, in: .default, name: own, icon: action)
    #expect(binding(h)?.customName == nil)
    #expect(binding(h)?.customIcon == nil)
    #expect(h.editor.config == EdgyConfig.defaults)
  }

  @Test func nameAndIconAreOneUndoStep() throws {
    let h = try EditorHarness()
    try h.editor.setNameAndIcon(Self.slot, in: .default, name: "Dictate", icon: "media.next")
    #expect(binding(h)?.customName == "Dictate")
    #expect(binding(h)?.customIcon == "media.next")
    #expect(try h.onDisk() == h.editor.config)
    #expect(try h.editor.undo())
    #expect(binding(h)?.customName == nil)
    #expect(binding(h)?.customIcon == nil)
    #expect(!h.editor.canUndo)
  }

  @Test func unknownIconIsRefused() throws {
    let h = try EditorHarness()
    #expect(throws: SettingsEditorError.unknownIcon("no.such.icon")) {
      try h.editor.setNameAndIcon(Self.slot, in: .default, name: "Dictate", icon: "no.such.icon")
    }
    #expect(throws: SettingsEditorError.unknownIcon(.doNothing)) {
      try h.editor.setNameAndIcon(Self.slot, in: .default, name: nil, icon: .doNothing)
    }
    // The UI's library (the IDs it draws) wins over the catalog.
    #expect(throws: SettingsEditorError.unknownIcon("media.next")) {
      try h.editor.setNameAndIcon(Self.slot, in: .default, name: nil, icon: "media.next", library: ["audio.mute"])
    }
    #expect(h.editor.config == EdgyConfig.defaults)
    #expect(!h.editor.canUndo)
  }

  @Test func resetClearsBoth() throws {
    let h = try EditorHarness()
    try h.editor.setNameAndIcon(Self.slot, in: .default, name: "Dictate", icon: "media.next")
    try h.editor.setNameAndIcon(Self.slot, in: .default, name: nil, icon: nil)
    #expect(binding(h)?.customName == nil)
    #expect(binding(h)?.customIcon == nil)
    #expect(h.editor.config == EdgyConfig.defaults)
  }

  @Test func namingAnInheritedBindingOnAnAppTabCreatesAnOverrideAndRevertDropsIt() throws {
    let h = try EditorHarness()
    try h.editor.addAppProfile(bundleID: Self.appID)
    let inherited = try #require(binding(h))
    try h.editor.setNameAndIcon(Self.slot, in: .app(Self.appID), name: "Dictate", icon: nil)
    let row = try #require(h.editor.effectiveBindings(forApp: Self.appID).first { $0.binding.key == Self.slot })
    #expect(row.source == .overridden)
    #expect(row.binding.action == inherited.action)
    #expect(row.binding.parameters == inherited.parameters)
    #expect(row.binding.customName == "Dictate")
    #expect(binding(h)?.customName == nil, "Default is unchanged")
    // One undo step back to plain inheritance.
    #expect(try h.editor.undo())
    #expect(
      h.editor.effectiveBindings(forApp: Self.appID).first { $0.binding.key == Self.slot }?.source == .inherited)
    #expect(try h.editor.redo())
    try h.editor.revertToDefault(Self.slot, forApp: Self.appID)
    let back = try #require(h.editor.effectiveBindings(forApp: Self.appID).first { $0.binding.key == Self.slot })
    #expect(back.source == .inherited)
    #expect(back.binding.customName == nil)
  }

  @Test func anEmptySlotIsNotFound() throws {
    let h = try EditorHarness()
    let empty = BindingKey(zone: .corner(.bottomLeft), gesture: .tap)
    #expect(throws: SettingsEditorError.bindingNotFound(empty)) {
      try h.editor.setNameAndIcon(empty, in: .default, name: "X", icon: nil)
    }
  }

  @Test func handEditedIconAndNameWarnButNeverBlock() {
    let validator = ConfigValidator(catalog: FakeCatalog.descriptors)
    var binding = Binding(zone: .corner(.topRight), gesture: .tap, action: "audio.mute", customIcon: "no.such.icon")
    #expect(validator.validate(binding).map(\.code) == [.unknownCustomIcon])
    binding.customIcon = "media.next"
    binding.customName = String(repeating: "x", count: 25)
    #expect(validator.validate(binding).map(\.code) == [.customNameTooLong])
    #expect(validator.validate(binding).allSatisfy { !$0.isError })
  }
}

/// The engine never reads `customName` / `customIcon`: a renamed binding performs identically.
@Suite struct NameAndIconEngineParityTests {
  static func config(named: Bool) -> EdgyConfig {
    var config = EdgyConfig.defaults
    config.defaultProfile.bindings = config.defaultProfile.bindings.map {
      var binding = $0
      if named {
        binding.customName = "Mine"
        binding.customIcon = "media.next"
      }
      return binding
    }
    return config
  }

  func run(_ config: EdgyConfig) -> (String, [HapticEvent]) {
    let actions = FakeActions()
    let router = Router(actions: actions, logger: RecordingLogger())
    for binding in config.defaultProfile.bindings {
      let phases: [GestureEvent.Phase] =
        binding.gesture == .slide || binding.gesture == .longPress ? [.began, .changed, .ended] : [.ended]
      for phase in phases {
        router.route(
          Sample.event(binding.zone, binding.gesture, phase: phase, delta: 0.1), config: config,
          frontmostBundleID: nil)
      }
    }
    return (String(describing: actions.performed), actions.feedbacks)
  }

  @Test func aRenamedBindingPerformsIdentically() {
    let plain = run(Self.config(named: false))
    let named = run(Self.config(named: true))
    #expect(!plain.0.isEmpty)
    #expect(plain.0 == named.0)
    #expect(plain.1 == named.1)
  }
}

@Suite struct KeySequenceValidationTests {
  static let keys = [ActionParameter(key: "keys", kind: .keyCombo, required: true, displayName: "Keys")]
  static let shortcut = ActionDescriptor(
    id: "keyboard.shortcut", shape: .trigger, displayName: "Keyboard Shortcut", category: .keyboard,
    parameters: keys)
  static let hold = ActionDescriptor(
    id: "keyboard.hold", shape: .hold, displayName: "Hold Keys", category: .keyboard, parameters: keys)
  let validator = ConfigValidator(catalog: [Self.shortcut, Self.hold] + FakeCatalog.descriptors)

  func issues(_ keys: String, _ action: ActionID = "keyboard.shortcut") -> [ValidationIssue] {
    let gesture: GestureKind = action == "keyboard.hold" ? .longPress : .tap
    return validator.validate(
      Binding(zone: .corner(.topLeft), gesture: gesture, action: action, parameters: ["keys": keys]))
  }

  @Test func oneToFourCombosSeparatedByOneSpace() {
    for keys in ["cmd+shift+4", "ctrl+b n", "ctrl+b n shift+3", "ctrl+b n c d", " ctrl+b n "] {
      #expect(issues(keys).isEmpty, "\(keys)")
    }
    #expect(ConfigValidator.keySteps("ctrl+b n") == ["ctrl+b", "n"])
    #expect(ConfigValidator.keySteps("cmd+shift+4") == ["cmd+shift+4"])
    #expect(ConfigValidator.keySteps("cmd + 4") == ["cmd + 4"], "one combo is today's value exactly")
  }

  @Test func fiveStepsAreTooMany() {
    #expect(issues("a b c d e").map(\.code) == [.keySequenceTooLong])
  }

  @Test func everyStepMustBeValid() {
    #expect(issues("ctrl+b nope").map(\.code) == [.invalidKeyCombo])
    #expect(issues("ctrl+b  n").map(\.code) == [.invalidKeyCombo], "a doubled space is an empty step")
  }

  @Test func aModifierOnlyStepIsRefusedWithTheExistingError() {
    let found = issues("ctrl+b ctrl")
    #expect(found.map(\.code) == [.invalidKeyCombo])
    #expect(found.first?.detail == ValidationIssue.modifierOnlyNeedsHold)
  }

  @Test func holdKeysTakesOneComboAndKeepsItsModifierOnlyRule() {
    #expect(issues("fn", "keyboard.hold").isEmpty)
    #expect(issues("ctrl+opt", "keyboard.hold").isEmpty)
    #expect(issues("fn space", "keyboard.hold").map(\.code) == [.keySequenceNotAllowed])
  }

  @Test func otherKeyParametersTakeOneCombo() {
    let binding = Binding(zone: .corner(.topLeft), gesture: .tap, action: "fake.press", parameters: ["keys": "a b"])
    #expect(validator.validate(binding).map(\.code) == [.keySequenceNotAllowed])
  }

  @Test func codesAreStable() {
    #expect(ValidationIssue.Code.keySequenceTooLong.rawValue == "keySequenceTooLong")
    #expect(ValidationIssue.Code.keySequenceNotAllowed.rawValue == "keySequenceNotAllowed")
    #expect(ValidationIssue.Code.unknownCustomIcon.rawValue == "unknownCustomIcon")
    #expect(ValidationIssue.Code.customNameTooLong.rawValue == "customNameTooLong")
  }
}
