import Actions
import EdgyCore
import EdgyRuntime
import Foundation
import Observation

/// The key-combo field's flow (BRIEF § Binding parameters → Key-combo recorder) over
/// `model.keyRecorder`:
/// - idle → recording ("Press keys…", accent ring) → a committed combo, or back to idle on Esc,
///   timeout or Cancel.
/// - Modifiers held show live (in `ink2`) while recording.
/// - Modifiers alone: on a hold action they commit only when held ≥ `modifierHold` (0.6 s); a
///   shorter press keeps listening. On a trigger action they show the inline error instead.
/// - Key sequences (Keyboard Shortcut's `keys` only, BRIEF § Key sequences): "+ Then…" records
///   the next step the same way (`start(after:)`); its commit stores the earlier steps plus the new
///   one, joined by one space. Esc, a timeout or a refused step leave the earlier steps alone. ⌫
///   while idle removes the last step (`removingLastStep`).
/// - Recording Escape itself (BRIEF § Key-combo recorder): a bare Esc cancels, so "Use Escape"
///   (`useEscape()`) cancels the live recording and commits `escape` as the step.
@MainActor
@Observable
final class KeyRecorderController {
  enum Phase: Equatable {
    case idle
    case recording(held: Set<KeyCombo.Modifier>)
  }

  static let modifierHold: TimeInterval = 0.6
  static let timeout: TimeInterval = 10

  private(set) var phase: Phase = .idle
  /// The inline error under the field (`nil` = none).
  var error: String?

  @ObservationIgnored let isHold: Bool
  @ObservationIgnored private let recorder: KeyComboRecording?
  @ObservationIgnored private let now: () -> Date
  @ObservationIgnored private let commit: (KeyCombo, String) -> Void
  @ObservationIgnored private var heldSince: Date?
  @ObservationIgnored private var task: Task<Void, Never>?
  /// The earlier steps while "+ Then…" records the next one (`nil` = recording replaces the value).
  @ObservationIgnored private(set) var base: [String]?

  /// `commit` gets the recorded combo alone (one-combo fields; a sequence step still commits).
  convenience init(
    recorder: KeyComboRecording?, isHold: Bool, now: @escaping () -> Date = Date.init,
    commit: @escaping (KeyCombo) -> Void
  ) {
    self.init(recorder: recorder, isHold: isHold, now: now) { combo, _ in commit(combo) }
  }

  /// `commitValue` gets the combo and the whole new stored value (the earlier steps plus this one).
  init(
    recorder: KeyComboRecording?, isHold: Bool, now: @escaping () -> Date = Date.init,
    commitValue: @escaping (KeyCombo, String) -> Void
  ) {
    self.recorder = recorder
    self.isHold = isHold
    self.now = now
    self.commit = commitValue
  }

  var isRecording: Bool { phase != .idle }

  /// Records a combo that replaces the whole value (clicking the field, as before sequences).
  func start() {
    base = nil
    begin()
  }

  /// "+ Then…": records the next step after `stored`'s steps. Does nothing at the step limit.
  func start(after stored: String?) {
    let steps = KeyComboText.steps(stored ?? "")
    guard steps.count < ConfigValidator.keySequenceLimit else { return }
    base = steps
    begin()
  }

  private func begin() {
    error = nil
    heldSince = nil
    guard let recorder else {
      error = "Keys can’t be recorded right now."
      base = nil
      return
    }
    phase = .recording(held: [])
    let stream = recorder.start(timeout: Self.timeout)
    task?.cancel()
    task = Task { [weak self] in
      for await state in stream {
        guard let self, !Task.isCancelled else { return }
        self.handle(state)
      }
    }
  }

  func cancel() {
    task?.cancel()
    task = nil
    recorder?.cancel()
    phase = .idle
    base = nil
  }

  /// Applies one recorder state (the stream calls this; tests call it directly).
  func handle(_ state: KeyRecorderState) {
    switch state {
    case .listening(let held):
      if held.isEmpty { heldSince = nil } else if heldSince == nil { heldSince = now() }
      phase = .recording(held: held)
    case .recorded(let combo):
      guard combo.isModifierOnly else { return finish(combo) }
      guard isHold else {
        phase = .idle
        base = nil
        error = IssueCopy.modifiersAlone
        return
      }
      let held = heldSince.map { now().timeIntervalSince($0) } ?? 0
      if held >= Self.modifierHold { return finish(combo) }
      // Too short to be a deliberate hold: keep listening.
      begin()
    case .cancelled, .timedOut:
      // Esc cancels only the step being recorded: the earlier steps stay as stored.
      phase = .idle
      base = nil
    case .unavailable(let reason):
      phase = .idle
      base = nil
      error = reason
    }
  }

  /// "Use Escape": ends the live recording and commits bare `escape` as this step (after any
  /// earlier steps). Does nothing when idle.
  func useEscape() {
    guard isRecording else { return }
    let steps = base
    task?.cancel()
    task = nil
    recorder?.cancel()
    base = steps
    finish(KeyCombo(modifiers: [], key: "escape"))
  }

  /// The moment the last combo committed: the field keeps swallowing keys for `swallowAfterCommit`
  /// so the key that just committed can't also press the field (Space, Return) or clear it (⌫).
  @ObservationIgnored private var committedAt: Date?
  static let swallowAfterCommit: TimeInterval = 0.5

  /// Whether the field eats a key press instead of handling it: always while recording (the keys
  /// belong to the recorder), and briefly after a commit.
  var swallowsKeys: Bool {
    if isRecording { return true }
    guard let committedAt else { return false }
    return now().timeIntervalSince(committedAt) < Self.swallowAfterCommit
  }

  private func finish(_ combo: KeyCombo) {
    committedAt = now()
    let value = ((base ?? []) + [combo.description]).joined(separator: " ")
    phase = .idle
    error = nil
    base = nil
    commit(combo, value)
  }

  // MARK: Sequence rules (pure; the field calls these)

  /// Whether a key parameter takes a sequence: Keyboard Shortcut's `keys` only (the validator's
  /// rule). Hold Keys and Slide to Repeat Keys take one combo.
  static func allowsSequence(action: ActionID, parameter: String) -> Bool {
    ConfigValidator.keySequenceActions.contains(action) && parameter == "keys"
  }

  /// Whether "+ Then…" shows: a sequence field, idle, with 1–3 steps.
  static func showsThen(stored: String?, allowsSequence: Bool, isRecording: Bool) -> Bool {
    guard allowsSequence, !isRecording else { return false }
    let count = KeyComboText.steps(stored ?? "").count
    return count >= 1 && count < ConfigValidator.keySequenceLimit
  }

  /// ⌫ while idle: the value without its last step; `nil` (cleared) when one step or none is left.
  static func removingLastStep(_ stored: String?) -> String? {
    let steps = KeyComboText.steps(stored ?? "")
    guard steps.count > 1 else { return nil }
    return steps.dropLast().joined(separator: " ")
  }
}
