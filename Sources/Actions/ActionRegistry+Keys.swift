import EdgyCore
import Foundation

/// The app switcher slide in progress: command is down until it ends.
struct SwitcherSession: Equatable {
  /// Slide travel per app, from the binding.
  var step: Double
  /// Travel toward the next tab.
  var carry: Double
}

extension ActionRegistry {
  /// The modifier that keeps the switcher open, and the key that moves through it.
  static let switcherModifier: KeyCombo.Modifier = .cmd
  static let switcherKey = "tab"
  /// Watchdog: a switcher session that gets no event for this long is cancelled (escape, then
  /// command up), so a lost `.ended` / `.cancelled` never leaves command stuck down.
  static let switcherIdleTimeout: TimeInterval = 10

  // MARK: - App switcher

  /// `apps.switcher`: `.began` holds command and sends one tab (the switcher opens on the next
  /// app); each `step` of travel sends tab (toward top/right) or shift-tab; `.ended` releases
  /// command, which selects; `.cancelled` sends escape, then releases.
  ///
  /// Command is never left down: every error releases it, a `.began` that arrives while a
  /// switcher session is still open (its end was lost) first cancels that session — escape, then
  /// release — rather than selecting an app the user never chose, and a session that hears
  /// nothing for `switcherIdleTimeout` is cancelled by its watchdog.
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
      endSwitcher(cancel: true)
      let step = try number(
        ActionParameterKey.step, for: id, in: context, range: ActionCatalog.switcherStepRange,
        default: ActionCatalog.defaultSwitcherStep)
      // The session (and so the release) exists only once command is really down.
      try unavailable(id) { try keyboard.setModifiers([Self.switcherModifier], down: true) }
      keySessionGeneration += 1
      switcher = SwitcherSession(step: step, carry: 0)
      try releasingSwitcherOnError(id) { try tapSwitcher(forward: true) }
      try switcherTravel(id, delta: delta, context: context)
    case .changed:
      try switcherTravel(id, delta: delta, context: context)
    case .ended:
      defer { endSwitcher(cancel: false) }
      try switcherTravel(id, delta: delta, context: context)
    case .cancelled:
      endSwitcher(cancel: true)
    }
  }

  /// Tabs for `delta` of travel. No session (its start failed) → nothing.
  private func switcherTravel(_ id: ActionID, delta: Double, context: ActionContext) throws {
    guard let session = switcher else { return }
    let result = KeySteps.apply(
      travel: delta * Self.sensitivity(context), step: session.step, carry: session.carry)
    switcher?.carry = result.carry
    guard result.presses != 0 else { return }
    let tick = settings.allowsHaptic(.slideSteps, parameters: context.parameters)
    try releasingSwitcherOnError(id) {
      for _ in 0..<abs(result.presses) {
        try tapSwitcher(forward: result.presses > 0)
        if tick { haptics.tick(strength: settings.hapticTickStrength) }
      }
    }
  }

  private func tapSwitcher(forward: Bool) throws {
    let modifiers: Set<KeyCombo.Modifier> = forward ? [Self.switcherModifier] : [Self.switcherModifier, .shift]
    try keyboard.key(Self.switcherKey, down: true, modifiers: modifiers)
    try keyboard.key(Self.switcherKey, down: false, modifiers: modifiers)
  }

  /// Runs `body`; on any error cancels the switcher (escape, release) before rethrowing.
  private func releasingSwitcherOnError(_ id: ActionID, _ body: () throws -> Void) throws {
    do {
      try unavailable(id, body)
    } catch {
      endSwitcher(cancel: true)
      throw error
    }
  }

  /// Ends the switcher session, if any: escape first when cancelling, then release command.
  /// Best effort — a failure here can't be reported to anyone who could act on it, so it is logged.
  func endSwitcher(cancel: Bool) {
    keyLock.lock()
    defer { keyLock.unlock() }
    switcherWatchdog?.cancel()
    switcherWatchdog = nil
    guard switcher != nil else { return }
    switcher = nil
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
