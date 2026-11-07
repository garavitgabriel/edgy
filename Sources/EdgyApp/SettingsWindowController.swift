import AppKit
import EdgyUI
import SwiftUI

/// Hosts the designed settings window (`SettingsWindowView`, EdgyUI) in an AppKit window.
/// Edgy is a menu-bar app, so showing the window also brings the app forward; closing it leaves
/// Edgy running in the menu bar.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
  private let model: SettingsModel
  private var window: NSWindow?

  init(model: SettingsModel) {
    self.model = model
  }

  func show() {
    if window == nil {
      let host = NSHostingController(rootView: SettingsWindowView(model: model))
      let window = NSWindow(contentViewController: host)
      window.title = "Edgy"
      window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
      window.titlebarAppearsTransparent = true
      window.titleVisibility = .hidden
      window.isMovableByWindowBackground = true
      window.isReleasedWhenClosed = false
      window.delegate = self
      window.setContentSize(host.view.fittingSize)
      window.center()
      self.window = window
    }
    model.startFeed()
    NSApp.activate()
    window?.makeKeyAndOrderFront(nil)
  }

  func windowWillClose(_ notification: Notification) {
    model.stopFeed()
  }
}
