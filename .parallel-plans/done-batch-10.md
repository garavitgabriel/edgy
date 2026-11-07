---
batch: 10
tag: EDGY-GESTURES-3
branch: worktree-edgy-gestures-v04
worktree_path: /Users/gabrielgaravit/Projects/edgy/.claude/worktrees/edgy-gestures-v04
completed_at: 2026-11-07
verification: pass
---

## Acceptance criteria
- [✓] **≥ 14 new tests**: 32 in total (24 gesture, 8 TouchKit).
  - Click rejection, in `Tests/GesturesTests/PhysicalClickTests.swift` (10):
    - candidate: `clickWithoutDragInACornerIsNotATap`
    - slide: `clickMidSlideCancelsTheSlide`
    - hold: `clickAfterALongPressBeganEndsTheHold`
    - tap: `clickedEdgeTapNeverFires`
    - swipe: `clickedFlickAlongAnEdgeIsNotASwipe`
    - force click while still: `forceClickWhileStillIsNotALongPress`
    - also `clickedTapDoesNotPairWithTheNextTap`, `fingerLandingOnAnEdgeWhileTheButtonIsHeldIsNotOurs`, `releasingTheButtonDoesNotReviveTheTouch`, `buttonGoingDownAsTheFingerLiftsKeepsTheTap`
  - Tap wait, in `Tests/GesturesTests/TapWaitTests.swift` (11):
    - single tap delayed by the window: `singleTapWaitsForTheDoubleTapWindow`
    - only the double-tap is emitted: `doubleTapInAWaitingZoneEmitsOnlyTheDoubleTap`
    - a zone without a double-tap fires at once: `zoneWithoutADoubleTapFiresItsTapAtOnce`, `noDoubleTapZonesMeansNobodyWaits`
    - reset drops the pending tap: `resetDropsAPendingTap`
    - position preserved: `delayedTapKeepsItsPositionAndLiftTime`
    - also `flushReleasesThePendingTapWhenNoMoreFramesCome`, `secondTouchStillDownPastTheWindowKeepsTheTapWaiting`, `tapThenHoldReleasesTheTapBeforeTheHold`, `tapThenSwipeInsideTheWindowReleasesTheTapFirst`, `tapsInDifferentZonesWaitIndependently`
  - Corner-size boundary pair, in `Tests/GesturesTests/CornerSizeTests.swift` (3): `…IsACornerTapWithTwelveMillimetreCorners` / `…IsAnEdgeTapWithTenMillimetreCorners`, plus `testSettingsMatchTheShippedDefaultsApartFromCornerSize`.
  - TouchKit button source on a fake, in `Tests/TouchKitTests/ButtonStateTests.swift` (5):
    - press/release ordering: `framesCarryTheButtonStateInPressReleaseOrder`
    - failed start reads false: `failedStartReadsButtonUp`
    - lazy start, stop with the manager: `sourceStartsOnStartNotAtConstructionAndStopsWithTheManager`
    - also `restartAfterAFailedStartTriesAgain`, `withoutASourceEveryFrameReadsButtonUp`
  - Trace round trip, in `Tests/TouchKitTests/TraceRecorderTests.swift` (3): `buttonDownRoundTripsThroughATraceFile`, `traceWithoutButtonDownDecodesAsButtonUp`, `liveLineMarksTheButton`.
- [✓] **The disabled batch-9 test is enabled and passes.** `physicalClickAndDragStartingInAnEdgeStripIsNotOurs` now also asserts the `.physicalClick` reason. No other test was weakened. Every corner-dependent test runs with an explicit `GestureSettings.test`: `replay`'s default, `Preset.settings`, and the three direct uses of `.defaults`.
- [✓] **No test installs an event tap or reads real input.** `HIDButtonState` is built only in `LiveTouchSource`, and the tests use `FakeButtonState` through `DeviceManager`.
- [✓] Verification triple green, denylist clean.
- [~] **Tap-wait time drive:** done in the recognizer. The engine-side timer is outside my glob; see `blockers-batch-10.md`.

## Verification
- `swift build` → `Build complete!`
- `swift test` → exit 0. TouchKit 56 (was 48), **Gestures 88** (was 64), EdgyRuntime 114, the others unchanged (6, 19, 50, 156).
- `swift format lint --strict -r Sources Tests Package.swift` → exit 0
- `git grep -niE -f ~/.config/edgy-names-denylist` → no output

## Chosen button-state source, and why
`HIDButtonState` (`Sources/TouchKit/LiveSystem.swift`) reads `CGEventSource.buttonState(.hidSystemState, …)` for the primary or secondary button. `DeviceManager.deliver` reads it as each frame is handed out and stamps `frame.buttonDown`.
- **Correct by the next frame, by construction.** The read is synchronous at frame time. The HID system state changes as the HID event is processed, before the event reaches any event tap. A listen-only tap would add a WindowServer hop and a run-loop callback that can lag the multitouch thread, and it can be disabled by a timeout. It would also need an Input Monitoring or Accessibility grant.
- **Works on every pointing device**, built-in and Bluetooth trackpads alike, because the state is system-wide.
- **Secondary counts too.** "Click in the bottom-right corner" is a real press in a corner.
- **Lifecycle:** `ButtonStateSource` (public, additive) has `start() -> Bool`, `stop()` and `isDown`. Nothing starts at construction. `DeviceManager.start` starts the source before any device registers, and `stop` stops it. A failed start (no HID event source) logs one reason, and every frame reads `false`.
- **Limit:** it can't tell which device clicked. A mouse click while a thumb rests on a trackpad edge rejects the thumb. I think that's fine, arguably desirable.

