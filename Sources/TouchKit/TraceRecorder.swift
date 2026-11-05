import EdgyCore
import Foundation

/// Accumulates frames from one device into a `TraceFile`. Thread-safe: frames may arrive on the
/// device callback thread while the CLI reads the count from the main thread.
public final class TraceRecorder: @unchecked Sendable {
  public enum RecorderError: Error, Equatable {
    case invalidLabel(String)
  }

  public let label: String
  public let expectation: String

  private let lock = NSLock()
  private var lockedDeviceID: UInt64?
  private var frames: [TouchFrame] = []

  /// - Parameter deviceID: record only this device; nil locks onto the first device seen.
  public init(label: String, expectation: String, deviceID: UInt64? = nil) throws {
    guard Self.isValidLabel(label) else { throw RecorderError.invalidLabel(label) }
    self.label = label
    self.expectation = expectation
    self.lockedDeviceID = deviceID
  }

  /// Lowercase kebab-case: `a-z0-9` words separated by single hyphens.
  public static func isValidLabel(_ label: String) -> Bool {
    let words = label.split(separator: "-", omittingEmptySubsequences: false)
    guard !label.isEmpty, !words.contains(where: \.isEmpty) else { return false }
    return label.allSatisfy { ($0.isASCII && ($0.isLowercase || $0.isNumber)) || $0 == "-" }
  }

  public var deviceID: UInt64? { lock.withLock { lockedDeviceID } }
  public var frameCount: Int { lock.withLock { frames.count } }

  public func append(_ frame: TouchFrame) {
    lock.withLock {
      if lockedDeviceID == nil { lockedDeviceID = frame.deviceID }
      guard frame.deviceID == lockedDeviceID else { return }
      frames.append(frame)
    }
  }

  /// Builds the trace. With `rebaseTimestamps`, the first frame is at t = 0 (still monotonic).
  public func makeTrace(device: TouchDeviceInfo, rebaseTimestamps: Bool = true) -> TraceFile {
    var captured = lock.withLock { frames }
    if rebaseTimestamps, let t0 = captured.first?.timestamp {
      for i in captured.indices { captured[i].timestamp -= t0 }
    }
    return TraceFile(label: label, expectation: expectation, device: device, frames: captured)
  }
}

/// Compact one-line rendering of a frame, for `edgy-trace live`.
public enum FrameFormatter {
  public static func line(_ frame: TouchFrame) -> String {
    let head = String(
      format: "%10.3f #%-6d dev=%llu n=%d", frame.timestamp, frame.frameNumber, frame.deviceID, frame.contacts.count)
    let contacts = frame.contacts.map { c in
      String(
        format: "[%d %@ (%.3f,%.3f) v(%.2f,%.2f) %.1fx%.1fmm]", c.id, short(c.state), c.position.x, c.position.y,
        c.velocity.dx, c.velocity.dy, c.majorAxisMM, c.minorAxisMM)
    }
    return ([head] + contacts).joined(separator: " ")
  }

  static func short(_ state: TouchContact.State) -> String {
    switch state {
    case .starting: return "start"
    case .hovering: return "hover"
    case .touching: return "touch"
    case .lifting: return "lift"
    case .leaving: return "leave"
    case .unknown: return "?"
    }
  }
}
