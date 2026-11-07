import EdgyCore

/// A rectangle on the sensor in millimetres, origin bottom-left.
public struct PadRect: Hashable, Sendable {
  public var x: Double
  public var y: Double
  public var width: Double
  public var height: Double

  public init(x: Double, y: Double, width: Double, height: Double) {
    self.x = x
    self.y = y
    self.width = width
    self.height = height
  }
}

/// The zone layout the recognizer uses, for drawing the trackpad mirror: the mirror must show
/// exactly where touches land, so it reads geometry from here instead of recomputing it.
///
/// - Corner squares are `cornerSizeMM` on a side. A mapped corner wins over the edges inside its
///   square; an unmapped corner passes its touches through to the edge strip it overlaps.
/// - Edge strips are `edgeWidthMM` deep and run the full physical length; segment `i` of `n`
///   covers the `i`-th equal slice of that length (corner squares included).
public struct PadLayout: Hashable, Sendable {
  public let sensorSizeMM: Size2D
  public let edgeWidthMM: Double
  public let cornerSizeMM: Double

  public init(sensorSizeMM: Size2D, settings: GestureSettings) {
    let geometry = ZoneGeometry(
      device: TouchDeviceInfo(id: 0, kind: .unknown, sensorSizeMM: sensorSizeMM, familyID: 0), settings: settings)
    self.sensorSizeMM = Size2D(width: geometry.width, height: geometry.height)
    edgeWidthMM = geometry.edgeWidth
    cornerSizeMM = geometry.cornerSize
  }

  /// Where `zone` lies on the sensor.
  public func rect(for zone: Zone) -> PadRect {
    let w = sensorSizeMM.width
    let h = sensorSizeMM.height
    switch zone {
    case .corner(let corner):
      let c = cornerSizeMM
      switch corner {
      case .bottomLeft: return PadRect(x: 0, y: 0, width: c, height: c)
      case .bottomRight: return PadRect(x: w - c, y: 0, width: c, height: c)
      case .topLeft: return PadRect(x: 0, y: h - c, width: c, height: c)
      case .topRight: return PadRect(x: w - c, y: h - c, width: c, height: c)
      }
    case .edge(let edge, let segment, let segments):
      let count = Double(max(segments, 1))
      let index = Double(min(max(segment, 0), max(segments, 1) - 1))
      let d = edgeWidthMM
      switch edge {
      case .left: return PadRect(x: 0, y: h * index / count, width: d, height: h / count)
      case .right: return PadRect(x: w - d, y: h * index / count, width: d, height: h / count)
      case .bottom: return PadRect(x: w * index / count, y: 0, width: w / count, height: d)
      case .top: return PadRect(x: w * index / count, y: h - d, width: w / count, height: d)
      }
    }
  }

  /// The mapped zone a touch landing at `pointMM` belongs to — the same answer the recognizer
  /// gives — or nil for an ordinary pointer touch.
  public func zone(atMM pointMM: Point2D, mapped: Set<Zone>) -> Zone? {
    let geometry = ZoneGeometry(
      device: TouchDeviceInfo(id: 0, kind: .unknown, sensorSizeMM: sensorSizeMM, familyID: 0),
      settings: GestureSettings(
        edgeWidthMM: edgeWidthMM, cornerSizeMM: cornerSizeMM, dwellMS: 0, palmMajorAxisMM: 0,
        typingSuppressionMS: 0, doubleTapWindowMS: 0, longPressMS: 0, fingers: 1))
    return geometry.resolve(at: pointMM, enabled: mapped)?.zone
  }
}
