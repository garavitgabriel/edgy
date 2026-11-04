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

## After the session

```bash
ls -la Fixtures/traces/
git add Fixtures/traces/*.json && git commit -m "fixtures: recorded touch traces"
```

Sanity check while recording: in `swift run edgy-trace live`, a resting fingertip should show a
major axis of roughly 8–15 mm and a palm clearly more. If not, note the numbers — the axis
conversion (device units → mm) is calibrated from the device's own velocity readouts and may
need a correction factor.
