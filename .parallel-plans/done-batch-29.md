---
batch: 29
tag: EDGY-NAMES
branch: worktree-edgy-names
worktree_path: .claude/worktrees/edgy-names
completed_at: 2026-11-09
verification: swift build ✔ · swift test ✔ (full run repeated after the last code change, the ValidationTests edit: every suite green; EdgyUI 483, EdgyRuntime 270) · item 5 blocked (blockers-batch-29.md) · swift format lint --strict -r Sources Tests Package.swift ✔ · denylist ✔ (empty, tracked and untracked) · token greps ✔ (empty) · `git diff --name-only main...` only owned paths
---

# Done: batch 29, EDGY-NAMES (your own name and icon, Hold Keys first on a long-press, key sequences, Last App, Use Escape, target names)

Shots: `docs/design/build-shots/batch-29/<name>-light.png` + `-dark.png`. Test files:
- R = `Tests/EdgyRuntimeTests/Batch29NameAndIconTests.swift`
- I = `Tests/EdgyUITests/Inspector/Batch29InspectorTests.swift`
- K = `Tests/EdgyUITests/Inspector/Batch29RecorderTests.swift`
- P = `Tests/EdgyUITests/Picker/Batch29PickerTests.swift`
- M = `Tests/EdgyUITests/Mirror/Batch29MirrorTests.swift`
- O = `Tests/EdgyUITests/Overlay/Batch29OverlayTests.swift`

## Acceptance criteria

- [x] **1. Editor and validation.** `SettingsEditor.setNameAndIcon(_:in:name:icon:library:)` sets the name and icon in one undo step.
  - **Name:** `SettingsEditor.customName(_:actionName:)` trims it and cuts it to 24 characters. Empty, or equal to the action's own name, saves as nil.
  - **Icon:** the action's own saves as nil. Anything outside the library throws `unknownIcon` and changes nothing.
  - **App tabs:** naming an inherited binding on an app tab makes an override (same action and parameters).
  - **Hand edits:** a bad name or icon in the file only warns: `unknownCustomIcon`, `customNameTooLong`.
  - **Tests:** R `nameIsTrimmedAndCappedAt24Characters`, `emptyOrTheActionsOwnNameSavesAsNil`, `nameAndIconAreOneUndoStep`, `unknownIconIsRefused`, `resetClearsBoth`, `namingAnInheritedBindingOnAnAppTabCreatesAnOverrideAndRevertDropsIt`, `anEmptySlotIsNotFound`, `handEditedIconAndNameWarnButNeverBlock`.
  - **Engine parity:** R `aRenamedBindingPerformsIdentically`. The router gives identical performed actions and haptics with and without names and icons on every default binding.
  - **UI side:** I `popoverSavesNameAndIconAsOneStepAndResets`, `renamingAnInheritedRowOnAnAppTabMakesAnOverrideWithRevert`.
- [x] **2. Inspector.**
  - **Menu:** "Name and Icon…" is the second "…" menu item, greyed on a turned-off row.
  - **Popover:** `NameAndIconPopover`, 320 pt, anchored to the row.
    - The Name field's placeholder is the action's name. It is focused on open; Return saves and closes. Closing also saves a changed name.
    - The grid has 16 pt icons in 28 pt cells, grouped and ordered like the picker under 11 pt semibold `ink2` headers. The selected cell has an `ink` ring, and the action's own icon has the tooltip "Default". Clicking a cell saves name and icon in one step.
    - "Reset name and icon" (`ink2`) shows only when either is set.
  - **Row:** the custom name in `ink`, with an `ink2` sub-line naming the real action ("Hold Keys: fn Space").
  - **Shots:** `name-and-icon-empty`, `name-and-icon-set`, `inspector-row-custom-name`.
  - **Tests:** I `menuOffersNameAndIcon`, `iconGridIsGroupedLikeThePickerAndOnlyDrawnIcons`, `rowSubLineNamesTheRealActionAndParameter`, `keepIconLeavesTheCurrentIcon`.
  - **Ruling change:** `ParameterPresentationTests.rowMenusGreyOutWhatDoesntApply` has new arrays; the old ones are kept as comments naming batch 29.
