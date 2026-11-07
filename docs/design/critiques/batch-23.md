# Batch 23 critique (overlay polish)

Verdict: ready. All 11 critique-18 items are fixed: the 3 must-fix, the 3 should-fix and the 5 design answers. The plates now sit in the gutter. The display check stacks under the level plate along the left edge, 26 pt clear of the window, and the Volume plate is 106 pt clear. The plate is one dark component: all 30 isolated light/dark pairs are byte-identical (`cmp`). Dry run shows no level plate, and the timings are proven on the injected clock. The pixels match the tokens (below). Every string matches BRIEF character for character. There are no new must-fix items, and the two should-fix items below are housekeeping.

Pixel samples (2×, `plate-run-volume-light`, `plate-would-set-light`): fill (59,45,39) over white, (39,25,19) over black, which is `#2A1B15` at 0.92. Edge: 1 px (0.5 pt) of (91,74,64) over black, where `rgba(255,230,210,.24)` predicts (91,74,65). Rim: 2 px (1 pt) of (193,177,165), which is `#FBEADB` at 70%, at 6.3:1 against the plate (the accent alone is 2.7:1). The contact is 26 pt overall. The dry-run mark is a 2 pt accent ring with the rim outside it. The rejection mark is unrimmed `ink2`.

## Critique-18 items: status

| Item | Status | Evidence |
|---|---|---|
| M1 Level plate and check off the text | FIXED | `batch-23/overlay-level-check-stacked-*`, `batch-18/overlay-docked-level-check-*`: the check is stacked below the level plate in the left gutter, with its right edge 26 pt from the window. Tests: `aPlateNeverCoversTheFocusedText`, `displayCheckStacksAlongTheDockedEdge`. |
| M2 One plate appearance | FIXED | `plate-component-*` is dark. All 30 `plate-*` pairs are byte-identical, and the fill sampled as above. |
| M3 Dry-run suppression and timings | FIXED | `batch-23/overlay-dryrun-brightness-*`: only "Would set Brightness" / "Left edge, slide" shows, although the feed also offered a check. `overlay-level-test-mode-off-*` has no Test Mode dot. `done-batch-23.md`: `timingsAreBRIEFs` (1.2 / 0.6 / 0.2 / 15), `fadesAfter15sUnanswered`, `asksAtMostThreeTimes`, `noLevelPlateInDryRun`, present in `OverlayBehaviourTests.swift`. For the HUD, the chief's addendum: `hud.show` is called only on the perform path, and `testModeRunsNothingButReportsAndTicks` asserts that nothing is performed. |
| S1 Volume plate overlaps the window | FIXED | `overlay-light-document-*`, `batch-18/overlay-docked-test-mode-*`: the Volume plate is 106 pt clear. The hold plate's top is exactly 8 pt below the window. |
| S2 Menu bar cropped | FIXED | Every docked shot has the menu-bar strip. The glyph shows its dot with Test Mode on (`overlay-light-document`, `overlay-dryrun-brightness`) and no dot with it off (`overlay-level-check-stacked`, `overlay-level-test-mode-off`). There's no pill. |
| S3 No dark document | FIXED | `batch-23/overlay-dark-document-*`. The plates stay in the gutter, so the edge-over-black proof comes from the isolated shots' black half, as measured above. |
| R1 Always dark plus 0.5 pt edge | FIXED | Fill and edge measured above. The edge is always drawn; see Q1. |
| R2 Contact rim | FIXED | `plate-run-volume-*`, `plate-would-set-*`, `plate-hold-*`: rim measured on the filled contact and outside the dry-run ring. |
| R3 Bare trigger name | FIXED | `plate-run-trigger-*`: "Play/Pause" / "Bottom edge, double-tap". |
| R4 Display check exempt from 17/13 | FIXED | `plate-display-check-*`: a 13 semibold question with two `ink`-wash buttons and no accent. |
| R5 Keyboard plate | FIXED | `plate-level-keyboard-*` and `overlay-level-test-mode-off-*`: "Keyboard 60%" / "Built-in keyboard". The bar is filled to 60% (171 of 287 px). |

Counts: 11 FIXED, 0 PARTIAL, 0 OPEN, 0 NOT SHOT.

## New must fix

None.

## New should fix

1. **The committed skeleton plate shots are still pale.** On `HEAD`, the centre pixel of `docs/design/build-shots/skeleton/plate-light.png` is (251,231,216), the old pale plate. The regenerated dark versions sit uncommitted in the working tree, because the builder restored them with `git checkout` (it didn't own that path). `main` shows two plate appearances again (M2). Fix: commit the regenerated `skeleton/plate-*.png` from a session that owns that glob, before the batch-24 onboarding review.
2. **`plate-component-*` is the only isolated shot without the black-document half.** It's drawn on a single cream ground, so the component sheet never shows the edge doing its job. Fix: render it over the same white/black split as the other 29.

## Matches BRIEF

- Copy: all 16 rejection rows, the five "Would" lines, the three hold lines, both level plates and the display check are exact. The decimal rule holds, and rejections with no measure stop after the reason.
- Bone 3: "Play/Pause" uses the catalog spelling. Bone 4: a filled, rimmed accent disc against a struck `ink2` circle, and recognized stays louder.
- Bone 8: the glyph dot is the only Test Mode marker. Bone 9: docked, on-screen, clear of the text, 16 pt in from the edge. The layout matches S8's gutter and D's placements.
- Level bars read true (40% and 60% of the track). One hue: the accent appears only on contacts and level fills.

## Questions for design

1. **The edge is always drawn, not only over dark documents.** Over white it measures (106,89,80): one device pixel lighter than the plate (59,45,39), so it reads as a softened silhouette rather than a visible outline. The plate can't know what's behind it. I'd accept that. Confirm, or say it must be gated on the backdrop.
2. **Should parameterized run plates drop the verb as well?** The plates read "Opened Quillpad", "Pressed ⇧⌘ 4" and "Ran <name>". Ruling 2 covered only the bare trigger. I'd keep these verbs: a bare "Quillpad" or "⇧⌘ 4" doesn't say anything happened, and "Would open" / "Opened" pair cleanly. Confirm.
3. **The stacked check is wider than the level plate (about 257 pt vs 220 pt), with their left edges aligned.** S8 also uses two widths, so I'd leave it. Say if the stack should share one width.

## Design answers (chief, 2026-11-07)
1. **An always-drawn edge:** accepted. The plate can't know its backdrop, and over white the edge just softens the silhouette. Don't gate it.
2. **Parameterised run plates keep their verb:** "Opened Quillpad", "Pressed ⇧⌘ 4", "Ran <name>". This pairs with dry run's "Would open / Would press / Would run". Plain triggers stay bare ("Play/Pause"), because the action name already says what happened. Added to BRIEF.
3. **Stack widths:** leave them. Two widths with aligned leading edges is fine (S8 does the same).
