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
  /// The trackpad the next ticks play on (`ActionContext.deviceID`); `nil` = the default trackpad.
  func target(deviceID: UInt64?)
}

/// Runs a user Shortcut. Must return immediately; the work happens off the caller's thread.
protocol ShortcutRunner: AnyObject {
  func run(name: String)
}

/// Posts keyboard shortcuts as if typed. Needs Accessibility.
protocol KeyboardOutput: AnyObject {
  /// Presses and releases `combo` (modifiers down, key down/up, modifiers up).
  func post(_ combo: KeyCombo) throws
  /// Presses (`down: true`) or releases each modifier key, in the order given, and leaves it in
  /// that state. For keys held across calls (app switcher, hold-a-key). Implementations track
  /// which modifiers are down so every event carries the right flags.
  func setModifiers(_ modifiers: [KeyCombo.Modifier], down: Bool) throws
  /// One key-down or key-up of `key`, flagged with `modifiers` (their own keys are not pressed).
  func key(_ key: String, down: Bool, modifiers: Set<KeyCombo.Modifier>) throws
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
  /// The window is in macOS full screen (its own Space); it can't be moved or resized until it
  /// leaves.
  var isFullScreen = false
}

/// The frontmost app's focused window. Needs Accessibility.
///
/// `isFullScreen(_:)` and `snapshot(of:)` may be called from a `TransitionWaiter`'s queue while
/// the action thread uses the other methods; implementations must allow that.
protocol WindowOutput: AnyObject {
  /// No focused window → `OutputError`.
  func focusedWindow() throws -> WindowSnapshot
  /// A fresh snapshot of a window handed out earlier by `focusedWindow`.
  func snapshot(of window: WindowID) throws -> WindowSnapshot
  /// Moves and resizes the window. `frame` is in top-left-origin global coordinates.
  func setFrame(_ frame: CGRect, of window: WindowID) throws
  func minimize(_ window: WindowID) throws
  /// Asks the window to leave full screen. Returns at once; the transition animates afterwards.
  func exitFullScreen(_ window: WindowID) throws
}

// MARK: - v0.3 outputs

/// The keyboard's system level keys. They reach macOS as system-defined events, so the system
/// changes the level itself and draws its own current HUD (including per-device variants).
enum LevelKey: String, CaseIterable, Equatable, Sendable {
  case volumeUp, volumeDown, mute, brightnessUp, brightnessDown
}

/// Posts system level keys. Must fail synchronously (throw `OutputError`) when the events can't
/// be built or posted, so the registry can fall back to setting the level itself.
protocol LevelKeyOutput: AnyObject {
  /// Presses and releases `key` `count` times. `fine`: with the system's fine-step modifiers, so
  /// each press moves the level 1/64 of its range instead of 1/16.
  func press(_ key: LevelKey, count: Int, fine: Bool) throws
}

/// The built-in keyboard's backlight.
protocol KeyboardBacklightOutput: AnyObject {
  /// False when this Mac has no backlit keyboard (or its control can't be loaded).
  var isAvailable: Bool { get }
  /// Backlight level, 0...1.
  func level() throws -> Double
  func setLevel(_ level: Double) throws
}

/// macOS Dictation.
protocol DictationOutput: AnyObject {
  /// Starts Dictation, or stops it if it is listening.
  func toggle() throws
}

/// Polls a condition off the caller's thread. Used to wait for a window to leave full screen.
protocol TransitionWaiter: AnyObject, Sendable {
  /// Returns immediately. Checks `condition` every `interval` seconds on the waiter's own queue
  /// and calls `done(true)` once it holds, or `done(false)` after `timeout` seconds. `done` runs on
  /// the waiter's queue, exactly once.
  func wait(
    timeout: TimeInterval, interval: TimeInterval, until condition: @escaping @Sendable () -> Bool,
    then done: @escaping @Sendable (Bool) -> Void)
}

/// System-wide views and power commands.
enum SystemCommand: String, CaseIterable, Equatable, Sendable {
  case missionControl, appWindows, showDesktop, spaceLeft, spaceRight, lockScreen, sleepDisplay
}

/// Mission Control family, Spaces, lock and display sleep.
protocol SystemOutput: AnyObject {
  func perform(_ command: SystemCommand) throws
}

// MARK: - v0.4

/// A piece of work handed to an `ActionScheduler`.
protocol ScheduledWork: AnyObject, Sendable {
  /// Stops the work from running, if it hasn't yet. Safe to call more than once.
  func cancel()
}

/// Runs work later, off the caller's thread. Injected so tests drive time (the hold and app
/// switcher watchdogs).
protocol ActionScheduler: AnyObject, Sendable {
  /// Runs `work` once, `delay` seconds from now, on the scheduler's own queue, unless the
  /// returned handle is cancelled first.
  func schedule(after delay: TimeInterval, _ work: @escaping @Sendable () -> Void) -> ScheduledWork
}

/// What ends a lingering app switcher session (batch 20 keep-open between strokes).
enum SwitcherInterrupt: Equatable, Sendable {
  /// A mouse button went down anywhere.
  case click
  /// The pointer moved clearly (past the monitor's own threshold), so the user moved on.
  case pointerMoved
  /// Escape was pressed: the system closes its switcher; Edgy releases command without selecting.
  case escape
}

/// Listen-only input the app switcher watches while it lingers between strokes, plus how many apps
/// the switcher shows (for the wrap click). Installed only while a session lingers.
protocol SwitcherInputMonitor: AnyObject, Sendable {
  /// Starts listening; `handler` may be called on any thread, any number of times, until `stop`.
  func start(_ handler: @escaping @Sendable (SwitcherInterrupt) -> Void)
  func stop()
  /// Apps the system app switcher lists (regular apps running), or nil when unknown.
  func switcherAppCount() -> Int?
}

/// No input to watch: a lingering session ends on its timer (or the watchdog).
final class NoSwitcherInputMonitor: SwitcherInputMonitor {
  func start(_ handler: @escaping @Sendable (SwitcherInterrupt) -> Void) {}
  func stop() {}
  func switcherAppCount() -> Int? { nil }
}
