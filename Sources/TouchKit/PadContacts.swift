import EdgyCore
import Foundation

/// What the pointer guard needs from the touch frames to tell a physical press from the system's
/// tap-to-click click (batch 35).
public struct PadContactSnapshot: Sendable, Equatable {
  /// A finger is down (`starting`, `touching` or `unknown`) on any multitouch device right now.
  public var fingersDown: Bool
  /// Bumped every time the pads go from "a finger down" to "no finger down".
  public var emptyEpoch: Int
  /// When the pads last emptied (monotonic seconds), or nil before the first lift.
  public var emptiedAt: TimeInterval?

  public init(fingersDown: Bool, emptyEpoch: Int, emptiedAt: TimeInterval?) {
    self.fingersDown = fingersDown
    self.emptyEpoch = emptyEpoch
    self.emptiedAt = emptiedAt
  }
}

public protocol PadContactSensing: AnyObject, Sendable {
  var snapshot: PadContactSnapshot { get }
}

/// Which fingers are on the pads, written from every frame as `DeviceManager` hands it out (on the
/// input thread, before the frame hops to the engine) and read by the pointer guard's event tap.
/// Both factories are separate, so the live touch source and the live guard share `shared`.
public final class PadContacts: PadContactSensing, @unchecked Sendable {
  static let shared = PadContacts()

  private let lock = NSLock()
  private let now: @Sendable () -> TimeInterval
  private var downByDevice: [UInt64: Bool] = [:]
  private var current = PadContactSnapshot(fingersDown: false, emptyEpoch: 0, emptiedAt: nil)

  public init(now: @escaping @Sendable () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
    self.now = now
  }

  public var snapshot: PadContactSnapshot { lock.withLock { current } }

  /// The same "down" the gesture pipeline uses: a lifting or hovering finger is up.
  static func isDown(_ state: TouchContact.State) -> Bool {
    switch state {
    case .starting, .touching, .unknown: return true
    case .hovering, .lifting, .leaving: return false
    }
  }

  public func observe(_ frame: TouchFrame) {
    let down = frame.contacts.contains { Self.isDown($0.state) }
    let at = now()
    lock.withLock {
      guard downByDevice[frame.deviceID] != down else { return }
      downByDevice[frame.deviceID] = down
      update(at: at)
    }
  }

  /// A device that went away can't hold a finger down.
  public func forget(deviceIDs: Set<UInt64>) {
    let at = now()
    lock.withLock {
      let before = downByDevice.count
      downByDevice = downByDevice.filter { !deviceIDs.contains($0.key) }
      if downByDevice.count != before { update(at: at) }
    }
  }

  private func update(at: TimeInterval) {
    let anyDown = downByDevice.values.contains(true)
    if current.fingersDown && !anyDown {
      current.emptyEpoch += 1
      current.emptiedAt = at
    }
    current.fingersDown = anyDown
  }
}
