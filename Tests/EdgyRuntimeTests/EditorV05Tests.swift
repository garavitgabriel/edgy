import EdgyCore
import Foundation
import Testing

@testable import EdgyRuntime

// v0.5 editor API: the display check, presets and the broken-config state. Temp files and fakes
// only.

/// The real catalog's shape for every id the presets and the defaults use (ids, shapes and
/// categories as in `Sources/Actions/ActionCatalog.swift`), plus what `MachineDefaults` substitutes.
enum RealShapedCatalog {
  static let descriptors: [ActionDescriptor] =
    MachineCatalog.descriptors + [
      trigger("window.leftHalf", .windows), trigger("window.rightHalf", .windows),
      trigger("window.maximize", .windows), trigger("window.center", .windows),
      trigger("system.missionControl", .system), trigger("system.showDesktop", .system),
    ]

  static func trigger(_ id: ActionID, _ category: ActionCategory) -> ActionDescriptor {
    ActionDescriptor(id: id, shape: .trigger, displayName: id.rawValue, category: category)
  }

  @MainActor
  static func editor(
    config: EdgyConfig = .defaults, availability: [ActionID: ActionAvailability] = [:]
  ) throws -> (SettingsEditor, ConfigStore) {
    let store = ConfigStore(fileURL: Sample.tempConfigURL(), logger: RecordingLogger())
    try store.save(config)
    let registry = MachineCatalog.Registry()
    registry.catalog = descriptors
    registry.availabilities = availability
    let editor = SettingsEditor(
      config: config, catalog: descriptors, store: store, scheduler: FakeScheduler(), actions: registry,
      logger: RecordingLogger(), apply: { _ in })
    return (editor, store)
  }
}

@MainActor
@Suite struct DisplayCheckEditorTests {
  static let key = "4c2d-7154-9"

  @Test func asksAreCountedAndStopAtThree() throws {
    let h = try EditorHarness()
    #expect(h.editor.displayCheckDue(key: Self.key))
    for _ in 0..<5 { try h.editor.countDisplayCheckAsk(key: Self.key) }
    #expect(h.editor.config.app.displayCheckAsks[Self.key] == 3)
    #expect(!h.editor.displayCheckDue(key: Self.key))
    #expect(try h.onDisk().app.displayCheckAsks[Self.key] == 3)
  }

  @Test func yesConfirmsTheDisplayForGood() throws {
    let h = try EditorHarness()
    try h.editor.answerDisplayCheck(key: Self.key, responds: true)
    #expect(h.editor.config.app.confirmedDisplays == [Self.key])
    #expect(!h.editor.displayCheckDue(key: Self.key))
    #expect(try h.onDisk().app.confirmedDisplays == [Self.key])
  }

  @Test func confirmedDisplayIsNeverDueEvenWithoutAsks() throws {
    var config = EdgyConfig.defaults
    config.app.confirmedDisplays = [Self.key]
    let h = try EditorHarness(config: config)
    #expect(h.editor.config.app.displayCheckAsks[Self.key] == nil)
    #expect(!h.editor.displayCheckDue(key: Self.key))
  }

  @Test func noTurnsTheDisplayOffAndTurnBackOnRestoresIt() throws {
    let h = try EditorHarness()
    try h.editor.answerDisplayCheck(key: Self.key, responds: false)
    #expect(h.editor.config.app.unresponsiveDisplays == [Self.key])
    #expect(!h.editor.displayCheckDue(key: Self.key))
    try h.editor.turnDisplayBackOn(key: Self.key)
    #expect(h.editor.config.app.unresponsiveDisplays.isEmpty)
    #expect(h.editor.config.app.confirmedDisplays.isEmpty)
    #expect(h.editor.displayCheckDue(key: Self.key))
    #expect(try h.onDisk().app.unresponsiveDisplays.isEmpty)
  }

