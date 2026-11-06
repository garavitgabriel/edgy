import EdgyCore
import Foundation

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

/// Turns slide travel into whole key presses: one per `step` of travel, unbounded.
///
/// Travel that doesn't reach a whole step is carried to the next update, so slow slides press
/// as often as fast ones over the same distance. Moving back the other way first pays off the
/// carry before it presses the opposite keys.
struct KeySteps: Equatable {
  /// Positive: presses toward top/right; negative: the other way.
  var presses: Int
  var carry: Double

  /// Upper bound on presses from one update, so a runaway delta can't flood the event stream.
  static let maxPressesPerUpdate = 64

  static func apply(travel: Double, step: Double, carry: Double) -> KeySteps {
    let total = carry + travel
    // A hair of tolerance so 0.3 / 0.1 counts as 3, not 2.999….
    let raw = total / step
    let whole = (raw + (raw >= 0 ? 1e-9 : -1e-9)).rounded(.towardZero)
    let presses = Int(min(max(whole, -Double(maxPressesPerUpdate)), Double(maxPressesPerUpdate)))
    let left = total - Double(presses) * step
    return KeySteps(presses: presses, carry: abs(left) < 1e-9 ? 0 : left)
  }
}

/// The action registry: turns `(ActionID, ActionInput)` into calls on system outputs.
///
/// Not thread-safe; call it from one thread (the router's).
public final class ActionRegistry: ActionPerforming {
  /// HUD and haptics follow these live; the app may replace them at any time.
  public var settings: AppSettings

  public func apply(settings: AppSettings) { self.settings = settings }

  public func feedback(_ event: HapticEvent, context: ActionContext) {
    guard settings.allowsHaptic(event, parameters: context.parameters) else { return }
    switch event {
    case .gestureCaught, .slideSteps: haptics.tick(strength: settings.hapticTickStrength)
    case .actionFired, .slideLimits: haptics.strongTick(strength: settings.hapticClickStrength)
    }
  }

  let audio: AudioOutput
  let display: BrightnessOutput
  let media: MediaKeyOutput
  let hud: HUDOutput
  let haptics: HapticOutput
  let shortcuts: ShortcutRunner
  let keyboard: KeyboardOutput
  let workspace: WorkspaceOutput
  let windows: WindowOutput
  let system: SystemOutput

  /// Level of the slide in progress, per action. Avoids re-reading (and re-quantizing) the
  /// system value on every frame.
  private var sessionLevels: [ActionID: Double] = [:]

  /// Travel toward the next key press of the `keyboard.slideSteps` slide in progress.
  private var keyStepCarry: Double = 0

  /// Each snapped window's frame from before Edgy first snapped it, for `window.restore`. A
  /// chain of snaps (left, then maximize…) keeps the frame from before the chain.
  private(set) var snapMemory: [WindowID: CGRect] = [:]
  /// Windows come and go; forget the oldest memories past this many.
  static let snapMemoryLimit = 32
  private var snapOrder: [WindowID] = []

  init(
    settings: AppSettings, audio: AudioOutput, display: BrightnessOutput, media: MediaKeyOutput,
    hud: HUDOutput, haptics: HapticOutput, shortcuts: ShortcutRunner, keyboard: KeyboardOutput,
    workspace: WorkspaceOutput, windows: WindowOutput, system: SystemOutput
  ) {
    self.settings = settings
    self.audio = audio
    self.display = display
    self.media = media
    self.hud = hud
    self.haptics = haptics
    self.shortcuts = shortcuts
    self.keyboard = keyboard
    self.workspace = workspace
    self.windows = windows
    self.system = system
  }

  public let available: [ActionDescriptor] = ActionCatalog.all

