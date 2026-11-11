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
      let activation = Self.describe(app)
      handler(activation)
      guard !activation.hasWindowOnScreen else { return }
      // Its window may still be sliding in (a full-screen Space): look once more, if it stayed.
      DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + Self.windowRecheckS) {
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier else { return }
        handler(Self.describe(app))
      }
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
    // Through the workspace, like a Dock click: a bare `activate()` reports success yet is dropped
    // when the target sits in a full-screen Space (reported 2026-11-10). Opening a running app
    // launches nothing; it only brings it forward.
    guard let url = running.bundleURL else { return running.activate() }
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = true
    NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
      if let error {
        actionsLog.error("last app: bringing the app forward failed: \(error, privacy: .public)")
      }
    }
    return true
  }

  /// How long after an activation with no window the app is looked at again.
  static let windowRecheckS: Double = 1
  /// Smaller than this (points, either side) is a strip, a badge or a bar, not a window.
  static let minWindowSide: Double = 100

  private static func describe(_ app: NSRunningApplication) -> AppActivation {
    AppActivation(
      pid: app.processIdentifier, bundleID: app.bundleIdentifier, isRegular: app.activationPolicy == .regular,
      hasWindowOnScreen: hasWindowOnScreen(pid: app.processIdentifier))
  }

  /// An ordinary window (layer 0, window-sized) of this process on screen now. Overlays, panels
  /// and status items sit on other layers. Reads geometry only, never titles or contents. If the
  /// window list can't be read, the app counts (as before this check existed).
  private static func hasWindowOnScreen(pid: Int32) -> Bool {
    let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
    guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return true }
    return windows.contains { window in
      guard (window[kCGWindowOwnerPID as String] as? Int32) == pid,
        (window[kCGWindowLayer as String] as? Int) == 0,
        let bounds = window[kCGWindowBounds as String] as? [String: Any],
        let width = bounds["Width"] as? Double, let height = bounds["Height"] as? Double
      else { return false }
      return width >= minWindowSide && height >= minWindowSide
    }
  }
}
