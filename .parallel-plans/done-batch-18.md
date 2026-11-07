---
batch: 18
tag: EDGY-OVERLAY
branch: worktree-edgy-overlay
worktree_path: /Users/gabrielgaravit/Projects/edgy/.claude/worktrees/edgy-overlay
completed_at: 2026-11-07
verification: pass
---

## Acceptance criteria
- [✓] **`PlateView`, the one plate component** (`Sources/EdgyUI/Overlay/PlateView.swift`):
  - one radius (`Tokens.radiusPlate`), the 17 semibold / 13 type pair, one inset (18 × 14);
  - marks: recognized (filled accent), **would-run** (2 pt accent outline, no fill; a new `Mark.wouldRun` case, which BRIEF § Test Mode needs), rejected (hollow `ink2` circle with a strike), level (slim accent bar), none;
  - the frozen `init(mark:title:detail:)` is unchanged. A second init adds buttons for the display check.
- [✓] **Copy mapper**, pure: `PlateContent.from(_:catalog:context:dryRun:)` (`PlateContent.swift`, `PlateCopy.swift`).
  - Every rejection row of BRIEF bone 4 uses batch 13's real measures and units.
  - Runs, dry run "Would…", holds held / released / cancelled, the level plate, the display check, failures.
  - No level plate when `systemHUDShown` or in dry run.
- [✓] **`OverlayController`** (`init(model:)`, `start()` / `stop()`, `public var showsTestModePlates`):
  - one click-through, non-activating panel per screen, plus one small clickable non-activating panel for the display check;
  - plates dock at the touched zone's screen edge or corner, fully on-screen, inside `visibleFrame`;
  - the level plate goes on the display it changed; the other plates go on the key window's screen;
  - plates replace each other per zone, with at most 6 at once.
- [✓] **Display check**:
  - It asks through `editor.displayCheckDue` and counts each ask with `countDisplayCheckAsk`, so it asks at most 3 times. Answers go to `answerDisplayCheck`.
  - It fades after 15 s and stays put while its level plate fades.
- [✓] **Snapshots, light + dark**, 32 pairs in `docs/design/build-shots/batch-18/`. Each plate is shown over a white and a black document strip:
  - `plate-run-volume`, `plate-run-trigger`
  - `plate-would-set`, `-run`, `-open`, `-hold`, `-release`
  - `plate-rejected-*`, 16 shots: every bone 4 row, plus off-in-app
  - `plate-hold-held`, `-released`, `-cancelled`
  - `plate-level-brightness`, `plate-level-keyboard`
  - `plate-display-check`
  - `plate-component` (the component following the appearance)
  - `overlay-docked-test-mode` (D-like), `overlay-docked-level-check` (S8-like)
- [✓] **≥ 20 tests: 40 new test functions** (UI test count went from 220 to 260 cases):
  - copy for every decision kind and every rejection variant;
  - dry-run copy;
  - no level plate with the HUD shown or in dry run, both in the mapper and through the controller;
  - docking for each edge and corner, split segments, stacking and multiple screens;
  - fades on an injected clock (plate 1.6 s, slide end + 1.2 s, release 0.6 s + 200 ms, check 15 s);
  - display-check answers call the editor, and asks stop at 3;
  - plain touches and `startedOutsideZone` never make a plate;
  - contrast of 4.5:1 or better over white and black documents.
- [✓] Token greps clean, the verification triple passes, the denylist is clean.

## Verification
- `swift build`: `Build complete!`
- `swift test`: every target passes (56, 7, 134, **260 EdgyUI**, 250, 19, 57, 289).
- `swift format lint --strict -r Sources Tests Package.swift`: exit 0, no output.
- `git grep -niE -f ~/.config/edgy-names-denylist`: no output (exit 1).
- Token greps:
  - no colour literals outside Tokens;
  - no `.system(size:` and no `.custom(` fonts;
  - no second hue.
  - The only Unicode arrow-block characters are ⇧ and ⌘ in a comment's example key combo (system key symbols, not icons).

