import CoreGraphics
import EdgyCore
import EdgyRuntime
import Foundation

/// What the picker lists for one zone + gesture (BRIEF § Picker at catalog scale). Pure.
struct PickerCatalog: Equatable {
  struct Item: Equatable, Identifiable {
    var descriptor: ActionDescriptor
    var availability: ActionAvailability

    var id: ActionID { descriptor.id }
    /// "Open App…" for actions with parameters.
    var title: String { ActionNaming.pickerName(descriptor) }
    /// The 13 pt second line: the unavailable reason, or a limited action's note.
    var subtitle: String? {
      switch availability {
      case .available: return nil
      case .limited(let reason), .unavailable(let reason): return reason
      }
    }
    var isDimmed: Bool { !availability.isUsable }
  }

  struct Section: Equatable, Identifiable {
    var category: ActionCategory
    var items: [Item]
    var id: ActionCategory { category }
    var title: String {
      switch category {
      case .sound: return "Sound"
      case .display: return "Display"
      case .media: return "Media"
      case .system: return "System"
      case .windows: return "Windows"
      case .apps: return "Apps"
      case .keyboard: return "Keyboard"
      case .shortcuts: return "Shortcuts"
      }
    }
  }

  /// Fitting actions, grouped in catalog order (Sound, Display, … Shortcuts).
  var sections: [Section]
  /// Actions whose shape can't take the gesture, for the one disclosure row at the end.
  var others: [Item]
  /// "6 more need a slide" — names the gestures the hidden actions need.
  var othersTitle: String?
  /// "Do nothing here" (app tabs only, last, after a separator).
  var offersDoNothing: Bool

  /// Nothing to list at all (only possible with a search typed).
  var isEmpty: Bool { sections.isEmpty && others.isEmpty && !offersDoNothing }

  /// The empty state with a search typed: "No actions match “xyz”." (13, `ink2`). `nil` for an
  /// empty search.
  static func noMatches(_ query: String) -> String? {
    let typed = query.trimmingCharacters(in: .whitespaces)
    return typed.isEmpty ? nil : "No actions match \u{201C}\(typed)\u{201D}."
  }

  /// Every selectable item in list order (arrows and Return walk this).
  var selectable: [Item] { sections.flatMap(\.items) }

  init(
    groups: [ActionGroup], gesture: GestureKind, query: String = "", isAppTab: Bool,
    availability: (ActionID) -> ActionAvailability
  ) {
    let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
    func matches(_ descriptor: ActionDescriptor) -> Bool {
      guard !needle.isEmpty else { return true }
      return descriptor.displayName.lowercased().contains(needle)
    }
    var sections: [Section] = []
    var others: [Item] = []
    for group in groups {
      var fitting: [Item] = []
      for descriptor in Self.ordered(group.actions) where descriptor.id != .doNothing && matches(descriptor) {
        let item = Item(descriptor: descriptor, availability: availability(descriptor.id))
        if ConfigValidator.shape(descriptor.shape, fits: gesture) { fitting.append(item) } else { others.append(item) }
      }
      if !fitting.isEmpty { sections.append(Section(category: group.category, items: fitting)) }
    }
    self.sections = sections
    self.others = others
    self.othersTitle = others.isEmpty ? nil : "\(others.count) more \(Self.need(others.map(\.descriptor.shape)))"
    self.offersDoNothing = isAppTab && (needle.isEmpty || "do nothing here".contains(needle))
  }

  /// BRIEF § Picker clarity: within a group, the icon table's order (most-used first), never
  /// alphabetical; search keeps it (critique 22, design answer 2). Keyed by action ID so the
  /// catalog itself stays as it is. An action the table doesn't name keeps its catalog place,
  /// after the named ones.
  static let iconTableOrder: [ActionID] = [
    // Sound
    "audio.volume", "audio.mute", "mic.mute",
    // Display
    "display.brightness", "keyboard.backlight", "keyboard.backlightToggle",
    // Media
    "media.playPause", "media.next", "media.previous",
    // System
    "system.missionControl", "system.appWindows", "system.showDesktop", "spaces.left", "spaces.right",
    "system.lockScreen", "system.sleepDisplay", "system.dictation",
    // Windows
    "window.leftHalf", "window.rightHalf", "window.topHalf", "window.bottomHalf", "window.maximize",
    "window.center", "window.minimize", "window.restore",
    // Apps
    "app.open", "url.open", "file.open", "apps.switcher",
    // Keyboard
    "keyboard.shortcut", "keyboard.slideSteps", "keyboard.hold",
    // Shortcuts
    "shortcut.run",
  ]

