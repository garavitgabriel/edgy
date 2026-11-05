import EdgyCore
import Foundation

/// Turns recognized gestures into action calls using the profile for the frontmost app.
///
/// Discrete gestures fire exactly once: on `.began` if the recognizer emits one, otherwise on
/// `.ended`. `.changed` never fires a discrete action, and `.cancelled` fires nothing.
/// Slides forward every phase as `.delta` so continuous actions can finish cleanly.
public final class Router {
  public private(set) var actions: ActionPerforming
  private let logger: EdgyLogging

  private struct DiscreteKey: Hashable {
    var zone: Zone
    var kind: GestureKind
    var deviceID: UInt64
  }
  private var firedOnBegan: Set<DiscreteKey> = []

  public init(actions: ActionPerforming, logger: EdgyLogging) {
    self.actions = actions
    self.logger = logger
  }

  public func replaceActions(_ actions: ActionPerforming) {
    self.actions = actions
  }

  /// Forget in-flight discrete gestures (after pause, reload or stop).
  public func reset() {
    firedOnBegan.removeAll()
  }

  public func route(_ event: GestureEvent, config: EdgyConfig, frontmostBundleID: String?) {
    let profile = config.profile(for: frontmostBundleID)
    guard !profile.disabled else { return }
    let binding = profile.bindings.first(where: { $0.zone == event.zone && $0.gesture == event.kind })
    if event.kind != .slide || event.phase != .changed {
      logger.log(
        .info, "Gesture \(event.kind) \(event.phase) at \(event.zone) → \(binding?.action.rawValue ?? "unbound")")
    }
    guard let binding else { return }
    guard let input = input(for: event) else { return }
    let context = ActionContext(frontmostBundleID: frontmostBundleID, parameters: binding.parameters)
    do {
      try actions.perform(binding.action, input: input, context: context)
    } catch {
      logger.log(.error, "Action \(binding.action.rawValue) failed: \(error)")
    }
  }

  private func input(for event: GestureEvent) -> ActionInput? {
    if event.kind == .slide { return .delta(event.delta, phase: event.phase) }
    let key = DiscreteKey(zone: event.zone, kind: event.kind, deviceID: event.deviceID)
    switch event.phase {
    case .began:
      firedOnBegan.insert(key)
      return .trigger
    case .changed:
      return nil
    case .ended:
      return firedOnBegan.remove(key) == nil ? .trigger : nil
    case .cancelled:
      firedOnBegan.remove(key)
      return nil
    }
  }
}
