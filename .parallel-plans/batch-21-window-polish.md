# Batch 21 — EDGY-POLISH: the settings window, to the design critiques

Read `CLAUDE.md` (incl. "Design and brand"), `.parallel-plans/2026-11-07-edgy-v05.md` (hard rules), `docs/BRIEF.md` § Design (latest — bone 3 label rules, one open binding, picker interior cap, no Split on app tabs, 11 pt only for picker headers), `docs/BRAND.md`, and **the four critiques: `docs/design/critiques/batch-14.md`, `batch-15.md`, `batch-16.md`, `batch-17.md`** — they are your fix list. Then `done-batch-14/15/16.md` for how the code is built.

You own `Sources/EdgyUI/Mirror/**`, `Sources/EdgyUI/Inspector/**`, `Sources/EdgyUI/Picker/**`, `Sources/EdgyUI/Window/**`, `Sources/EdgyUI/Popover/**`, `Sources/EdgyUI/Glyph/**` (not the PDFs), their test folders, and `docs/design/build-shots/batch-14..17/**` + `batch-21/**`. (The chief set `Tokens.miniMirrorPointsPerMM` to 1.8 per critique 17.) Runs in parallel with batches 17–20 (other folders).

## Fix list
1. **Every must-fix** in the three critiques (14: inverted slab shadow / halo, corner tab + tile as one shape, live tab takes the bar's live fill, one open binding; 15: one open binding, path editor (field width + a real "Choose…" button), "Do nothing here" shot with empty search scrolled to the end; 16: paused / Huddle-off keep the mirror mounted at 40% with the centred line, no-trackpad dashed outline + copy, disabled fade, app marks on tabs and add-app rows, overlap note only under Split (already moved), broken-config strip without Reload, re-shoot window-picker).
2. **Every should-fix** unless it conflicts with BRIEF (then follow BRIEF and say so): label wraps ("Sensitivity", "Previous Track"), inspector left inset ≈ 22 pt as in A, mini mirror shot at real popover size (~290 pt), Windows preset mirror shot, Tap row present with a blank value while its picker is open, the rest as listed.
3. **Chief rulings already made:** "Split into" hidden on app tabs; picker height capped at the pad's interior (already merged — keep it); `InspectorDrafts` may stay a side table (document it).
4. **Labels on the pad** per bone 3 as updated: never "…" on the pad; parameter short value → action short name → clip with a 12 pt fade.
5. **From batch 17:** `MiniMirrorView` must not fade for Disabled when the popover already applies 0.4 (one fade only — keep the popover's); unify the two `ConfigProblem` types by making the Window one a thin wrapper or typealias over `EdgyRuntime.ConfigProblem` plus the file name (keep `WindowConditions` source-compatible for EdgyApp).
6. **From batch 20 (merged):** levels and stepped slides now carry optional tuning parameters (`speedUp`, `stepMM`, `keepOpenMS`, `holdMS`). In the picker, end a name in "…" only when the action has a **required** parameter (Volume / Keyboard Brightness must not read "Volume…"); update `PickerTests.searchFiltersGroupsAndTheDisclosure` back to "Keyboard Brightness". Draw `.choice(["on","off"])` (`speedUp`) as a checkbox row. Add the long-press "Press time" row from `ConfigValidator.pressTimeParameter` (see done-batch-20.md).
7. Use the catalog's `displayName` everywhere; never re-spell action names in the UI (batch 20 normalises the catalog spellings).

## Acceptance
- Every must-fix and should-fix in the three critiques ticked in the done report with the snapshot that shows it (or the BRIEF rule that overrides it).
- All batch 14/15/16 shots re-shot; new `build-shots/batch-21/` with the integrated window in each state (Default light/dark, picker open on the bottom edge, Wayfare tab, Huddle off, paused, no trackpad, disabled, broken config, Advanced).
- Existing EdgyUI tests unchanged in intent; new tests for one-open-binding, label shortening rule, tab/tile shape geometry, state fades.
- Token greps clean; verification triple green; denylist clean.
- Reader-first review of the integrated window against `docs/design/final/26F-1TVB-A.png` and `-B.png` in the done report.
