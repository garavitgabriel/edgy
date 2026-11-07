---
batch: 26
tag: EDGY-SWITCHER
branch: worktree-edgy-switcher
worktree_path: /Users/gabrielgaravit/Projects/edgy/.claude/worktrees/edgy-switcher
completed_at: 2026-11-07
verification: pass
---

## Acceptance criteria
- [✓] The switcher opens on earned travel: a fresh `.began` arms a session and presses nothing. One `stepMM` (default 8 mm) of travel in either direction opens it: command down + exactly one tab. That step is consumed, and `position` 0 is still the app after the frontmost.
- [✓] `.ended` / `.cancelled` on an armed, unopened session is a silent no-op: no key events, no command-up. It logs at debug: "switcher: stroke ended before opening".
- [✓] Keep-open path unchanged: a `.began` while a session lingers continues it with no tab.
- [✓] The outcome (`systemHUDShown`), the `actionFired` haptic and the watchdog start when it opens. End stepping (`atEnd`) never opens it.
- [✓] Command is never left down: every release path holds. Unopened sessions press nothing, so they release nothing.
- [✓] Copy: the Switch Apps `stepMM` helper now reads exactly "Slide this far to open the switcher and move one app." Slide to Repeat Keys keeps its own line (pinned by a test). `docs/settings-reference.md` says the switcher opens after one step of travel.
- [✓] `scripts/smoke-actions.sh` step 34 runs four parts: rest 1.5 s, tap (cancelled after 40 ms) and a 5 mm nudge should open nothing; one 8 mm step should open on the next app. Steps 19 and 29 were adjusted so they still do what their prompts say. The script's Swift typechecks against the built modules (`swiftc -typecheck`); it has not been run.
- [✓] Mock keyboard only (hard rule 1).
- [✓] Nothing changed outside the owned paths: `Sources/Actions/**`, `Tests/ActionsTests/**`, `scripts/smoke-actions.sh`, `docs/settings-reference.md`, plus this report.

## Verification
- `swift build`: `Build complete!`
- `swift test`: exit 0. Every target passes: 56, 7, 134, 388, 250, 19, 57, **303 Actions** (was 289; 14 new).
- `swift format lint --strict -r Sources Tests Package.swift`: exit 0, no output.
- `git grep -niE -f ~/.config/edgy-names-denylist`: no output.
- `swift test` regenerates some EdgyUI snapshot PNGs under `docs/design/build-shots/` (batches 19, 21, 22). They are outside this batch's glob, so I restored them with `git checkout` and did not commit them. See Open questions.

## New tests — `Tests/ActionsTests/SwitcherOpensOnTravelTests.swift`
| Test | Before (batch 20) | After (batch 26) |
|---|---|---|
| `aRestingFingerOpensNothing` | `.began` → `cmd down, cmd+tab`; after 10 s the watchdog sent escape + cmd up | no key events, no watchdog, no haptic |
| `travelShortOfAStepThenLiftingPressesNothing` (keep-open 400 and 0) | opened, then lingered / selected | no key events, no command-up, input monitor never started |
| `beganThenCancelledFortyMillisecondsLaterPressesNothing` | opened, then lingered with command down (the logged misfire) | nothing |
| `oneStepOfTravelOpensOnTheNextApp` | opened at `.began`; 8 mm = one more app | 7 mm: nothing; the 8th mm: exactly `cmd down, cmd+tab down, cmd+tab up` |
| `twoStepsOpenAndMoveOneApp` (frame by frame and in one update) | open + 2 tabs | open + 1 tab |
| `slidingBackOneStepAfterOpeningCancels` | — | open, then −8 mm → escape, cmd up |
| `backwardTravelOpensItToo` | a backward first step cancelled | −8 mm opens (on the next app); a further −8 mm cancels; a single −24 mm update only opens (no same-frame cancel) |
| `endSteppingWithoutAStepOfTravelOpensNothing` | — | 2 s at the end with 0 mm, and with 5 mm: nothing |
| `aBeganWhileLingeringContinuesWithNoTab` | same | same (keep-open path unchanged) |
| `hapticOutcomeAndWatchdogComeOnlyWithTheOpening` | outcome on `.began`, watchdog on `.began` | `nil` outcome, no haptic, no watchdog until the opening step. Then `systemHUDShown`, one `actionFired` click and a 10 s watchdog. Later steps tick |
| `theOpeningClickFollowsTheHapticSettings` | — | `actionFired` turned off → no click on opening |
| `speedUpNeverShortensTheOpening` | — | 400 mm/s with speed-up on: 6.66 mm → nothing, 9.99 mm → opens |
| `anUnopenedStrokeReplacedByANewOnePressesNothing` | a stale `.began` cancelled an open session | an armed stroke is replaced silently and its travel doesn't carry over |
| `theCatalogSaysTheSwitcherOpensAfterOneStep` | "Slide this far to move one app." | exact new copy; Repeat Keys' line differs |

