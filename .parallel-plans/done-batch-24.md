---
batch: 24
tag: EDGY-ONBOARDING-2
branch: worktree-edgy-onboarding2
worktree_path: /Users/gabrielgaravit/Projects/edgy/.claude/worktrees/edgy-onboarding2
completed_at: 2026-11-07
verification: swift build ✓ · swift test ✓ (exit 0; EdgyUITests 349 tests in 32 suites) · swift format lint --strict ✓ · token greps empty · denylist empty
---

# Done: batch 24, onboarding to critique 19

Shots: `docs/design/build-shots/batch-19/` (all 16 re-made from HEAD) and `docs/design/build-shots/batch-24/step2-rejected-{light,dark}.png` (new). Tests: `Tests/EdgyUITests/Onboarding/`.

## Acceptance criteria: critique 19, item by item

### Must fix
1. **[✓] Step 1 no longer clips labels.**
   - Fixed by ruling 1: the step-1 mirror draws no text at all (`OnboardingMirror(illustration: true)` passes `showsLabels: false` to `MirrorPad`).
   - "Mic (", "Mute" and "Brightne" are gone, and so is every other tab.
   - Shots: `batch-19/step1-accessibility-*`, `step1-granted-*`.

### Should fix
1. **[✓] Steps 1 and 2 share one scale.**
   - There's one box, `OnboardingMetrics.mirrorBox` (360 × 230). `OnboardingMirror.pointsPerMM(for:)` is the only scale either step uses.
   - For the 160 × 115 mm pad that's **2.0 pt/mm** (320 × 230 pt) on both steps. **Correction:** batch 19's "about 2.3 pt/mm" note was wrong; step 1 was actually about 1.86 and step 2 about 2.27.
   - Test: `stepsOneAndTwoShareOneScale`. Shots: `step1-*` vs `step2-*` (the mirror is 320 pt wide in all of them, at x 160–480).
2. **[✓] The bottom label no longer overflows its bar on step 1.** Resolved by ruling 1: step 1 has no in-bar text. Step 2's only label is the "Volume" side tab. Shots: `step1-*`.
3. **[✓] The corner tabs on step 1 are no longer off their tiles.** Resolved by ruling 1: there are no corner tabs. The mapped corners are solid tiles with their icons (mic, mute). Shots: `step1-*`.
4. **[✓] The step 4 switch is right-aligned to Done.** The row is full width now (the fixed 380 pt frame is gone), so the switch's right edge sits at 608 pt, the same as Done's. Shots: `step4-launch-at-login-*`.
5. **[✓] Step 3 rows have room.**
   - `presetRowPadding` went from 5 to 8. The mini mirrors are now about 16 pt apart (they were about 6), and the selected outline sits 8 pt from the mini's top.
   - To fit it, the note-to-Back gap went from 18 to 10.
   - Shots: `step3-media-*`, `step3-windows-*`, `step3-minimal-*`.

### Rulings (design answers 1–5)
1. **[✓] Step 1 mirror: zone shapes and corner icons only, no text.** Shots: `step1-accessibility-*`, `step1-granted-*`.
2. **[✓] Step 2 Continue is always enabled; a landed slide only adds the ✓.**
   - `canContinue` is always true now.
   - `isDone(.tryIt)` is `slideRecognized`. Continuing without a slide leaves "2" unchecked, the same rule as Skip for now on step 1.
   - Tests: `continueIsAlwaysEnabledOnTryIt` (with and without a trackpad), `theCheckMarkWaitsForARecognizedRightEdgeSlideFromTheFeed`, `theCheckMarkStaysAfterGoingBack`.
   - Shots: `step2-try-it-*` (Continue at full strength, "2" current) and `step2-after-slide-*` (✓ on Try it).
3. **[✓] A rejected slide on step 2 shows the struck contact plus the one dark plate.**
   - The plate reuses batch 23's code unchanged: `PlateContent.from(_:catalog:context:)` with `PlateContext.current(model:)`, drawn by `PlateView`.
   - The copy is word for word: "Ignored: swipe too short, 4 mm, needs 6 mm".
   - The struck contact is `MirrorPad`'s own rejected mark, at the touch on the right edge.
   - Only right-edge rejections that have plate copy show (so `startedOutsideZone` never does). A landed slide clears the plate, and so does leaving the step.
   - Tests: `aRejectedRightEdgeSlideShowsTheIgnoredPlate`, `onlyRightEdgeRejectionsOnTryItShowAPlate`. Shot: **`batch-24/step2-rejected-*`**.
4. **[✓] The system volume indicator appears wherever the system draws it.** The window stays where it is (`window.center()`), and step 2 draws no level of its own (bone 8). The headless shots can't show the system indicator; see Needs Gabriel.
5. **[✓] The step 4 switch colour goes to the G1 device check.** It's listed under Needs Gabriel.

