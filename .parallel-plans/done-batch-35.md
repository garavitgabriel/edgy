# Batch 35 — EDGY-TAPCLICK: done

A tap Edgy takes no longer also clicks the thing under the pointer. I was blocked at first
(`blockers-batch-35.md`). The chief added `GestureOutput.tapLifts` on main (`ef7e77c`), I merged
it, and built the batch.

## What was built, item by item

### 1. Engine opens an expectation on an accepted tap lift

- **Gestures** (`GesturePipeline.swift`): `FrameStep.tap()` appends the zone to `tapLifts` on all
  three branches:
  - a tap that fires at once;
  - a first tap held for the double-tap window;
  - the second tap of a `.doubleTap`.

  `flush` never fills it. I retuned no threshold, and what is recognised is unchanged.
- **Engine** (`Engine.swift`, `expectTapClick(_:profile:)`): called from `handle` (the frame path)
  only, never from `fireFlush`. It calls `pointerGuard.expectTapClick(within: 0.5)` once per step
  when a lifted zone has a `.tap` or `.doubleTap` binding in the current profile. It does nothing
  when the profile is disabled (Edgy off in this app). `handle` already returns early when Enabled
  is off or the engine is paused. Test Mode does not gate it.

Tests (Gestures, `Tests/GesturesTests/TapLiftTests.swift`):

| Test | Proves |
|---|---|
| `tapThatFiresAtOnceReportsItsLiftOnTheSameStep` | An immediate tap reports its lift. |
| `heldTapReportsItsLiftAtTheLiftNotWhenItIsReleased` | A held tap reports its lift at the lift, not when it is released. |
| `doubleTapReportsBothLifts` | Both taps report, with or without the wait. |
| `flushNeverReportsALift` | Flush output is empty. |
| `tapToClickButtonAtTheLiftStillReportsTheLift` | The system's own button-down on the lift frame does not undo the tap. |
| `palmLiftReportsNoTap` | Rejected: palm. |
| `typingLiftReportsNoTap` | Rejected: typing. |
| `movedLiftReportsNoTap` | Rejected: moved. |
| `physicallyClickedLiftReportsNoTap` | Rejected: physical click. |
| `liftInAnUnmappedZoneReportsNoTap` | Rejected: unmapped zone. |
| `liftThatIsNotATapReportsNone` | A lift too long to be a tap, and a swipe. |

Tests (Engine, `Tests/EdgyRuntimeTests/TapClickEngineTests.swift`):

| Test | Proves |
|---|---|
| `tapLiftInATapBoundZoneExpectsTheClick` | A tap lift in a tap-bound zone opens a 0.5 s expectation; the guard's engage/release calls are unchanged. |
| `heldFirstTapAndSecondTapOfADoubleTapEachExpectAClick` | Both taps of a double-tap expect a click. |
| `severalZonesLiftingInOneStepExpectOneClick` | One step expects at most one click. |
| `zoneWithoutATapOrDoubleTapBindingExpectsNothing` | Rejected: zone with no tap or double-tap binding. |
| `rejectedLiftsExpectNothing` | The engine opens nothing for any rejection on its own. |
| `edgyOffInThisAppExpectsNothing` | Rejected: Edgy off in this app. |
| `enabledOffExpectsNothing` | Rejected: Enabled off. |
| `pausedExpectsNothing` | Nothing while paused. |
| `testModeStillExpectsTheClick` | Test Mode still expects the click. |
| `aHeldTapReleasedByFlushIsNotANewLift` | A held tap released by flush is not a new lift. |

**Why the rejection tests are split across two layers:** EdgyRuntimeTests can't import Gestures.
- Palm, typing, moved and physical click produce no `tapLifts` in the real pipeline; the Gestures
  tests prove each one.
- "No tap or double-tap binding", "Edgy off in this app" and "Enabled off" are Engine decisions;
  the Engine tests cover them.

### 2. Guard (TouchKit)

- `LiveEventTap` now also watches `leftMouseDown` / `leftMouseUp`. It maps them to the new
  `TapEventKind.leftDown(clickState:)` / `.leftUp`, still on the input thread.
- `PointerGuardCore` swallows the next left-down and its up while an expectation is open; then
  the expectation is spent.
- Expectations expire by timestamp at click time, so no timer runs while nothing is expected.
- The only timer is the safety timer that runs while waiting for a swallowed down's up.
- The callback takes only short locks (no lock is held across the handler) and does no
  allocation-heavy work.