  @Test func changingTheAnswerMovesTheDisplayBetweenSets() throws {
    let h = try EditorHarness()
    try h.editor.answerDisplayCheck(key: Self.key, responds: false)
    try h.editor.answerDisplayCheck(key: Self.key, responds: true)
    #expect(h.editor.config.app.unresponsiveDisplays.isEmpty)
    #expect(h.editor.config.app.confirmedDisplays == [Self.key])
  }

  @Test func eachAnswerIsOneUndoStep() throws {
    let h = try EditorHarness()
    try h.editor.countDisplayCheckAsk(key: Self.key)
    try h.editor.answerDisplayCheck(key: Self.key, responds: false)
    try h.editor.undo()
    #expect(h.editor.config.app.unresponsiveDisplays.isEmpty)
    #expect(h.editor.config.app.displayCheckAsks[Self.key] == 1)
    try h.editor.undo()
    #expect(h.editor.config == .defaults)
  }
}

@MainActor
@Suite struct PresetTests {
  @Test func mediaIsTheShippedDefaults() {
    #expect(Presets.media == EdgyConfig.defaults)
    #expect(Presets.Preset.media.config == .defaults)
  }

  @Test func windowsHasExactlyTheBriefsBindings() {
    let bindings = Presets.windows.defaultProfile.bindings.map { "\($0.zone) \($0.gesture) \($0.action.rawValue)" }
    #expect(
      Set(Presets.windows.defaultProfile.bindings.map(\.action)) == [
        "audio.volume", "display.brightness", "window.leftHalf", "window.rightHalf", "window.maximize",
        "window.center", "system.missionControl", "system.showDesktop", "audio.mute",
      ])
    #expect(bindings.count == 9)
    let byAction = Dictionary(uniqueKeysWithValues: Presets.windows.defaultProfile.bindings.map { ($0.action, $0) })
    #expect(byAction["window.maximize"]?.gesture == .longPress)
    #expect(byAction["window.maximize"]?.zone == .edge(.bottom))
    #expect(byAction["system.missionControl"]?.zone == .edge(.top))
    #expect(byAction["system.missionControl"]?.gesture == .doubleTap)
    #expect(byAction["system.showDesktop"]?.zone == .corner(.topLeft))
    #expect(byAction["audio.mute"]?.zone == .corner(.topRight))
  }

  @Test func minimalIsVolumeAndBrightness() {
    #expect(
      Presets.minimal.defaultProfile.bindings == [
        Binding(zone: .edge(.right), gesture: .slide, action: "audio.volume"),
        Binding(zone: .edge(.left), gesture: .slide, action: "display.brightness"),
      ])
    #expect(Presets.minimal.app == EdgyConfig.defaults.app)
    #expect(Presets.minimal.gestures == EdgyConfig.defaults.gestures)
  }

  @Test(arguments: Presets.Preset.allCases)
  func everyPresetBindingValidatesClean(_ preset: Presets.Preset) throws {
    let (editor, _) = try RealShapedCatalog.editor()
    let issues = editor.validate(preset.config)
    #expect(issues.isEmpty, "\(preset): \(issues)")
    for binding in preset.config.defaultProfile.bindings {
      #expect(binding.zone.supports(binding.gesture), "\(binding)")
      #expect(editor.validate(binding, in: .default).isEmpty, "\(binding)")
    }
  }

  @Test(arguments: Presets.Preset.allCases)
  func everyPresetSurvivesMachineDefaultsUnchangedWhenEverythingWorks(_ preset: Presets.Preset) throws {
    let (editor, _) = try RealShapedCatalog.editor()
    #expect(editor.machineDefaults(from: preset.config) == preset.config)
  }

  @Test(arguments: Presets.Preset.allCases)
  func everyPresetPassesMachineDefaultsOnAMacWithoutBrightness(_ preset: Presets.Preset) throws {
    let (editor, _) = try RealShapedCatalog.editor(availability: MachineCatalog.noBrightness)
    let adjusted = editor.machineDefaults(from: preset.config)
    let left = adjusted.defaultProfile.bindings.first { $0.key == BindingKey(zone: .edge(.left), gesture: .slide) }
    #expect(left?.action == "apps.switcher")
    #expect(!adjusted.defaultProfile.bindings.contains { $0.action == "display.brightness" })
    #expect(editor.validate(adjusted).filter(\.isError).isEmpty)
  }

  @Test func applyingAPresetReplacesOnlyTheDefaultProfileInOneStep() throws {
    var config = EdgyConfig.defaults
    config.app.hud = .none
    config.appProfiles["com.example.wayfare"] = Profile(bindings: [], inheritsDefault: true)
    let (editor, store) = try RealShapedCatalog.editor(config: config)
    try editor.applyPreset(.windows)
    #expect(editor.config.defaultProfile == Presets.windows.defaultProfile)
    #expect(editor.config.app.hud == .none)
    #expect(editor.config.appProfiles["com.example.wayfare"] != nil)
    #expect(try store.load() == editor.config)
    try editor.undo()
    #expect(editor.config == config)
  }

  @Test func applyingAPresetUsesMachineDefaults() throws {
    let (editor, _) = try RealShapedCatalog.editor(availability: MachineCatalog.noBrightness)
    try editor.applyPreset(.minimal)
    #expect(editor.config.defaultProfile.bindings.map(\.action) == ["audio.volume", "apps.switcher"])
  }
}

