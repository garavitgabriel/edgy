# Batch 34 — EDGY-THEN: the key-sequence button people can find

Read `CLAUDE.md` (incl. "Design and brand"), `.parallel-plans/2026-11-07-edgy-v05.md` (hard rules), `docs/BRIEF.md` § Key-combo recorder / Key sequences (updated 2026-11-10), `done-batch-29.md`, `done-batch-33.md`. One builder; nothing else is running.

You own ONLY: `Sources/EdgyUI/Inspector/**`, `Tests/EdgyUITests/Inspector/**`, `docs/settings-reference.md`, `docs/design/build-shots/batch-{29,33,34}/**`.
MUST NOT touch: everything else, incl. `Sources/EdgyCore/**`, `Package.swift`, `Sources/EdgyApp/**`, `Sources/Actions/**`, `Sources/EdgyRuntime/**`, `Sources/EdgyUI/{Shared,Model,Preview,Icons,Glyph,Mirror,Overlay,Picker,Popover,Window,Onboarding}/**`, `Tests/EdgyUITests/{Support/**,SkeletonTests.swift}`, `docs/BRIEF.md`, `.parallel-plans/` except your own `done-batch-34.md` / `blockers-batch-34.md`. Need something there (a token, say) → blocker note, stop. **Never launch or quit the running Edgy.**

## Why
Gabriel, on device, 2026-11-10: key sequences work, but "+ Then…" is "hard to notice … it hides in plain sight". He picked: a visible button plus one hint line.

## Build
1. The quiet `ink2` text button "+ Then…" becomes a visible **"Add another key"** button: the standard bordered small button used elsewhere in the inspector, `ink` label, same tooltip ("Send another shortcut after this one"), same accessibility action. Same rules as today: Keyboard Shortcut only (never Hold Keys), shows once a combo is set, hidden at 4 steps and while recording, width always reserved (batch 33) so the field keeps its x.
2. Under the field, one 13 pt `ink2` line, exactly **"Sends these one after another."**, while the button shows or the value has 2+ steps. Not while recording (there "Use Escape" owns that line). No other new copy.
3. If the wider button no longer fits beside the field at the inspector's minimum width, the button goes on its own line under the field, left-aligned with it, above the hint. Pick one layout and use it at every width; say which in the report.
4. `docs/settings-reference.md`: the key-sequence paragraph names the new button.

## Acceptance
- Tests: label is "Add another key"; shows/hides by the same rules (1–3 steps idle; not Hold Keys; not at 4; not recording); field x identical with the button showing and hidden; hint shows with the button and with a 4-step value, never while recording, never on Hold Keys. No existing test deleted or weakened; where the label changes one, keep the old assertion beside it as a comment naming the 2026-11-10 ruling.
- Shots (light + dark): `batch-34/recorder-one-step-add-another`, `recorder-two-steps`, `recorder-four-steps`, `recorder-recording-use-escape`, `recorder-hold-keys` (no button, no hint); re-shoot the batch-29 / batch-33 recorder shots that change, nothing else. Invented app names only.
- `done-batch-34.md` ticks each item with its test or shot, a bones tick list, and a reader-first look at each shot.
- Verification triple green (`swift build && swift test && swift format lint --strict -r Sources Tests Package.swift`, read every "Test run with" line); token greps clean; denylist prints nothing. Format only your own paths.
