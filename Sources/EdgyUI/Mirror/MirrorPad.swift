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

/// One line centred on the pad, with an optional text button (§ System states, § App profiles).
struct MirrorMessage: Equatable {
  var text: String
  var button: String?

  static func == (lhs: Self, rhs: Self) -> Bool { lhs.text == rhs.text && lhs.button == rhs.button }
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
  var onMessageButton: (() -> Void)?
  /// `nil` = not interactive (mini mirror, preset mirror).
  var onSelect: ((Zone) -> Void)?

  /// Fully faded per BRIEF: "The mirror fades to 40%".
  static let fadedOpacity = 0.4

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
          if onSelect != nil {
            ForEach(zones.filter { !$0.isCorner }) { hitArea($0) }
            ForEach(zones.filter(\.isCorner)) { hitArea($0) }
          }
          if showsLabels { ForEach(zones) { label($0, live: live.contains($0.zone)) } }
        }
      }
      .opacity(faded ? Self.fadedOpacity : 1)
      if !dashedOutline {
        ForEach(touches, id: \.id) { contact($0) }.allowsHitTesting(false)
      }
      if let message { messageView(message, size: size) }
    }
    .frame(width: size.width, height: size.height, alignment: .topLeading)
  }

  // MARK: Slab

  @ViewBuilder private func slab(_ size: CGSize) -> some View {
    let shape = RoundedRectangle(cornerRadius: Tokens.radiusPlate, style: .continuous)
    if dashedOutline {
      shape.strokeBorder(Tokens.line, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
        .frame(width: size.width, height: size.height)
    } else {
      shape
        .fill(LinearGradient(colors: [Tokens.padTop, Tokens.padBottom], startPoint: .topLeading, endPoint: .bottomTrailing))
        // Top-left light.
        .overlay(
          shape.fill(
            RadialGradient(
              colors: [Tokens.padTop.opacity(0.9), Tokens.padTop.opacity(0)], center: .topLeading, startRadius: 0,
              endRadius: max(size.width, size.height) * 0.7)))
        // Rim: lighter at the top, a little heavier along the lower edge.
        .overlay(
          shape.strokeBorder(
            LinearGradient(
              colors: [Tokens.line.opacity(0.18), Tokens.line.opacity(0.5)], startPoint: .top, endPoint: .bottom),
            lineWidth: 1))
        // Soft lower edge: a lip just below the slab, then a short soft shadow (no halo).
        .background(shape.fill(Tokens.line.opacity(0.3)).offset(y: full ? 2 : 1))
        .shadow(color: Tokens.ink.opacity(0.14), radius: full ? 8 : 4, y: full ? 4 : 2)
        .frame(width: size.width, height: size.height)
    }
  }

  // MARK: Zones

  @ViewBuilder private func shape(_ zone: MirrorZone, live: Bool) -> some View {
    let rect = geometry.shapeFrame(for: zone.zone)
    let isSelected = zone.zone == selected
    Group {
      if zone.isCorner {
        cornerTile(zone, live: live, rect: rect)
      } else {
        edgeBar(zone, live: live)
      }
    }
    .frame(width: rect.width, height: rect.height)
    .anchorPreference(key: ZoneAnchorKey.self, value: .bounds) { [zone.zone: $0] }
    .overlay { if isSelected { selectionRing(zone, rect: rect) } }
    .offset(x: rect.minX, y: rect.minY)
    .allowsHitTesting(false)
  }

  @ViewBuilder private func edgeBar(_ zone: MirrorZone, live: Bool) -> some View {
    switch zone.style {
    case .mapped:
      Capsule().fill(Tokens.bar)
        .overlay { if live { Capsule().fill(Tokens.accent.opacity(0.4)) } }
        .overlay { if live { Capsule().strokeBorder(Tokens.accent, lineWidth: 1.5) } }
    case .unmapped, .offHere:
      Capsule().strokeBorder(Tokens.line, lineWidth: 1)
    }
  }

  @ViewBuilder private func cornerTile(_ zone: MirrorZone, live: Bool, rect: CGRect) -> some View {
    let tile = RoundedRectangle(cornerRadius: Tokens.radiusControl, style: .continuous)
    switch zone.style {
    case .mapped:
      tile.fill(Tokens.bar)
        .overlay { if live { tile.fill(Tokens.accent.opacity(0.4)) } }
        .overlay { if live { tile.strokeBorder(Tokens.accent, lineWidth: 1.5) } }
        .overlay {
          if showsIcons, let symbol = zone.symbol {
            Image(systemName: symbol)
              .font(Tokens.font(full ? Tokens.typeValue : Tokens.typeBody, semibold: true))
              .imageScale(full ? .medium : .small)
              .foregroundStyle(Tokens.ink)
          }
        }
    case .unmapped:
      // Dashed means pass-through and nothing else.
      tile.strokeBorder(Tokens.line, style: StrokeStyle(lineWidth: 1, dash: full ? [4, 3] : [2, 2]))
    case .offHere:
      tile.strokeBorder(Tokens.line, lineWidth: 1)
    }
  }

  /// The `ink` ring, outside the bar with a visible gap, so it never reads as the live border.
  @ViewBuilder private func selectionRing(_ zone: MirrorZone, rect: CGRect) -> some View {
    let outset: CGFloat = 3.5
    Group {
      if zone.isCorner {
        RoundedRectangle(cornerRadius: Tokens.radiusControl, style: .continuous).strokeBorder(Tokens.ink, lineWidth: 2)
      } else {
        Capsule().strokeBorder(Tokens.ink, lineWidth: 2)
      }
    }
    .padding(-outset)
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
    if let text = zone.label {
      let placement = labelPlacement(zone)
      labelBody(zone, text: text, live: live, inBar: placement.inBar)
        .fixedSize()
        .frame(maxWidth: placement.inBar ? geometry.shapeFrame(for: zone.zone).width - 16 : nil)
        .alignmentGuide(HorizontalAlignment.leading) { d in d.width * placement.anchor.x - placement.point.x }
        .alignmentGuide(VerticalAlignment.top) { d in d.height * placement.anchor.y - placement.point.y }
        .onTapGesture { onSelect?(zone.zone) }
        .allowsHitTesting(onSelect != nil)
    }
  }

  @ViewBuilder private func labelBody(_ zone: MirrorZone, text: String, live: Bool, inBar: Bool) -> some View {
    let off = zone.style == .offHere
    let content = HStack(spacing: 5) {
      if zone.overridden { Circle().fill(Tokens.ink).frame(width: 5, height: 5) }
      Text(text)
        .font(Tokens.font(Tokens.typeBody, semibold: !off))
        .foregroundStyle(off ? Tokens.ink2 : Tokens.ink)
        .lineLimit(1)
        .truncationMode(.tail)
    }
    if inBar || off {
      // Inside the top/bottom bar, or "Off here" beside a hairline zone (text only, render S1).
      content.padding(.horizontal, 8).padding(.vertical, 4)
    } else {
      let tab = RoundedRectangle(cornerRadius: Tokens.radiusControl, style: .continuous)
      content
        .padding(.horizontal, 9).padding(.vertical, 4)
        .background(tab.fill(Tokens.bar))
        .background { if live { tab.fill(Tokens.accent.opacity(0.4)).background(tab.fill(Tokens.bar)) } }
        .overlay { if live { tab.strokeBorder(Tokens.accent, lineWidth: 1.5) } }
    }
  }

  struct LabelPlacement {
    /// The point in pad space where `anchor` of the label sits.
    var point: CGPoint
    var anchor: UnitPoint
    var inBar: Bool
  }

  /// Where a zone's label goes. Side strips: a tab growing from the strip's inner side at the
  /// bar's middle, overlapping the bar so the two read as one shape. Top/bottom: centred inside the
  /// bar. Corners: a tab hanging from the tile toward the pad's middle, beside the side strip.
  func labelPlacement(_ zone: MirrorZone) -> LabelPlacement {
    let bar = geometry.shapeFrame(for: zone.zone)
    let join: CGFloat = Tokens.radiusControl
    let size = geometry.size
    let stripDepth = geometry.layout.edgeWidthMM * geometry.pointsPerMM
    switch zone.zone {
    case .edge(.left, _, _):
      return LabelPlacement(point: CGPoint(x: bar.maxX - join, y: bar.midY), anchor: .leading, inBar: false)
    case .edge(.right, _, _):
      return LabelPlacement(point: CGPoint(x: bar.minX + join, y: bar.midY), anchor: .trailing, inBar: false)
    case .edge(.top, _, _), .edge(.bottom, _, _):
      return LabelPlacement(point: CGPoint(x: bar.midX, y: bar.midY), anchor: .center, inBar: zone.style == .mapped)
    case .corner(.topLeft):
      return LabelPlacement(point: CGPoint(x: stripDepth, y: bar.maxY - 2), anchor: .topLeading, inBar: false)
    case .corner(.topRight):
      return LabelPlacement(
        point: CGPoint(x: size.width - stripDepth, y: bar.maxY - 2), anchor: .topTrailing, inBar: false)
    case .corner(.bottomLeft):
      return LabelPlacement(point: CGPoint(x: stripDepth, y: bar.minY + 2), anchor: .bottomLeading, inBar: false)
    case .corner(.bottomRight):
      return LabelPlacement(
        point: CGPoint(x: size.width - stripDepth, y: bar.minY + 2), anchor: .bottomTrailing, inBar: false)
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
    HStack(spacing: 10) {
      Text(message.text).font(Tokens.font(Tokens.typeBody)).foregroundStyle(Tokens.ink)
      if let button = message.button {
        Button(button) { onMessageButton?() }
          .buttonStyle(.plain)
          .font(Tokens.font(Tokens.typeBody, semibold: true))
          .foregroundStyle(Tokens.ink)
      }
    }
    .multilineTextAlignment(.center)
    .frame(width: size.width, height: size.height)
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
            LinearGradient(colors: [Tokens.ink.opacity(0.22), Tokens.ink.opacity(0)], startPoint: .top, endPoint: .center))
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