- [x] **3. Every surface.**
  - **Pad tab:** the custom name replaces the short-form rule, with the fade and never "…". Shots `pad-tab-custom-short`, `pad-tab-custom-long`.
  - **Zone icons:** the custom icon on full-mirror corners and the mini mirror. Shot `mini-mirror-custom-icon`.
  - **Hover line:** "Bottom-right: Dictate". Shot `hover-line-custom-name`.
  - **Plates:** "Dictate" (no verb); "Dictate, held" → "Dictate, released"; dry run "Would run Dictate"; second line unchanged. Shots `plate-custom-run`, `plate-custom-hold-held`, `plate-custom-hold-released`, `plate-custom-dry-run`.
  - **Picker:** keeps real names (P `pickerRowsShowRealNames`).
  - **Tests:** M and O (custom-name suites).
- [x] **4. Hold Keys findability.** On a long-press, Keyboard moves to the top with Hold Keys first, including while searching. Other gestures are unchanged.
  - **Tests:** P `longPressPutsKeyboardFirstWithHoldKeysFirst`, `otherGesturesKeepCatalogOrder`.
  - **Shot:** `picker-long-press-order`.
- [ ] **5. Performance: BLOCKED on the live numbers (see `blockers-batch-29.md`).** A read-only run against the running main build (not this branch; the Mac was in use) read CPU 16.08%, 146 wakeups/s. That is not a valid idle reading for this batch.
  - **No per-frame work:**
    - Pad labels and zone icons are computed in batch 28's `MirrorDataCache`, once per revision. `BindingNaming` is pure string work.
    - App marks go through `AppIconCache`, off main when `appIconsLoadOffMain` is set.
    - `MirrorAppPaths` looks up a bundle path once per bundle ID and keeps it.
    - The grid is built when the popover opens, never per frame.
  - **Tests:** batch 28's `mirrorDataIsComputedOnceForManyBodyEvaluationsAtOneRevision` and `identicalFramesProduceNoObservationChange` still pass.
  - **Not measured here:** `scripts/measure-idle.sh` with the popover open. It needs this build installed and running, and this session never launches or quits Edgy. See Needs Gabriel.
- [x] **6. Recorder.**
  - "+ Then…" (`ink2`, tooltip "Send another shortcut after this one") sits right of the field once a combo is committed. It is hidden at 4 steps and while recording.
  - ⌫ while idle removes the last step; with one step it clears.
  - Esc cancels only the step being recorded.
  - A modifier-only step is refused with the existing copy.
  - Hold Keys and the repeat keys never get the button.
  - **Tests:** K. **Shots:** `recorder-one-step`, `recorder-two-steps`, `recorder-four-steps` (no button).
- [x] **7. Display everywhere.**
  - **Field:** "⌃ B, N" (`KeyComboText.display`). Shot `recorder-two-steps`.
  - **Pad tab:** the sequence shows as the tab's short value. Shot `pad-tab-sequence`.
  - **Sub-line:** I `rowSubLineNamesTheRealActionAndParameter` ("Keyboard Shortcut: ⌃ B, N").
  - **Plates:** "Pressed ⌃ B, N" / "Would press ⌃ B, N". Shot `plate-sequence`; O.
- [x] **8. Sequence validation.**
  - 1–4 combos, separated by one space, each valid, with no modifier-only step.
  - New stable codes `keySequenceTooLong` and `keySequenceNotAllowed`, documented in `docs/settings-reference.md` § Validation codes and § Key sequences.
  - **Tests:** R `KeySequenceValidationTests` (7). `ValidationTests.everyCodeIsReachable` now also reaches the four new codes.
- [x] **9. Picker Apps.**
  - **Order:** Open App, Last App, Switch Apps, Open URL, Open File or Folder. The old order is kept as a comment naming the ruling.
  - **Last App:** no sub-line; search aliases back, previous, return, toggle. Tests use a fixture `app.last` descriptor when the catalog lacks it, so they run without skips.
  - **Tests:** P `appsOrderPutsLastAppSecond`, `lastAppHasNoSubLine`, `searchFindsLastAppByWhatItDoes`.
  - **Shot:** `picker-apps-last-app`.
- [x] **10. Use Escape (chief add-on).**
  - While a Keyboard Shortcut field or step is recording, "Use Escape" (`ink2`, tooltip "Record the Escape key itself") sits under the field. A click commits `escape` as that step, displayed "Esc" ("⌃ B, Esc").
  - Not on Hold Keys. ⌥Esc records as today.
  - Bare Return, Tab, Space and Delete record directly (test in K).
  - **Shots:** `recorder-use-escape`, `recorder-escape-recorded`.
