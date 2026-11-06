import CoreGraphics
import EdgyCore
import Foundation

/// Failure reported by a system output. The registry turns it into `ActionError.unavailable`.
struct OutputError: Error, Equatable {
  var reason: String
  init(_ reason: String) { self.reason = reason }
}

/// Default output / input audio devices.
protocol AudioOutput: AnyObject {
  /// Output volume, 0...1.
  func outputVolume() throws -> Double
  func setOutputVolume(_ level: Double) throws
  func isOutputMuted() throws -> Bool
  func setOutputMuted(_ muted: Bool) throws
  func isInputMuted() throws -> Bool
  func setInputMuted(_ muted: Bool) throws
  /// True when the default output is a headphone jack / headset.
  func outputIsHeadphones() -> Bool
}

/// Built-in display backlight.
protocol BrightnessOutput: AnyObject {
  var isAvailable: Bool { get }
  /// Brightness, 0...1.
  func brightness() throws -> Double
  func setBrightness(_ level: Double) throws
}

/// System media keys.
protocol MediaKeyOutput: AnyObject {
  func playPause()
  func next()
  func previous()
}

/// What the on-screen level indicator shows.
enum HUDKind: Equatable, Sendable {
  case volume(muted: Bool, headphones: Bool)
  case brightness
}

/// The on-screen level indicator. The registry never calls it when `HUDMode` is `.none`.
protocol HUDOutput: AnyObject {
  /// `level` is 0...1.
  func show(_ kind: HUDKind, level: Double)
}

/// Trackpad haptics. The registry never calls it when haptics are disabled.
protocol HapticOutput: AnyObject {
  /// `strength` is on `AppSettings.hapticStrengthRange` (1 = lightest).
  func tick(strength: Int)
  func strongTick(strength: Int)
}

/// Runs a user Shortcut. Must return immediately; the work happens off the caller's thread.
protocol ShortcutRunner: AnyObject {
  func run(name: String)
}

/// Posts keyboard shortcuts as if typed. Needs Accessibility.
protocol KeyboardOutput: AnyObject {
  /// Presses and releases `combo` (modifiers down, key down/up, modifiers up).
  func post(_ combo: KeyCombo) throws
}

/// Apps, URLs and files.
protocol WorkspaceOutput: AnyObject {
  /// True when an app with this bundle ID is the frontmost app.
  func isFrontmost(bundleID: String) -> Bool
  /// Brings the app forward (unhiding it), launching it first if it isn't running.
  /// No app installed with this bundle ID → `OutputError`.
  func activate(bundleID: String) throws
  /// Hides every running instance of the app.
  func hide(bundleID: String)
  /// Opens a URL in its default handler.
  func open(url: URL) throws
  /// Opens a file or folder in its default app. Nothing at `file` → `OutputError`.
  func open(file: URL) throws
}

/// Identity of an on-screen window, stable for as long as the window exists.
struct WindowID: Hashable, Sendable {
  var pid: Int32
  /// Opaque per-window token from the output (a hash of the window's accessibility element).
  var token: Int
}

/// The focused window and the screen area it may occupy, both in top-left-origin global
/// coordinates (y grows downward; origin at the top-left of the primary display).
struct WindowSnapshot: Equatable, Sendable {
  var id: WindowID
  var frame: CGRect
  /// The visible frame (minus menu bar and Dock) of the screen containing the window.
  var visibleFrame: CGRect
}

/// The frontmost app's focused window. Needs Accessibility.
protocol WindowOutput: AnyObject {
  /// No focused window → `OutputError`.
  func focusedWindow() throws -> WindowSnapshot
  /// Moves and resizes the window. `frame` is in top-left-origin global coordinates.
  func setFrame(_ frame: CGRect, of window: WindowID) throws
  func minimize(_ window: WindowID) throws
}

/// System-wide views and power commands.
enum SystemCommand: String, CaseIterable, Equatable, Sendable {
  case missionControl, appWindows, showDesktop, spaceLeft, spaceRight, lockScreen, sleepDisplay
}

/// Mission Control family, Spaces, lock and display sleep.
protocol SystemOutput: AnyObject {
  func perform(_ command: SystemCommand) throws
}