  public func perform(_ id: ActionID, input: ActionInput, context: ActionContext) throws {
    guard let descriptor = available.first(where: { $0.id == id }) else {
      throw ActionError.unknownAction(id)
    }
    switch (descriptor.shape, input) {
    case (.continuous, .delta(let delta, let phase)):
      if id == BuiltInAction.keyboardSlideSteps {
        try performKeySteps(id, delta: delta, phase: phase, context: context)
      } else {
        try performContinuous(id, delta: delta, phase: phase, context: context)
      }
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
    if step.strongTick && settings.allowsHaptic(.slideLimits, parameters: context.parameters) {
      haptics.strongTick(strength: settings.hapticClickStrength)
    }
    if settings.allowsHaptic(.slideSteps, parameters: context.parameters) {
      for _ in 0..<step.ticks { haptics.tick(strength: settings.hapticTickStrength) }
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

  /// `keyboard.slideSteps`: one press of `upKeys` / `downKeys` per `step` of travel. The
  /// binding's sensitivity scales travel, as it does for levels. Parameters are checked on every
  /// update (including `.began`) so a bad binding fails as soon as the slide starts.
  private func performKeySteps(
    _ id: ActionID, delta: Double, phase: GestureEvent.Phase, context: ActionContext
  ) throws {
    if phase == .began { keyStepCarry = 0 }
    defer { if phase == .ended || phase == .cancelled { keyStepCarry = 0 } }

    let up = try combo(ActionParameterKey.upKeys, for: id, in: context)
    let down = try combo(ActionParameterKey.downKeys, for: id, in: context)
    let step = try number(
      ActionParameterKey.step, for: id, in: context, range: ActionCatalog.stepRange,
      default: ActionCatalog.defaultStep)

    let result = KeySteps.apply(travel: delta * Self.sensitivity(context), step: step, carry: keyStepCarry)
    keyStepCarry = result.carry
    guard result.presses != 0 else { return }
    let keys = result.presses > 0 ? up : down
    let tick = settings.allowsHaptic(.slideSteps, parameters: context.parameters)
    for _ in 0..<abs(result.presses) {
      try unavailable(id) { try keyboard.post(keys) }
      if tick { haptics.tick(strength: settings.hapticTickStrength) }
    }
  }

  // MARK: - Triggers

  private func performTrigger(_ id: ActionID, context: ActionContext) throws {
    if let command = ActionCatalog.systemCommands[id] {
      return try unavailable(id) { try system.perform(command) }
    }
    if let snap = ActionCatalog.windowSnaps[id] {
      return try unavailable(id) { try snapWindow(snap) }
    }
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
      shortcuts.run(name: try text(ActionParameterKey.shortcutName, for: id, in: context))
    case BuiltInAction.keyboardShortcut:
      let keys = try combo(ActionParameterKey.keys, for: id, in: context)
      try unavailable(id) { try keyboard.post(keys) }
    case BuiltInAction.openApp:
      try openApp(id, context: context)
    case BuiltInAction.openURL:
      let raw = try text(ActionParameterKey.url, for: id, in: context)
      guard let url = URL(string: raw), let scheme = url.scheme, !scheme.isEmpty else {
        throw ActionError.missingParameter(id, name: ActionParameterKey.url)
      }
      try unavailable(id) { try workspace.open(url: url) }
    case BuiltInAction.openFile:
      let raw = try text(ActionParameterKey.path, for: id, in: context)
      let path = (raw as NSString).expandingTildeInPath
      guard path.hasPrefix("/") else { throw ActionError.missingParameter(id, name: ActionParameterKey.path) }
      try unavailable(id) { try workspace.open(file: URL(fileURLWithPath: path)) }
    case BuiltInAction.windowMinimize:
      try unavailable(id) { try windows.minimize(windows.focusedWindow().id) }
    case BuiltInAction.windowRestore:
      try unavailable(id) { try restoreWindow() }
    default:
      throw ActionError.unknownAction(id)
    }
  }

  /// `app.open`: brings the app forward (launching it if needed). If it is already frontmost,
  /// `whenFrontmost` decides: `hide` (default) hides it, `stay` brings it forward again.
  private func openApp(_ id: ActionID, context: ActionContext) throws {
    let bundleID = try text(ActionParameterKey.bundleID, for: id, in: context)
    let mode = try choice(
      ActionParameterKey.whenFrontmost, for: id, in: context,
      allowed: [ActionParameterKey.frontmostStay, ActionParameterKey.frontmostHide],
      default: ActionParameterKey.frontmostHide)
    if mode == ActionParameterKey.frontmostHide, workspace.isFrontmost(bundleID: bundleID) {
      workspace.hide(bundleID: bundleID)
    } else {
      try unavailable(id) { try workspace.activate(bundleID: bundleID) }
    }
  }

  // MARK: - Windows

  private func snapWindow(_ snap: WindowSnap) throws {
    let window = try windows.focusedWindow()
    let target = WindowGeometry.target(for: snap, window: window.frame, visible: window.visibleFrame)
    // Remember the frame from before this chain of snaps. A window the user has moved or resized
    // since Edgy last placed it starts a new chain.
    let chained =
      snapMemory[window.id] != nil
      && lastPlaced[window.id].map { Self.roughlyEqual($0, window.frame) } == true
    if !chained { remember(window.frame, for: window.id) }
    try windows.setFrame(target, of: window.id)
    lastPlaced[window.id] = target
  }

  /// Where Edgy last put each remembered window.
  private var lastPlaced: [WindowID: CGRect] = [:]

  /// Apps may round a requested frame (to a text grid, a minimum size), so "still where Edgy put
  /// it" allows this much slack per edge, in points.
  static let placementSlack: CGFloat = 32

  static func roughlyEqual(_ a: CGRect, _ b: CGRect) -> Bool {
    abs(a.minX - b.minX) <= placementSlack && abs(a.minY - b.minY) <= placementSlack
      && abs(a.maxX - b.maxX) <= placementSlack && abs(a.maxY - b.maxY) <= placementSlack
  }

  private func restoreWindow() throws {
    guard !snapMemory.isEmpty else { return }
    let window = try windows.focusedWindow()
    guard let frame = snapMemory[window.id] else { return }
    try windows.setFrame(frame, of: window.id)
    forget(window.id)
  }

  private func remember(_ frame: CGRect, for window: WindowID) {
    snapOrder.removeAll { $0 == window }
    snapOrder.append(window)
    snapMemory[window] = frame
    while snapOrder.count > Self.snapMemoryLimit { forget(snapOrder[0]) }
  }

  private func forget(_ window: WindowID) {
    snapOrder.removeAll { $0 == window }
    snapMemory[window] = nil
    lastPlaced[window] = nil
  }

  // MARK: - Parameters

  /// A required, non-empty text parameter.
  private func text(_ key: String, for id: ActionID, in context: ActionContext) throws -> String {
    guard let value = context.parameters[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty
    else { throw ActionError.missingParameter(id, name: key) }
    return value
  }

  /// A required key combination. Absent → `missingParameter`; present but not a valid combo →
  /// `unavailable` naming the parameter and the text.
  private func combo(_ key: String, for id: ActionID, in context: ActionContext) throws -> KeyCombo {
    let raw = try text(key, for: id, in: context)
    guard let combo = KeyCombo(raw) else {
      throw ActionError.unavailable(id, reason: "\(key): \"\(raw)\" is not a key combination")
    }
    return combo
  }

  /// An optional number. Absent → `defaultValue`; unparseable or outside `range` →
  /// `missingParameter` (there is no usable value).
  private func number(
    _ key: String, for id: ActionID, in context: ActionContext, range: ClosedRange<Double>,
    default defaultValue: Double
  ) throws -> Double {
    guard let raw = context.parameters[key]?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else {
      return defaultValue
    }
    guard let value = Double(raw), range.contains(value) else {
      throw ActionError.missingParameter(id, name: key)
    }
    return value
  }

  /// An optional choice. Absent → `defaultValue`; not one of `allowed` → `missingParameter`.
  private func choice(
    _ key: String, for id: ActionID, in context: ActionContext, allowed: [String], default defaultValue: String
  ) throws -> String {
    guard let raw = context.parameters[key]?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else {
      return defaultValue
    }
    guard allowed.contains(raw) else { throw ActionError.missingParameter(id, name: key) }
    return raw
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
