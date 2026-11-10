---
batch: 33
name: EDGY-COMBO — one way to write a key combo, and critique 29's fixes
branch: worktree-edgy-combo
worktree_path: .claude/worktrees/edgy-combo
completed_at: 2026-11-09
verification: swift build ✔ · swift test ✔ (all 8 test runs green: 58, 7, 134, 501, 270, 20, 57, 332 tests) · swift format lint --strict ✔ · denylist prints nothing
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
- [x] **3. Corner tabs grow to 40% of their edge before fading.** Forms are still chosen at the usual corner width, so render A's "Mic off" holds. Only the form that would fade may grow to 40%. Tests: `Batch33MirrorTests.cornerTabGrowsToFortyPercentOfItsEdge`, `Batch29MirrorTests.longCustomNameFadesAndNeverEllipsis`, `Batch33MirrorTests.nameWiderThanFortyPercentStillFades` (shot `batch-33/pad-corner-tab-wide-name-fades-*`). Shot: `batch-33/pad-corner-tab-forty-percent-*` ("example.com" whole). Also `batch-29/pad-url-and-file-tabs-*`.
- [x] **6. Rename carry:** a new action on an inherited row creates an override without Default's name. On an override, the name set there carries. Tests: `Batch33PickerTests.aNewActionOnAnInheritedRowStartsWithoutDefaultsName`, `aNameSetOnTheOverrideCarries`, `carryIsPure`.

### 4. Re-trigger while a sequence is sending
- [x] Silent, no plate. **This is a behaviour change, not only a pin.** Before this batch a plate did show: the action ignores the trigger but returns normally, so `Router` (Router.swift:170) still emits `actionRan`. Batch 32's done report left "no plate for a re-trigger?" open. `SequenceQuiet` (Overlay) drops the plate for (steps − 1) × 40 ms after a multi-step "Pressed …". The window is global, like the action's lock. Dry run is never quieted. Tests: `Batch33OverlayTests.reTriggerWhileASequenceSendsShowsNoPlate`, `singleCombosAreNeverQuieted`, `quietWindowLastsOneGapPerRemainingStep`.

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

BRIEF § Bones, pasted (hard rule 6):

<details><summary>BRIEF § Bones (verbatim)</summary>

### Bones (hard rules; every PR touching UI is checked against these)

The full text and evidence are in `docs/design/bones.md` and `docs/design/canvas-prompts-r3.md` § BONES.

1. **The mirror is the pad.**
   - It is to scale, from the device's real sensor size.
   - It uses the trackpad's orientation.
   - No rulers, dimension lines or mm callouts.
2. **Zone states by shape** (the build must match the final render):
   - **Mapped edge:** a solid inset bar with rounded ends.
   - **Unmapped edge:** a hairline outline.
   - **Mapped corner:** a solid rounded square with its action icon inside.
   - **Pass-through corner:** a dashed rounded square. Dashed means pass-through and nothing else.
   - **Selected:** an `ink` ring around the zone.
   - **Live:** the accent contact, plus a thin accent border on the lit bar.
   - **Which touches the mirror draws** (owner, 2026-11-07): only a touch that is a gesture candidate or a claim **inside a mapped zone**, or a rejection there. Plain pointer touches in the middle of the pad are **never drawn**. The mirror shows where the finger sits (absolute) while the pointer moves relatively, so drawing ordinary pointer use creates a second "cursor" that drifts against the real one.
   - Selection and live never look alike.
3. **Labels are joined to their zone.**
   - Side strips are 8 mm, about 30 pt, too narrow for text. Their labels are tabs growing from the strip's inner side, in the same fill and with no gap.
   - Top and bottom labels sit inside the bar.
   - Corner labels are tabs flush to the corner tile.
   - Labels are never floating pills, never rotated, and ≥13 pt.
   - The selected zone needs no chip, because the inspector names it.
   - **Long labels never use "…"** (that means "needs a parameter"). In order: the parameter's short value (app name, key combo); the action's short name ("Shortcut", "Repeat keys", "Mic off", "Link"); otherwise clip with a 12 pt fade. The full name is always in the inspector.
   - **"Off here"** is a tab too: a hairline outline, no fill, `ink2` text.
   - Mirrors under about 200 pt wide (presets, the popover mini mirror) may drop the corner action icons; the solid tile still means mapped.
   - Action names are the catalog's display names, spelled the same everywhere.
