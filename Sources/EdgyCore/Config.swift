import Foundation

/// Tunables for the gesture pipeline. Units are millimetres and milliseconds.
public struct GestureSettings: Codable, Hashable, Sendable {
  /// Width of each edge strip, measured inward from the physical edge.
  public var edgeWidthMM: Double
  /// Side length of each corner square.
  public var cornerSizeMM: Double
  /// Touch must rest (or move along-axis) this long before a slide is claimed.
  public var dwellMS: Double
  /// Contacts whose major axis exceeds this are treated as palms.
  public var palmMajorAxisMM: Double
  /// Edge gestures are ignored for this long after a key press.
  public var typingSuppressionMS: Double
  /// Max interval between taps for a double-tap.
  public var doubleTapWindowMS: Double
  /// Hold time for a long-press.
  public var longPressMS: Double
  /// Fingers a slide uses (1 or 2).
  public var fingers: Int

  public static let defaults = GestureSettings(
    edgeWidthMM: 8, cornerSizeMM: 12, dwellMS: 120, palmMajorAxisMM: 18,
    typingSuppressionMS: 500, doubleTapWindowMS: 300, longPressMS: 500, fingers: 1)

  public init(
    edgeWidthMM: Double, cornerSizeMM: Double, dwellMS: Double, palmMajorAxisMM: Double,
    typingSuppressionMS: Double, doubleTapWindowMS: Double, longPressMS: Double, fingers: Int
  ) {
    self.edgeWidthMM = edgeWidthMM
    self.cornerSizeMM = cornerSizeMM
    self.dwellMS = dwellMS
    self.palmMajorAxisMM = palmMajorAxisMM
    self.typingSuppressionMS = typingSuppressionMS
    self.doubleTapWindowMS = doubleTapWindowMS
    self.longPressMS = longPressMS
    self.fingers = fingers
  }
}

/// One zone + gesture → action mapping.
public struct Binding: Codable, Hashable, Sendable {
  public var zone: Zone
  public var gesture: GestureKind
  public var action: ActionID
  public var parameters: [String: String]

  public init(zone: Zone, gesture: GestureKind, action: ActionID, parameters: [String: String] = [:]) {
    self.zone = zone
    self.gesture = gesture
    self.action = action
    self.parameters = parameters
  }
}

public struct Profile: Codable, Hashable, Sendable {
  public var bindings: [Binding]
  /// When true, Edgy ignores all gestures while this profile's app is frontmost.
  public var disabled: Bool

  public init(bindings: [Binding], disabled: Bool = false) {
    self.bindings = bindings
    self.disabled = disabled
  }
}

public enum HUDMode: String, Codable, Sendable { case native, none }

public struct AppSettings: Codable, Hashable, Sendable {
  public var enabled: Bool
  public var showMenuBarIcon: Bool
  public var hud: HUDMode
  public var haptics: Bool
  public var launchAtLogin: Bool

  public static let defaults = AppSettings(
    enabled: true, showMenuBarIcon: true, hud: .native, haptics: true, launchAtLogin: false)

  public init(enabled: Bool, showMenuBarIcon: Bool, hud: HUDMode, haptics: Bool, launchAtLogin: Bool) {
    self.enabled = enabled
    self.showMenuBarIcon = showMenuBarIcon
    self.hud = hud
    self.haptics = haptics
    self.launchAtLogin = launchAtLogin
  }
}

/// The whole user configuration, persisted as JSON.
public struct EdgyConfig: Codable, Hashable, Sendable {
  public static let currentSchemaVersion = 1

  public var schemaVersion: Int
  public var app: AppSettings
  public var gestures: GestureSettings
  /// Applies when no per-app profile matches.
  public var defaultProfile: Profile
  /// Keyed by bundle identifier. A matching profile replaces the default profile.
  public var appProfiles: [String: Profile]

  public init(
    schemaVersion: Int = EdgyConfig.currentSchemaVersion, app: AppSettings, gestures: GestureSettings,
    defaultProfile: Profile, appProfiles: [String: Profile]
  ) {
    self.schemaVersion = schemaVersion
    self.app = app
    self.gestures = gestures
    self.defaultProfile = defaultProfile
    self.appProfiles = appProfiles
  }

  /// The out-of-the-box preset.
  public static let defaults = EdgyConfig(
    app: .defaults,
    gestures: .defaults,
    defaultProfile: Profile(bindings: [
      Binding(zone: .edge(.right), gesture: .slide, action: "audio.volume"),
      Binding(zone: .edge(.left), gesture: .slide, action: "display.brightness"),
      Binding(zone: .edge(.bottom), gesture: .swipe(.left), action: "media.previous"),
      Binding(zone: .edge(.bottom), gesture: .swipe(.right), action: "media.next"),
      Binding(zone: .edge(.bottom), gesture: .doubleTap, action: "media.playPause"),
      Binding(zone: .corner(.topRight), gesture: .doubleTap, action: "audio.mute"),
      Binding(zone: .corner(.topLeft), gesture: .doubleTap, action: "mic.mute"),
    ]),
    appProfiles: [:])

  /// The profile in effect for a frontmost app.
  public func profile(for bundleID: String?) -> Profile {
    if let bundleID, let p = appProfiles[bundleID] { return p }
    return defaultProfile
  }
}
