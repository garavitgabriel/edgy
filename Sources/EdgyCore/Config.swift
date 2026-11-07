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
    edgeWidthMM: 8, cornerSizeMM: 10, dwellMS: 120, palmMajorAxisMM: 18,
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
  /// App profiles only. `true`: this profile is a set of overrides on top of the default profile —
  /// a binding here replaces the default binding on the same zone + gesture, and a binding to
  /// `ActionID.doNothing` turns that default gesture off for this app. `false` (older configs): the
  /// profile replaces the default profile entirely. Ignored on the default profile.
  public var inheritsDefault: Bool

  public init(bindings: [Binding], disabled: Bool = false, inheritsDefault: Bool = false) {
    self.bindings = bindings
    self.disabled = disabled
    self.inheritsDefault = inheritsDefault
  }

  private enum CodingKeys: String, CodingKey { case bindings, disabled, inheritsDefault }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    bindings = try c.decode([Binding].self, forKey: .bindings)
    disabled = try c.decode(Bool.self, forKey: .disabled)
    inheritsDefault = try c.decodeIfPresent(Bool.self, forKey: .inheritsDefault) ?? false
  }
}

public enum HUDMode: String, Codable, Sendable { case native, none }

/// Moments that can produce trackpad haptic feedback. Users pick which ones they want.
public enum HapticEvent: String, Codable, CaseIterable, Hashable, Sendable {
  /// Light tick on every 1/16 step while sliding a level (volume, brightness).
  case slideSteps
  /// Stronger tick when a level reaches 0 or 1.
  case slideLimits
  /// Light tick the moment Edgy takes hold of a slide ("got it").
  case gestureCaught
  /// Click when a discrete gesture (tap, double-tap, swipe, long-press) runs its action.
  case actionFired
}

public struct AppSettings: Codable, Hashable, Sendable {
  public var enabled: Bool
  public var showMenuBarIcon: Bool
  public var hud: HUDMode
  /// Master haptics switch. Off silences every haptic regardless of `hapticEvents`.
  public var haptics: Bool
  /// Which haptic moments are on (when `haptics` is on). Missing from older config files → all.
  public var hapticEvents: Set<HapticEvent>
  /// Strength of light ticks (slide steps, gesture caught), `hapticStrengthRange`. A slider in UI. Default 6: on hardware, lower steps were not felt on a finger moving along an edge.
  public var hapticTickStrength: Int
  /// Strength of clicks (slide limits, action fired), `hapticStrengthRange`.
  public var hapticClickStrength: Int
  public var launchAtLogin: Bool

  /// Trackpad haptics come in fixed steps; this is the user-facing scale (1 = lightest).
  public static let hapticStrengthRange = 1...6

  /// Per-binding override key in `Binding.parameters`: `"off"` silences that binding's haptics.
  public static let hapticsParameter = "haptics"

  public static let defaults = AppSettings(
    enabled: true, showMenuBarIcon: true, hud: .native, haptics: true, launchAtLogin: false)

  public init(
    enabled: Bool, showMenuBarIcon: Bool, hud: HUDMode, haptics: Bool,
    hapticEvents: Set<HapticEvent> = Set(HapticEvent.allCases), hapticTickStrength: Int = 6,
    hapticClickStrength: Int = 6, launchAtLogin: Bool
  ) {
    self.enabled = enabled
    self.showMenuBarIcon = showMenuBarIcon
    self.hud = hud
    self.haptics = haptics
    self.hapticEvents = hapticEvents
    self.hapticTickStrength = Self.clampStrength(hapticTickStrength)
    self.hapticClickStrength = Self.clampStrength(hapticClickStrength)
    self.launchAtLogin = launchAtLogin
  }

  public static func clampStrength(_ value: Int) -> Int {
    min(max(value, hapticStrengthRange.lowerBound), hapticStrengthRange.upperBound)
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    enabled = try c.decode(Bool.self, forKey: .enabled)
    showMenuBarIcon = try c.decode(Bool.self, forKey: .showMenuBarIcon)
    hud = try c.decode(HUDMode.self, forKey: .hud)
    haptics = try c.decode(Bool.self, forKey: .haptics)
    hapticEvents = try c.decodeIfPresent(Set<HapticEvent>.self, forKey: .hapticEvents) ?? Set(HapticEvent.allCases)
    hapticTickStrength = Self.clampStrength(try c.decodeIfPresent(Int.self, forKey: .hapticTickStrength) ?? 6)
    hapticClickStrength = Self.clampStrength(try c.decodeIfPresent(Int.self, forKey: .hapticClickStrength) ?? 6)
    launchAtLogin = try c.decode(Bool.self, forKey: .launchAtLogin)
  }

  /// Whether `event` should produce haptics for a binding with these parameters.
  public func allowsHaptic(_ event: HapticEvent, parameters: [String: String] = [:]) -> Bool {
    haptics && hapticEvents.contains(event) && parameters[Self.hapticsParameter] != "off"
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

  /// The profile in effect for a frontmost app, resolved: an inheriting app profile is merged over
  /// the default profile (same zone + gesture → the app's binding wins, default order kept, the
  /// app's extra bindings appended), and `ActionID.doNothing` bindings are dropped so the zone stays
  /// free. The result never inherits.
  public func profile(for bundleID: String?) -> Profile {
    guard let bundleID, let app = appProfiles[bundleID] else { return Self.resolved(defaultProfile) }
    guard app.inheritsDefault else { return Self.resolved(app) }
    var merged: [Binding] = []
    var used = Set<Int>()
    for base in defaultProfile.bindings {
      if let index = app.bindings.firstIndex(where: { $0.zone == base.zone && $0.gesture == base.gesture }) {
        if used.insert(index).inserted { merged.append(app.bindings[index]) }
      } else {
        merged.append(base)
      }
    }
    merged += app.bindings.indices.filter { !used.contains($0) }.map { app.bindings[$0] }
    return Self.resolved(Profile(bindings: merged, disabled: app.disabled))
  }

  private static func resolved(_ profile: Profile) -> Profile {
    Profile(bindings: profile.bindings.filter { $0.action != .doNothing }, disabled: profile.disabled)
  }
}
