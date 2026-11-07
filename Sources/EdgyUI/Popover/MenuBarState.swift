import Actions
import EdgyCore
import EdgyRuntime
import Foundation
import Observation
import SwiftUI

/// What the popover's list and buttons do. The app supplies the live versions; the default does
/// nothing, so previews and tests never touch the system.
public struct MenuBarActions: Sendable {
  public typealias Command = @MainActor @Sendable () -> Void

  /// Opens the settings window (on `model.selectedProfile`, which a chip sets first).
  public var openSettings: Command
  public var openConfigFile: Command
  public var reloadConfig: Command
  public var about: Command
  public var quit: Command
  /// Opens the system privacy pane (the No Accessibility block's **Open Settings**).
  public var openAccessibilitySettings: Command

  public init(
    openSettings: @escaping Command = {}, openConfigFile: @escaping Command = {},
    reloadConfig: @escaping Command = {}, about: @escaping Command = {}, quit: @escaping Command = {},
    openAccessibilitySettings: @escaping Command = {}
  ) {
    self.openSettings = openSettings
    self.openConfigFile = openConfigFile
    self.reloadConfig = reloadConfig
    self.about = about
    self.quit = quit
    self.openAccessibilitySettings = openAccessibilitySettings
  }

  public static let none = MenuBarActions()

  /// The same commands, each running `first` before it (the controller closes the popover).
  func preceded(by first: @escaping Command) -> MenuBarActions {
    func wrap(_ command: @escaping Command) -> Command { { first(); command() } }
    return MenuBarActions(
      openSettings: wrap(openSettings), openConfigFile: wrap(openConfigFile), reloadConfig: wrap(reloadConfig),
      about: wrap(about), quit: wrap(quit), openAccessibilitySettings: wrap(openAccessibilitySettings))
  }
}

/// The popover's state that `SettingsModel` doesn't carry, owned by `MenuBarController` and
/// handed to `MenuPopoverView` through the environment (`.environment(state)`).
///
/// **Two Test Mode flags** (BRIEF § Test Mode: what it does):
/// - `testMode` is the **Test Mode switch**: the overlay is showing (batch 18 reads it, or listens
///   through `onTestModeChange`). Actions still run.
/// - `dontRunActions` is the checkbox under it (dry run). Only it reaches the engine:
///   `model.setTestMode(true)`. So `model.isTestMode` stays false unless it's checked.
/// Neither is persisted. Turning the switch off unchecks the box and leaves the engine running
/// actions, so no one is left with an Edgy that silently does nothing.
@MainActor
@Observable
public final class MenuBarState {
  /// The Test Mode switch: the overlay is on.
  public private(set) var testMode = false
  /// "Don't run actions" (only meaningful while `testMode`).
  public private(set) var dontRunActions = false

  /// From the app's `PermissionMonitor`. Only `.denied` shows the No Accessibility block.
  public var accessibility: PermissionState = .unknown
  /// The broken config file on reload, if any (the same value the settings window reads).
  public var configProblem: ConfigProblem?
  /// The frontmost app, so its profile's chip comes first and the live chip is right.
  public var frontmostBundleID: String?
  /// Installed apps, for chip names and marks (empty is fine: names fall back to the bundle ID).
  public var installedApps: [InstalledApp] = []

  /// The clock the paused countdown reads (injected in tests and snapshots).
  @ObservationIgnored public var now: @MainActor () -> Date = { Date() }
  /// Called when the Test Mode switch changes: the overlay-visible flag for batch 18.
  @ObservationIgnored public var onTestModeChange: (@MainActor (Bool) -> Void)?

  public init() {}

  /// The checkbox shows only while Test Mode is on.
  public var showsDontRunActions: Bool { testMode }

  public func setTestMode(_ on: Bool, model: SettingsModel) {
    guard on != testMode else { return }
    testMode = on
    if !on {
      dontRunActions = false
      if model.isTestMode { model.setTestMode(false) }
    }
    onTestModeChange?(on)
  }

  public func setDontRunActions(_ on: Bool, model: SettingsModel) {
    guard testMode else { return }
    dontRunActions = on
    model.setTestMode(on)
  }

  /// The glyph for the current facts (see `MenuGlyph.state(engine:editor:testMode:accessibility:configProblem:)`).
  public func glyphState(model: SettingsModel) -> MenuGlyph.State {
    _ = model.revision
    return MenuGlyph.state(
      engine: model.engineStatus, editor: model.editor, testMode: testMode, accessibility: accessibility,
      configProblem: configProblem)
  }
}

private struct MenuBarActionsKey: EnvironmentKey {
  static let defaultValue = MenuBarActions.none
}

extension EnvironmentValues {
  /// The popover list's commands for `MenuPopoverView`.
  public var menuBarActions: MenuBarActions {
    get { self[MenuBarActionsKey.self] }
    set { self[MenuBarActionsKey.self] = newValue }
  }
}
