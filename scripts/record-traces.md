# Recording session — touch traces

Real recordings for the misfire-defense regression tests. Each run writes one `TraceFile` JSON to
`Fixtures/traces/<label>.json`. About 20 minutes total.

## Before you start

1. `swift build --product edgy-trace`
2. `swift run edgy-trace devices` — note the built-in trackpad's `id`. Add `--device <id>` to every
   command below if more than one device is listed (default: built-in, else the first device).
3. Sit normally, hands in typing position. Each command counts down 3 s, then records for
   `--seconds`. Start the motion right after "● recording … go".
4. If a take goes wrong, just re-run the same command — it overwrites the file.
5. After each take, the command prints the frame count. Zero frames → run `scripts/smoke-touch.sh start-check`.

Each block: what to physically do, then the exact command (the `--expect` text is what the
gesture pipeline must do with it).

## 1. `deliberate-slide-right-up`

Index finger on the right edge strip, lower third. Slide straight up along the edge, steady speed,
~1 s, lift.

```bash
swift run edgy-trace record --label deliberate-slide-right-up --seconds 4 --out Fixtures/traces/deliberate-slide-right-up.json \
  --expect "One finger starts in the right edge and slides up along it. Expect: right-edge slide-up claimed, continuous slide output, pointer guarded."
```

## 2. `deliberate-slide-left-down`

Index finger on the left edge strip, upper third. Slide straight down along the edge, ~1 s, lift.

```bash
swift run edgy-trace record --label deliberate-slide-left-down --seconds 4 --out Fixtures/traces/deliberate-slide-left-down.json \
  --expect "One finger starts in the left edge and slides down along it. Expect: left-edge slide-down claimed, continuous slide output, pointer guarded."
```

## 3. `palm-rest-right`

Type a sentence, then let the right palm come to rest on the right side of the trackpad and stay
there, still, for ~3 s. Lift.

```bash
swift run edgy-trace record --label palm-rest-right --seconds 6 --out Fixtures/traces/palm-rest-right.json \
  --expect "A resting right palm covers the right edge with no deliberate motion. Expect: nothing fires; palm gate rejects the contact."
```

## 4. `palm-rest-left-while-typing`

Type continuously for the whole take (any text, into any text field) with the left palm brushing
and resting on the left edge of the trackpad.

```bash
swift run edgy-trace record --label palm-rest-left-while-typing --seconds 8 --out Fixtures/traces/palm-rest-left-while-typing.json \
  --expect "Left palm brushes and rests on the left edge while typing. Expect: nothing fires; typing suppression and palm gate both reject."
```

## 5. `two-finger-scroll-near-right-edge`

Two fingers close to (touching) the right edge. Scroll up and down a few times as you would in a
long page.

```bash
swift run edgy-trace record --label two-finger-scroll-near-right-edge --seconds 5 --out Fixtures/traces/two-finger-scroll-near-right-edge.json \
  --expect "Two-finger scroll right next to the right edge. Expect: nothing fires; contact-count gate rejects, system scroll unaffected."
```

## 6. `system-swipe-in-from-right`

The system's own two-finger swipe in from the right edge (the gesture that opens the notification
panel): two fingers start on the far right and move left, inward. Close the panel afterwards.

```bash
swift run edgy-trace record --label system-swipe-in-from-right --seconds 4 --out Fixtures/traces/system-swipe-in-from-right.json \
  --expect "Two fingers swipe inward from the right edge (system gesture). Expect: nothing fires; inward motion hands off to the system."
```

## 7. `drift-into-right-edge`

Normal one-finger pointer movement that starts in the middle of the trackpad and drifts rightward
into the right edge strip, then continues a little up. Lift.

```bash
swift run edgy-trace record --label drift-into-right-edge --seconds 4 --out Fixtures/traces/drift-into-right-edge.json \
  --expect "Pointer movement starts mid-pad and drifts into the right edge. Expect: nothing fires; touches must start in the zone."
```

## 8. `double-tap-top-right-corner`

Two quick light taps in the top-right corner, same spot, normal double-click rhythm.

```bash
swift run edgy-trace record --label double-tap-top-right-corner --seconds 3 --out Fixtures/traces/double-tap-top-right-corner.json \
  --expect "Two quick taps in the top-right corner. Expect: top-right corner double-tap fires once; no single-tap first."
```

## 9. `single-tap-bottom-edge`

One light tap in the middle of the bottom edge strip.

