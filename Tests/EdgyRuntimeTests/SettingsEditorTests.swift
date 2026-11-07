import EdgyCore
import Foundation
import Testing

@testable import EdgyRuntime

@MainActor
@Suite struct SettingsEditorTests {
  static let topTap = Binding(zone: .edge(.top), gesture: .tap, action: "media.playPause")
  static let app = "com.example.player"

  // MARK: Mutations save + apply

  @Test func setBindingSavesAppliesAndNotifies() throws {
    let h = try EditorHarness()
    try h.editor.setBinding(Self.topTap, in: .default)

    #expect(h.editor.config.defaultProfile.bindings.last == Self.topTap)
    #expect(try h.onDisk() == h.editor.config)
    #expect(h.applied == [h.editor.config])
    #expect(h.changes.map(\.cause) == [.edit])
    #expect(h.changes.first?.changedProfiles == [.default])
    #expect(h.changes.first?.appSettingsChanged == false)
    #expect(h.editor.canUndo)
  }

  @Test func setBindingReplacesItsSlotInPlace() throws {
    let h = try EditorHarness()
    let mute = Binding(zone: .corner(.topRight), gesture: .doubleTap, action: "media.next")
    try h.editor.setBinding(mute, in: .default)
    let bindings = h.editor.config.defaultProfile.bindings
    #expect(bindings.count == EdgyConfig.defaults.defaultProfile.bindings.count)
    #expect(bindings[5] == mute)
  }

  @Test func setBindingCanMoveABindingToAnotherSlot() throws {
    let h = try EditorHarness()
    let old = BindingKey(zone: .corner(.topRight), gesture: .doubleTap)
    let moved = Binding(zone: .corner(.bottomRight), gesture: .tap, action: "audio.mute")
    try h.editor.setBinding(moved, in: .default, replacing: old)
    let keys = h.editor.config.defaultProfile.bindings.map(\.key)
    #expect(!keys.contains(old))
    #expect(keys[5] == moved.key)
    #expect(h.changes.count == 1)
  }

