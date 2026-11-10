import EdgyCore

/// THE way a key combo or key sequence is written, on every surface: the recorder field, the pad
/// tab, the inspector sub-line, the hover line, the plates and the hold outcome's `detail`
/// (BRIEF § Binding parameters, "How a key combo is written"). There is no second formatter.
///
/// - Modifier symbols in the system order ⌃⌥⇧⌘, then the key, with no spaces: "⌃B", "⇧⌘4",
///   "⌃⌥Space", "⌃Tab", "⌥Esc", "⇧⌘[".
/// - fn is a word, so it's followed by one space: "fn Space", "fn ⌃B". Alone it's "fn".
/// - Named keys are words (Space, Tab, Return, Esc, Delete); arrows are "←", "→", "↑", "↓".
/// - Sequences join their steps with ", ": "⌃B, N".
///
/// Right-hand modifiers ("Right ⌘") stay dormant until the runtime tells them apart.
public enum KeyComboText {
  /// The one formatter: a sequence's steps (one step for a plain combo) joined by ", ".
  public static func text(_ steps: [KeyCombo]) -> String {
    steps.map { combo in
      let symbols = [KeyCombo.Modifier.ctrl, .opt, .shift, .cmd].filter(combo.modifiers.contains)
        .compactMap { modifierSymbols[$0] }.joined()
      let body = symbols + (combo.key.map(keyName) ?? "")
      guard combo.modifiers.contains(.fn) else { return body }
      return body.isEmpty ? "fn" : "fn " + body
    }.joined(separator: ", ")
  }

  /// One combo: `text([combo])`.
  public static func text(_ combo: KeyCombo) -> String { text([combo]) }

  /// Stored step strings (`["ctrl+b", "n"]`) as text; `nil` when there are none or any doesn't parse.
  public static func text(steps: [String]) -> String? {
    let combos = steps.map { KeyCombo($0) }
    guard !combos.isEmpty, !combos.contains(nil) else { return nil }
    return text(combos.compactMap { $0 })
  }

  static let modifierSymbols: [KeyCombo.Modifier: String] = [.ctrl: "⌃", .opt: "⌥", .shift: "⇧", .cmd: "⌘"]

  /// How a key reads: a word for named keys, an arrow for arrows, the symbol for punctuation,
  /// uppercase otherwise ("B", "4", "F5").
  public static func keyName(_ key: String) -> String {
    keyNames[key] ?? key.uppercased()
  }

  static let keyNames: [String: String] = [
    "return": "Return", "tab": "Tab", "space": "Space", "delete": "Delete", "forwarddelete": "Forward Delete",
    "escape": "Esc", "left": "←", "right": "→", "up": "↑", "down": "↓",
    "home": "Home", "end": "End", "pageup": "Page Up", "pagedown": "Page Down", "minus": "-", "equal": "=",
    "leftbracket": "[", "rightbracket": "]", "backslash": "\\", "semicolon": ";", "quote": "'", "comma": ",",
    "period": ".", "slash": "/", "grave": "`",
  ]
}
