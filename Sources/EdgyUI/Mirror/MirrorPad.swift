import AppKit
import EdgyCore
import EdgyRuntime
import SwiftUI

/// Publishes every zone's drawn bar or tile as an anchor, so the action picker (batch 15) can point
/// its popover arrow at the zone it sets (bone 5).
///
/// Read it from any ancestor of `PadMirrorView`:
/// ```swift
/// PadMirrorView(model: model)
///   .overlayPreferenceValue(PadMirrorView.ZoneAnchor.self) { anchors in
///     GeometryReader { proxy in
///       if let target = model.picking, let anchor = anchors[target.zone] {
///         let rect = proxy[anchor]  // the zone's bar, in this view's space
///         …
///       }
///     }
///   }
/// ```
/// Keys are zones exactly as drawn: a split edge publishes `.edge(e, segment: i, segments: n)`
/// for each segment, and a whole edge publishes `.edge(e, segment: 0, segments: 1)`.
public struct ZoneAnchorKey: PreferenceKey {
  public static let defaultValue: [Zone: Anchor<CGRect>] = [:]

  public static func reduce(value: inout [Zone: Anchor<CGRect>], nextValue: () -> [Zone: Anchor<CGRect>]) {
    value.merge(nextValue()) { $1 }
  }
}

extension PadMirrorView {
  /// The preference key carrying each zone's frame. See `ZoneAnchorKey`.
  public typealias ZoneAnchor = ZoneAnchorKey
}

/// One line centred on the pad (§ System states: no trackpad).
struct MirrorMessage: Equatable {
  var text: String
}

/// How a contact is drawn (bone 4, § Test Mode).
enum ContactMark: Equatable {
  /// Recognized or claimed: a filled accent contact, pressed in slightly, no glow.
  case recognized
  /// Dry run: a 2 pt accent outline, no fill. (Wired once the model exposes dry run; see blockers.)
  case dryRun
  /// Rejected: a hollow `ink2` circle with a strike.
  case rejected
  /// On the pad but not a gesture (ordinary pointer use, or still being judged): a `line` hairline
  /// circle, no strike. Not specced; kept quiet so recognized stays the loudest mark.
  case down

  init(_ state: LiveTouch.State) {
    switch state {
    case .claimed: self = .recognized
    case .rejected: self = .rejected
    case .down: self = .down
    }
  }
}

/// The pad drawing shared by the settings mirror, the popover's mini mirror and the preset mirror.
/// Everything is laid out in pad points from `MirrorGeometry` (origin top-left).
///
/// **Tabs are one shape with their zone** (bone 3). A side strip's label and a corner's label are
/// drawn in the label layer as the union of the bar (or tile) and the tab, so the tab grows from
/// the zone in the same fill with no seam or notch, takes the zone's current fill (idle or lit),
/// and the live accent stroke and the selection ring trace the joined outline. Top and bottom
/// labels sit inside their bar, which the zone layer draws.
struct MirrorPad: View {
  var geometry: MirrorGeometry
  var zones: [MirrorZone]
  var selected: Zone?
  var touches: [LiveTouch] = []
  /// 40% (§ System states: disabled, paused, off in app).
  var faded = false
  /// No trackpad: a dashed pad outline instead of the slab.
  var dashedOutline = false
  var showsLabels = true
  var showsIcons = true
  var message: MirrorMessage?
  /// `nil` = not interactive (mini mirror, preset mirror).
  var onSelect: ((Zone) -> Void)?
  /// Publish zone and mirror bounds for the action picker (batch 15's `PickerAnchorKey`). The
  /// settings mirror only.
  var publishesPickerAnchors = false

  /// Fully faded per BRIEF: "The mirror fades to 40%".
  static let fadedOpacity = 0.4
  /// The fade at the end of a label that still doesn't fit (bone 3).
  static let labelFade: CGFloat = 12
  /// Longest tab, in millimetres of pad: side strips, corners.
  static let sideTabMaxMM: CGFloat = 40
  static let cornerTabMaxMM: CGFloat = 26
  /// The `ink` selection ring sits this far outside the zone's outline, this thick.
  static let ringGap: CGFloat = 1.5
  static let ringWidth: CGFloat = 2
  static let space = "MirrorPad"

