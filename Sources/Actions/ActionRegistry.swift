import EdgyCore

/// Action identifiers the registry knows.
public enum BuiltInAction {
  public static let volume: ActionID = "audio.volume"
  public static let mute: ActionID = "audio.mute"
  public static let brightness: ActionID = "display.brightness"
  public static let micMute: ActionID = "mic.mute"
  public static let playPause: ActionID = "media.playPause"
  public static let next: ActionID = "media.next"
  public static let previous: ActionID = "media.previous"
  public static let runShortcut: ActionID = "shortcut.run"
}

/// Maps a continuous gesture delta onto a 0...1 level and decides which haptics it earns.
///
/// - `new = clamp(old + delta * sensitivity, 0, 1)`.
/// - The range is split into 16 steps. Every step boundary crossed by one update counts once.
/// - Landing on 0 or 1 (from somewhere else) earns one strong tick, which replaces that
///   boundary's normal tick. Pushing further while already pinned earns nothing.
struct LevelStep: Equatable {
  static let steps = 16.0

  var level: Double
  var ticks: Int
  var strongTick: Bool

  static func apply(delta: Double, sensitivity: Double, to old: Double) -> LevelStep {
    let start = min(max(old, 0), 1)
    let new = min(max(start + delta * sensitivity, 0), 1)
    // Boundaries k/16 passed or landed on, not counting the one the move started from.
    var crossed =
      new >= start
      ? Int((new * steps).rounded(.down) - (start * steps).rounded(.down))
      : Int((start * steps).rounded(.up) - (new * steps).rounded(.up))
    let hitEnd = new != start && (new == 0 || new == 1)
    if hitEnd { crossed -= 1 }
    return LevelStep(level: new, ticks: max(crossed, 0), strongTick: hitEnd)
  }
}

/// The action registry: turns `(ActionID, ActionInput)` into calls on system outputs.
///
/// Not thread-safe; call it from one thread (the router's).
public final class ActionRegistry: ActionPerforming {
  /// HUD and haptics follow these live; the app may replace them at any time.
  public var settings: AppSettings

  let audio: AudioOutput
  let display: BrightnessOutput
  let media: MediaKeyOutput
  let hud: HUDOutput
  let haptics: HapticOutput
  let shortcuts: ShortcutRunner

  /// Level of the slide in progress, per action. Avoids re-reading (and re-quantizing) the
  /// system value on every frame.
  private var sessionLevels: [ActionID: Double] = [:]

  init(
    settings: AppSettings, audio: AudioOutput, display: BrightnessOutput, media: MediaKeyOutput,
    hud: HUDOutput, haptics: HapticOutput, shortcuts: ShortcutRunner
  ) {
    self.settings = settings
    self.audio = audio
    self.display = display
    self.media = media
    self.hud = hud
    self.haptics = haptics
    self.shortcuts = shortcuts
  }

  public let available: [ActionDescriptor] = [
    ActionDescriptor(id: BuiltInAction.volume, shape: .continuous, displayName: "Volume"),
    ActionDescriptor(id: BuiltInAction.mute, shape: .trigger, displayName: "Mute"),
    ActionDescriptor(id: BuiltInAction.brightness, shape: .continuous, displayName: "Brightness"),
    ActionDescriptor(id: BuiltInAction.micMute, shape: .trigger, displayName: "Microphone Mute"),
    ActionDescriptor(id: BuiltInAction.playPause, shape: .trigger, displayName: "Play / Pause"),
    ActionDescriptor(id: BuiltInAction.next, shape: .trigger, displayName: "Next Track"),
    ActionDescriptor(id: BuiltInAction.previous, shape: .trigger, displayName: "Previous Track"),
    ActionDescriptor(id: BuiltInAction.runShortcut, shape: .trigger, displayName: "Run Shortcut"),
  ]

