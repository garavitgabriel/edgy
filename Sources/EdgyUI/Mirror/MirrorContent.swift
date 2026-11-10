import Actions
import EdgyCore
import EdgyRuntime
import Foundation

/// One zone as the mirror draws it.
struct MirrorZone: Hashable, Identifiable {
  enum Style: Hashable {
    /// Has at least one binding that runs here: a solid bar (edge) or solid tile with icon (corner).
    case mapped
    /// Nothing bound: a hairline bar (edge) or a dashed tile (corner, pass-through).
    case unmapped
    /// An app tab turns every binding of this zone off: drawn as unmapped, tab reads "Off here".
    case offHere
  }

  var zone: Zone
  var style: Style
  /// The tab or in-bar text in full (the inspector's names), `nil` when there is nothing to say.
  var label: String?
  /// An app tab overrides at least one of this zone's default bindings (ink dot on the tab).
  var overridden: Bool
  /// The action icon drawn inside a mapped corner tile (`nil` hides it). For an app mark it is
  /// Open App's; `zoneIcon` says what is really drawn.
  var symbol: ActionID?
  /// What the corner tile draws (`BindingNaming.icon` of the first binding: custom icon > the
  /// app's mark for Open App > the action's icon). `nil` draws `symbol`.
  var zoneIcon: BindingNaming.Icon?
  /// Shorter forms of `label`, longest first (bone 3: the action short names of bindings that
  /// read by their action). The pad draws the first form that fits, else the last one clipped
  /// with a fade.
  var shorter: [String] = []
  /// One of the zone's actions is unavailable on this Mac (§ Issue states, `actionUnavailable`):
  /// the tab reads in `ink2` with a small slashed-circle mark.
  var unavailable = false
  /// Every running action of the zone in pad gesture order (slide, swipes, tap, double-tap,
  /// long-press): the mini mirror draws up to two icons and names them all on hover (bone 10).
  var actions: [ActionID] = []
  /// Each binding's name in `actions` order (`BindingNaming.label`: custom name > target > the
  /// action's own name).
  var actionNames: [String] = []
  /// Which `actionNames` are fixed (a custom name or a target): those never take a short name or
  /// join a pair.
  var customNamed: [Bool] = []
  /// The icon each of `actions` draws (`BindingNaming.icon`); empty means the actions' own.
  var icons: [BindingNaming.Icon] = []

  /// Every form of the label, longest first.
  var labelForms: [String] { label.map { [$0] + shorter.filter { $0 != label } } ?? [] }

  var id: Zone { zone }
  var isCorner: Bool {
    if case .corner = zone { return true }
    return false
  }
}

/// Builds the mirror's zone list from the effective bindings of a profile (§ App profiles: the
/// mirror on an app tab shows what will actually happen in that app).
///
/// **Zones per edge:** an edge is drawn as `n` separate bars, where `n` is the largest `segments`
/// among that edge's bindings (1 when it has none). Unbound segments of a split edge are hairlines.
/// Corners are always drawn; an unbound corner is pass-through (dashed).
enum MirrorContent {
  static let offHereLabel = "Off here"

  /// `availability`: unavailable actions mark their zone (`unavailable`), or, with
  /// `unavailableAsUnmapped` (the popover's mini mirror), don't count as mapped at all.
  static func zones(
    rows: [EffectiveBinding], catalog: [ActionID: ActionDescriptor], allHairline: Bool = false,
    availability: (ActionID) -> ActionAvailability = { _ in .available }, unavailableAsUnmapped: Bool = false
  ) -> [MirrorZone] {
    var segmentsByEdge: [Zone.Edge: Int] = [:]
    for row in rows {
      if case .edge(let edge, _, let segments) = row.binding.zone {
        segmentsByEdge[edge] = max(segmentsByEdge[edge] ?? 1, min(max(segments, 1), 4))
      }
    }
    var zones: [Zone] = []
    for edge in Zone.Edge.allCases {
      let count = segmentsByEdge[edge] ?? 1
      zones += (0..<count).map { Zone.edge(edge, segment: $0, segments: count) }
    }
    zones += Zone.Corner.allCases.map { Zone.corner($0) }

    return zones.map { zone in
      let mine = rows.filter { normalized($0.binding.zone) == zone }
      var running = mine.filter { $0.source != .turnedOff }
      if unavailableAsUnmapped { running = running.filter { availability($0.binding.action).isUsable } }
      if allHairline {
        return MirrorZone(zone: zone, style: .unmapped, label: nil, overridden: false, symbol: nil)
      }
      if running.isEmpty {
        let off = mine.contains { $0.source == .turnedOff }
        return MirrorZone(
          zone: zone, style: off ? .offHere : .unmapped, label: off ? offHereLabel : nil, overridden: false,
          symbol: nil)
      }
      let bindings = running.map(\.binding)
      let ordered = ZoneLabel.ordered(bindings)
      let icons = ordered.map { BindingNaming.icon($0).icon }
      return MirrorZone(
        zone: zone, style: .mapped, label: ZoneLabel.text(for: bindings, catalog: catalog),
        overridden: running.contains { $0.source == .overridden },
        symbol: icons.first.map(\.symbol), zoneIcon: icons.first,
        shorter: ZoneLabel.shorterForms(for: bindings, catalog: catalog),
        unavailable: bindings.contains { !availability($0.action).isUsable },
        actions: ordered.map(\.action),
        actionNames: ordered.map { ZoneLabel.name(for: $0, catalog: catalog) },
        customNamed: ordered.map { ZoneLabel.isFixed($0, catalog: catalog) },
        icons: icons)
    }
  }

