import EdgyCore
import Foundation

/// Turns recognized gestures into action calls using the profile for the frontmost app.
///
/// Discrete gestures fire exactly once: on `.began` if the recognizer emits one, otherwise on
/// `.ended`. `.changed` never fires a discrete action, and `.cancelled` fires nothing.
/// Slides forward every phase as `.delta` so continuous actions can finish cleanly.
///
/// Hold actions (`ActionDescriptor.Shape.hold`, bound to a long-press) get `.press(down: true)` at
/// `.began` and `.press(down: false)` at `.ended` / `.cancelled`. The release goes to the action and
/// parameters that got the press, whatever the profile says by then, so a frontmost-app change, a
/// disabled profile or a removed binding can't strand a held key. `reset()`, `releaseHolds(reason:)`
/// and `replaceActions(_:)` release every pending hold before forgetting it: every `down: true` is
/// followed by exactly one `down: false`.
///
/// **Test Mode** (`testMode`): everything is routed as usual but no action is performed. Each
/// gesture that would run an action gives one `gestureCaught` haptic (a slide at its start, a
/// discrete gesture when it would fire, a hold at its `.began`) and reports `wouldRun`. A would-be
/// hold presses nothing, so nothing is released later either.
public final class Router {
  public private(set) var actions: ActionPerforming
  /// Route without performing (see the type's docs). The engine flips it with its own reset.
  public internal(set) var testMode = false
  /// The live feed's decision sink; `nil` when nobody observes, so nothing is built.
  var onDecision: ((LiveDecision) -> Void)?
  private let logger: EdgyLogging
  private var shapes: [ActionID: ActionDescriptor.Shape]

  private struct DiscreteKey: Hashable {
    var zone: Zone
    var kind: GestureKind
    var deviceID: UInt64
  }
  private struct PendingHold {
    var action: ActionID
    var context: ActionContext
    /// Press order, so releases happen oldest first.
    var order: Int
  }
  private var firedOnBegan: Set<DiscreteKey> = []
  private var pendingHolds: [DiscreteKey: PendingHold] = [:]
  private var holdCounter = 0

  public init(actions: ActionPerforming, logger: EdgyLogging) {
    self.actions = actions
    self.logger = logger
    self.shapes = Self.shapes(of: actions)
  }

  /// Holds pressed and not yet released.
  public var hasPendingHolds: Bool { !pendingHolds.isEmpty }

  /// Swap the registry. Pending holds are first released on the registry that pressed them.
  public func replaceActions(_ actions: ActionPerforming) {
    releaseHolds(reason: "action registry replaced")
    self.actions = actions
    self.shapes = Self.shapes(of: actions)
  }

  /// Forget in-flight discrete gestures (after pause, reload or stop), releasing pending holds.
  public func reset() {
    releaseHolds(reason: "reset")
    firedOnBegan.removeAll()
  }

  /// Send `.press(down: false)` for every pending hold, oldest first, and forget them. The
  /// recognizer's later `.ended` for those touches then finds nothing to release.
  public func releaseHolds(reason: String) {
    guard !pendingHolds.isEmpty else { return }
    let holds = pendingHolds.sorted { $0.value.order < $1.value.order }
    pendingHolds.removeAll()
    for (key, hold) in holds {
      firedOnBegan.remove(key)
      logger.log(.info, "Releasing hold \(hold.action.rawValue) (\(reason))")
      release(hold)
    }
  }

