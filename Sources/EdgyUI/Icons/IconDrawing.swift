import CoreGraphics
import Foundation
import SwiftUI

/// One exported SVG drawing from `docs/design/assets/icons/`, kept as its source elements (see
/// `IconData.swift`). Coordinates are the SVG's own user units; `path(scale:)` builds the geometry.
struct IconDrawing: Equatable, Sendable {
  enum Element: Equatable, Sendable {
    /// An SVG `<path>`: the `d` string verbatim.
    case path(String, fill: Bool, stroke: CGFloat)
    case rect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, rx: CGFloat, fill: Bool, stroke: CGFloat)
    case circle(cx: CGFloat, cy: CGFloat, r: CGFloat, fill: Bool, stroke: CGFloat)

    var fills: Bool {
      switch self {
      case .path(_, let fill, _), .rect(_, _, _, _, _, let fill, _), .circle(_, _, _, let fill, _): return fill
      }
    }

    /// Stroke width in viewBox units; 0 = no stroke.
    var strokeWidth: CGFloat {
      switch self {
      case .path(_, _, let stroke), .rect(_, _, _, _, _, _, let stroke), .circle(_, _, _, _, let stroke):
        return stroke
      }
    }

    /// The element's geometry in viewBox units.
    var geometry: Path {
      switch self {
      case .path(let d, _, _): return SVGPathData.path(d)
      case .rect(let x, let y, let width, let height, let rx, _, _):
        let rect = CGRect(x: x, y: y, width: width, height: height)
        return rx > 0 ? Path(roundedRect: rect, cornerRadius: rx, style: .circular) : Path(rect)
      case .circle(let cx, let cy, let r, _, _):
        return Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r))
      }
    }
  }

  /// The SVG viewBox size (its origin is always 0, 0).
  var width: CGFloat
  var height: CGFloat
  var elements: [Element]

  /// Draws every element: fills with `fill`, strokes (round caps and joins, the SVG's width
  /// scaled with the drawing) with `stroke`.
  func draw(
    in context: inout GraphicsContext, scale: CGFloat, fill: GraphicsContext.Shading, stroke: GraphicsContext.Shading
  ) {
    let transform = CGAffineTransform(scaleX: scale, y: scale)
    for element in elements {
      let path = element.geometry.applying(transform)
      if element.fills { context.fill(path, with: fill) }
      if element.strokeWidth > 0 {
        context.stroke(
          path, with: stroke,
          style: StrokeStyle(lineWidth: element.strokeWidth * scale, lineCap: .round, lineJoin: .round))
      }
    }
  }

  /// The painted bounds in viewBox units: each element's geometry, outset by half its stroke.
  var paintedBounds: CGRect {
    elements.reduce(CGRect.null) { bounds, element in
      let box = element.geometry.boundingRect
      let half = element.strokeWidth / 2
      return bounds.union(box.insetBy(dx: -half, dy: -half))
    }
  }
}

/// A small SVG path-data interpreter for the commands the exported icons use (M L H V A Z, absolute
/// and relative) plus C/Q for completeness. Arcs become cubic Béziers (SVG 1.1 implementation notes,
/// F.6.5 endpoint → centre conversion, then ≤90° segments).
enum SVGPathData {
  static func path(_ data: String) -> Path {
    var path = Path()
    var tokens = Tokenizer(data)
    var current = CGPoint.zero
    var start = CGPoint.zero
    var command: Character = "M"
    while let next = tokens.peekCommand() ?? (tokens.hasNumber ? command : nil) {
      if tokens.peekCommand() != nil { tokens.skipCommand() }
      command = next
      let relative = command.isLowercase
      let base = relative ? current : .zero
      func point() -> CGPoint? {
        guard let x = tokens.number(), let y = tokens.number() else { return nil }
        return CGPoint(x: base.x + x, y: base.y + y)
      }
      switch command.uppercased().first! {
      case "M":
        guard let p = point() else { return path }
        path.move(to: p)
        current = p
        start = p
        // Further pairs after a moveto are implicit linetos.
        command = relative ? "l" : "L"
      case "L":
        guard let p = point() else { return path }
        path.addLine(to: p)
        current = p
      case "H":
        guard let x = tokens.number() else { return path }
        current = CGPoint(x: (relative ? current.x : 0) + x, y: current.y)
        path.addLine(to: current)
      case "V":
        guard let y = tokens.number() else { return path }
        current = CGPoint(x: current.x, y: (relative ? current.y : 0) + y)
        path.addLine(to: current)
      case "C":
        guard let c1 = point(), let c2 = point(), let p = point() else { return path }
        path.addCurve(to: p, control1: c1, control2: c2)
        current = p
      case "Q":
        guard let c = point(), let p = point() else { return path }
        path.addQuadCurve(to: p, control: c)
        current = p
      case "A":
        guard let rx = tokens.number(), let ry = tokens.number(), let rotation = tokens.number(),
          let large = tokens.number(), let sweep = tokens.number(), let p = point()
        else { return path }
        addArc(
          to: &path, from: current, to: p, rx: rx, ry: ry, rotation: rotation, largeArc: large != 0,
          sweep: sweep != 0)
        current = p
      case "Z":
        path.closeSubpath()
        current = start
      default:
        return path
      }
    }
    return path
  }

