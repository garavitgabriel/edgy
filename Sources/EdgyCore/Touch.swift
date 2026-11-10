import Foundation

/// A multitouch-capable input device (built-in trackpad, Magic Trackpad, Magic Mouse).
public struct TouchDeviceInfo: Codable, Hashable, Sendable {
  public enum Kind: String, Codable, Sendable { case builtInTrackpad, externalTrackpad, mouse, unknown }

  /// Stable identifier for the current session (not guaranteed across reboots).
  public var id: UInt64
  public var kind: Kind
  /// Physical sensor surface size in millimetres. All gesture geometry is computed in mm.
  public var sensorSizeMM: Size2D
  /// Raw family ID reported by the device, kept for diagnostics.
  public var familyID: Int32

  public init(id: UInt64, kind: Kind, sensorSizeMM: Size2D, familyID: Int32) {
    self.id = id
    self.kind = kind
    self.sensorSizeMM = sensorSizeMM
    self.familyID = familyID
  }
}

/// One finger (or palm) contact within a frame.
public struct TouchContact: Codable, Hashable, Sendable {
  public enum State: String, Codable, Sendable { case starting, hovering, touching, lifting, leaving, unknown }

  /// Per-finger identifier, stable while the contact lives.
  public var id: Int32
  public var state: State
  /// Normalized position, origin bottom-left, 0...1 on both axes.
  public var position: Point2D
  /// Normalized velocity per second.
  public var velocity: Vector2D
  /// Contact ellipse axes in millimetres (major >= minor). Large axes suggest a palm.
  public var majorAxisMM: Double
  public var minorAxisMM: Double
  /// Ellipse angle in radians.
  public var angle: Double
  /// Device-reported contact size / pressure proxy (unitless).
  public var size: Double
  /// Device-reported contact density (unitless).
  public var density: Double

  public init(
    id: Int32, state: State, position: Point2D, velocity: Vector2D,
    majorAxisMM: Double, minorAxisMM: Double, angle: Double, size: Double, density: Double
  ) {
    self.id = id
    self.state = state
    self.position = position
    self.velocity = velocity
    self.majorAxisMM = majorAxisMM
    self.minorAxisMM = minorAxisMM
    self.angle = angle
    self.size = size
    self.density = density
  }
}

/// All contacts on one device at one instant.
public struct TouchFrame: Codable, Hashable, Sendable {
  public var deviceID: UInt64
  /// Seconds, monotonic, from the device callback.
  public var timestamp: TimeInterval
  public var frameNumber: Int32
  public var contacts: [TouchContact]
  /// The device's physical button (or force click) is down during this frame. A touch that clicks
  /// is the user pressing, dragging or selecting, never an edge gesture. Absent in older traces →
  /// `false`.
  public var buttonDown: Bool

  public init(
    deviceID: UInt64, timestamp: TimeInterval, frameNumber: Int32, contacts: [TouchContact],
    buttonDown: Bool = false
  ) {
    self.deviceID = deviceID
    self.timestamp = timestamp
    self.frameNumber = frameNumber
    self.contacts = contacts
    self.buttonDown = buttonDown
  }

  private enum CodingKeys: String, CodingKey { case deviceID, timestamp, frameNumber, contacts, buttonDown }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    deviceID = try c.decode(UInt64.self, forKey: .deviceID)
    timestamp = try c.decode(TimeInterval.self, forKey: .timestamp)
    frameNumber = try c.decode(Int32.self, forKey: .frameNumber)
    contacts = try c.decode([TouchContact].self, forKey: .contacts)
    buttonDown = try c.decodeIfPresent(Bool.self, forKey: .buttonDown) ?? false
  }
}

/// Source of touch frames. Implemented by TouchKit (live) and by test/trace players.
public protocol TouchSource: AnyObject, Sendable {
  /// Currently connected devices.
  var devices: [TouchDeviceInfo] { get }
  /// Begin delivering frames. Must survive device connect/disconnect and sleep/wake.
  func start(
    onFrame: @escaping @Sendable (TouchFrame) -> Void,
    onDevicesChanged: @escaping @Sendable ([TouchDeviceInfo]) -> Void) throws
  func stop()
}

/// Typing activity signal used to suppress edge gestures while the user types.
public protocol TypingActivitySource: AnyObject, Sendable {
  /// Seconds since the last key press, or nil if unknown.
  var secondsSinceLastKeyPress: TimeInterval? { get }
}

/// Keeps the on-screen pointer still while a gesture owns a finger. Implemented in TouchKit.
public protocol PointerGuarding: AnyObject, Sendable {
  /// Called when a gesture claims a contact: stop pointer movement from that finger.
  func engage()
  /// Called when the gesture ends or is cancelled: restore normal pointer movement.
  func release()
  /// Called when a finger lifts from a mapped zone as a tap that a tap or double-tap binding may
  /// take. With tap-to-click on, the system reports that tap as a click shortly after the lift,
  /// and the click lands on whatever is under the pointer (it can pull focus back from the app a
  /// gesture just opened). The guard swallows that one click (a button-down and its button-up)
  /// if it arrives within `seconds`. A physical press is never swallowed.
  func expectTapClick(within seconds: TimeInterval)
}

extension PointerGuarding {
  /// Guards that don't watch clicks ignore it.
  public func expectTapClick(within seconds: TimeInterval) {}
}
