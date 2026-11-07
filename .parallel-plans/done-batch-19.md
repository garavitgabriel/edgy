---
batch: 19
tag: EDGY-ONBOARDING
branch: worktree-edgy-onboarding
worktree_path: ~/Projects/edgy/.claude/worktrees/edgy-onboarding
completed_at: 2026-11-07
verification: swift build ✓ · swift test ✓ (exit 0; EdgyUITests 250 tests in 34 suites) · swift format lint --strict ✓ · token greps empty · denylist empty
---

# Done: batch 19, the four onboarding steps

## Acceptance criteria

| Criterion | Status | Evidence |
|---|---|---|
| `OnboardingView`: 640 × 520 glass content, step row (done ✓, current semibold), one 26 pt headline, ≤ 1 body sentence, round primary bottom-right, quiet Back | ✓ | `OnboardingView.swift`, `OnboardingParts.swift`; every shot |
| Step 1: live permission flip via an injected checker; Open Settings via a closure; Skip for now | ✓ | `OnboardingController(… permissions: PermissionChecking, scheduler:)` drives a `PermissionMonitor`; tests `permissionFlipsLiveFromTheChecker`, `opensOnAccessibilityWithOpenSettingsAndSkip`, `skipForNowContinuesWithoutAccess`; shots `step1-accessibility`, `step1-granted` |
| Step 2: live mirror, system volume indicator beside it (system-drawn), Continue after a recognized right-edge slide from the feed | ✓ | `OnboardingMirror` (live touches); tests `continueWaitsForARecognizedRightEdgeSlideFromTheFeed`, `theGateCountsSlidesOnTheRightEdgeOnly`, `theGateStaysOpenAfterGoingBack`, `withoutATrackpadTryItDoesNotTrapTheUser`; shots `step2-try-it` (Continue dimmed), `step2-after-slide` |
| Step 3: three radio rows with 120 pt `PresetMirrorView`s, Media preselected, applied through `applyPreset` (after `MachineDefaults`) | ✓ | tests `choosingAPresetAppliesItAndTheStepIsOneUndoStep`, `continueAppliesThePreselectedMedia`, `thePresetIsAdjustedToThisMac`; shots `step3-media`, `step3-windows`, `step3-minimal` |
| Step 4: launch-at-login switch on by default; Done calls the finish closure | ✓ | tests `doneWritesLaunchAtLoginOnByDefault`, `doneWritesLaunchAtLoginOffWhenSwitchedOff`, `finishIsCalledOnceAndClosesFirst`; shot `step4-launch-at-login` |
| `OnboardingController` (`init(model:actions:)`, `show()`): the 640 × 520 glass window; finishes through a closure | ✓ | `OnboardingController.swift` (extra init parameters are defaulted); test `closingEarlyDoesNotFinishAndEndsThePresetEdit` |
| Snapshots light + dark: each step, step 1 granted, step 2 after a simulated slide, step 3 each selection | ✓ | `docs/design/build-shots/batch-19/` — 8 states × light/dark = 16 PNGs |
| ≥ 12 tests | ✓ | 15 flow tests (`OnboardingTests.swift`) + 6 snapshot tests (8 cases) |
| Bones checklist, reader-first review vs C, S6, S7, token greps, triple + denylist | ✓ | below |

## Verification (run in this session, after the last code change)

```
swift build                                              → Build complete!
swift test                                               → exit 0; every suite passed (EdgyUITests: 250 tests in 34 suites)
swift format lint --strict -r Sources Tests Package.swift → exit 0, no output
colour / font-size / .custom / second-hue greps (shared brief rule 7) → no output
Unicode arrows / emoji in Sources/EdgyUI/Onboarding      → no output (the check mark is SF Symbol "checkmark")
git grep -niE -f ~/.config/edgy-names-denylist           → no output
git diff --name-only main...HEAD outside the batch-19 glob → none
```

## Bones checklist

1. **The mirror is the pad.**
   - [x] To scale from the device's sensor size, in its orientation: `OnboardingMirror` fits `MirrorGeometry` into the step's box with one scale for both axes (`step1-*`, `step2-*`). Preset minis use the mirrored pad's size (`step3-*`).
   - [x] No rulers, dimension lines or mm callouts: every shot.
