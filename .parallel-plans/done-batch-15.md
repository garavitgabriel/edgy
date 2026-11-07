---
batch: 15
tag: EDGY-INSPECTOR
branch: worktree-edgy-inspector
worktree_path: ~/Projects/edgy/.claude/worktrees/edgy-inspector
completed_at: 2026-11-07
verification: swift build ✔ · swift test ✔ (all suites green; EdgyUITests 108 tests, 61 of them batch 15) · swift format lint --strict ✔ · token greps empty · denylist empty
---

# Done — batch 15: inspector, action picker, parameter editors

## Acceptance criteria

The shots are in `docs/design/build-shots/batch-15/`, each in light and dark.

- [x] **Inspector, right edge** (slide + sensitivity): `inspector-right-edge`
- [x] **Inspector, bottom edge** (4 gestures + the info note): `inspector-bottom-edge-note`
  - The row's value is blank while picking: `inspector-bottom-edge-picking`
- [x] **Picker open for "Tap, bottom edge"**:
  - `picker-tap-bottom-edge` shows Keyboard Backlight On / Off dimmed with "Needs a backlit keyboard".
  - `picker-tap-bottom-edge-full` shows the whole list, ending in the "6 more need a slide or long-press" disclosure, expanded.
  - Anchored with its arrow: `picker-anchored-bottom`, `picker-anchored-right`
- [x] **Picker, searched**: `picker-searched` (the search covers the disclosure too).
  - Also shot: `picker-app-tab-do-nothing` and `picker-add-gesture`.
- [x] **Wayfare inspector rows** (each source: inherited, overridden, turned off, app-only): `inspector-wayfare-sources`
- [x] **Each parameter editor state:**
  - Recorder: `param-recorder-idle-empty` ("Click to record"), `-idle` ("⌃⌥ Space"), `-recording` (accent ring, live "⌃⌥" in ink2, "Press keys…"), `-fn-result`, `-error` ("Add a key. Modifiers alone work only on Hold Keys.")
  - App: `param-app-chooser` (with "If already in front: Hide it / Stay") and `param-app-list` (Running, then All apps)
  - URL: `param-url` and `param-url-error`
  - The rest: `param-path`, `param-number`, `param-choice-segmented`, `param-choice-popup`, `param-shortcut`, `param-haptics`
  - In context: `inspector-corner-needs-keys`
  - The chief's added fields: `param-presentation-fields` (help line, unit, "Off" at 0, "Default (500 ms)", Reset)
- [x] **An issue line for each severity:**
  - `issue-lines` shows error, warning and info.
  - In context: `inspector-overlap-warning` (under the split control, with Show) and `inspector-unavailable-warning`
- [x] **≥ 20 tests: 61 batch 15 tests**, all green.
  - `Tests/EdgyUITests/Inspector/InspectorTests.swift` (28): rows are mapped gestures only; app-tab sources; Revert / Turn off; choosing writes the binding (`setBinding`), an override on app tabs, a revert when the choice equals Default, Do nothing → turnOff; drafts + "Needs keys" / "Needs an app"; validation errors under the control (URL, path, modifiers alone); haptics; the split copies parts as one undo step, merges and moves the selection; the tap note uses the real `doubleTapWindowMS` and its fix; the recorder flow on a fake (combo, ≥0.6 s modifiers on a hold, a quick tap keeps listening, the error on triggers, Esc / cancel, the live stream); key symbols.
  - `Tests/EdgyUITests/Picker/PickerTests.swift` (9): grouping in catalog order, the collapse and its wording per shape, search, unavailable / limited sub-lines, the "…" suffix, Do nothing on app tabs only, the placement side, the height cap (mirror − 16, ≤420), staying in the window.
  - `ParameterPresentationTests.swift` (6): unit, zeroLabel, fallback "Default (…)", generic info fallback, "…" menu greying, the note fix opening a row's menu.
  - `Batch15SnapshotTests.swift` (18): every shot above.
- [x] **Bones checklist and reader-first review** (below); token greps clean.
- [x] **Verification triple green; denylist clean.**

## Verification

Run in this transcript after the last code change, on the branch merged with `main` @ 4bba3d2+:

```
swift build                                            → Build complete!
swift test                                             → every suite ✔ (EdgyUITests 108 tests in 14 suites)
swift format lint --strict -r Sources Tests Package.swift → exit 0, no output
grep (colour literals, outside Tokens.swift)           → nothing
grep (.system(size:, .custom(, second hues)            → nothing in Inspector/ or Picker/
git grep -niE -f ~/.config/edgy-names-denylist         → nothing (exit 1)
```

**Note for the chief:** `swift test` re-renders batch 16's and the skeleton's shots, and these now differ because a real inspector draws inside the window. I restored them with `git checkout` every time and never committed them. Re-shoot them on `main` after the merge.

## Bones checklist

