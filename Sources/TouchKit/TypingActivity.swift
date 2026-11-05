import EdgyCore
import Foundation

/// A global key-down monitor. Behind a protocol so tests never install one.
public protocol KeyMonitorInstalling: AnyObject, Sendable {
  /// Returns false if the monitor could not be installed.
  func install(onKeyDown: @escaping @Sendable () -> Void) -> Bool
}

/// Tracks the time of the last key press.
///
/// Returns nil when the permission needed to observe keys is missing, or before any key press has
/// been seen. The permission check is cached for `permissionRecheckInterval` seconds because the
/// gesture pipeline may read this on every frame.
public final class TypingActivityCore: TypingActivitySource, @unchecked Sendable {
  private let monitor: KeyMonitorInstalling
  private let isPermitted: @Sendable () -> Bool
  private let now: @Sendable () -> TimeInterval
  private let permissionRecheckInterval: TimeInterval

  private let lock = NSLock()
  private var lastKeyDown: TimeInterval?
  private var installed = false
  private var cachedPermission: Bool?
  private var lastPermissionCheck: TimeInterval = 0

  public init(
    monitor: KeyMonitorInstalling,
    isPermitted: @escaping @Sendable () -> Bool,
    now: @escaping @Sendable () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
    permissionRecheckInterval: TimeInterval = 2
  ) {
    self.monitor = monitor
    self.isPermitted = isPermitted
    self.now = now
    self.permissionRecheckInterval = permissionRecheckInterval
    _ = permitted()
  }

  public var isMonitorInstalled: Bool { lock.withLock { installed } }

  public var secondsSinceLastKeyPress: TimeInterval? {
    guard permitted() else { return nil }
    let t = now()
    return lock.withLock { lastKeyDown.map { max(0, t - $0) } }
  }

  func noteKeyDown() {
    let t = now()
    lock.withLock { lastKeyDown = t }
  }

  /// Cached permission check; installs the monitor the first time permission is seen.
  private func permitted() -> Bool {
    let t = now()
    let cached = lock.withLock { () -> Bool? in
      if let cachedPermission, t - lastPermissionCheck < permissionRecheckInterval { return cachedPermission }
      return nil
    }
    if let cached { return cached }
    let ok = isPermitted()
    let needsInstall = lock.withLock { () -> Bool in
      cachedPermission = ok
      lastPermissionCheck = t
      if !ok { lastKeyDown = nil }
      return ok && !installed
    }
    if needsInstall {
      let didInstall = monitor.install { [weak self] in self?.noteKeyDown() }
      lock.withLock { installed = didInstall }
      if !didInstall { TouchKitLog.typing.error("typing monitor could not be installed") }
    }
    return ok
  }
}
