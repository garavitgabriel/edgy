import EdgyCore
import Foundation
import Testing

@testable import EdgyRuntime

@Suite struct ConfigStoreTests {
  @Test func firstRunCreatesDefaultsOnDisk() throws {
    let url = Sample.tempConfigURL()
    let store = ConfigStore(fileURL: url, logger: RecordingLogger())

    let loaded = try store.load()

    #expect(loaded == .defaults)
    #expect(FileManager.default.fileExists(atPath: url.path))
    let onDisk = try JSONDecoder().decode(EdgyConfig.self, from: Data(contentsOf: url))
    #expect(onDisk == .defaults)
  }

  @Test func saveThenLoadRoundTrips() throws {
    let url = Sample.tempConfigURL()
    var config = EdgyConfig.defaults
    config.gestures.edgeWidthMM = 10
    config.app.haptics = false
    config.appProfiles["com.example.editor"] = Profile(
      bindings: [
        Binding(
          zone: .edge(.top, segment: 1, segments: 3), gesture: .tap, action: "shortcut.run",
          parameters: ["name": "Focus"])
      ])
    config.appProfiles["com.example.game"] = Profile(bindings: [], disabled: true)

    try ConfigStore(fileURL: url, logger: RecordingLogger()).save(config)
    let reloaded = try ConfigStore(fileURL: url, logger: RecordingLogger()).load()

    #expect(reloaded == config)
  }

  @Test func fileIsPrettyPrintedWithSortedKeys() throws {
    let url = Sample.tempConfigURL()
    try ConfigStore(fileURL: url, logger: RecordingLogger()).load()
    let text = try String(contentsOf: url, encoding: .utf8)

    #expect(text.contains("\n  \""))
    let app = try #require(text.range(of: "\"app\""))
    let schema = try #require(text.range(of: "\"schemaVersion\""))
    #expect(app.lowerBound < schema.lowerBound)
  }

  @Test func unknownSchemaVersionThrowsAndKeepsBackup() throws {
    let url = Sample.tempConfigURL()
    let store = ConfigStore(fileURL: url, logger: RecordingLogger())
    var future = EdgyConfig.defaults
    future.schemaVersion = 99
    try store.save(future)
    let original = try Data(contentsOf: url)

    #expect(
      throws: ConfigStoreError.unsupportedSchemaVersion(
        found: 99, supported: EdgyConfig.currentSchemaVersion, backupPath: store.backupURL.path)
    ) {
      try ConfigStore(fileURL: url, logger: RecordingLogger()).load()
    }
    #expect(try Data(contentsOf: store.backupURL) == original)
    // The original file is left untouched; the failed store keeps working on defaults.
    #expect(try Data(contentsOf: url) == original)
    let failed = ConfigStore(fileURL: url, logger: RecordingLogger())
    _ = try? failed.load()
    #expect(failed.config == .defaults)
  }

  @Test func malformedJSONThrowsAndKeepsBackup() throws {
    let url = Sample.tempConfigURL()
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("{ not json".utf8).write(to: url)
    let store = ConfigStore(fileURL: url, logger: RecordingLogger())

    #expect(throws: ConfigStoreError.self) { try store.load() }
    #expect(FileManager.default.fileExists(atPath: store.backupURL.path))
    #expect(store.config == .defaults)
  }

  @Test func reloadPicksUpEdits() throws {
    let url = Sample.tempConfigURL()
    let store = ConfigStore(fileURL: url, logger: RecordingLogger())
    try store.load()

    var edited = EdgyConfig.defaults
    edited.gestures.dwellMS = 200
    try ConfigStore.encode(edited).write(to: url, options: .atomic)

    #expect(try store.load().gestures.dwellMS == 200)
    #expect(store.config.gestures.dwellMS == 200)
  }

  @Test func watcherReloadsAfterExternalEdit() async throws {
    let url = Sample.tempConfigURL()
    let store = ConfigStore(fileURL: url, debounce: 0.05, logger: RecordingLogger())
    try store.load()
    let received = Locked<EdgyConfig?>(nil)
    store.startWatching { received.value = $0 }
    defer { store.stopWatching() }

    var edited = EdgyConfig.defaults
    edited.gestures.edgeWidthMM = 11
    try ConfigStore.encode(edited).write(to: url, options: .atomic)

    for _ in 0..<100 where received.value == nil {
      try await Task.sleep(for: .milliseconds(20))
    }
    #expect(received.value?.gestures.edgeWidthMM == 11)
    #expect(store.config.gestures.edgeWidthMM == 11)
  }

  @Test func ownSaveDoesNotEchoAsReload() async throws {
    let url = Sample.tempConfigURL()
    let store = ConfigStore(fileURL: url, debounce: 0.05, logger: RecordingLogger())
    try store.load()
    let reloads = Locked(0)
    store.startWatching { _ in reloads.value += 1 }
    defer { store.stopWatching() }

    var changed = EdgyConfig.defaults
    changed.app.enabled = false
    try store.save(changed)
    try await Task.sleep(for: .milliseconds(400))

    #expect(reloads.value == 0)
    #expect(store.config.app.enabled == false)
  }
}