  private var full: Bool { geometry.pointsPerMM >= Tokens.mirrorPointsPerMM }

  var body: some View {
    let size = geometry.size
    let mapped = Set(zones.filter { $0.style == .mapped }.map(\.zone))
    let live = Set(
      touches.filter { $0.state == .claimed }.compactMap { geometry.zone(atNormalized: $0.position, mapped: mapped) })
    ZStack(alignment: .topLeading) {
      ZStack(alignment: .topLeading) {
        slab(size)
        if !(dashedOutline && !showsLabels) {
          ForEach(zones.filter { !$0.isCorner }) { shape($0, live: live.contains($0.zone)) }
          ForEach(zones.filter(\.isCorner)) { shape($0, live: live.contains($0.zone)) }
          if let zone = zones.first(where: { $0.zone == selected }), !isTabbed(zone) { selectionRing(zone) }
          if onSelect != nil {
            ForEach(zones.filter { !$0.isCorner }) { hitArea($0) }
            ForEach(zones.filter(\.isCorner)) { hitArea($0) }
          }
          if showsLabels { ForEach(zones) { label($0, live: live.contains($0.zone)) } }
        }
      }
      // One fade for the whole pad, not per layer (overlaps would show through).
      .compositingGroup()
      .opacity(faded ? Self.fadedOpacity : 1)
      if !dashedOutline {
        ForEach(touches, id: \.id) { contact($0) }.allowsHitTesting(false)
      }
      if let message { messageView(message, size: size) }
    }
    .frame(width: size.width, height: size.height, alignment: .topLeading)
    .coordinateSpace(name: Self.space)
    .modifier(PickerMirrorAnchor(enabled: publishesPickerAnchors))
  }

  // MARK: Slab

  /// The soft lower edge: a few layers of a dark, low-opacity copy of the slab, each a little
  /// lower and narrower, so the depth falls below the slab only (top-left light) and never reads
  /// as a lighter halo in dark mode. Drawn as plain shapes, not a layer shadow, so the offset
  /// can't flip in a non-flipped host. Neutral black: a shadow is the absence of light, not a hue.
  static func shadowLayers(full: Bool) -> [(offset: CGFloat, inset: CGFloat, opacity: Double)] {
    let count = full ? 6 : 3
    return (1...count).map { i in (CGFloat(i) * (full ? 1 : 0.7), CGFloat(i), full ? 0.035 : 0.05) }
  }

