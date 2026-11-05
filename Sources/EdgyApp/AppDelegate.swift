import Actions
import AppKit
import EdgyCore
import EdgyRuntime
import Gestures
import TouchKit

/// Owns the config store, the engine and the status item. Functional shell only: the real icon,
/// settings window and onboarding come from the design sprint.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private let logger = SystemLogger(category: "app")
  private let store = ConfigStore()
  private let frontmost = WorkspaceFrontmostAppProvider()
  private var config = EdgyConfig.defaults
  private var engine: Engine?
  private var statusMenu: StatusMenu?
  private var pausedUntil: Date?
  private var pauseTimer: Timer?

  func applicationDidFinishLaunching(_ notification: Notification) {
    config = loadConfig()

    // Sibling modules are reached only through their frozen factories.
    let engine = Engine(
      touchSource: makeLiveTouchSource(), recognizer: makeGestureRecognizer(),
      actions: makeLiveActionRegistry(settings: config.app), pointerGuard: makeLivePointerGuard(),
      typing: makeLiveTypingActivitySource(), frontmost: frontmost, config: config,
      logger: SystemLogger(category: "engine"), queue: .main)
    self.engine = engine
    do {
      try engine.start()
    } catch {
      logger.log(.error, "Touch input failed to start: \(error)")
    }

    store.startWatching { [weak self] newConfig in
      Task { @MainActor in self?.apply(newConfig) }
    }
    LaunchAtLogin.sync(wanted: config.app.launchAtLogin, logger: logger)

    statusMenu = StatusMenu(handler: self)
    refreshMenu()
  }

  func applicationWillTerminate(_ notification: Notification) {
    store.stopWatching()
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

  private func apply(_ newConfig: EdgyConfig) {
    let old = config
    config = newConfig
    if old.app != newConfig.app {
      engine?.replaceActions(makeLiveActionRegistry(settings: newConfig.app))
    }
    if old.app.launchAtLogin != newConfig.app.launchAtLogin {
      LaunchAtLogin.sync(wanted: newConfig.app.launchAtLogin, logger: logger)
    }
    engine?.apply(newConfig)
    refreshMenu()
  }

  private func refreshMenu() {
    statusMenu?.update(
      StatusMenu.State(enabled: config.app.enabled, pausedUntil: pausedUntil, configPath: store.fileURL.path))
  }

  private func endPause() {
    pauseTimer?.invalidate()
    pauseTimer = nil
    pausedUntil = nil
    engine?.resume()
    refreshMenu()
  }
}

extension AppDelegate: StatusMenuHandler {
  func toggleEnabled() {
    var next = config
    next.app.enabled.toggle()
    do {
      try store.save(next)
    } catch {
      logger.log(.error, "Could not save config: \(error)")
    }
    apply(next)
  }

  func pauseForOneHour() {
    pauseTimer?.invalidate()
    pausedUntil = Date().addingTimeInterval(3600)
    engine?.pause()
    pauseTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: false) { [weak self] _ in
      Task { @MainActor in self?.endPause() }
    }
    refreshMenu()
  }

  func resumeNow() {
    endPause()
  }

  func openConfigFile() {
    NSWorkspace.shared.open(store.fileURL)
  }

  func reloadConfig() {
    do {
      apply(try store.load())
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