@MainActor
@Suite struct BrokenConfigTests {
  static let broken = "{\n  \"schemaVersion\": 1,\n  \"app\": {\n    \"enabled\": nope\n  }\n}\n"

  static func write(_ text: String, to h: EditorHarness) throws {
    try Data(text.utf8).write(to: h.store.fileURL, options: .atomic)
  }

  @Test func aBrokenFileKeepsTheRunningConfigAndSaysWhere() throws {
    var running = EdgyConfig.defaults
    running.app.hud = .none
    let h = try EditorHarness(config: running)
    try Self.write(Self.broken, to: h)
    #expect(throws: (any Error).self) { try h.editor.reloadFromDisk() }
    #expect(h.editor.config == running)
    #expect(h.applied.isEmpty)
    let problem = try #require(h.editor.configProblem)
    #expect(problem.line == 4, "\(problem.message)")
    #expect(!problem.message.isEmpty)
    #expect(h.changes.map(\.cause) == [.configProblem])
  }

  @Test func editsUndoAndRedoAreRefusedWhileBroken() throws {
    let h = try EditorHarness()
    try h.editor.updateAppSettings { $0.hud = .none }
    try Self.write(Self.broken, to: h)
    try? h.editor.reloadFromDisk()
    let problem = try #require(h.editor.configProblem)
    #expect(throws: SettingsEditorError.readOnly(problem)) { try h.editor.updateAppSettings { $0.haptics = false } }
    #expect(throws: SettingsEditorError.readOnly(problem)) { try h.editor.answerDisplayCheck(key: "k", responds: true) }
    #expect(throws: SettingsEditorError.readOnly(problem)) { try h.editor.undo() }
    #expect(throws: SettingsEditorError.readOnly(problem)) { try h.editor.redo() }
    // The user's broken file is left alone.
    #expect(try String(contentsOf: h.store.fileURL, encoding: .utf8) == Self.broken)
  }

  @Test func replaceWritesTheRunningConfigAndUnlocks() throws {
    var running = EdgyConfig.defaults
    running.gestures.edgeWidthMM = 11
    let h = try EditorHarness(config: running)
    try Self.write(Self.broken, to: h)
    try? h.editor.reloadFromDisk()
    try h.editor.replaceFileWithCurrentSettings()
    #expect(h.editor.configProblem == nil)
    #expect(try h.onDisk() == running)
    try h.editor.updateAppSettings { $0.haptics = false }
    #expect(try h.onDisk().app.haptics == false)
  }

  @Test func fixingTheFileRecovers() throws {
    let h = try EditorHarness()
    try Self.write(Self.broken, to: h)
    try? h.editor.reloadFromDisk()
    var fixed = EdgyConfig.defaults
    fixed.app.hud = .none
    try ConfigStore.encode(fixed).write(to: h.store.fileURL, options: .atomic)
    try h.editor.reloadFromDisk()
    #expect(h.editor.configProblem == nil)
    #expect(h.editor.config == fixed)
    #expect(h.changes.map(\.cause) == [.configProblem, .external])
  }

