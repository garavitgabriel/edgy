import Foundation

/// A keyboard shortcut as stored in `Binding.parameters`: lowercase modifiers then one key,
/// joined by `+`, e.g. `"cmd+shift+4"`, `"ctrl+opt+left"`, `"f5"`.
///
/// Parsing is forgiving (any order, any case, a few aliases); `description` is the canonical
/// form (modifiers in `Modifier.allCases` order). Mapping keys to hardware key codes is the
/// Actions module's job; this type only owns the vocabulary.
public struct KeyCombo: Hashable, Sendable, CustomStringConvertible {
  public enum Modifier: String, CaseIterable, Hashable, Sendable {
    case ctrl, opt, shift, cmd, fn
  }

  public var modifiers: Set<Modifier>
  /// A name from `KeyCombo.keyNames`.
  public var key: String

  /// Every key a combo may end in.
  public static let keyNames: [String] = {
    let letters = "abcdefghijklmnopqrstuvwxyz".map(String.init)
    let digits = (0...9).map(String.init)
    let functionKeys = (1...20).map { "f\($0)" }
    let named = [
      "return", "tab", "space", "delete", "forwarddelete", "escape",
      "left", "right", "up", "down", "home", "end", "pageup", "pagedown",
      "minus", "equal", "leftbracket", "rightbracket", "backslash", "semicolon", "quote",
      "comma", "period", "slash", "grave",
    ]
    return letters + digits + functionKeys + named
  }()

  private static let keySet = Set(keyNames)

  private static let modifierAliases: [String: Modifier] = [
    "ctrl": .ctrl, "control": .ctrl, "⌃": .ctrl,
    "opt": .opt, "option": .opt, "alt": .opt, "⌥": .opt,
    "shift": .shift, "⇧": .shift,
    "cmd": .cmd, "command": .cmd, "⌘": .cmd,
    "fn": .fn,
  ]

  private static let keyAliases: [String: String] = [
    "enter": "return", "esc": "escape", "backspace": "delete", "del": "forwarddelete",
    "-": "minus", "=": "equal", "[": "leftbracket", "]": "rightbracket", "\\": "backslash",
    ";": "semicolon", "'": "quote", ",": "comma", ".": "period", "/": "slash", "`": "grave",
  ]

  public init(modifiers: Set<Modifier>, key: String) {
    self.modifiers = modifiers
    self.key = key
  }

  /// Parses `"cmd+shift+4"`-style text. Returns `nil` unless there is exactly one known key.
  public init?(_ text: String) {
    let parts = text.lowercased().split(separator: "+", omittingEmptySubsequences: false).map {
      $0.trimmingCharacters(in: .whitespaces)
    }
    guard !parts.isEmpty, !parts.contains(where: \.isEmpty) else { return nil }
    var modifiers = Set<Modifier>()
    var key: String?
    for part in parts {
      if let modifier = Self.modifierAliases[part] {
        guard !modifiers.contains(modifier) else { return nil }
        modifiers.insert(modifier)
      } else {
        let name = Self.keyAliases[part] ?? part
        guard key == nil, Self.keySet.contains(name) else { return nil }
        key = name
      }
    }
    guard let key else { return nil }
    self.init(modifiers: modifiers, key: key)
  }

  public var description: String {
    (Modifier.allCases.filter(modifiers.contains).map(\.rawValue) + [key]).joined(separator: "+")
  }
}
