import Displays
import EdgyCore
import Foundation

/// The hardware facts availability depends on. The availability table is cached per value: a
/// display connected or disconnected (or a monitor that starts or stops accepting brightness
/// control) changes the facts, and the table is rebuilt.
struct HardwareFacts: Hashable {
  /// The built-in panel's brightness can be set (a MacBook with its lid open).
  var builtInPanel: Bool
  var displays: [DisplayInfo]
  var backlitKeyboard: Bool
}

extension ActionRegistry {
  /// User-facing copy for actions that lean on something outside Edgy's control.
  enum AvailabilityCopy {
    static let spaceLeft =
      "Uses the system shortcut Control–Left Arrow (“Move left a space”). It does nothing if that shortcut is turned off or changed in Keyboard Shortcuts settings."
    static let spaceRight =
      "Uses the system shortcut Control–Right Arrow (“Move right a space”). It does nothing if that shortcut is turned off or changed in Keyboard Shortcuts settings."
    static let lockScreen =
      "Uses the system shortcut Control–Command–Q (“Lock Screen”). It does nothing if that shortcut is turned off or changed in Keyboard Shortcuts settings."
    static let dictation =
      "Needs Dictation turned on in Keyboard settings, with the microphone key as its shortcut."
    static let noBrightnessNoMonitor =
      "This Mac has no built-in display, and no connected monitor accepts brightness control."
    static let noBrightnessOneMonitor =
      "This Mac has no built-in display, and the connected monitor doesn't accept brightness control."
    static let noBrightnessMonitors =
      "This Mac has no built-in display, and the connected monitors don't accept brightness control."
    static let unknownAction = "Edgy doesn't know this action."

    /// "Works on A and B; C doesn't accept brightness control."
    static func someMonitors(working: [String], notWorking: [String]) -> String {
      let verb = notWorking.count == 1 ? "doesn't" : "don't"
      return "Works on \(list(working)); \(list(notWorking)) \(verb) accept brightness control."
    }

    static func list(_ names: [String]) -> String {
      switch names.count {
      case 0: return ""
      case 1: return names[0]
      default: return names.dropLast().joined(separator: ", ") + " and " + names[names.count - 1]
      }
    }
  }

  public func availability(of id: ActionID) -> ActionAvailability {
    let facts = HardwareFacts(
      builtInPanel: display.isAvailable, displays: displays.displays(), backlitKeyboard: backlight.isAvailable)
    availabilityLock.lock()
    defer { availabilityLock.unlock() }
    if let cache = availabilityCache, cache.facts == facts {
      return cache.table[id] ?? .unavailable(reason: AvailabilityCopy.unknownAction)
    }
    let table = Dictionary(uniqueKeysWithValues: available.map { ($0.id, Self.availability(of: $0.id, facts)) })
    availabilityCache = (facts, table)
    return table[id] ?? .unavailable(reason: AvailabilityCopy.unknownAction)
  }

  /// Pure: what `id` can do given `facts`.
  static func availability(of id: ActionID, _ facts: HardwareFacts) -> ActionAvailability {
    switch id {
    case BuiltInAction.brightness: return brightnessAvailability(facts)
    case BuiltInAction.keyboardBacklight, BuiltInAction.keyboardBacklightToggle:
      return facts.backlitKeyboard ? .available : .unavailable(reason: noBacklightReason)
    case BuiltInAction.spaceLeft: return .limited(reason: AvailabilityCopy.spaceLeft)
    case BuiltInAction.spaceRight: return .limited(reason: AvailabilityCopy.spaceRight)
    case BuiltInAction.lockScreen: return .limited(reason: AvailabilityCopy.lockScreen)
    case BuiltInAction.dictation: return .limited(reason: AvailabilityCopy.dictation)
    default:
      // Mission Control, App Windows and Show Desktop ask the Dock directly: no shortcut needed.
      return ActionCatalog.all.contains { $0.id == id }
        ? .available : .unavailable(reason: AvailabilityCopy.unknownAction)
    }
  }

  /// Same facts `brightnessTarget()` routes on: the built-in panel (through the built-in output
  /// or `Displays`) or any external display that accepts brightness control.
  static func brightnessAvailability(_ facts: HardwareFacts) -> ActionAvailability {
    let builtIn =
      facts.builtInPanel || facts.displays.contains { $0.kind == .builtIn && $0.brightnessControllable }
    let external = facts.displays.filter { $0.kind != .builtIn }
    let working = external.filter(\.brightnessControllable).map(\.name)
    let notWorking = external.filter { !$0.brightnessControllable }.map(\.name)
    if builtIn {
      guard !notWorking.isEmpty else { return .available }
      return .limited(
        reason: AvailabilityCopy.someMonitors(working: ["the built-in display"] + working, notWorking: notWorking))
    }
    if working.isEmpty {
      switch notWorking.count {
      case 0: return .unavailable(reason: AvailabilityCopy.noBrightnessNoMonitor)
      case 1: return .unavailable(reason: AvailabilityCopy.noBrightnessOneMonitor)
      default: return .unavailable(reason: AvailabilityCopy.noBrightnessMonitors)
      }
    }
    guard !notWorking.isEmpty else { return .available }
    return .limited(reason: AvailabilityCopy.someMonitors(working: working, notWorking: notWorking))
  }
}
