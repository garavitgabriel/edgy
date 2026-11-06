import CoreGraphics

/// Where a window snap puts the window.
enum WindowSnap: String, CaseIterable, Sendable {
  case leftHalf, rightHalf, topHalf, bottomHalf, maximize, center
}

/// Pure window-snapping geometry. Every rect is in top-left-origin global coordinates (the
/// accessibility API's space: y grows downward from the top of the primary display).
enum WindowGeometry {
  /// The frame `snap` gives a window currently at `window` on a screen whose usable area is
  /// `visible`. Results are whole points; halves split odd sizes so that both halves together
  /// cover the visible frame exactly (the left/top half gets the smaller share).
  static func target(for snap: WindowSnap, window: CGRect, visible: CGRect) -> CGRect {
    let v = visible.integral
    let halfWidth = (v.width / 2).rounded(.down)
    let halfHeight = (v.height / 2).rounded(.down)
    switch snap {
    case .leftHalf:
      return CGRect(x: v.minX, y: v.minY, width: halfWidth, height: v.height)
    case .rightHalf:
      return CGRect(x: v.minX + halfWidth, y: v.minY, width: v.width - halfWidth, height: v.height)
    case .topHalf:
      return CGRect(x: v.minX, y: v.minY, width: v.width, height: halfHeight)
    case .bottomHalf:
      return CGRect(x: v.minX, y: v.minY + halfHeight, width: v.width, height: v.height - halfHeight)
    case .maximize:
      return v
    case .center:
      // Keep the size (shrunk to fit if larger than the screen), centred, inside the screen.
      let width = min(window.width.rounded(), v.width)
      let height = min(window.height.rounded(), v.height)
      let x = (v.minX + (v.width - width) / 2).rounded(.down)
      let y = (v.minY + (v.height - height) / 2).rounded(.down)
      return CGRect(
        x: min(max(x, v.minX), v.maxX - width), y: min(max(y, v.minY), v.maxY - height), width: width,
        height: height)
    }
  }

  /// Converts between AppKit's bottom-left-origin global coordinates and the accessibility API's
  /// top-left-origin ones. Both spaces are anchored on the primary display (height
  /// `primaryHeight`); the conversion is its own inverse.
  static func flip(_ rect: CGRect, primaryHeight: CGFloat) -> CGRect {
    CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
  }
}
