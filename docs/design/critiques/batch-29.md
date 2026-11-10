# Batch 29 critique (names, icons, sequences, targets, Last App)

Verdict: the features are built and mostly faithful. "Name and Icon…" is in the row menu and the popover matches the spec. Precedence (custom > target > action) holds on tabs, icons, the hover line and the inspector. Plates drop the verb for a custom name. Hold Keys leads a long-press picker with the push-to-talk sub-line, and Last App sits second in Apps with an icon that matches `app-last.svg` path for path. "Use Escape" and "+ Then…" appear and hide where they should. Fixtures use invented names only (Quillpad, Wayfare, Huddle, example.com, report.pdf); the Wayfare mark is the invented test icon. Not ready: every key combo on every surface breaks the just-ruled format, and two helpers disagree with each other. Fix the 3 items below and re-shoot.

## Must fix

1. **A space between the modifiers and the key, on every surface.** BRIEF: "Modifier symbols in the system order ⌃⌥⇧⌘, then the key, with **no spaces**: "⌃B", "⇧⌘4"… Sequences join steps with ", ": "⌃B, N"." The builder kept the old space on purpose (done-batch-29, Decisions). Instances in the shots:
   - Recorder field: "⌃ B" (`recorder-one-step`), "⌃ B, N" (`recorder-two-steps`), "⌃ B, Esc" (`recorder-escape-recorded`), "⌃ B, N, ⌘ K, X" (`recorder-four-steps`).
   - Inspector row text: the same four strings, top right of each recorder shot.
   - Pad tabs: "⌃ Tab" (`pad-shortcut-edge-and-corner`), "⌃ B, N" (`pad-tab-sequence`).
   - Plates: "Pressed ⌃ B, N" and "Would press ⌃ B, N" (`plate-sequence`).
   - Refreshed folders: "⇧⌘ [" in the inspector row and "⇧⌘ [, Next Track and Play/Pause" on the bottom bar (`batch-14/pad-wayfare`, `batch-15/inspector-wayfare-sources`, `batch-16/tab-wayfare`, `batch-21/tab-wayfare`).
   Fix: glue the modifiers to the key; update the tests and the doc comments that still teach "⌃⌥ Space".
2. **Two helpers, and they disagree about fn.** BRIEF: "one helper for every surface… fn is a word, so it's followed by one space: "fn Space", "fn ⌃B"." `KeyComboText.symbols` (field, tab, inspector, hover) writes "fn ⌃". `KeyCombo.displayText` (`DisplayCheck.swift`, used by `PlateNaming.keys` and the hold plates) writes "fn⌃", with no space. The builder flags this as an open question. Fix: delete one and route every surface, plates included, through the other. The output should be "fn ⌃B", "fn Space", "fn".
3. **Arrows read "Left Arrow".** Both key-name tables map left/right/up/down to "Left Arrow" etc. BRIEF: "arrows as "←", "→", "↑", "↓"." No shot shows it, but the table is shared by every surface. Fix it in the one helper (item 2) and add a test.

## Should fix

1. **Sub-lines go two ways on one row.** The target and custom sub-lines are right-aligned under the value ("Open App", "Hold Keys: fn Space"). The override line "Default: Previous Track" is left-aligned under the gesture. On an overridden Keyboard Shortcut row both stack, in opposite alignments ("Keyboard Shortcut" right, then "Default: Previous Track" left; `batch-15/inspector-wayfare-sources`, `batch-16/tab-wayfare`). Fix: one alignment for every inspector sub-line. Left, under the gesture name, matches the existing "Default:" line. Keep two lines (joining them would need a middot, which is on the kill list), same alignment.
2. **The Name and Icon grid opens with its selection out of sight.** `name-and-icon-empty`: the action is Hold Keys, but the grid stops at Windows (300 pt cap) with no scroll hint. The ringed own-icon is below the fold, so the popover looks as if nothing is selected and Apps, Keyboard and Shortcuts look missing. Fix: scroll the selected cell into view on open, the same as the picker's checked row.
3. **Duplicate cells in the grid.** Display shows two identical keyboard-with-rays icons (`keyboard-backlight.svg` and `keyboard-backlight-toggle.svg` are byte-identical). In a picker of icons, two equal cells are a coin flip. Fix: show the drawing once (store either ID), or see Q4.
4. **"+ Then…" moves the field.** At 4 steps the button hides and the field jumps about 60 pt right (`recorder-two-steps` vs `recorder-four-steps`). The builder raises it too. Fix: reserve the button's width, or keep the field anchored left after the label.
5. **The plate fixture is incoherent.** "Dictate" is the Hold Keys binding on the long-press (`inspector-row-custom-name`), but `plate-custom-run` and `plate-custom-dry-run` put it on "Bottom-right corner, double-tap". Hold Keys can't take a double-tap. Fix: shoot run/dry run on a custom-named trigger (e.g. "Notes" on Open App), or on the long-press.