4. **Recognized vs rejected by shape.**
   - **Recognized:** a filled accent contact. (Contacts appear only per bone 2's "which touches the mirror draws" rule: zone touches, never plain pointer use.)
   - **Rejected:** a hollow, struck circle.
   - A rejection states the measured value against the limit: **"Ignored: palm, 21 mm wide, limit 18 mm"**. This plate was every critic's KEEP; build it exactly like that.
   - **Copy pattern for every reason:** "Ignored: <reason>, <measured>, limit <limit>". Use the runtime's `RejectionMeasure` (measured, limit, unit) with its own unit (mm, ms, fingers). When the measure has no number (unit none), stop after the reason. Rewritten 2026-11-07 from the real measures in `.parallel-plans/done-batch-13.md`.

     | Reason (variant) | Plate copy |
     |---|---|
     | palm (major axis) | Ignored: palm, 21 mm wide, limit 18 mm |
     | palm (minor axis, round contact) | Ignored: palm, 15 mm across, limit 14 mm |
     | palm (size or density only) | Ignored: palm |
     | typing | Ignored: typing, last key 200 ms ago, limit 500 ms |
     | too many contacts | Ignored: 2 fingers, set to 1 *(it counts every non-palm contact, so a resting thumb counts)* |
     | off-axis, corner | Ignored: moved 3.4 mm before the long-press, limit 3 mm |
     | off-axis, edge outward | Ignored: moved 2.8 mm toward the edge, limit 2.5 mm |
     | off-axis, edge diagonal | Ignored: no clear direction, moved 3.4 mm, limit 3 mm |
     | off-axis, swipe that veered | Ignored: swipe veered, 9 mm across, 5 mm along |
     | too fast, held too long | Ignored: swipe too slow, 410 ms, limit 350 ms |
     | too fast, too short | Ignored: swipe too short, 4 mm, needs 6 mm |
     | too fast, no clear axis at lift | Ignored: swipe had no clear direction |
     | handed off to a system gesture | Ignored: system gesture |
     | click | Ignored: click |
     | zone disabled (unmapped part of an edge) | Ignored: nothing mapped here |
     | Edgy off in this app | Ignored: Edgy is off in Huddle |

     - **Started outside a zone is not shown.** The feed doesn't report it, because it's ordinary pointer use. The overlay must never surface it.
     - Numbers use one decimal place only when the value is under 10 and not whole ("3.4 mm"); otherwise they're whole ("21 mm", "410 ms").
   - Recognized is louder.
5. **You map on the pad.**
   - Clicking a zone selects it.
   - The action picker is a popover anchored to that zone on the mirror, with an arrow.
   - It has a header naming what it sets ("Tap, bottom edge"), a search field and grouped rows.
   - **Build it as a single-column list that scrolls if needed.** The render's two columns were a canvas-space workaround that the critic marked down.
   - Actions that can't take the gesture are dimmed, with **one** group note ("These need a slide.").
   - The picker never covers its trigger or the neighbouring zones, and never leaves the window.
6. **The inspector:**
   - It shows the selected zone's name (26), the **Split control** (§ Split control below; the runtime allows 1…4 segments), and **only the mapped gestures** with their actions in plain text.
   - It ends with "Add gesture…".
   - Clicking a row opens the same pad popover. There is one place to map, not two.
   - While the picker is open, the row's value is blank (the popover header already says it).
7. **Interaction notes are named with their fix** (since v0.4 they inform; they don't warn):
   - A tap on a zone that also has a double-tap **waits out the double-tap window**, so nothing misfires. The note is informational: **"Tap waits 300 ms here to tell it from a double-tap."** (use the real `doubleTapWindowMS` value).
   - One inline fix: **"Use long-press instead"**.
   - It keeps the icon plus inline-fix shape, but uses an **info** icon in `ink2`, not a warning triangle. It must never read as an error.
   - It doesn't repeat the zone name. *(Render B's copy, "fires the tap action first", and its "Delay tap by 300 ms" button are out of date. Follow this text, not the render.)*
8. **Each status is said once, next to the thing it describes.**
   - Live feedback appears on the mirror at the touch.
   - In onboarding, the system's own volume indicator carries "64%"; Edgy doesn't repeat it.
   - In Test Mode, the menu glyph's dot is the only "test mode is on" marker. **Drop the "Test mode" pill shown in render D.**
9. **The overlay (Test Mode):**
   - It is a click-through, non-activating panel that never takes focus and never sits over the text being worked on.
   - Each element is its own plate, docked to the screen edge or corner of the touched zone and fully on-screen.
   - Plate text is ≥13 pt at ≥4.5:1, readable over light and dark documents.
   - **One plate component** is shared by the overlay and the onboarding feedback: same radius, same 17/13 type pair, same inset. In the render, C and D look like two products; don't build that.
   - **The plate is always dark** (the espresso plate of renders D and S8) in both system appearances. Over dark documents it gets a 0.5 pt light edge (`rgba(255,230,210,.24)`).
   - **Contacts on a plate** (filled accent, or the dry-run ring) get a 1 pt cream rim (`#FBEADB` at 70%) for ≥3:1, like the app icon's dot. It's a stroke, never a halo.
   - **Run-mode trigger plates** show the bare action name ("Play/Pause"). Actions with a parameter keep a past-tense verb plus the object ("Opened Quillpad", "Pressed ⇧⌘4", "Ran <name>"), pairing with dry run's "Would …". The plate edge is always drawn; it isn't gated on the backdrop. The display check is the one plate exempt from the 17/13 pair.
10. **The menu-bar popover** (not a plain menu):
    - **Top half:** a live mini mirror (zones of the active profile plus the last touch where it landed), profile chips, and **Enabled** and **Test Mode** switches.

</details>

Ticks for this batch:
1. Mirror is the pad: unchanged (n/a).
2. Zone states by shape: unchanged. See `batch-33/pad-corner-tab-forty-percent-*`.
3. Labels joined to their zone: corner tabs stay flush and grow along their edge to 40%, then take the 12 pt fade, never "…". See `batch-33/pad-corner-tab-forty-percent-*` (fits whole) and `batch-33/pad-corner-tab-wide-name-fades-*` (fades). `batch-29/pad-tab-custom-long-*` now fits whole by ruling.
4. Recognized vs rejected by shape: n/a.
5. You map on the pad: n/a.
6. Inspector: sub-lines in one alignment. See `batch-15/inspector-wayfare-sources-*`.
7. Interaction notes: n/a.
8. Each status said once: "⇧⌘[ and 2 more" on the bar; the inspector lists all. See `batch-16/tab-wayfare-*`.
9. Overlay: plates per the rule ("Pressed ⌃B, N"). See `batch-29/plate-sequence-*`.
10. Menu-bar popover: hover line unchanged in form (bone 10 comma list).

**Kill list check:**
- No middot-chained metadata. The two sub-lines stay two lines.
- No second hue.
- No Unicode arrows as gesture icons. The ←→↑↓ appear only as key names inside combo text, which BRIEF rules.
- No filler copy. "and 2 more" is a count, not roadmap copy.
- The reserved "+ Then…" is invisible and inert, so it adds no visual element.
- The shared-cell tooltip is plain names joined by " and ".

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
5. **Re-trigger quiet lives in the overlay (a behaviour change: a plate used to show).** Actions is formatter-only for this batch and `ActionOutcome` is frozen. The window mirrors `ActionRegistry.sequenceStepGap` (40 ms) as a copied constant with a comment, since that constant is internal to Actions.
6. **Rename carry drops only the name, as ruled.** An inherited row's custom icon still carries; see Open questions.
7. **The plate fixture adds a coherent "Notes" binding for the shots.** The existing Play/Pause-named assertions are kept, so no test was weakened.

## Needs Gabriel
- On device: open Name and Icon on a Keyboard binding and confirm the scroll-to-selection lands smoothly (headless shots can't show the animation).
- On device: a fast double-trigger of a 2-step sequence shows one plate.

## Open questions
1. The hover line still joins with ", " ("Bottom: ⇧⌘[, Next Track, Play/Pause"). With combos in it, that reads like a sequence. Should it use " and " too?
2. Rename carry on an inherited row: should Default's **custom icon** also stay behind, like the name?
3. `NativeTests`/availability copy says "Control–Left Arrow" (system settings wording). Leave it, or write it as "⌃←"?
