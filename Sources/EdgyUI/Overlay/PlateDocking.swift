import CoreGraphics
import EdgyCore

/// Where a plate sits on a screen (bone 9): docked to the screen edge or corner of the touched
/// zone, fully on-screen, at the screen's edge (away from the text being worked on). Pure; frames
/// are in AppKit global coordinates (origin bottom-left, y up), inside the screen's
/// `visibleFrame` (so never under the menu bar or the Dock).
enum PlateDocking {
  /// Gap between a plate and the screen edge, and between stacked plates.
  static let margin: CGFloat = 16

  /// The frame for a plate of `size` touched in `zone`. `stack` is how many plates already sit at
  /// the same dock; each one moves the next along the edge (away from the corner for corners).
  static func frame(zone: Zone?, size: CGSize, in visible: CGRect, stack: Int = 0) -> CGRect {
    let inner = visible.insetBy(dx: margin, dy: margin)
    let step = CGFloat(stack)
    var origin: CGPoint
    switch zone {
    case .edge(let edge, let segment, let segments)?:
      let fraction = (CGFloat(segment) + 0.5) / CGFloat(max(segments, 1))
      switch edge {
      case .right, .left:
        let x = edge == .right ? inner.maxX - size.width : inner.minX
        // Side segments count bottom → top, like the screen's y.
        let y = inner.minY + inner.height * fraction - size.height / 2 - step * (size.height + margin)
        origin = CGPoint(x: x, y: y)
      case .top, .bottom:
        let y = edge == .top ? inner.maxY - size.height : inner.minY
        let x = inner.minX + inner.width * fraction - size.width / 2 + step * (size.width + margin)
        origin = CGPoint(x: x, y: y)
      }
    case .corner(let corner)?:
      let isRight = corner == .topRight || corner == .bottomRight
      let isTop = corner == .topLeft || corner == .topRight
      let x = isRight ? inner.maxX - size.width : inner.minX
      let y =
        isTop ? inner.maxY - size.height - step * (size.height + margin) : inner.minY + step * (size.height + margin)
      origin = CGPoint(x: x, y: y)
    case nil:
      // No zone (a display check on its own): bottom centre.
      origin = CGPoint(x: inner.midX - size.width / 2 + step * (size.width + margin), y: inner.minY)
    }
    return clamp(CGRect(origin: origin, size: size), in: inner)
  }

  /// The display check sits beside the level plate it asks about, on the side toward the screen's
  /// middle (render S8: to the right of a left-edge level plate), fully on-screen.
  static func beside(_ level: CGRect, size: CGSize, zone: Zone?, in visible: CGRect) -> CGRect {
    let inner = visible.insetBy(dx: margin, dy: margin)
    let towardLeft: Bool
    switch zone {
    case .edge(.right, _, _)?, .corner(.topRight)?, .corner(.bottomRight)?: towardLeft = true
    default: towardLeft = false
    }
    let x = towardLeft ? level.minX - margin - size.width : level.maxX + margin
    // Top-aligned with the level plate, as in S8.
    let frame = CGRect(x: x, y: level.maxY - size.height, width: size.width, height: size.height)
    return clamp(frame, in: inner)
  }

  /// Moves `frame` the least distance that keeps it inside `bounds` (top-left wins when it can't fit).
  static func clamp(_ frame: CGRect, in bounds: CGRect) -> CGRect {
    var result = frame
    if result.maxX > bounds.maxX { result.origin.x = bounds.maxX - result.width }
    if result.minX < bounds.minX { result.origin.x = bounds.minX }
    if result.minY < bounds.minY { result.origin.y = bounds.minY }
    if result.maxY > bounds.maxY { result.origin.y = bounds.maxY - result.height }
    return result
  }

  /// A key that is the same for plates that would land on the same spot.
  static func dockKey(_ zone: Zone?) -> String {
    switch zone {
    case .edge(let edge, let segment, let segments)?: return "\(edge.rawValue)-\(segment)/\(segments)"
    case .corner(let corner)?: return corner.rawValue
    case nil: return "none"
    }
  }
}
