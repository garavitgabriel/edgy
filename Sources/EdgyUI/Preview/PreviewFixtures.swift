import Actions
import EdgyCore
import EdgyRuntime
import Foundation

/// Demo data for previews and snapshot tests. Uses the real action catalog (building the live
/// registry only reads its catalog; nothing is performed) and invented app names only.
@MainActor
public enum PreviewFixtures {
  /// Invented apps for profile tabs (never a real product name).
  public static let wayfare = "com.example.wayfare"
  public static let huddle = "com.example.huddle"

  /// A Magic-Trackpad-sized pad.
  public static let externalPad = TouchDeviceInfo(
    id: 1, kind: .externalTrackpad, sensorSizeMM: Size2D(width: 160, height: 115), familyID: 0)
  /// A 14-inch-laptop-sized pad.
  public static let builtInPad = TouchDeviceInfo(
    id: 2, kind: .builtInTrackpad, sensorSizeMM: Size2D(width: 134, height: 87), familyID: 0)

  /// Defaults plus two app profiles: Wayfare overrides the bottom swipes and turns the left edge
  /// off; Huddle is off entirely.
  public static var demoConfig: EdgyConfig {
    var config = EdgyConfig.defaults
    config.appProfiles[wayfare] = Profile(
      bindings: [
        Binding(
          zone: .edge(.bottom), gesture: .swipe(.left), action: "keyboard.shortcut",
          parameters: ["keys": "cmd+shift+leftbracket"]),
        Binding(zone: .edge(.left), gesture: .slide, action: .doNothing),
        Binding(zone: .corner(.bottomRight), gesture: .longPress, action: "keyboard.hold", parameters: ["keys": "fn"]),
      ], inheritsDefault: true)
    config.appProfiles[huddle] = Profile(bindings: [], disabled: true, inheritsDefault: true)
    return config
  }

  /// A model with no engine: a static mirror unless a test calls `simulate`.
  public static func model(config: EdgyConfig? = nil, device: TouchDeviceInfo = externalPad) -> SettingsModel {
    let actions = makeLiveActionRegistry(settings: .defaults)
    let start = config ?? demoConfig
    let store = MemoryStore(start)
    let editor = SettingsEditor(
      config: start, catalog: actions.available, store: store, scheduler: ImmediateScheduler(), apply: { _ in })
    let model = SettingsModel(editor: editor, engine: nil, devices: [device])
    model.simulate(EngineStatus(running: true, paused: false, pausedUntil: nil, enabled: true, devices: [device]))
    return model
  }
}

/// In-memory config store for previews and tests.
public final class MemoryStore: SettingsPersisting {
  public private(set) var saved: EdgyConfig

  public init(_ config: EdgyConfig) { saved = config }

  public func load() throws -> EdgyConfig { saved }
  public func save(_ config: EdgyConfig) throws { saved = config }
}

/// Runs scheduled work on the next main-queue turn; previews never wait on real time.
@MainActor
public final class ImmediateScheduler: Scheduling {
  public init() {}

  @discardableResult
  public func schedule(after seconds: TimeInterval, _ work: @escaping @MainActor @Sendable () -> Void)
    -> ScheduledWork
  {
    MainQueueScheduler().schedule(after: 0, work)
  }
}
