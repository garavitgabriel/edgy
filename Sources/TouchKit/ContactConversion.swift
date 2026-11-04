import EdgyCore
import Foundation

/// Maps the device's raw per-contact state to `TouchContact.State`.
///
/// Raw states: 0 not tracking, 1 start-in-range, 2 hover-in-range, 3 make-touch, 4 touching,
/// 5 break-touch, 6 linger-in-range, 7 out-of-range.
public enum ContactStateMapping {
  public static func state(fromRaw raw: Int32) -> TouchContact.State {
    switch raw {
    case 1, 2: return .hovering
    case 3: return .starting
    case 4: return .touching
    case 5: return .lifting
    case 6, 7: return .leaving
    default: return .unknown
    }
  }
}

/// Learns how many millimetres one device unit (ellipse axes, absolute position) represents.
///
/// The contact record reports position twice: normalized (0…1 across the sensor) and in device
/// units. Velocity is reported the same two ways. For a moving finger, `absoluteVelocity /
/// normalizedVelocity` is the number of device units spanning the full sensor, independent of
/// where the device places its origin. Dividing the sensor size in mm by that span gives mm per
/// device unit, which we apply to the ellipse axes (assumed to share the absolute units).
/// Until a usable sample arrives the scale stays at its initial value (1 mm per unit).
public struct AxisScaleEstimator: Sendable, Equatable {
  public private(set) var mmPerUnit: Double
  public private(set) var sampleCount = 0
  /// Minimum |normalized velocity| on an axis for that axis to contribute a sample.
  public var minimumNormalizedSpeed: Double = 0.05
  /// Plausible scale range; anything outside is discarded as noise.
  public var plausibleRange: ClosedRange<Double> = 0.01...100
  /// Exponential smoothing weight for new samples after the first one.
  public var smoothing: Double = 0.1

  public init(initialMMPerUnit: Double = 1) {
    self.mmPerUnit = initialMMPerUnit
  }

  mutating func observe(_ raw: RawContact, sensorSizeMM: Size2D) {
    let candidates = [
      sample(norm: raw.normalizedVX, abs: raw.absoluteVX, spanMM: sensorSizeMM.width),
      sample(norm: raw.normalizedVY, abs: raw.absoluteVY, spanMM: sensorSizeMM.height),
    ]
    for s in candidates.compactMap({ $0 }) where plausibleRange.contains(s) {
      mmPerUnit = sampleCount == 0 ? s : mmPerUnit + smoothing * (s - mmPerUnit)
      sampleCount += 1
    }
  }

  /// mm per device unit from one axis, or nil when the axis is too slow / inconsistent to trust.
  private func sample(norm: Float, abs absolute: Float, spanMM: Double) -> Double? {
    let n = Double(norm)
    let a = Double(absolute)
    guard n.isFinite, a.isFinite, Swift.abs(n) >= minimumNormalizedSpeed, a != 0, n.sign == a.sign, spanMM > 0
    else { return nil }
    return spanMM * n / a
  }
}

/// Pure raw → `TouchContact` / `TouchFrame` conversion for one device.
public struct ContactConverter: Sendable, Equatable {
  public var sensorSizeMM: Size2D

  public init(sensorSizeMM: Size2D) {
    self.sensorSizeMM = sensorSizeMM
  }

  func contact(from raw: RawContact, mmPerAxisUnit: Double) -> TouchContact {
    let a = Double(raw.majorAxis) * mmPerAxisUnit
    let b = Double(raw.minorAxis) * mmPerAxisUnit
    return TouchContact(
      id: raw.identifier,
      state: ContactStateMapping.state(fromRaw: raw.state),
      position: Point2D(x: Self.clampUnit(Double(raw.normalizedX)), y: Self.clampUnit(Double(raw.normalizedY))),
      velocity: Vector2D(dx: Double(raw.normalizedVX), dy: Double(raw.normalizedVY)),
      majorAxisMM: max(a, b),
      minorAxisMM: min(a, b),
      angle: Double(raw.angle),
      size: Double(raw.size),
      density: Double(raw.density))
  }

  func frame(
    deviceID: UInt64, timestamp: TimeInterval, frameNumber: Int32, raws: [RawContact], mmPerAxisUnit: Double
  ) -> TouchFrame {
    TouchFrame(
      deviceID: deviceID, timestamp: timestamp, frameNumber: frameNumber,
      contacts: raws.map { contact(from: $0, mmPerAxisUnit: mmPerAxisUnit) })
  }

  static func clampUnit(_ v: Double) -> Double {
    guard v.isFinite else { return 0 }
    return min(1, max(0, v))
  }
}
