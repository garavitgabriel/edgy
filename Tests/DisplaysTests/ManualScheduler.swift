import Foundation

@testable import Displays

/// A scheduler on a hand-driven clock. Nothing runs until `advance(by:)` or `runDue()`.
final class ManualScheduler: Scheduler, @unchecked Sendable {
  private struct Job {
    var due: TimeInterval
    var order: Int
    var work: @Sendable () -> Void
  }

  private let lock = NSLock()
  private var clock: TimeInterval = 0
  private var jobs: [Job] = []
  private var nextOrder = 0

  func now() -> TimeInterval { lock.withLock { clock } }

  func schedule(after delay: TimeInterval, _ work: @escaping @Sendable () -> Void) {
    lock.withLock {
      jobs.append(Job(due: clock + max(0, delay), order: nextOrder, work: work))
      nextOrder += 1
    }
  }

  var pendingJobs: Int { lock.withLock { jobs.count } }

  /// Moves the clock forward, running every job that falls due on the way, in time order.
  func advance(by seconds: TimeInterval) {
    let target = lock.withLock { clock + seconds }
    while let job = popNext(dueBy: target) {
      job.work()
    }
    lock.withLock { clock = max(clock, target) }
  }

  /// Runs everything already due without moving the clock.
  func runDue() { advance(by: 0) }

  private func popNext(dueBy target: TimeInterval) -> Job? {
    lock.withLock {
      guard
        let index = jobs.indices.filter({ jobs[$0].due <= target + 1e-9 })
          .min(by: { (jobs[$0].due, jobs[$0].order) < (jobs[$1].due, jobs[$1].order) })
      else { return nil }
      let job = jobs.remove(at: index)
      clock = max(clock, job.due)
      return job
    }
  }
}
