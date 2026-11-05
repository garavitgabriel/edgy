import EdgyCore
import Foundation

/// Static knowledge about multitouch device families: classification and fallback sensor sizes.
///
/// The live bridge asks each device for its sensor surface size first. The per-family table is
/// only used when that query is unavailable or returns something implausible, and every use of it
/// is logged by the caller.
public enum DeviceCatalog {
  /// Family IDs reported by external multitouch mice.
  public static let mouseFamilies: Set<Int32> = [112, 113]
  /// Family IDs reported by external trackpads.
  public static let externalTrackpadFamilies: Set<Int32> = [128, 129, 130]

  /// Plausible sensor edge length, mm. Outside this a reported size is ignored.
  public static let plausibleSensorEdgeMM: ClosedRange<Double> = 20...400

  public static func kind(familyID: Int32, isBuiltIn: Bool) -> TouchDeviceInfo.Kind {
    if isBuiltIn { return .builtInTrackpad }
    if mouseFamilies.contains(familyID) { return .mouse }
    if externalTrackpadFamilies.contains(familyID) { return .externalTrackpad }
    return .unknown
  }

  /// Approximate sensor sizes per family (mm), used only when the device does not report one.
  public static func fallbackSensorSizeMM(familyID: Int32, kind: TouchDeviceInfo.Kind) -> Size2D {
    switch familyID {
    case 129, 130: return Size2D(width: 160, height: 115)
    case 128: return Size2D(width: 130, height: 110)
    case 112, 113: return Size2D(width: 55, height: 85)
    default: break
    }
    switch kind {
    case .builtInTrackpad: return Size2D(width: 135, height: 85)
    case .externalTrackpad: return Size2D(width: 160, height: 115)
    case .mouse: return Size2D(width: 55, height: 85)
    case .unknown: return Size2D(width: 120, height: 80)
    }
  }

  /// Resolves the sensor size: device-reported surface dimensions (hundredths of a mm) when
  /// plausible, otherwise the family fallback. `usedFallback` tells the caller to log it.
  public static func sensorSize(
    reportedHundredthsMM: (width: Int32, height: Int32)?, familyID: Int32, kind: TouchDeviceInfo.Kind
  ) -> (size: Size2D, usedFallback: Bool) {
    if let r = reportedHundredthsMM {
      let w = Double(r.width) / 100
      let h = Double(r.height) / 100
      if plausibleSensorEdgeMM.contains(w), plausibleSensorEdgeMM.contains(h) {
        return (Size2D(width: w, height: h), false)
      }
    }
    return (fallbackSensorSizeMM(familyID: familyID, kind: kind), true)
  }
}