| # | Bone | Status / evidence |
|---|---|---|
| 1 | The mirror is the pad | n/a (batch 14). The placeholder mirror in my picker shots is to scale: external pad × `Tokens.mirrorPointsPerMM`. |
| 2 | Zone states by shape | n/a (batch 14). |
| 3 | Labels joined to their zone | n/a (batch 14). |
| 4 | Recognized vs rejected | n/a (overlay, stage 2). |
| 5 | Map on the pad: popover anchored with an arrow, header "Tap, bottom edge", search, grouped rows, **single column**, scrolls, dimmed actions in **one** group note, never covers its trigger or neighbours, never leaves the window | ✔ `picker-anchored-bottom`, `picker-anchored-right`, `picker-tap-bottom-edge(-full)`, `picker-searched`. Placement is pure and tested (`PickerPlacementTests`). The note names the gestures (see Decisions). |
| 6 | Inspector: zone name 26, "Split into 1 2 3 4", only mapped gestures in plain text, ends with "Add gesture…", a row click opens the same pad popover, the row value is blank while picking | ✔ `inspector-right-edge`, `inspector-bottom-edge-note`, `inspector-bottom-edge-picking`. Corners have no split (S3). |
| 7 | Interaction notes informational: "Tap waits N ms here to tell it from a double-tap.", info icon in `ink2`, one fix "Use long-press instead", no zone name | ✔ `inspector-bottom-edge-note`, `issue-lines`. N is the real `doubleTapWindowMS` (test with 450). |
| 8 | Each status said once, next to its thing | ✔ Overlap under the split; unavailable reason under its row; errors under their control; tap note once per zone. |
| 9 | Overlay | n/a (stage 2). |
| 10 | Menu-bar popover | n/a (stage 2). |
| Kill list | No eyebrows, no emoji or Unicode arrows as icons (gesture icons are drawn shapes in one family and one stroke; swipe up and down differ by dot position and head), no middot chains, no space before %, one typeface, no second hue (no system blue: plain fields with drawn borders, the slider and checkbox tinted `ink`, the recorder ring in accent because recording is live) | ✔ all shots |

## Reader-first review (my shots vs the renders)

**Inspector vs A (right edge) and `inspector-right-edge`.**
- Matches: the 26 pt semibold title, "Split into" in ink2 with a neutral segmented control, the rule, the slide glyph + "Slide" … "Volume", the indented Sensitivity slider in ink, "+ Add gesture…".
- Differs:
  - The split offers 1–4; A shows 1–3. BRIEF bone 6 and S1 say 1–4.
  - A value "100%" sits right of the slider (BRIEF § Number).
  - Every row has a haptics checkbox (BRIEF § Per-binding haptics; S3 shows it).
  - Every row has a "…" button (BRIEF § App profiles: every row has one).

**Inspector vs B (bottom edge) and `inspector-bottom-edge-note` / `-picking`.**
- Matches: gesture glyph + name left, action right; the open row is highlighted and its value is **blank**. B shows "Choosing…", but bone 6 wins.
- Differs:
  - The note is bone 7's rewrite: an info icon, "Tap waits 300 ms here to tell it from a double-tap.", and one text fix. B's warning triangle, its "fires the tap action first" copy and its two buttons are out of date.
  - Rows are in the runtime gesture order (tap, double-tap, swipes). B lists swipes first.
  - The catalog name is "Play / Pause" with spaces; B shows "Play/Pause". Copy comes from the catalog, not the render.

**App-tab rows vs S1 and `inspector-wayfare-sources`.**
- Matches:
  - Inherited: action + "from Default" in ink2.
  - Overridden: ink dot + action in ink + **Revert**, with "Default: Previous Track" under it.
  - Turned off: "Off here" in ink2 + **Revert**, with "Default: Play / Pause".
  - App-only: plain ink.
- Differs:
  - Each row has its "…" menu (S1 misses it; BRIEF wins).
  - Overridden and app-only rows show their parameter rows. Inherited and turned-off rows don't, because they are Default's.
  - The split control is disabled on an inheriting app tab (see Decisions).

**Parameter editors vs S3 and `inspector-corner-needs-keys`, `param-*`.**
- Matches: "Needs keys" in ink2 on the row; "Keys to hold" with "Click to record" / "Press keys…" in an accent ring and the held "⌃⌥" in ink2; App pop-up with icon + name; "If already in front: Hide it / Stay"; "Haptics for this gesture" checkbox; no split on a corner.
- Differs:
  - The app icon is the system icon for the path. Demo apps don't exist on disk, so the shots show the generic document icon. Real apps show their own.
  - The checkbox is neutral/ink, not S3's filled light chip.

**Picker vs S4 and `picker-anchored-right` ("Slide, right edge") / `picker-tap-bottom-edge`.**
- Matches:
  - Header semibold, search with a magnifier, 11 pt group headers in ink2, the current action highlighted (Volume / Mute).
  - Unavailable items in ink2 with "Needs a backlit keyboard" under them.
  - Parameter actions end in "…".
  - The final disclosure "N more need a tap, swipe or long-press", word for word as S4.
