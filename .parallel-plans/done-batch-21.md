---
batch: 21
tag: EDGY-POLISH
branch: worktree-edgy-polish
worktree_path: ~/Projects/edgy/.claude/worktrees/edgy-polish
completed_at: 2026-11-07
verification: swift build ✔ · swift test ✔ (all runs pass; EdgyUITests 226 tests in 19 suites, up from 182) · swift format lint --strict ✔ · token greps empty · denylist empty
---

# Done — batch 21: the settings window, mirror, inspector, picker and popover polished to the four design critiques

Shots: `docs/design/build-shots/batch-21/` (new, integrated), plus re-shot `batch-14/`, `batch-15/`, `batch-16/` and `batch-17/` (every snapshot test reran). B21 = batch-21 shot. Names omit `-light/-dark`; every shot exists in both.

## Acceptance criteria
- [x] Every must-fix and should-fix in critiques 14–17 is ticked below with its shot or the overriding rule.
- [x] Batch 14/15/16/17 shots re-shot; `batch-21/` has the integrated window in each state: `window-default`, `window-picker-bottom`, `tab-wayfare`, `tab-huddle-off`, `state-paused`, `state-no-trackpad`, `state-disabled`, `issue-broken-config` and `advanced`, plus `window-live-right`, `inspector-long-labels`, add-app, presets, popover shots and `pad-pointer-touch-hidden`.
- [x] Existing tests keep their intent. Changed expectations, all copy rulings:
  - Play/Pause follows the catalog (ruling 6).
  - The corner label's full name is "Microphone Mute"; the pad still draws "Mic off" by rule (b), now asserted on the fitted label.
  - Overlap copy drops "The" (15 should-fix 8).
  - Curly apostrophes and quotes.
  - "Keyboard Brightness" has no "…" (batch-20 item).
  - The popover list drops the config rows (chief live-window item 2).
- [x] New tests:
  - One open binding: `Batch21InspectorTests`, six tests.
  - Label shortening: `shorterForms…`, `fitPicks…` and `aQuarterBarClips…`.
  - Tab and tile geometry: `cornerTabStartsInsideTheTile…` (it caught a real right-corner bug), `tabUnionIsOneOutline…`, `sideTabsAndCorners…` and `presetCornerRadiusIsCapped…`.
  - State fades: `miniMirrorLeavesTheFadeToItsHost`, `popoverFadesOnce…` and `windowStatesFade…`.
  - Also `configProblemWraps…`, `pickerEllipsisOnly…`, `longPressGetsPressTime…`, `onOffIsACheckbox…` and `unavailableActionMarks…`.
- [x] Token greps clean. The verification triple and the denylist are clean, run in the transcript.
- [x] Reader-first review against A and B is below.

## Fix list

### Critique 14 (mirror)
| # | Item | Done | Shot |
|---|---|---|---|
| M1 | Slab shadow upside down / dark halo | The `.shadow` and the `ink` shadow (light in dark mode, which was the halo) are gone. Depth is now a few downward-offset, narrower layers of neutral black at low opacity, drawn as shapes so the host can't flip them. The lip in `line` (lighter in dark) is gone too. | every `pad-*`; B21 `window-default` |
| M2 | Corner tabs float | Tile and tab are drawn as **one union shape** (`TabUnion`, `CGPath.union`). The tab starts inside the tile's x span, overlaps its edge by 2 pt and clears the side bar. | B21 `window-default`; `pad-wayfare` |
| M3 | Live tab keeps idle fill | The tab is part of the zone's union, so it takes the lit fill, and the accent stroke traces bar plus tab as one outline. The selection ring traces it too (`TabUnionRing`). | B21 `window-live-right`; `pad-live-slide-right` |
| M4 | Params under every binding | One open binding (see 15 M1) | B21 `window-picker-bottom` |
| S1 | Per-layer fade | `.compositingGroup()` before the 0.4 | `pad-disabled`, `pad-huddle-off` |
| S2 | 33 pt picker rows / 1.5 pt to top bar | 24 pt rows; 8 pt clearance from other zones in `PickerPlacement` | B21 `window-picker-bottom` |
| S3 | Name spellings | The UI uses catalog names verbatim. The catalog fix is a blocker (it lives in Actions). | all |
| S4 | Truncated tab "…" | Rule (a) short value → (b) short name → clip with a 12 pt fade. A cut never adds "…". | `pad-split-bottom4-long-label` |
| S5 | Preset corners as dots, shoot Windows | Corner radius capped at 30% of the tile | B21 `preset-windows`, `preset-minimal` |
| S6 | Mini at real size, mini-disabled | Shot inside the popover at its 1.8 pt/mm width | B21 `popover-normal`, `popover-disabled` |
| S7 | "Previous Track"/"Sensitivity" wraps, 57 pt inset | 22 pt inspector inset; one label column per binding, one line; values right-aligned | B21 `window-picker-bottom`, `window-default` |
| Q1 | "Off here" as a hairline tab | Union outline in `line`, no fill, `ink2` text | `pad-wayfare` |
| Q4 | Pending Tap row | `PendingRowView`: blank value while the picker is open on a new gesture | B21 `window-picker-bottom` |

