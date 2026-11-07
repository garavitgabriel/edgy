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
        // Side segments count bottom to top, like the screen's y.
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

  /// The display check stacks beside the level plate it asks about **along the docked edge**,
  /// never inward over the document (critique 18 must-fix 1; render S8 keeps both in the gutter):
  /// below a side-edge or corner level plate (above when there's no room below), and outward along
  /// a top or bottom edge (toward the nearer end; the other side when there's no room).
  static func beside(_ level: CGRect, size: CGSize, zone: Zone?, in visible: CGRect) -> CGRect {
    let inner = visible.insetBy(dx: margin, dy: margin)
    var frame = CGRect(origin: .zero, size: size)
    switch zone {
    case .edge(.top, _, _)?, .edge(.bottom, _, _)?:
      frame.origin.y = isTop(zone) ? level.maxY - size.height : level.minY
      let left = level.minX - margin - size.width
      let right = level.maxX + margin
      let fitsLeft = left >= inner.minX
      let fitsRight = right + size.width <= inner.maxX
      // Outward: toward the nearer end of the edge; the other side when it doesn't fit there.
      let preferLeft = level.midX < inner.midX
      let useLeft = preferLeft ? (fitsLeft || !fitsRight) : (!fitsRight && fitsLeft)
      frame.origin.x = useLeft ? left : right
    case nil:
      return self.frame(zone: nil, size: size, in: visible)
    default:
      let isRight: Bool
      switch zone {
      case .edge(.right, _, _)?, .corner(.topRight)?, .corner(.bottomRight)?: isRight = true
      default: isRight = false
      }
      frame.origin.x = isRight ? level.maxX - size.width : level.minX
      let below = level.minY - margin - size.height
      frame.origin.y = below >= inner.minY ? below : level.maxY + margin
    }
    return clamp(frame, in: inner)
  }

  // MARK: Keeping clear of the work

  /// Gap kept between a plate and the focused text element, and (when there's room) the window
  /// being worked in, so a plate never reads as attached to the document (critique 18 should-fix 1).
  static let workGap: CGFloat = 8
  /// The step a plate slides along its edge while looking for a clear spot.
  static let slideStep: CGFloat = 4

  /// Moves a docked `frame` **along its edge** (never inward) to the nearest spot that:
  /// 1. never covers the focused text (`work.text`, plus `workGap`), and never overlaps another
  ///    plate already placed (`plates`); then, when it can,
  /// 2. keeps `workGap` clear of the window being worked in (`work.window`).
  /// When nothing along the edge meets 2, the nearest spot meeting 1 wins; when nothing meets 1
  /// either, the docked frame stays (the edge is full).
  static func settle(_ frame: CGRect, zone: Zone?, in visible: CGRect, work: OverlayWorkArea, plates: [CGRect] = [])
    -> CGRect
  {
    let inner = visible.insetBy(dx: margin, dy: margin)
    let text = work.text?.insetBy(dx: -workGap, dy: -workGap)
    let window = work.window?.insetBy(dx: -workGap, dy: -workGap)
    // Plates already stacked sit exactly `margin` apart; anything closer overlaps.
    let others = plates.map { $0.insetBy(dx: -(margin - 1), dy: -(margin - 1)) }
    func hardClear(_ f: CGRect) -> Bool {
      !(text.map(f.intersects) ?? false) && !others.contains(where: f.intersects)
    }
    func softClear(_ f: CGRect) -> Bool { !(window.map(f.intersects) ?? false) }
    if hardClear(frame) && softClear(frame) { return frame }

    let vertical = slidesVertically(zone)
    let span = vertical ? inner.height : inner.width
    var candidates: [CGRect] = []
    var offset: CGFloat = slideStep
    while offset <= span {
      for signed in [-offset, offset] {
        let moved = frame.offsetBy(dx: vertical ? 0 : signed, dy: vertical ? signed : 0)
        let clamped = clamp(moved, in: inner)
        if clamped == moved { candidates.append(moved) }
      }
      offset += slideStep
    }
    if let best = candidates.first(where: { hardClear($0) && softClear($0) }) { return best }
    if hardClear(frame) { return frame }
    return candidates.first(where: hardClear) ?? frame
  }

  /// Side edges and corners slide up and down their side; top and bottom edges slide sideways.
  static func slidesVertically(_ zone: Zone?) -> Bool {
    switch zone {
    case .edge(.left, _, _)?, .edge(.right, _, _)?, .corner?: return true
    case .edge(.top, _, _)?, .edge(.bottom, _, _)?, nil: return false
    }
  }

  private static func isTop(_ zone: Zone?) -> Bool {
    if case .edge(.top, _, _)? = zone { return true }
    return false
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