  private static let rank: [ActionID: Int] = Dictionary(
    uniqueKeysWithValues: iconTableOrder.enumerated().map { ($1, $0) })

  /// `actions` in icon-table order; unnamed ones after, in their given order.
  static func ordered(_ actions: [ActionDescriptor]) -> [ActionDescriptor] {
    actions.enumerated()
      .sorted { a, b in
        let ra = rank[a.element.id] ?? iconTableOrder.count + a.offset
        let rb = rank[b.element.id] ?? iconTableOrder.count + b.offset
        return ra < rb
      }
      .map(\.element)
  }

  /// "need a slide", "need a long-press", "need a slide or long-press", "need a tap, swipe or
  /// long-press": the gestures the hidden shapes take.
  static func need(_ shapes: [ActionDescriptor.Shape]) -> String {
    let set = Set(shapes)
    var gestures: [String] = []
    if set.contains(.continuous) { gestures.append("slide") }
    if set.contains(.trigger) { gestures += ["tap", "swipe"] }
    if set.contains(.hold) || set.contains(.trigger) { gestures.append("long-press") }
    guard let last = gestures.popLast() else { return "" }
    let list = gestures.isEmpty ? last : "\(gestures.joined(separator: ", ")) or \(last)"
    return "\(shapes.count == 1 ? "needs" : "need") a \(list)"
  }
}

/// Where the anchored picker sits (bone 5): beside its zone with the arrow pointing at it, never
/// covering the zone or its neighbours, never leaving the window. Pure geometry.
enum PickerPlacement {
  /// The widest the picker gets (BRIEF: single column, at most 420 pt wide).
  static let maxWidth: CGFloat = 420
  static let width: CGFloat = 320
  /// Tallest: 420, and never taller than the mirror − 16 pt (so it never covers the pad's other bars).
  static let maxHeight: CGFloat = 420
  static let mirrorInset: CGFloat = 16
  /// The shortest the picker gets when it shrinks to clear other zones (header, search, ~4 rows).
  static let minHeight: CGFloat = 200
  /// Gap between the arrow tip and the zone, and from the window edge.
  static let gap: CGFloat = 6
  static let margin: CGFloat = 8
  /// Space kept between the panel and any other zone's bar.
  static let zoneClearance: CGFloat = 8
  static let arrowSize: CGFloat = 8

  enum Side: Equatable {
    /// The picker is above the zone (arrow on the picker's bottom edge, pointing down).
    case above, below, left, right
  }

  struct Result: Equatable {
    var frame: CGRect
    var side: Side
    /// The arrow's position along the picker's edge, from the frame's origin.
    var arrowOffset: CGFloat
  }

  static func height(mirrorHeight: CGFloat?) -> CGFloat {
    guard let mirrorHeight else { return maxHeight }
    return max(min(maxHeight, mirrorHeight - mirrorInset), 120)
  }

  /// At most the pad's interior (between the top and bottom bars' inner edges), so the picker never
  /// covers a bar (§ Picker at catalog scale, ruled 2026-11-07), and never past 420.
  static func height(interiorHeight: CGFloat) -> CGFloat {
    max(min(maxHeight, interiorHeight), 120)
  }

  /// A picker beside a side edge: vertically centred on the anchor, clamped into the free band
  /// between whatever sits above and below it in its column (corner tiles and their tabs, cleared by
  /// `zoneClearance`), and shorter if the band is (§ Picker clarity → Scrolling and placement).
  static func sideFrame(
    side: Side, anchor: CGRect, avoiding cleared: [CGRect], size: CGSize, bounds: CGRect
  ) -> Result {
    let reach = gap + arrowSize
    let x = side == .left ? anchor.minX - reach - size.width : anchor.maxX + reach
    let column = CGRect(x: x, y: bounds.minY, width: size.width, height: bounds.height)
    var top = bounds.minY
    var bottom = bounds.maxY
    for other in cleared where other.intersects(column) {
      if other.midY < anchor.midY { top = max(top, other.maxY) } else { bottom = min(bottom, other.minY) }
    }
    let height = max(min(size.height, bottom - top), minHeight)
    let y = min(max(anchor.midY - height / 2, top), max(bottom - height, top))
    let frame = CGRect(x: x, y: y, width: size.width, height: height)
    let offset = min(max(anchor.midY - frame.minY, 20), height - 20)
    return Result(frame: frame, side: side, arrowOffset: offset)
  }

