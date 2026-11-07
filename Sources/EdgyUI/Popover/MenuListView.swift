import AppKit
import SwiftUI

/// The popover's bottom half: a plain list with the system highlight (bone 10). Rows read like a
/// menu: title on the left, the shortcut in `ink2` on the right, a separator before About.
///
/// The hover highlight is the system's own menu selection (`selectedContentBackgroundColor`, with
/// `selectedMenuItemTextColor` text), which follows the user's system setting. BRIEF asks for "the
/// system highlight" here, and system-drawn chrome is exempt from the one-hue rule (§ Tokens).
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

/// The system's menu selection colours (system chrome; not an Edgy colour).
enum MenuHighlight {
  static let background = Color(nsColor: .selectedContentBackgroundColor)
  static let text = Color(nsColor: .selectedMenuItemTextColor)
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
