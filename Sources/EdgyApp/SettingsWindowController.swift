import AppKit
import EdgyRuntime
import EdgyUI
import Observation
import SwiftUI

/// Live window-level conditions the app knows and the model doesn't (Accessibility, a broken
/// config file), pushed into the window through `\.windowConditions`.
@MainActor
@Observable
final class SettingsWindowState {
  var conditions = WindowConditions.normal
}

/// Hosts the designed settings window (`SettingsWindowView`, EdgyUI) in an AppKit window with a
/// transparent full-size title bar, so the profile tabs share the title bar. Edgy is a menu-bar
/// app: showing the window brings Edgy forward; closing it leaves Edgy running.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
  private let model: SettingsModel
  let state = SettingsWindowState()
  private let commands: WindowCommands
  private var window: NSWindow?

  init(model: SettingsModel, commands: WindowCommands) {
    self.model = model
    self.commands = commands
  }

  func show() {
    if window == nil {
      let root = SettingsWindowRoot(model: model, state: state, commands: commands)
      let host = NSHostingController(rootView: root)
      let window = NSWindow(contentViewController: host)
      window.title = "Edgy"
      window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
      window.titlebarAppearsTransparent = true
      window.titleVisibility = .hidden
      window.isMovableByWindowBackground = true
      window.isReleasedWhenClosed = false
      window.contentMinSize = SettingsWindowView.minimumSize
      window.setContentSize(SettingsWindowView.minimumSize)
      window.delegate = self
      window.center()
      self.window = window
    }
    model.startFeed()
    // While Settings is open Edgy shows in the Dock and the app switcher (BRIEF § Window identity).
    NSApp.setActivationPolicy(.regular)
    NSApp.activate()
    window?.makeKeyAndOrderFront(nil)
  }

  func windowWillClose(_ notification: Notification) {
    // The feed stays on: the overlay (level plate, display check, Test Mode) needs it whether or
    // not this window is open. The engine throttles touches, so a running feed costs little.
    NSApp.setActivationPolicy(.accessory)
  }
}

private struct SettingsWindowRoot: View {
  let model: SettingsModel
  let state: SettingsWindowState
  let commands: WindowCommands

  var body: some View {
    SettingsWindowView(model: model)
      .environment(\.windowConditions, state.conditions)
      .environment(\.windowCommands, commands)
  }
}
