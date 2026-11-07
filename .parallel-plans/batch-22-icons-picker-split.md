# Batch 22 — EDGY-ICONS: action icon family, picker clarity, split control

Read `CLAUDE.md` (incl. "Design and brand"), `.parallel-plans/2026-11-07-edgy-v05.md` (hard rules), `docs/BRIEF.md` § Design — especially the new **§ "Picker clarity: icons and rhythm"** and **§ "Split control"** — and `docs/BRAND.md` (iconography). The design session will add renders of the new picker, an icon sheet and the split control; follow BRIEF's text where a render is missing or differs.

## Two phases (the polish batch 21 owns Picker/ and Inspector/ until it merges)

**Phase A — now:** you own `Sources/EdgyUI/Icons/**` (new folder), `Tests/EdgyUITests/Icons/**`, `docs/design/build-shots/batch-22/**`.
1. **The action icon family** from BRIEF's icon table: every catalog action id → one icon, custom drawn (SwiftUI `Shape`/`Path`), 1.5 pt stroke on the gesture-icon grid, one family; never SF Symbols or stock glyphs for actions (the gesture icons already in Inspector/ are the reference for stroke and grid — read, don't edit). Public API: `ActionIcon(id: ActionID, size: CGFloat = 16)` and an `ActionIcons.has(_:)` coverage check. A test proves every id in the real catalog (`makeLiveActionRegistry(settings: .defaults).available`) has an icon.
2. A **split-control drawing**: `EdgySplitGlyph(edge:parts:selected:)` — this edge in its orientation (40×12 top/bottom, 12×40 left/right), divided into 1–4 parts, selected one filled `ink`, no numbers.
3. Snapshots: an icon sheet (all actions, light/dark, 16 pt and 2×) and the split glyphs (both orientations, every count, selected/unselected).

**Phase B — after batch 21 merges (the chief messages you; `git merge main`, no rebase):** your glob grows to `Sources/EdgyUI/Picker/**`, `Sources/EdgyUI/Inspector/**` and their tests (batch 21 will be done by then).
4. **Picker rows** per § Picker clarity: 16 pt icon in a 24 pt column, name 13 ink, trailing checkmark on the bound action, 28 / 44 pt rows, group header rhythm (11 semibold ink2, 14 above / 4 below, no separators), unavailable/limited styling, search keeps headers of groups with matches, empty state copy exactly as BRIEF.
5. **Split control** per § Split control replacing "Split into 1 2 3 4": label + four glyphs, hover previews dividers on the mirror (publish the hover state through `SettingsModel` extension in your folder or a closure — not by editing Mirror/; if the mirror needs a hook, write a blocker), accessibility names, hidden on corners and app tabs, one undo step, the info note before bindings move or drop.

## Acceptance
- Phase A: every catalog action has an icon (test), icon sheet + split glyph shots, token greps clean (icons use `Tokens` colours only).
- Phase B: picker and split shots in light/dark (picker at catalog scale, searched, empty search, unavailable + limited rows, bound checkmark; split for each edge orientation and count, hover preview, the info note), tests for search/headers/empty state, split change + undo + note.
- Reader-first review against the design session's new renders; verification triple + denylist clean.
