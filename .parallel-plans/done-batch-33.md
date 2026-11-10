---
batch: 33
name: EDGY-COMBO — one way to write a key combo, and critique 29's fixes
branch: worktree-edgy-combo
worktree_path: .claude/worktrees/edgy-combo
completed_at: 2026-11-09
verification: swift build ✔ · swift test ✔ (all suites green; EdgyUITests 499+, ActionsTests 332) · swift format lint --strict ✔ · denylist prints nothing
---

# Done — batch 33

## Acceptance criteria

### 1. One formatter, everywhere
- [x] **Exactly one function** writes combos and sequences: `KeyComboText.text(_ steps: [KeyCombo])` in `Sources/Actions/KeyComboText.swift`. `text(_ combo:)` and `text(steps: [String])` are thin wrappers that call it. `KeyCombo.displayText` (DisplayCheck.swift) is **deleted**. The EdgyUI `KeyComboText` enum is gone; what's left is an extension that only parses (`display(stored)`, `held(modifiers)`, `steps`) and calls `text`.
- [x] Every surface calls it: the recorder field (`KeyRecorderField.text`) and its held modifiers while recording, the pad tab and the inspector sub-line (`BindingNaming.target`), the hover line (zone names), the plates (`PlateNaming.keys`) and the hold outcome's `detail` (`ActionRegistry.performReporting`).
- [x] The BRIEF rule, table-driven over every BRIEF example plus arrows, named keys, fn and sequences: `KeyComboTextTests.briefExample` (28 cases), `unparsableOrEmptyStepsHaveNoText`, `noComboTextHasASpaceAfterAModifierSymbol`.
- [x] Same string on all five surfaces for one binding: `Batch33ComboTests.everySurfaceReadsTheOneFormatter` (5 combos: field, fitted pad tab, inspector sub-line, hover line, run and dry-run plate), `holdPlateReadsTheOutcomeOfTheOneFormatter`, `heldModifiersWhileRecordingUseTheFormatter`.
- [x] "Right ⌘" stays dormant (answer 5). No change.
- [x] Old expected strings stay as `//` comments that name the ruling (critique 29 must-fix 1/2/3, design answer 1). No test was deleted or weakened.

### 2. Critique 29 should-fixes
- [x] **Sub-lines, one alignment.** The target and custom sub-lines and the non-inline "from Default" are left-aligned under the gesture name, like "Default: …". Shots: `batch-15/inspector-wayfare-sources-{light,dark}`, `batch-16/tab-wayfare-{light,dark}`, `batch-29/inspector-row-custom-name-*`, `batch-29/inspector-row-target-*`, `batch-33/inspector-overridden-shortcut-sub-lines-*`.
- [x] **Grid scrolls to the selection on open.** A `ScrollViewReader` scrolls to the selected cell on appear. The grid is now an eager `Grid` of 10-column rows, so every cell exists at open. Test: `Batch33InspectorTests.selectedIconIsAGridCell`. Shot: `batch-33/name-and-icon-scrolled-to-selection-{light,dark}` (Hold Keys ringed, Keyboard in view).
- [x] **The field keeps its place** when "+ Then…" hides. A sequence field always reserves the button's width (opacity 0, disabled, hidden from accessibility). Test: `Batch33InspectorTests.fieldKeepsItsWidthWhenThenHides`. Shots: `batch-29/recorder-two-steps-*` and `recorder-four-steps-*` (the field starts at the same x).
- [x] **Plate fixture is coherent.** The `plate-custom-run` and `plate-custom-dry-run` shots now show "Notes" (Open App on a double-tap): "Notes" / "Would run Notes". The old Play/Pause expectations are kept. Test: `Batch29OverlayTests.runPlateIsTheCustomNameWithNoVerb`, `dryRunReadsWouldRunTheCustomName`. Shots: `batch-29/plate-custom-{run,dry-run}-*`.
- [x] **Identical drawings once** (answer 4). Keyboard Brightness and Keyboard Backlight On/Off share one cell. Its tooltip and accessibility label name both, joined with " and ". Choosing it on either action's own row stores no custom icon. Test: `Batch33InspectorTests.identicalDrawingsShareOneCellNamingBoth`.

