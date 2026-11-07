---
batch: 22
tag: EDGY-ICONS
branch: worktree-edgy-icons
worktree_path: ~/Projects/edgy/.claude/worktrees/edgy-icons
completed_at: 2026-11-07
verification: swift build ✔ · swift test ✔ (all suites, 0 failures, after `swift package clean`) · swift format lint --strict ✔ · swift build -c release: no warnings in Inspector/Picker/Icons/Window/Mirror/Popover · denylist ✔ (empty) · token greps ✔ (empty)
---

# Done: batch 22 (icons, picker clarity, split control, window identity, critique 21)

## Acceptance criteria

| Item | Status | Proof |
|---|---|---|
| A1 Action icons transcribed, not drawn | ✔ | `Sources/EdgyUI/Icons/IconData.swift` copies each SVG's elements verbatim (path `d` strings as-is, rect/circle attributes as numbers); `IconDrawing.swift` interprets them (M L H V A C Q Z, arcs → cubics). `ActionIcon(id:size:)`, `ActionIcons.has(_:)`, `AdvancedIcon`. |
| A1 test: every catalog action has an icon | ✔ | `IconTranscriptionTests.everyCatalogActionHasAnIcon` (`makeLiveActionRegistry(settings: .defaults).available`) |
| A1 test: bounds vs SVG viewBox | ✔ | `transcribedBoundsSitInsideTheirViewBox`. Also `transcribedElementsMatchTheirSVGExactly` re-parses every SVG with `XMLParser` and compares element by element, and `actionMapMatchesTheREADMETable`. |
| A2 `EdgySplitGlyph(edge:parts:selected:)` | ✔ | From the exported `split-*` SVGs; 40×12 / 12×40; selected `ink` fill, unselected `line` hairline. Shot `batch-22/split-glyphs` |
| A3 icon sheet + split glyphs | ✔ | `batch-22/icon-sheet`, `batch-22/split-glyphs` |
| B4 picker rows | ✔ | 16 pt icon in a 24 pt column, 13 name, trailing `ink` checkmark on the bound action, 28/44 pt rows, sub-line aligned to the name. Headers 11 semibold `ink2`, 14 above / 4 below, first none, no separators. Highlight and hover share the 10% `ink` wash; bound ≠ highlighted. Shots `picker-slide-bound-checkmark`, `picker-catalog-scale`, `picker-searched`, `picker-empty-search` ("No actions match “xyz”."), `picker-searched-disclosure`, `picker-app-tab-do-nothing` |
| B4 tests | ✔ | `PickerClarityTests` (empty-state copy, search keeps only matching headers, rhythm, interior height cap, side-edge clamp) plus the existing `PickerCatalogTests` |
| B5 Split control | ✔ | `Inspector/SplitControl.swift`: "Split" + four diagrams; hover publishes `SplitPreview` (per-model side table, like `InspectorDrafts`), and `MirrorPad` draws `ink` 50% divider hairlines; accessibility names "Whole edge / 2 parts / 3 parts / 4 parts"; hidden on corners and app tabs; one undo step (`splitIsOneUndoStep`); the info note shows on hover, before the click. Shots `split-control`, `window-split-hover`, `window-split-hover-bottom`, `window-split-grouped` |
| B5 grouped bindings | ✔ | A split edge titles as "Right edge" and lists each segment under a 13 semibold `ink2` heading in reading order (Upper/Lower half, Top/Middle/Bottom third, Left/Right half, Part 1–4), each with its own rows and "Add gesture…" |
| B6 Window identity + Advanced | ✔ | `WindowIdentity` (18 pt app icon + "Edgy" 13 semibold `ink`, 8 pt apart, after the traffic lights). The app uses `NSApp.applicationIconImage` (the bundled `AppIcon.icns`, never redrawn); shots inject the exported `icon_16x16@2x.png`. `AdvancedButton`: sliders icon + "Advanced…" in `ink2`, no bezel, hover = `ink` + 10% wash. Shots `window-identity`, `advanced-button` |
| B7 render notes | ✔ | Catalog spellings come from the catalog ("Play/Pause", "Keyboard Backlight On/Off"); the picker scrolls to the bound row on open; side-edge picker centred on the anchor and clamped clear of corner tiles **and their tabs**, and of its own tab (`window-picker-left-edge`); height capped at the pad interior (the mirror publishes `pickerInterior()` and `pickerTab(for:)`) |
| B8 critique 21 | ✔ | Table below |
| Chief adds (cross-session) | ✔ | Sensitivity hidden where `stepMM` shows; batch-20 shots; Sendable-safe bindings; bone-10 mini mirror icons + hover line |

## Critique 21: every OPEN, PARTIAL and new item

