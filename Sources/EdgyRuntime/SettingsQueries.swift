import EdgyCore

/// Bindings that share a zone, for a per-zone list in the settings UI.
public struct ZoneBindings: Hashable, Sendable {
  public var zone: Zone
  public var bindings: [Binding]
}

/// One row of `SettingsEditor.effectiveBindings(forApp:)`: a slot as the app sees it.
public struct EffectiveBinding: Hashable, Sendable {
  public enum Source: String, Hashable, Sendable {
    /// The default's binding, unchanged for this app.
    case inherited
    /// The app replaces the default's binding on this slot.
    case overridden
    /// The app turns this slot off (`binding.action == .doNothing`).
    case turnedOff
    /// A slot only the app binds (or any binding of a full-replace profile).
    case appOnly
  }

  /// What the slot does for the app (a `doNothing` binding when turned off).
  public var binding: Binding
  public var source: Source
  /// The default's binding on this slot, when the app inherits, overrides or turns it off.
  public var defaultBinding: Binding?

  public init(binding: Binding, source: Source, defaultBinding: Binding?) {
    self.binding = binding
    self.source = source
    self.defaultBinding = defaultBinding
  }
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
  /// "Do nothing" is left out: it isn't an action of any category, and `compatibleActions` offers it
  /// last for every slot.
  public var catalogByCategory: [ActionGroup] {
    ActionCategory.allCases.compactMap { category in
      let actions = catalog.filter { $0.category == category && $0.id != .doNothing }.sorted(by: Self.byName)
      return actions.isEmpty ? nil : ActionGroup(category: category, actions: actions)
    }
  }

  /// Actions that can be bound to `gesture` on `zone`: continuous ones for a slide, triggers and
  /// holds for a long-press, triggers for everything else, none when the zone can't produce the
  /// gesture. Sorted by display name. Unavailable actions are included (the UI greys them out
  /// with `availability(of:)`). "Do nothing" comes last for every supported slot: the catalog's
  /// descriptor when it has one, else `doNothingFallback`.
  public func compatibleActions(zone: Zone, gesture: GestureKind) -> [ActionDescriptor] {
    guard zone.supports(gesture) else { return [] }
    let actions = catalog.filter { $0.id != .doNothing && Self.shape($0.shape, fits: gesture) }
    return actions.sorted(by: Self.byName) + [descriptor(for: .doNothing) ?? Self.doNothingFallback]
  }

  /// Stand-in for the "Do nothing" entry when the catalog doesn't list one.
  public static let doNothingFallback = ActionDescriptor(
    id: .doNothing, shape: .trigger, displayName: "Do Nothing", category: .system)

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
