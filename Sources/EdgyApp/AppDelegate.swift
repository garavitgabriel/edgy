import Actions
import AppKit
import EdgyCore
import EdgyRuntime
import EdgyUI
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
  private var menuBar: MenuBarController?
  private var overlay: OverlayController?
  private var frontmostObserver: NSObjectProtocol?
  private var pauseTimer: Timer?
  private var activationObserver: NSObjectProtocol?
  private var feedObserver: UUID?
  private var settingsModel: SettingsModel?
  private var settingsWindow: SettingsWindowController?

  func applicationDidFinishLaunching(_ notification: Notification) {
    let firstRun = !FileManager.default.fileExists(atPath: store.fileURL.path)
    var config = loadConfig()

    // Sibling modules are reached only through their frozen factories.
    let actions = makeLiveActionRegistry(settings: config.app)
    if firstRun {
      // First launch: start from defaults that work on this Mac (no brightness slide on a Mac
      // whose screens can't take it, no keyboard backlight without one).
      config = MachineDefaults.build(from: .defaults, actions: actions)
      do {
        try store.save(config)
      } catch {
        logger.log(.error, "Could not save first-run defaults: \(error)")
      }
      logger.log(.info, "First run: defaults chosen for this Mac")
    }
    applied = config

    let base = makeGestureRecognizer()
    let engine = Engine(
      touchSource: makeLiveTouchSource(), recognizer: FlushingRecognizer(base) ?? base, actions: actions,
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
      config: config, catalog: actions.available, store: store, scheduler: scheduler, actions: actions,
      apply: { [weak self] in self?.apply($0) })
    editor.observe { [weak self] _ in self?.refreshMenu() }
    self.editor = editor
    let settingsModel = SettingsModel(
      editor: editor, engine: engine, installedApps: makeLiveInstalledAppsProvider(),
      shortcuts: makeLiveShortcutsListing(), keyRecorder: makeLiveKeyComboRecorder())
    self.settingsModel = settingsModel
    settingsWindow = SettingsWindowController(
      model: settingsModel,
      commands: WindowCommands(
        openAccessibilitySettings: { [weak self] in self?.grantAccessibility() },
        openConfigFile: { [weak self] in self?.openConfigFile() },
        reloadConfig: { [weak self] in self?.reloadConfig() },
        replaceWithCurrentSettings: { [weak self] in self?.replaceFileWithCurrentSettings() }))

    store.startWatching(
      onChange: { [weak self] newConfig in
        Task { @MainActor in self?.editor?.adoptExternal(newConfig) }
      },
      onFailure: { [weak self] error in
        let message = String(describing: error)
        Task { @MainActor in
          self?.logger.log(.error, "Config file didn't load: \(message)")
          self?.editor?.reportConfigProblem(error)
        }
      })
    LaunchAtLogin.sync(wanted: config.app.launchAtLogin, logger: logger)

    // The designed menu-bar glyph + glass popover (EdgyUI). The old text menu (StatusMenu) stays
    // in the source as a fallback but is no longer installed.
    let menuBar = MenuBarController(
      model: settingsModel,
      actions: MenuBarActions(
        openSettings: { [weak self] in self?.showSettings() },
        openConfigFile: { [weak self] in self?.openConfigFile() },
        reloadConfig: { [weak self] in self?.reloadConfig() },
        about: { [weak self] in self?.showAbout() },
        quit: { [weak self] in self?.quit() },
        openAccessibilitySettings: { [weak self] in self?.grantAccessibility() }))
    // The overlay always runs (level plate for external displays, the display check); Test Mode
    // adds its recognized / ignored plates.
    let overlay = OverlayController(model: settingsModel)
    overlay.start()
    self.overlay = overlay
    menuBar.onOverlayVisibleChange = { [weak self] visible in self?.overlay?.showsTestModePlates = visible }
    menuBar.state.frontmostBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    menuBar.install()
    self.menuBar = menuBar
    frontmostObserver = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
    ) { [weak self] note in
      let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
      let id = app?.bundleIdentifier
      MainActor.assumeIsolated {
        guard id != Bundle.main.bundleIdentifier else { return }
        self?.menuBar?.state.frontmostBundleID = id
        self?.settingsModel?.frontmostBundleID = id
      }
    }
    if let apps = settingsModel.installedApps {
      Task { @MainActor [weak self] in self?.menuBar?.state.installedApps = await apps.installedApps() }
    }
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
    menuBar?.state.accessibility = permissions?.accessibility ?? .unknown
    menuBar?.state.configProblem = editor?.configProblem.map {
      EdgyUI.ConfigProblem(fileName: store.fileURL.lastPathComponent, line: $0.line, message: $0.message)
    }
    settingsWindow?.state.conditions.accessibility = permissions?.accessibility ?? .unknown
    settingsWindow?.state.conditions.configProblem = editor?.configProblem.map {
      EdgyUI.ConfigProblem(fileName: store.fileURL.lastPathComponent, line: $0.line, message: $0.message)
    }
    statusMenu?.update(
      StatusMenu.State(
        enabled: editor?.config.app.enabled ?? applied.app.enabled, pausedUntil: engineStatus.pausedUntil,
        configPath: store.fileURL.path, needsAccessibility: (permissions?.accessibility ?? .unknown) != .granted,
        hasTrackpad: engineStatus.hasTrackpad, testMode: engine?.isTestMode ?? false))
  }

  private func endPause() {
    pauseTimer?.invalidate()
    pauseTimer = nil
    engine?.resume()
  }
}

extension AppDelegate: StatusMenuHandler {
  func replaceFileWithCurrentSettings() {
    do {
      try editor?.replaceFileWithCurrentSettings()
    } catch {
      logger.log(.error, "Could not replace the config file: \(error)")
    }
    refreshMenu()
  }

  func showSettings() {
    settingsWindow?.show()
  }

  func toggleEnabled() {
    do {
      try editor?.updateAppSettings { $0.enabled.toggle() }
    } catch {
      logger.log(.error, "Could not change Enabled: \(error)")
    }
  }

  /// Test Mode until the settings window exists: gestures are recognized but nothing runs, and
  /// each decision goes to the log (`log stream --predicate 'subsystem == "com.garavit.edgy"'`).
  func toggleTestMode() {
    guard let engine else { return }
    let on = !engine.isTestMode
    if on {
      let log = SystemLogger(category: "testmode")
      feedObserver = engine.observeFeed { update in
        for decision in update.decisions { log.log(.info, "\(decision)") }
      }
    } else if let feedObserver {
      engine.removeFeedObserver(feedObserver)
      self.feedObserver = nil
    }
    engine.setTestMode(on)
    refreshMenu()
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

/// Lets the engine wake the gesture recognizer for a tap that waits out the double-tap window.
/// EdgyRuntime can't see Gestures, so it asks for its own `GestureFlushing`; this forwards to the
/// recognizer's `DeferredGestureFlushing`.
private final class FlushingRecognizer: GestureRecognizing, GestureFlushing {
  private let inner: GestureRecognizing & DeferredGestureFlushing

  init?(_ recognizer: GestureRecognizing) {
    guard let flushing = recognizer as? (GestureRecognizing & DeferredGestureFlushing) else { return nil }
    inner = flushing
  }

  func process(_ frame: TouchFrame, device: TouchDeviceInfo, context: GestureContext) -> GestureOutput {
    inner.process(frame, device: device, context: context)
  }

  func reset() { inner.reset() }

  var nextFlushDeadline: Double? { inner.nextFlushDeadline }

  func flush(now: Double) -> GestureOutput { inner.flush(now: now) }
}