```bash
swift run edgy-trace record --label single-tap-bottom-edge --seconds 3 --out Fixtures/traces/single-tap-bottom-edge.json \
  --expect "One light tap on the middle of the bottom edge. Expect: bottom-edge single tap fires once."
```

## 10. `swipe-bottom-edge-left`

One finger starts in the bottom edge strip, right of centre, and flicks quickly left along the edge.

```bash
swift run edgy-trace record --label swipe-bottom-edge-left --seconds 3 --out Fixtures/traces/swipe-bottom-edge-left.json \
  --expect "Quick one-finger flick leftward along the bottom edge. Expect: bottom-edge swipe-left fires once (not a slide)."
```

## 11. `long-press-top-left-corner`

One finger presses and holds still in the top-left corner for ~1.5 s, then lifts.

```bash
swift run edgy-trace record --label long-press-top-left-corner --seconds 4 --out Fixtures/traces/long-press-top-left-corner.json \
  --expect "One finger holds still in the top-left corner for about 1.5 s. Expect: top-left corner long-press fires once, on the hold."
```

## On an external trackpad (desktop Mac or a second device)

Every scenario above and below can be recorded on an external trackpad too; edges and corners are
measured in millimetres, so the same expectations apply.

1. `swift run edgy-trace devices` and note the external trackpad's `id` (kind `externalTrackpad`).
2. Add `--device <id>` to every command, and append `-external` to both the `--label` and the file
   name, e.g. `--label long-press-top-left-corner-external --out Fixtures/traces/long-press-top-left-corner-external.json`.
   The replay test strips `-external` / `-builtin` and applies the scenario's assertion.
3. The external pad is larger, so a 12 mm corner is a smaller share of it — but users reported the
   corner feeling large. Record scenario 21 there first.

## v0.3 scenarios — misfire hardening and holds

Same routine. These mirror the synthetic tests in `Tests/GesturesTests/AdversarialTests.swift`;
the recordings tell us whether the thresholds hold on real hands.

### 12. `thumb-rest-bottom-index-moves`

Rest your thumb on the bottom edge strip (as you do while clicking), keep it there, and move the
pointer around with the index finger for a few seconds.

```bash
swift run edgy-trace record --label thumb-rest-bottom-index-moves --seconds 6 --out Fixtures/traces/thumb-rest-bottom-index-moves.json \
  --expect "Thumb rests on the bottom edge while the index finger moves the pointer. Expect: nothing fires, nothing claimed."
```

### 13. `thumb-rest-right-index-moves`

Same, but the thumb (or a finger) rests on the right edge strip for a full second *before* the
index finger lands and moves the pointer.

```bash
swift run edgy-trace record --label thumb-rest-right-index-moves --seconds 6 --out Fixtures/traces/thumb-rest-right-index-moves.json \
  --expect "A finger rests on the right edge, then another finger moves the pointer. Expect: the resting finger's claim is let go as soon as the other finger moves; no volume change."
```

### 14. `two-finger-scroll-drift-into-right-edge`

Two-finger scroll that starts mid-pad and drifts right until one finger is in the right edge strip.

```bash
swift run edgy-trace record --label two-finger-scroll-drift-into-right-edge --seconds 5 --out Fixtures/traces/two-finger-scroll-drift-into-right-edge.json \
  --expect "Two-finger scroll drifts into the right edge. Expect: nothing fires; touches must start in the zone."
```

### 15. `three-finger-swipe-from-right-edge`

Three fingers start at the right edge and swipe left (switch Spaces / full-screen apps).

```bash
swift run edgy-trace record --label three-finger-swipe-from-right-edge --seconds 4 --out Fixtures/traces/three-finger-swipe-from-right-edge.json \
  --expect "Three-finger swipe starting at the right edge. Expect: nothing fires; contact-count gate rejects."
```

### 16. `four-finger-swipe-up-from-bottom`

Four fingers start low on the pad (touching the bottom edge strip) and swipe up (Mission Control).

```bash
swift run edgy-trace record --label four-finger-swipe-up-from-bottom --seconds 4 --out Fixtures/traces/four-finger-swipe-up-from-bottom.json \
  --expect "Four-finger swipe up starting at the bottom edge. Expect: nothing fires."
```

### 17. `three-finger-swipe-sideways-low`

Three fingers low on the pad, swipe sideways along the bottom.

```bash
swift run edgy-trace record --label three-finger-swipe-sideways-low --seconds 4 --out Fixtures/traces/three-finger-swipe-sideways-low.json \
  --expect "Three-finger sideways swipe along the bottom edge. Expect: no media swipe fires."
```

### 18. `palm-land-left-while-typing`

