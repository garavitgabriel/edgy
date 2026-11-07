import AppKit
import EdgyRuntime
import SwiftUI

/// Hosts onboarding (stage-2 brief, batch 19): the 640 × 520 glass window with `OnboardingView`.
///
/// - The Accessibility permission is watched live through the injected `PermissionChecking`
///   (a `PermissionMonitor` polls until granted). When access is granted, the window comes back to
///   the front, so the user returning from System Settings sees the step flip.
/// - **Done** closes the window, then calls `actions.finish` once: the app marks onboarding done
///   and opens the menu-bar popover once.
/// - Closing the window early (the close button) doesn't call `finish`; onboarding stays undone
///   and the app may show it again on the next launch.
///
/// Nothing touches the screen until `show()`, so tests build one and drive `state` directly.
@MainActor
public final class OnboardingController: NSObject, NSWindowDelegate {
  public let model: SettingsModel
  public let state: OnboardingState

  private let permissions: PermissionChecking?
  private let scheduler: Scheduling
  private var monitor: PermissionMonitor?
  private var window: NSWindow?

  /// - Parameters:
  ///   - actions: Open Settings and the finish closure.
  ///   - permissions: the live Accessibility check (`nil` = previews: stays unknown).
  ///   - scheduler: drives the permission polling (tests inject a manual one).
  public init(
    model: SettingsModel, actions: OnboardingActions, permissions: PermissionChecking? = nil,
    scheduler: Scheduling = MainQueueScheduler()
  ) {
    self.model = model
    self.permissions = permissions
    self.scheduler = scheduler
    state = OnboardingState(model: model, actions: actions)
    super.init()
    state.beforeFinish = { [weak self] in self?.closeWindow() }
  }

  /// The window is on screen.
  public var isShown: Bool { window?.isVisible == true }

  /// Opens the window (or brings it forward) and starts watching the permission and the feed.
  public func show() {
    if window == nil {
      let host = NSHostingController(rootView: OnboardingView(model: model, state: state))
      host.sizingOptions = []
      let window = NSWindow(contentViewController: host)
      window.title = "Edgy"
      window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
      window.titlebarAppearsTransparent = true
      window.titleVisibility = .hidden
      window.isMovableByWindowBackground = true
      window.isReleasedWhenClosed = false
      window.setContentSize(OnboardingMetrics.windowSize)
      window.delegate = self
      window.center()
      self.window = window
    }
    startWatching()
    NSApp.activate()
    window?.makeKeyAndOrderFront(nil)
  }

  /// Starts the permission monitor and the feed (idempotent). `show()` calls it.
  func startWatching() {
    state.start()
    guard monitor == nil, let permissions else { return }
    let monitor = PermissionMonitor(checker: permissions, scheduler: scheduler) { [weak self] permission in
      self?.permissionChanged(permission)
    }
    self.monitor = monitor
    monitor.start()
  }

  /// Re-checks the permission now (the app calls it when Edgy becomes active).
  public func refreshPermission() {
    monitor?.refresh()
  }

  public func windowWillClose(_ notification: Notification) {
    stopWatching()
  }

  // MARK: Private

  private func permissionChanged(_ permission: PermissionState) {
    let wasGranted = state.isAccessibilityGranted
    state.setAccessibility(permission)
    if permission == .granted, !wasGranted, isShown {
      NSApp.activate()
      window?.makeKeyAndOrderFront(nil)
    }
  }

  private func closeWindow() {
    window?.close()
    stopWatching()
  }

  private func stopWatching() {
    monitor?.stop()
    monitor = nil
    state.windowClosed()
    // The feed is shared; the popover (opened next on Done) or the settings window start it
    // again when they show. Same rule as the settings window's controller.
    model.stopFeed()
  }
}