  /// `.edge(e)` written with `segments: 1` and any segment index is the whole edge.
  static func normalized(_ zone: Zone) -> Zone {
    if case .edge(let edge, let segment, let segments) = zone {
      let count = min(max(segments, 1), 4)
      return .edge(edge, segment: count == 1 ? 0 : min(max(segment, 0), count - 1), segments: count)
    }
    return zone
  }
}

/// The label rule: a zone's label names its actions in plain words.
///
/// 1. Bindings are read in pad order: slide, swipes (up, down, left, right), tap, double-tap,
///    long-press.
/// 2. Each binding reads by `BindingNaming.label` (BRIEF § Bindings that name their target, one
///    precedence for every surface): its custom name, else its target (Open App → the app,
///    Open URL → the host, Open File → the file, Keyboard Shortcut / Hold Keys → the keys), else
///    the catalog display name, spelled exactly as the catalog spells it (bone 3; batch-14 ruling
///    6). A binding whose required parameter is still empty ends in "…" (§ Binding parameters);
///    that is the only "…" a pad label carries.
/// 3. Opposite pairs collapse into one word: Previous + Next Track read "Tracks"; Space Left + Space
///    Right read "Spaces"; Left + Right Half read "Halves". The word takes the place of the pair's first
///    member.
/// 4. Repeated names appear once.
/// 5. Names are joined without commas: "A", "A and B", "A and 2 more" (`joined`).
///
/// 6. A custom name or a target is fixed: it never joins a pair and stays in every shorter form
///    (the custom name replaces the short-form rule). A custom name on a binding still missing
///    its parameter keeps the "…" (it means "needs a parameter").
///
/// So the default bottom edge (swipe left: previous, swipe right: next, double-tap: play/pause)
/// reads "Tracks and " plus the catalog's Play/Pause name.
///
/// **Long labels** (bone 3, batch-14 ruling 5): the target is already the primary text (batch
/// 29), so `shorterForms` gives the action short names of bindings that read by their action
/// ("Repeat keys", "Mic off", "Shortcut…"). The pad draws the first form that fits and otherwise
/// clips the last one with a 12 pt fade (`MirrorPad`). The full name is always in the inspector.
enum ZoneLabel {
  static let pairs: [(ActionID, ActionID, String)] = [
    (BuiltInAction.previous, BuiltInAction.next, "Tracks"),
    (BuiltInAction.spaceLeft, BuiltInAction.spaceRight, "Spaces"),
    (BuiltInAction.windowLeftHalf, BuiltInAction.windowRightHalf, "Halves"),
  ]

  /// The action short names of ruling 5 (b).
  static let shortNames: [ActionID: String] = [
    BuiltInAction.keyboardShortcut: "Shortcut",
    BuiltInAction.keyboardSlideSteps: "Repeat keys",
    BuiltInAction.runShortcut: "Shortcut",
    BuiltInAction.micMute: "Mic off",
    BuiltInAction.openURL: "Link",
  ]

  static func ordered(_ bindings: [Binding]) -> [Binding] {
    bindings.enumerated().sorted { lhs, rhs in
      let l = padOrder(lhs.element.gesture)
      let r = padOrder(rhs.element.gesture)
      return l != r ? l < r : lhs.offset < rhs.offset
    }.map(\.element)
  }

  static func text(
    for bindings: [Binding], catalog: [ActionID: ActionDescriptor], replacing: (Binding) -> String? = { _ in nil }
  ) -> String {
    let sorted = ordered(bindings)
    let ids = Set(sorted.filter { !isFixed($0, catalog: catalog) }.map(\.action))
    var names: [String] = []
    var consumed = Set<ActionID>()
    for binding in sorted where isFixed(binding, catalog: catalog) || !consumed.contains(binding.action) {
      if !isFixed(binding, catalog: catalog),
        let pair = pairs.first(where: { ($0.0 == binding.action || $0.1 == binding.action) }),
        ids.contains(pair.0), ids.contains(pair.1)
      {
        consumed.formUnion([pair.0, pair.1])
        append(pair.2, to: &names)
        continue
      }
      append(replacing(binding) ?? name(for: binding, catalog: catalog), to: &names)
    }
    return joined(names)
  }

