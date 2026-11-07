# Blockers / notes for the chief — batch 19 (EDGY-ONBOARDING)

None of these stopped the batch. Each needs a file outside my glob.

1. **The decision feed has one consumer channel.** Step 2's gate reads `model.pendingDecisions` without taking them (`OnboardingState.watchDecisions`, an observation hop to the next main-actor turn). If batch 18's `OverlayController` drains `takeDecisions()` synchronously on every change while onboarding is open, the onboarding read can see an empty array and miss the slide.
   - **Ask (model, frozen):** a non-consuming signal on `SettingsModel`, e.g. `public private(set) var decisionCount` or `lastDecisions` (the latest delivery), bumped in `receive(_:)`. Onboarding would switch to it in one line.
   - **Or (EdgyApp wiring):** don't run the overlay's drain while the onboarding window is open (Test Mode is off then; the level plate is the only overlay use).
2. **`PadMirrorView` has a fixed 3.7 pt/mm** (592 × 426 pt for a 160 × 115 mm pad), too big for the 640 × 520 window, and `.scaleEffect` would take its labels under 13 pt. Onboarding draws the same `MirrorPad` at a fitted scale (`OnboardingMirror`, about 2.3 pt/mm). A `PadMirrorView(model:pointsPerMM:)` init in the Mirror folder would let onboarding compose it by name.
3. **EdgyApp wiring** (for the chief):
   ```swift
   let onboarding = OnboardingController(
     model: model,
     actions: OnboardingActions(
       openAccessibilitySettings: { AccessibilitySettings.open(logger: logger) },
       finish: { /* mark onboarding done */ menuBar.showPopover() }),
     permissions: AccessibilityPermissionChecker())
   onboarding.show()
   // on NSApplication.didBecomeActiveNotification: onboarding.refreshPermission()
   ```
   Closing the window early does not call `finish` (onboarding stays undone, so the app can show it again next launch). Decide whether that's what you want.
4. **Onboarding rejection feedback (bone 9: one plate component for the overlay and onboarding feedback).** Step 2 shows no Edgy plate for a recognized slide (bone 8: the system's volume indicator carries it). A rejected touch on the right edge could show the shared `PlateView` with "Ignored: …", but the copy formatter belongs to batch 18 and `PlateView`'s drawing isn't on `main` yet. After 18 merges, it's a few lines in `OnboardingView`'s step-2 content.
