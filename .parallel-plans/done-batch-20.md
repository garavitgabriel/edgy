---
batch: 20
tag: EDGY-FEEL
branch: worktree-edgy-feel
worktree_path: /Users/gabrielgaravit/Projects/edgy/.claude/worktrees/edgy-feel
completed_at: 2026-11-07
verification: pass
---

## Acceptance criteria
- [✓] **≥ 35 new tests: 92 new test functions** (cases: Gestures 111 → 134, Actions 238 → 289, EdgyRuntime 232 → 250).
  - mm stepping identical across two pad sizes and segment counts: `SlideStepsFeelTests.millimetreStepsAreTheSameOnEveryPadAndSegment`, `travelInMillimetresIsTheSameOnTwoPadSizes`.
  - speed-up monotonic, gentle, capped: `SlideFeelModelTests` (gain 1 when slow, monotonic and continuous at 1 mm/s resolution, capped, levels gentler), `aQuickFlick…` tests on keys, switcher and levels.
  - end stepping rate, ease-in, stop: `SlideStepperTests.endStepping…` (steady rate over 2 s, first step at ≈0.32 s, stops on motion and eases in again, follows the end's sign, first step flagged), plus keys and switcher end stepping with the click.
  - switcher keep-open: `SwitcherKeepOpenTests` (21) — linger, continue within the window, ten short strokes walk 6 apps, select after the window, select on click, select on pointer move, Esc, interruption keeps open, slide-back cancels, backward first step cancels, watchdog, late timer / late interrupt can't end a newer session, keep-open 0 = old switcher, per-binding time, bad value, command always released over every exit, error while continuing releases, wrap click.
  - slideSteps migration from `step`: `aLegacyFractionStepIsConvertedWithTheZoneLength`, `stepMMWinsOverALegacyStep`, `withoutAMotionTheLegacyFractionBehaviourIsUnchanged`, `aLegacyStepIsNeverUnknown`.
  - level speed-up off = old behaviour exactly: `LevelSpeedUpTests.speedUpOffIsTheOldBehaviourExactly` (bit-identical to the no-motion path), plus no motion, slow slides, gentle cap, no end stepping on levels.
  - Gestures `zoneLengthMM` / `atEnd`: 10 tests in `SlideFeelGestureTests` (both ends, middle, no end without having moved, stops when moving away, band size, segment ends, short-segment cap).
  - per-zone hold time: three Gestures tests (edge, other zone keeps global, corners and slide zones) + `HoldTimeTests` (5) in the runtime.
  - hold survives foreign motion after begin and still cancels on palm/click: `edgeHoldSurvivesAnotherFingerPointingAfterItBegan`, `pointingBeforeTheHoldBeginsStillRevokesIt`, `beganHoldStillCancelsWhenTheHeldTouchBecomesAPalm`, `beganHoldStillCancelsOnAClick`, `beganHoldStillCancelsOnThreeContacts`, `aPalmRestingElsewhereLeavesABeganHoldAlone`.
  - pointer guard released after hold begins: `HoldPointerGuardTests` (4).
  - trace replays: `traceReplaysKeepTheBatchTwentyInvariants` (every recorded trace — none yet — plus the five committed synthetic fixtures, with a 300 ms hold context) and three new scenario labels in `RecordedTraces.expectations`.
- [✓] Existing tests unchanged in intent; every moved expectation is listed below with why.
- [✓] `docs/settings-reference.md` updated: every new parameter (table with BRIEF's labels, helper lines, units), the feel's numbers, `holdMS` on other long-presses, legacy `step`, `slideAndSwipes`.
- [✓] Verification triple green, denylist clean (below).
- [✓] Nothing outside the allowed glob changed (`git diff --name-only f23ffa8..HEAD`: `Sources/{Gestures,Actions,EdgyRuntime}`, their tests, `docs/settings-reference.md`, `scripts/{smoke-actions.sh,record-traces.md}`, `.parallel-plans/{done,blockers}-batch-20.md`).

## Verification
- `swift build`: `Build complete!`
- `swift test`: exit 0. Every target passes: 56, 7, **134 Gestures**, 47, **250 EdgyRuntime**, 19, 57, **289 Actions**.
- `swift format lint --strict -r Sources Tests Package.swift`: exit 0, no output.
- `git grep -niE -f ~/.config/edgy-names-denylist`: no output (exit 1).

## Existing tests edited (and why)
| Test | Change | Why |
|---|---|---|
| `AdversarialTests.thumbHoldingAPushToTalkCornerIsCancelledWhenAnotherFingerMoves` → `…SurvivesAnotherFingerMoving` | expects `[.began, .ended]` and no rejection instead of `[.began, .cancelled]` | The brief reverses exactly this: a hold that has begun survives another finger pointing. Same trace, same invariants (paired, ends unclaimed). |
| `AppSwitcherTests` (4 tests), `V04Tests.normalEndDisarms`, `staleFireCannotEndANewerSession` | pass `keepOpenMS: "0"` | They pin the one-stroke switcher, which is now `keepOpenMS` 0 (the default keeps the session open). Same expectations. |
| `AppSwitcherTests.errorMidSlideReleasesTheModifier` | one app forward before the failing shift-tab | A step back from the starting point now cancels (brief), so the failing shift-tab needs a step to go back from. Same intent: an error mid-slide releases command. |
| `CatalogTests.parameterSpecs` | new parameter lists (`stepMM`, `speedUp`, `keepOpenMS`, `holdMS`; levels gain `speedUp`) | The catalog changed by design; the test still pins every spec. |
| `HoldRoutingTests.normalLift`, `stopReleases`, `LiveFeedTests.turningTestModeOffMidHoldIsSafe` | `guardCalls == []` instead of `["engage", "release"]` | A begun hold no longer holds the pointer guard (brief item 4). The scripted claim starts in the same frame as the hold's `.began`, so the guard never engages. `HoldPointerGuardTests` covers the dwell-then-hold case (engage, then release at `.began`). |
| `ValidationTests.everyCodeIsReachable` | one more binding (a swipe on the slide's edge) | Reaches the new `slideAndSwipes` code. Strengthened, nothing removed. |
| `SettingsAuditTests.theReferenceDocumentsEverySettingAndCode` | six batch 20 names added | Fails if the new parameters go undocumented. |
| `Tests/ActionsTests/Mocks.swift` `Harness` | a `MockSwitcherInput` and a `move(…)` helper with a `SlideMotion` | Old helpers unchanged. |

## Diff summary

**Gestures**
- Every event carries `zoneLengthMM`.
- A slide that has **moved** and then rests (the existing rest logic: within `restEpsilonMM` 0.6 mm for `restDurationS` 0.1 s) in the **end band** emits a `.changed` with delta 0 and `atEnd` ±1 on every frame, until it moves or lifts. Past the zone's end counts as the end.
  - The band is `endBandMM` 6 mm, at most `endBandMaxFraction` 0.2 of the zone's length (a quarter of a MacBook edge gets ~4.75 mm).
  - A finger that lands in the band and never moves gets no `atEnd`.
- `longPressMSByZone` honoured for edges, corners and slide zones.
- `foreignMotionMM` applies only before a hold begins. Cancel reasons that remain for a begun hold: the held touch becomes a palm, a physical click, 3+ non-palm contacts, a contact that landed together with it (multi-finger window), and `reset()`.
- On a zone named in `slideZones`, a swipe needs 260 mm/s and 9 mm (elsewhere 180 mm/s and 6 mm).

**Actions**
- `SlideFeel.swift`: `SlideFeel` (named constants), `SlideSpeed` (smoothed speed), `SlideStepper` (mm steps, carry, speed-up, end stepping), `LevelFeel` (gentle level gain).
- `keyboard.slideSteps`: `stepMM` + `speedUp`, and legacy `step` converted with the zone's length (from `deltaMM / delta`).
- Levels: `speedUp`. Off or without a motion, it's the old code path exactly.
- `apps.switcher` session: open, move, keep open, select, cancel, as the brief describes.
  - `SwitcherInputMonitor` (protocol) with `LiveSwitcherInputMonitor`: listen-only global monitors for clicks, mouse moves (40 pt accumulated) and Esc, installed on the main thread only while a session lingers. It also gives the app count, for the wrap click.
  - The frozen factory signature is unchanged; the registry's internal init takes the monitor, defaulting to a no-op.
- Descriptors: BRIEF's labels, helper lines and units; `zeroLabel: "Off"` on `keepOpenMS`; `keyboard.hold` `holdMS` default 300.
- `GestureParameters.pressTime` (public): "Press time", `fallback: .longPressMS`.

**EdgyRuntime**
- Router: `ActionContext.motion` from each slide event (`delta × zoneLengthMM`, timestamp, `atEnd`); nil for discrete gestures or an unknown length.
- Engine:
  - `longPressMSByZone`: each long-press binding's `holdMS`, else the action's own `holdMS` default (300 for `keyboard.hold`), else nothing (`Engine.longPressTimes`).
  - The pointer guard is released while any long-press is held (tracked from `.began` to `.ended`/`.cancelled`, cleared on reset).
- Validation:
  - `slideAndSwipes` info note on each swipe sharing an edge with a slide (same zone or overlapping segments).
  - `legacyParameters` (`step` on the two stepped slides, never "unknown").
  - `pressTimeParameter` range-checked on long-press bindings, and "unknown" on other gestures.

**Scripts**
- `smoke-actions.sh` steps 29–33: short strokes, click-to-select, flick speed, end stepping, push-to-talk while pointing (by hand), fn reaching the dictation app. Step 19 now runs the one-stroke switcher explicitly.
- `record-traces.md` scenarios 30–34.

## Tuning against traces
`Fixtures/traces/` holds only `.gitkeep`: **no recorded traces exist**. So, per the brief, every value stayed as it was (`longPressMaxTravelMM` 1.0 mm) and the new ones are first guesses: end band 6 mm, speed curve 60 → 300 mm/s, 3× / 1.6×, end rate 2 → 6 steps/s over 0.6 s, keep-open 400 ms, pointer threshold 40 pt. There is no before/after table. Scenarios 30–34 in `scripts/record-traces.md` say which trace sets which number. The replay test and the three labelled expectations run as soon as traces land.

## Decisions I made (and why)
- **End stepping is driven by frames, not a timer.** The recognizer reports `atEnd` every frame while the finger rests, so the action integrates the rate over frame timestamps. No timer can outlive a lift, and the logic stays pure.
- **Default `stepMM` is 8 mm for both stepped actions.** BRIEF gives 8 for the switcher and no value for keys. The old key default (1/16 of a zone) was 6–10 mm depending on the pad.
- **Legacy `step` with a motion is converted on every update** with that update's zone length. On an update with no travel the length is unknown, so it uses 100 mm; that only affects the step size for end steps, which are counted in steps, not mm.
- **The switcher continues on any `.began` of `apps.switcher` while it lingers.** The registry doesn't know which binding a gesture came from, and only one switcher session can exist.
- **The carry survives between strokes.** Short strokes shorter than a step still add up, the way the volume level does.
- **Slide-back cancel:** the app the switcher opened on is position 0, and one step back from there cancels (escape). The old "back from the start wraps to the last app" is gone; that is what the brief asks for.
- **Esc while lingering releases command without sending another escape.** The system switcher closes itself on Esc while command is down.
- **A physical click during a switcher stroke selects at `keepOpenMS`, not at once.**
  - The click cancels the gesture (`physicalClick` → `.cancelled`), and an interruption lingers like an end.
  - The input monitor is installed only then, so it never sees the click that caused it. The app is picked when the window passes (400 ms) instead of immediately.
  - Consistent with the brief; not a bug.
- **Pointer movement needs 40 pt.** The next stroke's finger moves the pointer a little before the recognizer claims it. Selecting on that would break short strokes.
- **Stricter swipes apply on every explicit slide zone**, not only slide + swipe edges. The recognizer can't see swipe bindings (see `blockers-batch-20.md`). On a slide-only edge it's what we want anyway.
- **Consequence to know:** a flick whose *initial* speed is ≥ 260 mm/s on a slide zone is still a swipe candidate. If the finger then stays down past 350 ms it is rejected (`tooFast`), not slid.
  - Speed-up works for strokes that start below that and then speed up. That covers almost all real slides, because the claim is decided in the first 2 mm.
  - The `swipeZones` blocker would remove the limit on slide-only edges.
- **The pointer guard stays released for the whole hold**, including a slide claim on another device during it. Nothing else claims while a hold is held: the contact-count rules revoke it.
- **On/off parameters are a two-value choice `on` / `off`.** `ActionParameter.Kind` has no boolean, and this matches the existing `haptics: "off"` convention. The inspector (batch 15) should draw `.choice(["on","off"])` as BRIEF's checkbox.
- **`holdMS` on other long-presses is offered by the gesture, not the action.** Adding it to every trigger descriptor would show it on taps too. `GestureParameters.pressTime` (Actions) and `ConfigValidator.pressTimeParameter` (EdgyRuntime, which can't import Actions) carry the same spec.

## Needs Gabriel
- Run `scripts/smoke-actions.sh` steps 29–33 (and 19, which now runs the one-stroke switcher). Its Swift typechecks against the built modules (`swiftc -typecheck`), but it has never been run.
- **Feel on the Magic Trackpad and the MacBook:**
  - short strokes (does 400 ms feel right between strokes?);
  - flicks (is 3× too much or too little? is the 60 → 300 mm/s curve smooth?);
  - end stepping (is the 6 mm band reachable at the physical end of each pad, and is 6 apps/s right?);
  - levels (does 1.6× feel gentle?).
- **Push-to-talk while pointing:**
  - hold a corner, point with another finger; the keys stay down and the pointer moves;
  - try the 300 ms hold time for talking.
- **`fn` reaching the dictation app (smoke 33).** If it doesn't, use a non-`fn` push-to-talk key: right option, or `ctrl+opt+space`, set in the dictation app and in Hold Keys.
- Record scenarios 30–34 on both pads so the numbers can be tuned against traces.

## Open questions / for the chief
0. **The `speedUp` checkbox is a visible BRIEF deviation until someone acts on it.**
   - BRIEF wants a checkbox. `ActionParameter.Kind` has no boolean, so `speedUp` is `.choice(["on","off"])`.
   - BRIEF's generic rule ("a segmented control for ≤3 options") would draw it as an on|off segmented control.
   - Either the inspector special-cases exactly `.choice(["on","off"])` as a checkbox, or the chief adds a boolean kind to the frozen `ActionParameter.Kind` on `main`. One of the two must happen.
   - The runtime has no "parameter rows for a binding" query (`SettingsQueries` / `SettingsEditor` have none), so the inspector also has to add `ConfigValidator.pressTimeParameter` itself, on long-press bindings whose action has no `holdMS`.
1. **`GestureContext.swipeZones`** (`blockers-batch-20.md`): lets slide-only edges never swipe and keeps the stricter threshold for slide + swipe edges only.
2. **Inspector (batch 15):**
   - draw `.choice(["on","off"])` as a checkbox;
   - offer `GestureParameters.pressTime` / `ConfigValidator.pressTimeParameter` on long-press bindings whose action has no `holdMS`;
   - map `slideAndSwipes` to BRIEF's copy with the "Move swipes to another edge" fix.
3. **Feed:** end steps and switcher steps produce no `actionUpdated` (the switcher reports `systemHUDShown`). Nothing new to draw.