  @Test func fixingTheFileBackToTheRunningConfigStillRecovers() throws {
    let h = try EditorHarness()
    try Self.write(Self.broken, to: h)
    try? h.editor.reloadFromDisk()
    try ConfigStore.encode(.defaults).write(to: h.store.fileURL, options: .atomic)
    try h.editor.reloadFromDisk()
    #expect(h.editor.configProblem == nil)
    #expect(h.changes.map(\.cause) == [.configProblem, .configProblem])
  }

  @Test func aFileThatStopsValidatingIsNotAdopted() throws {
    let h = try EditorHarness()
    var invalid = EdgyConfig.defaults
    invalid.defaultProfile.bindings.append(Binding(zone: .edge(.top), gesture: .tap, action: "nope.action"))
    try ConfigStore.encode(invalid).write(to: h.store.fileURL, options: .atomic)
    #expect(throws: (any Error).self) { try h.editor.reloadFromDisk() }
    #expect(h.editor.config == .defaults)
    let problem = try #require(h.editor.configProblem)
    #expect(problem.message.contains("nope.action"), "\(problem.message)")
    #expect(problem.line == nil)
  }

  @Test func theWatchersFailureReportsTheProblem() throws {
    let h = try EditorHarness()
    h.editor.beginContinuousEdit("edgeWidth")
    try h.editor.updateGestureSettings { $0.edgeWidthMM = 12 }
    h.editor.reportConfigProblem(
      ConfigStoreError.malformed(reason: "Unexpected end of file around line 9, column 1.", backupPath: "/tmp/x"))
    #expect(!h.editor.isEditingContinuously)
    #expect(
      h.editor.configProblem == ConfigProblem(message: "Unexpected end of file around line 9, column 1.", line: 9))
    // The same problem again is not a new change.
    h.editor.reportConfigProblem(
      ConfigStoreError.malformed(reason: "Unexpected end of file around line 9, column 1.", backupPath: "/tmp/x"))
    #expect(h.changes.filter { $0.cause == .configProblem }.count == 1)
    h.editor.adoptExternal(.defaults)
    #expect(h.editor.configProblem == nil)
  }

  @Test func unsupportedSchemaIsAProblemWithoutALine() {
    let problem = ConfigProblem(
      error: ConfigStoreError.unsupportedSchemaVersion(found: 3, supported: 1, backupPath: "/tmp/x"))
    #expect(problem.line == nil)
    #expect(problem.message.contains("3"))
  }

  /// End to end with the real file watcher: a broken save is reported, a fixed one recovers.
  @Test func watcherReportsBrokenFilesAndRecovers() async throws {
    let h = try EditorHarness(debounce: 0.05)
    h.store.startWatching(
      onChange: { [editor = h.editor] config in Task { @MainActor in editor.adoptExternal(config) } },
      onFailure: { [editor = h.editor] error in
        let message = String(describing: error)
        Task { @MainActor in editor.reportConfigProblem(ConfigProblem.TestError(message)) }
      })
    defer { h.store.stopWatching() }
    try Self.write(Self.broken, to: h)
    try await Task.sleep(for: .milliseconds(400))
    #expect(h.editor.configProblem != nil)
    var fixed = EdgyConfig.defaults
    fixed.app.hud = .none
    try ConfigStore.encode(fixed).write(to: h.store.fileURL, options: .atomic)
    try await Task.sleep(for: .milliseconds(400))
    #expect(h.editor.configProblem == nil)
    #expect(h.editor.config == fixed)
  }
}

extension ConfigProblem {
  /// Carries a watcher error across actors in tests (`ConfigStoreError` is what the app passes).
  struct TestError: Error, CustomStringConvertible, Sendable {
    let description: String
    init(_ description: String) { self.description = description }
  }
}
