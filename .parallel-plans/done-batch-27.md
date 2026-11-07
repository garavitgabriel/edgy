---
batch: 27
tag: EDGY-SIGNOFF
branch: worktree-edgy-signoff
worktree_path: ~/Projects/edgy/.claude/worktrees/edgy-signoff
completed_at: 2026-11-07
verification: after the last format pass, with main (6ab4e59, batch 26) merged: `swift build` ✔ · `swift test` ✔ (every run passes; EdgyUI 414 tests) · `swift format lint --strict -r Sources Tests Package.swift` ✔ · denylist ✔ (empty) · token greps ✔ (empty) · `git diff --name-only main...` only owned paths
---

# Done: batch 27 (critique 25 regression, the Edgy mark, findable Hold Keys)

Shots are in `docs/design/build-shots/`, each as `-light.png` + `-dark.png`. b27 = `batch-27/`. Tests: `Tests/EdgyUITests/Window/Batch27SnapshotTests.swift` (S27) and `Tests/EdgyUITests/Mirror/Batch27MirrorTests.swift` (M27).

## Acceptance criteria

| # | Item | Status | Proof |
|---|---|---|---|
| 1 | Side-edge split preview fades **only the label text** | ✔ | `MirrorPad.label`: the opacity now sits on `labelText` inside the tab, so the tab keeps its shape and the bar, dividers, ring and silhouette stay drawn. Test: M27 `splitPreviewKeepsTheSideBarAndRing` (light + dark). It renders the pad with the right edge selected and a thirds preview, then samples the bar's centre line mid-way through each third (it must be `bar`, not `padTop`) and the ring outside the bar (it must be `ink`). **Checked against the old code:** with batch 25's `MirrorPad.swift` restored, it fails in both appearances (bar and ring). Batch 25's `splitPreviewFadesTheEdgeLabels` still passes. Re-shot: `batch-25/window-split-hover-right-thirds`, `batch-22/window-split-hover` (also `batch-22/window-split-hover-bottom`, `batch-25/window-split-hover-bottom`) |
| 2a | "Real icon" fixture is mid-tone | ✔ | `IconApps` (in `Window/Batch21SnapshotTests.swift`) draws an invented slate tile with a light diamond into the Wayfare bundle's `AppIcon.icns`, in place of Edgy's cream icon. The bundle also gets a stub executable, a two-line shell script that is never run. Without one, the system stamps its "can't open" badge over the icon, which is what made batch 25's stand-in read pale. The temp folder is renamed so the system's icon cache can't serve the old drawing. Test: S27 `realIconFixtureIsMidTone` (the system's icon for the bundle has a mid brightness, between 0.3 and 0.75). Shots: b27 `window-app-marks`; re-shot `batch-25/window-app-marks`, `popover-app-marks`, `add-app-marks` |
| 2b | Shot of the selection after a split | ✔ | S27 `splitSelectsFirstPartShot`: whole right edge → thirds after the click, so the upper third is selected and holds the Volume row. Shot: b27 `split-selects-first-part` |
| 3 | The Edgy mark in the title bar | ✔ | `WindowIdentity`: `Tokens.ink` masked by the bundled `mark-edgy.pdf` (a non-template `NSImage`, used only as a mask so the system never tints it; the strip is `ink` too). Size `titleMarkWidth` × `titleMarkHeight` (26 × 18). `titleIconLeading` (12) after the traffic lights. Centred on the tab pill by the shared title-bar row. No outline, shadow or states. Tooltip + accessibility label "Edgy"; not a button. It no longer reads `titleIconSize` / `titleIconOutline*` (grep: no reader left in EdgyUI). The asset is copied byte for byte to `Sources/EdgyUI/Glyph/Assets/mark-edgy.pdf`. Test: S27 `titleBarIsTheInkMark` (sizes, leading, label, non-template, 16:11, bundled bytes == exported). Batch 25's `titleBarIsTheAppIconOnly` keeps its old 26 pt assertion as a comment naming the ruling. Shots: b27 `title-bar-zoom` (measured at 2× zoom: 104 × 72 px = 26 × 18 pt, centre line on the pill's), `window-identity` |
| 4A | Hold Keys picker sub-line + search | ✔ | `PickerCatalog.useLine` / `searchAliases`; `Item.subtitle` returns the use line only while `.available`, so limited/unavailable reasons win. Tests: S27 `holdKeysSubLineDescribesUse` (copy verbatim; the only available sub-line; limited and unavailable reasons win), `searchFindsHoldKeysByUse` ("hold", "push to talk", "talk", "dictation", "voice", case-insensitive; "volume" doesn't find it). Shots: b27 `picker-hold-keys-subline`, `picker-search-talk` |
| 4B | Empty-keys hint under the recorder | ✔ | `HoldKeysHint` (`Inspector/ParameterEditors.swift`), shown as the row's helper line (13, `ink2`, the 8 pt helper spacing) only while Hold Keys' keys are empty. There are no chips. Test: S27 `holdKeysEmptyHintUnderTheRecorder` (copy verbatim; gone with "fn"; never on other actions). Shots: b27 `inspector-hold-keys-empty` (hint), `inspector-hold-keys-fn` (no hint) |
| 5 | Chief: Switch Apps helper follows the batch 26 catalog | ✔ | Merged main (6ab4e59). `ParameterPresentationTests.unitFollowsTheValue` and `Batch15SnapshotTests.parameterPresentationFields` now use "Slide this far to open the switcher and move one app."; the old literal is kept as a comment naming the batch 26 ruling. Re-shot: `batch-22/inspector-switch-apps-keep-open-off` (and `batch-25/` of the same name), which read the real catalog |

## Bones checklist (BRIEF § Bones)

- [x] 1 The mirror is the pad: `batch-25/window-split-hover-right-thirds`
- [x] 2 Zone states by shape, a mapped edge is a solid bar, the selected edge has an `ink` ring: `batch-25/window-split-hover-right-thirds`, `batch-22/window-split-hover` (the bar and ring stay under the preview)
- [x] 3 Labels joined to their zone, never cut by a divider: same shots (the text fades, the tab keeps its shape)
- [x] 4 Recognized vs rejected: n/a for this batch
- [x] 5 You map on the pad: b27 `picker-hold-keys-subline`
- [x] 6 The inspector: b27 `inspector-hold-keys-empty`, `split-selects-first-part`
- [x] 7 Notes named with their fix: the split note is unchanged in `window-split-hover-right-thirds`
- [x] 8 Each status said once; accent means live only: the title mark is `ink`, never accent (b27 `title-bar-zoom`)
- [x] 9 The overlay: n/a for this batch
- [x] 10 The popover: `batch-25/popover-app-marks` (mid-tone mark on the chip)

## Reader-first review

- **Window, split preview** (`batch-25/window-split-hover-right-thirds-dark`): the right bar, its `ink` ring and the tab's silhouette are all there, with the two 50% dividers across the bar. Only "Volume" is gone. This matches design answer 1.
- **Title bar** (b27 `title-bar-zoom`): a solid `ink` pad with its strip cut out, no tile. It sits 12 pt after the traffic-light slot and shares the "Default" pill's centre line. In dark it's the cream `ink`.
- **App marks** (b27 `window-app-marks`): Wayfare's tab shows the slate tile with its diamond, distinct from Huddle's outlined Open App tile.
- **Picker** (b27 `picker-search-talk`): "talk" lists only Hold Keys…, with the use line under it at 44 pt row height.
- **Inspector** (b27 `inspector-hold-keys-empty`): the hint sits under "Keys to hold / Click to record" as a full-width helper line, wrapping to two lines. Once "fn" is set, the hint is gone.

## Diff summary

`Mirror/MirrorPad.swift` (opacity on the text only), `Window/WindowParts.swift` (`WindowIdentity` = ink mark; the `edgyAppIcon` environment key is removed), `Picker/PickerCatalog.swift` (use line, aliases), `Inspector/ParameterEditors.swift` (`HoldKeysHint`), `Glyph/Assets/mark-edgy.pdf` (added). Tests: new `Mirror/Batch27MirrorTests.swift` and `Window/Batch27SnapshotTests.swift`; `Window/Batch21SnapshotTests.swift` (fixture icon + stub executable); `Window/Batch22SnapshotTests.swift` (`withExportedAppIcon()` is now a no-op); `Window/Batch25SnapshotTests.swift` (old assertion kept as a comment); `Inspector/{ParameterPresentationTests,Batch15SnapshotTests}.swift` (batch 26 copy). Shots: `batch-22/`, `batch-25/` re-shot; `batch-27/` new.

## Decisions I made (and why)

- **The empty-keys hint is the row's helper line** (full width under the label and recorder), not a line inside the 170 pt recorder column, where it would wrap to five lines. It's still directly under the recorder row, in the same 13 `ink2` style and spacing as every other helper.
- **The mark is drawn as `ink` masked by the PDF**, rather than a template image, so it's never system-tinted and stays one colour in both appearances, exactly the token.
- **Shots outside my glob were not re-shot.** The full test run re-renders `batch-14/15/16/21` window shots (the title bar changed). I reverted those files because the brief limits me to `batch-{22..27}`, so they still show batch 25's app-icon title bar until the chief re-runs them on main.
- "dictation" also finds the System group's Dictation action (by its own name); both are listed.

## Needs Gabriel

- The ink mark on the real window: its spacing after the real traffic lights, and the "Edgy" tooltip (G1 item 1).
- A real colourful app icon on a tab and chip (G1 item 2).

## Open questions

- None.