**How physical vs tap clicks are told apart:** a physical press needs a finger pressing the pad;
the system's tap-to-click click comes after the lift.
- New `PadContacts` (TouchKit) is written by `DeviceManager.deliver` on every frame, before the
  frame is handed on. A finger counts as down when it is `starting`, `touching` or `unknown`
  (the pipeline's own rule).
- The live touch source and the live guard share `PadContacts.shared`, because the two factories
  are separate and frozen.
- A left-down while any finger is down on any pad passes, and so does any left-down with no
  open expectation.

**The window is anchored to the lift.** `PadContacts` records when the pads emptied (and bumps an
epoch). `expectTapClick` measures its 0.5 s from that moment, not from the call, because the
engine runs on `.main` and hears about the lift later than the tap does. If a no-finger left-down
already passed since that lift, the call is late and is dropped (logged): that click was the
tap's, and the next one is the user's.

Tests (`Tests/TouchKitTests/TapClickTests.swift`, `PadContactsTests`):

| Test | Proves |
|---|---|
| `expectedTapSwallowsOneClickThenTheNextPasses` | An expected click is swallowed once; the next passes. |
| `clickWithNoExpectationPasses` | No expectation, no swallow. |
| `physicalPressWithAFingerDownPassesEvenWithAnOpenExpectation` | A physical press during a touch passes. The gesture is still rejected as today; `physicallyClickedLiftReportsNoTap` and the existing `PhysicalClickTests` cover that. |
| `expectationExpiresAndALaterClickPasses` | Expiry needs no timer. |
| `windowIsAnchoredToTheLiftNotToTheCall` | The window runs from the lift. |
| `expectationThatArrivesAfterTheClickPassedIsDropped` | The late drop. |
| `doubleTapSwallowsBothClicksAndAThirdPasses` | clickState 2 is one pair; a third click passes. |
| `bothExpectationsOpenBeforeEitherClickStillSpendOnePairEach` | Two open expectations spend one pair each. |
| `secondExpectationAfterTheFirstClickWasSwallowedStillCounts` | A swallowed click doesn't mark the next call late. |
| `sameLiftExpectedTwiceIsOneClick` | One lift, one click. |
| `sameLiftExpectedAgainAfterItsClickWasSpentOpensNothing` | A repeat call after the spend opens nothing. |
| `swallowedDownWithNoUpIsReleasedByTheSafetyTimeoutAndLoggedOnce` | A missing up ends the wait after 3 s, counted once. |
| `newDownWhileWaitingForAnUpEndsTheWait` | A new down ends the wait, so the system is never left with a button down. |
| `upWithoutASwallowedDownPasses` | Never swallow an up whose down passed. |
| `tapDisabledBetweenASwallowedDownAndItsUpStopsWaitingForTheUp` | Disable by timeout or user input also ends the wait. |
| `idleCostsNoTimer` | Nothing scheduled while idle. |
| `pointerMotionIsUnchangedWhileAClickIsExpected` | Pointer motion behaves as before. |
| `tapDisabledWhileAClickIsExpectedIsTurnedBackOn` | Re-enable still works. |
| `withoutPadStateTheWindowStartsAtTheCall` | Fallback when there is no pad state. |
| `liftingAndHoveringFingersAreUpAndEachEmptyingBumpsTheEpochOnce` | Pad state: which states count as down; one epoch per emptying. |
| `aFingerOnAnyDeviceCountsAndAGoneDeviceIsForgotten` | Pad state across devices. |
| `deviceManagerTellsThePadAboutEveryFrameAndEveryGoneDevice` | The pad is updated before the frame is handed on. |

Every existing `PointerGuardTests` and `Batch28InputThreadTests` test passes untouched. The only
change to an existing test file is additive: `FakePointerGuard` records `expectTapClick` calls in
a separate `tapClicks` list, so every `calls` assertion is unchanged.

### 3. Test Mode honesty

The Engine doesn't gate on Test Mode (`testModeStillExpectsTheClick`). `docs/settings-reference.md`
(Runtime → Test Mode) now has one plain sentence about it, with the tap-to-click explanation.

### 4. Smoke

`scripts/smoke-actions.sh` has a new step 38, done by hand with Edgy running:
- a tap over another app's window runs the action and doesn't click the window (double-tap too);
- a physical press still clicks;
- a mid-pad tap still clicks;
- Test Mode still doesn't click.

It also gives the log grep. I checked the embedded Swift with `swiftc -parse`; I did not run the
script.

## The system's delay

No trace in `Fixtures/traces` or `Tests/GesturesTests/Fixtures` has a `buttonDown` frame, so I
could not observe a lift-to-click delay. What the code establishes:
- The click comes after the lift. The pipeline already settles lifts before a button-down on the
  same frame, so a tap-to-click button reading down from the lift frame still counts as the tap
  (`tapToClickButtonAtTheLiftStillReportsTheLift`).
- 0.5 s from the lift is the brief's starting window. It is not measured.

## What Gabriel should check on device

1. **The delay against the double-tap gap.** Measure the lift-to-click delay, and compare it with
   the gap between the two taps of a double-tap. If the system's first click arrives after the
   second finger has landed, the guard treats it as a physical press and lets it through. That
   case decides whether the Last App double-tap is fully fixed. Record a double-tap with
   `edgy-trace` (frames carry `buttonDown`) next to the `tap click` logs.
2. **Late expectations.** Count how often `tap click: expectation arrived after the click passed`
   appears. That message means the click beat the engine (frame → main queue hop). If it is
   common, the expectation should be opened on the input thread instead.
3. **Down/up pairs per double-tap,** with the system's tap-to-drag setting on and off. With
   dragging on, the system may hold the first click's up. A leftover expectation (a tap whose
   click never came) eats one real no-finger tap-click within 0.5 s of that lift.
4. **A click from a separate mouse** within 0.5 s of an Edgy tap, with no finger on the pad, is
   swallowed. It is an accepted edge case; confirm it is rare.
5. **A single tap in a double-tap-only zone** now swallows its click too. The lift is a tap the
   double-tap binding may take, as the brief says. Check that this feels right.

## Open questions

- If check 1 shows the first click landing after the second touch, does the chief want a rule for
  "a left-down while a finger is down, inside an open expectation, that the pipeline later
  accepts as a tap"? It is not built: it would risk swallowing a physical press.
- Should the expectation be opened on the input thread to beat the main-queue hop? That would
  need the pipeline's tap decision there, which is not built.

## Verification

At final HEAD, `swift build && swift test && swift format lint --strict -r Sources Tests Package.swift`
is green; the "Test run with" lines are in the builder's report to the chief. The denylist
printed nothing. I formatted only my own paths.
