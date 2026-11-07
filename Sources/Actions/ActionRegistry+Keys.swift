import EdgyCore
import Foundation

/// The app switcher session in progress: command is down until it ends. It spans strokes while
/// `keepOpenMS` lets it linger.
struct SwitcherSession: Equatable {
  /// Travel per app, carry, speed and end stepping (kept across strokes).
  var stepper: SlideStepper
  /// Seconds to linger after a stroke ends; 0 = finish at once.
  var keepOpen: TimeInterval
  /// Apps the switcher lists, when known (for the wrap click).
  var appCount: Int?
  /// Apps moved since the switcher opened; the app it opened on is 0.
  var position = 0
  /// A stroke ended and the session waits for the next one.
  var lingering = false

  /// Whether one step from `position` wraps the highlight around the list. The highlight is on
  /// list index `1 + position` (the switcher opens on index 1, the app after the frontmost).
  func wraps(forward: Bool) -> Bool {
    guard let appCount, appCount >= 2 else { return false }
    let index = ((1 + position) % appCount + appCount) % appCount
    return forward ? index == appCount - 1 : index == 0
  }
}

extension ActionRegistry {
  /// The modifier that keeps the switcher open, and the key that moves through it.
  static let switcherModifier: KeyCombo.Modifier = .cmd
  static let switcherKey = "tab"
  /// Watchdog: a switcher session that gets no event for this long is cancelled (escape, then
  /// command up), so a lost `.ended` / `.cancelled` never leaves command stuck down.
  static let switcherIdleTimeout: TimeInterval = 10

  // MARK: - App switcher

  /// `apps.switcher`, one session across strokes:
  ///
  /// - **Open.** The first `.began` holds command and sends one tab (the switcher opens on the next
  ///   app). That app is the session's starting point (`position` 0).
  /// - **Move.** One tab (toward top/right) or shift-tab per `stepMM` of travel, with the shared
  ///   slide feel (`SlideFeel`: speed-up, end stepping). A tick per app; a stronger click when the
  ///   highlight wraps past the last app (when the app count is known) or when end stepping starts.
  /// - **Keep open between strokes.** `.ended` and `.cancelled` (an interruption: palm, second
  ///   finger) don't release command: the session lingers for `keepOpenMS`. A `.began` within that
  ///   time continues the same session — no new command-down, no new opening tab, the travel carry
  ///   kept — so short repeated strokes walk through many apps. While it lingers, a listen-only
  ///   monitor (`SwitcherInputMonitor`) watches for a click or clear pointer movement (select now)
  ///   and Escape (the system closes its switcher; command is released). The monitor runs only
  ///   while a session lingers.
  /// - **Select.** Command up, when the window passes or on a click / pointer movement.
  ///   `keepOpenMS` 0: `.ended` selects at once and `.cancelled` cancels (escape, then command up),
  ///   exactly the pre-batch-20 behaviour.
  /// - **Cancel.** Sliding back past the starting point by one step: escape, then command up.
  ///
  /// Command is never left down: every error releases it, a `.began` that arrives while a stroke is
  /// still live (its end was lost) cancels that session first, and a session that hears nothing for
  /// `switcherIdleTimeout` is cancelled by its watchdog.
  func performSwitcher(
    _ id: ActionID, delta: Double, phase: GestureEvent.Phase, context: ActionContext
  ) throws {
    keyLock.lock()
    defer {
      rearmSwitcherWatchdog()
      keyLock.unlock()
    }
    switch phase {
    case .began:
      if switcher?.lingering == true {
        try continueSwitcher(id, context: context)
      } else {
        try openSwitcher(id, context: context)
      }
      try switcherTravel(id, delta: delta, context: context)
    case .changed:
      try switcherTravel(id, delta: delta, context: context)
    case .ended, .cancelled:
      if phase == .ended { try switcherTravel(id, delta: delta, context: context) }
      strokeEnded(cancelled: phase == .cancelled)
    }
  }

  /// A fresh session: command down, then the opening tab.
  private func openSwitcher(_ id: ActionID, context: ActionContext) throws {
    endSwitcher(cancel: true)
    let feel = try switcherFeel(id, delta: 0, context: context)
    // The session (and so the release) exists only once command is really down.
    try unavailable(id) { try keyboard.setModifiers([Self.switcherModifier], down: true) }
    keySessionGeneration += 1
    switcher = SwitcherSession(
      stepper: SlideStepper(step: feel.unit.step, speedUp: feel.speedUp), keepOpen: feel.keepOpen,
      appCount: switcherInput.switcherAppCount())
    try releasingSwitcherOnError(id) { try tapSwitcher(forward: true) }
  }

