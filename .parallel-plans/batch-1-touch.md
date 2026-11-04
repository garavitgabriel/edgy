# Batch 1 — EDGY-TOUCH: live touch input

Read `CLAUDE.md` and `.parallel-plans/2026-11-03-2131-edgy-v01.md` first.

## Build
1. **Private-framework bridge** (`Sources/TouchKit/`): load MultitouchSupport by path, resolve the functions listed in the brief by name, mirror the C contact struct in Swift with care (document field offsets + sizes you rely on, and validate the struct size at runtime against the callback's per-contact stride where possible). Determine whether `MTDeviceStart` is needed and record the answer in your done report.
2. **Conversion** raw → `TouchContact` / `TouchFrame`: normalized position + velocity, ellipse axes converted to mm using the device's sensor dimensions (find a way to read them; fall back to a per-family-ID table and log it), states mapped to `TouchContact.State`.
3. **Device manager**: enumerate devices into `TouchDeviceInfo` (kind: built-in / external trackpad / mouse), IOKit add/remove notifications, re-enumerate on sleep/wake, re-register callbacks without leaking or double-registering. `onDevicesChanged` fires on every change.
4. **`makeLiveTouchSource()`** returns the live source.
5. **Pointer guard** (`makeLivePointerGuard()`): active event tap that swallows mouse-moved/drag events while engaged and warps back to the engage point on release; idempotent engage/release; auto-release safety timeout (e.g. 3 s) so a lost `release()` can never strand the cursor; tap re-enable if the system disables it. The tap creation must be behind an internal protocol so tests run with a fake.
6. **Typing source** (`makeLiveTypingActivitySource()`): last key-down time via a global key monitor; nil when permission is missing.
7. **Trace recorder CLI** (`Sources/EdgyTrace/`): `swift run edgy-trace record --label <kebab> --expect "<text>" --seconds <n> --out Fixtures/traces/<label>.json` writing the `TraceFile` schema; `edgy-trace devices` lists devices; `edgy-trace live` prints a compact per-frame line.
8. `scripts/smoke-touch.sh` (manual): builds, runs `edgy-trace devices` and `live`, prints the permission checklist.
9. `scripts/record-traces.md`: the exact recording session for Gabriel — at minimum these labels: `deliberate-slide-right-up`, `deliberate-slide-left-down`, `palm-rest-right`, `palm-rest-left-while-typing`, `two-finger-scroll-near-right-edge`, `system-swipe-in-from-right`, `drift-into-right-edge`, `double-tap-top-right-corner`, `single-tap-bottom-edge`, `swipe-bottom-edge-left`, `long-press-top-left-corner` — each with the physical instruction and the expectation text.

## Acceptance (proof = code + tests, never hardware)
- ≥ 10 new tests in `Tests/TouchKitTests/`, all on synthetic data/fakes: raw→contact conversion (incl. mm conversion and state mapping), device-list diffing (add / remove / same), callback re-registration bookkeeping, pointer-guard state machine (engage/release idempotent, safety timeout releases, re-enable on disable), recorder writes a `TraceFile` that round-trips.
- No test calls the real MultitouchSupport, IOKit notifications, event taps, or cursor APIs.
- Factories return live implementations.
- Verification triple green.
- Done report "Needs Gabriel": grant Accessibility to the signed build, run `scripts/smoke-touch.sh`, unplug/replug a Magic Trackpad, sleep/wake, record the traces in `scripts/record-traces.md`.