  /// Sides to try, inner side first: a bottom bar opens upward, a right strip to its left.
  static func preferredSides(for zone: Zone) -> [Side] {
    switch zone {
    case .edge(.bottom, _, _): return [.above, .left, .right, .below]
    case .edge(.top, _, _): return [.below, .left, .right, .above]
    case .edge(.left, _, _): return [.right, .above, .below, .left]
    case .edge(.right, _, _): return [.left, .above, .below, .right]
    case .corner(.topLeft): return [.below, .right, .above, .left]
    case .corner(.topRight): return [.below, .left, .above, .right]
    case .corner(.bottomLeft): return [.above, .right, .below, .left]
    case .corner(.bottomRight): return [.above, .left, .below, .right]
    }
  }

  static func place(
    anchor: CGRect, zone: Zone, avoiding others: [CGRect], size: CGSize, in container: CGRect
  ) -> Result {
    let bounds = container.insetBy(dx: margin, dy: margin)
    // Other zones keep an 8 pt clearance (the panel never sits right against a bar).
    let cleared = others.map { $0.insetBy(dx: -zoneClearance, dy: -zoneClearance) }
    func overlap(_ result: Result) -> CGFloat {
      var total = area(result.frame.intersection(anchor)) * 4
      for other in cleared { total += area(result.frame.intersection(other)) }
      if !bounds.contains(result.frame.integral.insetBy(dx: 1, dy: 1)) { total += area(result.frame.size) }
      return total
    }
    var best: (Result, CGFloat)?
    // Inner side first; on each side the picker gets shorter (never below `minHeight`, the list
    // scrolls) until it clears its zone and every other zone (BRIEF: it never covers the pad's
    // other bars). Only when no side fits does the least-covering full-size spot win.
    for side in preferredSides(for: zone) {
      if case .edge(let edge, _, _) = zone, edge == .left || edge == .right, side == .left || side == .right {
        let result = sideFrame(side: side, anchor: anchor, avoiding: cleared, size: size, bounds: bounds)
        if overlap(result) == 0 { return result }
      }
      var height = size.height
      while true {
        let result = frame(for: side, anchor: anchor, size: CGSize(width: size.width, height: height), bounds: bounds)
        let covered = overlap(result)
        if covered == 0 { return result }
        if height == size.height, best == nil || covered < best!.1 { best = (result, covered) }
        guard height > minHeight else { break }
        height = max(height - 8, minHeight)
      }
    }
    return best!.0
  }

  private static func frame(for side: Side, anchor: CGRect, size: CGSize, bounds: CGRect) -> Result {
    let reach = gap + arrowSize
    var origin: CGPoint
    switch side {
    case .above: origin = CGPoint(x: anchor.midX - size.width / 2, y: anchor.minY - reach - size.height)
    case .below: origin = CGPoint(x: anchor.midX - size.width / 2, y: anchor.maxY + reach)
    case .left: origin = CGPoint(x: anchor.minX - reach - size.width, y: anchor.midY - size.height / 2)
    case .right: origin = CGPoint(x: anchor.maxX + reach, y: anchor.midY - size.height / 2)
    }
    // Slide along the arrow's edge to stay in the window; the arrow keeps pointing at the zone.
    switch side {
    case .above, .below:
      origin.x = min(max(origin.x, bounds.minX), bounds.maxX - size.width)
    case .left, .right:
      origin.y = min(max(origin.y, bounds.minY), bounds.maxY - size.height)
    }
    let frame = CGRect(origin: origin, size: size)
    let radiusRoom: CGFloat = 20
    let offset: CGFloat
    switch side {
    case .above, .below:
      offset = min(max(anchor.midX - frame.minX, radiusRoom), size.width - radiusRoom)
    case .left, .right:
      offset = min(max(anchor.midY - frame.minY, radiusRoom), size.height - radiusRoom)
    }
    return Result(frame: frame, side: side, arrowOffset: offset)
  }

  private static func area(_ rect: CGRect) -> CGFloat { rect.isNull ? 0 : rect.width * rect.height }
  private static func area(_ size: CGSize) -> CGFloat { size.width * size.height }
}
