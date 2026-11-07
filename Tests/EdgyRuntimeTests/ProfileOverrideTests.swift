import EdgyCore
import Foundation
import Testing

@testable import EdgyRuntime

@MainActor
@Suite struct ProfileOverrideTests {
  static let app = "com.example.terminal"
  static let rightSlide = BindingKey(zone: .edge(.right), gesture: .slide)
  static let muteKey = BindingKey(zone: .corner(.topRight), gesture: .doubleTap)
  static let brightnessOnRight = Binding(zone: .edge(.right), gesture: .slide, action: "display.brightness")

  func sources(_ h: EditorHarness) -> [EffectiveBinding.Source] {
    h.editor.effectiveBindings(forApp: Self.app).map(\.source)
  }

  @Test func newAppProfilesInheritByDefault() throws {
    let h = try EditorHarness()
    try h.editor.addAppProfile(bundleID: Self.app)
    #expect(h.editor.config.appProfiles[Self.app] == Profile(bindings: [], inheritsDefault: true))
    #expect(h.editor.config.profile(for: Self.app) == EdgyConfig.defaults.profile(for: nil))
    #expect(sources(h) == Array(repeating: .inherited, count: 7))
    try h.editor.addAppProfile(bundleID: "com.example.copy", startingAs: .copyOfDefault)
    #expect(
      h.editor.config.appProfiles["com.example.copy"] == Profile(bindings: EdgyConfig.defaults.defaultProfile.bindings))
    try h.editor.addAppProfile(bundleID: "com.example.empty", startingAs: .empty)
    #expect(h.editor.config.appProfiles["com.example.empty"] == Profile(bindings: []))
  }

  @Test func overrideReplacesOneGestureForTheAppOnly() throws {
    let h = try EditorHarness()
    try h.editor.addAppProfile(bundleID: Self.app)
    try h.editor.overrideBinding(Self.brightnessOnRight, forApp: Self.app)

    #expect(h.editor.config.appProfiles[Self.app]?.bindings == [Self.brightnessOnRight])
    #expect(h.editor.config.defaultProfile == EdgyConfig.defaults.defaultProfile)
    let rows = h.editor.effectiveBindings(forApp: Self.app)
    #expect(rows[0].source == .overridden)
    #expect(rows[0].binding == Self.brightnessOnRight)
    #expect(rows[0].defaultBinding?.action == "audio.volume")
    #expect(rows.filter { $0.source == .inherited }.count == 6)
    #expect(
      h.applied.last?.profile(for: Self.app).bindings.first { $0.key == Self.rightSlide } == Self.brightnessOnRight)
    #expect(try h.onDisk() == h.editor.config)
  }

  @Test func overridingTwiceKeepsOneBindingPerSlot() throws {
    let h = try EditorHarness()
    try h.editor.overrideBinding(Self.brightnessOnRight, forApp: Self.app)
    try h.editor.overrideBinding(
      Binding(zone: .edge(.right), gesture: .slide, action: "audio.volume", parameters: ["sensitivity": "2"]),
      forApp: Self.app)
    #expect(h.editor.config.appProfiles[Self.app]?.bindings.count == 1)
  }

  @Test func overridingWithoutAProfileCreatesAnInheritingOneInOneStep() throws {
    let h = try EditorHarness()
    try h.editor.overrideBinding(Self.brightnessOnRight, forApp: Self.app)
    #expect(h.editor.config.appProfiles[Self.app]?.inheritsDefault == true)
    #expect(h.changes.count == 1)
    try h.editor.undo()
    #expect(h.editor.config.appProfiles[Self.app] == nil)
    #expect(throws: SettingsEditorError.invalidBundleID("nodot")) {
      try h.editor.overrideBinding(Self.brightnessOnRight, forApp: "nodot")
    }
  }

  @Test func turnOffDisablesAGestureForTheAppOnly() throws {
    let h = try EditorHarness()
    try h.editor.addAppProfile(bundleID: Self.app)
    try h.editor.turnOff(Self.muteKey, forApp: Self.app)

    #expect(h.editor.config.profile(for: Self.app).bindings.allSatisfy { $0.key != Self.muteKey })
    #expect(h.editor.config.profile(for: nil).bindings.contains { $0.key == Self.muteKey })
    let row = h.editor.effectiveBindings(forApp: Self.app).first { $0.binding.key == Self.muteKey }
    #expect(row?.source == .turnedOff)
    #expect(row?.binding.action == .doNothing)
    #expect(row?.defaultBinding?.action == "audio.mute")
    #expect(h.editor.issues.isEmpty)
  }

  @Test func revertBringsTheDefaultBack() throws {
    let h = try EditorHarness()
    try h.editor.overrideBinding(Self.brightnessOnRight, forApp: Self.app)
    try h.editor.turnOff(Self.muteKey, forApp: Self.app)
    try h.editor.revertToDefault(Self.rightSlide, forApp: Self.app)
    try h.editor.revertToDefault(Self.muteKey, forApp: Self.app)
    #expect(sources(h) == Array(repeating: .inherited, count: 7))
    #expect(h.editor.config.appProfiles[Self.app] == Profile(bindings: [], inheritsDefault: true))
    // Reverting what isn't overridden is a no-op, not a step.
    let steps = h.changes.count
    try h.editor.revertToDefault(Self.rightSlide, forApp: Self.app)
    #expect(h.changes.count == steps)
    #expect(throws: SettingsEditorError.profileNotFound(.app("com.example.none"))) {
      try h.editor.revertToDefault(Self.rightSlide, forApp: "com.example.none")
    }
  }

  @Test func effectiveBindingsListAppOnlySlotsAfterTheDefaults() throws {
    let h = try EditorHarness()
    let extra = Binding(zone: .corner(.bottomLeft), gesture: .tap, action: "media.playPause")
    try h.editor.overrideBinding(extra, forApp: Self.app)
    try h.editor.turnOff(BindingKey(zone: .corner(.bottomRight), gesture: .tap), forApp: Self.app)
    let rows = h.editor.effectiveBindings(forApp: Self.app)
    #expect(rows.suffix(2).map(\.source) == [.appOnly, .turnedOff])
    #expect(rows.suffix(2).map(\.defaultBinding) == [nil, nil])
    #expect(rows.dropLast(2).map(\.binding) == EdgyConfig.defaults.defaultProfile.bindings)
    // Same order as what the engine runs (minus the turned-off row).
    #expect(
      rows.filter { $0.source != .turnedOff }.map(\.binding) == h.editor.config.profile(for: Self.app).bindings)
  }

  @Test func effectiveBindingsForAnAppWithoutAProfileAreInherited() throws {
    let h = try EditorHarness()
    #expect(h.editor.effectiveBindings(forApp: nil).map(\.source) == Array(repeating: .inherited, count: 7))
    #expect(h.editor.effectiveBindings(forApp: "com.example.none").count == 7)
  }

  @Test func fullReplaceProfilesStillBehaveExactlyAsBefore() throws {
    let h = try EditorHarness()
    let tap = Binding(zone: .edge(.top), gesture: .tap, action: "media.playPause")
    try h.editor.addAppProfile(bundleID: Self.app, copyingDefault: false)
    try h.editor.setBinding(tap, in: .app(Self.app))
    // Only the app's binding runs; nothing from the default leaks in.
    #expect(h.editor.config.profile(for: Self.app).bindings == [tap])
    #expect(sources(h) == [.appOnly])
    // Default edits don't reach a full-replace app.
    try h.editor.removeBinding(Self.muteKey, from: .default)
    #expect(h.editor.config.profile(for: Self.app).bindings == [tap])
    // Reset keeps the old meaning: a copy of the default.
    try h.editor.resetProfile(.app(Self.app))
    #expect(h.editor.config.appProfiles[Self.app] == Profile(bindings: h.editor.config.defaultProfile.bindings))
  }

  @Test func defaultEditsReachInheritingApps() throws {
    let h = try EditorHarness()
    try h.editor.addAppProfile(bundleID: Self.app)
    try h.editor.setBinding(
      Binding(zone: .corner(.topRight), gesture: .doubleTap, action: "media.next"), in: .default)
    #expect(h.editor.config.profile(for: Self.app).bindings[5].action == "media.next")
  }

  @Test func resetOfAnInheritingProfileClearsItsOverrides() throws {
    let h = try EditorHarness()
    try h.editor.overrideBinding(Self.brightnessOnRight, forApp: Self.app)
    try h.editor.setProfileDisabled(true, for: .app(Self.app))
    try h.editor.resetProfile(.app(Self.app))
    #expect(h.editor.config.appProfiles[Self.app] == Profile(bindings: [], inheritsDefault: true))
  }

  @Test func convertToInheritingKeepsTheAppBehavingTheSame() throws {
    let h = try EditorHarness()
    try h.editor.addAppProfile(bundleID: Self.app, copyingDefault: true)
    let app = ProfileRef.app(Self.app)
    try h.editor.setBinding(Self.brightnessOnRight, in: app)
    try h.editor.removeBinding(Self.muteKey, from: app)
    try h.editor.setBinding(Binding(zone: .corner(.bottomLeft), gesture: .tap, action: "audio.mute"), in: app)
    let before = h.editor.config.profile(for: Self.app)

    try h.editor.convertToInheriting(bundleID: Self.app)
    #expect(h.editor.config.profile(for: Self.app) == before)
    let profile = try #require(h.editor.config.appProfiles[Self.app])
    #expect(profile.inheritsDefault)
    #expect(profile.bindings.count == 3)
    #expect(sources(h).filter { $0 != .inherited } == [.overridden, .turnedOff, .appOnly])
    // Converting again does nothing; undo restores the full-replace profile.
    let steps = h.changes.count
    try h.editor.convertToInheriting(bundleID: Self.app)
    #expect(h.changes.count == steps)
    try h.editor.undo()
    #expect(h.editor.config.appProfiles[Self.app]?.inheritsDefault == false)
  }

  @Test func undoAndRedoCoverOverrideTurnOffAndRevert() throws {
    let h = try EditorHarness()
    let s0 = h.editor.config
    try h.editor.overrideBinding(Self.brightnessOnRight, forApp: Self.app)
    let s1 = h.editor.config
    try h.editor.turnOff(Self.muteKey, forApp: Self.app)
    let s2 = h.editor.config
    try h.editor.revertToDefault(Self.rightSlide, forApp: Self.app)
    let s3 = h.editor.config

    try h.editor.undo()
    #expect(h.editor.config == s2)
    try h.editor.undo()
    #expect(h.editor.config == s1)
    try h.editor.undo()
    #expect(h.editor.config == s0)
    #expect(try h.onDisk() == s0)
    try h.editor.redo()
    try h.editor.redo()
    try h.editor.redo()
    #expect(h.editor.config == s3)
    #expect(h.applied.last == s3)
  }

  @Test func invalidOverrideIsRefused() throws {
    let h = try EditorHarness()
    #expect(throws: SettingsEditorError.self) {
      try h.editor.overrideBinding(
        Binding(zone: .edge(.right), gesture: .slide, action: "media.next"), forApp: Self.app)
    }
    #expect(h.editor.config == .defaults)
  }

  @Test func validatingAnOverrideSeesInheritedBindings() throws {
    let h = try EditorHarness()
    try h.editor.addAppProfile(bundleID: Self.app)
    let half = Binding(zone: .edge(.right, segment: 1, segments: 2), gesture: .slide, action: "audio.volume")
    #expect(h.editor.validate(half, in: .app(Self.app)).map(\.code) == [.overlappingZones])
    #expect(h.editor.validate(Self.brightnessOnRight, in: .app(Self.app)).isEmpty)
  }
}
