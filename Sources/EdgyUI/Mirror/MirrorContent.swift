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
  /// The action whose icon is drawn inside a mapped corner tile (the transcribed action family).
  var symbol: ActionID?
  /// Shorter forms of `label`, longest first (bone 3: parameter short value, then action short
  /// name). The pad draws the first form that fits, else the last one clipped with a fade.
  var shorter: [String] = []
  /// One of the zone's actions is unavailable on this Mac (§ Issue states, `actionUnavailable`):
  /// the tab reads in `ink2` with a small slashed-circle mark.
  var unavailable = false

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
      let first = ZoneLabel.ordered(bindings).first
      return MirrorZone(
        zone: zone, style: .mapped, label: ZoneLabel.text(for: bindings, catalog: catalog),
        overridden: running.contains { $0.source == .overridden },
        symbol: first?.action,
        shorter: ZoneLabel.shorterForms(for: bindings, catalog: catalog),
        unavailable: bindings.contains { !availability($0.action).isUsable })
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
/// 2. Each action takes its catalog display name, spelled exactly as the catalog spells it (bone 3;
///    batch-14 ruling 6: the UI never re-spells a name). An action whose required parameter is
///    still empty ends in "…" (§ Binding parameters); that is the only "…" a pad label carries.
/// 3. Opposite pairs collapse into one word: Previous + Next Track read "Tracks"; Space Left + Space
///    Right read "Spaces"; Left + Right Half read "Halves". The word takes the place of the pair's first
///    member.
/// 4. Repeated names appear once.
/// 5. Names are joined like a sentence: "A", "A and B", "A, B and C".
///
/// So the default bottom edge (swipe left: previous, swipe right: next, double-tap: play/pause)
/// reads "Tracks and " plus the catalog's Play/Pause name.
///
/// **Long labels** (bone 3, batch-14 ruling 5): `shorterForms` gives the parameter's short value
/// (the key combo, the app or file name), then the action's short name ("Shortcut", "Repeat keys",
/// "Mic off", "Link"). The pad draws the first form that fits and otherwise clips the last one
/// with a 12 pt fade (`MirrorPad`). The full name is always in the inspector.
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
    let ids = Set(sorted.map(\.action))
    var names: [String] = []
    var consumed = Set<ActionID>()
    for binding in sorted where !consumed.contains(binding.action) {
      if let pair = pairs.first(where: { ($0.0 == binding.action || $0.1 == binding.action) }),
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
    var name = descriptor?.displayName ?? binding.action.rawValue
    if isMissingParameter(binding, descriptor) { name += "…" }
    return name
  }

  static func isMissingParameter(_ binding: Binding, _ descriptor: ActionDescriptor?) -> Bool {
    descriptor?.parameters.contains {
      $0.required && (binding.parameters[$0.key] ?? "").trimmingCharacters(in: .whitespaces).isEmpty
    } ?? false
  }

  /// (a) The parameter's short value: the key combo, the app's name, the file's name, the
  /// shortcut's name. `nil` when the action has none or it's empty.
  static func shortValue(for binding: Binding) -> String? {
    func value(_ key: String) -> String? {
      let raw = (binding.parameters[key] ?? "").trimmingCharacters(in: .whitespaces)
      return raw.isEmpty ? nil : raw
    }
    switch binding.action {
    case BuiltInAction.keyboardShortcut, BuiltInAction.keyboardHold:
      return value(ActionParameterKey.keys).map { KeyComboText.display($0) }
    case BuiltInAction.openApp: return value(ActionParameterKey.bundleID).map(MirrorCopy.appName)
    case BuiltInAction.openFile: return value(ActionParameterKey.path).map { ($0 as NSString).lastPathComponent }
    case BuiltInAction.runShortcut: return value(ActionParameterKey.shortcutName)
    default: return nil
    }
  }

  /// The shorter forms of `text(for:)`, longest first: each name replaced by its short value,
  /// then by its short value or short name. A missing parameter keeps its "…": on the pad that
  /// means "needs a parameter", never "cut off".
  static func shorterForms(for bindings: [Binding], catalog: [ActionID: ActionDescriptor]) -> [String] {
    let full = text(for: bindings, catalog: catalog)
    var forms: [String] = []
    for useShortName in [false, true] {
      let form = text(for: bindings, catalog: catalog) { binding in
        let missing = isMissingParameter(binding, catalog[binding.action])
        if !missing, let value = shortValue(for: binding) { return value }
        if useShortName, let short = shortNames[binding.action] { return missing ? short + "…" : short }
        return nil
      }
      if form != full, !forms.contains(form) { forms.append(form) }
    }
    return forms
  }

  static func joined(_ names: [String]) -> String {
    switch names.count {
    case 0: return ""
    case 1: return names[0]
    default: return names.dropLast().joined(separator: ", ") + " and " + names[names.count - 1]
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
