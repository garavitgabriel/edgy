---
batch: 2
tag: EDGY-GESTURE
branch: feat/edgy-v01-batch-2
completed_at: 2026-11-03 23:59
verification: pass
---
## Acceptance criteria
- [✓] Zone geometry in mm from `sensorSizeMM` + `GestureSettings`: edge strips, corners (always take precedence), segments (`Sources/Gestures/ZoneGeometry.swift`)
- [✓] Per-contact tracking across frames: birth time, position, role, palm flag, origin zone (`Track` / `Candidate` in `GesturePipeline.swift`)
- [✓] Misfire defense, each with its `RejectionReason`: start-in-zone (`startedOutsideZone`), unmapped (`disabledZone`), palm gate by major axis + minor-axis/size/density outliers (`palm`), contact count incl. 3+ always rejected (`tooManyContacts`), typing window (`typing`), intent gate: dwell or along-axis-dominant claim, inward perpendicular → `systemGestureHandoff`, other off-axis → `offAxisMotion`, initial flick → swipe candidate, `tooFast` when it is neither
- [✓] Hysteresis: dead band at rest + rest detection while moving
- [✓] Recognizers: slide (began/changed/ended/cancelled, normalized signed delta, +toward top/right), swipe, tap, double-tap, long-press; corners do tap/double-tap/long-press only
- [✓] `claimedContactIDs` non-empty exactly while a slide/long-press owns a finger — asserted on every frame (`expectClaimsFollowSlide`, long-press frame-by-frame check)
- [✓] `makeGestureRecognizer()` returns `GesturePipeline` (signature unchanged)
- [✓] Test-only `TraceBuilder` (mm keyframes, 120 Hz, configurable ellipse + growth, size/density, deterministic jitter)
- [✓] 30 tests in `Tests/GesturesTests/` (≥ 15), including all 16 named scenarios:
  `deliberateSlideRightUpProducesPositiveDeltas`, `deliberateSlideLeftDownProducesNegativeDeltas`, `palmRestOnRightEdgeIsRejected`, `twoFingerScrollNearEdgeIsRejected`, `inwardSwipeFromRightEdgeHandsOffToSystem`, `touchDriftingIntoZoneIsRejected`, `touchWhileTypingIsRejected`, `doubleTapTopRightCornerFires`, `singleTapDoesNotFireDoubleTap`, `longPressTopLeftCornerFires`, `bottomEdgeSwipeLeftAndRight`, `segmentedEdgeRoutesToCorrectSegment`, `cornerTakesPrecedenceOverEdge`, `unmappedZoneNeverClaims`, `slideAtRestDoesNotJitter`, `pipelineIsDeterministic`
- [✓] 6 named scenarios load JSON fixtures via `TraceFile.load` from `Tests/GesturesTests/Fixtures/` (slide-right-up, palm, two-finger scroll, inward swipe, double-tap, determinism). 5 fixtures committed; `fixturesMatchTraceBuilder` keeps them in sync (`EDGY_REGENERATE_FIXTURES=1 swift test --filter fixturesMatchTraceBuilder` rewrites them)
- [✓] No system frameworks in `Sources/Gestures/` — every file imports only `EdgyCore` (not even Foundation)
- [✓] Verification triple green
- [✓] Mutation check: with the factory swapped to the no-op recognizer, the scenario tests fail (then restored)

## Verification
- build: `swift build` → Build complete, exit 0
- test: `swift test` → exit 0; GesturesTests 30 tests (16 named + 13 extra + the kept `moduleLinks`), all suites pass
- lint: `swift format lint --strict -r Sources Tests Package.swift` → exit 0
- denylist: no hits (scanned Sources, Tests, .parallel-plans, CLAUDE.md, Package.swift)

## Default thresholds (for tuning against real traces)
User settings (`GestureSettings.defaults`, unchanged): edge 8 mm, corner 12 mm, dwell 120 ms, palm major axis 18 mm, typing 500 ms, double-tap 300 ms, long-press 500 ms, fingers 1.

