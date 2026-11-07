# Batch 9 — EDGY-GESTURES-2: hold gestures, misfire hardening, machine-aware routing

Read `CLAUDE.md` and `.parallel-plans/2026-11-06-edgy-v03.md` first. You own `Sources/Gestures/**`, `Tests/GesturesTests/**`, `Sources/EdgyRuntime/**`, `Tests/EdgyRuntimeTests/**`, `Fixtures/traces/**`, `scripts/record-traces.md`. Read `done-batch-2.md` (gesture thresholds and why) and `done-batch-6.md` (settings layer) before changing anything.

## Build

1. **Long-press lifecycle** (contract on main): emit `.longPress` `.began` at recognition (where today's single `.ended` fires), then `.ended` when the finger lifts, `.cancelled` if the touch is taken away (palm, extra fingers, pause/reset). The claim (pointer guard) is held until the end. Update existing long-press tests to the new phases; don't weaken what they check.
2. **Router + hold actions.** Discrete trigger actions on long-press keep firing exactly once, at `.began` (already supported). For `.hold` actions: `.began` → `.press(down: true)` (+ `actionFired` haptic), `.ended`/`.cancelled` → `.press(down: false)`. Guarantee pairing: `Router.reset()`, pause, config reload, profile switch (frontmost app changes mid-hold) and engine stop all send the pending `down: false` before forgetting.
3. **Validation + queries for `.hold`.** `hold` ↔ `.longPress` only (`shapeMismatch` otherwise); `compatibleActions` / `supportedGestures` know it. Keep issue codes stable (add none unless needed; if you add, document).
4. **Availability-aware runtime.** `SettingsEditor` exposes `availability(of:)` for the catalog (pass-through to `ActionPerforming`), and a `machineDefaults(from:)` builder: start from `EdgyConfig.defaults` and replace any binding whose action is unavailable with a sensible available alternative (document the substitution table; e.g. left-edge brightness → left-edge `keyboard.slideSteps` zoom only if nothing better — propose, don't over-think; the chief wires it on first run). Validation adds a **warning** (not error) for a binding whose action is unavailable on this Mac (new code `actionUnavailable`, document it).
5. **Misfire hardening.** Add adversarial scenarios via `TraceBuilder`, each a named test asserting no claim / the right rejection: thumb resting on the bottom edge while the index finger scrolls/moves elsewhere; two-finger scroll that drifts into the right edge; three/four-finger system swipes that start near an edge; physical click-and-drag starting in an edge strip (button-down while touching: treat as not-ours — check what `TouchFrame`/contacts expose; if nothing distinguishes a click, document and propose a contract addition instead of guessing); palm landing while typing; inward swipe from the right edge (system panel); a long-press that drifts slowly (must not fire); a tap that lands on the boundary between corner and edge (document which wins and why — users found the 12 mm corner large on an external trackpad). Fix whatever fails, with the smallest threshold or logic change, each documented in the done report with before/after.
6. **Real traces.** If `Fixtures/traces/*.json` exist when you start or appear during the batch (Gabriel may record on the Mac mini with a Magic Trackpad), add replay tests for each, asserting its `expectation`. Update `scripts/record-traces.md` for an external trackpad (`--device`), and add scenarios from item 5 to the recording list.

## Acceptance
- Long-press phases began/ended/cancelled tested, incl. pointer-claim lifetime.
- Router hold pairing tested for: normal lift, cancel, reset, pause, reload, frontmost-app change, stop.
- ≥ 12 adversarial scenario tests (item 5), each named for the scenario.
- Validation/queries for `.hold` and `actionUnavailable`; `machineDefaults` tested with a fake catalog where brightness is unavailable.
- All existing gesture and runtime tests still pass; changed ones keep their intent.
- Verification triple green, denylist clean.
- Done report: every threshold/logic change with rationale; "Needs Gabriel": record the new trace scenarios.
