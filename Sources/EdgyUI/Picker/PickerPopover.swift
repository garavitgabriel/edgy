import EdgyCore
import SwiftUI

/// Where zones and the mirror are, for anchoring the picker (bone 5).
///
/// The mirror (batch 14) publishes each zone's bounds with `.pickerAnchor(for:)` and its own
/// bounds with `.pickerMirrorBounds()`; the window (batch 16) puts `.actionPickerHost(model:)` on
/// the view that contains the mirror. Until the mirror lands, any view can publish a placeholder rect.
public struct PickerAnchors {
  public var zones: [Zone: Anchor<CGRect>] = [:]
  public var mirror: Anchor<CGRect>?
  /// The pad's interior: between the inner edges of the top and bottom bars (the picker is never
  /// taller, § Picker at catalog scale).
  public var interior: Anchor<CGRect>?
  /// Label tabs that grow out of a zone (corner and side tabs): the picker clears them too.
  public var tabs: [Zone: Anchor<CGRect>] = [:]
}

public struct PickerAnchorKey: PreferenceKey {
  public static var defaultValue: PickerAnchors { PickerAnchors() }
  public static func reduce(value: inout PickerAnchors, nextValue: () -> PickerAnchors) {
    let next = nextValue()
    value.zones.merge(next.zones) { _, new in new }
    value.tabs.merge(next.tabs) { _, new in new }
    value.mirror = next.mirror ?? value.mirror
    value.interior = next.interior ?? value.interior
  }
}

extension View {
  /// Publishes this view's bounds as `zone`'s anchor for the picker.
  public func pickerAnchor(for zone: Zone) -> some View {
    anchorPreference(key: PickerAnchorKey.self, value: .bounds) { PickerAnchors(zones: [zone: $0]) }
  }

  /// Publishes this view's bounds as the mirror's (the picker is at most its height − 16 pt).
  public func pickerMirrorBounds() -> some View {
    anchorPreference(key: PickerAnchorKey.self, value: .bounds) { PickerAnchors(mirror: $0) }
  }

  /// Publishes this view's bounds as the pad interior (the picker's height cap).
  public func pickerInterior() -> some View {
    anchorPreference(key: PickerAnchorKey.self, value: .bounds) { PickerAnchors(interior: $0) }
  }

  /// Publishes this view's bounds as `zone`'s label tab (the picker keeps clear of it).
  public func pickerTab(for zone: Zone) -> some View {
    anchorPreference(key: PickerAnchorKey.self, value: .bounds) { PickerAnchors(tabs: [zone: $0]) }
  }

  /// Shows `ActionPickerView` for `model.picking`, anchored to the picked zone with an arrow,
  /// inside this view's bounds (the window): never over its zone or the neighbouring zones when
  /// there is room, never outside. A click outside or Esc closes it.
  public func actionPickerHost(model: SettingsModel) -> some View {
    overlayPreferenceValue(PickerAnchorKey.self) { anchors in
      PickerPopoverLayer(model: model, anchors: anchors)
    }
  }
}

private struct PickerPopoverLayer: View {
  @Bindable var model: SettingsModel
  var anchors: PickerAnchors

  var body: some View {
    GeometryReader { proxy in
      if let target = model.picking, let anchor = anchors.zones[target.zone] {
        // The trigger is the zone plus its own label tab: the picker covers neither (bone 5).
        let rect = anchors.tabs[target.zone].map { proxy[anchor].union(proxy[$0]) } ?? proxy[anchor]
        let others =
          anchors.zones.filter { $0.key != target.zone }.map { proxy[$0.value] }
          + anchors.tabs.filter { $0.key != target.zone }.map { proxy[$0.value] }
        let height =
          anchors.interior.map { PickerPlacement.height(interiorHeight: proxy[$0].height) }
          ?? PickerPlacement.height(mirrorHeight: anchors.mirror.map { proxy[$0].height })
        let placement = PickerPlacement.place(
          anchor: rect, zone: target.zone, avoiding: others,
          size: CGSize(width: PickerPlacement.width, height: height), in: CGRect(origin: .zero, size: proxy.size))
        ZStack(alignment: .topLeading) {
          Color.clear.contentShape(Rectangle()).onTapGesture { model.picking = nil }
          PickerBubble(placement: placement) { ActionPickerView(model: model) }
        }
      }
    }
  }
}

/// The popover surface: a plate-radius bubble with an arrow on the side facing its zone.
struct PickerBubble<Content: View>: View {
  var placement: PickerPlacement.Result
  @ViewBuilder var content: Content

  var body: some View {
    let frame = placement.frame
    content
      .frame(width: frame.width, height: frame.height, alignment: .topLeading)
      .background(
        BubbleShape(side: placement.side, arrowOffset: placement.arrowOffset)
          .fill(Tokens.windowTint)
          .shadow(color: Tokens.ink.opacity(0.18), radius: 10, y: 3)
      )
      .offset(x: frame.minX, y: frame.minY)
  }
}

/// A rounded rectangle (plate radius) plus a triangle pointing out of `side`'s facing edge.
struct BubbleShape: Shape {
  var side: PickerPlacement.Side
  var arrowOffset: CGFloat
  var arrow = PickerPlacement.arrowSize

  func path(in rect: CGRect) -> Path {
    var path = Path(roundedRect: rect, cornerRadius: Tokens.radiusPlate)
    let a = arrow
    var points: [CGPoint]
    switch side {
    case .above:  // picker above the zone: arrow on the bottom edge, pointing down
      points = [
        CGPoint(x: arrowOffset - a, y: rect.maxY), CGPoint(x: arrowOffset, y: rect.maxY + a),
        CGPoint(x: arrowOffset + a, y: rect.maxY),
      ]
    case .below:
      points = [
        CGPoint(x: arrowOffset - a, y: rect.minY), CGPoint(x: arrowOffset, y: rect.minY - a),
        CGPoint(x: arrowOffset + a, y: rect.minY),
      ]
    case .left:  // picker left of the zone: arrow on the right edge
      points = [
        CGPoint(x: rect.maxX, y: arrowOffset - a), CGPoint(x: rect.maxX + a, y: arrowOffset),
        CGPoint(x: rect.maxX, y: arrowOffset + a),
      ]
    case .right:
      points = [
        CGPoint(x: rect.minX, y: arrowOffset - a), CGPoint(x: rect.minX - a, y: arrowOffset),
        CGPoint(x: rect.minX, y: arrowOffset + a),
      ]
    }
    path.addLines(points)
    path.closeSubpath()
    return path
  }
}
