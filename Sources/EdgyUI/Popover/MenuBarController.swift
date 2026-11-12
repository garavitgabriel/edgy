import AppKit
import Observation
import SwiftUI
import os

private let popoverLog = Logger(subsystem: "com.garavit.edgy", category: "popover")

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
  private var popoverResizeObserver: NSObjectProtocol?
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
    logPopoverFrame("shown", button: button)
    if popoverResizeObserver == nil, let window = popover.contentViewController?.view.window {
      popoverResizeObserver = NotificationCenter.default.addObserver(
        forName: NSWindow.didResizeNotification, object: window, queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated { self?.logPopoverFrame("resized", button: button) }
      }
    }
  }

  /// One info line per show: the popover's frame against the glyph and the screen's visible area,
  /// so a popover drawn up over its own glyph shows up in the log (`category == "popover"`).
  /// A placed popover's top edge sits at the glyph's bottom edge (`aboveGlyph false`).
  private func logPopoverFrame(_ event: String, button: NSStatusBarButton) {
    guard let window = popover?.contentViewController?.view.window else { return }
    let glyph = button.window.map { $0.convertToScreen(button.convert(button.bounds, to: nil)) } ?? .zero
    let visible = window.screen?.visibleFrame ?? .zero
    popoverLog.info(
      "popover \(event, privacy: .public): frame \(NSStringFromRect(window.frame), privacy: .public) glyph \(NSStringFromRect(glyph), privacy: .public) visible \(NSStringFromRect(visible), privacy: .public) aboveGlyph \(window.frame.maxY > glyph.minY + 1, privacy: .public)"
    )
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
    // The mini mirror is drawn to scale, so the popover's height changes when the mirrored
    // trackpad changes (a Magic Trackpad beside a built-in one). Without `.preferredContentSize`
    // the hosting view resized the popover window from its bottom-left origin, so it grew upward
    // over the menu bar and off the top of the screen. With it, NSPopover re-anchors to the glyph.
    let hosting = NSHostingController(rootView: root)
    hosting.sizingOptions = [.preferredContentSize]
    popover.contentViewController = hosting
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
