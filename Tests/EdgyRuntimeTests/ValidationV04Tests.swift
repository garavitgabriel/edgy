import EdgyCore
import Foundation
import Testing

@testable import EdgyRuntime

/// v0.4 catalog additions: a hold action that reads a key combo, and the "Do nothing" entry the
/// Actions module adds (made up here; never the real registry).
enum V04Catalog {
  static let holdKeys = ActionDescriptor(
    id: "keyboard.hold", shape: .hold, displayName: "Hold Keys", category: .keyboard,
    parameters: [ActionParameter(key: "keys", kind: .keyCombo, required: true, displayName: "Keys")])
  static let doNothing = ActionDescriptor(
    id: .doNothing, shape: .trigger, displayName: "Nothing (Fake)", category: .system)
  static let descriptors = FakeCatalog.descriptors + [holdKeys]
  static let withDoNothing = descriptors + [doNothing]
}

@Suite struct DoNothingValidationTests {
  let validator = ConfigValidator(catalog: V04Catalog.descriptors)

  @Test func doNothingIsValidOnEveryGestureEvenWithoutACatalogEntry() {
    for zone in [Zone.edge(.left), .edge(.top, segment: 1, segments: 3), .corner(.bottomRight)] {
      for gesture in ConfigValidator.supportedGestures(for: zone) {
        let binding = Binding(zone: zone, gesture: gesture, action: .doNothing)
        #expect(validator.validate(binding, in: .app("com.example.app")).isEmpty, "\(gesture) at \(zone)")
      }
    }
  }

  @Test func doNothingStillNeedsAZoneThatCanProduceTheGesture() {
    let binding = Binding(zone: .corner(.topLeft), gesture: .slide, action: .doNothing)
    #expect(validator.validate(binding).map(\.code) == [.gestureNotSupported])
  }

  @Test func doNothingWarnsAboutParametersItDoesNotRead() {
    let binding = Binding(
      zone: .edge(.left), gesture: .slide, action: .doNothing, parameters: ["haptics": "off", "keys": "a"])
    #expect(validator.validate(binding).map(\.code) == [.unknownParameter])
  }

  @Test func compatibleActionsListDoNothingLastEverywhere() {
    for zone in [Zone.edge(.right), .corner(.topLeft)] {
      for gesture in ConfigValidator.supportedGestures(for: zone) {
        let list = validator.compatibleActions(zone: zone, gesture: gesture)
        #expect(list.last?.id == .doNothing)
        #expect(list.filter { $0.id == .doNothing }.count == 1)
      }
    }
    #expect(validator.compatibleActions(zone: .corner(.topLeft), gesture: .slide).isEmpty)
  }

  @Test func catalogDescriptorForDoNothingIsUsedAndKeptOutOfCategories() {
    let withEntry = ConfigValidator(catalog: V04Catalog.withDoNothing)
    #expect(withEntry.compatibleActions(zone: .edge(.left), gesture: .slide).last == V04Catalog.doNothing)
    #expect(!withEntry.catalogByCategory.flatMap(\.actions).contains { $0.id == .doNothing })
    #expect(validator.compatibleActions(zone: .edge(.left), gesture: .tap).last == ConfigValidator.doNothingFallback)
  }
}

@Suite struct ModifierOnlyComboTests {
  let validator = ConfigValidator(catalog: V04Catalog.descriptors)

  @Test func modifierOnlyComboIsValidOnAHold() {
    for keys in ["fn", "ctrl+opt", "cmd+shift+4"] {
      let binding = Binding(
        zone: .corner(.topLeft), gesture: .longPress, action: "keyboard.hold", parameters: ["keys": keys])
      #expect(validator.validate(binding).isEmpty, "\(keys)")
    }
  }

  @Test func modifierOnlyComboIsRefusedOnATriggerWithAReason() {
    let binding = Binding(zone: .corner(.topLeft), gesture: .tap, action: "fake.press", parameters: ["keys": "fn"])
    let issues = validator.validate(binding)
    #expect(issues.map(\.code) == [.invalidKeyCombo])
    #expect(issues.first?.detail == ValidationIssue.modifierOnlyNeedsHold)
    #expect(issues.first?.isError == true)
    // An unparseable combo keeps the plain code with no detail.
    let garbage = Binding(zone: .corner(.topLeft), gesture: .tap, action: "fake.press", parameters: ["keys": "x+y"])
    #expect(validator.validate(garbage).first?.detail == nil)
  }

  @Test func modifierOnlyComboIsRefusedInOptionalParametersToo() {
    let binding = Binding(
      zone: .edge(.top), gesture: .tap, action: "fake.everything", parameters: ["combo": "ctrl+opt"])
    #expect(validator.validate(binding).map(\.code) == [.invalidKeyCombo])
  }

  @MainActor @Test func editorRefusesAModifierOnlyTrigger() throws {
    let h = try EditorHarness()
    let bad = Binding(zone: .corner(.bottomLeft), gesture: .tap, action: "fake.press", parameters: ["keys": "fn"])
    #expect(throws: SettingsEditorError.self) { try h.editor.setBinding(bad, in: .default) }
    #expect(h.editor.config == .defaults)
  }
}