### Fix list 2: decisions count only after step 2 opens
**[✓]**
- Onboarding still reads `model.recentDecisions` and never calls `takeDecisions()`. Test: `pendingDecisions.count == 4` in `theCheckMarkWaits…`.
- `start()` no longer feeds the decisions already there. Instead, every `go(to: .tryIt)` records a baseline (`seenDecisions`).
- `recentDecisions` is a capped rolling suffix of 32, so a count baseline would break once it wraps. `OnboardingState.newDecisions(seen:current:)` takes what follows the longest overlap between what was seen and the current array.
- When that overlap is ambiguous, it errs toward fewer new decisions, so nothing from before the baseline is ever counted.
- `receive(_:)` ignores everything unless step 2 is the current step.
- Tests: `slidesBeforeTryItOpensDoNotCount`, `theBaselineSurvivesTheCappedFeed` (more than 32 decisions on each side of the baseline), `newDecisionsFollowTheOverlapWithWhatWasSeen`.

## Verification (run in this transcript, after the last code change)

```
swift build                                              → Build complete!
swift test                                               → exit 0 (56, 7, 134, 349 EdgyUI, 250, 19, 57, 289 — all passed)
swift format lint --strict -r Sources Tests Package.swift → exit 0, no output
colour-literal grep over Sources/EdgyUI (minus Tokens)   → no output
.system(size: / Font.system(size: / .custom( grep         → no output
second hue / accentColor grep, Onboarding               → no output
Unicode arrows / emoji, Onboarding                      → no output
git grep -niE -f ~/.config/edgy-names-denylist           → no output (exit 1)
```

`swift test` also rewrites `build-shots/batch-21/inspector-long-labels-*` and `build-shots/skeleton/plate-*`, which are outside my glob. I restored both with `git checkout` before every commit. Nothing outside the batch-24 glob is in this branch's diff.

## Bones checklist

1. **The mirror is the pad.**
   - [x] To scale, at one constant scale shared by steps 1 and 2: `step1-*` and `step2-*`, plus `stepsOneAndTwoShareOneScale`.
   - [x] No rulers: every shot.
2. **Zone states by shape.**
   - [x] Mapped bar, hairline, mapped tile with icon, dashed pass-through: `step1-accessibility`.
   - [x] Live = accent contact + accent border on the lit bar: `step2-after-slide`.
   - [x] Only zone touches are drawn: the rejected touch is on the mapped right edge (`step2-rejected`).
   - [x] Selection ring: n/a (onboarding selects nothing).
3. **Labels.**
   - [x] Step 1 has no labels (ruling 1), so nothing can clip.
   - [x] Step 2's "Volume" is a tab joined to its strip at 13 pt: `step2-*`.
   - [x] The minis drop labels and icons: `step3-*`.
4. **Recognized vs rejected by shape.**
   - [x] Recognized = filled accent contact: `step2-after-slide`.
   - [x] Rejected = hollow struck circle, on the mirror and on the plate, with bone 4's copy: `batch-24/step2-rejected` (left unticked in batch 19, done now).
5. Map on the pad: n/a.
6. Inspector: n/a.
7. Interaction notes: n/a.
8. **Each status said once.**
   - [x] A landed slide draws nothing beside the mirror; the system indicator carries the level (`step2-after-slide`).
   - [x] Step 2's state is said by the ✓ only.
9. **One plate component.**
   - [x] The onboarding feedback is batch 23's `PlateView`, unchanged: the same dark espresso plate in light and dark, the same radius and inset, 13 pt text, the 0.5 pt edge (`step2-rejected-light` vs `-dark`).
10. The popover: n/a.

**BRIEF § Onboarding:**
- [x] Headlines and body unchanged, word for word.
- [x] One round primary.
- [x] Quiet Back and Skip for now.
- [x] Step 2 extras per the spec: Continue always enabled, ✓ on a landed slide, the struck contact plus one dark plate, the volume indicator wherever the system draws it.

**Kill list:** no tabs or text on step 1, no glow or halo, no second hue, no arrows or emoji, no rulers, no hero numerals, no third-party names. ✓

## Reader-first review

- **Step 2 vs C (`step2-try-it`, `step2-after-slide`, `step2-rejected`).**
  - Matches:
    - the step row;
    - the headline;
    - only the right edge is solid;
    - the lit bar and Volume tab with the accent contact;
    - Continue is the dark capsule at full strength before any slide, as in C.
  - Differs:
    - The pad is smaller than C's: 320 pt at 2.0 pt/mm, so steps 1 and 2 can share a scale and step 2 keeps room for the plate. It's still at true proportion.
    - The plate sits **under** the mirror, its right edge flush with the mirror's (the touched edge). "Beside" in the horizontal sense doesn't fit: the plate is about 347 pt wide, and the mirror plus the plate need about 680 pt against a 576 pt content column. The slot is always reserved and the plate hangs from a zero-width anchor, so the mirror never moves when it appears. Both shots have the mirror at x 160–480.
