import Displays
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
    var crossed = crossings(from: start, to: new, steps: steps)
    let hitEnd = new != start && (new == 0 || new == 1)
    if hitEnd { crossed -= 1 }
    return LevelStep(level: new, ticks: max(crossed, 0), strongTick: hitEnd)
  }

  /// Boundaries k/`steps` passed or landed on between `start` and `new` (either direction), not
  /// counting the one the move started from.
  static func crossings(from start: Double, to new: Double, steps: Double) -> Int {
    new >= start
      ? Int((new * steps).rounded(.down) - (start * steps).rounded(.down))
      : Int((start * steps).rounded(.up) - (new * steps).rounded(.up))
  }
}

/// The system's fine level steps: with the fine-step modifiers held, each volume or brightness
/// key press moves the level 1/64 of its range (four presses per normal 1/16 step).
enum FineSteps {
  static let perRange = 64.0
  /// One `slideSteps` haptic per this many fine steps, i.e. one per 1/16: the grid
  /// `HapticEvent.slideSteps` promises, the one the system HUD draws, and the one the
  /// CoreAudio / external-display paths already tick on. A tick per fine step (64 per full
  /// slide) reads as a buzz, not as steps.
  static let perTick = 4

  /// Signed key presses that move a level from `old` to `new`: every 1/64 boundary crossed.
  static func presses(from old: Double, to new: Double) -> Int {
    let count = LevelStep.crossings(from: old, to: new, steps: perRange)
    return new >= old ? count : -count
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

/// What a level slide drives. Chosen when the slide starts and kept until it ends, so moving the
/// pointer to another display mid-slide doesn't switch targets.
enum LevelTarget: Equatable {
  case volume
  case builtInBrightness
  /// A display controlled through `Displays` (an external monitor, or a built-in panel the
  /// built-in brightness output can't reach).
  case displayBrightness(UInt32)
  case keyboardBacklight
}

/// The action registry: turns `(ActionID, ActionInput)` into calls on system outputs.
///
/// Call `perform` from one thread (the router's). The one exception is window work that waits
/// for a full-screen exit: it finishes on the `TransitionWaiter`'s queue, so the window memory
/// it shares is behind `windowLock`. `availability(of:)` may be called from any thread.
public final class ActionRegistry: ActionPerforming, @unchecked Sendable {
  /// HUD and haptics follow these live; the app may replace them at any time.
  public var settings: AppSettings

  public func apply(settings: AppSettings) { self.settings = settings }

  public func feedback(_ event: HapticEvent, context: ActionContext) {
    guard settings.allowsHaptic(event, parameters: context.parameters) else { return }
    haptics.target(deviceID: context.deviceID)
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
  let levelKeys: LevelKeyOutput
  let displays: DisplayBrightnessControlling
  let backlight: KeyboardBacklightOutput
  let dictation: DictationOutput
  let waiter: TransitionWaiter
  let scheduler: ActionScheduler
  let switcherInput: SwitcherInputMonitor

  /// The level slide in progress, per action. Keeps its own level rather than re-reading (and
  /// re-quantizing) the system value on every frame.
  struct LevelSession {
    var target: LevelTarget
    var level: Double
    var feel = LevelFeel()
  }
  private var levelSessions: [ActionID: LevelSession] = [:]

  /// The `keyboard.slideSteps` slide in progress: its stepper (carry, speed, end stepping).
  private var keySteps: SlideStepper?

  /// Last non-zero keyboard backlight level, for `keyboard.backlightToggle`.
  var backlightMemory: Double?
  /// Toggling the backlight on with nothing remembered goes to this level.
  static let defaultBacklightLevel = 0.5

  /// Logged once: level keys couldn't be posted and the registry fell back to setting levels.
  private var loggedLevelKeyFallback = false
  /// The last level-key post failed and the level was set directly. The legacy system HUD is not
  /// shown then (it read as an old copy of Edgy); the outcome says no system HUD, so Edgy's own
  /// level plate shows instead. Cleared by the next post that works.
  private var levelKeysFallingBack = false

  // App switcher and hold-a-key sessions (see `ActionRegistry+Keys.swift`). Guarded by
  // `keyLock`: their watchdogs fire on the scheduler's queue.
  let keyLock = NSRecursiveLock()
  var switcher: SwitcherSession?
  var heldCombo: KeyCombo?
  /// Bumped for every new hold / switcher session, so a watchdog that fires late can't end a
  /// newer session than the one it was armed for.
  var keySessionGeneration = 0
  var holdWatchdog: ScheduledWork?
  var switcherWatchdog: ScheduledWork?
  /// The app switcher's keep-open timer while a session lingers between strokes.
  var switcherLinger: ScheduledWork?
  /// The `keyboard.shortcut` sequence still sending, if any (batch 32). Behind `keyLock`.
  var keySequence: KeySequenceRun?
  var sequenceGeneration = 0

  /// Apps in the order they were in front, for `app.last`. Behind `appHistoryLock`: the
  /// activation tracker records from its own thread.
  let apps: AppActivationOutput
  let appHistoryLock = NSLock()
  var appHistory = AppHistory()

  // Window memory (see `ActionRegistry+Windows.swift`). Guarded by `windowLock`.
  let windowLock = NSRecursiveLock()
  /// Each snapped window's frame from before Edgy first snapped it, for `window.restore`. A
  /// chain of snaps (left, then maximize…) keeps the frame from before the chain.
  var snapMemory: [WindowID: CGRect] = [:]
  /// Windows come and go; forget the oldest memories past this many.
  static let snapMemoryLimit = 32
  var snapOrder: [WindowID] = []
  /// Where Edgy last put each remembered window.
  var lastPlaced: [WindowID: CGRect] = [:]
  /// Windows asked to leave full screen, and what to do once they have. A newer request for the
  /// same window replaces the older one.
  var pendingFullScreenExits: [WindowID: WindowCommand] = [:]

  // Availability cache (see `ActionRegistry+Availability.swift`). Guarded by `availabilityLock`.
  let availabilityLock = NSLock()
  var availabilityCache: (facts: HardwareFacts, table: [ActionID: ActionAvailability])?

  init(
    settings: AppSettings, audio: AudioOutput, display: BrightnessOutput, media: MediaKeyOutput,
    hud: HUDOutput, haptics: HapticOutput, shortcuts: ShortcutRunner, keyboard: KeyboardOutput,
    workspace: WorkspaceOutput, windows: WindowOutput, system: SystemOutput, levelKeys: LevelKeyOutput,
    displays: DisplayBrightnessControlling, backlight: KeyboardBacklightOutput, dictation: DictationOutput,
    waiter: TransitionWaiter, scheduler: ActionScheduler,
    switcherInput: SwitcherInputMonitor = NoSwitcherInputMonitor(),
    apps: AppActivationOutput = NoAppActivations()
  ) {
    self.switcherInput = switcherInput
    self.apps = apps
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
    self.levelKeys = levelKeys
    self.displays = displays
    self.backlight = backlight
    self.dictation = dictation
    self.waiter = waiter
    self.scheduler = scheduler
    // Listen-only, event-driven: Last App needs the apps used before its first trigger.
    apps.startObserving { [weak self] app in self?.appActivated(app) }
  }

  public let available: [ActionDescriptor] = ActionCatalog.all

  public func perform(_ id: ActionID, input: ActionInput, context: ActionContext) throws {
    _ = try performReporting(id, input: input, context: context)
  }

  /// `perform`, reporting what happened (see `ActionOutcome`):
  /// - **Level slides** (`audio.volume`, `display.brightness`, `keyboard.backlight`): `level` is
  ///   the level after this update (0...1, unchanged when the update moved nothing).
  ///   `systemHUDShown` is true for volume and built-in brightness while the HUD setting is
  ///   `native` (the system draws its indicator). External brightness: `detail` is the display's
  ///   name, followed by a display-check request when one is due (`DisplayCheckRequest`).
  /// - **`keyboard.hold`**: `detail` is the combo as the user reads it (`KeyComboText.text`,
  ///   e.g. "fn", "⌃⌥Space").
  /// - **`apps.switcher`**: no level; `systemHUDShown` is true (the system's app switcher is the
  ///   feedback) once the switcher is open. While a stroke has armed it but not yet travelled one
  ///   step, nothing is showing and the outcome is `nil` (batch 26).
  /// - Everything else: `nil`.
  public func performReporting(_ id: ActionID, input: ActionInput, context: ActionContext) throws
    -> ActionOutcome?
  {
    haptics.target(deviceID: context.deviceID)
    guard let descriptor = available.first(where: { $0.id == id }) else {
      throw ActionError.unknownAction(id)
    }
    switch (descriptor.shape, input) {
    case (.continuous, .delta(let delta, let phase)):
      switch id {
      case BuiltInAction.keyboardSlideSteps:
        try performKeySteps(id, delta: delta, phase: phase, context: context)
        return nil
      case BuiltInAction.appSwitcher:
        let shown = try performSwitcher(id, delta: delta, phase: phase, context: context)
        return shown ? ActionOutcome(systemHUDShown: true) : nil
      default:
        return try performLevel(id, delta: delta, phase: phase, context: context)
      }
    case (.trigger, .trigger):
      try performTrigger(id, context: context)
      return nil
    case (.hold, .press(let down)):
      try performHold(id, down: down, context: context)
      return ActionOutcome(detail: (try? combo(ActionParameterKey.keys, for: id, in: context)).map(KeyComboText.text))
    default:
      throw ActionError.wrongInputShape(id)
    }
  }

  // MARK: - Levels

  /// Volume, brightness and keyboard backlight slides.
  private func performLevel(
    _ id: ActionID, delta: Double, phase: GestureEvent.Phase, context: ActionContext
  ) throws -> ActionOutcome {
    if phase == .began { levelSessions[id] = nil }
    defer { if phase == .ended || phase == .cancelled { levelSessions[id] = nil } }

    var session = try levelSessions[id] ?? startLevelSession(id)
    let old = session.level
    let felt = session.feel.scaled(delta, motion: context.motion, speedUp: try speedUp(id, in: context))
    let step = LevelStep.apply(delta: felt, sensitivity: Self.sensitivity(context), to: old)
    session.level = step.level
    levelSessions[id] = session
    guard step.level != old else { return levelOutcome(session.target, level: step.level) }

    try unavailable(id) { try setLevel(session.target, from: old, to: step.level) }
    if step.strongTick && settings.allowsHaptic(.slideLimits, parameters: context.parameters) {
      haptics.strongTick(strength: settings.hapticClickStrength)
    }
    if settings.allowsHaptic(.slideSteps, parameters: context.parameters) {
      for _ in 0..<step.ticks { haptics.tick(strength: settings.hapticTickStrength) }
    }
    // After `setLevel`: it decides whether the system drew its HUD (keys) or not (fallback).
    return levelOutcome(session.target, level: step.level)
  }

  /// What a level slide reports at `level` on `target`.
  func levelOutcome(_ target: LevelTarget, level: Double) -> ActionOutcome {
    switch target {
    case .volume, .builtInBrightness:
      return ActionOutcome(level: level, systemHUDShown: settings.hud == .native && !levelKeysFallingBack)
    case .keyboardBacklight:
      return ActionOutcome(level: level)
    case .displayBrightness(let id):
      guard let info = displays.displays().first(where: { $0.id == id }) else { return ActionOutcome(level: level) }
      let request = needsDisplayCheck(info) ? DisplayCheckRequest(key: info.key) : nil
      return ActionOutcome(level: level, detail: DisplayCheckRequest.detail(name: info.name, request: request))
    }
  }

  /// Whether to ask "Did this screen change brightness?" about `info`: a monitor driven over DDC
  /// (which can accept a command without applying it) that the user hasn't confirmed or turned
  /// off, asked fewer than `DisplayCheckRequest.maxAsks` times.
  func needsDisplayCheck(_ info: DisplayInfo) -> Bool {
    info.kind == .thirdParty && !settings.confirmedDisplays.contains(info.key)
      && !settings.unresponsiveDisplays.contains(info.key)
      && settings.displayCheckAsks[info.key, default: 0] < DisplayCheckRequest.maxAsks
  }

  static func sensitivity(_ context: ActionContext) -> Double {
    guard let raw = context.parameters["sensitivity"], let value = Double(raw), value.isFinite else {
      return 1.0
    }
    return value
  }

  /// Picks the target and reads its current level. The start level always comes from the system
  /// (CoreAudio, the display, the backlight), so slides begin where the keys left off.
  private func startLevelSession(_ id: ActionID) throws -> LevelSession {
    try unavailable(id) {
      let target = try levelTarget(id)
      let level: Double
      switch target {
      case .volume: level = try audio.outputVolume()
      case .builtInBrightness: level = try display.brightness()
      case .displayBrightness(let display): level = try displays.brightness(of: display)
      case .keyboardBacklight:
        level = try backlight.level()
        if level > 0 { backlightMemory = level }
      }
      return LevelSession(target: target, level: level)
    }
  }

  private func levelTarget(_ id: ActionID) throws -> LevelTarget {
    switch id {
    case BuiltInAction.volume: return .volume
    case BuiltInAction.brightness: return try brightnessTarget()
    case BuiltInAction.keyboardBacklight:
      guard backlight.isAvailable else { throw OutputError(Self.noBacklightReason) }
      return .keyboardBacklight
    default: throw ActionError.unknownAction(id)
    }
  }

  /// The display under the pointer: the built-in panel goes through the brightness keys (or the
  /// built-in output); a controllable external display through `Displays`; any other display is
  /// unavailable with its own reason. When `Displays` doesn't know the active display, the
  /// built-in panel, if there is one.
  // HUD for external displays: design sprint. External displays show no system HUD today.
  func brightnessTarget() throws -> LevelTarget {
    if let active = displays.activeDisplayID(), let info = displays.displays().first(where: { $0.id == active }) {
      switch info.kind {
      case .builtIn where display.isAvailable:
        return .builtInBrightness
      default:
        guard info.brightnessControllable else {
          throw OutputError(info.reason ?? "\(info.name) doesn't accept brightness control")
        }
        guard !settings.unresponsiveDisplays.contains(info.key) else {
          throw OutputError(AvailabilityCopy.turnedOffForDisplay)
        }
        return .displayBrightness(info.id)
      }
    }
    guard display.isAvailable else { throw OutputError("no built-in display") }
    return .builtInBrightness
  }

  /// Moves `target` from `old` to `new`.
  ///
  /// Volume and built-in brightness, HUD `.native`: the system's own keys with fine steps, so
  /// macOS changes the level and shows its current HUD. If the keys can't be posted, the level
  /// is set directly and Edgy's own level plate shows (no legacy HUD: on macOS 26 it looked like an
  /// old copy of Edgy). HUD `.none`: set directly, silently.
  private func setLevel(_ target: LevelTarget, from old: Double, to new: Double) throws {
    let rising = new > old
    switch target {
    case .volume:
      if settings.hud == .native, try pressLevelKeys(rising ? .volumeUp : .volumeDown, from: old, to: new) {
        return
      }
      try audio.setOutputVolume(new)
      // Raising the volume while muted unmutes, as the hardware keys do.
      var muted = (try? audio.isOutputMuted()) ?? false
      if muted, rising {
        try audio.setOutputMuted(false)
        muted = false
      }
      _ = muted  // Edgy's plate shows the level; the legacy HUD's mute glyph is no longer drawn.
    case .builtInBrightness:
      if settings.hud == .native,
        try pressLevelKeys(rising ? .brightnessUp : .brightnessDown, from: old, to: new)
      {
        return
      }
      try display.setBrightness(new)
    case .displayBrightness(let id):
      try displays.setBrightness(new, of: id)
    case .keyboardBacklight:
      try backlight.setLevel(new)
      if new > 0 { backlightMemory = new }
    }
  }

  /// Posts the fine-step presses between `old` and `new`. True when the keys took care of it
  /// (including "no whole step crossed yet"); false when posting failed and the caller should
  /// set the level itself.
  private func pressLevelKeys(_ key: LevelKey, from old: Double, to new: Double) throws -> Bool {
    let presses = abs(FineSteps.presses(from: old, to: new))
    guard presses > 0 else { return true }
    do {
      try levelKeys.press(key, count: presses, fine: true)
      levelKeysFallingBack = false
      return true
    } catch {
      levelKeysFallingBack = true
      if !loggedLevelKeyFallback {
        loggedLevelKeyFallback = true
        actionsLog.notice(
          "level keys unavailable (\(String(describing: error), privacy: .public)); setting levels directly")
      }
      return false
    }
  }

  /// `keyboard.slideSteps`: one press of `upKeys` / `downKeys` per `stepMM` of travel, with the
  /// shared slide feel (speed-up, end stepping; `SlideFeel`). The binding's sensitivity scales
  /// travel, as it does for levels. Parameters are checked on every update (including `.began`) so
  /// a bad binding fails as soon as the slide starts. Haptics: a tick per press, and a stronger
  /// click when end stepping starts.
  private func performKeySteps(
    _ id: ActionID, delta: Double, phase: GestureEvent.Phase, context: ActionContext
  ) throws {
    if phase == .began { keySteps = nil }
    defer { if phase == .ended || phase == .cancelled { keySteps = nil } }

    let up = try singleCombo(ActionParameterKey.upKeys, for: id, in: context, keyed: true)
    let down = try singleCombo(ActionParameterKey.downKeys, for: id, in: context, keyed: true)
    let unit = try stepUnit(
      id, in: context, legacyRange: ActionCatalog.stepRange, legacyDefault: ActionCatalog.defaultStep,
      zoneLengthMM: Self.zoneLength(delta: delta, motion: context.motion))
    let speedUp = try speedUp(id, in: context)
    var stepper = keySteps ?? SlideStepper(step: unit.step, speedUp: speedUp)
    stepper.step = unit.step
    stepper.speedUp = speedUp
    let result = stepper.advance(travel: unit.travel(delta) * Self.sensitivity(context), motion: unit.motion)
    keySteps = stepper
    guard result.steps != 0 else { return }
    let keys = result.steps > 0 ? up : down
    let tick = settings.allowsHaptic(.slideSteps, parameters: context.parameters)
    if result.endStarted && settings.allowsHaptic(.slideLimits, parameters: context.parameters) {
      haptics.strongTick(strength: settings.hapticClickStrength)
    }
    for _ in 0..<abs(result.steps) {
      try unavailable(id) { try keyboard.post(keys) }
      if tick { haptics.tick(strength: settings.hapticTickStrength) }
    }
  }

  /// How a stepped slide measures travel for this update.
  struct StepUnit {
    /// Per step, in the units `travel` returns (millimetres with a motion, else normalized).
    var step: Double
    var motion: SlideMotion?

    func travel(_ delta: Double) -> Double { motion?.deltaMM ?? delta }
  }

  /// The step for a stepped slide (`apps.switcher`, `keyboard.slideSteps`):
  /// - With a motion (the recognizer measured millimetres): `stepMM`; else the legacy fraction
  ///   `step` converted with the zone's length (`stepMigrationLengthMM`); else `defaultStepMM`.
  /// - Without one (an old caller): the legacy fraction `step` (or its default) on the normalized
  ///   delta, exactly as before batch 20. A `stepMM` there is converted with a 100 mm zone.
  func stepUnit(
    _ id: ActionID, in context: ActionContext, legacyRange: ClosedRange<Double>, legacyDefault: Double,
    zoneLengthMM: Double? = nil
  ) throws -> StepUnit {
    let stepMM =
      context.parameters[ActionParameterKey.stepMM] == nil
      ? nil
      : try number(
        ActionParameterKey.stepMM, for: id, in: context, range: ActionCatalog.stepMMRange,
        default: ActionCatalog.defaultStepMM)
    let legacy =
      context.parameters[ActionParameterKey.step] == nil
      ? nil
      : try number(ActionParameterKey.step, for: id, in: context, range: legacyRange, default: legacyDefault)
    guard let motion = context.motion else {
      return StepUnit(step: legacy ?? stepMM.map { $0 / Self.legacyZoneLengthMM } ?? legacyDefault, motion: nil)
    }
    if let stepMM { return StepUnit(step: stepMM, motion: motion) }
    if let legacy { return StepUnit(step: legacy * (zoneLengthMM ?? Self.legacyZoneLengthMM), motion: motion) }
    return StepUnit(step: ActionCatalog.defaultStepMM, motion: motion)
  }

  /// A `stepMM` read without a motion (or a legacy `step` on an update that carries no travel, so
  /// its zone's length is unknown) is converted as if the zone were this long.
  static let legacyZoneLengthMM = 100.0

  /// The zone's length in millimetres, from an update that moved (`deltaMM / delta`).
  static func zoneLength(delta: Double, motion: SlideMotion?) -> Double? {
    guard let motion, delta != 0, motion.deltaMM != 0 else { return nil }
    return abs(motion.deltaMM / delta)
  }

  /// Whether `speedUp` is on (default: the action's catalog default — off for stepped slides, on
  /// for levels); anything but "on"/"off" is a bad parameter.
  func speedUp(_ id: ActionID, in context: ActionContext) throws -> Bool {
    let fallback =
      available.first { $0.id == id }?.parameters.first { $0.key == ActionParameterKey.speedUp }?.defaultValue
      ?? ActionParameterKey.on
    return try choice(
      ActionParameterKey.speedUp, for: id, in: context, allowed: [ActionParameterKey.on, ActionParameterKey.off],
      default: fallback) == ActionParameterKey.on
  }

  // MARK: - Triggers

  private func performTrigger(_ id: ActionID, context: ActionContext) throws {
    if let command = ActionCatalog.systemCommands[id] {
      return try unavailable(id) { try system.perform(command) }
    }
    if let snap = ActionCatalog.windowSnaps[id] {
      return try unavailable(id) { try windowCommand(.snap(snap)) }
    }
    switch id {
    case BuiltInAction.mute:
      try unavailable(id) { try toggleMute() }
    case BuiltInAction.micMute:
      try unavailable(id) { try audio.setInputMuted(!audio.isInputMuted()) }
    case BuiltInAction.playPause: media.playPause()
    case BuiltInAction.next: media.next()
    case BuiltInAction.previous: media.previous()
    case BuiltInAction.runShortcut:
      shortcuts.run(name: try text(ActionParameterKey.shortcutName, for: id, in: context))
    case BuiltInAction.keyboardShortcut:
      try performShortcut(id, context: context)
    case BuiltInAction.openApp:
      try openApp(id, context: context)
    case BuiltInAction.lastApp:
      try performLastApp(id)
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
      try unavailable(id) { try windowCommand(.minimize) }
    case BuiltInAction.windowRestore:
      try unavailable(id) { try restoreWindow() }
    case BuiltInAction.dictation:
      try unavailable(id) { try dictation.toggle() }
    case BuiltInAction.keyboardBacklightToggle:
      try unavailable(id) { try toggleBacklight() }
    case BuiltInAction.doNothing:
      // Resolution drops these bindings; one that slips through does nothing, on purpose.
      return
    default:
      throw ActionError.unknownAction(id)
    }
  }

  /// HUD `.native`: the system mute key (system HUD). Otherwise, or if the key can't be posted,
  /// CoreAudio, plus the legacy HUD when it is on.
  private func toggleMute() throws {
    if settings.hud == .native {
      do {
        try levelKeys.press(.mute, count: 1, fine: false)
        return
      } catch {
        actionsLog.notice("mute key unavailable (\(String(describing: error), privacy: .public)); muting directly")
      }
    }
    let muted = try !audio.isOutputMuted()
    try audio.setOutputMuted(muted)
    let level = (try? audio.outputVolume()) ?? 0
    showHUD(.volume(muted: muted, headphones: audio.outputIsHeadphones()), level: muted ? 0 : level)
  }

  /// Off if lit (remembering the level), else back to the last non-zero level.
  private func toggleBacklight() throws {
    guard backlight.isAvailable else { throw OutputError(Self.noBacklightReason) }
    let current = try backlight.level()
    if current > 0 {
      backlightMemory = current
      try backlight.setLevel(0)
    } else {
      try backlight.setLevel(backlightMemory ?? Self.defaultBacklightLevel)
    }
  }

  static let noBacklightReason = "This Mac's keyboard has no backlight."

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

  // MARK: - Parameters

  /// A required, non-empty text parameter.
  func text(_ key: String, for id: ActionID, in context: ActionContext) throws -> String {
    guard let value = context.parameters[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty
    else { throw ActionError.missingParameter(id, name: key) }
    return value
  }

  /// A required key combination. Absent → `missingParameter`; present but not a valid combo →
  /// `unavailable` naming the parameter and the text.
  func combo(_ key: String, for id: ActionID, in context: ActionContext) throws -> KeyCombo {
    let raw = try text(key, for: id, in: context)
    guard let combo = KeyCombo(raw) else {
      throw ActionError.unavailable(id, reason: "\(key): \"\(raw)\" is not a key combination")
    }
    return combo
  }

  /// A required key combination that ends in a key, for actions that type it (shortcut, slide
  /// steps). A modifier-only combo (`"fn"`, `"ctrl+opt"`) can only be held → `unavailable`.
  func keyedCombo(_ key: String, for id: ActionID, in context: ActionContext) throws -> KeyCombo {
    let combo = try combo(key, for: id, in: context)
    guard !combo.isModifierOnly else {
      throw ActionError.unavailable(
        id, reason: "\(key): \"\(combo)\" is modifiers only; this action needs a key (holding works)")
    }
    return combo
  }

  /// An optional number. Absent → `defaultValue`; unparseable or outside `range` →
  /// `missingParameter` (there is no usable value).
  func number(
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
  func choice(
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
  func unavailable<T>(_ id: ActionID, _ body: () throws -> T) throws -> T {
    do {
      return try body()
    } catch let error as OutputError {
      throw ActionError.unavailable(id, reason: error.reason)
    } catch let error as ActionError {
      throw error
    } catch let error as DisplayBrightnessError {
      throw ActionError.unavailable(id, reason: Self.reason(error))
    } catch {
      throw ActionError.unavailable(id, reason: String(describing: error))
    }
  }

  static func reason(_ error: DisplayBrightnessError) -> String {
    switch error {
    case .noSuchDisplay: return "the display is no longer connected"
    case .notControllable(_, let reason), .failed(_, let reason): return reason
    }
  }
}
