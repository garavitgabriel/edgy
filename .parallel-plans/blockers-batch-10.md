---
batch: 10
branch: worktree-edgy-gestures-v04
status: nothing blocked in my glob; one wiring step for the chief (Engine, off-limits to me)
---

# Hand-off: the engine must wake the recognizer for a waiting tap

**Item:** brief §3, "the pending tap must be emitted on a later `process` call driven by time".

**What's done (in my glob):** the pipeline holds a tap in `context.doubleTapZones` and releases it
on any later frame from that device once the window has passed, or as soon as anything else
happens in that zone. It also adopts a new **additive** public protocol in `Sources/Gestures/Gestures.swift`.
The frozen `GestureRecognizing` and `makeGestureRecognizer()` are unchanged:

```swift
public protocol DeferredGestureFlushing: AnyObject {
  var nextFlushDeadline: Double? { get }          // frame clock; nil = nothing to wake for
  func flush(now: Double) -> GestureOutput        // releases what is due; idempotent
}
```

**Why the engine has to act:** a device stops sending frames shortly after the last finger lifts.
A single tap in a waiting zone would otherwise sit until the next touch. Engine is outside my glob.

**Smallest wiring (Engine, chief or batch 12):**

1. `doubleTapZones: zones(bound: .doubleTap, in: profile)` in the `GestureContext` (batch 12's brief §3
   already owns this). Until it's passed, `nil` means no zone waits, so nothing regresses.
2. After each `process` (and each `flush`), if
   `(recognizer as? DeferredGestureFlushing)?.nextFlushDeadline` is non-nil, schedule a one-shot
   on the engine queue for `deadline − lastFrame.timestamp` seconds after the last frame arrived.
   Cancel or ignore it if a newer frame arrives first; re-reading the deadline handles that.
3. When it fires, compute `now = lastFrame.timestamp + (monotonic now − monotonic arrival of lastFrame)`,
   call `flush(now:)`, and handle the output exactly like a `process` output: pointer guard from
   `claimedContactIDs` (all devices' live claims), route `events` with the current frontmost app's
   profile, log rejections (there are none).
   **Your call:** a flushed tap happened under the profile active at lift, but it's routed under the
   profile at flush time, about 300 ms later. If the frontmost app changed in between, it lands in
   the new app's binding. That's the same tradeoff the engine already makes for holds across an app
   switch. If you'd rather drop it, compare the frontmost bundle at the last frame against flush time
   and discard on a change.
4. `quiesce()` already calls `recognizer.reset()`, which drops pending taps. Cancel the timer there too.

A test for the engine side: a fake recognizer that adopts `DeferredGestureFlushing`, or the real one
with a tap in a waiting zone and no further frames. Expect exactly one `.tap` routed after the window.
