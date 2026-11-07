import EdgyCore
import SwiftUI

/// Edgy's action icon family (BRIEF § Picker clarity: icons and rhythm), transcribed from the
/// exported SVGs. Never SF Symbols or stock glyphs for actions.
public enum ActionIcons {
  /// Whether `id` has a drawing.
  public static func has(_ id: ActionID) -> Bool { drawing(for: id) != nil }

  static func drawing(for id: ActionID) -> IconDrawing? {
    IconDrawing.fileForAction[id.rawValue].flatMap { IconDrawing.all[$0] }
  }

  /// The Advanced… footer button's sliders (an interface icon from the same family).
  static var advanced: IconDrawing { IconDrawing.all["ui-advanced"]! }
}

/// One action's icon, `size` pt square (16 by default, on the 16 pt grid with a 1.5 pt stroke).
/// It takes its colour from the environment's foreground style, so callers set `Tokens.ink` or
/// `Tokens.ink2`. An id with no drawing (none in the shipped catalog; a test proves it) draws nothing.
public struct ActionIcon: View {
  public var id: ActionID
  public var size: CGFloat

  public init(id: ActionID, size: CGFloat = 16) {
    self.id = id
    self.size = size
  }

  public var body: some View {
    IconDrawingView(drawing: ActionIcons.drawing(for: id), size: size)
      .accessibilityHidden(true)
  }
}

/// Draws an `IconDrawing` square at `size`, in the foreground style.
struct IconDrawingView: View {
  var drawing: IconDrawing?
  var size: CGFloat

  var body: some View {
    Canvas { context, canvas in
      guard let drawing else { return }
      var context = context
      drawing.draw(in: &context, scale: canvas.width / drawing.width, fill: .foreground, stroke: .foreground)
    }
    .frame(width: size, height: size)
  }
}

/// The Advanced… button's 16 pt sliders icon (BRIEF § Window identity and Advanced).
public struct AdvancedIcon: View {
  public var size: CGFloat
  public init(size: CGFloat = 16) { self.size = size }
  public var body: some View {
    IconDrawingView(drawing: ActionIcons.advanced, size: size).accessibilityHidden(true)
  }
}

/// One segment of the Split control (BRIEF § Split control): *this* edge in the pad's orientation,
/// 40 × 12 pt for top and bottom, 12 × 40 pt for left and right, divided into `parts` (1–4) rounded
/// parts with 2 pt gaps. Selected is filled `ink`; unselected is a 1 pt `line` hairline. No numbers.
public struct EdgySplitGlyph: View {
  public var edge: Zone.Edge
  public var parts: Int
  public var selected: Bool

  public init(edge: Zone.Edge, parts: Int, selected: Bool) {
    self.edge = edge
    self.parts = parts
    self.selected = selected
  }

  static func file(edge: Zone.Edge, parts: Int, selected: Bool) -> String {
    let orientation = (edge == .left || edge == .right) ? "vertical" : "horizontal"
    return "split-\(orientation)-\(min(max(parts, 1), 4))\(selected ? "-selected" : "")"
  }

  var drawing: IconDrawing { IconDrawing.all[Self.file(edge: edge, parts: parts, selected: selected)]! }

  public var body: some View {
    let drawing = drawing
    let shading = GraphicsContext.Shading.color(selected ? Tokens.ink : Tokens.line)
    Canvas { context, _ in
      var context = context
      drawing.draw(in: &context, scale: 1, fill: shading, stroke: shading)
    }
    .frame(width: drawing.width, height: drawing.height)
    .accessibilityHidden(true)
  }
}
