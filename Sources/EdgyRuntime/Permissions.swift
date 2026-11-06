import Foundation

public enum PermissionState: String, Sendable {
  case granted, denied, unknown
}

/// Reads the app's privacy permissions. The live implementation (in EdgyApp) asks the system;
/// tests script it.
@MainActor
public protocol PermissionChecking: AnyObject {
  var accessibility: PermissionState { get }
}

/// Watches the Accessibility permission. While it is not granted, re-checks every `interval`
/// seconds on the injected scheduler and reports each transition; once granted, polling stops.
/// Call `refresh()` when the app becomes active to catch a later revocation.
@MainActor
public final class PermissionMonitor {
  public static let defaultInterval: TimeInterval = 1.5

  public private(set) var accessibility: PermissionState = .unknown
  public private(set) var isPolling = false

  private let checker: PermissionChecking
  private let scheduler: Scheduling
  private let interval: TimeInterval
  private let onChange: @MainActor (PermissionState) -> Void
  private var pending: ScheduledWork?

  public init(
    checker: PermissionChecking, scheduler: Scheduling, interval: TimeInterval = PermissionMonitor.defaultInterval,
    onChange: @escaping @MainActor (PermissionState) -> Void
  ) {
    self.checker = checker
    self.scheduler = scheduler
    self.interval = interval
    self.onChange = onChange
  }

  /// Checks now (reporting the first state) and polls if not granted.
  public func start() {
    refresh()
  }

  public func stop() {
    pending?.cancel()
    pending = nil
    isPolling = false
  }

  /// Checks now; reports a transition; starts or stops polling to match.
  public func refresh() {
    let state = checker.accessibility
    if state != accessibility {
      accessibility = state
      onChange(state)
    }
    if state == .granted {
      stop()
    } else if !isPolling {
      isPolling = true
      schedulePoll()
    }
  }

  private func schedulePoll() {
    pending = scheduler.schedule(after: interval) { [weak self] in
      guard let self, self.isPolling else { return }
      self.pending = nil
      self.isPolling = false
      self.refresh()
    }
  }
}
