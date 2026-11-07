import AppKit
import SwiftUI

/// The popover's bottom half: a plain list with the system highlight (bone 10). Rows read like a
/// menu: title on the left, the shortcut in `ink2` on the right, a separator before About.
///
/// The highlight behaves like a menu's (the full row lights on hover), but in `ink` at low
/// opacity, not the system selection colour: § Tokens says "no blue selection", and its system
/// chrome exception covers only what macOS draws itself (window buttons, the title bar).
struct MenuListView: View {
  let model: SettingsModel
  let rows: [MenuRow]
  let actions: MenuBarActions
  let now: @MainActor () -> Date

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      ForEach(rows, id: \.self) { row in
        if row.startsSecondGroup {
          Tokens.line.opacity(0.35).frame(height: 1)
            .padding(.horizontal, PopoverMetrics.inset - PopoverMetrics.listInset)
            .padding(.vertical, 5)
        }
        MenuRowButton(row: row) { row.perform(actions: actions, model: model, now: now()) }
      }
    }
    .padding(.top, PopoverMetrics.listInset)
  }
}

struct MenuRowButton: View {
  let row: MenuRow
  let perform: () -> Void
  @State private var hovering = false

  var body: some View {
    Button(action: perform) {
      HStack {
        Text(row.title)
        Spacer(minLength: 12)
        if let shortcut = row.shortcut {
          Text(shortcut).foregroundStyle(hovering ? MenuHighlight.text : Tokens.ink2)
        }
      }
      .foregroundStyle(hovering ? MenuHighlight.text : Tokens.ink)
      .padding(.horizontal, PopoverMetrics.inset - PopoverMetrics.listInset)
      .padding(.vertical, 4)
      .background {
        if hovering { RoundedRectangle(cornerRadius: Tokens.radiusControl - 2).fill(MenuHighlight.background) }
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .onHover { hovering = $0 }
    .modifier(RowShortcut(key: row.key))
  }
}

/// The row highlight: one hue, so an `ink` wash with `ink` text.
enum MenuHighlight {
  static let background = Tokens.ink.opacity(0.1)
  static let text = Tokens.ink
}

private struct RowShortcut: ViewModifier {
  let key: Character?

  func body(content: Content) -> some View {
    if let key {
      content.keyboardShortcut(KeyEquivalent(key), modifiers: .command)
    } else {
      content
    }
  }
}