- Differs:
  - Height is min(420, mirror − 16) per the chief's correction. S4 is drawn at 420.
  - Width is 320 (cap 420).
  - The bubble uses `windowTint` with a soft ink shadow. Material is judged on the device.
  - On a bottom bar the picker opens upward. At the current cap it reaches past the pad's top bar in the placeholder, because mirror − 16 is taller than the pad's interior (see Open questions).

## Diff summary

- `Sources/EdgyUI/Inspector/`
  - `InspectorView.swift`: the view, the split control, rows, the "…" menu, notes.
  - `InspectorModel.swift`: rows from the editor, writes (setBinding / override / revert / turnOff / remove), drafts, `SplitPlan`, the split as one undo step.
  - `InspectorText.swift`: zone, gesture and action naming, `IssueCopy`, `KeyComboText`.
  - `InspectorParts.swift`: drawn gesture icons, `IssueLine`, rule, text buttons, field chrome.
  - `ParameterEditors.swift`: every editor.
  - `KeyRecorderController.swift`: the recorder flow.
- `Sources/EdgyUI/Picker/`
  - `ActionPickerView.swift`
  - `PickerCatalog.swift`: grouping, collapse, search, placement geometry.
  - `PickerPopover.swift`: anchor preferences, `.actionPickerHost(model:)`, bubble with arrow.
- `Tests/EdgyUITests/Inspector/**`, `Tests/EdgyUITests/Picker/**`: fakes (availability, apps, shortcuts, recorder, clock), 61 tests.
- `docs/design/build-shots/batch-15/**`: 31 shots × light/dark.
- `.parallel-plans/blockers-batch-15.md`

## Decisions I made (and why)

1. **Split rule:** each new segment takes the bindings of the old segment under its centre.
   - Splitting copies: 1 → 2 gives both halves the edge's action, so nothing changes under the finger.
   - Merging keeps the middle part's binding.
   - The change is one undo step, through `beginContinuousEdit` / `endContinuousEdit`.
   - The selection moves to the part under the old one's centre.
   - Split is disabled on inheriting app tabs, whose layout follows Default.
2. **Drafts:** an action with an empty required parameter isn't written, because the editor refuses it. It is held as a draft until the field is filled. Clearing a saved binding's required value (⌫ on the recorder) removes the slot on Default, or turns it off on an app tab, so nothing fires while the row reads "Needs keys". See blocker 1.
3. **Disclosure wording names the gestures the hidden shapes take:**
   - "need a slide" when only continuous actions are hidden.
   - "need a slide or long-press" when a hold is hidden too. On a tap this gives "6 more need a slide or long-press", because Hold Keys can't take a tap. BRIEF's "6 more need a slide" would be wrong about it.
   - "need a tap, swipe or long-press" on a slide (S4 word for word).
   - "1 more needs …" for a single action.
   - Incompatible rows in the disclosure are shown but not choosable.
4. **Parameter rows show under every binding the tab owns.** That's Default rows, overridden and app-only rows. Inherited and turned-off rows show none, because editing them belongs to Default.
5. **"…" menu:**
   - Default-tab and app-only rows get "Change action…" and "Remove gesture". BRIEF's three items only make sense where a Default binding exists.
   - The menu is a small popover list rather than a system `Menu`, so the `slideAndSwipes` fix can open it (BRIEF: "opens its … menu").
6. **"Add gesture…"** first lists the zone's free gestures in the picker, then the actions for the chosen gesture. The header updates from "Add gesture, right edge" to "Tap, right edge".
7. **Choosing Default's own action on an app tab reverts** instead of writing an identical override.
8. **"Use long-press instead"** moves the tap binding to the long-press slot. It is offered only when long-press is free on that zone.
9. **Sensitivity** has no catalog range, so the slider runs 25%–400% with default 100%.
10. **Zone part names** count in reading order: side edges from the top ("upper half", "middle third", "quarter 2 of 4"), top and bottom from the left.
11. **Key display** uses the system modifier order ⌃⌥⇧⌘ ("⇧⌘ 4"). BRIEF's example "⌘⇧ 4" is out of system order.
12. **Issue copy** for codes BRIEF doesn't word (unknown action, duplicate, etc.) is plain one-clause text in `IssueCopy`. Unknown future `.info` codes render their `detail`, so new notes need no UI round.

## Needs Gabriel

- Picker bubble and inspector over real window material and wallpapers (shots render flat).
- Recorder feel: the 0.6 s modifiers-alone threshold, and that recording really swallows keys, on a real keyboard with the live recorder.
- Gesture icon legibility at real size (16 pt, 1.5 pt stroke), especially swipe up vs down.

## Open questions

1. **Picker height:** min(420, mirror − 16) still covers the pad's opposite bar when the picker opens across the pad. With 8 mm strips the interior is about mirror − 2×(8 mm + gap). Should the cap be the pad's interior height instead? The placement already avoids neighbouring zones whenever it fits.
2. **Should `SettingsModel` own drafts / focus / open-menu state?** See the blocker.
3. **Hosting:** `.actionPickerHost(model:)` still needs to be put on the window. See the blocker.