  /// The next stroke within the keep-open window: same session, nothing pressed.
  private func continueSwitcher(_ id: ActionID, context: ActionContext) throws {
    switcherLinger?.cancel()
    switcherLinger = nil
    switcherInput.stop()
    switcher?.lingering = false
    let feel = try releasingSwitcherOnError(id) { try switcherFeel(id, delta: 0, context: context) }
    switcher?.keepOpen = feel.keepOpen
    switcher?.stepper.speedUp = feel.speedUp
  }

  /// The binding's step, speed-up and keep-open time.
  private func switcherFeel(_ id: ActionID, delta: Double, context: ActionContext) throws -> (
    unit: StepUnit, speedUp: Bool, keepOpen: TimeInterval
  ) {
    let unit = try stepUnit(
      id, in: context, legacyRange: ActionCatalog.switcherStepRange, legacyDefault: ActionCatalog.defaultSwitcherStep,
      zoneLengthMM: Self.zoneLength(delta: delta, motion: context.motion))
    let keepOpen = try number(
      ActionParameterKey.keepOpenMS, for: id, in: context, range: ActionCatalog.keepOpenRange,
      default: ActionCatalog.defaultKeepOpenMS)
    return (unit, try speedUp(id, in: context), keepOpen / 1000)
  }

  /// A stroke ended (lift or interruption): linger for the next stroke, or finish now.
  private func strokeEnded(cancelled: Bool) {
    guard let session = switcher else { return }
    guard session.keepOpen > 0 else {
      endSwitcher(cancel: cancelled)
      return
    }
    switcher?.lingering = true
    let generation = keySessionGeneration
    switcherLinger?.cancel()
    switcherLinger = scheduler.schedule(after: session.keepOpen) { [weak self] in
      self?.switcherLingerEnded(generation: generation, because: "the keep-open time passed")
    }
    switcherInput.start { [weak self] interrupt in
      self?.switcherInterrupted(interrupt, generation: generation)
    }
  }

  /// A click, pointer movement or Escape while lingering. Each ends the session by releasing
  /// command: a click or pointer movement selects; after Escape the system has already closed its
  /// switcher, so the release selects nothing.
  func switcherInterrupted(_ interrupt: SwitcherInterrupt, generation: Int) {
    let reason: String
    switch interrupt {
    case .click: reason = "a click"
    case .pointerMoved: reason = "pointer movement"
    case .escape: reason = "Escape"
    }
    switcherLingerEnded(generation: generation, because: reason)
  }

  private func switcherLingerEnded(generation: Int, because reason: String) {
    keyLock.lock()
    defer { keyLock.unlock() }
    guard switcher?.lingering == true, generation == keySessionGeneration else { return }
    actionsLog.info("app switcher: selecting (\(reason, privacy: .public))")
    endSwitcher(cancel: false)
  }

  /// Tabs for `delta` of travel. No session (its start failed, or it was cancelled) → nothing.
  private func switcherTravel(_ id: ActionID, delta: Double, context: ActionContext) throws {
    guard var session = switcher else { return }
    let feel = try releasingSwitcherOnError(id) { try switcherFeel(id, delta: delta, context: context) }
    session.stepper.step = feel.unit.step
    let result = session.stepper.advance(
      travel: feel.unit.travel(delta) * Self.sensitivity(context), motion: feel.unit.motion)
    switcher = session
    guard result.steps != 0 else { return }
    let forward = result.steps > 0
    let tick = settings.allowsHaptic(.slideSteps, parameters: context.parameters)
    let click = settings.allowsHaptic(.slideLimits, parameters: context.parameters)
    var strong = result.endStarted
    for _ in 0..<abs(result.steps) {
      guard let current = switcher else { return }
      if !forward && current.position <= 0 {
        actionsLog.info("app switcher: slid back past the start; cancelling")
        endSwitcher(cancel: true)
        return
      }
      try releasingSwitcherOnError(id) { try tapSwitcher(forward: forward) }
      let wrapped = current.wraps(forward: forward)
      switcher?.position += forward ? 1 : -1
      if (strong || wrapped) && click {
        haptics.strongTick(strength: settings.hapticClickStrength)
      } else if tick {
        haptics.tick(strength: settings.hapticTickStrength)
      }
      strong = false
    }
  }

  private func tapSwitcher(forward: Bool) throws {
    let modifiers: Set<KeyCombo.Modifier> = forward ? [Self.switcherModifier] : [Self.switcherModifier, .shift]
    try keyboard.key(Self.switcherKey, down: true, modifiers: modifiers)
    try keyboard.key(Self.switcherKey, down: false, modifiers: modifiers)
  }

  /// Runs `body`; on any error cancels the switcher (escape, release) before rethrowing.
  private func releasingSwitcherOnError<T>(_ id: ActionID, _ body: () throws -> T) throws -> T {
    do {
      return try unavailable(id, body)
    } catch {
      endSwitcher(cancel: true)
      throw error
    }
  }

