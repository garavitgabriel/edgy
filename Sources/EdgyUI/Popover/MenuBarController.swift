import AppKit
import Observation
import SwiftUI

/// Hosts Edgy in the menu bar: the `NSStatusItem` with the glyph for the current state, and a
/// transient `NSPopover` hosting `MenuPopoverView` (stage-2 brief, batch 17).
///
/// The app creates one, sets `state` facts (Accessibility, broken config, frontmost app,
/// installed apps) as they change, and calls `install()`. Nothing touches the menu bar until
/// `install()`, so tests can build one and read `glyphState` without a status item.
///
/// **Overlay flag for batch 18:** `isOverlayVisible` (the Test Mode switch) and
/// `onOverlayVisibleChange`; start/stop the overlay controller from there.
@MainActor
public final class MenuBarController: NSObject {
  public let model: SettingsModel
  public let state: MenuBarState
  /// The list's commands. Each one closes the popover first.
  public var actions: MenuBarActions

  private var statusItem: NSStatusItem?
  private var popover: NSPopover?
  private var shownGlyph: MenuGlyph.State?

  public init(model: SettingsModel, actions: MenuBarActions = .none, state: MenuBarState = MenuBarState()) {
    self.model = model
    self.actions = actions
    self.state = state
    super.init()
  }

  // MARK: Overlay (batch 18)

  /// The Test Mode switch is on: the overlay should show.
  public var isOverlayVisible: Bool { state.testMode }

  /// Called with the new value whenever the Test Mode switch changes.
  public var onOverlayVisibleChange: (@MainActor (Bool) -> Void)? {
    get { state.onTestModeChange }
    set { state.onTestModeChange = newValue }
  }

  // MARK: Glyph

  /// The state the glyph shows right now (precedence per BRIEF; see `MenuGlyph.state`).
  public var glyphState: MenuGlyph.State { state.glyphState(model: model) }

  // MARK: Lifecycle

  /// Adds the status item and starts following the glyph state.
  public func install() {
    guard statusItem == nil else { return }
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    item.button?.target = self
    item.button?.action = #selector(togglePopover(_:))
    statusItem = item
    applyGlyph()
    followGlyph()
  }

  /// Removes the status item and closes the popover.
  public func uninstall() {
    popover?.performClose(nil)
    popover = nil
    if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) }
    statusItem = nil
    shownGlyph = nil
  }

  /// Opens the popover under the glyph (onboarding's Done opens it once).
  public func showPopover() {
    guard let button = statusItem?.button else { return }
    let popover = self.popover ?? makePopover()
    self.popover = popover
    guard !popover.isShown else { return }
    // The mini mirror is live. `SettingsModel` has one shared feed (the window and the overlay
    // read it too), so the popover starts it but never stops it; the app owns that.
    model.startFeed()
    popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    popover.contentViewController?.view.window?.makeKey()
  }

  public func closePopover() {
    popover?.performClose(nil)
  }

  // MARK: Private

  @objc private func togglePopover(_ sender: Any?) {
    if popover?.isShown == true { closePopover() } else { showPopover() }
  }

  private func makePopover() -> NSPopover {
    let popover = NSPopover()
    popover.behavior = .transient
    popover.animates = true
    let wrapped = actions.preceded { [weak self] in self?.closePopover() }
    let root = MenuPopoverView(model: model)
      .environment(state)
      .environment(\.menuBarActions, wrapped)
    popover.contentViewController = NSHostingController(rootView: root)
    return popover
  }

  private func applyGlyph() {
    let glyph = glyphState
    guard glyph != shownGlyph, let button = statusItem?.button else { return }
    shownGlyph = glyph
    button.image = MenuGlyph.image(for: glyph)
    button.setAccessibilityLabel(MenuGlyph.accessibilityLabel(for: glyph))
  }

  /// Re-applies the glyph whenever anything it reads changes (model status, settings, state).
  private func followGlyph() {
    withObservationTracking {
      _ = glyphState
    } onChange: { [weak self] in
      Task { @MainActor in
        guard let self, self.statusItem != nil else { return }
        self.applyGlyph()
        self.followGlyph()
      }
    }
  }
}
