import EdgyCore

/// The starting points onboarding offers ("Pick a starting point", BRIEF § Onboarding step 3).
/// Each is a whole config whose default profile is the preset; `SettingsEditor.applyPreset(_:)`
/// takes only the default profile, adjusted by `MachineDefaults` for this Mac.
///
/// Every binding fits its zone and gesture (top and bottom edges swipe only left / right; corners
/// take taps, double-taps and long-presses). `PresetTests` validates each one against a catalog
/// shaped like the real one.
public enum Presets {
  public enum Preset: String, CaseIterable, Hashable, Sendable {
    case media, windows, minimal

    /// The preset as a config: `EdgyConfig.defaults` with this preset's default profile.
    public var config: EdgyConfig {
      switch self {
      case .media: return Presets.media
      case .windows: return Presets.windows
      case .minimal: return Presets.minimal
      }
    }
  }

  /// "Volume, brightness and music on the edges." The shipped defaults.
  public static let media = EdgyConfig.defaults

  /// "Volume and brightness, plus window moves on the bottom edge."
  public static let windows = preset([
    Binding(zone: .edge(.right), gesture: .slide, action: "audio.volume"),
    Binding(zone: .edge(.left), gesture: .slide, action: "display.brightness"),
    Binding(zone: .edge(.bottom), gesture: .swipe(.left), action: "window.leftHalf"),
    Binding(zone: .edge(.bottom), gesture: .swipe(.right), action: "window.rightHalf"),
    Binding(zone: .edge(.bottom), gesture: .longPress, action: "window.maximize"),
    Binding(zone: .edge(.bottom), gesture: .doubleTap, action: "window.center"),
    Binding(zone: .edge(.top), gesture: .doubleTap, action: "system.missionControl"),
    Binding(zone: .corner(.topLeft), gesture: .doubleTap, action: "system.showDesktop"),
    Binding(zone: .corner(.topRight), gesture: .doubleTap, action: "audio.mute"),
  ])

  /// "Just volume and brightness."
  public static let minimal = preset([
    Binding(zone: .edge(.right), gesture: .slide, action: "audio.volume"),
    Binding(zone: .edge(.left), gesture: .slide, action: "display.brightness"),
  ])

  private static func preset(_ bindings: [Binding]) -> EdgyConfig {
    var config = EdgyConfig.defaults
    config.defaultProfile = Profile(bindings: bindings)
    return config
  }
}
