import EdgyCore
import Foundation

@testable import EdgyRuntime

// Doubles for the settings layer. Nothing here touches the real system.

/// A catalog that knows the ids `EdgyConfig.defaults` uses plus made-up `fake.*` actions covering
/// every parameter kind. Never the real registry.
enum FakeCatalog {
  static let parameterKinds: [ActionParameter] = [
    ActionParameter(key: "combo", kind: .keyCombo, required: false, displayName: "Combo"),
    ActionParameter(key: "app", kind: .appBundleID, required: false, displayName: "App"),
    ActionParameter(key: "link", kind: .url, required: false, displayName: "Link"),
    ActionParameter(key: "path", kind: .filePath, required: false, displayName: "Path"),
    ActionParameter(key: "count", kind: .number(1...10), required: false, defaultValue: "1", displayName: "Count"),
    ActionParameter(key: "mode", kind: .choice(["fast", "slow"]), required: false, displayName: "Mode"),
    ActionParameter(key: "note", kind: .text, required: false, displayName: "Note"),
  ]

  static let descriptors: [ActionDescriptor] = [
    ActionDescriptor(id: "audio.volume", shape: .continuous, displayName: "Volume", category: .sound),
    ActionDescriptor(id: "audio.mute", shape: .trigger, displayName: "Mute", category: .sound),
    ActionDescriptor(id: "mic.mute", shape: .trigger, displayName: "Microphone Mute", category: .sound),
    ActionDescriptor(id: "display.brightness", shape: .continuous, displayName: "Brightness", category: .display),
    ActionDescriptor(id: "media.playPause", shape: .trigger, displayName: "Play/Pause", category: .media),
    ActionDescriptor(id: "media.next", shape: .trigger, displayName: "Next Track", category: .media),
    ActionDescriptor(id: "media.previous", shape: .trigger, displayName: "Previous Track", category: .media),
    ActionDescriptor(
      id: "fake.press", shape: .trigger, displayName: "Press Keys", category: .keyboard,
      parameters: [ActionParameter(key: "keys", kind: .keyCombo, required: true, displayName: "Keys")]),
    ActionDescriptor(
      id: "fake.everything", shape: .trigger, displayName: "Everything", category: .apps, parameters: parameterKinds),
  ]

  /// An `ActionPerforming` whose `available` is this catalog, so the editor is fed the way the app feeds it.
  final class Registry: ActionPerforming {
    var available: [ActionDescriptor] { FakeCatalog.descriptors }
    func perform(_ id: ActionID, input: ActionInput, context: ActionContext) throws {}
  }
}

/// Manual clock: work runs only when the test advances time past its deadline.
@MainActor
final class FakeScheduler: Scheduling {
  final class Item: ScheduledWork {
    let due: TimeInterval
    let work: @MainActor @Sendable () -> Void
    var cancelled = false
    init(due: TimeInterval, work: @escaping @MainActor @Sendable () -> Void) {
      self.due = due
      self.work = work
    }
    func cancel() { cancelled = true }
  }

  private(set) var now: TimeInterval = 0
  private var items: [Item] = []

  var pendingCount: Int { items.filter { !$0.cancelled }.count }

  func schedule(after seconds: TimeInterval, _ work: @escaping @MainActor @Sendable () -> Void) -> ScheduledWork {
    let item = Item(due: now + seconds, work: work)
    items.append(item)
    return item
  }

  func advance(by seconds: TimeInterval) {
    now += seconds
    while let next = items.filter({ !$0.cancelled && $0.due <= now }).min(by: { $0.due < $1.due }) {
      items.removeAll { $0 === next }
      next.work()
    }
    items.removeAll { $0.cancelled }
  }
}

@MainActor
final class FakePermissionChecker: PermissionChecking {
  var state: PermissionState
  private(set) var checks = 0
  init(_ state: PermissionState) { self.state = state }
  var accessibility: PermissionState {
    checks += 1
    return state
  }
}

/// A store whose saves can be made to fail; loads return `loadResult`.
final class FailingStore: SettingsPersisting {
  struct SaveFailed: Error {}
  var failSaves = true
  var saved: [EdgyConfig] = []
  var loadResult: EdgyConfig = .defaults
  func load() throws -> EdgyConfig { loadResult }
  func save(_ config: EdgyConfig) throws {
    if failSaves { throw SaveFailed() }
    saved.append(config)
  }
}

/// A real `ConfigStore` in a temp dir, an editor over it, and recordings of what it applied and
/// announced.
@MainActor
final class EditorHarness {
  final class Recorder {
    var applied: [EdgyConfig] = []
    var changes: [SettingsChange] = []
  }

  let store: ConfigStore
  let scheduler = FakeScheduler()
  let recorder = Recorder()
  let logger = RecordingLogger()
  let editor: SettingsEditor

  init(config: EdgyConfig = .defaults, debounce: TimeInterval = 0.3) throws {
    store = ConfigStore(fileURL: Sample.tempConfigURL(), debounce: debounce, logger: RecordingLogger())
    try store.save(config)
    let recorder = recorder
    editor = SettingsEditor(
      config: config, catalog: FakeCatalog.Registry().available, store: store, scheduler: scheduler,
      logger: logger, apply: { recorder.applied.append($0) })
    editor.observe { recorder.changes.append($0) }
  }

  var applied: [EdgyConfig] { recorder.applied }
  var changes: [SettingsChange] { recorder.changes }

  func onDisk() throws -> EdgyConfig {
    try JSONDecoder().decode(EdgyConfig.self, from: Data(contentsOf: store.fileURL))
  }
}
