import Foundation

/// A region of the trackpad that can be mapped to actions.
public enum Zone: Codable, Hashable, Sendable {
  public enum Edge: String, Codable, CaseIterable, Sendable { case left, right, top, bottom }
  public enum Corner: String, Codable, CaseIterable, Sendable { case topLeft, topRight, bottomLeft, bottomRight }

  /// An edge strip, optionally split into equal segments. `segment` is 0-based along the edge
  /// (bottom→top for left/right, left→right for top/bottom); `segments == 1` means the whole edge.
  case edge(Edge, segment: Int = 0, segments: Int = 1)
  case corner(Corner)
}

public enum SwipeDirection: String, Codable, Sendable { case up, down, left, right }

public enum GestureKind: Codable, Hashable, Sendable {
  /// Continuous movement along the edge axis.
  case slide
  /// Discrete flick along the edge axis.
  case swipe(SwipeDirection)
  case tap
  case doubleTap
  case longPress
}

/// A recognized gesture, emitted by the Gestures module.
public struct GestureEvent: Codable, Hashable, Sendable {
  public enum Phase: String, Codable, Sendable { case began, changed, ended, cancelled }

  public var zone: Zone
  public var kind: GestureKind
  public var fingers: Int
  public var phase: Phase
  /// For `.slide`: signed movement since the previous event, normalized to the zone length
  /// (+1.0 = full zone length toward top/right). Zero for discrete gestures.
  public var delta: Double
  /// Position along the zone axis, 0...1.
  public var position: Double
  public var timestamp: TimeInterval
  public var deviceID: UInt64

  public init(
    zone: Zone, kind: GestureKind, fingers: Int, phase: Phase, delta: Double,
    position: Double, timestamp: TimeInterval, deviceID: UInt64
  ) {
    self.zone = zone
    self.kind = kind
    self.fingers = fingers
    self.phase = phase
    self.delta = delta
    self.position = position
    self.timestamp = timestamp
    self.deviceID = deviceID
  }
}

/// Why a touch was not turned into a gesture. Surfaced in test mode / diagnostics.
public enum RejectionReason: String, Codable, Sendable {
  case startedOutsideZone, palm, tooManyContacts, typing, offAxisMotion, tooFast, systemGestureHandoff, disabledZone
}

/// Output of one pipeline step.
public struct GestureOutput: Sendable {
  public var events: [GestureEvent]
  /// Contacts currently claimed by a gesture (pointer guard should be engaged while non-empty).
  public var claimedContactIDs: Set<Int32>
  public var rejections: [(contactID: Int32, reason: RejectionReason)]

  public init(
    events: [GestureEvent] = [], claimedContactIDs: Set<Int32> = [],
    rejections: [(contactID: Int32, reason: RejectionReason)] = []
  ) {
    self.events = events
    self.claimedContactIDs = claimedContactIDs
    self.rejections = rejections
  }
}

/// The gesture pipeline. Pure: same frames + settings → same output. No system calls.
public protocol GestureRecognizing: AnyObject {
  func process(_ frame: TouchFrame, device: TouchDeviceInfo, context: GestureContext) -> GestureOutput
  func reset()
}

/// Inputs the pipeline needs besides frames.
public struct GestureContext: Sendable {
  public var settings: GestureSettings
  /// Zones the active profile actually maps (unmapped zones never claim touches).
  public var enabledZones: Set<Zone>
  public var secondsSinceLastKeyPress: TimeInterval?
  /// Zones with a slide bound. A zone outside this set never becomes a slide: a resting finger
  /// doesn't claim the pointer, and along-axis motion is a swipe at any speed. `nil` = every
  /// enabled zone may slide.
  public var slideZones: Set<Zone>?
  /// Zones with a long-press bound. Elsewhere a resting finger never fires (or claims as) a
  /// long-press. `nil` = every enabled zone may long-press.
  public var longPressZones: Set<Zone>?

  public init(
    settings: GestureSettings, enabledZones: Set<Zone>, secondsSinceLastKeyPress: TimeInterval?,
    slideZones: Set<Zone>? = nil, longPressZones: Set<Zone>? = nil
  ) {
    self.settings = settings
    self.enabledZones = enabledZones
    self.secondsSinceLastKeyPress = secondsSinceLastKeyPress
    self.slideZones = slideZones
    self.longPressZones = longPressZones
  }
}
