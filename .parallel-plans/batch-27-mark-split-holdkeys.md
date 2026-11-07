# Batch 27 — EDGY-SIGNOFF: critique 25 regression, the Edgy mark, findable Hold Keys

Read `CLAUDE.md` (incl. "Design and brand"), `.parallel-plans/2026-11-07-edgy-v05.md` (hard rules), `docs/BRIEF.md` § Design (latest: § Window identity (a) is now "the Edgy mark"), `docs/BRAND.md`, **`docs/design/critiques/batch-25.md` (your fix list)**, `done-batch-25.md`, `docs/design/assets/README.md` § Identity mark. Runs in parallel with batch 26 (Actions only, no shared files).

You own ONLY: `Sources/EdgyUI/{Window,Mirror,Popover,Inspector,Picker,Overlay,Onboarding}/**`, the matching `Tests/EdgyUITests/{Window,Mirror,Popover,Inspector,Picker,Overlay,Onboarding}/**`, `Sources/EdgyUI/Glyph/Assets/mark-edgy.pdf` (add the exported asset; nothing else in Glyph/), and `docs/design/build-shots/batch-{22..27}/**`.
MUST NOT touch: `Sources/EdgyUI/{Shared,Model,Preview,Icons}/**`, the rest of `Glyph/`, `Tests/EdgyUITests/{Support/**,SkeletonTests.swift}`, `Sources/EdgyCore/**`, `Sources/Actions/**`, `Sources/Gestures/**`, `Sources/EdgyRuntime/**`, `Sources/EdgyApp/**`, `Package.swift`, `docs/BRIEF.md`, `docs/design/critiques/**`, `.parallel-plans/` except your own `done-batch-27.md` / `blockers-batch-27.md`. Need something there → blocker note, stop.

## Fix list
1. **Regression (blocking sign-off):** a 2/3/4 split preview on a SIDE edge erases the whole edge (bar, selection ring, tab). `MirrorPad` sets opacity 0 on the whole label view, and a side-edge tab carries the bar's shape. **Fade only the label text.** The tab keeps its shape; the bar, dividers, ring and silhouette stay. Re-shoot `batch-25/window-split-hover-right-thirds` and `batch-22/window-split-hover` (light + dark), and add a test that fails if the previewed edge's bar disappears.
2. **Critique 25 non-blocking:** give the "real icon" fixture app a mid-tone icon (not Edgy's own cream one); add a shot of the selection after a split (`batch-27/split-selects-first-part`).
3. **The Edgy mark** (BRIEF § Window identity (a), Gabriel's taste call; supersedes the 26 pt app icon you shipped in 25): the V3 pad + lit strip ALONE, no tile, from `docs/design/assets/mark-edgy.pdf` (copy it into `Sources/EdgyUI/Glyph/Assets/`), drawn as a non-template image tinted `Tokens.ink` (strip too, never accent), `Tokens.titleMarkWidth` × `titleMarkHeight` (26 × 18 pt), `titleIconLeading` (12 pt) after the last traffic light, vertically centred on the tab pill. No outline, no shadow, no states. Tooltip + accessibility label "Edgy", not clickable. Stop reading `titleIconSize` / `titleIconOutline*` (the chief deletes them after merge). Re-shoot the title-bar shots (`batch-27/title-bar-zoom`, `window-identity`).
4. **Hold Keys, findable for any app's hold shortcut** (Gabriel's ruling, copy verbatim):
   - A. In the picker, Hold Keys' sub-line is **"Hold any app's shortcut while your finger rests"**. It's the only sub-line for an available action that describes use; keep unavailable/limited reasons winning over it. Picker search also matches Hold Keys on "hold", "push to talk", "talk", "dictation" and "voice".
   - B. When Hold Keys has no keys yet, under the key recorder, a 13 pt `ink2` line: **"Press the shortcut your app uses while held. For a key like fn alone, hold it a second, then let go."** It disappears once keys are set. No suggestion chips.
   - Shots: `batch-27/picker-hold-keys-subline`, `picker-search-talk`, `inspector-hold-keys-empty`, `inspector-hold-keys-fn`.

## Acceptance
- `done-batch-27.md` ticks every item with its shot (light + dark) or test name.
- Token greps clean (no colour/size/radius literals outside `Shared/Tokens.swift`); denylist prints nothing (the copy names no product).
- Verification triple green. Format only your own paths.
