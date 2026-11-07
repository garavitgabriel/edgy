import Dispatch
import Foundation

/// A monotonic clock plus deferred work. Live: a serial dispatch queue. Tests: a manual clock.
protocol Scheduler: Sendable {
  /// Seconds on a monotonic clock.
  func now() -> TimeInterval
  /// Runs `work` once, at least `delay` seconds from now, never on the caller's stack.
  func schedule(after delay: TimeInterval, _ work: @escaping @Sendable () -> Void)
}

/// Runs work on its own serial queue, so everything scheduled on one instance is serialized.
struct DispatchScheduler: Scheduler {
  let queue: DispatchQueue

  init(label: String) {
    queue = DispatchQueue(label: label, qos: .userInitiated)
  }

  func now() -> TimeInterval {
    TimeInterval(DispatchTime.now().uptimeNanoseconds) / 1_000_000_000
  }

  func schedule(after delay: TimeInterval, _ work: @escaping @Sendable () -> Void) {
    if delay <= 0 {
      queue.async(execute: work)
    } else {
      queue.asyncAfter(deadline: .now() + delay, execute: work)
    }
  }
}