| # | Status now | Shot / proof |
|---|---|---|
| New must-fix 1: inspector cuts the action name | FIXED | `batch-21/tab-wayfare`: "• Keyboard Shortcut" whole; **Revert** moved to the "Default: Previous Track" sub-line. `BindingRowView` uses `ViewThatFits`: inline when it fits, else the caption/Revert drop to the sub-line and the name wraps at word boundaries (max 2 lines). Inspector rows use the catalog name; the "…" stays a picker-only mark. |
| New must-fix 2 / 17 M2: mini draws no last touch | FIXED | `batch-21/popover-last-touch`: a right-edge contact. The root cause was in the fixture: no device was attached, so the mini drew nothing. The mini also now remembers the last frame **with a zone touch**, so a lifted pointer touch never lingers. |
| 17 M3: unavailable in the mini | FIXED | `batch-21/popover-unavailable-unmapped`: the right edge's only binding is unavailable and it draws as a hairline (asserted in the test). Also `batch-22/mini-unavailable-zone` |
| New must-fix 3: mixed builds | FIXED | Batches 14–17, 21 and 22 were re-shot by one `swift test` after `swift package clean` (commit `d08227e`); "Play/Pause" everywhere |
| 14 M2: corner tabs pinch | FIXED | The tab tucks under the tile by the control radius (`labelPlacement`, test updated to the new rule). `batch-21/window-default` |
| 14 S3 / 15 S3: spelling | FIXED | One build; catalog names only |
| 16 M4 / 17 S4: app marks | FIXED (Needs Gabriel for real icons) | `AppMark`: the real icon at 14 pt, desaturated, 70% in dark; with no icon, the "Open App" tile icon in `ink2`. Used on tabs, add-app rows and chips. Shots show the generic icon of the invented test apps. |
| 16 S1: read-only incomplete | FIXED | `batch-21/issue-broken-config`: footer labels and tab labels go to `ink2` with the controls disabled |
| Should-fix 1: whole label column stacks | n/a | Ruled correct (design answer 2) |
| Should-fix 2: helper crowding | FIXED | 8 pt after each helper line. `batch-21/inspector-long-labels` |
| Should-fix 3: Huddle chip drops mark | FIXED | `batch-21/popover-normal`: [mark] Huddle ⊘, like the tab |
| Should-fix 4: strip buttons centred on two lines | NOT DONE | Ran out of turns; `WindowParts.WindowStripView` needs `alignment: .firstTextBaseline`/top on its HStack |
| Should-fix 5: pointer-touch-hidden idle | FIXED | `batch-21/pad-pointer-touch-hidden`: one frame with a mid-pad pointer touch (not drawn) and a right-edge claim (drawn) |
| Design answer 4: selection opens nothing | FIXED | `batch-21/window-default` re-shot collapsed; the test asserts `openBinding == nil` |
| 14 S4 long label (a)(b)(c) | SHOT | `batch-14/pad-split-bottom4-long-label` (re-shot) |
| 15 M2 path editor | SHOT | `batch-15/param-path` |
| 15 M3 Do nothing here | SHOT | `batch-22/picker-app-tab-do-nothing`, `batch-15/picker-app-tab-do-nothing` |
| 15 S2 Hold Keys timing | SHOT | `batch-22/inspector-hold-keys-open` |
| 15 S4 / S5 / S8 labels | SHOT | `batch-15/param-presentation-fields`, `batch-21/inspector-long-labels` |
| 15 S6 recorder error | SHOT | `batch-15/param-recorder-error` |
| 15 S7 chevron while searching | SHOT | `batch-22/picker-searched-disclosure` |
| 16 M5 overlap line | SHOT | `batch-16/issue-overlapping-zones`, `batch-15/inspector-overlap-warning` |
| 17 A1 hover wash | PARTIAL | `batch-22/advanced-button` shows the same 10% `ink` wash; no forced-hover shot of a popover menu row |
| G1 shots | SHOT | No Accessibility popover `batch-17/popover-no-accessibility`; No trackpad `batch-17/popover-no-trackpad`; faded mini with Huddle `batch-14/mini-huddle-off`; window strip `batch-16/state-no-accessibility`; live border on an unselected zone `batch-21/popover-last-touch` and `batch-21/pad-pointer-touch-hidden` |

## Batch-20 shots (chief)

`batch-22/inspector-hold-keys-open` (300 ms, "Let go after" 120 s), `inspector-press-time-default` ("Default (500 ms)"), `inspector-press-time-changed` (800 ms with Reset), `inspector-switch-apps-keep-open-off` ("Off", plus a changed slider in `ink`), `inspector-repeat-keys-open`, `inspector-slide-and-swipes-note`.

## Bone-10 mini mirror (chief, BRIEF on main)

10 pt `ink` icons on every mapped zone, up to two per bar in gesture order; corner icons at 10 pt; split edges per segment; unavailable = unmapped with no icon; hover line "Bottom edge: Previous Track, Next Track, Play/Pause" (13 `ink2`, reserved height, 12 pt fade inside the mirror width). The window mirror is unchanged. Shots `batch-22/mini-icons-every-zone`, `mini-two-icons`, `mini-split-edge`, `mini-unavailable-zone`, `mini-hover-line`. Test `miniHoverLineCopy`.