Type, and mid-sentence let the left palm land on the left edge of the trackpad.

```bash
swift run edgy-trace record --label palm-land-left-while-typing --seconds 6 --out Fixtures/traces/palm-land-left-while-typing.json \
  --expect "Left palm lands on the left edge mid-typing. Expect: nothing fires (the recording has no typing signal, so the palm gate must catch it alone)."
```

### 19. `inward-swipe-from-right-one-finger`

One finger starts at the far right and moves left into the pad at a relaxed speed.

```bash
swift run edgy-trace record --label inward-swipe-from-right-one-finger --seconds 4 --out Fixtures/traces/inward-swipe-from-right-one-finger.json \
  --expect "One finger moves inward from the right edge. Expect: nothing fires; handed off to the system."
```

### 20. `long-press-drift-top-left`

Put a finger in the top-left corner and let it creep slowly (2–3 mm over a second) instead of
holding still. Hard to do on purpose: think "resting, not pressing".

```bash
swift run edgy-trace record --label long-press-drift-top-left --seconds 4 --out Fixtures/traces/long-press-drift-top-left.json \
  --expect "A finger creeps slowly in the top-left corner. Expect: no long-press."
```

### 21. `tap-corner-edge-boundary-top-right`

Tap a few times right where the top-right corner meets the right edge (about 12 mm down from the
top), a second apart. No assertion yet — it shows where real taps land relative to the line.

```bash
swift run edgy-trace record --label tap-corner-edge-boundary-top-right --seconds 6 --out Fixtures/traces/tap-corner-edge-boundary-top-right.json \
  --expect "Taps on the line between the top-right corner and the right edge. Expect: each tap goes to exactly one zone (corner inside its 12 mm square)."
```

### 22. `push-to-talk-hold-bottom-left`

Press and hold the bottom-left corner for ~2 s as if talking, letting the finger shift a little,
then lift.

```bash
swift run edgy-trace record --label push-to-talk-hold-bottom-left --seconds 5 --out Fixtures/traces/push-to-talk-hold-bottom-left.json \
  --expect "Hold the bottom-left corner about 2 s. Expect: one hold, began then ended at lift."
```

## v0.4 scenarios — physical clicks and taps that wait

Frames now carry `buttonDown` (the live line shows `BUTTON` while the trackpad is clicked), so a
click can be recorded. For each click take, press until the trackpad clicks; on a force-touch pad,
a firm press is enough. Record each on both trackpads (`-external` suffix on the Magic Trackpad).

### 23. `click-drag-right-edge`

Click down inside the right edge strip and drag up along it, as when resizing a window from its
right side. Keep the button down for the whole drag.

```bash
swift run edgy-trace record --label click-drag-right-edge --seconds 4 --out Fixtures/traces/click-drag-right-edge.json \
  --expect "Physical click-and-drag up the right edge. Expect: nothing fires, nothing claimed."
```

### 24. `click-drag-left-edge`

Same on the left edge, dragging down.

```bash
swift run edgy-trace record --label click-drag-left-edge --seconds 4 --out Fixtures/traces/click-drag-left-edge.json \
  --expect "Physical click-and-drag down the left edge. Expect: nothing fires, nothing claimed."
```

### 25. `click-drag-top-edge`

Click inside the top edge strip and drag right along it (selecting text in the top line of a
window).

```bash
swift run edgy-trace record --label click-drag-top-edge --seconds 4 --out Fixtures/traces/click-drag-top-edge.json \
  --expect "Physical click-and-drag right along the top edge. Expect: nothing fires, nothing claimed."
```

### 26. `click-drag-bottom-edge`

Click inside the bottom edge strip and drag left along it (the thumb-click-and-drag many people
use on a trackpad).

```bash
swift run edgy-trace record --label click-drag-bottom-edge --seconds 4 --out Fixtures/traces/click-drag-bottom-edge.json \
  --expect "Physical click-and-drag left along the bottom edge. Expect: nothing fires, nothing claimed."
```

### 27. `click-top-right-corner`

Click once in the top-right corner without moving: press, click, release, lift. Do it three
times, a second apart.

```bash
swift run edgy-trace record --label click-top-right-corner --seconds 5 --out Fixtures/traces/click-top-right-corner.json \
  --expect "Three plain clicks in the top-right corner. Expect: no tap, no double-tap."
```

### 28. `force-click-top-left-corner`

Rest a finger in the top-left corner and press through to a force click (or a firm click) within
about a quarter second; hold it down for about 1 s, then lift.