  static func name(for binding: Binding, catalog: [ActionID: ActionDescriptor]) -> String {
    let descriptor = catalog[binding.action]
    let actionName = descriptor?.displayName ?? binding.action.rawValue
    if isMissingParameter(binding, descriptor) { return (BindingNaming.customName(binding) ?? actionName) + "…" }
    return BindingNaming.label(binding, actionName: actionName).text
  }

  /// A binding whose name is its own (custom) or its target's: never paired, never shortened.
  static func isFixed(_ binding: Binding, catalog: [ActionID: ActionDescriptor]) -> Bool {
    if BindingNaming.customName(binding) != nil { return true }
    return !isMissingParameter(binding, catalog[binding.action]) && BindingNaming.target(binding) != nil
  }

  static func isMissingParameter(_ binding: Binding, _ descriptor: ActionDescriptor?) -> Bool {
    descriptor?.parameters.contains {
      $0.required && (binding.parameters[$0.key] ?? "").trimmingCharacters(in: .whitespaces).isEmpty
    } ?? false
  }

  /// The parameter's short value (the target): the keys, the app's name, the host, the file's
  /// name (`BindingNaming.target`), or the shortcut's name. `nil` when the action has none or
  /// it's empty.
  static func shortValue(for binding: Binding) -> String? {
    if let target = BindingNaming.target(binding) { return target }
    guard binding.action == BuiltInAction.runShortcut else { return nil }
    let raw = (binding.parameters[ActionParameterKey.shortcutName] ?? "").trimmingCharacters(in: .whitespaces)
    return raw.isEmpty ? nil : raw
  }

  /// The shorter forms of `text(for:)`, longest first: each name that reads by its action replaced
  /// by its short value (a shortcut's name), then by its short value or short name. A missing parameter keeps its "…": on the pad that means "needs a parameter", never
  /// "cut off". Custom names and targets stay as they are.
  static func shorterForms(for bindings: [Binding], catalog: [ActionID: ActionDescriptor]) -> [String] {
    let full = text(for: bindings, catalog: catalog)
    var forms: [String] = []
    for useShortName in [false, true] {
      let form = text(for: bindings, catalog: catalog) { binding in
        if isFixed(binding, catalog: catalog) { return nil }
        let missing = isMissingParameter(binding, catalog[binding.action])
        if missing, BindingNaming.customName(binding) != nil { return nil }
        if !missing, let value = shortValue(for: binding) { return value }
        if useShortName, let short = shortNames[binding.action] { return missing ? short + "…" : short }
        return nil
      }
      if form != full, !forms.contains(form) { forms.append(form) }
    }
    return forms
  }

  /// Combined edge labels never use commas (", " is the key-sequence separator; critique 29
  /// design answer 1): "A", "A and B", and from three names on "A and 2 more". Counted after
  /// pairs collapse and repeats drop, so the default bottom edge still reads "Tracks and
  /// Play/Pause". The hover line and the inspector list every binding.
  static func joined(_ names: [String]) -> String {
    switch names.count {
    case 0: return ""
    case 1: return names[0]
    case 2: return names[0] + " and " + names[1]
    default: return "\(names[0]) and \(names.count - 1) more"
    }
  }

  private static func padOrder(_ gesture: GestureKind) -> Int {
    switch gesture {
    case .slide: return 0
    case .swipe(.up): return 1
    case .swipe(.down): return 2
    case .swipe(.left): return 3
    case .swipe(.right): return 4
    case .tap: return 5
    case .doubleTap: return 6
    case .longPress: return 7
    }
  }

  private static func append(_ name: String, to names: inout [String]) {
    if !names.contains(name) { names.append(name) }
  }
}

extension BindingNaming.Icon {
  /// The action icon standing for this one: an app mark stands for Open App.
  var symbol: ActionID {
    switch self {
    case .action(let id): return id
    case .app: return BuiltInAction.openApp
    }
  }
}

/// Plain names for zones (accessibility labels and messages).
enum ZoneName {
  static func text(for zone: Zone) -> String {
    switch zone {
    case .edge(let edge, let segment, let segments):
      let base = "\(edge.rawValue.capitalized) edge"
      return segments > 1 ? "\(base), part \(segment + 1) of \(segments)" : base
    case .corner(let corner):
      switch corner {
      case .topLeft: return "Top-left corner"
      case .topRight: return "Top-right corner"
      case .bottomLeft: return "Bottom-left corner"
      case .bottomRight: return "Bottom-right corner"
      }
    }
  }
}
