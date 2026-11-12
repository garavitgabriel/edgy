import Foundation

/// Stable action identifier, e.g. "audio.volume", "audio.mute", "display.brightness",
/// "mic.mute", "media.playPause", "media.next", "media.previous", "shortcut.run".
public struct ActionID: RawRepresentable, Codable, Hashable, Sendable, ExpressibleByStringLiteral {
  public var rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }
  public init(stringLiteral value: String) { self.rawValue = value }

  /// "Do nothing": in an app profile that inherits the default, binding a gesture to this turns
  /// that default gesture off for the app. Never performed; resolution drops it (see
  /// `EdgyConfig.profile(for:)`). Listed in the catalog so the picker can offer it.
  public static let doNothing: ActionID = "edgy.none"
}

/// What a gesture hands to an action.
public enum ActionInput: Sendable, Equatable {
  /// Continuous change, normalized (+1.0 = full zone length).
  case delta(Double, phase: GestureEvent.Phase)
  /// One-shot trigger.
  case trigger
  /// Press-and-hold: `down: true` when a long-press is recognized, `down: false` when the finger
  /// lifts (or the gesture is cancelled). Every `down: true` is followed by exactly one `down: false`.
  case press(down: Bool)
}

/// Whether an action can work on this Mac right now. The settings UI greys out unavailable
/// actions and shows `reason`; first-run defaults skip them.
public enum ActionAvailability: Sendable, Hashable {
  case available
  /// Works, with a caveat worth showing (e.g. "needs the system Mission Control shortcut").
  case limited(reason: String)
  /// Can't work on this hardware/setup (e.g. "No built-in display, and this monitor doesn't
  /// accept brightness control").
  case unavailable(reason: String)

  public var isUsable: Bool {
    if case .unavailable = self { return false }
    return true
  }
}

/// Where and why the action fires.
/// The physical side of a slide step, for actions that step in millimetres, speed up with quick
/// flicks or keep stepping at the end of the edge.
public struct SlideMotion: Hashable, Sendable {
  /// Signed travel since the previous event, in millimetres (+ = toward top/right).
  public var deltaMM: Double
  /// Device timestamp of this event, seconds.
  public var timestamp: TimeInterval
  /// -1 / +1 while resting at the low / high end of the zone, 0 otherwise (`GestureEvent.atEnd`).
  public var atEnd: Int

  public init(deltaMM: Double, timestamp: TimeInterval, atEnd: Int = 0) {
    self.deltaMM = deltaMM
    self.timestamp = timestamp
    self.atEnd = atEnd
  }
}

public struct ActionContext: Sendable {
  /// Bundle ID of the frontmost app, if known.
  public var frontmostBundleID: String?
  /// Free-form parameters from the binding (e.g. Shortcut name, step size).
  public var parameters: [String: String]
  /// For slide input: the physical motion behind the normalized delta. `nil` when unknown.
  public var motion: SlideMotion?
  /// The multitouch device the gesture came from, so haptics play on the trackpad under the
  /// finger (a Magic Trackpad beside a closed MacBook, not the built-in one). `nil` when unknown.
  public var deviceID: UInt64?

  public init(
    frontmostBundleID: String?, parameters: [String: String], motion: SlideMotion? = nil, deviceID: UInt64? = nil
  ) {
    self.frontmostBundleID = frontmostBundleID
    self.parameters = parameters
    self.motion = motion
    self.deviceID = deviceID
  }
}

/// Groups actions in the settings UI's action picker.
public enum ActionCategory: String, Codable, CaseIterable, Sendable {
  case sound, display, media, system, windows, apps, keyboard, shortcuts
}

/// One value an action reads from `Binding.parameters`. The settings layer uses these to build
/// the right control and to validate a binding before it is saved.
public struct ActionParameter: Sendable, Hashable {
  public enum Kind: Sendable, Hashable {
    /// Free text (e.g. a Shortcut name).
    case text
    /// A key combination in `KeyCombo` string form, e.g. `"cmd+shift+4"`.
    case keyCombo
    /// An application bundle identifier, e.g. `"com.apple.Safari"`.
    case appBundleID
    /// An absolute URL with a scheme (`https:`, `mailto:`, an app scheme...).
    case url
    /// An absolute file or folder path; `~` is expanded by the action.
    case filePath
    /// A decimal number within `range`.
    case number(ClosedRange<Double>)
    /// One of a fixed set of raw values.
    case choice([String])
  }