  @ViewBuilder private func slab(_ size: CGSize) -> some View {
    let shape = RoundedRectangle(cornerRadius: Tokens.radiusPlate, style: .continuous)
    if dashedOutline {
      shape.strokeBorder(Tokens.line, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
        .frame(width: size.width, height: size.height)
    } else {
      ZStack(alignment: .topLeading) {
        ForEach(Array(Self.shadowLayers(full: full).enumerated()), id: \.offset) { _, layer in
          shape.fill(Color.black.opacity(layer.opacity))
            .frame(width: size.width - 2 * layer.inset, height: size.height)
            .offset(x: layer.inset, y: layer.offset)
        }
        shape
          .fill(
            LinearGradient(
              colors: [Tokens.padTop, Tokens.padBottom], startPoint: .topLeading, endPoint: .bottomTrailing)
          )
          // Top-left light.
          .overlay(
            shape.fill(
              RadialGradient(
                colors: [Tokens.padTop.opacity(0.9), Tokens.padTop.opacity(0)], center: .topLeading, startRadius: 0,
                endRadius: max(size.width, size.height) * 0.7))
          )
          // Rim: faint at the top, a little heavier along the lower edge.
          .overlay(
            shape.strokeBorder(
              LinearGradient(
                colors: [Tokens.line.opacity(0.15), Tokens.line.opacity(0.4)], startPoint: .top, endPoint: .bottom),
              lineWidth: 1)
          )
          .frame(width: size.width, height: size.height)
      }
      .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
  }

  // MARK: Zones

  /// A side strip or corner whose label is a tab: drawn with its tab as one shape in the label layer.
  func isTabbed(_ zone: MirrorZone) -> Bool {
    showsLabels && zone.label != nil && !labelPlacement(zone).inBar
  }

  /// Corner tiles keep their corners square-ish at any size: the radius never passes 30% of the
  /// tile (at preset size the control radius would turn a tile into a dot).
  func tileRadius(_ rect: CGRect) -> CGFloat {
    min(Tokens.radiusControl, min(rect.width, rect.height) * 0.3)
  }

  @ViewBuilder private func shape(_ zone: MirrorZone, live: Bool) -> some View {
    let rect = geometry.shapeFrame(for: zone.zone)
    Group {
      if isTabbed(zone) {
        Color.clear  // drawn with its tab in the label layer
      } else if zone.isCorner {
        cornerTile(zone, live: live, rect: rect)
      } else {
        edgeShape(zone, live: live, rect: rect)
      }
    }
    .frame(width: rect.width, height: rect.height)
    .anchorPreference(key: ZoneAnchorKey.self, value: .bounds) { [zone.zone: $0] }
    .modifier(PickerZoneAnchor(zone: zone.zone, enabled: publishesPickerAnchors))
    .offset(x: rect.minX, y: rect.minY)
    .allowsHitTesting(false)
  }

  /// Zone bars have fully rounded ends (Tokens: "use Capsule()"). Drawn as a circular rounded
  /// rectangle with radius = half the short side, which is a capsule; a stroked `Capsule` renders
  /// flattened ends in a hosting view at this aspect ratio.
  static func pill(_ rect: CGRect) -> RoundedRectangle {
    RoundedRectangle(cornerRadius: min(rect.width, rect.height) / 2, style: .circular)
  }

  @ViewBuilder private func edgeShape(_ zone: MirrorZone, live: Bool, rect: CGRect) -> some View {
    let pill = Self.pill(rect)
    switch zone.style {
    case .mapped:
      pill.fill(Tokens.bar)
        .overlay { if live { pill.fill(Tokens.accent.opacity(0.4)) } }
        .overlay { if live { pill.strokeBorder(Tokens.accent, lineWidth: 1.5) } }
    case .unmapped, .offHere:
      pill.strokeBorder(Tokens.line, lineWidth: 1)
    }
  }

  @ViewBuilder private func cornerTile(_ zone: MirrorZone, live: Bool, rect: CGRect) -> some View {
    let tile = RoundedRectangle(cornerRadius: tileRadius(rect), style: .continuous)
    switch zone.style {
    case .mapped:
      tile.fill(Tokens.bar)
        .overlay { if live { tile.fill(Tokens.accent.opacity(0.4)) } }
        .overlay { if live { tile.strokeBorder(Tokens.accent, lineWidth: 1.5) } }
        .overlay { cornerIcon(zone) }
    case .unmapped:
      // Dashed means pass-through and nothing else.
      tile.strokeBorder(Tokens.line, style: StrokeStyle(lineWidth: 1, dash: full ? [4, 3] : [2, 2]))
    case .offHere:
      tile.strokeBorder(Tokens.line, lineWidth: 1)
    }
  }

  @ViewBuilder private func cornerIcon(_ zone: MirrorZone) -> some View {
    if showsIcons, let symbol = zone.symbol {
      Image(systemName: symbol)
        .font(Tokens.font(full ? Tokens.typeValue : Tokens.typeBody, semibold: true))
        .imageScale(full ? .medium : .small)
        .foregroundStyle(Tokens.ink)
    }
  }

  /// The `ink` ring, outside the bar with a visible gap, so it never reads as the live border.
  @ViewBuilder private func selectionRing(_ zone: MirrorZone) -> some View {
    let shape = geometry.shapeFrame(for: zone.zone)
    let ring = shape.insetBy(dx: -(Self.ringGap + Self.ringWidth), dy: -(Self.ringGap + Self.ringWidth))
    Group {
      if zone.isCorner {
        RoundedRectangle(cornerRadius: tileRadius(shape) + Self.ringGap + Self.ringWidth, style: .continuous)
          .strokeBorder(Tokens.ink, lineWidth: Self.ringWidth)
      } else {
        Self.pill(ring).strokeBorder(Tokens.ink, lineWidth: Self.ringWidth)
      }
    }
    .frame(width: ring.width, height: ring.height)
    .offset(x: ring.minX, y: ring.minY)
    .allowsHitTesting(false)
  }

  /// The click target: the zone as the recognizer sees it (`PadLayout`), corners on top of edges.
  @ViewBuilder private func hitArea(_ zone: MirrorZone) -> some View {
    if let onSelect {
      let frame = geometry.frame(for: zone.zone)
      Color.clear
        .frame(width: frame.width, height: frame.height)
        .contentShape(Rectangle())
        .onTapGesture { onSelect(zone.zone) }
        .accessibilityElement()
        .accessibilityLabel(ZoneName.text(for: zone.zone))
        .accessibilityValue(zone.label ?? "")
        .accessibilityAddTraits(.isButton)
        .offset(x: frame.minX, y: frame.minY)
    }
  }

  // MARK: Labels (bone 3: joined to their zone, never floating, never rotated, ≥13 pt)

  @ViewBuilder private func label(_ zone: MirrorZone, live: Bool) -> some View {
    if zone.label != nil {
      let placement = labelPlacement(zone)
      let fit = fittedLabel(zone, placement: placement)
      Group {
        if placement.inBar {
          labelText(zone, fit: fit).padding(.horizontal, 8).padding(.vertical, 4)
        } else {
          labelText(zone, fit: fit)
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background { tabBackground(zone, live: live) }
        }
      }
      .fixedSize()
      .alignmentGuide(HorizontalAlignment.leading) { d in d.width * placement.anchor.x - placement.point.x }
      .alignmentGuide(VerticalAlignment.top) { d in d.height * placement.anchor.y - placement.point.y }
      .onTapGesture { onSelect?(zone.zone) }
      .allowsHitTesting(onSelect != nil)
    }
  }

  /// The label's text as it fits: the full name, or a shorter form, or the last form clipped
  /// with a 12 pt fade (never "…" for a cut, bone 3).
  struct FittedLabel: Equatable {
    var text: String
    /// Width to clip to, `nil` when the text fits.
    var clipWidth: CGFloat?
  }

  /// Room for the label's text (without the tab's padding and marks).
  func labelRoom(_ zone: MirrorZone, placement: LabelPlacement) -> CGFloat {
    let marks = (zone.overridden ? 10 : 0) + (zone.unavailable ? 18 : 0)
    if placement.inBar { return max(geometry.shapeFrame(for: zone.zone).width - 32 - CGFloat(marks), 0) }
    let maxMM = zone.isCorner ? Self.cornerTabMaxMM : Self.sideTabMaxMM
    return max(maxMM * geometry.pointsPerMM - 18 - CGFloat(marks), 0)
  }

  func fittedLabel(_ zone: MirrorZone, placement: LabelPlacement) -> FittedLabel {
    Self.fit(zone.labelForms, room: labelRoom(zone, placement: placement))
  }

  /// The first form whose width fits `room`, else the last form clipped to `room`.
  static func fit(_ forms: [String], room: CGFloat) -> FittedLabel {
    for form in forms where textWidth(form) <= room { return FittedLabel(text: form, clipWidth: nil) }
    return FittedLabel(text: forms.last ?? "", clipWidth: room)
  }

  /// The drawn width of a label in the tab type (13 semibold).
  static func textWidth(_ text: String) -> CGFloat {
    let font = NSFont.systemFont(ofSize: Tokens.typeBody, weight: .semibold)
    return ceil((text as NSString).size(withAttributes: [.font: font]).width)
  }

  @ViewBuilder private func labelText(_ zone: MirrorZone, fit: FittedLabel) -> some View {
    let quiet = zone.style == .offHere || zone.unavailable
    HStack(spacing: 5) {
      if zone.overridden { Circle().fill(Tokens.ink).frame(width: 5, height: 5) }
      if zone.unavailable {
        Image(systemName: "circle.slash").font(Tokens.font(Tokens.typeBody)).foregroundStyle(Tokens.ink2)
          .accessibilityLabel("Unavailable")
      }
      let text = Text(fit.text)
        .font(Tokens.font(Tokens.typeBody, semibold: zone.style != .offHere))
        .foregroundStyle(quiet ? Tokens.ink2 : Tokens.ink)
        .lineLimit(1)
        .fixedSize()
      if let width = fit.clipWidth {
        text.frame(width: width, alignment: .leading).clipped()
          .mask(
            LinearGradient(
              stops: [
                .init(color: .black, location: 0),
                .init(color: .black, location: max(0, 1 - Self.labelFade / max(width, 1))),
                .init(color: .clear, location: 1),
              ], startPoint: .leading, endPoint: .trailing))
      } else {
        text
      }
    }
  }

  /// The tab and its zone as one shape: `bar` fill (lit when live, accent stroke around both), or
  /// a hairline outline with no fill for "Off here". A corner keeps its icon; a selected zone gets
  /// the `ink` ring around the joined outline.
  @ViewBuilder private func tabBackground(_ zone: MirrorZone, live: Bool) -> some View {
    GeometryReader { proxy in
      let origin = proxy.frame(in: .named(Self.space)).origin
      let rect = geometry.shapeFrame(for: zone.zone).offsetBy(dx: -origin.x, dy: -origin.y)
      let radius = zone.isCorner ? tileRadius(rect) : min(rect.width, rect.height) / 2
      let union = TabUnion(zone: rect, zoneRadius: radius, tabRadius: Tokens.radiusControl)
      ZStack(alignment: .topLeading) {
        switch zone.style {
        case .mapped:
          union.fill(Tokens.bar)
          if live {
            union.fill(Tokens.accent.opacity(0.4))
            union.stroke(Tokens.accent, lineWidth: 1.5)
          }
          if zone.isCorner { cornerIcon(zone).position(x: rect.midX, y: rect.midY) }
        case .unmapped, .offHere:
          union.stroke(Tokens.line, lineWidth: 1)
        }
        if zone.zone == selected {
          TabUnionRing(union: union, gap: Self.ringGap, width: Self.ringWidth).fill(Tokens.ink)
        }
      }
    }
  }

  struct LabelPlacement {
    /// The point in pad space where `anchor` of the label sits.
    var point: CGPoint
    var anchor: UnitPoint
    var inBar: Bool
  }

  /// Where a zone's label goes. Side strips: a tab growing from the strip's inner side at the
  /// bar's middle, overlapping the bar so the two are one shape. Top/bottom: centred inside the
  /// bar (an "Off here" too, inside its hairline). Corners: a tab flush under (or over) the tile,
  /// starting inside the tile's span and running toward the pad's middle, clear of the side strip.
  func labelPlacement(_ zone: MirrorZone) -> LabelPlacement {
    let bar = geometry.shapeFrame(for: zone.zone)
    let join: CGFloat = Tokens.radiusControl
    let size = geometry.size
    let stripDepth = geometry.layout.edgeWidthMM * geometry.pointsPerMM
    // The tab's start, measured from the pad's side: inside the tile's x span (short of its far
    // rounded corner), clear of the side bar.
    let tileReach = bar.minX < size.width / 2 ? bar.maxX : size.width - bar.minX
    let inset = min(stripDepth, tileReach - tileRadius(bar) - 2)
    let overlap: CGFloat = 2
    switch zone.zone {
    case .edge(.left, _, _):
      return LabelPlacement(point: CGPoint(x: bar.maxX - join, y: bar.midY), anchor: .leading, inBar: false)
    case .edge(.right, _, _):
      return LabelPlacement(point: CGPoint(x: bar.minX + join, y: bar.midY), anchor: .trailing, inBar: false)
    case .edge(.top, _, _), .edge(.bottom, _, _):
      return LabelPlacement(point: CGPoint(x: bar.midX, y: bar.midY), anchor: .center, inBar: true)
    case .corner(.topLeft):
      return LabelPlacement(point: CGPoint(x: inset, y: bar.maxY - overlap), anchor: .topLeading, inBar: false)
    case .corner(.topRight):
      return LabelPlacement(
        point: CGPoint(x: size.width - inset, y: bar.maxY - overlap), anchor: .topTrailing, inBar: false)
    case .corner(.bottomLeft):
      return LabelPlacement(point: CGPoint(x: inset, y: bar.minY + overlap), anchor: .bottomLeading, inBar: false)
    case .corner(.bottomRight):
      return LabelPlacement(
        point: CGPoint(x: size.width - inset, y: bar.minY + overlap), anchor: .bottomTrailing, inBar: false)
    }
  }

  // MARK: Touches (bone 4)

  @ViewBuilder private func contact(_ touch: LiveTouch) -> some View {
    let point = geometry.point(forNormalized: touch.position)
    let size = geometry.contactSize
    ContactView(mark: ContactMark(touch.state), full: full)
      .frame(width: size.width, height: size.height)
      .offset(x: point.x - size.width / 2, y: point.y - size.height / 2)
  }

  // MARK: Message

  @ViewBuilder private func messageView(_ message: MirrorMessage, size: CGSize) -> some View {
    Text(message.text)
      .font(Tokens.font(Tokens.typeBody))
      .foregroundStyle(Tokens.ink)
      .multilineTextAlignment(.center)
      .frame(width: size.width, height: size.height)
  }
}

/// A tab (the shape's own rect) joined to its zone's bar or tile: one outline, no seam.
struct TabUnion: Shape {
  var zone: CGRect
  var zoneRadius: CGFloat
  var tabRadius: CGFloat

  func cgPath(tab rect: CGRect) -> CGPath {
    func rounded(_ r: CGRect, _ radius: CGFloat) -> CGPath {
      let clamped = max(0, min(radius, r.width / 2, r.height / 2))
      return CGPath(roundedRect: r, cornerWidth: clamped, cornerHeight: clamped, transform: nil)
    }
    return rounded(rect, tabRadius).union(rounded(zone, zoneRadius))
  }

  func path(in rect: CGRect) -> Path { Path(cgPath(tab: rect)) }
}

/// The selection ring around a joined tab and zone: a band `gap` to `gap + width` outside it.
struct TabUnionRing: Shape {
  var union: TabUnion
  var gap: CGFloat
  var width: CGFloat

  func path(in rect: CGRect) -> Path {
    let outline = union.cgPath(tab: rect)
    let outer = outline.copy(strokingWithWidth: 2 * (gap + width), lineCap: .round, lineJoin: .round, miterLimit: 4)
    let inner = outline.copy(strokingWithWidth: 2 * gap, lineCap: .round, lineJoin: .round, miterLimit: 4)
    return Path(outer.subtracting(inner).subtracting(outline))
  }
}

/// `.pickerAnchor(for:)` on a zone's drawn bar or tile, when the mirror hosts the picker.
struct PickerZoneAnchor: ViewModifier {
  var zone: Zone
  var enabled: Bool

  func body(content: Content) -> some View {
    if enabled { content.pickerAnchor(for: zone) } else { content }
  }
}

/// `.pickerMirrorBounds()` for the whole pad, when the mirror hosts the picker. Published from a
/// background sibling, not on the pad itself: `anchorPreference` replaces its subtree's value for
/// the key, so wrapping the pad would erase every zone's `.pickerAnchor(for:)`.
struct PickerMirrorAnchor: ViewModifier {
  var enabled: Bool

  func body(content: Content) -> some View {
    if enabled { content.background(Color.clear.pickerMirrorBounds()) } else { content }
  }
}

/// A single contact mark.
struct ContactView: View {
  var mark: ContactMark
  var full: Bool

  var body: some View {
    switch mark {
    case .recognized:
      Ellipse().fill(Tokens.accent)
        // Pressed in: shade just inside the top rim, a fine darker rim, a slab-coloured ring outside.
        .overlay(
          Ellipse().fill(
            LinearGradient(
              colors: [Tokens.ink.opacity(0.22), Tokens.ink.opacity(0)], startPoint: .top, endPoint: .center))
        )
        .overlay(Ellipse().strokeBorder(Tokens.ink.opacity(0.3), lineWidth: 1))
        .padding(full ? 2 : 1)
        .background(Ellipse().fill(Tokens.padTop))
    case .dryRun:
      Ellipse().strokeBorder(Tokens.accent, lineWidth: 2)
    case .rejected:
      Ellipse().strokeBorder(Tokens.ink2, lineWidth: 1.5)
        .overlay(StrikeShape().stroke(Tokens.ink2, style: StrokeStyle(lineWidth: 1.5, lineCap: .round)))
    case .down:
      Ellipse().strokeBorder(Tokens.line, lineWidth: 1)
    }
  }
}

/// The rejection strike: a diagonal across the circle, bottom-left to top-right.
struct StrikeShape: Shape {
  func path(in rect: CGRect) -> Path {
    let inset = rect.width * 0.15
    var path = Path()
    path.move(to: CGPoint(x: rect.minX + inset, y: rect.maxY - inset))
    path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.minY + inset))
    return path
  }
}
