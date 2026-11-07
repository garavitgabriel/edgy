# Batch 23 — EDGY-OVERLAY-2: overlay polish to critique 18

Read `CLAUDE.md` (incl. "Design and brand"), `.parallel-plans/2026-11-07-edgy-v05.md` (hard rules), `docs/BRIEF.md` § Design (bone 9 rulings: plate always dark, light edge, contact rim; § Level plate and display check; § Test Mode), `docs/BRAND.md`, **`docs/design/critiques/batch-18.md` (your fix list)**, `done-batch-18.md`, and renders `docs/design/final/26F-1TVB-D.png`, `docs/design/final/supp/26F-SUPP-S8.png`.

You own `Sources/EdgyUI/Overlay/**`, `Tests/EdgyUITests/Overlay/**`, `docs/design/build-shots/batch-18/**`, `docs/design/build-shots/batch-23/**`.

## Fix list
1. Every must-fix and should-fix in critique 18: the level plate and display check never sit on the document text (stack along the docked edge, avoid the focused text element's frame — give `OverlayScreenProviding` a way to report it, faked in tests); one plate component, always dark; proof (shots and/or timing tests on the injected clock) that dry run shows no level plate / HUD, the level plate shows with Test Mode off, 1.2 s fade, display check 15 s + max 3 asks, hold 0.6 s + 200 ms fade; leave a gap between a plate and the document window; overlay shots include the menu bar; a dark-document overlay shot.
2. Rulings: plate uses the new tokens `Tokens.plateFill`, `plateInk`, `plateInk2`, `plateEdge(+Width)` (edge drawn over dark documents — or always, if indistinguishable; document), `contactRim(+Width)` on the accent contact and the dry-run ring; run-mode trigger plates show the bare name ("Play/Pause"); the display check is exempt from the 17/13 pair; keyboard plate "Keyboard 60%" / "Built-in keyboard" (or the external keyboard's name).

## Acceptance
- Every critique-18 item ticked in `done-batch-23.md` with its evidence.
- Shots re-made (batch-18) + new batch-23 compositions (light document, dark document, level + check stacked, dry run).
- Token greps clean; verification triple + denylist green.
