# Batch 25 — EDGY-POLISH: final v0.5 polish (critiques 22 + 24, overlay copy, onboarding serial)

Read `CLAUDE.md` (incl. "Design and brand"), `.parallel-plans/2026-11-07-edgy-v05.md` (hard rules), `docs/BRIEF.md` § Design (latest — split, picker order, mini hover line and onboarding were updated today), `docs/BRAND.md`, **`docs/design/critiques/batch-22.md` and `batch-24.md` (your fix list, incl. "Design answers" — binding)**, `done-batch-22.md`, `done-batch-23.md`, `done-batch-24.md`. Runs in parallel with batch 26 (Actions only — no shared files).

You own ONLY: `Sources/EdgyUI/{Window,Mirror,Popover,Inspector,Picker,Overlay,Onboarding}/**`, the matching `Tests/EdgyUITests/{Window,Mirror,Popover,Inspector,Picker,Overlay,Onboarding}/**`, and `docs/design/build-shots/batch-{14..25}/**` (re-shoot only what you touch; new shots go in `batch-25/`).
MUST NOT touch: `Sources/EdgyUI/{Shared,Model,Preview,Glyph,Icons}/**`, `Tests/EdgyUITests/{Support/**,SkeletonTests.swift}`, `Sources/EdgyCore/**`, `Sources/Actions/**`, `Sources/Gestures/**`, `Sources/EdgyRuntime/**`, `Sources/EdgyApp/**`, `Package.swift`, `docs/BRIEF.md`, `docs/design/critiques/**`, `.parallel-plans/` except your own `done-batch-25.md` / `blockers-batch-25.md`. Need something there → blocker note, stop.

## Fix list
1. **Critique 22 must-fix — `AppMark.hasIcon`** (`Window/WindowParts.swift` ~166): a bundle with no own icon (`CFBundleIconFile`/`CFBundleIconName` absent, or the system's generic application icon) counts as no icon → the Open App tile in `ink2`, never the generic pale square. Everywhere app marks draw (tabs, chips, popover). Fixtures: one real-icon app + one iconless bundle (build the bundle in a temp dir in the test).
2. **Critique 22 PARTIALs and should-fixes 1–7**: checkbox helpers (8 pt after every helper, indented to the label), split-preview divider vs label, picker bottom inset/fade, read-only "Enabled" in `ink2`, mini contact keeps the edge icon readable, both fixtures rebuilt from shipping views (`MenuRow.visible`, the real window strip), and shoot the two NOT SHOT items.
3. **Critique 22 design answers 1–3**:
   - Mini hover line: popover full content width, short zone names ("Bottom:", "Left:", "Top-left:", "Right, upper:"), then pad-tab short names, fade only as last resort.
   - Picker order within a group = BRIEF icon-table order (most-used first), search keeps it. Implement the order inside `Picker/` (a table keyed by action ID); do NOT change `ActionCatalog`.
   - **SplitPlan behaviour change** (`Inspector/InspectorModel.swift`): the first part (top/upper for sides, left for top/bottom) keeps the bindings; the others start empty; fewer parts keeps the first part's bindings and drops the rest; the note says so before the click ("Upper third keeps Volume; the other two start empty."); one undo step. Update the existing SplitPlan tests — keep each old assertion beside the new one as a comment naming the ruling (critique 22 answer 3).
4. **Critique 24 should-fixes**: re-stage the demo struck contact clear of the Volume tab; centre the rejected plate under the mirror (answer 2). Shoot both.
5. **Overlay copy** (critique 23 should-fix, backlog): parameterised run plates use past tense + object — "Opened Quillpad", "Pressed ⇧⌘ 4", "Ran <shortcut name>"; plain triggers stay bare. The plate-component shot gets a black-document half.
6. **Onboarding step 2 counts by serial**: `SettingsModel.decisionSerial` is on main (monotonic count of every decision). Record it as the baseline when step 2 opens; new decisions = the last `min(serial − baseline, recentDecisions.count)` of `recentDecisions`. Remove the overlap inference (`newDecisions(seen:current:)`) and its tests, replacing them with serial-based tests, including the wrapped-cap case.

## Acceptance
- `done-batch-25.md` ticks every item above, each with its shot (light + dark) or test name.
- Token greps clean (no colour/size/radius literals outside `Shared/Tokens.swift`).
- Verification triple green; denylist prints nothing. Format only your own paths.
