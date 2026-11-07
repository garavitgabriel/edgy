import Actions
import EdgyCore
import EdgyRuntime
import Foundation

@testable import EdgyUI

/// Fakes for batch 15's tests: nothing here touches the real system (CLAUDE.md rule 1). The
/// catalog is the real one (read only); availability, apps, shortcuts and the key recorder are fakes.
@MainActor
enum InspectorFixtures {
  static let backlitReason = "Needs a backlit keyboard"
  static let spaceNote = "Uses the system Control–Left shortcut"

  /// Demo config plus a tap on the bottom edge (so the tap-waits note shows).
  static var configWithBottomTap: EdgyConfig {
    var config = PreviewFixtures.demoConfig
    config.defaultProfile.bindings.append(Binding(zone: .edge(.bottom), gesture: .tap, action: "audio.mute"))
    return config
  }

  static func model(
    config: EdgyConfig = PreviewFixtures.demoConfig,
    availability: [ActionID: ActionAvailability] = [
      "keyboard.backlight": .unavailable(reason: backlitReason),
      "keyboard.backlightToggle": .unavailable(reason: backlitReason),
      "spaces.left": .limited(reason: spaceNote),
    ],
    recorder: KeyComboRecording? = nil, apps: [InstalledApp] = [], shortcuts: [String] = []
  ) -> SettingsModel {
    let catalog = makeLiveActionRegistry(settings: .defaults).available
    let fake = FakeActions(catalog: catalog, availability: availability)
    let editor = SettingsEditor(
      config: config, catalog: catalog, store: MemoryStore(config), scheduler: ImmediateScheduler(), actions: fake,
      apply: { _ in })
    return SettingsModel(
      editor: editor, engine: nil, installedApps: InspectorFakeApps(apps: apps), shortcuts: FakeShortcuts(names: shortcuts),
      keyRecorder: recorder, devices: [PreviewFixtures.externalPad])
  }

  static let apps = [
    InstalledApp(name: "Quillpad", bundleID: "com.example.quillpad", path: "/Applications/Quillpad.app", isRunning: true),
    InstalledApp(name: "Wayfare", bundleID: "com.example.wayfare", path: "/Applications/Wayfare.app", isRunning: false),
  ]
}

final class FakeActions: ActionPerforming {
  let available: [ActionDescriptor]
  let table: [ActionID: ActionAvailability]

  init(catalog: [ActionDescriptor], availability: [ActionID: ActionAvailability]) {
    available = catalog
    table = availability
  }

  func perform(_ id: ActionID, input: ActionInput, context: ActionContext) throws {}
  func availability(of id: ActionID) -> ActionAvailability { table[id] ?? .available }
}

struct InspectorFakeApps: InstalledAppsProviding {
  var apps: [InstalledApp]
  func installedApps() async -> [InstalledApp] { apps }
}

struct FakeShortcuts: ShortcutsListing {
  var names: [String]
  func shortcuts() async -> ShortcutsList { ShortcutsList(names: names) }
}

/// A recorder the test drives: each `start` hands back a stream whose continuation the test keeps.
final class FakeRecorder: KeyComboRecording, @unchecked Sendable {
  private(set) var continuation: AsyncStream<KeyRecorderState>.Continuation?
  private(set) var starts = 0
  private(set) var cancels = 0

  func start(timeout: TimeInterval) -> AsyncStream<KeyRecorderState> {
    starts += 1
    let (stream, continuation) = AsyncStream.makeStream(of: KeyRecorderState.self)
    self.continuation = continuation
    continuation.yield(.listening(held: []))
    return stream
  }

  func cancel() {
    cancels += 1
    continuation?.yield(.cancelled)
    continuation?.finish()
  }

  func send(_ state: KeyRecorderState) {
    continuation?.yield(state)
    if state.isFinal { continuation?.finish() }
  }
}

/// A clock the test moves by hand.
final class TestClock: @unchecked Sendable {
  var now = Date(timeIntervalSinceReferenceDate: 1000)
  func advance(_ seconds: TimeInterval) { now += seconds }
}