## Gesture rules (as built)
- **Click:** on a `buttonDown` frame, after lifts and new contacts are processed and before the contact count and advance, every live candidate is rejected with `.physicalClick`. A claimed slide gets `.cancelled`, and a hold gets `.cancelled`, which is its up. Rejected fingers are `finished` and never become candidates again, so they stay not-ours until lift. A finger landing while the button is down is rejected in the same frame.
  - **Lifts are processed first.** A real click needs a finger pressing. Tap-to-click reports its click after the lift, so a button first seen on the lift frame doesn't undo a tap (`buttonGoingDownAsTheFingerLiftsKeepsTheTap`).
- **Tap wait:**
  - **Wait set** = `context.doubleTapZones`. The brief's "tap-bound" set can't be derived exactly: the context has no tap-zone set, and every enabled zone may emit a tap. Where a zone has a double-tap but no tap, the router drops the delayed tap, so waiting costs nothing. `nil` means no zone waits.
  - **Released when:**
    - (a) a frame arrives past lift + window and no live touch in that zone could still pair with it (born inside the window, not claimed or moved, still within tap duration and travel). The worst-case wait is window + `tapMaxDurationS`, and only while a second touch is actually down.
    - (b) anything else is emitted in that zone (a swipe, a hold, slide motion). The earlier tap is then final.
    - (c) `flush(now:)` is called.
  - Released taps go ahead of the frame's other events.
  - **The delayed event is identical** to the immediate one, including the lift timestamp and position (`delayedTapKeepsItsPositionAndLiftTime`).
  - `reset()` drops pending taps.

## Latency added to taps
Only in zones listed in `doubleTapZones`: one double-tap window (`doubleTapWindowMS`, 300 ms default), plus up to one frame. If a second touch lands inside the window and stays down, the wait lasts until it lifts or stops being a possible tap, at most +250 ms. Other zones fire on the lift frame, as before (`zoneWithoutADoubleTapFiresItsTapAtOnce`).

## Adversarial suite at 10 mm corners
I ran the whole gesture suite with `.test` set to 10 mm, then reverted. Only 3 tests changed, all geometry probes of points between 10 and 12 mm from the sides:
- `tapOnTheCornerEdgeBoundary`: the 11.9 mm point and the (146, 10) point become edge taps.
- `tapThatLandsInACornerAndRollsIntoTheEdgeStaysACornerTap`: it lands about 11 mm from the side, so the touch starts on the edge.
- `zoneGeometryClassifiesInMillimetres`: (140, 85) is no longer a corner.

No misfire scenario changed. All three are pinned at 12 mm now, so flipping the default to 10 breaks nothing.

## Diff summary
- `Sources/Gestures/GesturePipeline.swift`: click rejection, `PendingTap`, release rules, `DeferredGestureFlushing` conformance, `event(…)` split from `emit`.
- `Sources/Gestures/Gestures.swift`: public `DeferredGestureFlushing`.
- `Sources/TouchKit/ButtonState.swift` (new): `ButtonStateSource`, `NoButtonState`.
- `Sources/TouchKit/DeviceManager.swift`: `buttonState:` init parameter (defaulted), lifecycle, stamping.
- `Sources/TouchKit/LiveSystem.swift`: `HIDButtonState`, wired in `LiveTouchSource`.
- `Sources/TouchKit/TraceRecorder.swift`: the live line prints `BUTTON`. The recorder stores `buttonDown` through `Codable`.
- Tests:
  - `Harness`: `GestureSettings.test` and `test(cornerSizeMM:)`, `doubleTapZones:` on `replay`.
  - `TraceBuilder.buttonDown`; `Preset.run(buttons:)`.
  - 3 new gesture test files and 1 new TouchKit test file, plus `FakeButtonState`.
  - `RecordedTraceTests`: 7 new labels, a `.waitingTaps` expectation, and stacked suffixes including `-taptoclick`.
- `scripts/record-traces.md`: §23 rewritten, §24–29 added (click-drag on each edge, corner click, force click, tap then double-tap, with and without tap-to-click).

## Decisions I made (and why)
- **The HID-state sampler, not an event tap.** Reasons above.
- **The wait set is `doubleTapZones`** as given. It can't be narrowed exactly, and it doesn't need to be.
- **The delayed tap keeps its lift timestamp.** It says when the tap happened; nothing downstream computes on event timestamps today.
- **A tap followed by a hold or swipe in the same zone still fires the tap**, ahead of the other gesture. The first touch really was a tap.
- **Tap-to-click race:** I chose lift-before-click ordering (see Gesture rules), which favours taps. If recordings show `BUTTON` frames *while* a plain tap's finger is still down with tap-to-click on, those taps would be rejected. That would need a rule such as ignoring a press that starts within a few ms of the lift.

## Needs Gabriel
- **Record the new scenarios** (`scripts/record-traces.md` §23–29) on the MacBook and on the Mac mini with the Magic Trackpad (`-external`). Record §29 with tap-to-click off and on (`-taptoclick`). Drop them in `Fixtures/traces/`. The replay test picks them up automatically.
- **Click-drag a window edge on both Macs:** resize a window from its right edge, and select text starting low on the pad. Nothing should fire, and the pointer must never freeze. In `edgy-trace live`, confirm `BUTTON` appears on the first frame after the click on both trackpads.
- **Tap-to-click on:** tap and double-tap a corner. Both must still fire.
- **Feel the 300 ms tap delay** on a zone with tap + double-tap. This needs the engine wiring first (blocker note).

## Open questions
- **Engine wiring** for `DeferredGestureFlushing` and `doubleTapZones`: see `blockers-batch-10.md`. Until it's wired, no zone waits, so nothing regresses.
- Should a mouse click (not the trackpad) reject a thumb resting on an edge? Today it does, because the state is system-wide.
