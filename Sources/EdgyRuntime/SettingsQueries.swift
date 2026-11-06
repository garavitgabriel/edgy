import EdgyCore

/// Bindings that share a zone, for a per-zone list in the settings UI.
public struct ZoneBindings: Hashable, Sendable {
  public var zone: Zone
  public var bindings: [Binding]
}

/// Actions in one category, for the action picker.
public struct ActionGroup: Hashable, Sendable {
  public var category: ActionCategory
  public var actions: [ActionDescriptor]
}

extension Zone {
  /// Stable display order: edges (left, right, top, bottom; whole edge before its segments, then
  /// by segment count and index), then corners (top-left, top-right, bottom-left, bottom-right).
  public var displayOrder: [Int] {
    switch self {
    case .edge(let edge, let segment, let segments):
      return [0, Edge.allCases.firstIndex(of: edge) ?? 0, segments, segment]
    case .corner(let corner):
      return [1, Corner.allCases.firstIndex(of: corner) ?? 0, 0, 0]
    }
  }
}

extension GestureKind {
  /// Every gesture, in display order.
  public static let all: [GestureKind] = [
    .slide, .tap, .doubleTap, .longPress, .swipe(.up), .swipe(.down), .swipe(.left), .swipe(.right),
  ]

  var displayOrder: Int { Self.all.firstIndex(of: self) ?? Self.all.count }
}

extension ConfigValidator {
  /// The catalog grouped by `ActionCategory` in `allCases` order, each group sorted by display
  /// name. Empty categories are left out.
  public var catalogByCategory: [ActionGroup] {
    ActionCategory.allCases.compactMap { category in
      let actions = catalog.filter { $0.category == category }.sorted(by: Self.byName)
      return actions.isEmpty ? nil : ActionGroup(category: category, actions: actions)
    }
  }

  /// Actions that can be bound to `gesture` on `zone`: continuous ones for a slide, triggers for
  /// everything else, none when the zone can't produce the gesture. Sorted by display name.
  public func compatibleActions(zone: Zone, gesture: GestureKind) -> [ActionDescriptor] {
    guard zone.supports(gesture) else { return [] }
    let shape: ActionDescriptor.Shape = gesture == .slide ? .continuous : .trigger
    return catalog.filter { $0.shape == shape }.sorted(by: Self.byName)
  }

  /// Gestures `zone` can produce, in display order.
  public static func supportedGestures(for zone: Zone) -> [GestureKind] {
    GestureKind.all.filter(zone.supports)
  }

  /// A profile's bindings grouped by zone, zones in `Zone.displayOrder`, gestures in display order.
  public static func bindingsByZone(_ profile: Profile) -> [ZoneBindings] {
    var order: [Zone] = []
    var groups: [Zone: [Binding]] = [:]
    for binding in profile.bindings {
      if groups[binding.zone] == nil { order.append(binding.zone) }
      groups[binding.zone, default: []].append(binding)
    }
    return order.sorted { $0.displayOrder.lexicographicallyPrecedes($1.displayOrder) }.map { zone in
      ZoneBindings(zone: zone, bindings: groups[zone]!.sorted { $0.gesture.displayOrder < $1.gesture.displayOrder })
    }
  }

  private static func byName(_ a: ActionDescriptor, _ b: ActionDescriptor) -> Bool {
    a.displayName == b.displayName ? a.id.rawValue < b.id.rawValue : a.displayName < b.displayName
  }
}
