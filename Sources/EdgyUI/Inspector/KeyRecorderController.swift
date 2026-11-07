import Actions
import EdgyCore
import Foundation
import Observation

/// The key-combo field's flow (BRIEF § Binding parameters → Key-combo recorder) over
/// `model.keyRecorder`:
/// - idle → recording ("Press keys…", accent ring) → a committed combo, or back to idle on Esc,
///   timeout or Cancel.
/// - Modifiers held show live (in `ink2`) while recording.
/// - Modifiers alone: on a hold action they commit only when held ≥ `modifierHold` (0.6 s); a
///   shorter press keeps listening. On a trigger action they show the inline error instead.
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
  @ObservationIgnored private let commit: (KeyCombo) -> Void
  @ObservationIgnored private var heldSince: Date?
  @ObservationIgnored private var task: Task<Void, Never>?

  init(
    recorder: KeyComboRecording?, isHold: Bool, now: @escaping () -> Date = Date.init,
    commit: @escaping (KeyCombo) -> Void
  ) {
    self.recorder = recorder
    self.isHold = isHold
    self.now = now
    self.commit = commit
  }

  var isRecording: Bool { phase != .idle }

  func start() {
    error = nil
    heldSince = nil
    guard let recorder else {
      error = "Keys can’t be recorded right now."
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
        error = IssueCopy.modifiersAlone
        return
      }
      let held = heldSince.map { now().timeIntervalSince($0) } ?? 0
      if held >= Self.modifierHold { return finish(combo) }
      // Too short to be a deliberate hold: keep listening.
      start()
    case .cancelled, .timedOut:
      phase = .idle
    case .unavailable(let reason):
      phase = .idle
      error = reason
    }
  }

  private func finish(_ combo: KeyCombo) {
    phase = .idle
    error = nil
    commit(combo)
  }
}
