import AppKit
import EdgyCore

/// Tracks app activations through the workspace's did-activate notification (no polling) and
/// brings a running app back with `NSRunningApplication.activate`.
final class LiveAppActivations: AppActivationOutput, @unchecked Sendable {
  let ownPID = ProcessInfo.processInfo.processIdentifier
  private let lock = NSLock()
  private var observer: NSObjectProtocol?

  deinit {
    if let observer { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
  }

  func startObserving(_ handler: @escaping @Sendable (AppActivation) -> Void) {
    lock.lock()
    defer { lock.unlock() }
    guard observer == nil else { return }
    observer = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: nil
    ) { note in
      guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
      handler(Self.describe(app))
    }
    if let front = NSWorkspace.shared.frontmostApplication { handler(Self.describe(front)) }
  }

  func frontmost() -> AppActivation? { NSWorkspace.shared.frontmostApplication.map(Self.describe) }

  func isRunning(_ app: AppActivation) -> Bool {
    guard let running = NSRunningApplication(processIdentifier: app.pid), !running.isTerminated else { return false }
    return running.bundleIdentifier == app.bundleID
  }

  func activate(_ app: AppActivation) -> Bool {
    guard let running = NSRunningApplication(processIdentifier: app.pid), !running.isTerminated else { return false }
    running.unhide()
    return running.activate()
  }

  private static func describe(_ app: NSRunningApplication) -> AppActivation {
    AppActivation(
      pid: app.processIdentifier, bundleID: app.bundleIdentifier, isRegular: app.activationPolicy == .regular)
  }
}
