import EdgyCore
import EdgyRuntime
import Foundation

/// Every user-facing name the inspector and picker show for zones and gestures. Plain words, one
/// clause (BRIEF § Copy voice).
enum ZoneNaming {
  /// The 26 pt title: "Right edge", "Right edge, upper half", "Bottom-right corner".
  static func title(_ zone: Zone) -> String {
    switch zone {
    case .corner(let corner): return cornerName(corner)
    case .edge(let edge, let segment, let segments):
      let base = "\(edgeName(edge)) edge"
      guard segments > 1 else { return base }
      return "\(base), \(part(edge: edge, segment: segment, segments: segments))"
    }
  }

  /// The picker header's zone part, lowercase: "bottom edge", "right edge, upper half".
  static func lowercased(_ zone: Zone) -> String {
    let title = title(zone)
    return title.prefix(1).lowercased() + title.dropFirst()
  }

  /// Which part of a split edge: "upper half", "middle third", "quarter 2 of 4", or "whole edge".
  /// Side edges count from the top, top and bottom edges from the left (reading order); the
  /// runtime's `segment` counts bottom→top on side edges.
  static func part(edge: Zone.Edge, segment: Int, segments: Int) -> String {
    guard segments > 1 else { return "whole edge" }
    let isSide = edge == .left || edge == .right
    let reading = isSide ? segments - 1 - segment : segment
    switch segments {
    case 2:
      return isSide ? ["upper half", "lower half"][clamp(reading, 2)] : ["left half", "right half"][clamp(reading, 2)]
    case 3:
      return isSide
        ? ["upper third", "middle third", "lower third"][clamp(reading, 3)]
        : ["left third", "middle third", "right third"][clamp(reading, 3)]
    default: return "quarter \(reading + 1) of \(segments)"
    }
  }

  static func edgeName(_ edge: Zone.Edge) -> String {
    switch edge {
    case .left: return "Left"
    case .right: return "Right"
    case .top: return "Top"
    case .bottom: return "Bottom"
    }
  }

  static func cornerName(_ corner: Zone.Corner) -> String {
    switch corner {
    case .topLeft: return "Top-left corner"
    case .topRight: return "Top-right corner"
    case .bottomLeft: return "Bottom-left corner"
    case .bottomRight: return "Bottom-right corner"
    }
  }

  private static func clamp(_ index: Int, _ count: Int) -> Int { min(max(index, 0), count - 1) }
}

enum GestureNaming {
  static func name(_ gesture: GestureKind) -> String {
    switch gesture {
    case .slide: return "Slide"
    case .tap: return "Tap"
    case .doubleTap: return "Double-tap"
    case .longPress: return "Long-press"
    case .swipe(.up): return "Swipe up"
    case .swipe(.down): return "Swipe down"
    case .swipe(.left): return "Swipe left"
    case .swipe(.right): return "Swipe right"
    }
  }

  /// Lowercase, for running text: "a tap", "a long-press".
  static func lower(_ gesture: GestureKind) -> String { name(gesture).lowercased() }

  /// The picker's header: "Tap, bottom edge" (bone 5).
  static func pickerHeader(gesture: GestureKind?, zone: Zone) -> String {
    "\(gesture.map(name) ?? "Add gesture"), \(ZoneNaming.lowercased(zone))"
  }
}

/// Names for actions as rows and picker items show them.
enum ActionNaming {
  /// "Open App…" for an action with a **required** parameter (BRIEF § Picker at catalog scale:
  /// the "…" means "it will ask for something"); optional tuning parameters (`speedUp`, `stepMM`,
  /// `keepOpenMS`, `holdMS`) don't count, so Volume stays "Volume". Else the catalog name.
  static func pickerName(_ descriptor: ActionDescriptor) -> String {
    descriptor.parameters.contains(where: \.required) ? "\(descriptor.displayName)…" : descriptor.displayName
  }

  /// The row's label for a parameter: the catalog name in sentence case ("Shortcut name", "File or
  /// folder"), with the labels the specs give where they differ.
  static func parameterLabel(_ parameter: ActionParameter, action: ActionID) -> String {
    switch (action.rawValue, parameter.key) {
    case ("keyboard.hold", "keys"): return "Keys to hold"
    case ("app.open", "whenFrontmost"): return "If already in front"
    case (_, "maxSeconds"): return "Let go after"  // batch-15 design answer 2
    default: return sentenceCase(parameter.displayName)
    }
  }

