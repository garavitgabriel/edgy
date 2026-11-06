import Foundation

/// A piece of scheduled work that can be called off.
public protocol ScheduledWork: AnyObject {
  func cancel()
}

/// One-shot delayed work on the main actor. The settings layer uses it for debounced saves and
/// permission polling; tests inject a manual clock.
@MainActor
public protocol Scheduling: AnyObject {
  @discardableResult
  func schedule(after seconds: TimeInterval, _ work: @escaping @MainActor @Sendable () -> Void) -> ScheduledWork
}

/// Live scheduler on the main queue.
@MainActor
public final class MainQueueScheduler: Scheduling {
  public init() {}

  @discardableResult
  public func schedule(after seconds: TimeInterval, _ work: @escaping @MainActor @Sendable () -> Void)
    -> ScheduledWork
  {
    let item = DispatchWorkItem { MainActor.assumeIsolated { work() } }
    DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: item)
    return WorkItemHandle(item)
  }

  private final class WorkItemHandle: ScheduledWork {
    let item: DispatchWorkItem
    init(_ item: DispatchWorkItem) { self.item = item }
    func cancel() { item.cancel() }
  }
}