- [x] **11. Bindings that name their target (chief add-on).**
  - **One rule:** `BindingNaming.label` / `BindingNaming.icon` in `Inspector/InspectorText.swift`: custom > target > the action's own.
    - Open App → the app's name; URL → the host without "www."; File → the last path component; Keyboard Shortcut and Hold Keys → their keys.
    - An empty parameter still shows "Name…".
  - **Open App icon:** the app mark (`ZoneMark`, through `AppIconCache`). An app with no icon of its own gets the Open App tile in `ink2`.
  - **Inspector row:** the target in `ink` with the action under it ("Open App").
  - **The bug:** an edge tab had room for "Keyboard Shortcut", so it never fell back to the keys; corners did. The target is now the main text everywhere (M, edge-shortcut test).
  - **Tests:** I `precedenceIsCustomThenTargetThenAction`, `targetsReadShort`, `rowShowsTheTargetWithTheActionUnder`; M (three levels on tabs and icons, two Open App corners, URL and file tabs, hover "Top-right: Wayfare").
  - **Shots:** `pad-two-open-app-corners`, `pad-shortcut-edge-and-corner`, `pad-url-and-file-tabs`, `mini-mirror-app-mark`, `inspector-row-target`.
  - **Ruling changes:** `Batch21MirrorTests` and `MirrorTests` have new label assertions; the old ones are kept as comments naming the ruling.

## Verification
Run in this transcript after the last code change (the full `swift test` was repeated after the `ValidationTests.swift` edit):
- `swift build`: Build complete.
- `swift test`: every run passed, 0 ✘. EdgyUI ran 483 tests in 49 suites.
- `swift format lint --strict -r Sources Tests Package.swift`: no output.
- `git grep -niE -f ~/.config/edgy-names-denylist`: empty, and empty over untracked files too.
- Token greps: empty.

## Bones checklist (BRIEF § Bones)
- [x] 1 The mirror is the pad: `pad-two-open-app-corners`, `pad-shortcut-edge-and-corner` (to scale, unchanged geometry)
- [x] 2 Zone states by shape: same shots. A mapped corner is a solid tile with its icon, now the custom icon or app mark (`mini-mirror-custom-icon`, `mini-mirror-app-mark`).
- [x] 3 Labels joined to their zone, fade never "…": `pad-tab-custom-long`, `pad-tab-sequence`, `pad-url-and-file-tabs`
- [x] 4 Recognized vs rejected: n/a (rejection copy unchanged)
- [x] 5 You map on the pad: `picker-long-press-order`, `picker-apps-last-app`
- [x] 6 The inspector: `inspector-row-custom-name`, `inspector-row-target`, `name-and-icon-set`
- [x] 7 Notes named with their fix: n/a (unchanged)
- [x] 8 Each status said once; accent means live only: the recorder ring is the only accent (`recorder-use-escape`). The selected icon cell is an `ink` ring (`name-and-icon-set`).
- [x] 9 The overlay: `plate-custom-run`, `plate-custom-hold-held`, `plate-custom-dry-run`, `plate-sequence` (one plate component, 17/13, always dark)
- [x] 10 The popover: `mini-mirror-custom-icon`, `hover-line-custom-name`, `mini-mirror-app-mark`

## Reader-first review
- **Name and icon popover** (`name-and-icon-set-light`): Name field, then grouped icons with 11 pt headers. The Dictation cell carries the `ink` ring, and "Reset name and icon" sits quietly under the grid. The grid scrolls (300 pt cap), so Apps, Keyboard and Shortcuts are below the fold. No render exists for this surface yet; it follows the BRIEF text.
- **Inspector row** (`inspector-row-custom-name-dark`): "Dictate" in `ink` on the Long-press row, with "Hold Keys: fn Space" right-aligned under it in `ink2`. It matches the existing sub-line pattern ("Default: X").
- **Pad** (`pad-shortcut-edge-and-corner-light`): the left edge reads "⌃ Tab" (it used to read "Keyboard Shortcut"), and the corner tab reads "fn Space". Tabs join the strip as in render A.
- **Plate** (`plate-custom-hold-held-dark`): "Dictate, held" over "Bottom-right corner, long-press", espresso plate with a rimmed accent contact. It matches S8's hold plate.
- **Recorder** (`recorder-use-escape-light`): an accent ring with "Press keys…", and "Use Escape" quiet under the field.

