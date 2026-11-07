# Blockers / notes for the chief — batch 24 (EDGY-ONBOARDING-2)

Neither of these stopped the batch. Each needs a file outside my glob.

1. **A cream rim on the rejected mark?**
   - Ruling 3 says the step-2 plate comes "with its cream rim".
   - Bone 9 puts the 1 pt `contactRim` on *filled or dry-run* contacts only. Batch 23's `PlateView` draws the rejected mark (bone 4's hollow struck circle, `plateInk2`) without a rim.
   - Onboarding reuses `PlateView` unchanged (one component), so it matches the overlay today. Its 0.5 pt cream edge is drawn.
   - If the struck circle should take the rim too, change `Sources/EdgyUI/Overlay/PlateView.swift` (`markShape`, `.rejected`). It would apply to the overlay as well.
2. **An exact decision baseline.**
   - Step 2 counts only decisions that arrive after it opens. `SettingsModel.recentDecisions` is a capped rolling suffix with no serial number, so onboarding infers the new ones from the overlap with what it last read (`OnboardingState.newDecisions(seen:current:)`).
   - It never over-counts. In theory it can miss a new decision that exactly repeats a full window of 32 old ones.
   - **Ask (frozen model):** a monotonic `public private(set) var decisionSerial: Int`, bumped by the count in `receive(_:)`. Onboarding would then take `recentDecisions.suffix(serial - baselineSerial)`.
