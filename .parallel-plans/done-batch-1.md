---
batch: 1
tag: EDGY-TOUCH
branch: feat/edgy-v01-batch-1
completed_at: 2026-11-03 23:17
verification: pass
---
## Acceptance criteria
- [✓] Private-framework bridge — `Sources/TouchKit/MultitouchBridge.swift`: framework loaded by path via `CFBundleCreate`, every function resolved by name (`MTDeviceCreateList`, `…GetDeviceID`, `…GetFamilyID`, `…IsBuiltIn`, `…GetSensorSurfaceDimensions`, `MTRegisterContactFrameCallback[WithRefcon]`, `MTUnregisterContactFrameCallback`, `MTDeviceStart/Stop`, `MTDeviceScheduleOnRunLoop`); each miss logged, missing core symbols → `TouchKitError.multitouchUnavailable(reason:)` thrown from `start`. Contact record mirrored in `RawContact.swift` with a documented offset table (96-byte stride), read by explicit offset, and validated on every callback (frame field of records 0 and 1 must equal the callback's frame arg → proves the stride; 3 consecutive failures disable that device with a fault log).
- [✓] Conversion raw → `TouchContact`/`TouchFrame` (`ContactConversion.swift`): clamped normalized position, velocity, state mapping (all 8 raw states + unknown), ellipse axes → mm with major ≥ minor. mm scale is learned per device from the record's own normalized-vs-device-unit velocity ratio × sensor size (offset-independent); sensor size comes from the device (`GetSensorSurfaceDimensions`, hundredths of mm), falling back to a per-family table (`DeviceCatalog.swift`) with a log line.
- [✓] Device manager (`DeviceManager.swift`): enumerate → `TouchDeviceInfo` (built-in / external trackpad / mouse / unknown), diff by ID (added / removed / changed / unchanged), registers each live device exactly once, unregisters removed ones, retries failed registrations, re-registers everything on wake; `onDevicesChanged` fires on start and on every actual change. Live notifier (`LiveDeviceChangeNotifier.swift`): IOKit first-match + terminated on `AppleMultitouchDevice`, workspace wake notification, debounced refreshes.
- [✓] `makeLiveTouchSource()` returns `LiveTouchSource`.
- [✓] `makeLivePointerGuard()` returns `PointerGuardCore` over a live HID-level event tap (`LiveSystem.swift`) swallowing mouse-moved/dragged while engaged, warp-back to the engage point on release, idempotent engage/release, 3 s safety timeout (stale timers can't release a newer engagement), tap re-enabled when the system disables it, tap creation behind `EventTapping` (fake in tests), lazily installed and retried if Accessibility is missing.
- [✓] `makeLiveTypingActivitySource()` returns `TypingActivityCore` over global + local key-down monitors; nil when Accessibility is missing (permission check cached 2 s) and nil before any key press.
- [✓] `edgy-trace record | devices | live` (`Sources/EdgyTrace/main.swift`), writing `TraceFile`. The recorder itself lives in TouchKit (`TraceRecorder.swift`) so it's testable (Package.swift is frozen; no EdgyTrace test target).
- [✓] `scripts/smoke-touch.sh` (build, devices, live, permission checklist, `start-check` mode).
- [✓] `scripts/record-traces.md` — all 11 required labels with physical instruction + expectation text + exact command.
- [✓] ≥ 10 new tests: **44 new** in `Tests/TouchKitTests/` (raw layout/stride validation, conversion incl. mm + state mapping, axis-scale learning, catalog, device diff add/remove/same/changed, manager registration bookkeeping incl. wake/retry/duplicates/stop/restart, pointer-guard state machine incl. idempotence/timeout/stale-timer/re-enable/install-failure, typing source, recorder round-trip through a temp file).
- [✓] No test calls MultitouchSupport, IOKit, event taps or cursor APIs — tests only construct cores with fakes (`Fakes.swift`); live types are internal and never instantiated in tests.
- [✓] Verification triple green (below).
- [✓] `Fixtures/traces/` left with `.gitkeep` only — no synthetic data posing as real recordings.

## Verification
- `swift build` — clean, no warnings
- `swift test` — all targets pass; TouchKitTests: 45 tests / 8 suites (44 new + existing `moduleLinks`)
- `swift format lint --strict -r Sources Tests Package.swift` — exit 0
- Denylist `git grep` — no matches

## Needs Gabriel (manual steps)
- Grant Accessibility to the signed Edgy build (and the terminal, for `edgy-trace`).
- `scripts/smoke-touch.sh` — confirm frames stream and a fingertip reads ~8–15 mm major axis, a palm clearly more.
- `scripts/smoke-touch.sh start-check` — answers whether `MTDeviceStart` is required (see open question 1).
- Unplug + replug the Magic Trackpad during `edgy-trace live`; sleep/wake during `live` — frames must resume both times.
- Record the 11 traces in `scripts/record-traces.md` and commit them to `Fixtures/traces/`.

## Diff summary
20 files, +2316/−5, all inside the batch glob. TouchKit: raw layout (`RawContact.swift`), conversion + axis-scale estimator, device catalog, device manager + protocols, pointer-guard core, typing core, recorder + frame formatter, logging/errors; live adapters in `MultitouchBridge.swift`, `LiveDeviceChangeNotifier.swift`, `LiveSystem.swift`; factory bodies replaced (signatures untouched). Added one public helper `isAccessibilityTrusted()` (non-prompting) for the CLI and the app. EdgyTrace CLI; smoke script; recording guide.

## Surprises / learnings (1–3)
- Enumeration works on this machine with no permission: `edgy-trace devices` listed a Magic Trackpad 2 (family 129) whose **reported** sensor size is 156.0 × 110.4 mm, so the per-family table is fallback-only. The framework also prints a "Recognized family (30 cols × 22 rows)" line on load.
- C callbacks can't capture `Self` — the refcon flavour carries an `Unmanaged` context; unregistered contexts are kept alive (tiny) because a callback may already be in flight on the device thread.

## Open questions
1. **Is `MTDeviceStart` required?** Unanswered on hardware (needs a human touching the pad). The bridge calls it by default after registering; `EDGY_MT_SKIP_START=1` disables it and `smoke-touch.sh start-check` runs both variants back-to-back.
2. Ellipse-axis units: assumed to share the record's device units with absolute position, calibrated from velocity. If the smoke check shows fingertips far outside 8–15 mm, a fixed correction factor goes in `AxisScaleEstimator`.
2b. Layout check kill switch: if the "frame field equals callback frame" assumption is wrong on real hardware, devices go silent after 3 frames with a fault in `log stream --predicate 'subsystem == "app.edgy"'`. `EDGY_MT_SKIP_LAYOUT_CHECK=1` bypasses it; the smoke script's start-check prints these instructions.
2c. Velocity is passed through as the device's normalized velocity, assumed per second — units unverified on hardware. The Gestures batch should treat velocity thresholds as provisional until traces are recorded.
3. Callback thread: by default frames arrive on the framework's own thread (no run-loop scheduling). `EDGY_MT_RUNLOOP=1` schedules on the main run loop instead. The App batch's router must be thread-safe either way.
