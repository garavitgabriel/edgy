---
batch: 9
tag: EDGY-GESTURES-2
branch: worktree-edgy-gestures-v03
worktree_path: /Users/gabrielgaravit/Projects/edgy/.claude/worktrees/edgy-gestures-v03
completed_at: 2026-11-06 20:51
verification: pass
---

## Acceptance criteria
- [✓] **Long-press phases began / ended / cancelled tested, incl. pointer-claim lifetime.** `Tests/GesturesTests/HoldLifecycleTests.swift` (9 tests) + the two updated scenario tests. New harness check `expectHoldsArePaired` asserts, on every frame, that each `.began` is closed by exactly one `.ended`/`.cancelled` and that the fingers stay claimed while a hold is open. Claim lifetime is checked frame by frame in `longPressTopLeftCornerFires` and `edgeHoldEndsAtLiftAndStaysClaimedUntilThen`. Cancel paths: palm spreading under a hold, 3+ fingers, and (new) another finger moving.
- [✓] **Router hold pairing tested for normal lift, cancel, reset, pause, reload, frontmost-app change, stop.** `Tests/EdgyRuntimeTests/HoldRoutingTests.swift`: `RouterHoldTests` (10) and `EngineHoldPairingTests` (8: `normalLift`, `cancelled`, `pauseReleases`, `configReloadReleases`, `frontmostAppChangeReleasesBeforeTheNextFrameIsRouted`, `stopReleases`, `replacingActionsReleasesOnTheOldRegistry`, plus a no-op control).
- [✓] **≥ 12 adversarial scenario tests, each named for the scenario.** `Tests/GesturesTests/AdversarialTests.swift`: 17 active + 1 disabled (blocked, see below).
- [✓] **Validation/queries for `.hold` and `actionUnavailable`; `machineDefaults` tested with a fake catalog where brightness is unavailable.** `Tests/EdgyRuntimeTests/AvailabilityTests.swift` (21 tests across `HoldValidationTests`, `ActionUnavailableTests`, `EditorAvailabilityTests`, `MachineDefaultsTests`).
- [✓] **All existing gesture and runtime tests still pass; changed ones keep their intent.** Changes to existing tests: `longPressTopLeftCornerFires` and `longPressFiresOnlyWhereBound` now expect `[.began, .ended]` instead of one event. Both still check the timing (fires at 0.50–0.52 s), and the first still checks the frame-by-frame claim; each adds the pairing check and the lift timing. `everyCodeIsReachable` validates on a Mac where one bound action is unavailable, so the new code is reachable; the rest of the test is unchanged. `EngineHarness.init` gained an optional `catalog:`, and `FakeActions.available` became settable (defaults unchanged).
- [✓] Verification triple green, denylist clean.
- [✓] Done report (this file). Blocker for the click item: `.parallel-plans/blockers-batch-9.md`.

## Verification
- `swift build` → `Build complete!`
- `swift test` → exit 0. Every target passes: 48, 6, **64 GesturesTests** (was 30), **114 EdgyRuntimeTests** (was 75), 13, 1, 89 (integration, including the real catalog against the validator).
- `swift format lint --strict -r Sources Tests Package.swift` → exit 0
- `git grep -niE -f ~/.config/edgy-names-denylist` → no output (exit 1)
- Before/after for the fixes: the first run of the adversarial suite failed 4 scenarios (listed below). All passed after the two changes.

## Threshold / logic changes (before → after, why)

| Change | Before | After | Why / evidence |
|---|---|---|---|
| Long-press lifecycle | one `.longPress .ended` at recognition | `.began` at recognition; `.ended` when a member lifts; `.cancelled` from `rejectCandidate` (palm, 3+ fingers, landed-together finger, another finger moving) | Contract on main. `reset()` still emits nothing (it returns nothing); the router closes holds on reset. |
| Hold freezes the touch | after a hold fired on an edge, motion could still turn it into a swipe, emit slide `.changed`, or reject it as off-axis | `advanceEdge` returns early once `longPressFired`, as `advanceCorner` already did | Without this, a hold whose finger shifted ≥ 2 mm became a swipe, and the `.ended` was lost (a stuck push-to-talk key). Tests: `holdThatMovesAfterItBeganIsNotASwipe`, `holdThatDriftsInwardAfterItBeganIsNotHandedOff`, `holdOnASlideZoneFreezesSlideOutputUntilLift`. On a zone with both a slide and a long-press, slide output stops once the hold begins. Before, the slide kept emitting under a held key. |
| `Tuning.foreignMotionMM` (new) = 3.0 mm | a claimed slide/hold was revoked only by 3+ contacts or a finger that landed with it | also revoked (`tooManyContacts`) when any other non-palm contact moves > 3 mm from where it landed. A late finger that only rests still doesn't revoke (`lateRestingFingerDoesNotCancelClaimedSlide` unchanged and green) | **Failed before:** `thumbRestingOnASlideEdgeIsLetGoWhenAnotherFingerMoves` (thumb on the right edge claimed a slide at the dwell, then the index finger moved the pointer and the pointer guard froze it) and `thumbHoldingAPushToTalkCornerIsCancelledWhenAnotherFingerMoves`. 3 mm matches `diagonalDecideMM`: well above tremor, and reached in ~70 ms of normal pointer motion. |
| `Tuning.longPressMaxTravelMM` | 1.5 mm | 1.0 mm (= `stillRadiusMM`) | **Failed before:** `longPressThatDriftsSlowlyInACornerDoesNotFire` and `…AlongAnEdgeDoesNotFire`. A finger creeping ~2.7 mm/s had travelled ~1.35 mm at 500 ms and fired. Now a hold needs the same stillness as a dwell claim. Risk: a firm press that rolls > 1 mm in its first 500 ms won't fire. Real traces 11/20/22 will tell (Needs Gabriel). |

