import EdgyCore
import SwiftUI

/// Gesture icons: one family, one stroke weight, one 16 pt grid (BRIEF § Tokens). Every icon is
/// a contact dot plus strokes; swipe up and swipe down differ by where the dot sits and which way
/// the head points.
struct GestureIcon: View {
  var gesture: GestureKind
  /// Gesture icons follow the edge (BRIEF § Tokens): a slide on the top/bottom edge is drawn
  /// horizontal (the vertical glyph rotated 90°). Set by the inspector and picker for their zone.
  @Environment(\.gestureIconHorizontal) private var horizontal
  static let size: CGFloat = 16
  static let stroke: CGFloat = 1.5

  var body: some View {
    Canvas { context, size in
      let s = min(size.width, size.height)
      let c = CGPoint(x: size.width / 2, y: size.height / 2)
      let dot: CGFloat = s * 0.14
      var strokes = Path()
      var fill = Path()
      func dotAt(_ p: CGPoint) {
        fill.addEllipse(in: CGRect(x: p.x - dot, y: p.y - dot, width: dot * 2, height: dot * 2))
      }
      func ring(_ r: CGFloat) { strokes.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)) }
      func chevron(at p: CGPoint, toward angle: Double) {
        let len = s * 0.2
        for spread in [-0.75, 0.75] {
          let a = angle + .pi + spread
          strokes.move(to: p)
          strokes.addLine(to: CGPoint(x: p.x + len * cos(a), y: p.y + len * sin(a)))
        }
      }
      switch gesture {
      case .tap:
        dotAt(c)
        ring(s * 0.34)
      case .doubleTap:
        dotAt(c)
        ring(s * 0.26)
        ring(s * 0.44)
      case .longPress:
        dotAt(c)
        strokes.addArc(
          center: c, radius: s * 0.36, startAngle: .degrees(-60), endAngle: .degrees(210), clockwise: false)
        chevron(at: CGPoint(x: c.x + s * 0.36 * cos(-.pi / 3), y: c.y + s * 0.36 * sin(-.pi / 3)), toward: -.pi / 6)
      case .slide:
        dotAt(c)
        let top = CGPoint(x: c.x, y: s * 0.08)
        let bottom = CGPoint(x: c.x, y: s * 0.92)
        strokes.move(to: CGPoint(x: c.x, y: c.y - dot * 2))
        strokes.addLine(to: top)
        strokes.move(to: CGPoint(x: c.x, y: c.y + dot * 2))
        strokes.addLine(to: bottom)
        chevron(at: top, toward: -.pi / 2)
        chevron(at: bottom, toward: .pi / 2)
      case .swipe(let direction):
        let angle: Double
        switch direction {
        case .up: angle = -.pi / 2
        case .down: angle = .pi / 2
        case .left: angle = .pi
        case .right: angle = 0
        }
        let r = s * 0.4
        let tail = CGPoint(x: c.x - r * cos(angle), y: c.y - r * sin(angle))
        let head = CGPoint(x: c.x + r * cos(angle), y: c.y + r * sin(angle))
        dotAt(tail)
        strokes.move(to: CGPoint(x: tail.x + dot * 2 * cos(angle), y: tail.y + dot * 2 * sin(angle)))
        strokes.addLine(to: head)
        chevron(at: head, toward: angle)
      }
      context.stroke(
        strokes, with: .color(Tokens.ink), style: StrokeStyle(lineWidth: Self.stroke, lineCap: .round, lineJoin: .round)
      )
      context.fill(fill, with: .color(Tokens.ink))
    }
    .frame(width: Self.size, height: Self.size)
    .rotationEffect(horizontal && gesture == .slide ? .degrees(90) : .zero)
    .accessibilityHidden(true)
  }

  /// Top and bottom edges slide horizontally.
  static func isHorizontal(_ zone: Zone?) -> Bool {
    guard case .edge(let edge, _, _) = zone else { return false }
    return edge == .top || edge == .bottom
  }
}

private struct GestureIconHorizontalKey: EnvironmentKey {
  static let defaultValue = false
}

extension EnvironmentValues {
  var gestureIconHorizontal: Bool {
    get { self[GestureIconHorizontalKey.self] }
    set { self[GestureIconHorizontalKey.self] = newValue }
  }
}

/// One issue line: icon + wording, never colour (BRIEF § Issue states). Error = `ink`, warning
/// and info = `ink2`.
struct IssueLine<Trailing: View>: View {
  var style: IssueCopy.Style
  var text: String
  @ViewBuilder var trailing: Trailing

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 6) {
      Image(systemName: style.symbol)
        .font(Tokens.font(Tokens.typeBody))
      VStack(alignment: .leading, spacing: 6) {
        Text(text).fixedSize(horizontal: false, vertical: true)
        trailing
      }
    }
    .font(Tokens.font(Tokens.typeBody))
    .foregroundStyle(style == .error ? Tokens.ink : Tokens.ink2)
    .accessibilityElement(children: .combine)
  }
}

extension IssueLine where Trailing == EmptyView {
  init(style: IssueCopy.Style, text: String) {
    self.init(style: style, text: text) { EmptyView() }
  }
}

/// A hairline rule in `line` (system dividers draw in their own grey).
struct InspectorRule: View {
  var body: some View {
    Rectangle().fill(Tokens.line.opacity(0.35)).frame(height: 1)
  }
}

/// A plain text button in `ink` semibold: Revert, Show, Use long-press instead, Choose….
struct TextAction: View {
  var title: String
  var semibold = true
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(title).font(Tokens.font(Tokens.typeBody, semibold: semibold)).foregroundStyle(Tokens.ink)
    }
    .buttonStyle(.plain)
  }
}

/// The bordered text field look (system focus rings are the second hue; this draws its own).
struct FieldChrome: ViewModifier {
  var isActive = false
  var ring: Color = Tokens.ink

  func body(content: Content) -> some View {
    content
      .padding(.horizontal, 8)
      .frame(height: 24)
      .background(
        RoundedRectangle(cornerRadius: Tokens.radiusControl).fill(Tokens.padTop.opacity(0.55))
      )
      .overlay(
        RoundedRectangle(cornerRadius: Tokens.radiusControl)
          .strokeBorder(isActive ? ring : Tokens.line.opacity(0.6), lineWidth: isActive ? 2 : 1)
      )
  }
}

extension View {
  func fieldChrome(active: Bool = false, ring: Color = Tokens.ink) -> some View {
    modifier(FieldChrome(isActive: active, ring: ring))
  }
}
