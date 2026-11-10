import EdgyCore
import Foundation

/// A key sequence still sending: the steps left and the timer for the next one.
struct KeySequenceRun {
  var remaining: [KeyCombo]
  var generation: Int
  var next: ScheduledWork?
}

extension ActionRegistry {
  /// At most this many shortcuts in one `keyboard.shortcut` sequence.
  static let maxSequenceSteps = 4
  /// Pause between the shortcuts of a sequence (after one is released, before the next goes down).
  static let sequenceStepGap: TimeInterval = 0.040

  // MARK: - Keyboard Shortcut

  /// `keyboard.shortcut`. `keys` holds one combo (`cmd+c`) or a sequence of up to four separated
  /// by one space (`ctrl+b n`).
  ///
  /// - **One combo:** exactly as before sequences: one `post`, nothing scheduled.
  /// - **A sequence:** every step is checked before anything is sent. The first step goes now;
  ///   each next one `sequenceStepGap` after the previous, on the action scheduler (never a sleep
  ///   on the caller's thread). Each step is a full press and release.
  /// - **Failure:** the failed step's key and modifiers are released and the rest is dropped. A
  ///   first-step failure is thrown like a single shortcut's; a later one can only be logged.
  /// - **Re-trigger** while a sequence is still sending is ignored (logged), never interleaved.
  func performShortcut(_ id: ActionID, context: ActionContext) throws {
    keyLock.lock()
    defer { keyLock.unlock() }
    guard keySequence == nil else {
      actionsLog.info("keyboard shortcut: a sequence is still sending; ignoring this trigger")
      return
    }
    let steps = try shortcutSteps(id, in: context)
    guard steps.count > 1 else {
      try unavailable(id) { try keyboard.post(steps[0]) }
      return
    }
    sequenceGeneration += 1
    try unavailable(id) { try postSequenceStep(steps[0]) }
    keySequence = KeySequenceRun(remaining: Array(steps.dropFirst()), generation: sequenceGeneration)
    scheduleNextSequenceStep()
  }

  /// The steps of `keys`. Text today's parser reads as one combo (`cmd+c`, also `cmd + c`) is one
  /// step, with today's errors. Otherwise it is split on single spaces into 2…4 combos, each one
  /// ending in a key. Too many, an unparseable step or a modifier-only step → `unavailable`.
  func shortcutSteps(_ id: ActionID, in context: ActionContext) throws -> [KeyCombo] {
    let key = ActionParameterKey.keys
    let raw = try text(key, for: id, in: context)
    let tokens = raw.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
    if KeyCombo(raw) != nil || tokens.count < 2 {
      return [try keyedCombo(key, for: id, in: context)]
    }
    guard tokens.count <= Self.maxSequenceSteps else {
      throw ActionError.unavailable(
        id, reason: "\(key): \"\(raw)\" has \(tokens.count) shortcuts; a sequence has at most \(Self.maxSequenceSteps)")
    }
    return try tokens.map { token in
      guard let combo = KeyCombo(token) else {
        throw ActionError.unavailable(id, reason: "\(key): \"\(token)\" in \"\(raw)\" is not a key combination")
      }
      guard !combo.isModifierOnly else {
        throw ActionError.unavailable(
          id, reason: "\(key): \"\(token)\" in \"\(raw)\" is modifiers only; every step needs a key")
      }
      return combo
    }
  }

  /// A combo for an action that takes exactly one (`keyboard.hold`, `keyboard.slideSteps`): a
  /// space means a sequence, which only Keyboard Shortcut sends → `unavailable`.
  func singleCombo(_ key: String, for id: ActionID, in context: ActionContext, keyed: Bool) throws -> KeyCombo {
    let raw = try text(key, for: id, in: context)
    guard !raw.contains(" ") else {
      throw ActionError.unavailable(
        id, reason: "\(key): \"\(raw)\" has a space; this action takes one key combination, not a sequence")
    }
    return keyed ? try keyedCombo(key, for: id, in: context) : try combo(key, for: id, in: context)
  }

  private func scheduleNextSequenceStep() {
    guard let run = keySequence else { return }
    guard !run.remaining.isEmpty else {
      keySequence = nil
      actionsLog.debug("keyboard shortcut: sequence sent")
      return
    }
    let generation = run.generation
    keySequence?.next = scheduler.schedule(after: Self.sequenceStepGap) { [weak self] in
      self?.sequenceStepDue(generation: generation)
    }
  }

  /// The gap passed: send the next step (on the scheduler's queue).
  func sequenceStepDue(generation: Int) {
    keyLock.lock()
    defer { keyLock.unlock() }
    guard var run = keySequence, run.generation == generation, !run.remaining.isEmpty else { return }
    let combo = run.remaining.removeFirst()
    run.next = nil
    keySequence = run
    do {
      try postSequenceStep(combo)
    } catch {
      actionsLog.error(
        "keyboard shortcut: sequence step \(combo.description, privacy: .public) failed: \(String(describing: error), privacy: .public); dropping the rest"
      )
      keySequence = nil
      return
    }
    scheduleNextSequenceStep()
  }

  /// One step: a full press and release. On failure its key and modifiers are released (best
  /// effort), then the error is rethrown.
  private func postSequenceStep(_ combo: KeyCombo) throws {
    do {
      try keyboard.post(combo)
    } catch {
      releaseSequenceStep(combo)
      throw error
    }
  }

  /// Key up, then the step's modifiers in reverse. Modifiers a hold or the open switcher keeps
  /// down stay down: they belong to that gesture.
  private func releaseSequenceStep(_ combo: KeyCombo) {
    if let key = combo.key {
      do {
        try keyboard.key(key, down: false, modifiers: [])
      } catch {
        actionsLog.error("keyboard shortcut: key up failed: \(String(describing: error), privacy: .public)")
      }
    }
    var kept = heldCombo?.modifiers ?? []
    if switcher?.opened == true { kept.insert(Self.switcherModifier) }
    let modifiers = Self.ordered(combo.modifiers.subtracting(kept))
    guard !modifiers.isEmpty else { return }
    do {
      try keyboard.setModifiers(modifiers.reversed(), down: false)
    } catch {
      actionsLog.error("keyboard shortcut: releasing modifiers failed: \(String(describing: error), privacy: .public)")
    }
  }
}
