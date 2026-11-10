# Batch 32 — EDGY-SEQUENCE: key sequences and Last App (engine)

**Starts after batch 28 has merged** (same folder). Runs in parallel with batch 29 (EdgyUI + EdgyRuntime: the recorder UI, display and validation). Read `CLAUDE.md`, `.parallel-plans/2026-11-07-edgy-v05.md` (hard rules), `docs/BRIEF.md` § "Key sequences" and the Apps rows of the icon table, `done-batch-11.md` (keyboard actions), `done-batch-26.md` + `done-batch-28.md` (the switcher and the input thread you build on).

You own ONLY: `Sources/Actions/**`, `Tests/ActionsTests/**`, `scripts/smoke-actions.sh`.
MUST NOT touch: `Sources/EdgyCore/**` (`KeyCombo` stays one combo), `Package.swift`, `Sources/EdgyRuntime/**`, `Sources/EdgyUI/**`, `Sources/EdgyApp/**`, `Sources/{Gestures,TouchKit,Displays}/**`, `docs/**`, `.parallel-plans/` except your own `done-batch-32.md` / `blockers-batch-32.md`. Need a contract change → blocker note, stop.

## Why
Gabriel steers many terminal sessions through a multiplexer whose commands are "prefix, then a key"; Edgy sends one combo per gesture, so none of them can sit on a zone. His main loop is terminal ↔ browser, and there is no clean way to bind "back to the app I was in".

## Build
1. **Key sequences on `keyboard.shortcut`.** **Shared format (fixed, both batches):** the `keys` parameter holds 1–4 combos separated by ONE space (`ctrl+b n`); each combo uses today's syntax. One combo behaves byte-for-byte as today (same events, same timing, same outcome). For 2–4: each combo is a full press and release, in order, with a fixed gap between combos (a named constant; start at 40 ms, on the action scheduler, never a sleep on the main or input thread). All keys and modifiers are released on any failure, and the rest of the sequence is dropped. A second trigger while a sequence is still sending is ignored (logged), never interleaved. Refused with the existing unavailable/invalid path: more than 4 combos, an unparseable combo, a modifier-only step.
   - `keyboard.hold` and `keyboard.slideSteps` keep taking ONE combo; a space in their keys is invalid.
   - Outcome/plate text is the UI's job; report the same outcome as a single shortcut.
2. **`app.last`, "Last App"** (Apps category, trigger shape, no parameters; gestures: tap, double-tap, long-press; catalog order: right after Open App; display name "Last App"). It brings back the app that was frontmost before the current one. Do it without the visible switcher if a public API allows (track activations via the workspace's did-activate notification behind a protocol, then activate the previous regular app that is still running; skip Edgy itself and apps that quit); fall back to one quick press of the switcher shortcut only if activation is refused, and say which path ships in the done report. No previous app → a no-op outcome, never an error sound.
3. `scripts/smoke-actions.sh`: steps for a two-step sequence into a terminal multiplexer (prefix, then a key), a four-step sequence into a text field (types in order, nothing stuck), and Last App back and forth between two apps, including after one of them quits.

## Acceptance (mocks only, hard rule 1)
- Tests: one combo = the exact pre-batch event list; 2 and 4 combos in order with the gap on the fake scheduler; failure mid-sequence releases everything and stops; re-trigger while sending is ignored; 5 combos / bad combo / modifier-only step refused; hold and slide-steps refuse a space; Last App: A→B then trigger → A, trigger again → B, previous app quit → the one before or no-op, Edgy's own windows never count, no history → no-op.
- No existing test deleted or weakened. Stay inside batch 28's idle budgets (the activation observer must not poll).
- `done-batch-32.md` lists each test and the Last App path chosen. Verification triple green; denylist prints nothing. Format only your own paths.
