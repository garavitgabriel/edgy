import Foundation

/// Stable action identifier, e.g. "audio.volume", "audio.mute", "display.brightness",
/// "mic.mute", "media.playPause", "media.next", "media.previous", "shortcut.run".
public struct ActionID: RawRepresentable, Codable, Hashable, Sendable, ExpressibleByStringLiteral {
  public var rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }
  public init(stringLiteral value: String) { self.rawValue = value }
}

/// What a gesture hands to an action.
public enum ActionInput: Sendable, Equatable {
  /// Continuous change, normalized (+1.0 = full zone length).
  case delta(Double, phase: GestureEvent.Phase)
  /// One-shot trigger.
  case trigger
}

/// Where and why the action fires.
public struct ActionContext: Sendable {
  /// Bundle ID of the frontmost app, if known.
  public var frontmostBundleID: String?
  /// Free-form parameters from the binding (e.g. Shortcut name, step size).
  public var parameters: [String: String]

  public init(frontmostBundleID: String?, parameters: [String: String]) {
    self.frontmostBundleID = frontmostBundleID
    self.parameters = parameters
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

  public init(key: String, kind: Kind, required: Bool, defaultValue: String? = nil, displayName: String) {
    self.key = key
    self.kind = kind
    self.required = required
    self.defaultValue = defaultValue
    self.displayName = displayName
  }
}

public struct ActionDescriptor: Sendable, Hashable {
  public enum Shape: String, Sendable { case continuous, trigger }
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
public protocol ActionPerforming: AnyObject {
  var available: [ActionDescriptor] { get }
  func perform(_ id: ActionID, input: ActionInput, context: ActionContext) throws
  /// Live app-settings change (HUD mode, haptics). Implementations keep their in-flight state.
  func apply(settings: AppSettings)
  /// Haptic feedback for a gesture moment (not tied to an action's own output). Implementations
  /// decide with `AppSettings.allowsHaptic(_:parameters:)` using `context.parameters`.
  func feedback(_ event: HapticEvent, context: ActionContext)
}

extension ActionPerforming {
  public func apply(settings: AppSettings) {}
  public func feedback(_ event: HapticEvent, context: ActionContext) {}
}

public enum ActionError: Error, Equatable {
  case unknownAction(ActionID)
  case wrongInputShape(ActionID)
  case unavailable(ActionID, reason: String)
  case missingParameter(ActionID, name: String)
}
