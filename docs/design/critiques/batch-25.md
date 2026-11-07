# Batch 25 critique (design sign-off)

## Verdict

**NOT YET, on one item.** Batch 25 closes everything critiques 22–24 asked for. Iconless apps get the Open App tile in `ink2`, the read-only "Enabled" is `ink2`, helpers sit right, the picker follows the icon table, the split keeps the first part, the onboarding plate is centred and the run plates use past tense. The title-bar identity is superseded by the owner's ruling and isn't judged here. One regression blocks: **hovering a 2/3/4 split on a side edge erases that edge**, meaning the bar, its selection ring and its tab, instead of only fading the label. This needs one fix and two re-shots (`batch-25/window-split-hover-right-thirds`, `batch-22/window-split-hover`), not another review. Once those shots show the bar with its dividers, design signs off on the window, popover and onboarding, and only the G1 list below remains. The Switch Apps helper is OPEN but already scheduled for batch 26.

## Carried items: status

Shot names omit `-light`/`-dark`. b25 = `batch-25/`.

| # | Item | Status | Evidence |
|---|---|---|---|
| 22 M1 | Iconless app → Open App tile in `ink2` | FIXED | b25 `window-app-marks`, `popover-app-marks`, `add-app-marks`: the Huddle/Quillpad/Ledgerly tiles sample #6B4A3B light, #D9BFAE dark. Wayfare shows its own icon. Test `onlyABundleWithItsOwnIconHasAMark` |
| 16 M4 / 22 P | App marks on tabs | FIXED | b25 `window-app-marks`; re-shot `batch-16/*`, `batch-21/*` tabs |
| 17 S4 / 22 P | App marks on chips | FIXED | b25 `popover-app-marks`, `batch-21/popover-normal` |
| 16 S1 / 22 P | Read-only "Enabled" tone | FIXED | b25 `issue-broken-config`: (109,77,62) vs (63,37,29) normal; dark (215,190,173) vs (249,232,218) |
| 21 S2 / 22 S1 | Checkbox helper spacing, indent | FIXED | b25 `inspector-switch-apps-keep-open-off`, `inspector-repeat-keys-open`: helper starts at the label's x (68 pt), about 18 pt to the next row |
| 22 S2 | Split divider vs label | PARTIAL | Top/bottom fixed (b25 `window-split-hover-bottom`: the label is gone and the divider is #896852 on the bar). Side edges are broken; see Regressions |
| 22 S3 | Picker ends in a sliver | FIXED | b25 `window-picker-left-edge`: the list ends with an inset; `picker-icon-table-order` fades at the scroll edge |
| 22 S5 | Mini contact covers the edge icon | FIXED | b25 `popover-last-touch`: the speaker icon draws above the contact |
| 22 S6 | Fixtures from shipping code | FIXED | b25 `popover-menu-hover-wash` (4 rows, no config items); `strip-broken-config-wrapped` (‘x’, "Replace with current settings…", bezels) |
| 22 S7a | Stacked side-edge icons (mini) | FIXED | b25 `mini-two-icons-side-edge`: volume over mute, right edge |
| 22 S7b | Horizontal slide in "Add gesture…" | FIXED | b25 `picker-add-gesture-bottom-edge`: ↔ slide, ←/→ swipes |
| 22 A1 | Hover line: full width, short zone name | FIXED | b25 `mini-hover-line`: "Bottom: Previous Track, Next Track, Play/Pause", unclipped, x 33–601 of 640 |
| 22 A2 | Picker in icon-table order | FIXED | b25 `picker-icon-table-order`: Mute, Microphone Mute; Play/Pause, Next Track, Previous Track |
| 22 A3 | Split: first part keeps the bindings, note before the click | FIXED | b25 `window-split-hover-right-thirds`: "Upper third keeps Volume; the other two start empty."; `-bottom`: "Left half keeps …; right half starts empty." |
| 24 S1 | Struck contact clear of the Volume tab | FIXED | b25 `step2-rejected`: the circle starts about 25 pt below the tab |
| 24 S2 | Plate centred under the mirror | FIXED | b25 `step2-rejected`: plate centre 320.25 pt, mirror centre 319.75 pt |
| 23 A2 | Past-tense run plates | FIXED | b25 `plate-component`: "Opened Quillpad", "Pressed ⇧⌘ 4", "Ran Morning lights"; "Play/Pause" bare |
| BRIEF | Title-bar identity | SUPERSEDED | Owner ruling 2026-11-07, re-check in the next batch |
| BRIEF | Advanced as a quiet text button | FIXED | Every window shot: sliders icon plus "Advanced…" in `ink2`, no bezel |
| BRIEF | Switch Apps helper copy | OPEN | b25 `inspector-switch-apps-keep-open-off` still reads "Slide this far to move one app." (`ActionCatalog.swift:225`). Deferred to batch 26 by 51d3ec1. Not blocking |
| Chief | After a split, select the first part | NOT SHOT | Test `splitSelectsTheFirstPart` only; no shot shows the state after the click |

**Totals:** 17 FIXED, 1 PARTIAL, 1 OPEN, 1 NOT SHOT, 1 SUPERSEDED.

## Title-bar identity

**SUPERSEDED: owner ruling 2026-11-07, re-check in the next batch.** On device, the owner rejected the 26 pt app-icon title bar. BRIEF § Window identity (a) is being rewritten to a stateless `ink` mark: the V3 shape, no tile, 18×26 pt. The batch-25 icon isn't measured or flagged here. The next batch's critique measures the new mark: size, the gap after the traffic lights, its centre against the tab pill, the tooltip and the accessibility label.

## Regressions

1. **The side-edge split preview erases the edge.** In b25 `window-split-hover-right-thirds` and the re-shot `batch-22/window-split-hover` (light and dark), only two short divider ticks remain on the right edge. The bar fill is pad (242,211,181) where the shots at 5452a61 and 8a25a0a had `bar` (217,174,140), and the selection ring and the "Volume" tab are also gone. This breaks bone 2 (a mapped edge is a solid bar; the selected edge has an `ink` ring) and § Split control ("the edge shows its dividers"). Cause: `MirrorPad` puts `.opacity(splitPreviewHides ? 0 : 1)` on the whole label view, and a side-edge tab carries the bar's shape. Fix: fade only the label **text** (or the tab, but not the bar and ring), and keep the bar and ring drawn under the 50% dividers. Re-shoot the two shots above.

Not regressions: the title-bar row changes in every re-shot window (superseded, above). The batch-19 step diffs against 8a25a0a are the batch-24 rulings landing (step 1 has no tabs, Continue is enabled on step 2, step 3 rows are looser). The other batch-14–22 diffs are the app marks and the picker inset. Sampled and unchanged where expected: `batch-21/window-default` (light and dark), `batch-16/window-picker`, `batch-21/popover-normal`, `batch-19/step1`–`step4`, `batch-23/overlay-light-document`.

## Remaining should-fix

1. **The "real icon" fixture is Edgy's own cream tile**, so Wayfare reads as a pale square at 14 pt, especially in light (`window-app-marks`). It proves the code path but not the look. Fix: use a contrasting, mid-tone icon in the `IconApps` fixture.
2. **Switch Apps helper** (OPEN above): ship BRIEF's "Slide this far to open the switcher and move one app." in batch 26 as planned.
3. **Shoot the selection after a split** (whole → thirds, after the click) so the first-part ruling has visual evidence.

## G1 device checklist for the owner

1. Title-bar mark: once the next batch ships the new ink mark, check its spacing after the window buttons and its tooltip "Edgy" on the real window.
2. Add a real app with a colourful icon: its 14 pt tab mark and popover chip read clearly, not as a pale or grey square.
3. Add an app that has no icon of its own: it shows the outlined Open App tile, not the system's blank icon.
4. In the real popover, hover a busy edge: the line under the mini mirror fits the width and isn't clipped.
5. Look at the menu bar next to the battery: the Lit-strip glyph never reads as a second battery.
6. Switch colours (Enabled, Test Mode, Haptics, Launch at login) look right when the window is active.
7. Onboarding step 2: note where the system volume indicator appears, and that nothing in Edgy repeats the percentage.
8. The mirror's pad slab has a soft depth, with no flat or muddy edge.
9. Window and popover glass over your own wallpapers: the text stays easy to read.

## Questions for design

1. **Split preview on side edges:** when fading the label, should the side-edge tab keep its shape (text only fades), or should the tab fold into the bar while the bar and ring stay? Either fixes the regression. I'd fade the text only, so the zone keeps its silhouette.

## Design answers (chief, 2026-11-07)
1. **Split preview on side edges:** fade **only the label text**. The tab keeps its shape, and the bar, selection ring and tab silhouette all stay drawn, so the zone never disappears. Once the two re-shots show this, design signs off on the window, popover and onboarding. The title-bar mark is re-checked separately in its own small batch.

## Sign-off (chief, 2026-11-07, after batch 27 / 84328c7)
- **Side-edge split regression: FIXED.** In `batch-25/window-split-hover-right-thirds-*`, the right edge keeps its bar, ring and tab shape; only the "Volume" text fades; the thirds dividers preview at `ink` 50%; the note "Upper third keeps Volume; the other two start empty." is present.
- **Ink mark (`batch-27/title-bar-zoom-*`, `window-identity-*`):** the V3 shape with no tile, in `ink`, vertically centred on the tab pill. The gap after the traffic lights can't be measured headlessly, so it goes to G1.
- **Push-to-talk:** the Hold Keys sub-line and search aliases are verbatim in `PickerCatalog.swift:96,102`. `inspector-hold-keys-empty-*` shows "Needs keys", "Click to record" and the exact helper line under the recorder.

**DESIGN SIGNS OFF on the settings window, the menu-bar popover, onboarding and the Test Mode overlay.** What remains is the owner's G1 device checklist (above) and any of his taste calls from it.
