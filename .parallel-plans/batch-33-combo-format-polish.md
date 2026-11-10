# Batch 33 — EDGY-COMBO: one way to write a key combo, and critique 29's fixes

Read `CLAUDE.md` (incl. "Design and brand"), `.parallel-plans/2026-11-07-edgy-v05.md` (hard rules), `docs/BRIEF.md` § key recorder → "How a key combo is written" and § Binding parameters (latest), **`docs/design/critiques/batch-29.md` (your fix list, incl. "Design answers": binding)**, `done-batch-29.md`, `done-batch-32.md`. One builder; nothing else is running.

You own ONLY: `Sources/EdgyUI/{Inspector,Mirror,Popover,Picker,Overlay,Window,Onboarding}/**`, `Sources/EdgyRuntime/**`, their tests (`Tests/EdgyUITests/{Inspector,Mirror,Popover,Picker,Overlay,Window,Onboarding}/**`, `Tests/EdgyRuntimeTests/**`), `docs/settings-reference.md`, `docs/design/build-shots/batch-{14..33}/**` (re-shoot what your changes alter; new shots in `batch-33/`).
MUST NOT touch: `Sources/EdgyCore/**`, `Package.swift`, `Sources/EdgyApp/**`, `Sources/{Gestures,TouchKit,Actions,Displays}/**`, `Sources/EdgyUI/{Shared,Model,Preview,Icons,Glyph}/**`, `Tests/EdgyUITests/{Support/**,SkeletonTests.swift}`, `docs/BRIEF.md`, `docs/design/critiques/**`, `.parallel-plans/` except your own `done-batch-33.md` / `blockers-batch-33.md`. Never launch or quit the running Edgy. Need something outside → blocker note, stop.

## Fix list
1. **One formatter, everywhere** (critique 29 must-fix 1–3). Exactly one function turns a combo or sequence into text; the field, pad tab, inspector sub-line, hover line and plates all call it; delete the second formatter (today: `KeyComboText` and `KeyCombo.displayText` in the overlay's display-check file disagree). The rule, verbatim from BRIEF: modifier symbols in the order ⌃⌥⇧⌘ then the key with NO spaces ("⌃B", "⇧⌘4", "⌃⌥Space", "⌃Tab", "⌥Esc", "⇧⌘["); fn is a word followed by one space ("fn Space", "fn ⌃B", alone "fn"); named keys Space, Tab, Return, Esc, Delete; arrows ←→↑↓; sequences joined by ", " ("⌃B, N"); "Right ⌘" stays dormant (answer 5). A table-driven test covers every example in BRIEF, and a test proves each surface calls the one function (same string on all five for one binding).
2. **Critique 29 should-fixes:** target sub-line and "Default: …" both left-aligned on an overridden row; the Name and Icon grid scrolls the selected icon into view on open; the field keeps its width when "+ Then…" hides at 4 steps; the plate fixture uses a possible gesture for a Hold Keys binding; identical drawings appear once in the icon grid with a tooltip naming both actions (answer 4).
3. **Design answers 1–3 and 6:** combined edge labels never use commas ("A and B"; three or more "A and 2 more"); dry-run verb by kind ("Would set / hold / run <name>"); corner tabs may grow to 40% of their edge before fading; a new action on an inherited row creates an override WITHOUT Default's custom name, while a name set on the override itself carries.
4. **Re-trigger while a sequence is sending** stays silent (no plate); pin it with a test so it's a decision, not an accident.
5. Stay inside batch 28's idle budgets; no per-frame formatting (format once per revision).

## Acceptance
- `done-batch-33.md` ticks every item with its test name or light+dark shot; every shot that showed a combo is re-shot and reads per the rule (grep the test fixtures: no "⌃ " followed by a key, no "Arrow").
- Token greps clean; verification triple green; denylist prints nothing. Format only your own paths.
