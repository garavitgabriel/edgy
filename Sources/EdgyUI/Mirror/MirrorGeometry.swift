import CoreGraphics
import EdgyCore
import Gestures

/// Converts the recognizer's own zone layout (`Gestures.PadLayout`, millimetres, origin
/// bottom-left) into mirror points (origin top-left). The mirror never recomputes zone math: every
/// zone frame here is a `PadLayout` rect, scaled and flipped (bone 1, "the mirror is the pad").
///
/// Two frames per zone:
/// - `frame(for:)` is the zone as the recognizer sees it. It is the hit area for clicks and the
///   frame the tests compare against `PadLayout`. Edge strips run the full length and overlap the
///   corner squares, exactly as `PadLayout` says.
/// - `shapeFrame(for:)` is what gets drawn. It is the same frame, inset so the bar sits inside its
///   strip with rounded ends, and with the corner squares trimmed off the strip's ends so the
///   bars stop at the corner tiles (render A). Segment boundaries stay where `PadLayout` puts them.
///   This is presentation only. Hits and the picker anchor never use it for geometry decisions.
struct MirrorGeometry: Hashable {
  /// The proportion drawn when no trackpad has ever been seen (a full-size external pad).
  static let defaultSensorSizeMM = Size2D(width: 160, height: 115)

  /// Share of the strip depth (or corner size) left empty on each side of a drawn bar or tile.
  static let insetRatio = 0.16

  let layout: PadLayout
  let pointsPerMM: CGFloat

  init(sensorSizeMM: Size2D, settings: GestureSettings, pointsPerMM: CGFloat) {
    layout = PadLayout(sensorSizeMM: sensorSizeMM, settings: settings)
    self.pointsPerMM = pointsPerMM
  }

  /// The pad, to scale.
  var size: CGSize {
    CGSize(width: layout.sensorSizeMM.width * pointsPerMM, height: layout.sensorSizeMM.height * pointsPerMM)
  }

  /// The zone as the recognizer sees it, in mirror points (origin top-left).
  func frame(for zone: Zone) -> CGRect {
    points(layout.rect(for: zone))
  }

  /// The drawn bar or tile for `zone`, in mirror points: inset in its strip, ends trimmed at the
  /// corner squares.
  func shapeFrame(for zone: Zone) -> CGRect {
    var rect = layout.rect(for: zone)
    let w = layout.sensorSizeMM.width
    let h = layout.sensorSizeMM.height
    switch zone {
    case .corner:
      let inset = layout.cornerSizeMM * Self.insetRatio / 2
      rect = PadRect(
        x: rect.x + inset, y: rect.y + inset, width: rect.width - 2 * inset, height: rect.height - 2 * inset)
    case .edge(let edge, _, _):
      let across = layout.edgeWidthMM * Self.insetRatio
      let gap = across / 2
      let corner = layout.cornerSizeMM
      switch edge {
      case .left, .right:
        var low = rect.y + gap
        var high = rect.y + rect.height - gap
        if rect.y <= 0 { low = corner + across }
        if rect.y + rect.height >= h { high = h - corner - across }
        rect = PadRect(x: rect.x + across, y: low, width: rect.width - 2 * across, height: max(high - low, 0))
      case .top, .bottom:
        var low = rect.x + gap
        var high = rect.x + rect.width - gap
        if rect.x <= 0 { low = corner + across }
        if rect.x + rect.width >= w { high = w - corner - across }
        rect = PadRect(x: low, y: rect.y + across, width: max(high - low, 0), height: rect.height - 2 * across)
      }
    }
    return points(rect)
  }

  /// A live touch's position (normalized, origin bottom-left) in mirror points (origin top-left).
  func point(forNormalized position: Point2D) -> CGPoint {
    CGPoint(x: position.x * size.width, y: (1 - position.y) * size.height)
  }

  /// A live touch's position on the sensor, in millimetres (origin bottom-left), for `PadLayout`.
  func millimetres(forNormalized position: Point2D) -> Point2D {
    Point2D(x: position.x * layout.sensorSizeMM.width, y: position.y * layout.sensorSizeMM.height)
  }

  /// The mapped zone a touch at `position` belongs to: the recognizer's own answer.
  func zone(atNormalized position: Point2D, mapped: Set<Zone>) -> Zone? {
    layout.zone(atMM: millimetres(forNormalized: position), mapped: mapped)
  }

  /// A fingertip contact, in points (slightly taller than wide, as in the renders).
  var contactSize: CGSize {
    CGSize(width: 7.5 * pointsPerMM, height: 9 * pointsPerMM)
  }

  private func points(_ rect: PadRect) -> CGRect {
    let h = layout.sensorSizeMM.height
    return CGRect(
      x: rect.x * pointsPerMM, y: (h - rect.y - rect.height) * pointsPerMM,
      width: rect.width * pointsPerMM, height: rect.height * pointsPerMM)
  }
}