## Bones checklist
1. Mirror is the pad: n/a (no mirror in this batch).
2. Zone states by shape: n/a.
3. Labels joined to zones: n/a. The plates use the catalog's display names, spelled the way the pad does ("Play/Pause"): `plate-run-trigger`.
4. Recognized vs rejected by shape:
   - ✓ filled accent: `plate-run-volume`;
   - ✓ hollow struck circle: `plate-rejected-palm-wide`;
   - ✓ "Ignored: palm, 21 mm wide, limit 18 mm" exactly: `plate-rejected-palm-wide`, `overlay-docked-test-mode`;
   - ✓ every row of the copy table: `plate-rejected-*`;
   - ✓ started-outside-zone is never shown (test).
5. Map on the pad: n/a.
6. Inspector: n/a.
7. Interaction notes: n/a.
8. Each status said once:
   - ✓ no "Test mode" pill anywhere;
   - ✓ level plates show only where the system draws nothing (`systemHUDShown` → no level plate; tests).
9. The overlay:
   - ✓ click-through and non-activating (`OverlayPanel`: `canBecomeKey` false, `.nonactivatingPanel`, `ignoresMouseEvents`);
   - ✓ docked at the touched edge or corner, fully on-screen: `overlay-docked-*` and the docking tests;
   - ✓ ≥13 pt text at 4.5:1 or better over light and dark documents: `PlateContrastTests`, and every `plate-*` shot over white and black;
   - ✓ one plate component: `plate-component` shows the same view that onboarding can use.
10. Popover: n/a.

Kill list: no hero numerals, no middot chains, no space before %, no second hue, no glow on the contact (a flat fill). ✓

## Reader-first review
- **D (Test Mode overlay)** vs `overlay-docked-test-mode-light.png`.
  - **Matches:**
    - the volume plate sits at the right edge, vertically centred;
    - the palm rejection sits in the bottom-left corner;
    - dark warm plates over a light desktop;
    - the 17/13 pair, an accent dot and a struck circle;
    - the copy is word for word.
  - **Differs:**
    - No "Test mode" pill (bone 8 drops it).
    - D's contact is an oval with a light ring; mine is a flat accent circle with no ring (the kill list bans halos).
    - The mock desktop is a token gradient, not a photo.
- **S8 (level plate, display check, hold)** vs `overlay-docked-level-check-light.png`.
  - **Matches:**
    - "Brightness 40%" / "Desk 34" with a slim accent bar on the left edge;
    - the check beside it, top-aligned, toward the middle;
    - "Yes" and "No, turn off for this display" as stacked text buttons on an `ink` wash;
    - "Holding fn" / "Bottom edge, long-press" centred on the bottom edge.
  - **Differs:**
    - The check is placed beside the level plate wherever it is, not only at S8's left-edge spot.
    - Headless, the plate is a flat tint; in the live panel it sits on the HUD material.
- **C (onboarding)**:
  - The component follows the appearance (`plate-component-light` is a light plate with `ink` text), so batch 19 can put it on the light glass window.
  - C itself shows the system's volume indicator, not a plate (bone 8), so there is nothing else to match.

## Diff summary
All in `Sources/EdgyUI/Overlay/`:
- `PlateView.swift`: the marks, the level bar, the struck circle, the button style, and `init(_ content:onAnswer:)`.
- `PlateCopy.swift`: `PlateContext` (bindings in effect, app names, off-in-app, `palmMajorAxisMM`), `PlateNumber`, `RejectionCopy`, `PlateNaming`.
- `PlateContent.swift`: the content model and the mapper.
- `PlateDocking.swift`: docking geometry.
- `OverlayTimeline.swift`: plates over time.
- `OverlayController.swift`: the loop, screens, the display check, and the live screens and clock.
- `PanelPresenter.swift`: the live panels.

Tests are in `Tests/EdgyUITests/Overlay/` (copy, behaviour, snapshots).

