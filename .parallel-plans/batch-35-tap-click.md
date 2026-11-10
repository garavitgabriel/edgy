# Batch 35 — EDGY-TAPCLICK: a tap Edgy takes as a gesture doesn't also click

Read `CLAUDE.md`, `.parallel-plans/2026-11-07-edgy-v05.md` (hard rules), `.parallel-plans/backlog.md` § "2026-11-10 device session", `done-batch-28.md` (input thread, the pointer guard tap), `Sources/TouchKit/PointerGuard.swift`, `Sources/TouchKit/LiveSystem.swift`, `Sources/EdgyRuntime/Engine.swift` § pointer guard, `Sources/Gestures/GesturePipeline.swift` (how taps settle; the note at "tap-to-click reports its click after the lift"). One builder; nothing else is running.

You own ONLY: `Sources/TouchKit/**`, `Sources/EdgyRuntime/**`, `Sources/Gestures/**`, `Tests/TouchKitTests/**`, `Tests/EdgyRuntimeTests/**`, `Tests/GesturesTests/**`, `docs/settings-reference.md`, `scripts/smoke-actions.sh`.
MUST NOT touch: `Sources/EdgyCore/**` (the contract is already on main: `PointerGuarding.expectTapClick(within:)`, default no-op), `Package.swift`, `Sources/EdgyApp/**`, `Sources/Actions/**`, `Sources/EdgyUI/**`, `docs/BRIEF.md`, `docs/design/**`, `.parallel-plans/` except your own `done-batch-35.md` / `blockers-batch-35.md`. Need something there → blocker note, stop. **Never launch or quit the running Edgy. Tests never create an event tap, post an event or read the real button state** (fakes only, hard rule 1).

## Why
Gabriel, Mac mini, two monitors, tap-to-click on, 2026-11-10: Last App on a double-tap focused the other app, then focus came straight back, four presses in a row. Best explanation (not proven): the system reports a tap as a click after the lift; Edgy's tap sees only pointer motion, so the click went to the window under the pointer and re-focused it. Every tap and double-tap binding has this side effect today: the gesture runs AND the thing under the pointer is clicked.

## Build
1. **Engine:** when a finger lifts from a mapped zone as a tap that a tap or double-tap binding may take (a tap candidate there; both taps of a double-tap; also a tap that then waits out the double-tap window), call `pointerGuard.expectTapClick(within:)`. Not for a lift the pipeline rejected (palm, typing, moved, physical click, zone with no tap/double-tap binding, Edgy off in this app, Enabled off). If the smallest honest way needs one new field on the gesture output, add it in Gestures; do not retune any threshold or change what is recognised.
2. **Guard (TouchKit):** the event tap also watches left button down/up. While an expectation is open, swallow the next left-down and its matching left-up; then the expectation is spent. Rules:
   - Never swallow a physical press: a button-down that arrives while a finger is still down on the pad, or with no open expectation, passes. (State how you tell them apart with the data the tap and the frames give you, and prove it with tests.)
   - Never swallow an up without having swallowed its down; never leave a button "down" for the system: a swallowed down whose up doesn't arrive within the safety timeout releases cleanly and logs once.
   - A double-tap may produce two clicks (or one double-click): each expected tap spends one down/up pair; `clickState` 2 is still one pair.
   - Expectation window: start with 0.5 s from the lift; expire silently. Say in the report what the system's delay looked like in the events you could reason about, and what Gabriel should measure on device.
   - The tap stays on the input thread; the callback stays cheap (no allocation-heavy work, no locks held across the handler). Re-enable on timeout / user-input disable still works. Idle cost unchanged: no timer while nothing is expected.
3. **Test Mode honesty:** in dry run the gesture runs nothing, but the click is still swallowed (the tap was Edgy's). Note it in `docs/settings-reference.md` in one plain sentence, with the tap-to-click explanation.
4. `scripts/smoke-actions.sh`: a step for Gabriel — pointer over a window of another app, tap a mapped zone: the action runs and that window is not clicked; a physical click anywhere still clicks; a tap in the middle of the pad still clicks.

## Acceptance
- Tests (fakes): expected tap → down/up swallowed once, the next pair passes; no expectation → passes; physical press during a zone touch → passes and the gesture is rejected as today; expectation expires → later click passes; double-tap → both taps' clicks swallowed, a third passes; swallowed down with no up → released by the safety timeout, logged once; rejected lifts never open an expectation (one test per reason above); pointer-motion behaviour unchanged (every existing guard test passes untouched). No existing test deleted or weakened.
- Batch 28's idle tests green and unchanged.
- `done-batch-35.md`: each item with its test, how physical vs tap clicks are told apart, what to check on device, open questions.
- Verification triple green (`swift build && swift test && swift format lint --strict -r Sources Tests Package.swift`, read every "Test run with" line); denylist prints nothing. Format only your own paths.