## Bones checklist

1. Mirror is the pad — ✔ unchanged geometry (`window-default`)
2. Zone states by shape — ✔ the corner tile now carries its **action icon** (it was an SF Symbol before) (`window-default`, `mini-icons-every-zone`)
3. Labels joined — ✔ corner tabs tuck under the tile (`window-default`); the inspector never cuts a name (`tab-wayfare`)
4. Recognized vs rejected — n/a (unchanged)
5. Map on the pad — ✔ the picker clears its trigger, its own tab, the corner tiles and their tabs, and is capped at the interior (`window-picker-left-edge`, `window-picker-bottom`)
6. Inspector — ✔ the Split control and per-segment headings (`window-split-hover`, `window-split-grouped`)
7. Interaction notes — ✔ the split note uses the info icon in `ink2` (`window-split-hover`)
8. Said once — ✔ no idle hover line; the Huddle off mark is shown once per chip/tab
9. Overlay — n/a
10. Popover — ✔ last touch, icons, hover line (`popover-last-touch`, `mini-hover-line`)

Kill list: no stock glyphs for actions (the SF Symbol corner table is removed), no second hue, no middots, no emoji.

## Reader-first review

- **S9 (picker):** matches: header, search, icon column, the bound checkmark, unavailable rows with their sub-line, group rhythm. Differs: no top divider under the search field (BRIEF: no separator lines). The scrollbar is the system's.
- **S12 (split):** matches: the "Split" label, four diagrams on a quiet track with the selected tile raised, the hover tile wash, the mirror dividers and the info note under the row. Differs: **the note copy follows SplitPlan, not the render.** The render says "Top third keeps Volume; the other two start empty", but `SplitPlan` copies on split, so the build says "All three thirds keep Volume." (BRIEF: "as the runtime's SplitPlan does today"). The render's second "Bottom edge / Split" block is a sample of the horizontal glyph, not built.
- **A:** the title bar gains the icon and wordmark (BRIEF § Window identity wins over the render). The Advanced button is quiet text, and the corner tabs now tuck.
- **B:** single column, 28 pt rows with icons, about 9 pt clear of the bars.
- **E:** the mini now shows the last touch on the right edge (as E does) and edge icons (bone 10, newer than E).

## Diff summary

New: `Sources/EdgyUI/Icons/{IconData,IconDrawing,ActionIcon}.swift`, `Sources/EdgyUI/Inspector/SplitControl.swift`, `Tests/EdgyUITests/Icons/*`, `Tests/EdgyUITests/Inspector/SplitControlTests.swift`, `Tests/EdgyUITests/Window/Batch22SnapshotTests.swift`. Changed: Picker (rows, rhythm, empty state, placement, anchors), Inspector (row layout, grouping, params), Mirror (icons, dividers, interior and tab anchors, tab tuck, mini hover and last touch), Window (identity, Advanced, marks, read-only), Popover (chip mark). Re-shot batches 14–17, 21 and 22. Batch-18 and batch-19 shots rewritten by the test run were restored (outside my glob).

## Decisions I made (and why)

- **Transcription method:** the SVG data is copied verbatim and interpreted at runtime, not generated into hand-shaped `Path` calls or PDFs. The test can then diff the Swift table against every SVG exactly, so "never redraw" is enforced by CI. (The one-off generator was a scratch script; regenerating is a copy of the SVG attributes, and the test fails on any drift.)
- **Split note on hover:** BRIEF says "before the click takes effect" and S12 draws it under a hovered segment.
- **Horizontal thirds** are named "Left/Middle/Right third" (BRIEF names only the vertical thirds).
- **Hover state** lives in a per-model side table (`SplitPreview`), because `SettingsModel` is frozen. It's the same pattern as `InspectorDrafts`.
- **The picker's anchor** is the zone plus its own tab, so it never covers its trigger's label.
- **App icon in the title bar:** `NSApp.applicationIconImage` (the bundled `.icns`), injected in shots. No resource was added to EdgyUI, because Package.swift is frozen.
- **Tests updated to rulings, intent kept:** the corner-tab overlap test now asserts the tuck; `MirrorTests` expects an action id instead of an SF Symbol name; `window-default` asserts nothing is open.

## Needs Gabriel

- App marks with real app icons (desaturated, 70% in dark) on tabs, chips and add-app rows: the shots only have generic test apps.
- The 18 pt title-bar icon at real size next to the traffic lights (vertical centring on the real title bar).
- Hover behaviour (Split preview, the mini hover line, the Advanced and picker washes) with a real pointer.

## Open / remaining

1. **Slide gesture icon follows the edge orientation** (chief, arrived at turn ~108): ↔ on top/bottom, ↕ on left/right, everywhere `GestureIcon` shows, plus a top-edge slide row shot. Not started.
2. Should-fix 4: top-align the broken-config strip's buttons when the text wraps (`WindowStripView`).
3. 17 A1: a forced-hover shot of a popover menu row.