Unchanged and documented by tests:
- **Corner/edge boundary** (`tapOnTheCornerEdgeBoundary`): the corner square is `[0, 12)` mm from both sides, with strict `<`. Exactly 12.0 mm belongs to the edge, 11.9 to the corner. A mapped corner wins inside its square, and an unmapped one falls through to the edge strip. The zone is fixed where the finger lands, so rolling across the line changes nothing (`tapThatLandsInACornerAndRollsIntoTheEdgeStaysACornerTap`). Corner wins because a corner square is the only place a corner gesture can happen, while the edge still has its whole length. **Proposal for the chief:** users found 12 mm large on the external pad. Consider a `GestureSettings.cornerSizeMM` default of 10 mm (the limits allow 5…30). It's a frozen-core default, so I didn't touch it. Recording 21 shows where real taps land.
- Palm while typing is rejected as `typing` at landing, before the palm spreads. Without typing it's `palm` (two tests).

## Router / runtime design
- `Router` reads shapes from `actions.available` (cached and rebuilt in `replaceActions`). For a `.hold` action, a long-press `.began` → `.press(down: true)` + `actionFired` haptic. `.ended`/`.cancelled` → `.press(down: false)` **with the stored action + parameters**. This check runs before the profile/disabled/binding lookup, so a profile switch, a disabled profile or a removed binding can't swallow the release.
- The pending hold is recorded *before* performing, so a press that throws is still released. A second `.began` for a held key releases the first. A hold action bound to a non-long-press gesture is refused with one error log, and nothing is performed.
- `Router.reset()` / `releaseHolds(reason:)` / `replaceActions(_:)` release every pending hold, oldest first. Engine `pause`, `apply` (reload, also a profile edit), `stop` → `quiesce` → `router.reset()`. Engine `replaceActions` releases on the old registry.
- **Frontmost-app change:** `Engine.handle` remembers the last frame's bundle id. When it changes and holds are pending, `releaseHolds("frontmost app changed")` runs before the new frame's events are routed. The later `.ended` from the recognizer then finds nothing and does nothing.
- `ConfigValidator(catalog:availability:)` takes an `[ActionID: ActionAvailability]` snapshot (it stays `Sendable`). Missing ids count as `.available`. `ConfigValidator.shape(_:fits:)` is the single shape table that validation and `compatibleActions` share.
- `SettingsEditor(…, actions: ActionPerforming? = nil, …)` (new defaulted parameter, so `AppDelegate` compiles unchanged):
  - `availability(of:)` passes through live to the registry.
  - `refreshAvailability()` re-snapshots for validation, e.g. after a display or keyboard hot-plug. It doesn't notify observers.
  - `machineDefaults(from: = .defaults)`.
  - I took the registry rather than a closure: under Swift 6, a `@MainActor` closure type is implicitly `@Sendable`, so `actions.availability(of:)` couldn't be passed.
- `MachineDefaults.build(from:catalog:availability:) -> (config, substitutions)` plus `MachineDefaults.build(from:actions:)`. Substitution table (documented on the type):

  | Unavailable | Alternatives, in order | Otherwise |
  |---|---|---|
  | `display.brightness` | `apps.switcher`, then `keyboard.slideSteps` with `cmd+equal` / `cmd+minus` (zoom) | dropped |
  | `keyboard.backlight` | `display.brightness` | dropped |
  | anything else | — | dropped |

  An alternative must be in the catalog, fit the gesture, be usable, validate without errors, and not already be bound in that profile. Only `.unavailable` is touched; `.limited` is kept. Every profile is adjusted. Batch 7's ids (`apps.switcher`, `keyboard.backlight`) aren't in this branch's catalog yet, so with today's real catalog a Mac without brightness falls to the zoom slide. After batch 7 merges it gets the switcher.