  /// Ends the switcher session, if any: escape first when cancelling, then release command. Stops
  /// the keep-open timer and the input monitor. Best effort — a failure here can't be reported to
  /// anyone who could act on it, so it is logged.
  func endSwitcher(cancel: Bool) {
    keyLock.lock()
    defer { keyLock.unlock() }
    switcherWatchdog?.cancel()
    switcherWatchdog = nil
    switcherLinger?.cancel()
    switcherLinger = nil
    guard let session = switcher else { return }
    switcher = nil
    if session.lingering { switcherInput.stop() }
    let held: Set<KeyCombo.Modifier> = [Self.switcherModifier]
    do {
      if cancel {
        try keyboard.key("escape", down: true, modifiers: held)
        try keyboard.key("escape", down: false, modifiers: held)
      }
    } catch {
      actionsLog.error("app switcher: escape failed: \(String(describing: error), privacy: .public)")
    }
    do {
      try keyboard.setModifiers([Self.switcherModifier], down: false)
    } catch {
      actionsLog.error("app switcher: releasing command failed: \(String(describing: error), privacy: .public)")
    }
  }

  /// Restarts the idle watchdog after any switcher event; no open session → no watchdog.
  private func rearmSwitcherWatchdog() {
    switcherWatchdog?.cancel()
    switcherWatchdog = nil
    guard switcher != nil else { return }
    let generation = keySessionGeneration
    switcherWatchdog = scheduler.schedule(after: Self.switcherIdleTimeout) { [weak self] in
      self?.switcherWatchdogFired(generation: generation)
    }
  }

  func switcherWatchdogFired(generation: Int) {
    keyLock.lock()
    defer { keyLock.unlock() }
    guard switcher != nil, generation == keySessionGeneration else { return }
    actionsLog.notice(
      "app switcher: no event for \(Self.switcherIdleTimeout, privacy: .public) s; cancelling and releasing command")
    endSwitcher(cancel: true)
  }

  // MARK: - Hold a key

  /// `keyboard.hold`: `down: true` presses the combo's modifiers, then its key (if it has one),
  /// and keeps them down; `down: false` releases the key, then the modifiers in reverse. A
  /// modifier-only combo (`fn`, `ctrl+opt`) presses and releases just the modifiers, as
  /// flags-changed events like the physical keys send. A second `down: true` without an up
  /// releases the first combo before pressing. Releasing never needs the binding's parameters
  /// (they may have changed or broken meanwhile), so a held key always comes back up.
  ///
  /// Watchdog: if no up arrives within `maxSeconds` (default 120), the hold is released and
  /// logged once.
  func performHold(_ id: ActionID, down: Bool, context: ActionContext) throws {
    keyLock.lock()
    defer { keyLock.unlock() }
    releaseHeld()
    guard down else { return }
    let combo = try combo(ActionParameterKey.keys, for: id, in: context)
    let maxSeconds = try number(
      ActionParameterKey.maxSeconds, for: id, in: context, range: ActionCatalog.holdMaxSecondsRange,
      default: ActionCatalog.defaultHoldMaxSeconds)
    keySessionGeneration += 1
    heldCombo = combo
    do {
      try unavailable(id) {
        try keyboard.setModifiers(Self.ordered(combo.modifiers), down: true)
        if let key = combo.key { try keyboard.key(key, down: true, modifiers: combo.modifiers) }
      }
    } catch {
      releaseHeld()
      throw error
    }
    let generation = keySessionGeneration
    holdWatchdog = scheduler.schedule(after: maxSeconds) { [weak self] in
      self?.holdWatchdogFired(generation: generation, after: maxSeconds)
    }
  }

  func holdWatchdogFired(generation: Int, after seconds: Double) {
    keyLock.lock()
    defer { keyLock.unlock() }
    guard let combo = heldCombo, generation == keySessionGeneration else { return }
    actionsLog.notice(
      "hold: no release after \(seconds, privacy: .public) s; releasing \(combo.description, privacy: .public)")
    releaseHeld()
  }

  /// Releases the held combo, if any: key up, then modifiers in reverse order. Best effort, logged.
  func releaseHeld() {
    keyLock.lock()
    defer { keyLock.unlock() }
    holdWatchdog?.cancel()
    holdWatchdog = nil
    guard let combo = heldCombo else { return }
    heldCombo = nil
    do {
      if let key = combo.key { try keyboard.key(key, down: false, modifiers: combo.modifiers) }
    } catch {
      actionsLog.error("hold: key up failed: \(String(describing: error), privacy: .public)")
    }
    do {
      try keyboard.setModifiers(Self.ordered(combo.modifiers).reversed(), down: false)
    } catch {
      actionsLog.error("hold: releasing modifiers failed: \(String(describing: error), privacy: .public)")
    }
  }

  /// Modifiers in their canonical order (`KeyCombo.Modifier.allCases`).
  static func ordered(_ modifiers: Set<KeyCombo.Modifier>) -> [KeyCombo.Modifier] {
    KeyCombo.Modifier.allCases.filter(modifiers.contains)
  }
}