## Decisions I made (and why)
- **Overlay plates are always dark (`darkAqua` on the panel), but `PlateView` follows the appearance.**
  - Renders D and S8 draw dark plates on a light desktop, and a dark plate holds contrast over any document.
  - Onboarding (C) puts the same component on light glass, so the component itself stays neutral.
- **Plates use 0.92 tint opacity**, not the window's 0.82. At 0.82, a light plate over a black page puts `ink2` at about 4.1:1; the contrast test caught it. BRIEF: "add opacity, not a second colour."
- **Rejection variants are told apart by the measure.** `RejectionMeasure` doesn't say which check produced it, and `Gestures.Tuning` is internal to Gestures.
  - Palm: a limit equal to `palmMajorAxisMM` reads "wide"; anything else reads "across".
  - Off-axis: a corner zone → "before the long-press"; limit 2.5 → "toward the edge"; limit 3 → "no clear direction"; any other limit → "swipe veered".
  - Too fast: unit ms → "too slow"; unit mm → "too short"; no measure → "no clear direction".
  - The fixed limits are mirrored in one place (`RejectionCopy`), with comments naming their `Tuning` source.
  - It can be wrong in one edge case: a veered swipe whose along-travel is exactly 2.5 or 3 mm. See Open questions.
- **"Edgy is off in Huddle"** comes from the context: the frontmost app's profile is `disabled`, so the runtime reports every touch as `disabledZone`.
- **Copy BRIEF doesn't give:**
  - Test Mode trigger runs use the action's pad name ("Play/Pause").
  - Actions with a parameter say what they did: "Opened Quillpad", "Pressed ⇧⌘ 4", "Ran <name>".
  - Failures: "<Action> didn't run" / "<Action> can't run here" plus the reason, with no mark. The struck mark is for touches only.
- **Timings BRIEF doesn't give:** taps, swipes and rejections stay 1.6 s. Every fade is 200 ms. A slide or hold whose end never arrives goes after 130 s.
- **Test Mode with a level change and no system indicator:** the level plate wins (one plate per zone; bone 8).
- **Dry-run holds** use the binding's `keys`, since `wouldRun` carries no outcome. The release comes from the later `recognized(.longPress, .ended/.cancelled)`.
- **Screens:**
  - Plates other than the level plate go on `NSScreen.main` (the key window's screen).
  - The level plate matches `localizedName` to the outcome's display name and falls back to the main screen.
- The feed is pumped by a 30 Hz main-run-loop timer: it calls `takeDecisions()` and steps the fades.

## Needs Gabriel
- Plates over real wallpapers and documents, light and dark (material, and the 0.92 tint).
- That the panels never take focus while typing, and that the display check takes clicks without activating Edgy.
- Docking on a real two-display setup: the level plate on the monitor being dimmed.
- The display check on the Mac mini's third-party monitor (batch 13's "Needs Gabriel").

## Open questions / for the chief
1. **Wiring (EdgyApp):**
   - `let overlay = OverlayController(model: model); overlay.start()`
   - `menuBar.onOverlayVisibleChange = { overlay.showsTestModePlates = $0 }`
   - Keep `start()` running whether or not Test Mode is on, because the level plate and display check show either way.
2. **`RejectionMeasure` has no variant field.** Adding one (e.g. `variant: palmMinor | edgeOutward | edgeDiagonal | swipeVeered | swipeSlow | swipeShort`) would remove the limit-matching above. It's a frozen-contract change.
3. **App names:** `PlateContext.current(model:)` falls back to the bundle ID's last part. If `SettingsModel` grows a name cache (`installedApps` is async), pass it as `appNames`.
4. **Skeleton shots:** `SkeletonTests` rewrites `docs/design/build-shots/skeleton/plate-*.png` because the plate now draws for real. I restored those files after every run (outside my glob). Regenerate them on `main`.
5. **Chief's rule (ordinary pointer touches are never shown):** it holds. Plates come only from decisions, never from touch frames, and the `plainTouchesNeverMakeAPlate` test locks it in.
