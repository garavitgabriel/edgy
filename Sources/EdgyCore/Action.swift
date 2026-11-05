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

public struct ActionDescriptor: Sendable, Hashable {
  public enum Shape: String, Sendable { case continuous, trigger }
  public var id: ActionID
  public var shape: Shape
  /// Human-readable name for the settings UI.
  public var displayName: String

  public init(id: ActionID, shape: Shape, displayName: String) {
    self.id = id
    self.shape = shape
    self.displayName = displayName
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
