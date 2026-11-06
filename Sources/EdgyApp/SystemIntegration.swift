import AppKit
import ApplicationServices
import EdgyRuntime
import ServiceManagement

/// Tracks the frontmost app's bundle ID from workspace activation notifications.
/// Read from the engine queue, written on the main queue, so the value is lock-protected.
final class WorkspaceFrontmostAppProvider: FrontmostAppProviding, @unchecked Sendable {
  private let lock = NSLock()
  private var current: String?
  private var observer: NSObjectProtocol?

  @MainActor init() {
    current = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    observer = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
    ) { [weak self] note in
      let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
      self?.set(app?.bundleIdentifier)
    }
  }

  deinit {
    if let observer { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
  }

  var frontmostBundleID: String? { lock.withLock { current } }

  private func set(_ bundleID: String?) {
    lock.withLock { current = bundleID }
  }
}

/// Live Accessibility check. `AXIsProcessTrusted` answers yes or no, so this never reports `.unknown`.
@MainActor
final class AccessibilityPermissionChecker: PermissionChecking {
  var accessibility: PermissionState { AXIsProcessTrusted() ? .granted : .denied }
}

enum AccessibilitySettings {
  static let paneURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!

  /// Opens System Settings → Privacy & Security → Accessibility.
  @MainActor static func open(logger: EdgyLogging) {
    if !NSWorkspace.shared.open(paneURL) {
      logger.log(.error, "Could not open the Accessibility settings pane")
    }
  }
}

/// Keeps the login-item registration in line with `AppSettings.launchAtLogin`.
/// Registration only works from a signed app bundle; failures are logged, never fatal.
enum LaunchAtLogin {
  @MainActor static func sync(wanted: Bool, logger: EdgyLogging) {
    let service = SMAppService.mainApp
    let registered = service.status == .enabled || service.status == .requiresApproval
    guard wanted != registered else { return }
    do {
      if wanted {
        try service.register()
        logger.log(.info, "Registered as login item (status: \(service.status.rawValue))")
      } else {
        try service.unregister()
        logger.log(.info, "Removed login item")
      }
    } catch {
      logger.log(.error, "Launch-at-login update failed: \(error)")
    }
  }
}