### Critique 15 (inspector, picker)
| # | Item | Done | Shot |
|---|---|---|---|
| M1 | One open binding | `openBinding(in:rows:)`: nothing while picking; else the clicked or just-chosen row; else the first with an empty required parameter. Inherited and turned-off rows never open. | `inspector-bottom-edge-*`, `inspector-corner-needs-keys`, `inspector-wayfare-sources` |
| M2 | Path editor | The field takes the remaining width with middle truncation; **Choose…** is a bordered `.fixedSize()` button | `param-path` |
| M3 | Do nothing here not shown | App-tab picker shot with an empty search and the full list: disclosure, separator, "Do nothing here" | `picker-app-tab-do-nothing` |
| S1 | Keep-open helper | Helper always shown, from the catalog | B21 `inspector-long-labels` |
| S2 | Hold Keys timing | "Hold before it starts" row; "Let go after" moved last, with the spec's label and helper; default in `ink2` | `inspector-corner-needs-keys` |
| S3 | Spaced slashes | Catalog blocker (UI follows catalog) | — |
| S4 | Title-case labels | `sentenceCase` ("Shortcut name", "File or folder") | `param-shortcut`, `param-path` |
| S5 | Label sits low in two-line rows | Custom `.parameterRow` alignment: the label lines up with the field; the message hangs below | `param-url-error`, `param-recorder-error` |
| S6 | Recorder error demo | Field shows "⌘" alone | `param-recorder-error` |
| S7 | Chevron while searching | Driven by `othersExpanded` (open or a search typed) | `picker-searched` |
| S8 | Extra "The" | "Whole edge and upper half both use Slide." | `inspector-overlap-warning` |
| S9 | App list empty row | Plain `VStack` keyed per section; headers 13 semibold `ink2` (Q3) | `param-app-list` |
| S10 | Slider tracks misaligned | One label column per binding plus a fixed 56 pt value column | `param-presentation-fields` |
| Q1 | Split on app tabs | **Hidden** on app tabs (chief ruling) | `tab-wayfare` |
| Q2 | Release after | "Let go after", helper line, last before haptics | `inspector-corner-needs-keys` |

### Critique 16 (window)
| # | Item | Done | Shot |
|---|---|---|---|
| M1 | Paused / app-off swap the mirror | The mirror stays mounted. The window fades it to 40% for Paused; the mirror fades itself for app-off (all hairlines). The line sits centred on top, unfaded. | B21 `state-paused`, `tab-huddle-off` |
| M2 | No trackpad shows nothing | Dashed outline with "Connect a trackpad to see it here."; zones from `lastKnownPadSizeMM` | B21 `state-no-trackpad` |
| M3 | Disabled doesn't fade | The mirror fades to 40%; editing still works | B21 `state-disabled` |
| M4 | App marks missing | 16 pt monochrome marks on tabs (Huddle keeps the trailing slashed circle); add-app rows and step 2 use the real icon | B21 `window-default`, `add-app-step1/2` |
| M5 | Overlap banner placement | Under "Split into", warning icon, `ink2`, **Show** | `issue-overlapping-zones` |
| M6 | Reload in window strip | Removed. The strip has **Open config file** and **Replace with current settings…** | B21 `issue-broken-config` |
| M7 | Picker missing in shot | The picker is hosted and anchored | B21 `window-picker-bottom`; `batch-16/window-picker` |
| S1 | Read-only incomplete | Tab bar, Enabled, "+", columns and footer are all `.disabled` while the file is broken (Launch at login too, per Q3) | B21 `issue-broken-config` |
| S2 | Straight apostrophes | ’ in every shipped string (doesn’t, what’s, can’t, That’s, Don’t) and ‘ ’ around parser tokens | `legacy-note`, `add-app-step2` |
| S3 | Step-2 icon | Real 16 pt icon before the name | B21 `add-app-step2` |
| S4 | Footer order | **Dropped by ruling** (native label then switch) | — |
| S5 | Plate behind lines | Removed; the faded pad gives the contrast | B21 `state-paused` |
| Q2 | Advanced defaults | `ink2` at default, `ink` changed | B21 `advanced` |

