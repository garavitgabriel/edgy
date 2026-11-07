import Actions
import EdgyCore
import EdgyRuntime
import Foundation

/// The system and issue states (BRIEF § System states, § Issue states), in precedence order:
/// a broken config file first, then No Accessibility > No trackpad > Paused > Disabled > Test Mode.
public enum SystemState: Int, CaseIterable, Comparable, Sendable {
  case brokenConfig, noAccessibility, noTrackpad, paused, disabled, testMode

  public static func < (a: SystemState, b: SystemState) -> Bool { a.rawValue < b.rawValue }
}

/// What the settings window says about the states that apply, each once, beside what it affects.
///
/// - The **strip** under the tabs carries the top of broken config / No Accessibility.
/// - The **pad line** centred on the mirror carries Paused or "Edgy is off in <App>". It's a
///   different place from the strip, so a strip and a pad line can show together.
/// - No trackpad and Disabled are drawn by `PadMirrorView` itself (batch 14 owns its fade and the
///   dashed outline); the window only adds the paused fade, which no mirror spec covers.
public struct WindowStatus: Equatable, Sendable {
  public enum Strip: Equatable, Sendable {
    case brokenConfig(ConfigProblem)
    case noAccessibility
  }

  public enum PadLine: Equatable, Sendable {
    case paused(until: Date?)
    case offInApp(bundleID: String)
  }

  /// Every state that applies, top first.
  public var states: [SystemState]
  public var strip: Strip?
  public var padLine: PadLine?

  public var top: SystemState? { states.first }
  /// While the file is broken nothing in the window can edit, so nothing overwrites the user's fix.
  public var isReadOnly: Bool { states.contains(.brokenConfig) }
  /// The window fades the mirror to 40% only while paused (see the type note).
  public var fadesMirror: Bool { padLine.map { if case .paused = $0 { true } else { false } } ?? false }
  /// "Edgy is off in this app": the inspector stays empty.
  public var hidesInspector: Bool { padLine.map { if case .offInApp = $0 { true } else { false } } ?? false }

  public static func resolve(
    conditions: WindowConditions, engine: EngineStatus, config: EdgyConfig, tab: ProfileRef
  ) -> WindowStatus {
    var states: [SystemState] = []
    if conditions.configProblem != nil { states.append(.brokenConfig) }
    if conditions.accessibility == .denied { states.append(.noAccessibility) }
    if !engine.devices.contains(where: { $0.kind != .mouse }) { states.append(.noTrackpad) }
    if engine.paused { states.append(.paused) }
    if !config.app.enabled { states.append(.disabled) }
    if engine.testMode { states.append(.testMode) }
    states.sort()

    var strip: Strip?
    if let problem = conditions.configProblem {
      strip = .brokenConfig(problem)
    } else if states.contains(.noAccessibility) {
      strip = .noAccessibility
    }

    var padLine: PadLine?
    if !states.contains(.noTrackpad) {
      if engine.paused {
        padLine = .paused(until: engine.pausedUntil)
      } else if case .app(let id) = tab, config.appProfiles[id]?.disabled == true {
        padLine = .offInApp(bundleID: id)
      }
    }
    return WindowStatus(states: states, strip: strip, padLine: padLine)
  }
}

/// Copy the window writes (BRIEF § Copy voice: plain, specific, measured).
public enum WindowCopy {
  public static let noAccessibility = "Edgy needs Accessibility access to run actions."
  public static let legacyNote = "This profile doesn’t follow Default."
  public static let legacyDetail = "It keeps working exactly as it does now."

  /// "Paused, 47 min left"; whole minutes, "less than a minute left" under one. No clock time.
  public static func paused(until: Date?, now: Date) -> String {
    guard let until else { return "Paused" }
    let seconds = until.timeIntervalSince(now)
    if seconds < 60 { return "Paused, less than a minute left" }
    return "Paused, \(Int(seconds / 60)) min left"
  }

  public static func offIn(_ app: String) -> String { "Edgy is off in \(app)" }

  /// The display name of an app profile: the installed app's name, else the bundle ID's last
  /// part with its first letter capitalized ("com.example.wayfare" becomes "Wayfare").
  public static func appName(for bundleID: String, in apps: [InstalledApp]) -> String {
    if let app = apps.first(where: { $0.bundleID == bundleID }) { return app.name }
    let last = bundleID.split(separator: ".").last.map(String.init) ?? bundleID
    return last.prefix(1).uppercased() + last.dropFirst()
  }

  public static func gestureName(_ gesture: GestureKind) -> String {
    switch gesture {
    case .slide: return "Slide"
    case .swipe(let direction): return "Swipe \(direction.rawValue)"
    case .tap: return "Tap"
    case .doubleTap: return "Double-tap"
    case .longPress: return "Long-press"
    }
  }

  /// A part of an edge in words: "whole edge", "upper half", "middle third"…
  public static func partName(_ zone: Zone) -> String {
    guard case .edge(let edge, let segment, let count) = zone, count > 1 else { return "whole edge" }
    let vertical = edge == .left || edge == .right
    let names: [String]
    switch count {
    case 2: names = vertical ? ["lower half", "upper half"] : ["left half", "right half"]
    case 3:
      names =
        vertical ? ["lower third", "middle third", "upper third"] : ["left third", "middle third", "right third"]
    default:
      names =
        vertical
        ? ["bottom quarter", "lower-middle quarter", "upper-middle quarter", "top quarter"]
        : ["left quarter", "left-middle quarter", "right-middle quarter", "right quarter"]
    }
    return names[min(max(segment, 0), names.count - 1)]
  }

  /// "Upper half and whole edge both use Swipe up."
  public static func overlap(_ first: Zone, _ second: Zone, gesture: GestureKind) -> String {
    let text = "\(partName(first)) and \(partName(second)) both use \(gestureName(gesture))."
    return text.prefix(1).uppercased() + text.dropFirst()
  }
}

/// Two parts of one edge bound to the same gesture (`overlappingZones`, a warning): the selected
/// zone and the other one, which **Show** selects.
public struct OverlapNote: Equatable, Sendable {
  public var zone: Zone
  public var other: Zone
  public var gesture: GestureKind

  public var text: String { WindowCopy.overlap(zone, other, gesture: gesture) }

  /// The first overlap that involves `zone` in `profile`, if any.
  public static func find(for zone: Zone, in profile: Profile) -> OverlapNote? {
    let live = profile.bindings.filter { $0.action != .doNothing }
    for binding in live where binding.zone == zone {
      if let other = live.first(where: { ConfigValidator.overlaps(binding, $0) }) {
        return OverlapNote(zone: zone, other: other.zone, gesture: binding.gesture)
      }
    }
    return nil
  }
}
