import Foundation
import Testing

@testable import Displays

/// Records every write with the manual clock's time; can be told to fail the next N writes.
final class RecordingWriter: @unchecked Sendable {
  private let lock = NSLock()
  private let scheduler: ManualScheduler
  private var _writes: [(value: UInt16, at: TimeInterval)] = []
  private var failuresLeft = 0
  private var _failures: [UInt16] = []

  init(scheduler: ManualScheduler) { self.scheduler = scheduler }

  struct Failed: Error {}

  var values: [UInt16] { lock.withLock { _writes.map(\.value) } }
  var times: [TimeInterval] { lock.withLock { _writes.map(\.at) } }
  var reportedFailures: [UInt16] { lock.withLock { _failures } }

  func failNext(_ count: Int) { lock.withLock { failuresLeft = count } }

  func makeQueue(policy: DDCWriteQueue.Policy = .init()) -> DDCWriteQueue {
    DDCWriteQueue(
      scheduler: scheduler, policy: policy,
      write: { [self] value in
        let now = scheduler.now()
        try lock.withLock {
          _writes.append((value, now))
          if failuresLeft > 0 {
            failuresLeft -= 1
            throw Failed()
          }
        }
      },
      onFailure: { [self] value, _ in lock.withLock { _failures.append(value) } })
  }
}

@Test func tenRapidSetsCoalesceToOneWriteWithTheLastValue() {
  let scheduler = ManualScheduler()
  let writer = RecordingWriter(scheduler: scheduler)
  let queue = writer.makeQueue()
  for value in UInt16(1)...10 { queue.submit(value) }
  scheduler.advance(by: 1)
  #expect((1...2).contains(writer.values.count))
  #expect(writer.values.last == 10)
  #expect(!queue.isBusy)
}

@Test func setsArrivingDuringAWriteCoalesceBehindIt() {
  let scheduler = ManualScheduler()
  let writer = RecordingWriter(scheduler: scheduler)
  let queue = writer.makeQueue()
  queue.submit(1)
  scheduler.runDue()  // first value goes out at once
  for value in UInt16(2)...10 { queue.submit(value) }
  scheduler.advance(by: 1)
  #expect(writer.values == [1, 10])
}

@Test func writesAreSpacedByTheConfiguredInterval() {
  let scheduler = ManualScheduler()
  let writer = RecordingWriter(scheduler: scheduler)
  let queue = writer.makeQueue(policy: .init(spacing: 0.05, maxAttempts: 3))
  for step in 0..<6 {
    queue.submit(UInt16(step))
    scheduler.advance(by: 0.01)
  }
  scheduler.advance(by: 1)
  let times = writer.times
  #expect(times.count >= 2)
  for (earlier, later) in zip(times, times.dropFirst()) {
    #expect(later - earlier >= 0.05 - 1e-9)
  }
  #expect(writer.values.last == 5)
}

@Test func idleQueueWritesImmediately() {
  let scheduler = ManualScheduler()
  let writer = RecordingWriter(scheduler: scheduler)
  let queue = writer.makeQueue()
  queue.submit(7)
  scheduler.runDue()
  #expect(writer.values == [7])
  #expect(writer.times == [0])
}

@Test func failedWriteRetriesBoundedTimesThenReportsOnce() {
  let scheduler = ManualScheduler()
  let writer = RecordingWriter(scheduler: scheduler)
  let queue = writer.makeQueue(policy: .init(spacing: 0.05, maxAttempts: 3))
  writer.failNext(100)
  queue.submit(42)
  scheduler.advance(by: 2)
  #expect(writer.values == [42, 42, 42])
  #expect(writer.reportedFailures == [42])
  let times = writer.times
  for (earlier, later) in zip(times, times.dropFirst()) { #expect(later - earlier >= 0.05 - 1e-9) }
  #expect(!queue.isBusy)
}

@Test func retrySucceedsWithoutReportingFailure() {
  let scheduler = ManualScheduler()
  let writer = RecordingWriter(scheduler: scheduler)
  let queue = writer.makeQueue()
  writer.failNext(1)
  queue.submit(9)
  scheduler.advance(by: 1)
  #expect(writer.values == [9, 9])
  #expect(writer.reportedFailures.isEmpty)
}

@Test func newerValueReplacesAPendingRetry() {
  let scheduler = ManualScheduler()
  let writer = RecordingWriter(scheduler: scheduler)
  let queue = writer.makeQueue()
  writer.failNext(1)
  queue.submit(1)
  scheduler.runDue()  // write of 1 fails, retry scheduled
  queue.submit(2)
  scheduler.advance(by: 1)
  #expect(writer.values == [1, 2])
  #expect(writer.reportedFailures.isEmpty)
}

@Test func submitNeverWritesOnTheCallersStack() {
  let scheduler = ManualScheduler()
  let writer = RecordingWriter(scheduler: scheduler)
  let queue = writer.makeQueue()
  queue.submit(3)
  #expect(writer.values.isEmpty)
  #expect(queue.isBusy)
}
