---
batch: 25
tag: EDGY-POLISH
branch: worktree-edgy-polish
worktree_path: ~/Projects/edgy/.claude/worktrees/edgy-polish
completed_at: 2026-11-07
verification: after the last format pass — `swift build` ✔ · `swift test` ✔ (all runs pass, 0 failures; EdgyUI 405 tests) · `swift format lint --strict -r Sources Tests Package.swift` ✔ · denylist ✔ (empty) · token greps ✔ · `git diff --name-only main...` only owned paths
---

# Done: batch 25 (final v0.5 polish)

All shots are in `docs/design/build-shots/batch-25/`, each as `-light.png` + `-dark.png`. Test names are in `Tests/EdgyUITests/…` (b25 = `Window/Batch25SnapshotTests.swift`).

## Acceptance criteria

| # | Item | Status | Proof |
|---|---|---|---|
| 1 | `AppMark.hasIcon`: no own icon → Open App tile in `ink2` | ✔ | A bundle needs `CFBundleIconName` + `Assets.car`, or a `CFBundleIconFile` that exists in Resources. `AppMark.icon(_:)` is used by tabs, chips, add-app rows and the Open App parameter field (`AppIcon`). The fixture `IconApps` has one real-icon bundle (Wayfare, ships `AppIcon.icns`) and the rest iconless, all built in a temp dir. Test: b25 `onlyABundleWithItsOwnIconHasAMark` (real, iconless, missing path, a plist naming a missing icon). Shots: `window-app-marks`, `popover-app-marks`, `add-app-marks` (Huddle = tile, Wayfare = real icon). |
| 2.1 | Checkbox helpers: 8 pt after, indented to the label | ✔ | `ParameterEditors.swift` on/off row: the box with its label hidden, then label + helper in one column. Test: b25 `checkboxHelpersIndentToTheLabelWithSpaceAfter`. Shots: `inspector-switch-apps-keep-open-off`, `inspector-repeat-keys-open` |
| 2.2 | Split-preview divider vs label | ✔ | The previewed edge's labels fade out while the preview shows (`MirrorPad.splitPreviewHides`). Test: b25 `splitPreviewFadesTheEdgeLabels`. Shot: `window-split-hover-bottom` |
| 2.3 | Picker bottom inset/fade | ✔ | `PickerScrollEdge`: a 12 pt bottom inset (equal to the top) plus a 12 pt fade, on the action and gesture lists. Test: b25 `pickerListEndsWithAnInsetAndFade`. Shot: `window-picker-left-edge` |
| 2.4 | Read-only "Enabled" in `ink2` | ✔ | `SettingsWindowView.tabBar`. Test: b25 `readOnlyEnabledIsInk2`. Shot: `issue-broken-config` |
| 2.5 | Mini contact keeps the edge icon readable | ✔ | The touched zone's icons draw again above the contact (`MirrorPad`, `zoneIcons` only). Test: b25 `miniContactKeepsTheEdgeIcon`. Shot: `popover-last-touch` (the speaker icon is visible under the contact) |
| 2.6 | Fixtures from shipping views | ✔ | `popover-menu-hover-wash` iterates `MenuRow.visible(paused:)` (test b25 `menuRowHoverWashOnTheVisibleRows` asserts that neither config row is in the list). `strip-broken-config-wrapped` is the real `SettingsWindowView` with a long problem message (b25 `brokenConfigStripWrappedFromTheWindow`). |
| 2.7 | NOT SHOT items | ✔ | b25 `notShotItems`. Shots: `mini-two-icons-side-edge`, `picker-add-gesture-bottom-edge` (sideways slide icon) |
| 3.1 | Mini hover line: full width, short zone names, then short action names, fade last | ✔ | `MiniMirrorView.hoverLineForms` / `shortZoneName` / `shortActionNames`. The popover passes its content width (`hoverLineWidth`). Tests: b25 `miniHoverLineUsesShortZoneNames` ("Bottom: Previous Track, Next Track, Play/Pause"; "Bottom: Tracks, Play/Pause" at 150 pt; "Left", "Top-left", "Right, upper"). Batch-22's `miniHoverLineCopy` keeps its old assertion as a comment naming the ruling. Shot: `mini-hover-line` |
| 3.2 | Picker order = icon table; search keeps it | ✔ | `PickerCatalog.iconTableOrder`, keyed by action ID. `ActionCatalog` is untouched. Test: b25 `pickerOrderIsTheIconTable`. Shot: `picker-icon-table-order` |
| 3.3 | SplitPlan: first part keeps the bindings, the others start empty; fewer parts drops the rest; note before the click; one undo | ✔ | `SplitPlan.remap` / `firstSegment`; `SplitNaming.noteName` ("Upper third"). Tests: `InspectorTests.splittingKeepsTheEdgeOnTheFirstPartAsOneUndoStep`, `remapKeepsOnlyTheFirstPart`; `SplitControlTests.noteSaysWhatSplitPlanDoes` (BRIEF's example word for word, plus the dropped clause), `noteComesFromTheOpenProfile`, `splitIsOneUndoStep`; b25 `splitNoteBeforeTheClick`. Old assertions are kept as comments naming critique 22 answer 3. Shots: `window-split-hover-bottom`, `window-split-hover-right-thirds` |
| 4.1 | Struck contact clear of the Volume tab | ✔ | Re-staged on the lower bar, clear of the tab by about 35 pt. Shot: `step2-rejected` |
| 4.2 | Plate centred under the mirror | ✔ | `OnboardingView.tryIt`: a centred zero-width slot. Shot: `step2-rejected` (the plate's centre is on the mirror's) |
| 5 | Overlay copy: past tense + object; plain triggers bare | ✔ | Already on main (`PlateContent.runTitle`). Locked by `Overlay/Batch25OverlayTests.parameterRunsArePastTenseWithTheirObject`: "Opened Quillpad", "Pressed ⇧⌘ 4", "Ran Morning lights", "Play/Pause". Shot: `plate-component`, every plate over a white and a black document half (`componentOverLightAndDarkDocuments`) |
| 6 | Onboarding step 2 counts by `decisionSerial` | ✔ | The baseline is the serial, and new decisions are the last `min(serial − baseline, recent.count)`. The observer watches `decisionSerial`. `newDecisions(seen:current:)` and its test are removed. Tests: `OnboardingTests.newDecisionsCountBySerial`, `newDecisionsBySerialAcrossTheWrappedCap`, `identicalSlidesAfterTheBaselineCount`; the existing `slidesBeforeTryItOpensDoNotCount` and `theBaselineSurvivesTheCappedFeed` still pass. |
| 7 | Chief follow-up 1: merge `main` (f1a6f01); the title bar shows the app icon only (BRIEF § Window identity (a), the owner's ruling) | ✔ | `WindowIdentity`: the V3 icon at `Tokens.titleIconSize` (26). It starts `Tokens.titleIconLeading` (12) after the last traffic light (`WindowMetrics.titleBarLeading = trafficLightsTrailing 72 + 12`) and shares the tab pill's centre line in the title-bar row. A `titleIconOutline` 0.5 pt continuous outline follows the icon tile (system icon grid), light only (the token is clear in dark). Tooltip and accessibility label "Edgy"; not a button, no hover wash; no wordmark. Snapshots inject the exported V3 `icon_32x32@2x.png` (64 px, the small drawing). Test: b25 `titleBarIsTheAppIconOnly`. Shots: `batch-25/title-bar-zoom` (2× zoom: outline in light, none in dark, icon centred with the pill) and `batch-25/window-identity`. Every window shot that shows the title bar was re-shot by the full run (batches 14, 16, 21, 22, 25). |
| 8 | Chief follow-up 2: after a split or a merge, the selection goes to the first part | ✔ | `SplitPlan.selection(after:segments:)` returns `firstSegment`. Test: b25 `splitSelectsTheFirstPart` (whole → thirds selects the upper third, which holds the rows; 3 → 2 → 1 stays on the first part; bottom edge → left; corners unchanged). The existing selection assertions in `InspectorTests` still hold unchanged. |

## Bones checklist (BRIEF § Bones)

- [x] 1 The mirror is the pad: `step2-rejected` (the mirror doesn't move when the plate appears)
- [x] 2 Zone states by shape: `window-app-marks`, `mini-two-icons-side-edge`
- [x] 3 Labels joined to their zone; no cut by a divider: `window-split-hover-bottom`; short forms in the hover line: `mini-hover-line`
- [x] 4 Recognized vs rejected by shape: `step2-rejected`, `popover-last-touch`
- [x] 5 You map on the pad: `window-picker-left-edge`
- [x] 6 The inspector: `inspector-switch-apps-keep-open-off`, `window-split-hover-right-thirds`
- [x] 7 Notes named with their fix: split note, `window-split-hover-bottom`
- [x] 8 Each status said once: `issue-broken-config` (Enabled in `ink2`, no second status)
- [x] 9 The overlay: one dark plate over light and dark documents: `plate-component`
- [x] 10 The popover: `popover-last-touch`, `popover-app-marks`, `popover-menu-hover-wash`

## Reader-first review

- **Onboarding step 2** (`step2-rejected`): the plate is centred on the mirror and the struck contact sits clear of the Volume tab. Matches answer 2.
- **Window** (`window-app-marks`, `window-split-hover-bottom`): Huddle's tab shows the Open App tile. Wayfare shows its own icon, desaturated; the stand-in is Edgy's cream icon, so it reads pale at 14 pt. A real app icon is a G1 check. The previewed bottom edge drops its label, so the divider is clean, and the note reads "Left half keeps Previous Track, Next Track and Play/Pause; right half starts empty."
- **Popover** (`popover-last-touch`, dark): the speaker icon reads under the accent contact. The chips match the tabs.

## Diff summary

`Window/WindowParts.swift` (AppMark), `Window/SettingsWindowView.swift` (Enabled), `Inspector/{ParameterEditors,InspectorModel,SplitControl}.swift`, `Picker/{PickerCatalog,ActionPickerView}.swift`, `Mirror/{MirrorPad,MiniMirrorView}.swift`, `Popover/MenuPopoverView.swift` (hover-line width), `Onboarding/{OnboardingState,OnboardingView}.swift`; tests in the matching folders; shots in `batch-25/`.

## Decisions I made (and why)

- The split note names halves and thirds by the zone's words ("Upper third", BRIEF's example) and quarters by heading ("Part 2"). The inspector headings stay "Top third".
- Selection after a split: resolved by the chief (item 8). It now goes to the first part.
- Traffic-light end is taken as 72 pt (the unified title bar's standard buttons), so the icon starts at 84 pt, where the old identity started. This needs confirming on the device.
- The "generic icon" test is an Info.plist + Resources check, not a pixel comparison with the system's generic icon: it's deterministic and needs no rendering.
- The split preview hides the previewed edge's labels entirely (opacity 0, 120 ms) rather than half-fading them, so the 50% divider never crosses text.

## Needs Gabriel

- A real app's icon at 14 pt on tabs and chips, and an iconless app installed on the device (G1).
- The hover line's width in the real popover.
- The title-bar icon: 12 pt after the real traffic lights, and the light outline against real glass.

## Open questions

- None.
