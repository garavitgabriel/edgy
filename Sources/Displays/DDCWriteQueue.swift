import Foundation

/// Serializes brightness writes to one slow, flaky monitor.
///
/// - Coalesces: only the latest submitted value matters; values superseded before their turn are
///   never sent.
/// - Spaces: consecutive writes are at least `spacing` seconds apart (from the end of one write to
///   the start of the next), so the monitor is never flooded at slide rate.
/// - Retries: a failed write is retried up to `maxAttempts` in total, each retry spaced like any
///   other write. A newer value arriving meanwhile replaces the retry. After the last attempt the
///   failure is reported once through `onFailure`.
/// - Never blocks: `submit` only records the value and schedules work.
final class DDCWriteQueue: @unchecked Sendable {
  struct Policy: Sendable {
    var spacing: TimeInterval = 0.05
    var maxAttempts = 3
  }

  typealias Write = @Sendable (UInt16) throws -> Void
  typealias FailureHandler = @Sendable (_ value: UInt16, _ error: any Error) -> Void

  private let scheduler: any Scheduler
  private let policy: Policy
  private let write: Write
  private let onFailure: FailureHandler

  private let lock = NSLock()
  /// The newest value not yet handed to `write`.
  private var pending: UInt16?
  /// A drain is scheduled or running; at most one at a time.
  private var busy = false
  private var lastWriteEnd: TimeInterval?

  init(
    scheduler: any Scheduler, policy: Policy = Policy(), write: @escaping Write,
    onFailure: @escaping FailureHandler
  ) {
    self.scheduler = scheduler
    self.policy = policy
    self.write = write
    self.onFailure = onFailure
  }

  func submit(_ value: UInt16) {
    lock.withLock {
      pending = value
      guard !busy else { return }
      busy = true
      scheduleDrainLocked(attempt: 1, retrying: nil)
    }
  }

  /// True while a value is waiting or being written.
  var isBusy: Bool { lock.withLock { busy } }

  private func scheduleDrainLocked(attempt: Int, retrying value: UInt16?) {
    var delay: TimeInterval = 0
    if let lastWriteEnd { delay = max(0, lastWriteEnd + policy.spacing - scheduler.now()) }
    scheduler.schedule(after: delay) { [self] in drain(attempt: attempt, retrying: value) }
  }

  private func drain(attempt: Int, retrying retryValue: UInt16?) {
    let next: (value: UInt16, attempt: Int)? = lock.withLock {
      defer { pending = nil }
      if let pending { return (pending, pending == retryValue ? attempt : 1) }
      if let retryValue { return (retryValue, attempt) }
      busy = false
      return nil
    }
    guard let next else { return }

    var failure: (any Error)?
    do { try write(next.value) } catch { failure = error }

    let gaveUp: (any Error)? = lock.withLock {
      lastWriteEnd = scheduler.now()
      var gaveUp: (any Error)?
      if let failure, pending == nil {
        if next.attempt < policy.maxAttempts {
          scheduleDrainLocked(attempt: next.attempt + 1, retrying: next.value)
          return nil
        }
        gaveUp = failure
      }
      if pending != nil {
        scheduleDrainLocked(attempt: 1, retrying: nil)
      } else {
        busy = false
      }
      return gaveUp
    }
    if let gaveUp { onFailure(next.value, gaveUp) }
  }
}
