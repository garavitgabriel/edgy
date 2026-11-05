import EdgyCore

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
  func tick()
  func strongTick()
}

/// Runs a user Shortcut. Must return immediately; the work happens off the caller's thread.
protocol ShortcutRunner: AnyObject {
  func run(name: String)
}
