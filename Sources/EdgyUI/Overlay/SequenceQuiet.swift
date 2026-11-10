import Actions
import EdgyCore
import EdgyRuntime
import Foundation

/// Re-triggering Keyboard Shortcut while a key sequence is still sending (batch 33 fix 4).
///
/// The action ignores that trigger: it never interleaves two sequences, and it logs the skip
/// (`ActionRegistry.performShortcut`). It still returns normally, so the feed reports `actionRan`.
/// A plate for it would claim keys were pressed when none were, so it **stays silent**: no plate.
/// This is a decision, pinned by `Batch33OverlayTests`.
///
/// The window opens when a multi-step "Pressed …" plate is admitted and lasts as long as the
/// action sends the rest: one `stepGap` per step after the first. Like the action's own lock, it
/// covers every Keyboard Shortcut binding, not only the one that started it. Dry run sends nothing,
/// so it never opens a window.
struct SequenceQuiet {
  /// Mirrors `ActionRegistry.sequenceStepGap` (internal to Actions): the pause between steps.
  static let stepGap: TimeInterval = 0.040

  private(set) var sendingUntil: TimeInterval?

  /// Whether `decision` may show a plate at `now`; opens the window for a sequence that starts.
  mutating func admits(_ decision: LiveDecision, context: PlateContext, now: TimeInterval) -> Bool {
    guard case .actionRan(let id, let zone, let kind, _) = decision, id == BuiltInAction.keyboardShortcut else {
      return true
    }
    if let until = sendingUntil, now < until { return false }
    sendingUntil = nil
    let stored = context.parameters(zone: zone, kind: kind)[ActionParameterKey.keys] ?? ""
    let steps = ConfigValidator.keySteps(stored).count
    if steps > 1 { sendingUntil = now + Double(steps - 1) * Self.stepGap }
    return true
  }
}