  /// The helper line under a parameter row: the catalog's, or the spec's where the catalog has none.
  static func parameterHelp(_ parameter: ActionParameter) -> String? {
    if let help = parameter.helpText { return help }
    if parameter.key == "maxSeconds" { return "If a lift is missed, the keys come back up after this long." }
    return nil
  }

  /// "Shortcut Name" → "Shortcut name"; words in capitals ("URL") stay as they are.
  static func sentenceCase(_ text: String) -> String {
    let words = text.split(separator: " ", omittingEmptySubsequences: false)
    return words.enumerated().map { index, word in
      guard index > 0, word.count > 1, word != word.uppercased() else { return String(word) }
      return word.lowercased()
    }.joined(separator: " ")
  }

  /// An on/off choice (`speedUp`): drawn as a checkbox (BRIEF § Slide feel; the catalog has no
  /// boolean kind, so on/off is a two-value choice).
  static func isOnOff(_ parameter: ActionParameter) -> Bool {
    if case .choice(let choices) = parameter.kind { return Set(choices) == ["on", "off"] }
    return false
  }

  /// "Needs keys" / "Needs an app" (BRIEF § Binding parameters) for a missing required parameter.
  static func needs(_ parameter: ActionParameter) -> String {
    switch parameter.kind {
    case .keyCombo: return "Needs keys"
    case .appBundleID: return "Needs an app"
    case .url: return "Needs a URL"
    case .filePath: return "Needs a file or folder"
    case .text: return "Needs a shortcut name"
    case .number, .choice: return "Needs a value"
    }
  }

  /// Display labels for `choice` values.
  static func choiceLabel(_ value: String, parameter: String) -> String {
    switch (parameter, value) {
    case ("whenFrontmost", "hide"): return "Hide it"
    case ("whenFrontmost", "stay"): return "Stay"
    default: return value.prefix(1).uppercased() + value.dropFirst()
    }
  }

  /// Choice values in display order ("Hide it" before "Stay").
  static func orderedChoices(_ choices: [String], parameter: String) -> [String] {
    parameter == "whenFrontmost" ? choices.sorted { $0 == "hide" && $1 != "hide" } : choices
  }
}

/// Copy for `ValidationIssue` codes (BRIEF § Issue states, § Binding parameters).
enum IssueCopy {
  enum Style: Equatable {
    /// Error icon + `ink`.
    case error
    /// Warning icon + `ink2`.
    case warning
    /// Info icon + `ink2`.
    case info

    init(_ severity: ValidationIssue.Severity) {
      switch severity {
      case .error: self = .error
      case .warning: self = .warning
      case .info: self = .info
      }
    }

    /// SF Symbol name. Monochrome, drawn in the text's own ink: the icon carries the severity.
    var symbol: String {
      switch self {
      case .error: return "xmark.octagon"
      case .warning: return "exclamationmark.triangle"
      case .info: return "info.circle"
      }
    }
  }

  static let modifiersAlone = "Add a key. Modifiers alone work only on Hold Keys."
  static let urlScheme = "Needs a scheme, like https://"
  static let filePath = "Use a full path or start with ~"

  /// The tap-waits note (bone 7): the real double-tap window, no zone name.
  static func tapWaits(ms: String) -> String { "Tap waits \(ms) ms here to tell it from a double-tap." }
  static let useLongPress = "Use long-press instead"

