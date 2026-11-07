# Batch 26 — EDGY-SWITCHER: Switch Apps opens on travel, never on contact

Read `CLAUDE.md`, `.parallel-plans/2026-11-07-edgy-v05.md` (hard rules), `done-batch-20.md` (the switcher session you're changing), `Sources/Actions/ActionRegistry+Keys.swift` § App switcher. Runs in parallel with batch 25 (EdgyUI only — no shared files).

You own ONLY: `Sources/Actions/**`, `Tests/ActionsTests/**`, `scripts/smoke-actions.sh`, `docs/settings-reference.md`.
MUST NOT touch: `Sources/EdgyCore/**` (frozen — `GestureEvent.Phase`, `ActionContext`, `SlideMotion` stay as they are), `Sources/Gestures/**` (slide feel is signed off — do not retune dwell/still radius), `Sources/EdgyRuntime/**`, `Sources/EdgyUI/**`, `Sources/EdgyApp/**`, `Package.swift`, `docs/BRIEF.md`, `.parallel-plans/` except your own `done-batch-26.md` / `blockers-batch-26.md`. Need a contract change → blocker note, stop.

## Why
Gabriel, MacBook Pro, 2026-11-07: Switch Apps on the top edge "opens a lot of the time, I don't have to swipe it, or very small and it triggers." Cause: a finger resting on the edge for `dwellMS` (120 ms) claims a slide and emits `.began` with zero travel; `performSwitcher` opens the switcher on `.began` (command down + tab). The top edge of a built-in pad sits right under the keyboard, so fingers landing there open the switcher. Logs show `began` → `cancelled` 40 ms later at the top edge, and the switcher still opened. Other slide actions are inert at zero travel; the switcher is the only one with a visible side effect on `.began`.

## Build — the switcher opens on earned travel
1. A fresh `.began` (not lingering) **arms** a session but presses nothing. Travel accumulates along the edge in either direction.
2. When accumulated travel reaches **one `stepMM`** (the binding's step, default 8 mm), the switcher opens: command down + exactly one tab. That first step **is** the opening, so it's consumed. `position` 0 is still "the app after the frontmost", and later steps move from there exactly as today (speed-up, end stepping, slide-back-past-start cancel).
3. `.ended` / `.cancelled` on an armed-but-unopened session is a **silent no-op**: no key events, and no command-up for a command that was never pressed. Log it at debug ("switcher: stroke ended before opening").
4. The keep-open path is unchanged: a `.began` while a session lingers continues it with no tab.
5. The outcome report, the `actionFired` haptic and the watchdog arm fire when the switcher **actually opens**, not on `.began`. End stepping (`atEnd`) on an unopened session does not open it; only real travel does.
6. Command is still never left down: every existing release path holds.
7. `docs/settings-reference.md` and the `stepMM` help line (if the catalog's helper text mentions opening) say the switcher opens after one step of travel. Don't change BRIEF copy; if the catalog copy must change, list it in the done report for design.
8. `scripts/smoke-actions.sh`: add a step to rest a finger on the switcher edge (nothing opens), tap it (nothing), slide less than one step (nothing), then slide one step (opens on the next app).

## Acceptance (mock keyboard only, hard rule 1)
- Tests: rest (`.began` then nothing) → no key events; travel < step then `.ended` → none, and no command-up; `.began` → `.cancelled` 40 ms later → none; travel ≥ step → exactly `[cmd down, tab]`; travel of 2 steps → open + one more tab; travel back one step after opening → cancels as today; `atEnd` with no travel → none; lingering `.began` → continues, no tab; haptic/outcome only on open. Keep every existing switcher test passing; when one asserted open-on-`.began`, keep the old assertion beside it as a comment naming this ruling.
- `done-batch-26.md` lists each test and the before/after behaviour.
- Verification triple green; denylist prints nothing. Format only your own paths.