### Critique 17 (popover, glyph)
| # | Item | Done | Shot |
|---|---|---|---|
| M1 | Mini ignores live profile | The mini mirror and chips read one source, `model.frontmostBundleID` (falling back to the state's). The view's own `NSWorkspace` observer is removed, and the view reads `model.revision`. | B21 `popover-app-chip-live` |
| M2 | Last touch | Shot added | B21 `popover-last-touch` |
| M3 | actionUnavailable in mini | `unavailableAsUnmapped` draws the zone as a hairline. The full mirror marks its tab `ink2` with a slashed circle instead. | B21 `popover-unavailable-unmapped` |
| S1 | Width | Chief set 1.8 pt/mm | B21 `popover-normal` |
| S2 | Line named twice | `ConfigProblem.sentence` folds "around line N, column M" into the lead | B21 `popover-no-access-broken-config` |
| S3 | Straight quotes | "Don’t run actions"; ‘x’ | `popover-test-mode` |
| S4 | Chip marks | Fixture apps with real bundle paths | B21 `popover-*` |
| S5 | Semibold switch labels | Regular 13 `ink` | B21 `popover-normal` |
| S6 | Combination shots | Paused + Test Mode (glyph asserted `.paused`), No Accessibility + broken config (broken wins, asserted) | B21 `popover-paused-test-mode`, `popover-no-access-broken-config` |
| Q2 | Switches under blocks | Enabled and Test Mode stay under both blocks | B21 `popover-no-access-broken-config` |
| Q3 | Paused fade 40% | Paused is in `PopoverMirror.faded` | — |

### Brief items 4–7 and the chief's live-window items
- **Pad labels per bone 3:** never "…" for a cut; short value → short name → 12 pt fade. Done.
- **Batch 17:**
  - One fade: the popover keeps its 0.4 and the mini mirror's `fadedByHost()` adds none.
  - `ConfigProblem` is a thin wrapper over `EdgyRuntime.ConfigProblem` plus the file name. `init(fileName:line:message:)` stays, so EdgyApp is untouched.
- **Batch 20:**
  - "…" only for a **required** parameter.
  - `.choice(["on","off"])` draws as a checkbox with its helper line.
  - "Press time" (`ConfigValidator.pressTimeParameter`) shows on long-presses whose action has no `holdMS`.
  - The picker test is back to "Keyboard Brightness".
- **Catalog `displayName` everywhere:** done (the re-spelling map is removed).
- **Chief live-window items:**
  1. Labels never break mid-word: one line, and when label plus control don't fit, the label moves above the control (`ViewThatFits`) (B21 `inspector-long-labels`).
  2. Popover list is Pause, Settings…, About, Quit. "Open config file" stays only in the broken-config block (no Reload) and the window strip.
  3. The popover reflects live settings (`model.frontmostBundleID`, `model.revision`).
  4. Only touches inside a mapped zone are drawn (`MirrorPad.drawnTouches`; B21 `pad-pointer-touch-hidden`).

## Bones checklist
1. **Mirror is the pad:**
   - [x] to scale, no rulers (B21 `window-default`)
2. **Zone shapes:**
   - [x] bars, hairlines, tiles with icons, dashed pass-through
   - [x] selection ring vs live border distinct (B21 `window-default`, `window-live-right`)
3. **Labels joined:**
   - [x] side and corner tabs are one shape with their zone
   - [x] top and bottom labels in the bar
   - [x] never "…" for a cut
   - [x] "Off here" is a hairline tab
   - [x] catalog names (`pad-wayfare`, `pad-split-bottom4-long-label`)
4. **Recognized vs rejected:**
   - [x] filled contact vs struck circle
   - [x] pointer touches outside zones not drawn (`pad-rejected-touch`, B21 `pad-pointer-touch-hidden`)
5. **Map on the pad:**
   - [x] anchored single-column picker with an arrow, clear of other bars (B21 `window-picker-bottom`)
6. **Inspector:**
   - [x] name 26, Split 1–4 (Default only)
   - [x] mapped gestures only, Add gesture…
   - [x] blank value while picking, one open binding (B21 `window-picker-bottom`)
7. **Interaction notes:**
   - [x] info icon, `ink2`, inline fix (`inspector-bottom-edge-note`)
8. **Each status once:**
   - [x] Paused line on the pad only; one fade per surface (B21 `state-paused`, `popover-disabled`)
9. **Overlay:** n/a for this batch.
10. **Popover:**
    - [x] live mini mirror and last touch
    - [x] chips with marks
    - [x] switches
    - [x] list Pause / Settings… / About / Quit (B21 `popover-*`)
- **Kill list:** no second hue, micro-caps, middots, rotated text or halos.

## Reader-first review (B21 against renders A and B)
- **Window vs A** (`window-default`):
  - Matches: tabs top centre with marks, Enabled top right, mirror left and inspector right, footer.
  - Corner tabs: "Mic off" and "Mute" hang flush under their tiles, as in A.
  - Depth: the slab's lower edge is soft and below the slab; there's no glow in dark.
  - Inspector: the left inset is now ≈22 pt like A. The slide row is open with Faster when you flick (checkbox), Sensitivity and Haptics. A shows only Sensitivity, because the catalog grew since.
  - Differences: the mirror is taller than A because it's to scale (BRIEF wins), and "Play / Pause" carries the catalog's spaces (blocker 1).
- **Picker vs B** (`window-picker-bottom`):
  - Matches: anchored to the bottom bar with the arrow on the ringed bar, and a pending "Tap" row with a blank value.
  - Differences:
    - B is two columns; the build is one, per bone 5.
    - Rows are 24 pt.
    - The panel clears the top bar by 8 pt and the side bars.
    - The corner tabs ("Mic off", "Mute") sit beside the panel, not under it.
- **States:**
  - Paused, Huddle off and Disabled are faded and mounted, with the line on top and no plate.
  - No trackpad is the dashed outline with the exact copy.
  - Broken config is the one-line strip with two buttons, and the window is read-only.
- **Long labels** (`inspector-long-labels`): Switch Apps' labels each take their own line above the control. There are no mid-word breaks, and every slider track ends at the same x.

## Diff summary
- **Mirror:**
  - `MirrorPad.swift`: union tabs, ring, manual shadow, fitting, touch filter, corner radius cap.
  - `MirrorContent.swift`: label forms, unavailable, catalog names.
  - `MiniMirrorView.swift`: host fade, model frontmost, revision.
  - `SettingsModel+Mirror.swift`.
- **Inspector:**
  - one open binding and pending row (`InspectorModel`, `InspectorView`)
  - names, labels and copy (`InspectorText`)
  - parameter rows: alignment, column, checkbox, press time, path button, app list (`ParameterEditors`)
- **Picker:** chevron, 24 pt rows, 8 pt clearance.
- **Window:**
  - strip without Reload, padline without plate, inspector inset and width (360)
  - `init(model:apps:)`
  - Advanced default colours
  - add-app real icons
  - `ConfigProblem` wrapper
  - apostrophes
- **Popover:**
  - frontmost source, one fade (paused included), switches under blocks
  - regular labels, list without config rows, recovery block without Reload
- **Tests:**
  - `Batch21MirrorTests`, `Batch21InspectorTests`, `Batch21SnapshotTests`
  - updated expectations listed above
  - Batch-15 fixture fixes (recorder "⌘", Do nothing full list)

## Decisions I made (and why)
- **Tabs as a union path in the label layer.** The zone layer draws a clear placeholder for tabbed zones (anchors and hits unchanged). Separate shapes can't avoid a seam or doubled translucency where they overlap.
- **Shadow in neutral black.** Every token is lighter than the dark window material, which is what caused the halo. See blocker 2.
- **Corner tab cap 26 mm, side tab 40 mm.** A long corner name falls back to its short name per rule (b). That gives render A's "Mic off" while the full name stays in the inspector.
- **Nothing is open while the picker is open on that zone.** A new gesture has no row, and the open binding follows the choice.
- **`MenuRow.openConfigFile/.reloadConfig` cases kept** (just not listed), so EdgyApp's code still compiles.
- **Fixture app icons:** empty `.app` folders in the temp directory, which get the generic system app icon. No real product's icon is shown.

## Needs Gabriel
- Slab depth (layer opacity) and the joined tabs at real size, light and dark.
- App marks with real installed apps (the shots show the generic icon desaturated).
- The popover following the frontmost app live, and the mini redrawing after edits in Settings.
- The touch filter on hardware: no drifting dot mid-pad.

## Open questions
- Catalog spellings (blocker 1): once fixed, the UI follows with no change.
- Should Sensitivity stay in a binding's shared label column when a long label pushes the whole column above its controls (Switch Apps)? Today all rows of that binding stack, which keeps the tracks aligned.
