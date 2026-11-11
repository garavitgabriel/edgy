# Batch 35 — EDGY-TAPCLICK: blocker

Status: **stopped before building**. No source or test changed. Only this note was added.

## What's blocked

Build item 1 says to open an expectation for "a tap that then waits out the double-tap window",
and to add one field on the gesture output in Gestures if needed. That field can't be added
without touching a frozen path.

- In a zone with a double-tap bound, `FrameStep.tap()` (`Sources/Gestures/GesturePipeline.swift`)
  puts the first tap into `pendingTaps` and **emits nothing at the lift**. This is tap 1 of every
  double-tap binding, which includes the reported Last App case. The `.tap` comes out a full
  double-tap window later (from `flush` or at the head of a later `process`), and by then the
  tap-to-click has already landed.
- The pipeline reaches the Engine only through:
  - `GestureOutput`, which is declared in `Sources/EdgyCore/Gesture.swift` (frozen);
  - the four members the app's `FlushingRecognizer` forwards, in `Sources/EdgyApp/AppDelegate.swift`
    (not mine).
  
  EdgyRuntime can't import Gestures. So an "output field added in Gestures" has no way to reach
  the Engine.

## Workarounds I rejected (each is dishonest or dead on device)

- **Inferring from `nextFlushDeadline`:** it is nil while any other finger is on that device, and
  its `min` hides a new pending tap behind an older one. A false positive eats a real click.
- **Encoding "tap lifted" in existing fields** (rejections, measures, claimed IDs, an extra
  phase): this changes what is recognised and breaks existing tests.
- **Copying the tap thresholds (`Tuning.tapMaxDurationS` / `tapMaxTravelMM`) into the Engine**
  so it can judge lifts itself: the copy would drift from `Tuning`.
- **A new EdgyRuntime-only protocol with a test fake:** the tests go green, but the live
  `FlushingRecognizer` never forwards it, so the feature is dead on device.

## What I need (pick one, on main)

1. **Preferred:** add one defaulted field on `GestureOutput` (EdgyCore), for example
   `tapLifts: [Zone] = []`: the zones where a contact lifted this step as an accepted tap. I would
   fill it in `tap()` on all three branches (immediate `.tap`, held `.tap`, `.doubleTap`). It stays
   empty from `flush` and on every rejected lift. The Engine reads it straight from `process`.
2. **Alternative:** a one-line forward in the app's `FlushingRecognizer` for a new
   `GestureFlushing` member (for example `var lastTapLifts: [Zone]`) that the pipeline fills.
   This one needs an EdgyApp change by whoever owns it.

## Constraints for when this resumes

1. **Stale taps never open an expectation.** A released pending `.tap` (its timestamp is the old
   lift time) and anything from `fireFlush` must not open one. Only the lift step does.
2. **The Engine does the binding check.** The pipeline emits `.tap` / `.doubleTap` in any enabled
   zone, including slide-only zones. The Engine opens an expectation only where the profile binds
   `.tap` or `.doubleTap` in that zone, with Edgy on in this app and Enabled on. Test Mode does not
   gate it.
3. **Main-queue lag.** The Engine runs on `.main` (AppDelegate) and the event tap runs on the
   input thread. The system's click can therefore pass before `expectTapClick` is called, and a
   late expectation would then eat the user's *next* real tap-click. The plan:
   - anchor the window to the lift time, not to the call time;
   - drop the expectation if a no-finger left-down has already passed since the pad emptied;
   - add a test for that drop;
   - put the frame-to-main hop latency on the device checklist.
4. **Physical vs tap click.** The guard learns "a finger is on the pad" from TouchKit-internal
   state written in `DeviceManager.deliver` on the input thread (before the frame hops). It is
   injected into `PointerGuardCore` through a defaulted init parameter, because the two
   `makeLive…` factories are separate and frozen. A left-down while any contact is down, or with
   no open expectation, passes.
5. **No measured delay yet.** No trace in `Fixtures/traces` or `Tests/GesturesTests/Fixtures`
   has a `buttonDown` frame, so I can't read the lift-to-click delay offline. Gabriel should
   record a tap-to-click with `edgy-trace` on device so the 0.5 s window can be checked.
6. **Existing guard tests stay untouched.** Keep the `install` / `handleTap` signatures and only
   add `TapEventKind` cases. Expire expectations by comparing timestamps at click time, with no
   timer. Only the "swallowed down with no up" safety release uses the scheduler.
