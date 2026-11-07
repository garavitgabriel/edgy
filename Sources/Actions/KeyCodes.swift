import CoreGraphics
import EdgyCore

/// Hardware key codes for `KeyCombo`, by key position on an ANSI keyboard.
///
/// Codes name physical keys, so on other layouts a letter combo presses the key at that ANSI
/// position — the same thing the system does for shortcuts typed on a remapped layout.
enum KeyCodes {
  /// Virtual key code for every name in `KeyCombo.keyNames`.
  static let byName: [String: CGKeyCode] = [
    "a": 0x00, "s": 0x01, "d": 0x02, "f": 0x03, "h": 0x04, "g": 0x05, "z": 0x06, "x": 0x07,
    "c": 0x08, "v": 0x09, "b": 0x0B, "q": 0x0C, "w": 0x0D, "e": 0x0E, "r": 0x0F, "y": 0x10,
    "t": 0x11, "o": 0x1F, "u": 0x20, "i": 0x22, "p": 0x23, "l": 0x25, "j": 0x26, "k": 0x28,
    "n": 0x2D, "m": 0x2E,
    "1": 0x12, "2": 0x13, "3": 0x14, "4": 0x15, "6": 0x16, "5": 0x17, "9": 0x19, "7": 0x1A,
    "8": 0x1C, "0": 0x1D,
    "equal": 0x18, "minus": 0x1B, "rightbracket": 0x1E, "leftbracket": 0x21, "quote": 0x27,
    "semicolon": 0x29, "backslash": 0x2A, "comma": 0x2B, "slash": 0x2C, "period": 0x2F,
    "grave": 0x32,
    "return": 0x24, "tab": 0x30, "space": 0x31, "delete": 0x33, "escape": 0x35,
    "forwarddelete": 0x75, "home": 0x73, "end": 0x77, "pageup": 0x74, "pagedown": 0x79,
    "left": 0x7B, "right": 0x7C, "down": 0x7D, "up": 0x7E,
    "f1": 0x7A, "f2": 0x78, "f3": 0x63, "f4": 0x76, "f5": 0x60, "f6": 0x61, "f7": 0x62,
    "f8": 0x64, "f9": 0x65, "f10": 0x6D, "f11": 0x67, "f12": 0x6F, "f13": 0x69, "f14": 0x6B,
    "f15": 0x71, "f16": 0x6A, "f17": 0x40, "f18": 0x4F, "f19": 0x50, "f20": 0x5A,
  ]

  /// Key codes and event flags of the modifier keys themselves.
  static let modifiers: [KeyCombo.Modifier: (code: CGKeyCode, flag: CGEventFlags)] = [
    .ctrl: (0x3B, .maskControl),
    .opt: (0x3A, .maskAlternate),
    .shift: (0x38, .maskShift),
    .cmd: (0x37, .maskCommand),
    .fn: (0x3F, .maskSecondaryFn),
  ]

  /// The `KeyCombo` name of a virtual key code, `nil` for keys Edgy has no name for.
  static func name(for keyCode: Int64) -> String? { namesByCode[keyCode] }

  private static let namesByCode: [Int64: String] = Dictionary(
    uniqueKeysWithValues: byName.map { (Int64($0.value), $0.key) })

  /// The modifiers whose generic flags are set in `flags` (device bits and others ignored).
  static func modifiers(in flags: CGEventFlags) -> Set<KeyCombo.Modifier> {
    Set(KeyCombo.Modifier.allCases.filter { modifiers[$0].map { flags.contains($0.flag) } ?? false })
  }

  /// Device-dependent flag bits a real keyboard sets alongside each generic modifier flag, for
  /// the left-hand key (the key codes in `modifiers` are the left-hand ones). Some apps that
  /// listen for a bare modifier check these bits to tell left from right. fn has none: its only
  /// signal is `.maskSecondaryFn`.
  static let deviceBits: [KeyCombo.Modifier: UInt64] = [
    .ctrl: 0x0000_0001, .shift: 0x0000_0002, .cmd: 0x0000_0008, .opt: 0x0000_0020,
  ]

  /// Flags of a set of held modifier keys, as a real keyboard reports them: each modifier's
  /// generic flag plus its left-hand device bit.
  static func heldFlags(_ held: Set<KeyCombo.Modifier>) -> CGEventFlags {
    held.reduce(into: CGEventFlags()) { flags, modifier in
      guard let entry = modifiers[modifier] else { return }
      flags.insert(entry.flag)
      flags.insert(CGEventFlags(rawValue: deviceBits[modifier] ?? 0))
    }
  }

  /// One event of a modifier key going down or up.
  struct ModifierEvent: Equatable {
    var modifier: KeyCombo.Modifier
    var code: CGKeyCode
    var down: Bool
    /// The full modifier state *after* this key changed, which is what a flags-changed event
    /// carries (so a key-up carries the modifiers still held, not its own flag).
    var flags: CGEventFlags
  }

  /// The events that press (or release) `modifiers` in the order given, starting from `held`,
  /// and the held set afterwards. Pressing a held modifier, or releasing one that isn't, still
  /// emits its event (the system ignores a duplicate) so a stuck key can always be released.
  ///
  /// On macOS 27 a keyboard event built for a modifier key code is a **flags-changed** event
  /// (type 12), not a key-down: that is the route a key-listening app watches for a bare
  /// modifier such as a dictation app's fn push-to-talk key. The live output also sets the type
  /// explicitly, so the route doesn't depend on that inference.
  static func modifierEvents(
    _ modifiers: [KeyCombo.Modifier], down: Bool, held: Set<KeyCombo.Modifier>
  ) -> (events: [ModifierEvent], held: Set<KeyCombo.Modifier>) {
    var held = held
    var events: [ModifierEvent] = []
    for modifier in modifiers {
      guard let entry = self.modifiers[modifier] else { continue }
      if down { held.insert(modifier) } else { held.remove(modifier) }
      events.append(ModifierEvent(modifier: modifier, code: entry.code, down: down, flags: heldFlags(held)))
    }
    return (events, held)
  }

  /// Keys a real keyboard reports with extra flags: arrows carry the numeric-pad and function
  /// flags, the other navigation and function keys carry the function flag. Some system
  /// shortcuts (e.g. switching Spaces with ctrl+arrow) only match events that look like that.
  static func implicitFlags(for key: String) -> CGEventFlags {
    switch key {
    case "left", "right", "up", "down": return [.maskNumericPad, .maskSecondaryFn]
    case "home", "end", "pageup", "pagedown", "forwarddelete": return .maskSecondaryFn
    default: return key.hasPrefix("f") && key.count > 1 ? .maskSecondaryFn : []
    }
  }

  /// The flags for a whole combo: its modifiers plus the key's implicit flags.
  static func flags(for combo: KeyCombo) -> CGEventFlags {
    combo.modifiers.reduce(implicitFlags(for: combo.key ?? "")) { $0.union(modifiers[$1]?.flag ?? []) }
  }
}
