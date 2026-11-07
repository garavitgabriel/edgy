# Chief handoff — 2026-11-07 (outgoing chief → "edgy chief")

The outgoing chief ran v0.2 → v0.5 in one long session and is out of context. This file is everything the new chief needs. Read it, then `CLAUDE.md`, `docs/BRIEF.md` § Design, `.parallel-plans/backlog.md`.

## State right now
- `main` = everything merged and pushed; verification triple green; denylist clean. **v0.5 build work is complete** (batches 13–24 merged). Edgy runs from `main` on the Mac mini and is rsynced to the MacBook Pro.
- **No builders running.** One stale locked worktree: `.claude/worktrees/edgy-onboarding2` (batch 24, fully merged). Remove it once that session exits (`git worktree unlock … && git worktree remove … && git branch -D worktree-edgy-onboarding2`).
- `docs/BRIEF.md` may have **uncommitted design-session edits** — check `git status`, run the denylist on it, commit.

## What exists (one line each; details in each `done-batch-N.md`)
- Engine: TouchKit (buttonDown), Gestures (click rejection, tap-waits-for-double-tap, hold lifecycle, rejection measures, zoneLengthMM/atEnd), Actions (34 actions, native HUD, modifier-only hold incl. fn, watchdogs, pickers, outcomes, slide feel: mm steps / speed-up / end stepping / keep-open switcher), Displays (DDC/CI, honest "may not respond" + display check), Runtime (profile inheritance + doNothing, conflict notes, live feed, Test Mode = dry run, presets, broken-config read-only, deferred tap flush).
- UI (`Sources/EdgyUI`, SwiftUI hosted in AppKit): settings window (tabs, mirror, inspector, icon picker, split control, footer, Advanced, title-bar identity), menu-bar glyph V3 "Lit strip" + glass popover (mini mirror with icons + hover line), Test Mode overlay + always-dark plates + level plate + display check, onboarding (4 steps, shows until finished; `UserDefaults onboardingDone`).
- App wiring (`Sources/EdgyApp`, chief-only): MenuBarController replaces the old StatusMenu; OverlayController always on (Test Mode switch drives plates); SettingsWindowController (Dock while open); OnboardingController on launch; first-run MachineDefaults; config watcher → broken-config state.
- Design source of truth: `docs/BRIEF.md` (wins over renders), `docs/BRAND.md`, renders `docs/design/final/**`, exported assets `docs/design/assets/**` (glyph PDFs bundled in `Sources/EdgyUI/Glyph/Assets`, `Resources/AppIcon.icns`), critiques `docs/design/critiques/batch-*.md`, build shots `docs/design/build-shots/batch-*/`.

## What's left (in order)
1. **Wait for `docs/design/critiques/batch-24.md`** (design session is writing it).
2. **Brief + run batch 25 — final v0.5 polish** (one builder). Fix list:
   - `docs/design/critiques/batch-22.md`: must-fix `AppMark.hasIcon` (WindowParts.swift ~166: a bundle with no own icon → fall back to the "Open App" tile in ink2, not the generic pale square; fixtures: one real-icon app + one iconless bundle), the 4 PARTIALs, all should-fixes, and **answers 1–3** (mini hover line = full width + short zone names "Bottom:" etc.; picker order within a group = icon-table order, most-used first; **SplitPlan**: first part keeps bindings, others start empty, note before the click — behaviour change in `Sources/EdgyUI/Inspector/InspectorModel.swift`).
   - `critiques/batch-24.md` items when it lands.
   - Backlog overlay copy: parameterised run plates use past tense ("Opened Quillpad", "Pressed ⇧⌘ 4", "Ran <name>"); plate-component shot with a black-document half.
   - Chief (not the builder, frozen model): `SettingsModel.decisionSerial` (monotonic) so onboarding step 2 counts exactly; then the builder switches `OnboardingState` to it.
   - Glob: the EdgyUI folders those items touch (Window, Mirror, Popover, Inspector, Picker, Overlay, Onboarding) + their tests + build-shots; NOT Shared/Model/Preview/Glyph assets/Core/Runtime/App/Package.
3. Merge 25 → hand shots to the design session for final sign-off → `/end-ship-train`-style integrated check → Gabriel's **G1 device check** with the design session (glyph V3 in the real menu bar, slab depth, glass over his wallpapers, onboarding switch colour).
4. **Pre-launch (v1)** — see `.parallel-plans/backlog.md`: touch traces (10 priority scenarios in `scripts/record-traces.md`; Gabriel deferred to pre-launch) + tuning; `GestureContext.swipeZones`; right-hand modifiers + recorder key-swallow; external-brightness re-check on the Samsung; MacBook smoke runs. Then a **release plan** (offered, not written): Developer ID signing + notarization, DMG, auto-update, versioning, landing page tie-in with the GTM session.

## Process (what worked — keep it)
- Builders: `claude -w <name>` on the **Mac mini** (Gabriel runs them; he may ssh in via herdr). Each gets a paste-ready prompt: READ FIRST list, ONE scope with "ONLY", allowed / MUST-NOT globs, a `/goal` with anti-reward-hacking guards. **Goal wording lessons:** exempt the vault commit made by `/builder-close`; allow design-ruled test changes when the original assertion is kept beside; when adding scope mid-run, say the turn cap is lifted (else the stop hook loops and Gabriel must `/goal clear`).
- Contracts (`EdgyCore`, `Package.swift`, `Sources/EdgyUI/{Shared,Model,Preview}`, `Sources/EdgyApp`) are **chief-only**; add them on main before spawning.
- Merge: check scope (`git diff --name-only main...<branch>` against the glob), `git merge --no-ff`, run build/test/lint/denylist, push, relaunch (`osascript -e 'quit app "Edgy"'; scripts/run-dev.sh`), rsync to MBP (`rsync -az --exclude '.build/' --exclude '/build/' --exclude '.claude/worktrees/' ~/Projects/edgy/ mbp:Projects/edgy/`). **Binary shot conflicts:** take the builder's version (`git checkout <branch> -- <png>`), never commit a conflicted tree.
- Design loop: the design session ("Design Sprint edgebar") writes BRIEF edits + critiques uncommitted → the chief commits them (denylist first) → folds into the next batch. Ask it for specs/rulings on any visual question Gabriel raises; forward Gabriel's picks.
- Vault: `/builder-close` now uses `sync-vault.sh --manifest` (only the return file). Never `git add -A` in the vault.
- Gabriel: plain English, tables for status, one decision at a time; reviews on the MacBook Pro; prefers seeing it live over screenshots.
