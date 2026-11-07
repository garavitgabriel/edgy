import EdgyCore
import Foundation

/// One finger on the mini trackpad mirror.
public struct LiveTouch: Hashable, Sendable {
  public enum State: String, Hashable, Sendable {
    /// On the pad, not (yet) a gesture: ordinary pointer use, or a candidate still being judged.
    case down
    /// Owned by a gesture right now (the pointer is held still).
    case claimed
    /// Turned down as a gesture (palm, typing, off-axis…); stays `rejected` until the finger lifts.
    case rejected
  }

  /// Contact id, stable while the finger stays down.
  public var id: Int32
  /// Normalized position, origin bottom-left, 0...1 on both axes.
  public var position: Point2D
  public var state: State

  public init(id: Int32, position: Point2D, state: State) {
    self.id = id
    self.position = position
    self.state = state
  }
}

/// Every finger on one device at one instant, for the mirror.
public struct LiveTouchFrame: Hashable, Sendable {
  public var deviceID: UInt64
  /// Device timestamp in seconds (`TouchFrame.timestamp`).
  public var timestamp: TimeInterval
  /// Empty when the last finger lifted (sent once, so the mirror clears).
  public var touches: [LiveTouch]

  public init(deviceID: UInt64, timestamp: TimeInterval, touches: [LiveTouch]) {
    self.deviceID = deviceID
    self.timestamp = timestamp
    self.touches = touches
  }
}

/// What the engine decided, for Test Mode's "recognized / rejected" list.
public enum LiveDecision: Hashable, Sendable {
  /// The recognizer produced a gesture. Every phase but a slide's `.changed` (those come at frame
  /// rate; the mirror shows the motion).
  case recognized(zone: Zone, kind: GestureKind, phase: GestureEvent.Phase, deviceID: UInt64)
  /// A touch was turned down as a gesture. `zone` is the mapped zone it landed in, when one did.
  /// Ordinary pointer touches (`startedOutsideZone`) are not reported.
  case rejected(contactID: Int32, zone: Zone?, reason: RejectionReason, deviceID: UInt64)
  /// The bound action ran (a discrete gesture, a hold's press, or a slide's first step).
  case actionRan(ActionID, zone: Zone, kind: GestureKind)
  /// The action threw; `message` is the error, for diagnostics.
  case actionFailed(ActionID, zone: Zone, kind: GestureKind, message: String)
  /// The action can't work on this Mac right now (`ActionError.unavailable`).
  case actionUnavailable(ActionID, zone: Zone, kind: GestureKind, reason: String)
  /// Test Mode: the action would have run here; nothing was performed.
  case wouldRun(ActionID, zone: Zone, kind: GestureKind)
}

/// One delivery to a feed observer: at most one frame of touches per device (throttled to
/// `Engine.feedTouchInterval`) and every decision since the last delivery (never throttled).
public struct LiveFeedUpdate: Hashable, Sendable {
  public var touches: LiveTouchFrame?
  public var decisions: [LiveDecision]

  public init(touches: LiveTouchFrame?, decisions: [LiveDecision]) {
    self.touches = touches
    self.decisions = decisions
  }
}

/// Engine-side state behind the feed; exists only while someone observes. Queue-confined to the
/// engine queue.
struct LiveFeedState {
  struct ContactKey: Hashable {
    var deviceID: UInt64
    var id: Int32
  }

  var observers: [UUID: (queue: DispatchQueue, handler: @Sendable (LiveFeedUpdate) -> Void)] = [:]
  var decisions: [LiveDecision] = []
  var rejected: Set<ContactKey> = []
  var landing: [ContactKey: Point2D] = [:]
  /// Per device: timestamp of the last touch frame sent, and whether it had touches.
  var lastSent: [UInt64: (timestamp: TimeInterval, hadTouches: Bool)] = [:]

  var isActive: Bool { !observers.isEmpty }

  mutating func clearTracking() {
    decisions.removeAll()
    rejected.removeAll()
    landing.removeAll()
    lastSent.removeAll()
  }

  static func isOnPad(_ contact: TouchContact) -> Bool {
    switch contact.state {
    case .starting, .touching, .lifting: return true
    case .hovering, .leaving, .unknown: return false
    }
  }

  /// The mapped zone containing `point` (normalized), using the same geometry the settings
  /// describe: corner squares of `cornerSizeMM` win over edge strips `edgeWidthMM` deep, edge
  /// segments split along the edge (bottom→top, left→right). `nil` when no enabled zone contains it.
  static func zone(
    at point: Point2D, device: TouchDeviceInfo, settings: GestureSettings, enabled: Set<Zone>
  ) -> Zone? {
    let width = device.sensorSizeMM.width
    let height = device.sensorSizeMM.height
    guard width > 0, height > 0 else { return nil }
    let x = point.x * width
    let y = point.y * height
    let corner = settings.cornerSizeMM
    let left = x < corner
    let right = width - x < corner
    let bottom = y < corner
    let top = height - y < corner
    let cornerHit: Zone.Corner? =
      top && left
      ? .topLeft : top && right ? .topRight : bottom && left ? .bottomLeft : bottom && right ? .bottomRight : nil
    if let cornerHit, enabled.contains(.corner(cornerHit)) { return .corner(cornerHit) }

    let strip = settings.edgeWidthMM
    let candidates: [(Zone.Edge, Bool, Double)] = [
      (.left, x < strip, point.y), (.right, width - x < strip, point.y),
      (.bottom, y < strip, point.x), (.top, height - y < strip, point.x),
    ]
    for (edge, inside, along) in candidates where inside {
      let hits = enabled.filter { zone in
        guard case .edge(edge, let segment, let segments) = zone, segments > 0 else { return false }
        let start = Double(segment) / Double(segments)
        let end = Double(segment + 1) / Double(segments)
        return along >= start && (along < end || (end >= 1 && along <= 1))
      }
      // Prefer the finest split that contains the point.
      if let best = hits.max(by: { $0.displayOrder.lexicographicallyPrecedes($1.displayOrder) }) { return best }
    }
    return nil
  }
}