## Existing tests edited (none deleted, none weakened)
Every edited assertion keeps the old line as a comment naming the batch 26 ruling.

| Test | Change | Why |
|---|---|---|
| `AppSwitcherTests.fullLifecycle` | asserts `.began` → no events (old assertion commented), then a 0.1 step opens; the rest is unchanged | opening moved to the first step |
| `AppSwitcherTests.cancelSendsEscapeThenReleases`, `newBeganWithoutEndCancelsTheOldSessionFirst` | a 0.1 step after each `.began`; same expected events | the session must be open for there to be anything to cancel |
| `AppSwitcherTests.errorMidSlideReleasesTheModifier` | 0.2 forward instead of 0.1 | the first step is the opening, so one app forward takes two |
| `AppSwitcherTests.errorOpeningTheSwitcherReleasesTheModifier`, `commandFailingToGoDownLeavesNoSession` | `#expect(throws:)` moved from `.began` to the first step; same events | keys are pressed at the first step |
| `AppSwitcherTests.stepAndSensitivityScaleTravel` | 3 → 2 tabs | of the two steps, one is the opening (still proves sensitivity: without it, one tab) |
| `AppSwitcherTests.oneTickPerTab` | ticks 3 → 2, plus `strongTicks == 1` and 3 tabs | the opening step plays `actionFired`; the other two each tick |
| `SwitcherWatchdogTests` (all 4) | a 0.1 step after `.began`; `idleSession…` also asserts no watchdog before opening | the watchdog arms only when the switcher opens |
| `OutcomeTests.appSwitcherReportsNoLevelAndTheSystemUI` | `.began` → `nil`; the 0.1 step → `systemHUDShown` | the outcome comes with the opening |
| `SwitcherKeepOpenTests` first strokes of 9 mm → 17 mm (8 tests, each marked "was 9") | same expected events | 17 mm = 8 to open + 8 for one app + 1 carry, exactly the old 9 mm after a `.began` that opened |
| `SwitcherKeepOpenTests.shortStrokesWalkThroughManyApps` | first stroke 13 mm | otherwise the 5 mm first stroke never opens (by design) |
| `SwitcherKeepOpenTests.aBackwardFirstStepCancels` | +9 mm then −9 mm; same expected events | backward travel now opens. The intent kept: one step back from where it opened cancels |
| `SwitcherKeepOpenTests.theWatchdogStillCancels…`, `aLateInterruptCannotEndANewerSession` | 9 mm after `.began` | needs an open session |
| `SwitcherKeepOpenTests.eachAppTicksAndAWrapClicks` | 25 mm; strongTicks 1 → 2 | 8 mm more to still reach the wrap; the opening clicks too |
| `SwitcherKeepOpenTests.restingAtTheEnd…` | 17 mm; strongTicks 1 → 2 | same tab count (12); the opening click plus the end-stepping click |
| `SwitcherKeepOpenTests.aQuickFlickSkipsSeveralApps` | both open with a slow 8 mm, pause, then the same 12 frames | the 4 mm slow stroke alone would never open; slow = 1 tab, quick > 6 as before |

