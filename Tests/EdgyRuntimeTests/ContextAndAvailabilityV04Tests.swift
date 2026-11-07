import EdgyCore
import Foundation
import Testing

@testable import EdgyRuntime

@Suite struct DoubleTapZonesContextTests {
  @Test func contextCarriesDoubleTapZonesFromTheProfile() throws {
    let h = try EngineHarness()
    h.step()
    // Defaults double-tap on the bottom edge and the two top corners.
    #expect(h.recognizer.contexts.last?.doubleTapZones == [.edge(.bottom), .corner(.topLeft), .corner(.topRight)])
  }

  @Test func doubleTapZonesFollowTheResolvedAppProfile() throws {
    var config = EdgyConfig.defaults
    config.appProfiles["com.example.app"] = Profile(
      bindings: [
        Binding(zone: .edge(.bottom), gesture: .doubleTap, action: .doNothing),
        Binding(zone: .edge(.top), gesture: .doubleTap, action: "media.next"),
      ], inheritsDefault: true)
    let h = try EngineHarness(config: config)
    h.frontmost.bundleID.value = "com.example.app"
    h.step()
    let context = try #require(h.recognizer.contexts.last)
    #expect(context.doubleTapZones == [.edge(.top), .corner(.topLeft), .corner(.topRight)])
    // The bottom edge stays enabled for its inherited swipes; only its double-tap is off.
    #expect(context.enabledZones.contains(.edge(.bottom)))
    #expect(context.enabledZones.contains(.edge(.top)))
  }

  @Test func disabledProfileHasNoDoubleTapZones() throws {
    var config = EdgyConfig.defaults
    config.appProfiles["com.example.app"] = Profile(bindings: [], disabled: true, inheritsDefault: true)
    let h = try EngineHarness(config: config)
    h.frontmost.bundleID.value = "com.example.app"
    h.step()
    #expect(h.recognizer.contexts.last?.doubleTapZones == [])
  }

  @Test func inheritingOverrideRoutesTheAppsAction() throws {
    var config = EdgyConfig.defaults
    config.appProfiles["com.example.app"] = Profile(
      bindings: [Binding(zone: .corner(.topRight), gesture: .doubleTap, action: "media.next")], inheritsDefault: true)
    let h = try EngineHarness(config: config)
    h.frontmost.bundleID.value = "com.example.app"
    h.step(GestureOutput(events: [Sample.event(.corner(.topRight), .doubleTap)]))
    h.step(GestureOutput(events: [Sample.event(.corner(.topLeft), .doubleTap)]))
    #expect(h.actions.performed.map(\.id) == ["media.next", "mic.mute"])
  }

  @Test func turnedOffGestureRoutesNothing() throws {
    var config = EdgyConfig.defaults
    config.appProfiles["com.example.app"] = Profile(
      bindings: [Binding(zone: .corner(.topRight), gesture: .doubleTap, action: .doNothing)], inheritsDefault: true)
    let h = try EngineHarness(config: config)
    h.frontmost.bundleID.value = "com.example.app"
    h.step(GestureOutput(events: [Sample.event(.corner(.topRight), .doubleTap)]))
    #expect(h.actions.performed.isEmpty)
    #expect(h.recognizer.contexts.last?.enabledZones.contains(.corner(.topRight)) == false)
  }
}

@MainActor
@Suite struct AvailabilityNotificationTests {
  func editor(_ registry: MachineCatalog.Registry) throws -> (SettingsEditor, EditorHarness.Recorder) {
    let store = ConfigStore(fileURL: Sample.tempConfigURL(), debounce: 0.3, logger: RecordingLogger())
    try store.save(.defaults)
    let recorder = EditorHarness.Recorder()
    let editor = SettingsEditor(
      config: .defaults, catalog: registry.available, store: store, scheduler: FakeScheduler(), actions: registry,
      logger: RecordingLogger(), apply: { recorder.applied.append($0) })
    editor.observe { recorder.changes.append($0) }
    return (editor, recorder)
  }

  @Test func refreshNotifiesWhenAvailabilityChanges() throws {
    let registry = MachineCatalog.Registry()
    let (editor, recorder) = try editor(registry)
    registry.availabilities = MachineCatalog.noBrightness
    #expect(editor.refreshAvailability())
    let change = try #require(recorder.changes.last)
    #expect(change.cause == .availability)
    #expect(change.config == change.previous)
    #expect(change.changedProfiles.isEmpty)
    #expect(editor.issues.map(\.code) == [.actionUnavailable])
    // Nothing is applied to the engine or made undoable.
    #expect(recorder.applied.isEmpty)
    #expect(!editor.canUndo)
  }

  @Test func refreshWithNoChangeIsSilent() throws {
    let registry = MachineCatalog.Registry()
    let (editor, recorder) = try editor(registry)
    #expect(!editor.refreshAvailability())
    #expect(recorder.changes.isEmpty)
  }

  @Test func aLimitedReasonChangeAlsoNotifies() throws {
    let registry = MachineCatalog.Registry()
    let (editor, recorder) = try editor(registry)
    registry.availabilities = ["audio.volume": .limited(reason: "a")]
    editor.refreshAvailability()
    registry.availabilities = ["audio.volume": .limited(reason: "b")]
    editor.refreshAvailability()
    registry.availabilities = ["audio.volume": .limited(reason: "b")]
    editor.refreshAvailability()
    #expect(recorder.changes.map(\.cause) == [.availability, .availability])
  }
}
