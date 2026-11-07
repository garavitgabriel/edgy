---
batch: 9
branch: worktree-edgy-gestures-v03
status: one item blocked; everything else done
---

# Blocker: telling a physical click from a touch

**Item:** brief §5, "physical click-and-drag starting in an edge strip (button-down while touching: treat as not-ours)".

**What the contracts expose today:** `TouchFrame` (deviceID, timestamp, frameNumber, contacts) and `TouchContact` (id, state, position, velocity, axes, angle, size, density). Nothing carries the trackpad button / force-click state. `size` and `density` are pressure *proxies* but a light touch and a click-and-drag overlap in both, so guessing from them would trade one misfire for another. `TraceFile` is built from these types, so a click can't even be recorded for tuning.

**Consequence today:** a click-drag along an edge strip (a window resize at the right edge, a text selection that starts low) looks exactly like a deliberate slide and claims after the dwell. A click-drag inward already hands off (`systemGestureHandoff`).

**Proposed contract addition (chief, on `main`):**

```swift
// Sources/EdgyCore/Touch.swift
public struct TouchFrame {
  …
  /// The device's physical button (or force click) is down. Optional in JSON so existing traces
  /// decode as `false`.
  public var buttonDown: Bool = false
}
```

- TouchKit fills it: the multitouch frame callback has no button field either, so the simplest source is a listen-only event tap for left-mouse-down/up from that device (or `NSEvent.pressedMouseButtons` sampled per frame — coarse but enough). Owner: EDGY-TOUCH.
- Gestures (me, once it lands): any candidate that sees `buttonDown` at any point before it claims is rejected with a new `RejectionReason.physicalClick` (also a frozen-contract addition) — or `systemGestureHandoff` if you'd rather not add a reason. A live claim seeing `buttonDown` is cancelled the same way a palm cancels it.
- The test is already written and disabled: `physicalClickAndDragStartingInAnEdgeStripIsNotOurs` in `Tests/GesturesTests/AdversarialTests.swift`; it needs `TraceBuilder` to emit `buttonDown` once the field exists.

Nothing else in batch 9 is blocked.