  /// Message for one issue, or `nil` when the inspector doesn't show it (overlaps are said once
  /// under the split control; the tap note has its own line).
  static func message(
    for issue: ValidationIssue, parameter: ActionParameter? = nil, availability: ActionAvailability = .available
  ) -> String? {
    switch issue.code {
    case .missingParameter: return parameter.map(ActionNaming.needs) ?? "Needs a value"
    case .invalidKeyCombo:
      return issue.detail == ValidationIssue.modifierOnlyNeedsHold ? modifiersAlone : "Edgy can’t press that key."
    case .invalidURL: return urlScheme
    case .invalidFilePath: return filePath
    case .invalidBundleID: return "Choose an app."
    case .notANumber: return "Needs a number."
    case .numberOutOfRange: return "That’s outside the range this setting takes."
    case .invalidChoice: return "Choose one of the options."
    case .unknownAction: return "Edgy doesn’t know this action."
    case .shapeMismatch: return "This action doesn’t fit this gesture."
    case .gestureNotSupported: return "This zone can’t take this gesture."
    case .segmentOutOfRange: return "The config file splits this edge into more than 4 parts."
    case .duplicateBinding: return "The config file maps this gesture twice."
    case .unknownParameter: return issue.parameter.map { "This action doesn’t read “\($0)”." }
    case .actionUnavailable:
      if case .unavailable(let reason) = availability { return reason }
      return "Not available on this Mac."
    case .tapWaitsForDoubleTap: return issue.detail.map(tapWaits)
    case .overlappingZones, .invalidProfileID, .settingOutOfRange: return nil
    // Codes added after this batch (e.g. batch 20's notes) still say something.
    default: return note(for: issue)
    }
  }

  // MARK: Interaction notes (bone 7 pattern: info icon, `ink2`, one inline fix)

  /// Batch 20's slide-plus-swipes note (BRIEF § Binding parameters → Slide feel and hold timing).
  static let slideAndSwipesCode = "slideAndSwipes"
  static let slideAndSwipes = "Quick slides can look like swipes here, so swipes need a clearer flick on this edge."
  static let moveSwipes = "Move swipes to another edge"

  /// Copy for an info note: the known ones by code, any other info code by its `detail`.
  static func note(for issue: ValidationIssue) -> String? {
    switch issue.code.rawValue {
    case ValidationIssue.Code.tapWaitsForDoubleTap.rawValue: return issue.detail.map(tapWaits)
    case slideAndSwipesCode: return slideAndSwipes
    default: return issue.severity == .info ? issue.detail : nil
    }
  }

  /// "Whole edge and upper half both use Swipe up." (BRIEF § Issue states; the pattern "<part> and
  /// <part> both use <gesture>.").
  static func overlap(_ a: Zone, _ b: Zone, gesture: GestureKind) -> String {
    func part(_ zone: Zone) -> String {
      guard case .edge(let edge, let segment, let segments) = zone else { return ZoneNaming.lowercased(zone) }
      return ZoneNaming.part(edge: edge, segment: segment, segments: segments)
    }
    let text = "\(part(a)) and \(part(b)) both use \(GestureNaming.name(gesture))."
    return text.prefix(1).uppercased() + text.dropFirst()
  }
}

/// Key combos as system key symbols plus the key name: "⌃⌥ Space", "⇧⌘ 4", "fn".
enum KeyComboText {
  static func symbols(_ modifiers: Set<KeyCombo.Modifier>) -> String {
    var text = modifiers.contains(.fn) ? "fn" : ""
    let symbols: [(KeyCombo.Modifier, String)] = [(.ctrl, "⌃"), (.opt, "⌥"), (.shift, "⇧"), (.cmd, "⌘")]
    let rest = symbols.filter { modifiers.contains($0.0) }.map(\.1).joined()
    if !rest.isEmpty { text += text.isEmpty ? rest : " \(rest)" }
    return text
  }

  static func display(_ combo: KeyCombo) -> String {
    let mods = symbols(combo.modifiers)
    guard let key = combo.key else { return mods }
    let name = keyName(key)
    return mods.isEmpty ? name : "\(mods) \(name)"
  }

  /// Display text for a stored combo string; the raw text when it doesn't parse.
  static func display(_ stored: String) -> String {
    KeyCombo(stored).map(display) ?? stored
  }

  static func keyName(_ key: String) -> String {
    let named: [String: String] = [
      "return": "Return", "tab": "Tab", "space": "Space", "delete": "Delete", "forwarddelete": "Forward Delete",
      "escape": "Esc", "left": "Left Arrow", "right": "Right Arrow", "up": "Up Arrow", "down": "Down Arrow",
      "home": "Home", "end": "End", "pageup": "Page Up", "pagedown": "Page Down", "minus": "-", "equal": "=",
      "leftbracket": "[", "rightbracket": "]", "backslash": "\\", "semicolon": ";", "quote": "'", "comma": ",",
      "period": ".", "slash": "/", "grave": "`",
    ]
    if let name = named[key] { return name }
    return key.uppercased()
  }
}