## Matches BRIEF

- Name and Icon popover: 320 pt, action name as placeholder, 16/28 pt grid under 11 pt headers, `ink` ring, Reset only when set.
- Inspector row pattern: custom or target name in `ink` ("Dictate", "Quillpad", "fn"), real action in an `ink2` sub-line ("Hold Keys: fn Space", "Open App", "Hold Keys"). "Needs keys" in `ink2` when empty.
- Pad tabs: target or custom name, 12 pt fade, never "…"; no tab reads "Keyboard Shortcut".
- Zone icons: custom icon; Open App fallback tile in `ink2` (sampled #6B4A3B). App marks get `.saturation(0)` and 70% in dark in code; headless shots show colour, as in batch 27 (device check).
- Hover line: "Bottom-right: Dictate", "Top-right: Wayfare"; height reserved when empty.
- Plates: "Dictate", "Dictate, held", "Dictate, released", "Would run Dictate", character for character.
- Recorder: accent ring, "Press keys…"; "Use Escape" under the field, not on Hold Keys; "+ Then…" hidden while recording and at 4 steps.
- Picker: long-press puts Keyboard, then Hold Keys, first, with its push-to-talk sub-line; other gestures unchanged. Last App second in Apps, no sub-line.
- Last App icon: `IconData` reproduces `app-last.svg` element for element (tile, hook, arrowhead, 1.5 stroke); the 16 pt render matches.
- One hue and the type scale intact.

## Regressions

- `batch-14/15/16/21`: tabs and rows now show the target, as ruled. The only regressions are must-fix 1 ("⇧⌘ [") and should-fix 1 (two sub-line alignments on one row).
- `batch-15/22/27` pickers and Hold Keys inspectors, window default, mini popover, plates: changed only as ruled.

## Questions for design

1. **Edge labels join several bindings with ", ", which is now the sequence separator.** The bottom bar reads "⇧⌘[, Next Track and Play/Pause" once fixed, which looks like a two-step sequence. Should a combined edge label use the action's short name for keys ("Shortcut, Next Track and Play/Pause"), or another joiner?
2. **Dry run on a custom-named hold or slide.** The builder writes "Would hold Dictate" and "Would set Dictate"; BRIEF only gives "Would run Dictate". Accept the verb by kind, or always "Would run"?
3. **Corner tabs clip short targets.** "example.com" fades to "example.co" (`pad-url-and-file-tabs`). Is the corner tab's width cap intended, or may it grow toward the bar's length before fading?
4. **Keyboard Brightness and Keyboard Backlight On/Off share one drawing.** For the Name and Icon grid, show it once, or draw the toggle differently (e.g. a keycap with rays and a slash-free on/off tick)?
5. **Right-hand modifiers.** Nothing in the code produces "Right ⌘". Does the runtime not distinguish them yet, so that rule is dormant?
6. **Rename carry on an inherited row.** After a rename, picking a new action on an inherited row carries Default's name into the new override (builder's open question). Wanted?

## Design answers (chief, 2026-11-09)
1. **Combined edge labels never use commas** (", " is the sequence separator). Two bindings: "A and B" ("⇧⌘[ and Play/Pause"). Three or more: "A and 2 more" ("⇧⌘[ and 2 more"). The hover line and inspector list them all. Items in gesture order.
2. **Dry-run verb by kind:** accepted. "Would set Dictate" (continuous), "Would hold Dictate" (hold), "Would run Dictate" (trigger). Run mode stays verb-less for custom names.
3. **Corner tabs** may grow along their adjacent edge up to **40% of that edge's length** before the fade applies, so "example.com" fits.
4. **Duplicate drawings in the Name and Icon grid:** show each drawing **once**. Keyboard Brightness and Keyboard Backlight On/Off share one cell whose tooltip names both. No new drawing in v1.
5. **Right-hand modifiers:** the rule is dormant until the runtime distinguishes them. No change.
6. **Rename carry:** **no.** A custom name carries only within the same binding. Picking a new action on an inherited row creates an override **without** Default's custom name. On an already-overridden row, a name the user set there carries.

Must-fix 1–3 stand: one formatter (`KeyComboText`) for every surface, the BRIEF format (no spaces inside a combo; "fn" + one space), and arrows as ←→↑↓. Remove `KeyCombo.displayText` or route it through the helper.