  static func addArc(
    to path: inout Path, from p0: CGPoint, to p1: CGPoint, rx: CGFloat, ry: CGFloat, rotation: CGFloat,
    largeArc: Bool, sweep: Bool
  ) {
    var rx = abs(rx)
    var ry = abs(ry)
    guard rx > 0, ry > 0, p0 != p1 else {
      path.addLine(to: p1)
      return
    }
    let phi = rotation * .pi / 180
    let cosPhi = cos(phi)
    let sinPhi = sin(phi)
    let dx = (p0.x - p1.x) / 2
    let dy = (p0.y - p1.y) / 2
    let x1p = cosPhi * dx + sinPhi * dy
    let y1p = -sinPhi * dx + cosPhi * dy
    let lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
    if lambda > 1 {
      rx *= sqrt(lambda)
      ry *= sqrt(lambda)
    }
    let numerator = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p
    let denominator = rx * rx * y1p * y1p + ry * ry * x1p * x1p
    var coefficient = sqrt(max(0, numerator / denominator))
    if largeArc == sweep { coefficient = -coefficient }
    let cxp = coefficient * rx * y1p / ry
    let cyp = -coefficient * ry * x1p / rx
    let cx = cosPhi * cxp - sinPhi * cyp + (p0.x + p1.x) / 2
    let cy = sinPhi * cxp + cosPhi * cyp + (p0.y + p1.y) / 2
    func angle(_ ux: CGFloat, _ uy: CGFloat, _ vx: CGFloat, _ vy: CGFloat) -> CGFloat {
      atan2(ux * vy - uy * vx, ux * vx + uy * vy)
    }
    let theta1 = angle(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry)
    var delta = angle((x1p - cxp) / rx, (y1p - cyp) / ry, (-x1p - cxp) / rx, (-y1p - cyp) / ry)
    if !sweep && delta > 0 { delta -= 2 * .pi }
    if sweep && delta < 0 { delta += 2 * .pi }
    let segments = max(1, Int((abs(delta) / (.pi / 2)).rounded(.up)))
    let step = delta / CGFloat(segments)
    let k = 4 / 3 * tan(step / 4)
    func onEllipse(_ t: CGFloat) -> CGPoint {
      CGPoint(x: cx + rx * cos(t) * cosPhi - ry * sin(t) * sinPhi, y: cy + rx * cos(t) * sinPhi + ry * sin(t) * cosPhi)
    }
    func derivative(_ t: CGFloat) -> CGPoint {
      CGPoint(x: -rx * sin(t) * cosPhi - ry * cos(t) * sinPhi, y: -rx * sin(t) * sinPhi + ry * cos(t) * cosPhi)
    }
    var t = theta1
    for index in 0..<segments {
      let t2 = t + step
      let a = onEllipse(t)
      let b = index == segments - 1 ? p1 : onEllipse(t2)
      let da = derivative(t)
      let db = derivative(t2)
      path.addCurve(
        to: b, control1: CGPoint(x: a.x + k * da.x, y: a.y + k * da.y),
        control2: CGPoint(x: b.x - k * db.x, y: b.y - k * db.y))
      t = t2
    }
  }

  /// Splits path data into command letters and numbers ("M2.2 6", "A2.8 2.8 0 0 1 11 10", ".7").
  struct Tokenizer {
    private let chars: [Character]
    private var index = 0

    init(_ data: String) { chars = Array(data) }

    private mutating func skipSeparators() {
      while index < chars.count, chars[index] == " " || chars[index] == "," || chars[index].isNewline {
        index += 1
      }
    }

    mutating func peekCommand() -> Character? {
      skipSeparators()
      guard index < chars.count, chars[index].isLetter, chars[index] != "e", chars[index] != "E" else { return nil }
      return chars[index]
    }

    mutating func skipCommand() { index += 1 }

    var hasNumber: Bool {
      var probe = self
      return probe.number() != nil
    }

    mutating func number() -> CGFloat? {
      skipSeparators()
      var text = ""
      var seenDot = false
      var seenExponent = false
      while index < chars.count {
        let c = chars[index]
        if c.isNumber {
          text.append(c)
        } else if (c == "-" || c == "+") && (text.isEmpty || text.last == "e" || text.last == "E") {
          text.append(c)
        } else if c == "." && !seenDot && !seenExponent {
          seenDot = true
          text.append(c)
        } else if (c == "e" || c == "E") && !seenExponent && !text.isEmpty {
          seenExponent = true
          text.append(c)
        } else {
          break
        }
        index += 1
      }
      return Double(text).map { CGFloat($0) }
    }
  }
}