  public func route(_ event: GestureEvent, config: EdgyConfig, frontmostBundleID: String?) {
    let key = DiscreteKey(zone: event.zone, kind: event.kind, deviceID: event.deviceID)
    // A hold closes on the action that was pressed, before any profile lookup can hide it.
    if event.phase == .ended || event.phase == .cancelled, let hold = pendingHolds.removeValue(forKey: key) {
      firedOnBegan.remove(key)
      logger.log(.info, "Gesture \(event.kind) \(event.phase) at \(event.zone) → release \(hold.action.rawValue)")
      release(hold)
      return
    }
    let profile = config.profile(for: frontmostBundleID)
    guard !profile.disabled else { return }
    let binding = profile.bindings.first(where: { $0.zone == event.zone && $0.gesture == event.kind })
    if event.kind != .slide || event.phase != .changed {
      logger.log(
        .info, "Gesture \(event.kind) \(event.phase) at \(event.zone) → \(binding?.action.rawValue ?? "unbound")")
    }
    guard let binding else { return }
    let context = ActionContext(frontmostBundleID: frontmostBundleID, parameters: binding.parameters)
    if shapes[binding.action] == .hold {
      press(binding, event: event, key: key, context: context)
      return
    }
    guard let input = input(for: event, key: key) else { return }
    // Reported once per gesture: a discrete gesture when it fires, a slide at its start.
    let firstOfGesture = input == .trigger || event.phase == .began
    if testMode {
      guard firstOfGesture else { return }
      actions.feedback(.gestureCaught, context: context)
      onDecision?(.wouldRun(binding.action, zone: event.zone, kind: event.kind))
      return
    }
    if event.kind == .slide && event.phase == .began {
      actions.feedback(.gestureCaught, context: context)
    }
    do {
      try actions.perform(binding.action, input: input, context: context)
      if case .trigger = input { actions.feedback(.actionFired, context: context) }
      if firstOfGesture { onDecision?(.actionRan(binding.action, zone: event.zone, kind: event.kind)) }
    } catch {
      logger.log(.error, "Action \(binding.action.rawValue) failed: \(error)")
      if firstOfGesture { report(error, binding.action, event) }
    }
  }

  private func report(_ error: Error, _ action: ActionID, _ event: GestureEvent) {
    guard let onDecision else { return }
    if case ActionError.unavailable(_, let reason) = error {
      onDecision(.actionUnavailable(action, zone: event.zone, kind: event.kind, reason: reason))
    } else {
      onDecision(.actionFailed(action, zone: event.zone, kind: event.kind, message: String(describing: error)))
    }
  }

  /// A hold action only ever starts at a long-press `.began`; its release is handled in `route`.
  private func press(_ binding: Binding, event: GestureEvent, key: DiscreteKey, context: ActionContext) {
    guard event.kind == .longPress, event.phase == .began else {
      if event.kind != .longPress {
        logger.log(
          .error, "Hold action \(binding.action.rawValue) is bound to \(event.kind); only a long-press drives it")
      }
      return
    }
    if testMode {
      // Nothing is pressed, so nothing is recorded to release.
      actions.feedback(.gestureCaught, context: context)
      onDecision?(.wouldRun(binding.action, zone: event.zone, kind: event.kind))
      return
    }
    // A second `.began` for a key still held (a recognizer that skipped the end) closes the first.
    if let stale = pendingHolds.removeValue(forKey: key) { release(stale) }
    holdCounter += 1
    // Recorded before performing: even if the press fails part-way, the release still follows.
    pendingHolds[key] = PendingHold(action: binding.action, context: context, order: holdCounter)
    do {
      try actions.perform(binding.action, input: .press(down: true), context: context)
      actions.feedback(.actionFired, context: context)
      onDecision?(.actionRan(binding.action, zone: event.zone, kind: event.kind))
    } catch {
      logger.log(.error, "Action \(binding.action.rawValue) failed: \(error)")
      report(error, binding.action, event)
    }
  }

  private func release(_ hold: PendingHold) {
    do {
      try actions.perform(hold.action, input: .press(down: false), context: hold.context)
    } catch {
      logger.log(.error, "Action \(hold.action.rawValue) failed to release: \(error)")
    }
  }

  private func input(for event: GestureEvent, key: DiscreteKey) -> ActionInput? {
    if event.kind == .slide { return .delta(event.delta, phase: event.phase) }
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

  private static func shapes(of actions: ActionPerforming) -> [ActionID: ActionDescriptor.Shape] {
    Dictionary(actions.available.map { ($0.id, $0.shape) }, uniquingKeysWith: { first, _ in first })
  }
}