## Diff summary
- **Runtime:** `EdgyRuntime/SettingsEditor.swift` (`setNameAndIcon`, `customName`, `iconLibrary`, two error cases) and `Validation.swift` (four codes, `keySteps`, `checkKeys`).
- **Inspector:**
  - `NameAndIconPopover.swift` (new).
  - `InspectorView.swift`: menu item, row label and sub-line.
  - `InspectorModel.swift`: the `naming` draft, and the name/icon carry in `choose`.
  - `InspectorText.swift`: `BindingNaming`, sequence display, issue copy.
  - `KeyRecorderController.swift` and `ParameterEditors.swift`: sequences and Use Escape.
- **Picker:** `PickerCatalog.swift` (long-press order, Apps order, Last App) and `PickerChoice.swift` (new: name/icon carry rule).
- **Mirror:** `MirrorContent.swift`, `MirrorPad.swift`, `MiniMirrorView.swift`, and `ZoneMark.swift` (new: app mark on zones).
- **Popover:** `MenuPopoverView.swift` (app paths for the mini mirror).
- **Overlay:** `PlateCopy.swift` and `PlateContent.swift`.
- **Docs:** `settings-reference.md`.
- **Tests:** the six new files above, plus ruling updates in `ParameterPresentationTests`, `Batch21MirrorTests`, `MirrorTests` and `ValidationTests`.

## Decisions I made (and why)
- **Combo display keeps today's space:** "⌃ B, N", not BRIEF's "⌃B, N", so a sequence reads like every existing combo ("⇧⌘ 4", "fn Space").
- **A value that parses as one combo as a whole stays one step.** An older hand edit like `"cmd + 4"` still works, which keeps "one combo = today's value exactly".
- **The icon library is passed by the UI** (the IDs `ActionIcons` draws), because EdgyRuntime can't see EdgyUI. The editor's default is the catalog minus "Do nothing".
- **The name and icon follow a new action from the picker.**
  - The icon is dropped if it is the new action's own. The name is dropped if it equals the new action's name.
  - Nothing carries to "Do nothing" or from a turned-off slot.
  - The rule lives in `PickerChoice.carry`, called from `choose`, so it is one write and one undo step.
- **The target pattern in the inspector covers keys too.** A Hold Keys row reads "fn Space" with "Hold Keys" under it. It is the same function on every surface, so the row and the tab never disagree.
- **Plates and dry run:**
  - A cancelled hold reads "Dictate, released, finger left the zone".
  - A hold in dry run reads "Would hold Dictate", and a slide reads "Would set Dictate".
  - Level and failed plates keep the real action name.
  - A custom name on a binding with an empty parameter shows "Dictate…".
- **Recording swallows keys in the field.** The live key tap is listen-only, so the field swallows key presses while recording and for 0.5 s after. Otherwise Space or Return would press the field.
- **Shots in other batch folders were restored.** The full test run rewrites batch-14/15/16/21/22/27 shots, because tabs and the long-press picker now follow this batch's rulings. Those folders are outside my glob, so I restored them from HEAD. They still show the old labels until the chief re-runs them on main.

## Needs Gabriel
1. **Idle measurement with this build:** install, launch, open the popover, then `scripts/measure-idle.sh 3 150`. Do the same with Settings open on a zone with the Name and Icon popover open.
2. **Recorder keys on the device:** record bare Return, Tab, Space and Delete. Confirm none of them presses, moves or clears the field.
3. **App mark tint:** on the real mirror and mini mirror, check it is desaturated (and 70% in dark). Snapshots show colour because the filter isn't applied headlessly, the same as batch 27's app marks.
4. **"+ Then…" layout:** the button shifts the 170 pt field left when it appears. Judge whether it should hold its place.

## Open questions
- Plates write "fn⌃" (`KeyCombo.displayText`) while the pad and inspector write "fn ⌃". Should one helper serve both?
- After a rename, picking a new action on an inherited row carries Default's name into the new override. Confirm that's wanted.