### 3. Design answers 1–3 and 6
- [x] **1. No commas in combined edge labels:** "A and B", and "A and N more" from three on. Names are counted after pairs collapse, so the default bottom edge still reads "Tracks and Play/Pause". Tests: `Batch33MirrorTests.combinedEdgeLabelHasNoCommas`, `MirrorTests.labelRuleOrdersPairsDedupesJoinsAndMarksMissingParameters`, `appTabShowsEffectiveBindingsWithSourceMarks` ("⇧⌘[ and 2 more"). Shot: `batch-16/tab-wayfare-*`.
- [x] **2. Dry-run verb by kind:** "Would set / hold / run Dictate". Run mode stays verb-less. Test: `Batch33MirrorTests.dryRunVerbFollowsTheKind`. The behaviour was already there; this pins it.
- [x] **3. Corner tabs grow to 40% of their edge before fading.** Forms are still chosen at the usual corner width, so render A's "Mic off" holds. Only the form that would fade may grow to 40%. Tests: `Batch33MirrorTests.cornerTabGrowsToFortyPercentOfItsEdge`, `Batch29MirrorTests.longCustomNameFadesAndNeverEllipsis` (a 24-W name still fades). Shot: `batch-33/pad-corner-tab-forty-percent-*` ("example.com" whole). Also `batch-29/pad-url-and-file-tabs-*`.
- [x] **6. Rename carry:** a new action on an inherited row creates an override without Default's name. On an override, the name set there carries. Tests: `Batch33PickerTests.aNewActionOnAnInheritedRowStartsWithoutDefaultsName`, `aNameSetOnTheOverrideCarries`, `carryIsPure`.

### 4. Re-trigger while a sequence is sending
- [x] Silent, no plate. The action ignores the trigger but returns normally, so the feed still says `actionRan`. `SequenceQuiet` (Overlay) drops the plate for (steps − 1) × 40 ms after a multi-step "Pressed …". The window is global, like the action's lock. Dry run is never quieted. Tests: `Batch33OverlayTests.reTriggerWhileASequenceSendsShowsNoPlate`, `singleCombosAreNeverQuieted`, `quietWindowLastsOneGapPerRemainingStep`.

### 5. Idle budgets / no per-frame formatting
- [x] Labels are formatted inside `MirrorContent.zones`, which is cached per model revision (`MirrorDataCache`). Plates format once per decision. Hover forms come from the cached zone. Test: `Batch33MirrorTests.comboLabelsAreFormattedOncePerRevision`. Batch 28's quiet-when-idle tests are unchanged and green.

### Greps
- Combo grep over `Sources` and `Tests`, comment lines excluded: no "⌃ "+key and no "Arrow" in a combo. Remaining hits:
  - `KeyComboTextTests` (the guard itself).
  - `NativeTests` "Control–Left Arrow", which is the Space Left/Right system-settings copy (prose naming a system shortcut, not a combo display; "change no action behaviour").
