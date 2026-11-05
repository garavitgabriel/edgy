import EdgyCore

/// The physical region of the sensor a point falls in, before checking which zones are mapped.
enum Region: Hashable, Sendable {
  case edge(Zone.Edge)
  case corner(Zone.Corner)
}

/// Zone layout in millimetres for one device + settings.
///
/// - Corner squares (`cornerSizeMM`) always win over edge strips (`edgeWidthMM`).
/// - Edge segments split the full physical edge length (corner squares included) into equal parts.
/// - The "along" axis is y for left/right edges and x for top/bottom edges, so movement toward the
///   top or the right is positive.
struct ZoneGeometry: Sendable {
  let width: Double
  let height: Double
  let edgeWidth: Double
  let cornerSize: Double

  init(device: TouchDeviceInfo, settings: GestureSettings) {
    width = max(device.sensorSizeMM.width, 1)
    height = max(device.sensorSizeMM.height, 1)
    edgeWidth = max(settings.edgeWidthMM, 0)
    cornerSize = max(settings.cornerSizeMM, 0)
  }

  /// Normalized (0...1, origin bottom-left) → millimetres.
  func millimetres(_ point: Point2D) -> Point2D {
    Point2D(x: point.x * width, y: point.y * height)
  }

  func region(at point: Point2D) -> Region? {
    let left = point.x
    let right = width - point.x
    let bottom = point.y
    let top = height - point.y
    if min(left, right) < cornerSize && min(bottom, top) < cornerSize {
      switch (left <= right, bottom <= top) {
      case (true, true): return .corner(.bottomLeft)
      case (true, false): return .corner(.topLeft)
      case (false, true): return .corner(.bottomRight)
      case (false, false): return .corner(.topRight)
      }
    }
    var best: (edge: Zone.Edge, distance: Double)?
    let distances: [(Zone.Edge, Double)] = [(.left, left), (.right, right), (.bottom, bottom), (.top, top)]
    for (edge, distance) in distances where distance < edgeWidth {
      if let current = best, current.distance <= distance { continue }
      best = (edge, distance)
    }
    return best.map { .edge($0.edge) }
  }

  func length(of edge: Zone.Edge) -> Double {
    switch edge {
    case .left, .right: return height
    case .top, .bottom: return width
    }
  }

  /// Coordinate along the edge axis, in millimetres.
  func along(_ edge: Zone.Edge, _ point: Point2D) -> Double {
    switch edge {
    case .left, .right: return point.y
    case .top, .bottom: return point.x
    }
  }

  /// Signed movement away from the edge, toward the centre of the sensor (positive = inward).
  func inward(_ edge: Zone.Edge, from start: Point2D, to end: Point2D) -> Double {
    switch edge {
    case .left: return end.x - start.x
    case .right: return start.x - end.x
    case .bottom: return end.y - start.y
    case .top: return start.y - end.y
    }
  }

  /// The mapped zone a touch landing at `point` (inside `region`) belongs to, or nil if unmapped.
  /// When several segmentations of the same edge are mapped, the finest one wins.
  func zone(for region: Region, at point: Point2D, enabled: Set<Zone>) -> Zone? {
    switch region {
    case .corner(let corner):
      return enabled.contains(.corner(corner)) ? .corner(corner) : nil
    case .edge(let edge):
      let fraction = along(edge, point) / length(of: edge)
      var best: (segment: Int, segments: Int)?
      for candidate in enabled {
        guard case .edge(let candidateEdge, let segment, let segments) = candidate, candidateEdge == edge,
          segments >= 1, segment >= 0, segment < segments,
          segment == Self.segmentIndex(fraction, segments: segments)
        else { continue }
        if let current = best, current.segments >= segments { continue }
        best = (segment, segments)
      }
      return best.map { .edge(edge, segment: $0.segment, segments: $0.segments) }
    }
  }

  static func segmentIndex(_ fraction: Double, segments: Int) -> Int {
    let raw = (fraction * Double(segments)).rounded(.down)
    guard raw.isFinite else { return 0 }
    return min(segments - 1, max(0, Int(raw)))
  }

  /// Length of the zone along its axis, in millimetres (the denominator for normalized deltas).
  func zoneLength(_ zone: Zone) -> Double {
    switch zone {
    case .corner: return cornerSize > 0 ? cornerSize : 1
    case .edge(let edge, _, let segments): return length(of: edge) / Double(max(segments, 1))
    }
  }

  /// Position along the zone axis, 0...1. Corners have no axis and report 0.
  func position(in zone: Zone, at point: Point2D) -> Double {
    switch zone {
    case .corner: return 0
    case .edge(let edge, let segment, _):
      let length = zoneLength(zone)
      let value = (along(edge, point) - Double(segment) * length) / length
      return min(1, max(0, value))
    }
  }
}
