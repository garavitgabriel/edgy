# Batch 18 — EDGY-OVERLAY: Test Mode overlay, plates, level plate, display check

Read the v0.5 shared brief, the stage-2 brief, `docs/BRIEF.md` § Design in full (bones 4, 8, 9, § Level plate and display check, § Test Mode: what it does, § Hold actions in Test Mode, the rejection copy table), renders C, D, S8, and `done-batch-13.md` (outcomes, measures, display-check decisions).

## Build
1. **`PlateView`** — the ONE plate component (bone 9): same radius, the 17/13 type pair, same inset, ≥4.5:1 over light and dark documents. Marks: recognized (filled accent), would-run (2 pt accent outline, no fill), rejected (hollow `ink2` circle with a strike), level (accent bar), none. Keep the frozen content enum; add cases only if BRIEF needs them (document).
2. **Copy from decisions** — a pure, fully tested mapper `PlateContent.from(_ decision:, catalog:)`: "Volume 64%" / "Right edge, slide"; "Ignored: palm, 21 mm wide, limit 18 mm" (BRIEF's copy table, using batch 13's real measures and units — where BRIEF's table and the real measure differ, follow the measure and list the difference); dry run "Would set Volume" / "Would run Play/Pause" / "Would open <app name>" / "Would hold fn" → "Would release fn"; hold "Holding fn" → "Released fn" (0.6 s, then 200 ms fade; cancel variant); level plate "Brightness 40%" / display name; no level plate when `systemHUDShown` or in dry run.
3. **`OverlayController`** per the stage-2 brief: per-screen panels, plates docked at the touched edge/corner of the screen the action changed (level plate on the changed display), fully on-screen, never over the focused text when avoidable (dock at the screen edge), timings per BRIEF, plates replace each other per zone rather than stacking without bound.
4. **Display check plate** — the only clickable plate (non-activating): "Did this screen change brightness?" with Yes / "No, turn off for this display", fades after 15 s, asks at most 3 times; answers go through batch 13's `SettingsEditor` API.

## Acceptance
- Snapshots (light + dark) in `build-shots/batch-18/`: each plate kind (run, would-run, every rejection reason, hold held/released/cancelled, level plate, display check) and a docked composition on a mock screen (D-like).
- ≥ 20 tests: copy mapper for every decision kind and rejection reason; dry-run copy; no level plate when the system HUD showed / in dry run; docking geometry for each edge/corner and multi-screen; fade timings on an injected clock; display-check answers call the editor; asks stop at 3.
- Bones checklist + reader-first review vs C, D, S8; token greps clean; verification triple + denylist.