- **Step 1 vs S6 (`step1-*`).** It matches S6's text-free mirror: tiles with mic and mute icons, solid bars, dashed bottom corners, no tabs. The body copy is BRIEF's.
- **Step 3 vs S7 (`step3-*`).** The rows breathe now: 8 pt inside each row and about 16 pt between minis. It's still a little denser than S7, because the minis are to scale (86 pt tall).
- **Step 4 (`step4-*`).** The switch is flush with Done's right edge.

## Diff summary

- `OnboardingState.swift`:
  - `canContinue` is always true, and `isDone(.tryIt)` = `slideRecognized`;
  - new `rejection: PlateContent?`;
  - the step-2 baseline: `seenDecisions`, `newDecisions(seen:current:)`, `readNewDecisions()`;
  - `receive` counts only on step 2;
  - removed the dead `hasTaughtSlide`.
- `OnboardingParts.swift`:
  - the shared `mirrorBox`, plus `plateGap` and `plateSlotHeight`;
  - `OnboardingMirror(illustration:onlyTaughtZone:)` with a static `pointsPerMM(for:)` and `sensorSize(_:)`;
  - the preset row padding is 8 and the row spacing 0, plus a new `noteGap`;
  - the switch row width constant is gone.
- `OnboardingView.swift`:
  - step 1 draws the illustration mirror;
  - step 2 is the mirror plus the plate slot;
  - the step 4 row is full width;
  - new `OnboardingMotion.plate`, a 200 ms fade.
- Tests:
  - re-aimed: `continueWaits…` → `theCheckMarkWaits…`, `withoutATrackpad…` → `continueIsAlwaysEnabledOnTryIt`, `theGateStaysOpen…` → `theCheckMarkStays…`;
  - new: the baseline (3 tests), the plate (2), the shared scale (1), and the `step2RejectedSlide` snapshot;
  - 28 onboarding tests in all.

## Decisions I made (and why)

1. **Tests re-aimed, not weakened.** The three gate tests asserted the Continue gate that ruling 2 removes.
   - Each keeps its intent (right-edge slides only, read but not taken, sticky across Back, never trapped without a trackpad), now checked through the ✓ and an always-enabled Continue.
   - `theGateCountsSlidesOnTheRightEdgeOnly` is unchanged.
2. **✓ on step 2 means a slide landed.** Continuing without one leaves "2" unchecked, matching how step 1 treats Skip for now.
3. **The plate goes under the mirror, right-aligned to the touched edge.** "Beside" horizontally would need the mirror at about 200 pt; see the reader-first review.
4. **The plate shows only right-edge rejections.** Step 2 maps only that edge, so a struck contact elsewhere isn't drawn, and a plate without its contact would float.
5. **The plate has no timed fade.** It stays until a slide lands or the step closes. It's a teaching step, and the overlay's timeline isn't needed here.
6. **The cream rim.** Bone 9 puts the rim on *filled or dry-run* contacts. The rejected mark is bone 4's hollow struck circle in `plateInk2`, and batch 23's `PlateView` draws it without a rim. I reused the component unchanged rather than fork its marks; the cream 0.5 pt plate edge is drawn. See Open questions.
7. **The baseline is taken on every entry to step 2.** Going Back and returning doesn't re-count old decisions, and a ✓ already earned stays.

## Needs Gabriel (human-only)

- The system volume indicator next to the window on a real slide, wherever the system draws it (ruling 4).
- The step 4 switch tint when ON at the G1 device check (ruling 5).
- A real too-short slide on the right edge, to check that the plate and the struck contact appear and that the plate goes after a good slide.
- The 2.0 pt/mm mirror at real size: does it still read as the pad?

## Open questions

1. **BRIEF line 372** says "steps 1–3 may use a fitted scale, but one scale for all of them", but step 3's minis are specced at 120 pt. I followed the batch brief (steps 1–2 share a scale; the step 3 minis stay at 120 pt). The BRIEF wording may need "steps 1–2".
2. **The rim on the rejected mark:** ruling 3 says "with its cream rim". If that means a rim on the struck circle too, it's a change in `Overlay/PlateView` (not my glob), and it would apply to the overlay as well.
3. **An exact decision baseline:** `recentDecisions` has no serial number, so the overlap match can, in theory, miss a new decision that exactly repeats a full window of 32 old ones. It never over-counts. A monotonic `decisionSerial` on `SettingsModel` (frozen) would make the baseline exact.