@Suite struct ConflictNoteTests {
  let validator = ConfigValidator(catalog: V04Catalog.descriptors)
  static let bottomTap = Binding(zone: .edge(.bottom), gesture: .tap, action: "audio.mute")

  @Test func defaultsHaveNoNotes() {
    #expect(validator.validate(EdgyConfig.defaults).isEmpty)
  }

  @Test func tapNextToADoubleTapGetsAnInfoNoteWithTheWait() {
    var config = EdgyConfig.defaults
    config.defaultProfile.bindings.append(Self.bottomTap)
    config.gestures.doubleTapWindowMS = 350
    let issues = validator.validate(config)
    #expect(
      issues == [
        ValidationIssue(
          .info, .tapWaitsForDoubleTap, profile: .default, binding: Self.bottomTap.key, action: "audio.mute",
          detail: "350")
      ])
    #expect(!issues[0].isError)
  }

  @MainActor @Test func notesNeverBlockSaving() throws {
    let h = try EditorHarness()
    try h.editor.setBinding(Self.bottomTap, in: .default)
    #expect(h.editor.issues.map(\.code) == [.tapWaitsForDoubleTap])
    #expect(try h.onDisk() == h.editor.config)
  }

  @Test func otherZonesAndSegmentsDoNotWait() {
    var config = EdgyConfig.defaults
    config.defaultProfile.bindings += [
      Binding(zone: .edge(.top), gesture: .tap, action: "audio.mute"),
      Binding(zone: .edge(.bottom, segment: 0, segments: 2), gesture: .tap, action: "audio.mute"),
    ]
    #expect(validator.validate(config).isEmpty)
  }

  @Test func inheritingAppGetsTheNoteItsOwnTapCauses() {
    var config = EdgyConfig.defaults
    config.appProfiles["com.example.app"] = Profile(bindings: [Self.bottomTap], inheritsDefault: true)
    #expect(
      validator.validate(config).map { [$0.code.rawValue, $0.profile?.description ?? ""] } == [
        ["tapWaitsForDoubleTap", "com.example.app"]
      ])
  }

  @Test func turningTheDoubleTapOffInTheAppRemovesTheNote() {
    var config = EdgyConfig.defaults
    config.defaultProfile.bindings.append(Self.bottomTap)
    config.appProfiles["com.example.app"] = Profile(
      bindings: [Binding(zone: .edge(.bottom), gesture: .doubleTap, action: .doNothing)], inheritsDefault: true)
    // The default's own note is reported once, on the default; the app turned the double-tap off.
    #expect(validator.validate(config).map(\.profile) == [.default])
  }

  @Test func fullReplaceAppProfilesGetTheirOwnNotes() {
    var config = EdgyConfig.defaults
    config.appProfiles["com.example.app"] = Profile(bindings: [
      Self.bottomTap, Binding(zone: .edge(.bottom), gesture: .doubleTap, action: "media.next"),
    ])
    #expect(validator.validate(config).map(\.profile) == [.app("com.example.app")])
  }
}

@Suite struct InheritingValidationTests {
  let validator = ConfigValidator(catalog: V04Catalog.descriptors)
  static let app = "com.example.app"

  @Test func overridingADefaultSlotIsNotADuplicate() {
    var config = EdgyConfig.defaults
    config.appProfiles[Self.app] = Profile(
      bindings: [
        Binding(zone: .edge(.right), gesture: .slide, action: "display.brightness"),
        Binding(zone: .corner(.topRight), gesture: .doubleTap, action: .doNothing),
      ], inheritsDefault: true)
    #expect(validator.validate(config).isEmpty)
  }

  @Test func duplicatesInsideTheOverridesAreStillErrors() {
    var config = EdgyConfig.defaults
    let tap = Binding(zone: .corner(.bottomLeft), gesture: .tap, action: "audio.mute")
    config.appProfiles[Self.app] = Profile(bindings: [tap, tap], inheritsDefault: true)
    #expect(validator.validate(config).map(\.code) == [.duplicateBinding])
  }

  @Test func overridesAreValidatedLikeAnyBinding() {
    var config = EdgyConfig.defaults
    config.appProfiles[Self.app] = Profile(
      bindings: [Binding(zone: .edge(.right), gesture: .slide, action: "media.next")], inheritsDefault: true)
    #expect(validator.validate(config).map(\.code) == [.shapeMismatch])
  }

  @Test func anOverrideOverlappingAnInheritedBindingWarns() {
    var config = EdgyConfig.defaults
    config.appProfiles[Self.app] = Profile(
      bindings: [Binding(zone: .edge(.left, segment: 0, segments: 2), gesture: .slide, action: "audio.volume")],
      inheritsDefault: true)
    #expect(validator.validate(config).map(\.code) == [.overlappingZones])
    // Turning the whole-edge default off in the app clears it.
    config.appProfiles[Self.app]!.bindings.append(Binding(zone: .edge(.left), gesture: .slide, action: .doNothing))
    #expect(validator.validate(config).isEmpty)
  }
}
