import Actions
import AppKit
import EdgyCore
import EdgyRuntime
import Gestures
import TouchKit

/// Owns the config store, the settings editor, the engine and the status item. Functional shell
/// only: the real icon, settings window and onboarding come from the design sprint.
///
/// Every config write goes through `SettingsEditor`; the editor's `apply` hands committed configs
/// to the engine. File-watcher reloads enter the editor as external edits.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private let logger = SystemLogger(category: "app")
  private let store = ConfigStore()
  private let frontmost = WorkspaceFrontmostAppProvider()
  private let scheduler = MainQueueScheduler()
  /// The config the engine last received; used to spot launch-at-login changes.
  private var applied = EdgyConfig.defaults
  private var engine: Engine?
  private var editor: SettingsEditor?
  private var permissions: PermissionMonitor?
  private var engineStatus = EngineStatus()
  private var statusMenu: StatusMenu?
  private var pauseTimer: Timer?
  private var activationObserver: NSObjectProtocol?

  func applicationDidFinishLaunching(_ notification: Notification) {
    let config = loadConfig()
    applied = config

    // Sibling modules are reached only through their frozen factories.
    let actions = makeLiveActionRegistry(settings: config.app)
    let engine = Engine(
      touchSource: makeLiveTouchSource(), recognizer: makeGestureRecognizer(), actions: actions,
      pointerGuard: makeLivePointerGuard(), typing: makeLiveTypingActivitySource(), frontmost: frontmost,
      config: config, logger: SystemLogger(category: "engine"), queue: .main)
    self.engine = engine
    engine.onStatusChange { [weak self] status in
      Task { @MainActor in self?.engineStatusChanged(status) }
    }
    do {
      try engine.start()
    } catch {
      logger.log(.error, "Touch input failed to start: \(error)")
    }
    engineStatus = engine.status

    let editor = SettingsEditor(
      config: config, catalog: actions.available, store: store, scheduler: scheduler,
      apply: { [weak self] in self?.apply($0) })
    editor.observe { [weak self] _ in self?.refreshMenu() }
    self.editor = editor

    store.startWatching { [weak self] newConfig in
      Task { @MainActor in self?.editor?.adoptExternal(newConfig) }
    }
    LaunchAtLogin.sync(wanted: config.app.launchAtLogin, logger: logger)

    statusMenu = StatusMenu(handler: self)
    let permissions = PermissionMonitor(checker: AccessibilityPermissionChecker(), scheduler: scheduler) {
      [weak self] state in
      self?.logger.log(.info, "Accessibility permission: \(state.rawValue)")
      self?.refreshMenu()
    }
    self.permissions = permissions
    permissions.start()
    activationObserver = NotificationCenter.default.addObserver(
      forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.permissions?.refresh() }
    }
    refreshMenu()
  }

  func applicationWillTerminate(_ notification: Notification) {
    try? editor?.endContinuousEdit()
    store.stopWatching()
    permissions?.stop()
    engine?.stop()
  }

  private func loadConfig() -> EdgyConfig {
    do {
      return try store.load()
    } catch {
      logger.log(.error, "\(error)")
      return store.config
    }
  }

  /// The editor's `apply`: push a committed config to the engine and the system.
  private func apply(_ newConfig: EdgyConfig) {
    let old = applied
    applied = newConfig
    if old.app.launchAtLogin != newConfig.app.launchAtLogin {
      LaunchAtLogin.sync(wanted: newConfig.app.launchAtLogin, logger: logger)
    }
    engine?.apply(newConfig)
  }

  private func engineStatusChanged(_ status: EngineStatus) {
    engineStatus = status
    refreshMenu()
  }

  private func refreshMenu() {
    statusMenu?.update(
      StatusMenu.State(
        enabled: editor?.config.app.enabled ?? applied.app.enabled, pausedUntil: engineStatus.pausedUntil,
        configPath: store.fileURL.path, needsAccessibility: (permissions?.accessibility ?? .unknown) != .granted,
        hasTrackpad: engineStatus.hasTrackpad))
  }

  private func endPause() {
    pauseTimer?.invalidate()
    pauseTimer = nil
    engine?.resume()
  }
}

extension AppDelegate: StatusMenuHandler {
  func toggleEnabled() {
    do {
      try editor?.updateAppSettings { $0.enabled.toggle() }
    } catch {
      logger.log(.error, "Could not change Enabled: \(error)")
    }
  }

  func pauseForOneHour() {
    pauseTimer?.invalidate()
    engine?.pause(until: Date().addingTimeInterval(3600))
    pauseTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: false) { [weak self] _ in
      Task { @MainActor in self?.endPause() }
    }
  }

  func resumeNow() {
    endPause()
  }

  func grantAccessibility() {
    AccessibilitySettings.open(logger: logger)
    permissions?.refresh()
  }

  func openConfigFile() {
    NSWorkspace.shared.open(store.fileURL)
  }

  func reloadConfig() {
    do {
      try editor?.reloadFromDisk()
    } catch {
      logger.log(.error, "\(error)")
      let alert = NSAlert()
      alert.messageText = "Edgy couldn't reload its config"
      alert.informativeText = String(describing: error)
      NSApp.activate()
      alert.runModal()
    }
  }

  func showAbout() {
    NSApp.activate()
    NSApp.orderFrontStandardAboutPanel(nil)
  }

  func quit() {
    NSApp.terminate(nil)
  }
}