- **New validation code** `actionUnavailable` (warning): the binding's action is `.unavailable` on this Mac. It never blocks an edit. The binding is kept so it works again when the hardware returns. No other codes were added; existing raw values are unchanged.

## Diff summary
- `Sources/Gestures/GesturePipeline.swift`: lifecycle, hold freeze, `Track.origin`, foreign-motion revoke.
- `Sources/Gestures/Tuning.swift`: `foreignMotionMM`, `longPressMaxTravelMM`.
- `Sources/EdgyRuntime/Router.swift`: hold routing and pairing.
- `Sources/EdgyRuntime/Engine.swift`: frontmost-change release.
- `Sources/EdgyRuntime/Validation.swift` / `SettingsQueries.swift`: shape table, availability snapshot, `actionUnavailable`.
- `Sources/EdgyRuntime/SettingsEditor.swift`: `actions:`, `availability(of:)`, `refreshAvailability()`, `machineDefaults(from:)`.
- `Sources/EdgyRuntime/MachineDefaults.swift` (new).
- Tests: `HoldLifecycleTests`, `AdversarialTests`, `RecordedTraceTests` (new). `Harness` gained `expectHoldsArePaired`/`holdPhases`. `HoldRoutingTests` and `AvailabilityTests` are new. Small additive changes to `Fakes`, `EngineTests` harness and `ValidationTests`.
- `scripts/record-traces.md`: an external-trackpad section (`--device <id>` and the `-external` label suffix) and scenarios 12–23.
- 20 files, +1475 / −28. Seven commits on `worktree-edgy-gestures-v03`.

## Real traces
`Fixtures/traces/` was empty when I started and still was at the end. `recordedTracesReplayAsExpected` loads every `Fixtures/traces/*.json` and checks the invariants on each: deterministic, nothing claimed at the end, holds paired. A known label also gets its scenario assertion, keyed by label with an optional `-external` / `-builtin` suffix. There are 21 labels: the 11 existing recording scenarios plus the v0.3 ones. `recordedTraceCheckerAcceptsSyntheticStandIns` runs the checker on synthetic stand-ins so the table is proven while the directory is empty. An unknown label gets the invariants only. Typing state isn't recorded in traces, so typing suppression never helps in replays.

## Decisions I made (and why)
- **A hold freezes slide output** on a zone that binds both. Holding a key while volume changes under the same finger is the bigger surprise.
- **A late moving finger cancels a hold too**, not just a slide. The claim freezes the pointer the user is visibly trying to move. Holding push-to-talk while pointing with another finger therefore isn't supported (see Open questions).
- **One late resting finger still doesn't cancel a hold** (`oneLateRestingFingerDoesNotCancelAHold`). This is the same rule as for slides.
- **The router releases a hold when the frontmost app changes**, not at lift. The new app's profile may bind something else, and a key held across an app switch lands in the wrong app.
- **Reload re-arms the hold:** `apply` resets the recognizer, so a finger still held after a config reload re-fires its hold ~500 ms later, as a new down/up pair. Pairing still holds.

## Needs Gabriel
- **Record the new trace scenarios** (`scripts/record-traces.md` §12–23) on the MacBook and on the Mac mini with the Magic Trackpad (`--device <id>`, `-external` suffix). Priority:
  - 20 (slow drift) and 22 (push-to-talk hold): validate the 1.0 mm long-press stillness.
  - 13 (thumb on the right edge while pointing): validate the 3 mm foreign-motion revoke.
  - 21 (corner boundary on the external pad).
- Drop them in `Fixtures/traces/`. The replay test picks them up automatically, and a failing one is a tuning signal.
- Feel check once the chief wires a `keyboard.hold` binding: hold a corner for push-to-talk in a dictation app, switch apps mid-hold, and pause Edgy mid-hold. The key must never stay down.

## Open questions
- **Physical click** (blocked): proposal in `blockers-batch-9.md`, an optional `buttonDown` on `TouchFrame` plus a rejection reason. The disabled test is ready.
- **Corner size default** 12 → 10 mm? A frozen-core default, so it's the chief's call. Recording 21 should inform it.
- **Push-to-talk while pointing:** if users want to keep a hold while moving the pointer with another finger, holds would need to skip the foreign-motion revoke, and the pointer guard would have to free the pointer for non-member fingers. Today the guard is all-or-nothing.
- `SettingsEditor.refreshAvailability()` doesn't notify observers. If the settings window needs to redraw issues on a display hot-plug, add a `SettingsChange.Cause.availability` (a cause, not a contract change) or have the window observe the hot-plug itself.
