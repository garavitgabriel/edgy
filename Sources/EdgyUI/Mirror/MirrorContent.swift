import Actions
import EdgyCore
import EdgyRuntime

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
  /// The tab or in-bar text, `nil` when there is nothing to say.
  var label: String?
  /// An app tab overrides at least one of this zone's default bindings (ink dot on the tab).
  var overridden: Bool
  /// The SF Symbol drawn inside a mapped corner tile.
  var symbol: String?

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

  static func zones(
    rows: [EffectiveBinding], catalog: [ActionID: ActionDescriptor], allHairline: Bool = false
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
      let running = mine.filter { $0.source != .turnedOff }
      if allHairline {
        return MirrorZone(zone: zone, style: .unmapped, label: nil, overridden: false, symbol: nil)
      }
      if running.isEmpty {
        let off = !mine.isEmpty
        return MirrorZone(
          zone: zone, style: off ? .offHere : .unmapped, label: off ? offHereLabel : nil, overridden: false,
          symbol: nil)
      }
      let bindings = running.map(\.binding)
      let first = ZoneLabel.ordered(bindings).first
      return MirrorZone(
        zone: zone, style: .mapped, label: ZoneLabel.text(for: bindings, catalog: catalog),
        overridden: running.contains { $0.source == .overridden },
        symbol: first.map { ZoneLabel.symbol(for: $0.action) })
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
/// 2. Each action takes its short pad name: "Mic off" (`mic.mute`), "Mute" (`audio.mute`),
///    "Play/Pause" (`media.playPause`); any other action uses its catalog name, with " / " closed
///    up to "/". An action whose required parameter is still empty ends in "…" (§ Binding
///    parameters).
/// 3. Opposite pairs collapse into one word: Previous + Next Track → "Tracks"; Space Left + Space
///    Right → "Spaces"; Left + Right Half → "Halves". The word takes the place of the pair's first
///    member.
/// 4. Repeated names appear once.
/// 5. Names are joined like a sentence: "A", "A and B", "A, B and C".
///
/// So the default bottom edge (swipe left → previous, swipe right → next, double-tap → play/pause)
/// reads "Tracks and Play/Pause".
enum ZoneLabel {
  static let pairs: [(ActionID, ActionID, String)] = [
    (BuiltInAction.previous, BuiltInAction.next, "Tracks"),
    (BuiltInAction.spaceLeft, BuiltInAction.spaceRight, "Spaces"),
    (BuiltInAction.windowLeftHalf, BuiltInAction.windowRightHalf, "Halves"),
  ]

  static let shortNames: [ActionID: String] = [
    BuiltInAction.micMute: "Mic off",
    BuiltInAction.mute: "Mute",
    BuiltInAction.playPause: "Play/Pause",
  ]

  static func ordered(_ bindings: [Binding]) -> [Binding] {
    bindings.enumerated().sorted { lhs, rhs in
      let l = padOrder(lhs.element.gesture)
      let r = padOrder(rhs.element.gesture)
      return l != r ? l < r : lhs.offset < rhs.offset
    }.map(\.element)
  }

  static func text(for bindings: [Binding], catalog: [ActionID: ActionDescriptor]) -> String {
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
      append(name(for: binding, catalog: catalog), to: &names)
    }
    return joined(names)
  }

  static func name(for binding: Binding, catalog: [ActionID: ActionDescriptor]) -> String {
    let descriptor = catalog[binding.action]
    var name =
      shortNames[binding.action]
      ?? descriptor?.displayName.replacingOccurrences(of: " / ", with: "/") ?? binding.action.rawValue
    let missing = descriptor?.parameters.contains { $0.required && (binding.parameters[$0.key] ?? "").isEmpty } ?? false
    if missing { name += "…" }
    return name
  }

  static func joined(_ names: [String]) -> String {
    switch names.count {
    case 0: return ""
    case 1: return names[0]
    default: return names.dropLast().joined(separator: ", ") + " and " + names[names.count - 1]
    }
  }

  /// The icon inside a mapped corner tile (SF Symbols only; one family, one weight).
  static func symbol(for action: ActionID) -> String {
    symbols[action] ?? "circle.dotted"
  }

  private static let symbols: [ActionID: String] = [
    BuiltInAction.micMute: "mic.slash",
    BuiltInAction.mute: "speaker.slash",
    BuiltInAction.volume: "speaker.wave.2",
    BuiltInAction.brightness: "sun.max",
    BuiltInAction.playPause: "playpause",
    BuiltInAction.next: "forward",
    BuiltInAction.previous: "backward",
    BuiltInAction.runShortcut: "square.stack.3d.up",
    BuiltInAction.keyboardShortcut: "command",
    BuiltInAction.keyboardHold: "keyboard",
    BuiltInAction.keyboardSlideSteps: "keyboard",
    BuiltInAction.keyboardBacklight: "light.max",
    BuiltInAction.keyboardBacklightToggle: "light.max",
    BuiltInAction.openApp: "app",
    BuiltInAction.openURL: "link",
    BuiltInAction.openFile: "folder",
    BuiltInAction.appSwitcher: "square.on.square",
    BuiltInAction.missionControl: "rectangle.3.group",
    BuiltInAction.appWindows: "macwindow.on.rectangle",
    BuiltInAction.showDesktop: "menubar.dock.rectangle",
    BuiltInAction.spaceLeft: "rectangle.lefthalf.inset.filled",
    BuiltInAction.spaceRight: "rectangle.righthalf.inset.filled",
    BuiltInAction.lockScreen: "lock",
    BuiltInAction.sleepDisplay: "moon",
    BuiltInAction.dictation: "mic",
    BuiltInAction.windowLeftHalf: "rectangle.lefthalf.filled",
    BuiltInAction.windowRightHalf: "rectangle.righthalf.filled",
    BuiltInAction.windowTopHalf: "rectangle.tophalf.filled",
    BuiltInAction.windowBottomHalf: "rectangle.bottomhalf.filled",
    BuiltInAction.windowMaximize: "rectangle.inset.filled",
    BuiltInAction.windowCenter: "rectangle.center.inset.filled",
    BuiltInAction.windowMinimize: "minus.rectangle",
    BuiltInAction.windowRestore: "rectangle",
  ]

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
