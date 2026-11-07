import AppKit

@MainActor
protocol StatusMenuHandler: AnyObject {
  func showSettings()
  func toggleEnabled()
  func toggleTestMode()
  func pauseForOneHour()
  func resumeNow()
  func grantAccessibility()
  func openConfigFile()
  func reloadConfig()
  func showAbout()
  func quit()
}

/// Placeholder text-only status item. The real icon and menu design come from the design sprint.
@MainActor
final class StatusMenu: NSObject {
  struct State {
    var enabled: Bool
    var pausedUntil: Date?
    var configPath: String
    /// Accessibility isn't granted (yet): offer the way to grant it.
    var needsAccessibility: Bool
    /// The engine sees a built-in or external trackpad.
    var hasTrackpad: Bool
    /// Gestures are recognized but no action runs.
    var testMode: Bool
  }

  private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
  private weak var handler: StatusMenuHandler?

  init(handler: StatusMenuHandler) {
    self.handler = handler
    super.init()
  }

  func update(_ state: State) {
    let active = state.enabled && state.pausedUntil == nil
    item.button?.title = state.testMode ? "Edgy · Test" : "Edgy"
    item.button?.appearsDisabled = !active
    item.button?.toolTip = active ? "Edgy is on" : "Edgy is off"

    let menu = NSMenu()
    if state.needsAccessibility {
      menu.addItem(entry("Grant Accessibility…", #selector(grantAccessibility)))
    }
    if !state.hasTrackpad {
      let none = NSMenuItem(title: "No trackpad found", action: nil, keyEquivalent: "")
      none.isEnabled = false
      menu.addItem(none)
    }
    if state.needsAccessibility || !state.hasTrackpad { menu.addItem(.separator()) }
    let enabled = entry("Enabled", #selector(toggleEnabled))
    enabled.state = state.enabled ? .on : .off
    menu.addItem(enabled)
    let test = entry("Test Mode", #selector(toggleTestMode))
    test.state = state.testMode ? .on : .off
    test.toolTip = "Gestures are recognized but nothing runs; each one is written to the log."
    menu.addItem(test)

    if let until = state.pausedUntil {
      let time = until.formatted(date: .omitted, time: .shortened)
      let paused = NSMenuItem(title: "Paused until \(time)", action: nil, keyEquivalent: "")
      paused.isEnabled = false
      menu.addItem(paused)
      menu.addItem(entry("Resume Now", #selector(resumeNow)))
    } else {
      let pause = entry("Pause for 1 Hour", #selector(pauseForOneHour))
      pause.isEnabled = state.enabled
      menu.addItem(pause)
    }

    menu.addItem(.separator())
    menu.addItem(entry("Settings…", #selector(showSettings), key: ","))
    let open = entry("Open Config File", #selector(openConfigFile))
    open.toolTip = state.configPath
    menu.addItem(open)
    menu.addItem(entry("Reload Config", #selector(reloadConfig)))
    menu.addItem(.separator())
    menu.addItem(entry("About Edgy", #selector(showAbout)))
    menu.addItem(entry("Quit Edgy", #selector(quit), key: "q"))
    // Items with a target are validated against it; keep them enabled unless set above.
    menu.autoenablesItems = false
    item.menu = menu
  }

  private func entry(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
    let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: key)
    menuItem.target = self
    return menuItem
  }

  @objc private func showSettings() { handler?.showSettings() }
  @objc private func toggleEnabled() { handler?.toggleEnabled() }
  @objc private func toggleTestMode() { handler?.toggleTestMode() }
  @objc private func pauseForOneHour() { handler?.pauseForOneHour() }
  @objc private func resumeNow() { handler?.resumeNow() }
  @objc private func grantAccessibility() { handler?.grantAccessibility() }
  @objc private func openConfigFile() { handler?.openConfigFile() }
  @objc private func reloadConfig() { handler?.reloadConfig() }
  @objc private func showAbout() { handler?.showAbout() }
  @objc private func quit() { handler?.quit() }
}
