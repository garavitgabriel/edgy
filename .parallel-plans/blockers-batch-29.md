# Blockers: batch 29

## Item 5: idle numbers with the popover open (blocked)

**Needed:** `scripts/measure-idle.sh 3 150` against **this branch's** build. Run it with the popover open, and again with Settings open on the Name and Icon popover, hands off the Mac.

**Why blocked:**
- The script measures the Edgy that is running. That is `build/Edgy.app` from main (pid 13280), not this branch.
- Measuring this branch means installing and launching its build in place of the running one. This session must never launch or quit Edgy.
- Opening the popover is a human action.

**What I could read (not valid for item 5):** a read-only run on 2026-11-09 against the running main build, window state unknown, gave **CPU 16.08%, 146 idle wakeups/s over 20 s**. `ioreg` HIDIdleTime read 0.7 s, so the Mac was in use. This is not an idle reading and not this build.

**Evidence that batch 29 adds no per-frame work:**
- Labels and zone icons are computed inside batch 28's `MirrorDataCache`, once per revision.
- App marks go through `AppIconCache`, off main.
- `MirrorAppPaths` looks up a bundle path once per bundle ID.
- The icon grid is built when the popover opens.
- Batch 28's `mirrorDataIsComputedOnceForManyBodyEvaluationsAtOneRevision` and `identicalFramesProduceNoObservationChange` pass.

**To unblock (chief or Gabriel):**
1. Merge or build this branch (`scripts/bundle.sh`) and launch it.
2. Open the popover and leave the Mac alone.
3. Run `scripts/measure-idle.sh 3 150`.
4. Repeat with Settings → a zone's "…" → Name and Icon… open.
5. Put the numbers in `done-batch-29.md` item 5.