## Diff summary
- `ActionRegistry+Keys.swift`:
  - `SwitcherSession.opened`.
  - `armSwitcher`: on `.began`, checks parameters, bumps the generation and arms. A stale session is ended first; an armed one ends silently.
  - `openSwitcher`: on the first whole step. Command goes down; if that fails, the session is dropped and the rest of the gesture does nothing. Then `opened = true`, the tab (a failure releases command), and the `actionFired` click.
  - `switcherTravel`:
    - While armed, it skips end reports and counts travel 1:1 (speed-up off until open).
    - On the opening update it consumes one step and keeps only forward extras.
    - It returns whether this update opened the switcher.
  - `strokeEnded`: an unopened session is dropped, with the debug log.
  - `endSwitcher` presses nothing for an unopened session.
  - The watchdog arms and fires only for an open session.
  - `performSwitcher` returns whether the switcher was showing.
- `ActionRegistry.performReporting`: the switcher returns `ActionOutcome(systemHUDShown: true)` only while showing, else `nil`.
- `ActionCatalog`: the new helper copy and comment.
- `docs/settings-reference.md`: the helper row and the switcher session paragraph.
- `scripts/smoke-actions.sh`: new step 34, plus steps 19 and 29 adjusted.

## Decisions I made (and why)
- **Backward travel opens too, on the next app** (the brief's "either direction" read literally). A further step back cancels, as before. A single update that jumps more than one step backward only opens: cancelling in the same frame would only flash the switcher. This changes `aBackwardFirstStepCancels`' input (above).
- **Travel while armed counts 1:1** (no speed-up), so a flick can't open on less than one `stepMM`. The speed is still tracked, so speed-up is right from the first step after opening. Speed-up is off by default for the switcher.
- **An armed stroke that ends drops its travel.** Strokes shorter than a step never add up to an opening, otherwise repeated touches could still open it. Once open, the carry between strokes works as before.
- **The opening's haptic is `actionFired` (strong click)**, played by the registry through the same settings gate as `feedback(.actionFired)`. The Router only plays `actionFired` for triggers. The opening step gets no extra slide tick.
- **The generation is bumped when the session arms**, not when it opens. That keeps a late linger or watchdog from an earlier session out of the new one.

## Needs Gabriel
- Run `scripts/smoke-actions.sh` step 34 (and 19, 29 to confirm they still read right).
- On the MacBook top edge: rest a finger there, tap it, nudge it: nothing should open. Then slide about 8 mm: it should open on the next app. Is 8 mm the right amount to open, or should the opening take more than later steps?

## Open questions / for the chief
1. **Router (outside this glob) still reports at `.began`.**
   - `Router.route` plays `gestureCaught` (a tick) on every slide `.began`, so a resting finger on the switcher edge still ticks once, even though nothing opens.
   - It emits `actionRan(outcome: nil)` on `.began`. The opening update then arrives as `actionUpdated(systemHUDShown: true)`.
   - If the feed or haptics must be fully silent until the switcher opens, the Router needs a change (e.g. defer a switcher's first report until an outcome is non-nil).
2. **Snapshot drift.** `swift test` rewrote `docs/design/build-shots/batch-22/inspector-switch-apps-keep-open-off-*.png`, presumably from the catalog's new helper copy. Batches 19/21 shots also changed, which looks like rendering noise. I didn't commit them (outside the glob); the chief may want to regenerate them on `main`.
3. EdgyUI tests (`ParameterPresentationTests`, `Batch15SnapshotTests`) build their own descriptor with the old line "Slide this far to move one app." They don't read the catalog, so they pass. Update them if they should mirror the catalog.
