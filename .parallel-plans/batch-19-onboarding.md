# Batch 19 — EDGY-ONBOARDING: the four steps

Read the v0.5 shared brief, the stage-2 brief, `docs/BRIEF.md` § Design in full (§ Surfaces C, § Onboarding), renders C, S6, S7, and `done-batch-13.md` (presets, `MachineDefaults`).

## Build
1. **`OnboardingView`** — 640 × 520 glass window content, step row ("1 Accessibility ✓  2 Try it  3 Pick a preset  4 Launch at login"; done steps ✓, current semibold), one 26 pt headline, at most one body sentence, the round primary bottom-right (the only chunky round control), Back as a quiet text button.
   - Step 1 per BRIEF (live permission flip via an injected checker protocol; Open Settings via a closure; Skip for now).
   - Step 2 "Rest a finger on the right edge and slide up": `PadMirrorView` live + the system volume indicator beside it (the system draws it; Edgy doesn't repeat the number); Continue enables after a recognized right-edge slide from the feed.
   - Step 3 "Pick a starting point": three radio rows with 120 pt `MiniMirrorView`s of each preset (Media preselected); choosing applies the preset through batch 13's editor API (after `MachineDefaults`).
   - Step 4: Launch at login switch (on by default here), Done calls the finish closure.
2. **`OnboardingController`** per the stage-2 brief.

## Acceptance
- Snapshots (light + dark) in `build-shots/batch-19/`: each step, step 1 granted, step 2 after a simulated slide, step 3 each selection.
- ≥ 12 tests: step flow + Back; permission flip; Continue gating on the feed; preset applied (one undo step) and machine-adjusted; launch-at-login written; finish closure called once.
- Bones checklist + reader-first review vs C, S6, S7; token greps clean; verification triple + denylist.