2. **Zone states by shape.**
   - [x] Mapped edge / unmapped hairline / mapped corner tile with icon / dashed pass-through corner: `step1-accessibility` (the Default profile, as in S6).
   - [x] Live = accent contact + thin accent border on the lit bar: `step2-after-slide`.
   - [x] Selection ring: n/a (onboarding selects no zone; clicks on the pad do nothing).
3. **Labels joined to their zone.**
   - [x] Tabs from the strip's inner side, in-bar bottom text, corner tabs, ≥ 13 pt (fitted scale keeps the mirror's 13 pt type, never scaled): `step1-*`, `step2-*` ("Volume").
   - [x] Minis under 200 pt drop labels and icons: `step3-*`.
4. **Recognized vs rejected by shape.**
   - [x] Recognized = filled accent contact: `step2-after-slide`.
   - [ ] Rejection plate in onboarding: not built. See blockers-batch-19.md item 4 (needs batch 18's copy and plate).
5. You map on the pad: n/a (no picker in onboarding).
6. The inspector: n/a.
7. Interaction notes: n/a.
8. **Each status said once.**
   - [x] Step 2 draws nothing beside the mirror; the system's volume indicator carries "64%" (`step2-after-slide`).
   - [x] Step 1's permission state is said once, in the body ("Access granted.") and the step row's check mark (`step1-granted`).
9. The overlay: n/a. (One plate component: onboarding doesn't draw a second plate style; see item 4.)
10. The popover: n/a. Done hands off to the app, which opens the popover once.

**Onboarding-specific rules (BRIEF § Onboarding):**
- [x] One 26 pt headline, one clause, no colon: all four headlines, word for word.
- [x] At most one body sentence: step 1 only, BRIEF's sentence (not S6's older two-sentence copy).
- [x] The round primary is the only chunky round control: `OnboardingPrimaryStyle`, a capsule at 17 pt semibold.
- [x] Back / Skip for now are quiet 13 pt `ink2` text buttons.
- [x] Step 4's switch is on by default and tinted with the accent (ON switches are the accent's job).

**Kill list:** no eyebrow micro-caps, no sidebar, no cards per zone, no glow, no emoji or Unicode arrows, no middot strings, no rulers, no hero numerals, no second hue, no third-party names. ✓

## Reader-first review (my shots next to the renders)

**Step 2 vs C (`step2-try-it`, `step2-after-slide`).**
- **Matches:**
  - The step row: a ✓ in a pale circle for Accessibility, "2 Try it" in a filled ink circle and semibold, outlined 3 and 4 in `ink2`.
  - The headline, word for word, at 26 semibold.
  - Only the right edge is solid; the other edges are hairlines and all four corners dashed, as in C.
  - The lit bar has the accent tint and border; "Volume" is a tab joined to the bar; the contact is a filled accent oval.
  - Back is quiet on the left; Continue is the dark round capsule on the right.