- Comment lines keep the old strings on purpose (the user's rule).
- Token greps: clean. Denylist: prints nothing.

## Verification
`swift build && swift test && swift format lint --strict -r Sources Tests Package.swift` all green in the transcript. Formatting was run only on owned paths.

## Bones checklist
1. Mirror is the pad: unchanged (n/a).
2. Zone states by shape: unchanged. See `batch-33/pad-corner-tab-forty-percent-*`.
3. Labels joined to their zone: corner tabs stay flush and grow along their edge with the 12 pt fade, never "…". See `batch-33/pad-corner-tab-forty-percent-*` and `batch-29/pad-tab-custom-long-*`.
4. Recognized vs rejected by shape: n/a.
5. You map on the pad: n/a.
6. Inspector: sub-lines in one alignment. See `batch-15/inspector-wayfare-sources-*`.
7. Interaction notes: n/a.
8. Each status said once: "⇧⌘[ and 2 more" on the bar; the inspector lists all. See `batch-16/tab-wayfare-*`.
9. Overlay: plates per the rule ("Pressed ⌃B, N"). See `batch-29/plate-sequence-*`.
10. Menu-bar popover: hover line unchanged in form (bone 10 comma list).

## Reader-first review
- **Recorder** (`batch-29/recorder-*`): "⌃B, N, ⌘K, X" with no inner spaces. The field sits at the same x with and without "+ Then…".
- **Inspector** (`batch-15/inspector-wayfare-sources`): "Keyboard Shortcut" and "Default: Previous Track" stack left under "Swipe left", which matches the critique's fix.
- **Pad** (`batch-16/tab-wayfare`): the bar reads "• ⇧⌘[ and 2 more", with no comma ambiguity. Corner "example.com" is whole (`batch-33/pad-corner-tab-forty-percent`). "Mic off" is unchanged, as in render A.
- **Name and Icon** (`batch-33/name-and-icon-scrolled-to-selection`): it opens scrolled so Keyboard and its ringed Hold Keys cell show. Sound, Media and Display sit above the fold. The Display group no longer has two identical cells.
- **Plates** (`batch-29/plate-sequence`, `plate-custom-*`): "Pressed ⌃B, N", "Would press ⌃B, N", "Notes", "Would run Notes".

## Diff summary
- `Sources/Actions/KeyComboText.swift` (new, the one formatter). `DisplayCheck.swift` loses `KeyCombo.displayText`. `ActionRegistry.swift` builds the hold detail through the formatter.
- EdgyUI:
  - `InspectorText.swift`: parse-only extension.
  - `ParameterEditors.swift`: field seam, held modifiers, reserved "+ Then…".
  - `InspectorView.swift`: sub-lines left.
  - `NameAndIconPopover.swift`: dedupe, scroll, tooltip.
  - `InspectorModel.swift` and `PickerChoice.swift`: rename carry.
  - `MirrorContent.swift`: joiner.
  - `MirrorPad.swift`: corner growth.
  - `PlateCopy.swift`: keys through the formatter.
  - `OverlayController.swift` + new `SequenceQuiet.swift`.
- Tests:
  - New: `KeyComboTextTests`, `Batch33{Combo,Inspector,Mirror,Overlay,Picker}Tests`.
  - Updated expectations, with the old ones kept as comments: InspectorTests, Batch21/29 Mirror, MirrorTests, Batch25/29 Overlay, PlateCopyTests, Batch29 Inspector/Recorder, OutcomeTests.
- Docs: `settings-reference.md` combo examples. Shots re-shot across batch-14/15/16/21/22/25/27/29, plus new `batch-33/`.

## Decisions I made (and why)
1. **The formatter takes `[KeyCombo]`.** Actions can't see `ConfigValidator.keySteps` (EdgyRuntime), so splitting stored text stays with callers, and formatting lives only in Actions.
2. **"A and N more" counts names after pair-collapse and de-dup**, not raw bindings. Otherwise the default bottom edge would read "Tracks and 1 more".
3. **Corner growth applies only to the form that would fade.** Forms are still chosen at the 26 mm corner width, so render A's "Mic off" short form keeps winning over "Microphone Mute". "Grow … before the fade applies" reads as a fade-only allowance.
4. **The hover line keeps its comma list** (bone 10; the answer says the hover line "lists them all"). See Open questions.
5. **Re-trigger quiet lives in the overlay.** Actions is formatter-only for this batch and `ActionOutcome` is frozen. The window mirrors `ActionRegistry.sequenceStepGap` (40 ms) as a copied constant with a comment, since that constant is internal to Actions.
6. **Rename carry drops only the name, as ruled.** An inherited row's custom icon still carries; see Open questions.
7. **The plate fixture adds a coherent "Notes" binding for the shots.** The existing Play/Pause-named assertions are kept, so no test was weakened.

## Needs Gabriel
- On device: open Name and Icon on a Keyboard binding and confirm the scroll-to-selection lands smoothly (headless shots can't show the animation).
- On device: a fast double-trigger of a 2-step sequence shows one plate.

## Open questions
1. The hover line still joins with ", " ("Bottom: ⇧⌘[, Next Track, Play/Pause"). With combos in it, that reads like a sequence. Should it use " and " too?
2. Rename carry on an inherited row: should Default's **custom icon** also stay behind, like the name?
3. `NativeTests`/availability copy says "Control–Left Arrow" (system settings wording). Leave it, or write it as "⌃←"?