Internal (`Sources/Gestures/Tuning.swift`, `Tuning.standard`):
| Threshold | Default | Why |
|---|---|---|
| `stillRadiusMM` | 1.0 | Resting fingertip tremor is a few tenths of a mm; 1 mm leaves headroom without letting a real slide count as still |
| `alongClaimMM` | 2.0 | ~2 frames of a fast slide; far enough that sensor noise never claims |
| `axisDominance` | 2.0 | Along must be ≥ 2× perpendicular (~27° cone) to count as "clearly along-axis" |
| `perpendicularDecideMM` | 2.5 | Inward system swipes travel far and fast; 2.5 mm decides within ~2 frames |
| `diagonalDecideMM` | 3.0 | No dominant axis after 3 mm → reject instead of waiting forever |
| `flickSpeedMMPerS` | 180 | Deliberate slides measured in the 20–80 mm/s range; flicks are 200+ |
| `swipeMinTravelMM` | 6 | A real flick covers ≥ 6 mm; shorter fast twitches become `tooFast` |
| `swipeMaxDurationS` | 0.35 | A flick that hasn't lifted by then isn't a flick |
| `tapMaxDurationS` / `tapMaxTravelMM` | 0.25 / 1.5 | Typical taps are 60–200 ms with sub-mm travel |
| `longPressMaxTravelMM` | 1.5 | Same stillness as a tap |
| `cornerMaxTravelMM` | 3.0 | Corners have no motion gestures; drifting out of a corner rejects |
| `deadBandMM` | 0.8 | Above resting tremor; ~0.8% of a 95 mm edge, finer than a volume step |
| `restEpsilonMM` / `restDurationS` | 0.6 / 0.1 | Holding within 0.6 mm for 100 ms re-arms the dead band |
| `multiFingerWindowS` | 0.12 | Fingers of one multi-finger touch land within ~20–80 ms |
| `palmMinorAxisMM` | 14 | A blob this wide on both axes is not a fingertip |
| `palmSize` / `palmSoftSize` + `palmMaxDensity` | 2.5 / 1.5 + 0.1 | **Guesses** — the device's unitless size/density ranges are unknown until real traces exist |

## Needs Gabriel (manual steps)
- Record real traces (batch 1's recorder) for: palm rest on each edge, two-finger scroll near the right edge, inward system swipe, deliberate slides, corner taps — then drop them in `Fixtures/traces/` so the chief can replay them through `makeGestureRecognizer()` and tune `Tuning.standard` (especially the palm size/density values).

## Diff summary
- `Sources/Gestures/Tuning.swift` — internal thresholds + ms→s conversion of settings (done once per frame, so no comparison mixes units)
- `Sources/Gestures/ZoneGeometry.swift` — mm layout, region classification, zone resolution (finest mapped segmentation wins), zone length/position
- `Sources/Gestures/GesturePipeline.swift` — `GesturePipeline` (per-device state, sorted iteration for determinism), tracks, candidates, intent gate, slide output stage, recognizers, rejections
- `Sources/Gestures/Gestures.swift` — factory returns `GesturePipeline()`; `NoopGestureRecognizer` kept as an explicit off switch
- `Tests/GesturesTests/` — `TraceBuilder.swift`, `Harness.swift` (replay, claim invariant, fixtures), `ScenarioTests.swift` (16 named), `PipelineTests.swift` (13 extra), `Fixtures/*.json` (5)

## Surprises / learnings (1–3)
- The pipeline has no timers, so a tap can't wait out the double-tap window. Decision: first tap emits `.tap`, the second emits `.doubleTap` instead of another `.tap`.
- Rest detection needs a tolerance wider than the tremor's peak-to-peak range (0.6 mm against ±0.25 mm noise). Otherwise it resets on every frame and the slide never settles.

## Open questions
- **Per-kind enablement:** `GestureContext` gives zones, not (zone, kind) pairs. So a still finger in any mapped edge claims a slide after the dwell, even if that zone binds only swipe/tap. The pointer guard engages, and the router must accept `slide .began`/`.ended` with no slide binding. A `Set<Binding>`-like context would let the pipeline skip unbound recognizers.
- **Tap vs double-tap on one zone:** a zone that binds both fires the tap action on the first tap of a double-tap.
- **Edge tap longer than dwell:** a 120–250 ms tap in an edge emits `slide .began` → `slide .cancelled` → `.tap` (the slide never produced output).
- **Edge long-press:** a resting edge slide that hasn't moved by `longPressMS` also emits `.longPress` (the slide stays live).
- **Corners always win geometrically,** even when unmapped (→ `disabledZone`, no fall-through to the edge). With the default config, the corner ends of the left/right edges are dead. Fall-through would be a one-line change in `FrameStep.birth` if preferred.
- **Segments span the full edge length,** corner squares included. Slide `delta` and `position` are normalized to the segment's length.
- **Discrete gestures** emit exactly one event with phase `.ended` (long-press fires at the threshold, while the finger is still down).
- **Late extra contacts:** a contact that lands > 120 ms after a claimed slide doesn't cancel it (e.g. a resting thumb). One that lands together with it, or any 3rd contact, does.
