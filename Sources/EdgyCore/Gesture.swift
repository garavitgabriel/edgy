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

extension Zone {
  /// Whether this zone can produce `gesture`. Corners are too small to slide or swipe in;
  /// edges swipe only along their own axis (left/right edges: up/down; top/bottom: left/right).
  public func supports(_ gesture: GestureKind) -> Bool {
    switch (self, gesture) {
    case (.corner, .tap), (.corner, .doubleTap), (.corner, .longPress): return true
    case (.corner, _): return false
    case (.edge, .slide), (.edge, .tap), (.edge, .doubleTap), (.edge, .longPress): return true
    case (.edge(let edge, _, _), .swipe(let direction)):
      switch edge {
      case .left, .right: return direction == .up || direction == .down
      case .top, .bottom: return direction == .left || direction == .right
      }
    }
  }
}

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
///
/// Phases per kind: `.slide` → began / changed… / ended (or cancelled). `.longPress` → `.began`
/// the moment the hold is recognized, then `.ended` when the finger lifts (`.cancelled` if the
/// touch is taken away, e.g. by a palm or extra fingers). Tap, double-tap and swipe → one `.ended`.
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
  /// The zone's length along its axis in millimetres (`delta * zoneLengthMM` = travel in mm), so
  /// actions can step in physical distance and read speed. 0 when unknown.
  public var zoneLengthMM: Double
  /// For `.slide`: -1 / +1 while the finger rests at the low / high end of the zone (bottom/left,
  /// top/right), 0 otherwise. Lets stepped actions keep stepping at the end of the edge.
  public var atEnd: Int

  public init(
    zone: Zone, kind: GestureKind, fingers: Int, phase: Phase, delta: Double,
    position: Double, timestamp: TimeInterval, deviceID: UInt64, zoneLengthMM: Double = 0, atEnd: Int = 0
  ) {
    self.zone = zone
    self.kind = kind
    self.fingers = fingers
    self.phase = phase
    self.delta = delta
    self.position = position
    self.timestamp = timestamp
    self.deviceID = deviceID
    self.zoneLengthMM = zoneLengthMM
    self.atEnd = atEnd
  }

  private enum CodingKeys: String, CodingKey {
    case zone, kind, fingers, phase, delta, position, timestamp, deviceID, zoneLengthMM, atEnd
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    zone = try c.decode(Zone.self, forKey: .zone)
    kind = try c.decode(GestureKind.self, forKey: .kind)
    fingers = try c.decode(Int.self, forKey: .fingers)
    phase = try c.decode(Phase.self, forKey: .phase)
    delta = try c.decode(Double.self, forKey: .delta)
    position = try c.decode(Double.self, forKey: .position)
    timestamp = try c.decode(TimeInterval.self, forKey: .timestamp)
    deviceID = try c.decode(UInt64.self, forKey: .deviceID)
    zoneLengthMM = try c.decodeIfPresent(Double.self, forKey: .zoneLengthMM) ?? 0
    atEnd = try c.decodeIfPresent(Int.self, forKey: .atEnd) ?? 0
  }
}

/// Why a touch was not turned into a gesture. Surfaced in test mode / diagnostics.
public enum RejectionReason: String, Codable, Sendable {
  case startedOutsideZone, palm, tooManyContacts, typing, offAxisMotion, tooFast, systemGestureHandoff, disabledZone
  /// The physical button went down while the touch was a candidate or a claim (click, drag, select).
  case physicalClick
}

/// The number behind a rejection, for Test Mode's plate: "Ignored: palm, 21 mm wide, limit 18 mm".
/// `measured` is what the touch did, `limit` the setting or threshold it crossed, both in `unit`.
public struct RejectionMeasure: Hashable, Sendable {
  public enum Unit: String, Hashable, Sendable {
    /// Millimetres (palm width, travel, distance from the edge).
    case mm
    /// Milliseconds (time since the last key, hold or dwell time).
    case ms
    /// Contact count (`measured` fingers against the `limit` the binding uses).
    case fingers
    /// Millimetres per second (initial speed).
    case mmPerSecond
  }

  public var measured: Double
  public var limit: Double
  public var unit: Unit

  public init(measured: Double, limit: Double, unit: Unit) {
    self.measured = measured
    self.limit = limit
    self.unit = unit
  }
}

/// Output of one pipeline step.
public struct GestureOutput: Sendable {
  public var events: [GestureEvent]
  /// Contacts currently claimed by a gesture (pointer guard should be engaged while non-empty).
  public var claimedContactIDs: Set<Int32>
  public var rejections: [(contactID: Int32, reason: RejectionReason)]
  /// The measurement behind a rejection in `rejections`, keyed by contact id, when one means
  /// something (none for a click or a system-gesture handoff).
  public var rejectionMeasures: [Int32: RejectionMeasure]
  /// Zones where a contact lifted this step as an accepted tap: a `.tap` emitted now, a first tap
  /// held back for the double-tap window, or the second tap of a `.doubleTap`. Empty for rejected
  /// lifts and for output from a flush (a held tap released later is not a new lift). The runtime
  /// uses it to expect the system's tap-to-click click (`PointerGuarding.expectTapClick`).
  public var tapLifts: [Zone]

  public init(
    events: [GestureEvent] = [], claimedContactIDs: Set<Int32> = [],
    rejections: [(contactID: Int32, reason: RejectionReason)] = [],
    rejectionMeasures: [Int32: RejectionMeasure] = [:], tapLifts: [Zone] = []
  ) {
    self.events = events
    self.claimedContactIDs = claimedContactIDs
    self.rejections = rejections
    self.rejectionMeasures = rejectionMeasures
    self.tapLifts = tapLifts
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
  /// Zones with a double-tap bound. In a zone that also has a tap bound, a single tap is held
  /// until the double-tap window passes, so the first tap of a double-tap never fires the tap
  /// action. Elsewhere a tap fires at once. `nil` = no zone waits.
  public var doubleTapZones: Set<Zone>?
  /// Per-zone long-press time in milliseconds, overriding `settings.longPressMS` for that zone
  /// (e.g. 300 ms for a push-to-talk hold). `nil` / missing zone = the global setting.
  public var longPressMSByZone: [Zone: Double]?

  public init(
    settings: GestureSettings, enabledZones: Set<Zone>, secondsSinceLastKeyPress: TimeInterval?,
    slideZones: Set<Zone>? = nil, longPressZones: Set<Zone>? = nil, doubleTapZones: Set<Zone>? = nil,
    longPressMSByZone: [Zone: Double]? = nil
  ) {
    self.settings = settings
    self.enabledZones = enabledZones
    self.secondsSinceLastKeyPress = secondsSinceLastKeyPress
    self.slideZones = slideZones
    self.longPressZones = longPressZones
    self.doubleTapZones = doubleTapZones
    self.longPressMSByZone = longPressMSByZone
  }
}
