import EdgyCore
import Testing

@testable import Actions

/// Every example in BRIEF § Binding parameters, "How a key combo is written" (batch 33), through
/// the one formatter.
@Suite struct KeyComboTextTests {
  static let briefExamples: [(stored: [String], text: String)] = [
    // Modifier symbols in ⌃⌥⇧⌘ order, then the key, no spaces.
    (["ctrl+b"], "⌃B"),
    (["cmd+shift+4"], "⇧⌘4"),
    (["shift+cmd+4"], "⇧⌘4"),
    (["ctrl+opt+space"], "⌃⌥Space"),
    (["ctrl+tab"], "⌃Tab"),
    (["opt+escape"], "⌥Esc"),
    (["cmd+shift+leftbracket"], "⇧⌘["),
    (["cmd+opt+shift+ctrl+a"], "⌃⌥⇧⌘A"),
    // fn is a word followed by one space; alone it's "fn".
    (["fn+space"], "fn Space"),
    (["fn+ctrl+b"], "fn ⌃B"),
    (["fn"], "fn"),
    (["fn+ctrl"], "fn ⌃"),
    (["ctrl+opt"], "⌃⌥"),
    // Named keys are words; arrows are arrows.
    (["space"], "Space"), (["tab"], "Tab"), (["return"], "Return"), (["escape"], "Esc"), (["delete"], "Delete"),
    (["left"], "←"), (["right"], "→"), (["up"], "↑"), (["down"], "↓"),
    (["ctrl+opt+left"], "⌃⌥←"),
    (["f5"], "F5"), (["a"], "A"),
    // Sequences join steps with ", ".
    (["ctrl+b", "n"], "⌃B, N"),
    (["ctrl+b", "escape"], "⌃B, Esc"),
    (["ctrl+b", "n", "cmd+k", "x"], "⌃B, N, ⌘K, X"),
  ]

  @Test(arguments: briefExamples.indices)
  func briefExample(_ index: Int) {
    let example = Self.briefExamples[index]
    #expect(KeyComboText.text(steps: example.stored) == example.text)
  }

  @Test func singleComboIsAOneStepSequence() {
    let combo = KeyCombo(modifiers: [.cmd, .shift], key: "4")
    #expect(KeyComboText.text(combo) == KeyComboText.text([combo]))
  }

  @Test func unparsableOrEmptyStepsHaveNoText() {
    #expect(KeyComboText.text(steps: []) == nil)
    #expect(KeyComboText.text(steps: ["ctrl+b", ""]) == nil)
    #expect(KeyComboText.text(steps: ["nope+b"]) == nil)
  }

  @Test func noComboTextHasASpaceAfterAModifierSymbol() {
    for example in Self.briefExamples {
      #expect(example.text.range(of: "[⌃⌥⇧⌘] ", options: .regularExpression) == nil)
      #expect(!example.text.contains("Arrow"))
    }
  }
}