  public func perform(_ id: ActionID, input: ActionInput, context: ActionContext) throws {
    guard let descriptor = available.first(where: { $0.id == id }) else {
      throw ActionError.unknownAction(id)
    }
    switch (descriptor.shape, input) {
    case (.continuous, .delta(let delta, let phase)):
      try performContinuous(id, delta: delta, phase: phase, context: context)
    case (.trigger, .trigger):
      try performTrigger(id, context: context)
    default:
      throw ActionError.wrongInputShape(id)
    }
  }

  // MARK: - Continuous

  private func performContinuous(
    _ id: ActionID, delta: Double, phase: GestureEvent.Phase, context: ActionContext
  ) throws {
    if phase == .began { sessionLevels[id] = nil }
    defer { if phase == .ended || phase == .cancelled { sessionLevels[id] = nil } }

    let old = try sessionLevels[id] ?? currentLevel(id)
    let step = LevelStep.apply(delta: delta, sensitivity: Self.sensitivity(context), to: old)
    sessionLevels[id] = step.level
    guard step.level != old else { return }

    try setLevel(id, step.level, rising: step.level > old)
    if settings.haptics {
      if step.strongTick { haptics.strongTick() }
      for _ in 0..<step.ticks { haptics.tick() }
    }
  }

  static func sensitivity(_ context: ActionContext) -> Double {
    guard let raw = context.parameters["sensitivity"], let value = Double(raw), value.isFinite else {
      return 1.0
    }
    return value
  }

  private func currentLevel(_ id: ActionID) throws -> Double {
    try unavailable(id) {
      if id == BuiltInAction.volume { return try audio.outputVolume() }
      guard display.isAvailable else { throw OutputError("no built-in display") }
      return try display.brightness()
    }
  }

  private func setLevel(_ id: ActionID, _ level: Double, rising: Bool) throws {
    try unavailable(id) {
      if id == BuiltInAction.volume {
        try audio.setOutputVolume(level)
        // Raising the volume while muted unmutes, as the hardware keys do.
        var muted = (try? audio.isOutputMuted()) ?? false
        if muted, rising {
          try audio.setOutputMuted(false)
          muted = false
        }
        showHUD(.volume(muted: muted, headphones: audio.outputIsHeadphones()), level: level)
      } else {
        guard display.isAvailable else { throw OutputError("no built-in display") }
        try display.setBrightness(level)
        showHUD(.brightness, level: level)
      }
    }
  }

  // MARK: - Triggers

  private func performTrigger(_ id: ActionID, context: ActionContext) throws {
    switch id {
    case BuiltInAction.mute:
      try unavailable(id) {
        let muted = try !audio.isOutputMuted()
        try audio.setOutputMuted(muted)
        let level = (try? audio.outputVolume()) ?? 0
        showHUD(.volume(muted: muted, headphones: audio.outputIsHeadphones()), level: muted ? 0 : level)
      }
    case BuiltInAction.micMute:
      try unavailable(id) { try audio.setInputMuted(!audio.isInputMuted()) }
    case BuiltInAction.playPause: media.playPause()
    case BuiltInAction.next: media.next()
    case BuiltInAction.previous: media.previous()
    case BuiltInAction.runShortcut:
      guard let name = context.parameters["name"], !name.isEmpty else {
        throw ActionError.missingParameter(id, name: "name")
      }
      shortcuts.run(name: name)
    default:
      throw ActionError.unknownAction(id)
    }
  }

  // MARK: - Helpers

  private func showHUD(_ kind: HUDKind, level: Double) {
    guard settings.hud != .none else { return }
    hud.show(kind, level: level)
  }

  /// Runs `body`, turning output failures into `ActionError.unavailable`.
  private func unavailable<T>(_ id: ActionID, _ body: () throws -> T) throws -> T {
    do {
      return try body()
    } catch let error as OutputError {
      throw ActionError.unavailable(id, reason: error.reason)
    } catch let error as ActionError {
      throw error
    } catch {
      throw ActionError.unavailable(id, reason: String(describing: error))
    }
  }
}
