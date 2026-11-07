---
batch: 23
tag: EDGY-OVERLAY-2
branch: worktree-edgy-overlay2
worktree_path: /Users/gabrielgaravit/Projects/edgy/.claude/worktrees/edgy-overlay2
completed_at: 2026-11-07
verification: pass
---

# Batch 23: overlay polish to critique 18

Shots: `docs/design/build-shots/batch-18/` (re-made) and `docs/design/build-shots/batch-23/` (new). Tests: `Tests/EdgyUITests/Overlay/`.

## Acceptance criteria: critique 18, item by item

### Must fix
1. **[✓] Level plate and display check never sit on the document text.**
   - `OverlayScreenProviding.workArea()` reports the focused text element's frame and its window (`OverlayWorkArea`). Live: `LiveScreens` reads the frontmost app's `AXFocusedUIElement` and `AXFocusedWindow` through Accessibility, with a 0.1 s messaging timeout. It reads only when a plate that wasn't up appears. It never reads on the 30 Hz tick, for a slide's per-tick `actionUpdated`, or for decisions that make no plate (`levelPlateAndCheckStayClearOfTheText` asserts one read across a slide's updates and a `startedOutsideZone` rejection). It returns empty, with one logged reason, when Accessibility isn't granted. Tests use `FakeOverlayScreens(work:)`.
   - `PlateDocking.settle` slides a docked plate **along its edge**, never inward:
     - it never covers the text (plus an 8 pt gap) or another plate;
     - then, when there's room, it keeps 8 pt from the window.
   - `PlateDocking.beside` now stacks the display check **along the docked edge**:
     - below a side-edge or corner level plate, or above it when there's no room below;
     - outward along a top or bottom edge.
     - Before this batch it went inward toward the screen's middle.
   - Evidence:
     - shots `batch-23/overlay-level-check-stacked-*`, `batch-18/overlay-docked-level-check-*`;
     - tests `aPlateNeverCoversTheFocusedText`, `whenTheWindowFillsTheEdgeThePlateStillClearsTheText`, `settledPlatesNeverOverlapEachOther`, `displayCheckStacksAlongTheDockedEdge`, `levelPlateAndCheckStayClearOfTheText` (through the controller; it also proves one work-area read per batch, none per tick) and `showsBesideTheLevelPlateAlongItsEdgeAndCountsTheAsk`;
     - every docked shot asserts that no placement intersects the mock's text frame and that all are inside `visibleFrame` (`MockScreen.docked`).
2. **[✓] One plate component, always dark.**
   - `PlateView` reads only `Tokens.plateFill`, `plateInk`, `plateInk2`, `plateEdge` (+ `plateEdgeWidth`) and `contactRim` (+ `contactRimWidth`), plus `accent`. The appearance-following `ink`/`ink2`/`line`/`windowTint` are gone from it, and so is `PlateMetrics.tintOpacity` (`plateFill` carries its own 0.92).
   - The snapshot harness no longer overrides the colour scheme (`.environment(\.colorScheme, .dark)` removed from `shot()` and `docked()`). All 30 `batch-18/plate-*` light/dark pairs are **byte-identical** (`cmp`), and so is `plate-component-*`, which is no longer pale.
   - Onboarding gets the same plate automatically (one component).
   - Tests: `plateIsTheSameInLightAndDark`, `plateTextReadsOverWhiteAndBlackDocuments` (now against `plateFill`).
3. **[✓] Dry-run suppression and timings shown.**
   - Shot `batch-23/overlay-dryrun-brightness-*`. The feed offers a brightness `wouldRun` **and** a `displayCheckDue`; only "Would set Brightness" shows. The test asserts there's no level plate and no check.
   - The level plate with Test Mode off:
     - shots `batch-23/overlay-level-check-stacked-*` and `overlay-level-test-mode-off-*` (keyboard, dark document; the glyph has no Test Mode dot);
     - test `testModeOffShowsOnlyLevelPlates`.
   - Timings on the injected clock (`ManualClock`, `OverlayBehaviourTests.swift`):
     - `timingsAreBRIEFs` (new): `slideLinger` 1.2, `releaseLinger` 0.6, `fade` 0.2, `displayCheckLinger` 15;
     - `levelPlateFades1point2sAfterTheSlideEnds`: opacity 1 at +1.2 s, gone at +1.4 s;
     - `holdReadsReleasedFor0point6sThenFades200ms`: "Released fn" at 1.0 for 0.6 s, 0.5 at +0.7, gone at +0.8;
     - `fadesAfter15sUnanswered`: 1.0 at 15 s, gone at 15.2 s;
     - `asksAtMostThreeTimes`: five dues lead to `displayCheckAsks == 3`, and the sixth shows nothing;
     - `noLevelPlateInDryRun`.
   - The system HUD in dry run is suppressed by the engine and Actions, outside this glob. The overlay can only prove it adds no level plate.

### Should fix
1. **[✓] The Volume plate no longer overlaps the document window.**
   - `settle` keeps `PlateDocking.workGap` (8 pt) from the focused window, sliding along the edge into empty space.
   - When the window fills the whole edge, the nearest spot that only clears the text wins (`whenTheWindowFillsTheEdgeThePlateStillClearsTheText`). The critique called that legal.
   - Shots `batch-23/overlay-light-document-*`, `batch-18/overlay-docked-test-mode-*`; test `aPlateKeepsAGapFromTheWindowWhenThereIsRoom`.
2. **[✓] The overlay shots include the menu bar.**
   - Every docked shot has a 24 pt menu bar with the exported `MenuGlyph.image(for:)` at the right: `.testMode` (dot) when Test Mode is on, `.normal` when it's off.
   - There's no pill anywhere.
3. **[✓] A dark-document overlay.**
   - `batch-23/overlay-dark-document-*` and `overlay-level-test-mode-off-*`.
   - The plates sit in the gutter (that's the fix), so the edge-over-black evidence is the isolated `plate-*` shots, whose right half is a black document. There the 0.5 pt light edge is visible, and over white it vanishes.
   - Test `plateEdgeShowsOverADarkDocument`.

### Rulings (Design answers 1–5, BRIEF bone 9)
1. **[✓] Always the dark espresso plate**, plus a 0.5 pt light edge. **Decision: the edge is always drawn.** The plate can't know what's behind it. Over white, a 24% cream 0.5 pt line on the dark plate is indistinguishable from no edge (`plate-*-light` left half), and over black it separates the plate (right half).
2. **[✓] Bare trigger name in run mode:** "Play/Pause" (`plate-run-trigger-*`, `triggerUsesThePadSpelling`). Parameterized runs keep "Opened Quillpad" / "Pressed ⇧⌘ 4" / "Ran <name>" (see Open questions).
3. **[✓] Display check exempt from 17/13:** 13 semibold question, two text buttons (`plate-display-check-*`).
4. **[✓] Contact rim:**
   - The recognized contact is an accent fill inside a 1 pt `contactRim` stroke.
   - The dry-run mark is a 2 pt accent ring with the same rim outside it.
   - Both keep the 26 pt mark size. It's a solid stroke, not a halo (kill list).
   - Shots `plate-run-volume-*`, `plate-would-set-*`; test `contactRimReachesThreeToOneOnThePlate` (≥3:1 over white and black documents).
5. **[✓] Keyboard plate:** "Keyboard 60%" / "Built-in keyboard", or the external keyboard's name from `ActionOutcome.detail` (`plate-level-keyboard-*`; tests `keyboardBacklightLevelPlate`, `keyboardPlateNamesAnExternalKeyboard`).

### Also
- The chief's request: removed the dead `default:` in `PlateContent.from` (the switch is exhaustive), so `Overlay/` builds without that warning.

## Verification (run in this transcript)
- `swift build`: `Build complete!`, no warnings from `Overlay/`.
- `swift test`: every target passes: 56, 7, 134, **342 EdgyUI**, 250, 19, 57, 289.
- `swift format lint --strict -r Sources Tests Package.swift`: exit 0.
- `git grep -niE -f ~/.config/edgy-names-denylist`: no output (exit 1).
- Token greps:
  - the colour-literal grep over `Sources/EdgyUI` (minus Tokens) prints nothing;
  - no `.system(size:`, `.custom(`, second hue or `accentColor` in `Overlay/`.
- `swift test` rewrites `docs/design/build-shots/skeleton/plate-*.png` (outside my glob); I restored them with `git checkout`.

## Bones checklist
1. Mirror is the pad: n/a.
2. Zone states: n/a.
3. Labels: n/a. Plate names use the catalog spelling (`plate-run-trigger`).
4. Recognized vs rejected by shape: ✓ filled and rimmed contact vs struck `plateInk2` circle (`plate-run-volume`, `plate-rejected-palm-wide`); copy unchanged from batch 18.
5. Map on the pad: n/a.
6. Inspector: n/a.
7. Interaction notes: n/a.
8. Each status said once: ✓ the glyph dot is the only Test Mode marker, now visible in the menu bar (`overlay-light-document`, vs `.normal` in `overlay-level-check-stacked`); no pill.
9. The overlay:
   - ✓ click-through and non-activating (unchanged);
   - ✓ never over the text being worked on (must-fix 1 evidence);
   - ✓ docked at the edge or corner, fully on-screen (snapshot asserts);
   - ✓ ≥13 pt at ≥4.5:1 over light and dark (`plateTextReadsOverWhiteAndBlackDocuments`);
   - ✓ one component (identical pairs);
   - ✓ always dark plus the light edge;
   - ✓ contact rim;
   - ✓ bare trigger name;
   - ✓ display check exempt.
10. Popover: n/a.

Kill list: no halo (the rim is a 1 pt solid stroke), no hero numerals, no second hue, no space before %. ✓

## Reader-first review
- **D vs `batch-23/overlay-light-document-light.png`.**
  - **Matches:**
    - dark warm plates over a light desktop and a white document;
    - Volume at the right edge's middle, the palm bottom-left;
    - the rim reads like the app icon's dot.
  - **Differs:**
    - The glyph sits in a menu bar strip, not a pill (bone 8).
    - Plates stay in the gutter, clear of the window, by rule.
    - The hold plate is added at the bottom.
- **S8 vs `batch-23/overlay-level-check-stacked-light.png`.**
  - **Matches:**
    - "Brightness 40%" / "Desk 34" with the slim bar at the left edge;
    - the check in the left gutter, clear of the document.
  - **Differs:**
    - The check is stacked **below** the level plate (critique ruling), where S8 has it beside.
    - The mock desktop is a token gradient, not a photo.
- Desktop gradient: the mock desktop follows the appearance (light/dark tokens), so the docked `-dark` shots differ from `-light`, but the plates in them are identical.

## Diff summary
- `PlateView.swift`:
  - plate tokens only;
  - an always-drawn edge;
  - the contact rim;
  - the level track is `plateInk2` at 30%;
  - buttons use `plateInk`.
- `PlateContent.swift`: `keyboardDevice` = "Built-in keyboard"; the dead `default` is removed.
- `PlateDocking.swift`: `beside` places along the edge; new `settle`, `workGap`, `slideStep`, `slidesVertically`.
- `OverlayController.swift`:
  - `OverlayWorkArea`;
  - `OverlayScreenProviding.workArea()`;
  - the work area is read once per batch of decisions;
  - every placement goes through `settle` with the plates already placed;
  - the live AX reader is in `LiveScreens`.
- `PanelPresenter.swift`: comment only.
- Tests:
  - `FakeOverlayScreens(work:)`;
  - the contrast suite is rewritten against the plate tokens;
  - new docking, controller and timing tests;
  - `MockScreen` + `MockDesktop` (menu bar, glyph, light or dark document at known frames);
  - `OverlayCompositionTests` writes the batch-23 shots.

## Decisions I made (and why)
- **The edge is always drawn** (ruling 1 allows it when indistinguishable; the isolated shots show it is).
- **Work area read only when a new plate appears**, not per tick or per slide update: AX calls are IPC to the frontmost app on the main thread. Plates that are already up keep their spot until the next new plate.
- **The text is a hard limit and the window a soft one.** BRIEF forbids covering text; the window gap is the critique's should-fix. When nothing on the edge clears the text, the docked frame stays (the edge is full; this never happens with a normal text column).
- **The level track** uses `plateInk2` at 30% (no plate `line` token; `Shared/` is frozen).
- **Existing test changed in direction, not intent:** `displayCheckSitsBesideTheLevelPlateTowardTheMiddle` → `displayCheckStacksAlongTheDockedEdge`, and `showsBesideTheLevelPlateAndCountsTheAsk` → `…AlongItsEdge…`. Both still check that the check sits beside its level plate, fully on screen; the asserted side changed because "inward" was the bug.

## Needs Gabriel
- Avoidance on the device:
  - in a real editor, with Accessibility granted, the plates should slide off the text column;
  - check the AX frame of a web text area, which can be the whole page.
- The 0.5 pt edge and the rim at real size, over a real dark document.
- The level plate on a second display while the focused window is on the first. The work area is per frontmost app, so it can sit on another screen; it doesn't intersect there, and that's harmless.

## Open questions
1. **Parameterized run copy:** does "run mode needs no verb" extend to "Opened Quillpad" → "Quillpad", "Pressed ⇧⌘ 4" → "⇧⌘ 4", "Ran <name>" → "<name>"? I kept batch 18's copy because the ruling answered the bare trigger only.
2. **External keyboard name:** the plate shows `ActionOutcome.detail` when Actions sets it for the keyboard backlight. Today Actions sends none, so it always reads "Built-in keyboard".
3. **Skeleton shots:** `SkeletonTests` rewrites `build-shots/skeleton/plate-*.png` with the now-dark plate. Regenerate them on `main`.