  @Test func invalidEditThrowsAndChangesNothing() throws {
    let h = try EditorHarness()
    let before = try Data(contentsOf: h.store.fileURL)

    #expect(throws: SettingsEditorError.self) {
      try h.editor.setBinding(Binding(zone: .edge(.top), gesture: .tap, action: "audio.volume"), in: .default)
    }
    do {
      try h.editor.setBinding(Binding(zone: .corner(.topLeft), gesture: .slide, action: "audio.volume"), in: .default)
      Issue.record("expected a throw")
    } catch SettingsEditorError.invalid(let issues) {
      #expect(issues.map(\.code) == [.gestureNotSupported])
    }
    #expect(throws: SettingsEditorError.profileNotFound(.app("com.example.none"))) {
      try h.editor.setBinding(Self.topTap, in: .app("com.example.none"))
    }

    #expect(h.editor.config == .defaults)
    #expect(try Data(contentsOf: h.store.fileURL) == before)
    #expect(h.applied.isEmpty)
    #expect(h.changes.isEmpty)
    #expect(!h.editor.canUndo)
  }

  @Test func failedSaveChangesNothing() throws {
    let store = FailingStore()
    var applied = 0
    let editor = SettingsEditor(
      config: .defaults, catalog: FakeCatalog.descriptors, store: store, scheduler: FakeScheduler(),
      logger: RecordingLogger(), apply: { _ in applied += 1 })

    #expect(throws: FailingStore.SaveFailed.self) { try editor.updateAppSettings { $0.enabled = false } }
    #expect(editor.config == .defaults)
    #expect(applied == 0)
    #expect(!editor.canUndo)
  }

  @Test func removeBindingSavesAndApplies() throws {
    let h = try EditorHarness()
    let key = BindingKey(zone: .edge(.left), gesture: .slide)
    try h.editor.removeBinding(key, from: .default)
    #expect(!h.editor.config.defaultProfile.bindings.map(\.key).contains(key))
    #expect(try h.onDisk() == h.editor.config)
    #expect(h.applied.count == 1)

    // Removing what isn't there is not a step.
    try h.editor.removeBinding(key, from: .default)
    #expect(h.changes.count == 1)
  }

  @Test func appProfilesAddRemoveAndDisable() throws {
    let h = try EditorHarness()
    // The pre-v0.4 full-replace path (v0.4's bare call makes an inheriting profile).
    try h.editor.addAppProfile(bundleID: Self.app, copyingDefault: false)
    #expect(h.editor.config.appProfiles[Self.app] == Profile(bindings: []))
    try h.editor.addAppProfile(bundleID: "com.example.copy", copyingDefault: true)
    #expect(h.editor.config.appProfiles["com.example.copy"]?.bindings == EdgyConfig.defaults.defaultProfile.bindings)

    #expect(throws: SettingsEditorError.profileExists(Self.app)) { try h.editor.addAppProfile(bundleID: Self.app) }
    #expect(throws: SettingsEditorError.invalidBundleID("nodot")) { try h.editor.addAppProfile(bundleID: "nodot") }

    try h.editor.setProfileDisabled(true, for: .app(Self.app))
    #expect(h.editor.config.appProfiles[Self.app]?.disabled == true)
    #expect(h.editor.effectiveProfile(for: Self.app) == .app(Self.app))
    #expect(h.editor.effectiveProfile(for: "com.example.other") == .default)
    #expect(h.editor.effectiveProfile(for: nil) == .default)

    try h.editor.removeAppProfile(bundleID: Self.app)
    #expect(h.editor.config.appProfiles[Self.app] == nil)
    #expect(throws: SettingsEditorError.profileNotFound(.app(Self.app))) {
      try h.editor.removeAppProfile(bundleID: Self.app)
    }
    #expect(try h.onDisk() == h.editor.config)
    #expect(h.applied.count == 4)
    #expect(
      h.changes.map(\.changedProfiles) == [
        [.app(Self.app)], [.app("com.example.copy")], [.app(Self.app)], [.app(Self.app)],
      ])
  }

  @Test func appSettingsEditsSaveAndClampStrength() throws {
    let h = try EditorHarness()
    try h.editor.updateAppSettings {
      $0.enabled = false
      $0.hapticTickStrength = 40
    }
    #expect(h.editor.config.app.enabled == false)
    #expect(h.editor.config.app.hapticTickStrength == AppSettings.hapticStrengthRange.upperBound)
    #expect(try h.onDisk().app.enabled == false)
    #expect(h.applied.last?.app.enabled == false)
    #expect(h.changes.last?.appSettingsChanged == true)
  }

  @Test func gestureSettingsEditsAreClamped() throws {
    let h = try EditorHarness()
    try h.editor.updateGestureSettings {
      $0.edgeWidthMM = 100
      $0.fingers = 5
      $0.longPressMS = .nan
    }
    #expect(h.editor.config.gestures.edgeWidthMM == GestureSettingsLimits.edgeWidthMM.upperBound)
    #expect(h.editor.config.gestures.fingers == 2)
    #expect(h.editor.config.gestures.longPressMS == GestureSettings.defaults.longPressMS)
    #expect(try h.onDisk().gestures == h.editor.config.gestures)
    #expect(h.changes.last?.gestureSettingsChanged == true)
  }

  @Test func resetProfileAndResetAll() throws {
    let h = try EditorHarness()
    try h.editor.removeBinding(BindingKey(zone: .edge(.left), gesture: .slide), from: .default)
    try h.editor.addAppProfile(bundleID: Self.app, copyingDefault: false)
    try h.editor.setBinding(Self.topTap, in: .app(Self.app))
    try h.editor.setProfileDisabled(true, for: .app(Self.app))

    try h.editor.resetProfile(.app(Self.app))
    #expect(h.editor.config.appProfiles[Self.app] == Profile(bindings: h.editor.config.defaultProfile.bindings))

    try h.editor.resetProfile(.default)
    #expect(h.editor.config.defaultProfile == EdgyConfig.defaults.defaultProfile)

    try h.editor.updateGestureSettings { $0.dwellMS = 300 }
    try h.editor.resetAll()
    #expect(h.editor.config == .defaults)
    #expect(try h.onDisk() == .defaults)
    #expect(h.applied.last == .defaults)

    // Reset is one undo step.
    try h.editor.undo()
    #expect(h.editor.config.gestures.dwellMS == 300)
  }

  // MARK: Undo / redo

  @Test func undoAndRedoAcrossMutationKinds() throws {
    let h = try EditorHarness()
    let states = [h.editor.config]
    try h.editor.setBinding(Self.topTap, in: .default)
    let s1 = h.editor.config
    try h.editor.addAppProfile(bundleID: Self.app, copyingDefault: true)
    let s2 = h.editor.config
    try h.editor.updateAppSettings { $0.haptics = false }
    let s3 = h.editor.config
    try h.editor.updateGestureSettings { $0.edgeWidthMM = 10 }
    let s4 = h.editor.config

    #expect(try h.editor.undo())
    #expect(h.editor.config == s3)
    #expect(try h.onDisk() == s3)
    #expect(h.applied.last == s3)
    #expect(try h.editor.undo())
    #expect(h.editor.config == s2)
    #expect(try h.editor.undo())
    #expect(h.editor.config == s1)
    #expect(h.changes.suffix(3).map(\.cause) == [.undo, .undo, .undo])

    #expect(try h.editor.redo())
    #expect(try h.editor.redo())
    #expect(try h.editor.redo())
    #expect(h.editor.config == s4)
    #expect(try h.onDisk() == s4)
    #expect(try !h.editor.redo())

    for _ in 0..<4 { try h.editor.undo() }
    #expect(h.editor.config == states[0])
    #expect(try !h.editor.undo())
  }

  @Test func newEditClearsRedo() throws {
    let h = try EditorHarness()
    try h.editor.setBinding(Self.topTap, in: .default)
    try h.editor.undo()
    #expect(h.editor.canRedo)
    try h.editor.updateAppSettings { $0.hud = .none }
    #expect(!h.editor.canRedo)
    #expect(try !h.editor.redo())
  }

  @Test func undoHistoryIsBoundedToFifty() throws {
    let h = try EditorHarness()
    for step in 1...55 {
      try h.editor.updateGestureSettings { $0.dwellMS = Double(step) }
    }
    var undone = 0
    while try h.editor.undo() { undone += 1 }
    #expect(undone == SettingsEditor.undoLimit)
    #expect(h.editor.config.gestures.dwellMS == 5)
  }

  // MARK: Continuous edits

  @Test func sliderDragIsOneUndoStepWithDebouncedSaves() throws {
    let h = try EditorHarness()
    h.editor.beginContinuousEdit("edgeWidth")
    try h.editor.updateGestureSettings { $0.edgeWidthMM = 9 }
    try h.editor.updateGestureSettings { $0.edgeWidthMM = 10 }
    // Applied live, but not saved yet.
    #expect(h.applied.map(\.gestures.edgeWidthMM) == [9, 10])
    #expect(try h.onDisk().gestures.edgeWidthMM == 8)
    #expect(h.scheduler.pendingCount == 1)

    h.scheduler.advance(by: SettingsEditor.continuousSaveDelay)
    #expect(try h.onDisk().gestures.edgeWidthMM == 10)

    try h.editor.updateGestureSettings { $0.edgeWidthMM = 11 }
    try h.editor.updateGestureSettings { $0.edgeWidthMM = 12 }
    #expect(try h.onDisk().gestures.edgeWidthMM == 10)
    try h.editor.endContinuousEdit()
    #expect(try h.onDisk().gestures.edgeWidthMM == 12)
    #expect(h.scheduler.pendingCount == 0)
    #expect(
      h.changes.map(\.cause) == [
        .continuousEdit, .continuousEdit, .continuousEdit, .continuousEdit, .continuousEditEnded,
      ])

    #expect(try h.editor.undo())
    #expect(h.editor.config.gestures.edgeWidthMM == 8)
    #expect(try h.onDisk().gestures.edgeWidthMM == 8)
    #expect(try !h.editor.undo())
  }

  @Test func continuousEditWithNoChangeAddsNoStepAndNewKeyEndsTheOld() throws {
    let h = try EditorHarness()
    h.editor.beginContinuousEdit("tick")
    try h.editor.endContinuousEdit()
    #expect(!h.editor.canUndo)

    h.editor.beginContinuousEdit("tick")
    try h.editor.updateAppSettings { $0.hapticTickStrength = 3 }
    h.editor.beginContinuousEdit("click")
    #expect(try h.onDisk().app.hapticTickStrength == 3)
    try h.editor.updateAppSettings { $0.hapticClickStrength = 2 }
    try h.editor.endContinuousEdit()
    #expect(try h.onDisk().app.hapticClickStrength == 2)

    try h.editor.undo()
    #expect(h.editor.config.app.hapticTickStrength == 3)
    #expect(h.editor.config.app.hapticClickStrength == 6)
  }

  @Test func undoDuringDragClosesTheDragFirst() throws {
    let h = try EditorHarness()
    h.editor.beginContinuousEdit("dwell")
    try h.editor.updateGestureSettings { $0.dwellMS = 200 }
    #expect(h.editor.canUndo)
    try h.editor.undo()
    #expect(!h.editor.isEditingContinuously)
    #expect(h.editor.config.gestures.dwellMS == 120)
    #expect(try h.onDisk().gestures.dwellMS == 120)
    #expect(h.scheduler.pendingCount == 0)
  }

  // MARK: External edits

  @Test func externalEditIsAdoptedAndUndoable() throws {
    let h = try EditorHarness()
    var handEdited = EdgyConfig.defaults
    handEdited.gestures.cornerSizeMM = 15
    try ConfigStore.encode(handEdited).write(to: h.store.fileURL, options: .atomic)

    h.editor.adoptExternal(handEdited)
    #expect(h.editor.config == handEdited)
    #expect(h.applied == [handEdited])
    #expect(h.changes.map(\.cause) == [.external])
    #expect(h.changes.first?.gestureSettingsChanged == true)

    // The editor's own state echoing back is not a change.
    h.editor.adoptExternal(handEdited)
    #expect(h.changes.count == 1)

    try h.editor.undo()
    #expect(h.editor.config == .defaults)
    #expect(try h.onDisk() == .defaults)
  }

  @Test func externalEditMidDragWinsOnDisk() throws {
    let h = try EditorHarness()
    h.editor.beginContinuousEdit("edgeWidth")
    try h.editor.updateGestureSettings { $0.edgeWidthMM = 14 }
    var handEdited = EdgyConfig.defaults
    handEdited.app.hud = .none
    try ConfigStore.encode(handEdited).write(to: h.store.fileURL, options: .atomic)

    h.editor.adoptExternal(handEdited)
    #expect(!h.editor.isEditingContinuously)
    #expect(h.editor.config == handEdited)
    #expect(try h.onDisk() == handEdited)
    h.scheduler.advance(by: 10)
    #expect(try h.onDisk() == handEdited)

    // Two steps: the drag, then the external edit.
    try h.editor.undo()
    #expect(h.editor.config.gestures.edgeWidthMM == 14)
    try h.editor.undo()
    #expect(h.editor.config == .defaults)
  }

  @Test func reloadFromDiskAdoptsTheFile() throws {
    let h = try EditorHarness()
    var handEdited = EdgyConfig.defaults
    handEdited.app.hud = .none
    try ConfigStore.encode(handEdited).write(to: h.store.fileURL, options: .atomic)
    try h.editor.reloadFromDisk()
    #expect(h.editor.config == handEdited)
    #expect(h.changes.map(\.cause) == [.external])
  }

  /// End to end with the real file watcher: the editor's saves don't come back, a hand edit does.
  @Test func watcherDeliversHandEditsButNotOwnSaves() async throws {
    let h = try EditorHarness(debounce: 0.05)
    h.store.startWatching { [editor = h.editor] config in
      Task { @MainActor in editor.adoptExternal(config) }
    }
    defer { h.store.stopWatching() }

    try h.editor.setBinding(Self.topTap, in: .default)
    try await Task.sleep(for: .milliseconds(400))
    #expect(h.changes.map(\.cause) == [.edit])

    var handEdited = h.editor.config
    handEdited.gestures.dwellMS = 250
    try ConfigStore.encode(handEdited).write(to: h.store.fileURL, options: .atomic)
    for _ in 0..<100 where h.changes.count < 2 {
      try await Task.sleep(for: .milliseconds(20))
    }
    #expect(h.changes.map(\.cause) == [.edit, .external])
    #expect(h.editor.config.gestures.dwellMS == 250)
  }

  @Test func preexistingErrorsAreExposedButDontBlockOtherEdits() throws {
    var broken = EdgyConfig.defaults
    broken.defaultProfile.bindings.append(Binding(zone: .edge(.top), gesture: .tap, action: "nope.gone"))
    let h = try EditorHarness(config: broken)
    #expect(h.editor.issues.map(\.code) == [.unknownAction])
    #expect(h.editor.config == broken)
    #expect(!h.logger.errors.isEmpty)

    try h.editor.updateAppSettings { $0.enabled = false }
    try h.editor.setBinding(Binding(zone: .edge(.bottom), gesture: .tap, action: "audio.mute"), in: .default)
    // (v0.4: the bottom tap also gets a `tapWaitsForDoubleTap` info note; notes aren't problems.)
    #expect(h.editor.issues.filter { $0.severity != .info }.map(\.code) == [.unknownAction])

    try h.editor.removeBinding(BindingKey(zone: .edge(.top), gesture: .tap), from: .default)
    #expect(h.editor.issues.filter { $0.severity != .info }.isEmpty)

    // A new error is still refused.
    #expect(throws: SettingsEditorError.self) {
      try h.editor.setBinding(Binding(zone: .edge(.top), gesture: .tap, action: "nope.gone"), in: .default)
    }
  }

  // MARK: Queries

  @Test func bindingsGroupedByZoneInStableOrder() throws {
    let h = try EditorHarness()
    let groups = h.editor.bindingsByZone(in: .default)
    #expect(
      groups.map(\.zone) == [.edge(.left), .edge(.right), .edge(.bottom), .corner(.topLeft), .corner(.topRight)])
    #expect(groups[2].bindings.map(\.gesture) == [.doubleTap, .swipe(.left), .swipe(.right)])
    #expect(h.editor.bindingsByZone(in: .app("com.example.none")).isEmpty)
  }

  @Test func catalogQueries() throws {
    let h = try EditorHarness()
    let groups = h.editor.catalogByCategory
    #expect(groups.map(\.category) == [.sound, .display, .media, .apps, .keyboard])
    #expect(groups[0].actions.map(\.displayName) == ["Microphone Mute", "Mute", "Volume"])

    #expect(
      h.editor.compatibleActions(zone: .edge(.left), gesture: .slide).map(\.id) == [
        "display.brightness", "audio.volume", .doNothing,
      ])
    let cornerTap = h.editor.compatibleActions(zone: .corner(.topLeft), gesture: .tap)
    // 7 catalog triggers + "Do nothing" last (v0.4).
    #expect(cornerTap.count == 8)
    #expect(cornerTap.allSatisfy { $0.shape == .trigger })
    #expect(h.editor.compatibleActions(zone: .corner(.topLeft), gesture: .slide).isEmpty)

    #expect(h.editor.supportedGestures(for: .corner(.bottomLeft)) == [.tap, .doubleTap, .longPress])
    #expect(
      h.editor.supportedGestures(for: .edge(.top)) == [
        .slide, .tap, .doubleTap, .longPress, .swipe(.left), .swipe(.right),
      ])
  }

  @Test func validatingABindingWarnsAboutOverlapsInItsProfile() throws {
    let h = try EditorHarness()
    let segment = Binding(zone: .edge(.right, segment: 0, segments: 2), gesture: .slide, action: "audio.volume")
    #expect(h.editor.validate(segment, in: .default).map(\.code) == [.overlappingZones])
    // Its own slot is replaced, not overlapped.
    let same = Binding(zone: .edge(.right), gesture: .slide, action: "display.brightness")
    #expect(h.editor.validate(same, in: .default).isEmpty)
    // Warnings never block.
    try h.editor.setBinding(segment, in: .default)
    #expect(h.editor.issues.map(\.code) == [.overlappingZones])
  }
}