```bash
swift run edgy-trace record --label force-click-top-left-corner --seconds 4 --out Fixtures/traces/force-click-top-left-corner.json \
  --expect "Force click held in the top-left corner. Expect: no hold (long-press) fires."
```

### 29. `tap-then-double-tap-top-right`

With **tap-to-click off and then again with it on** (record twice; add `-taptoclick` to the
second label and file name), tap the top-right corner once, wait about 1 s, then double-tap it.
The replay test binds both a tap and a double-tap there, so the single tap waits for the
double-tap window.

```bash
swift run edgy-trace record --label tap-then-double-tap-top-right --seconds 4 --out Fixtures/traces/tap-then-double-tap-top-right.json \
  --expect "One tap, a pause, then a double-tap, top-right corner. Expect (taps wait): tap, then one double-tap."
```

With tap-to-click on, watch the live line: if `BUTTON` shows while the finger is still down
during a plain tap, taps would be rejected as clicks; note it in the done report.

## Batch 20 scenarios — slide feel and holds

No traces were in `Fixtures/traces/` when batch 20 was built, so `longPressMaxTravelMM` (1.0 mm), the
end band (`endBandMM` 6 mm, at most a fifth of a zone) and the speed curve (`SlideFeel`: gain from
60 to 300 mm/s, 3× stepped, 1.6× levels) are still first guesses. Record these on **both** the Magic
Trackpad and the MacBook's built-in pad (add `-builtin` / `-magic` to label and file name).

### 30. `short-strokes-right-edge`

Five or six short upward strokes on the right edge, about 5–8 mm each, lifting between them with
pauses of about 0.2–0.4 s (how you'd walk the app switcher).

```bash
swift run edgy-trace record --label short-strokes-right-edge --seconds 6 --out Fixtures/traces/short-strokes-right-edge.json \
  --expect "Short repeated strokes up the right edge. Expect: one slide per stroke, each began/changed/ended."
```

Check in the replay: how long the gap between lift and the next claim really is (sets the
`keepOpenMS` default of 400 ms).

### 31. `flick-vs-slow-right-edge`

One slow slide up the right edge (about 3 s for half the edge), lift, then the same distance as a
quick flick that keeps the finger down at the end (not a swipe-and-lift).

```bash
swift run edgy-trace record --label flick-vs-slow-right-edge --seconds 8 --out Fixtures/traces/flick-vs-slow-right-edge.json \
  --expect "Slow slide, then a quick flick-and-stay. Expect: two slides; the flick's speed peaks well above 300 mm/s."
```

### 32. `rest-at-top-end-right`

Slide up the right edge all the way to the top and keep the finger resting at the very end for
about 2 s, then slide back down a little and lift.

```bash
swift run edgy-trace record --label rest-at-top-end-right --seconds 6 --out Fixtures/traces/rest-at-top-end-right.json \
  --expect "Slide to the top end and rest. Expect: atEnd +1 on every frame while resting, none after moving back."
```

Check in the replay: how far from the physical end the finger really rests (sets `endBandMM`), and
how much it wanders while "still" (sets `restEpsilonMM`).

### 33. `hold-corner-while-pointing`

Hold the bottom-left corner with the thumb for about 1 s, then, still holding, move the pointer in
circles with the index finger for 3 s; lift the index, then the thumb.

```bash
swift run edgy-trace record --label hold-corner-while-pointing --seconds 7 --out Fixtures/traces/hold-corner-while-pointing.json \
  --expect "Thumb holds the corner, index points. Expect: hold began, survives the pointing, ends at thumb lift."
```

Check in the replay: how far the held thumb drifts while the index moves (sets
`longPressMaxTravelMM`, and whether a hold that has begun needs any drift limit at all).

### 34. `push-to-talk-300ms-bottom-edge`

Press and hold the bottom edge for about 0.3–0.4 s at a time, three times, as you would to talk
briefly (with a 300 ms hold bound there).

```bash
swift run edgy-trace record --label push-to-talk-300ms-bottom-edge --seconds 6 --out Fixtures/traces/push-to-talk-300ms-bottom-edge.json \
  --expect "Three short holds on the bottom edge. Expect (holdMS 300): three holds, no slides."
```

## After the session

```bash
ls -la Fixtures/traces/
git add Fixtures/traces/*.json && git commit -m "fixtures: recorded touch traces"
```

Sanity check while recording: in `swift run edgy-trace live`, a resting fingertip should show a
major axis of roughly 8–15 mm and a palm clearly more. If not, note the numbers — the axis
conversion (device units → mm) is calibrated from the device's own velocity readouts and may
need a correction factor.