- **Differs:**
  - C's pad is wider than true proportion (about 1.6:1). Ours is to scale (160 × 115 mm, 1.39:1), so it is narrower (bone 1 wins).
  - The "Volume" tab sits at the middle of the bar, not near the top (batch 14's rule for 1–4 segments).
  - Before a slide, Continue is dimmed to 40% (C shows it after the slide).
  - The system volume indicator and the traffic lights are absent: the system draws both, and the headless shot has neither.

**Step 1 vs S6 (`step1-accessibility`, `step1-granted`).**
- **Matches:** step row with "1 Accessibility" current; headline word for word; the Default profile's pad with Mic off / Mute corner tiles and tabs, Brightness / Volume tabs and "Tracks and Play/Pause" in the bottom bar; "Skip for now" quiet on the left; "Open Settings" as the round primary.
- **Differs:**
  - Body copy is BRIEF's ("Edgy uses it to keep the pointer still…"). S6's two-sentence copy is out of date.
  - Granted: body "Access granted.", the step's circle becomes a check, the primary reads Continue, and Skip for now goes away (nothing left to skip). S6 doesn't draw this state.
  - Our side tabs sit mid-bar; S6 places Brightness high and Volume low (same batch 14 rule as above).

**Step 3 vs S7 (`step3-media`, `-windows`, `-minimal`).**
- **Matches:** three rows (radio, 120 pt mini, name semibold, one line in `ink2`), the selected row lifted with a hairline edge, "You can change any of it in Settings." above Back, Continue on the right.
- **Differs:**
  - The minis are to scale (86 pt tall at 120 pt wide), so rows are a little taller than S7's.
  - The selected row's lift is the window tint over the material. Headless shots render the material flat, so here it reads only as a hairline. On the device it should be lighter, as in S7.

**Step 4 (no render; BRIEF only).** Headline, one switch row "Open Edgy when you log in", Back + Done. The headless shot draws the switch in the system's inactive grey because the offscreen window is never key; on the device it takes `Tokens.accent`.

## Diff summary

- `Sources/EdgyUI/Onboarding/OnboardingState.swift`:
  - `OnboardingActions` (open the Accessibility pane, finish).
  - `OnboardingState` (`@Observable`): step, permission, slide gate, preset, launch at login, finish once.
  - `OnboardingCopy`.
- `Sources/EdgyUI/Onboarding/OnboardingView.swift`: the view. The frozen `init(model:)` is kept; `init(model:state:)` is added.
- `Sources/EdgyUI/Onboarding/OnboardingParts.swift`: `OnboardingMetrics`, step row, round primary and quiet button styles, `OnboardingMirror` (the shared `MirrorPad` at a fitted scale), `PresetRow`.
- `Sources/EdgyUI/Onboarding/OnboardingController.swift`: the window, `PermissionMonitor`, finish, close.
- `Tests/EdgyUITests/Onboarding/OnboardingTests.swift` (15) and `OnboardingSnapshotTests.swift` (6 functions, 8 cases).
- `docs/design/build-shots/batch-19/` (16 PNGs).

## Decisions I made (and why)

1. **Step 3's choices are one continuous edit.** Entering the step calls `beginContinuousEdit("onboarding.preset")`. Each radio click calls `applyPreset` right away. Leaving the step (Continue, Back, closing the window, Done) ends the edit. However many times the user changes their mind, it is **one undo step**. Continue applies the selection too, so a preselected Media is applied even if never clicked; on a config already equal to Media, that is a no-op.
2. **Step 2 draws only the taught zone as mapped** (render C). It is presentation only; the config isn't touched. Steps 1 and 3 show real zones.
3. **The mirror is drawn at a fitted scale** (`OnboardingMirror`, about 2.3 pt/mm) with the mirror's own `MirrorPad`. `PadMirrorView`'s fixed 3.7 pt/mm doesn't fit, and scaling it would take labels under 13 pt. See blockers item 2.
4. **Step 2 doesn't trap the user.** Continue also enables when no trackpad is attached, or when the Default profile has no right-edge slide.
5. **The gate counts** `recognized`, `actionRan`, `actionUpdated` or `wouldRun` for a slide on any segment of the right edge. It never calls `takeDecisions()`. It stays open after going Back.
6. **Step 1's ✓ means granted.** Skipping moves on but leaves "1" unchecked, because skipping isn't done. When access is granted, the controller brings the window back to the front.
7. **Launch at login is written on Done**, from the switch's value (on by default). It is not written as the switch toggles: the choice is made with Done.
8. **Finish:** Done ends the preset edit, writes launch at login, closes the window, then calls `actions.finish` exactly once. Closing the window early never calls `finish`.
9. **Feed:** `show()` starts the feed. Closing stops it, the same rule as the settings window controller. The popover starts it again when it opens.

## Needs Gabriel (human-only)

- The material and the selected preset row's lift over real wallpapers, light and dark.
- The round Continue's weight and size against render C at real size.
- The live permission flip end to end: Open Settings, grant, and the window comes back with the check.
- A real right-edge slide enabling Continue, with the system volume indicator beside the window.
- That the step-4 switch shows the accent when ON.

## Open questions

- See `.parallel-plans/blockers-batch-19.md`: decision-feed contention with the overlay; a `pointsPerMM` init on `PadMirrorView`; EdgyApp wiring; onboarding rejection plate after batch 18.
- Should an early close mark onboarding done? I chose no.