  /// Key in `Binding.parameters`.
  public var key: String
  public var kind: Kind
  public var required: Bool
  /// Used when the parameter is absent; `nil` for required parameters.
  public var defaultValue: String?
  /// Label for the settings UI.
  public var displayName: String
  /// One helper line under the row (BRIEF § Binding parameters: tuning rows only). `nil` = none.
  public var helpText: String?
  /// Unit shown after a number's value ("mm", "ms"). `nil` = none.
  public var unit: String?
  /// What a number reads as at 0 (e.g. "Off"). `nil` = the number.
  public var zeroLabel: String?
  /// When the parameter is absent, the value comes from this app-wide setting instead of
  /// `defaultValue` (e.g. a hold time that falls back to `GestureSettings.longPressMS`); the UI
  /// shows "Default (<that value>)" and a Reset once changed.
  public var fallback: Fallback?

  public enum Fallback: String, Sendable, Hashable {
    case longPressMS
  }

  public init(
    key: String, kind: Kind, required: Bool, defaultValue: String? = nil, displayName: String,
    helpText: String? = nil, unit: String? = nil, zeroLabel: String? = nil, fallback: Fallback? = nil
  ) {
    self.key = key
    self.kind = kind
    self.required = required
    self.defaultValue = defaultValue
    self.displayName = displayName
    self.helpText = helpText
    self.unit = unit
    self.zeroLabel = zeroLabel
    self.fallback = fallback
  }
}

public struct ActionDescriptor: Sendable, Hashable {
  /// `continuous` ↔ `.slide`; `hold` ↔ `.longPress` only; `trigger` ↔ every non-slide gesture.
  public enum Shape: String, Sendable { case continuous, trigger, hold }
  public var id: ActionID
  public var shape: Shape
  /// Human-readable name for the settings UI.
  public var displayName: String
  public var category: ActionCategory
  /// Parameters this action reads, besides the cross-cutting ones (`haptics`, and `sensitivity`
  /// on continuous actions) that the settings layer offers for every binding.
  public var parameters: [ActionParameter]

  public init(
    id: ActionID, shape: Shape, displayName: String, category: ActionCategory = .system,
    parameters: [ActionParameter] = []
  ) {
    self.id = id
    self.shape = shape
    self.displayName = displayName
    self.category = category
    self.parameters = parameters
  }
}

/// The action registry. Implemented by the Actions module.
/// What an action did, for Test Mode's plate and Edgy's own level plate ("Volume 64%",
/// "Brightness 40%" + "Desk 34", "Holding fn"). Every field is optional; `nil` = nothing to show.
public struct ActionOutcome: Hashable, Sendable {
  /// The level after the action, 0...1 (volume, brightness, backlight).
  public var level: Double?
  /// Short qualifier: the display or device changed, the key held ("fn").
  public var detail: String?
  /// The system drew its own HUD for this change; Edgy must not draw a level plate for it.
  public var systemHUDShown: Bool

  public init(level: Double? = nil, detail: String? = nil, systemHUDShown: Bool = false) {
    self.level = level
    self.detail = detail
    self.systemHUDShown = systemHUDShown
  }
}

public protocol ActionPerforming: AnyObject {
  var available: [ActionDescriptor] { get }
  func perform(_ id: ActionID, input: ActionInput, context: ActionContext) throws
  /// `perform`, reporting what happened. The default calls `perform` and reports nothing; level
  /// and hold actions override it. Callers that want an outcome call this instead of `perform`.
  func performReporting(_ id: ActionID, input: ActionInput, context: ActionContext) throws -> ActionOutcome?
  /// Live app-settings change (HUD mode, haptics). Implementations keep their in-flight state.
  func apply(settings: AppSettings)
  /// Haptic feedback for a gesture moment (not tied to an action's own output). Implementations
  /// decide with `AppSettings.allowsHaptic(_:parameters:)` using `context.parameters`.
  func feedback(_ event: HapticEvent, context: ActionContext)
  /// Whether `id` can work on this Mac (hardware, attached displays, keyboard). Cheap enough to
  /// call when building settings UI or first-run defaults; implementations may cache.
  func availability(of id: ActionID) -> ActionAvailability
}

extension ActionPerforming {
  public func performReporting(_ id: ActionID, input: ActionInput, context: ActionContext) throws
    -> ActionOutcome?
  {
    try perform(id, input: input, context: context)
    return nil
  }

  public func apply(settings: AppSettings) {}
  public func feedback(_ event: HapticEvent, context: ActionContext) {}
  public func availability(of id: ActionID) -> ActionAvailability { .available }
}

public enum ActionError: Error, Equatable {
  case unknownAction(ActionID)
  case wrongInputShape(ActionID)
  case unavailable(ActionID, reason: String)
  case missingParameter(ActionID, name: String)
}
