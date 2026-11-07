# Batch 17 — EDGY-POPOVER: menu-bar glyph, popover, system states

Read the v0.5 shared brief, the stage-2 brief, `docs/BRIEF.md` § Design in full (bone 10, § Menu glyph and app icon, § System states, § Test Mode: what it does, § Issue states — broken config), renders E, F, S5, and `docs/design/assets/README`.

## Build
1. **Glyph:** `MenuGlyph.image(for:)` returns the template image for each state from the exported PDFs (disabled / no trackpad = normal at 40% opacity), at the right point size; precedence per § System states (broken config > No Accessibility > No trackpad > Paused > Disabled > Test Mode) as a pure function `MenuGlyph.state(engine:editor:testMode:accessibility:)` (document inputs; tested).
2. **`MenuPopoverView`**: top half = `MiniMirrorView` + profile chips (live chip filled, others outlined, frontmost app's chip first; clicking opens Settings on that tab — via a closure) + **Enabled** and **Test Mode** switches + the **"Don't run actions"** checkbox (indented 24 pt, visible only while Test Mode is on, off by default, not persisted, resets when Test Mode turns off) — Test Mode on = overlay on with actions running (`model.isTestMode` stays false unless "Don't run actions" is checked, which calls `model.setTestMode(true)`); expose the overlay-visible flag for batch 18 via a closure/binding you define. Bottom half = plain list with the system highlight: Pause for 1 hour (hidden while paused), Settings… ⌘,, Open config file, Reload config ⌘R, About Edgy, Quit Edgy ⌘Q. No power button, no hero numeral, no cards on cards.
3. **States in the popover** per § System states (paused line + Resume with whole minutes / "less than a minute left"; No Accessibility block + Open Settings + "Touches still show in Test Mode."; no trackpad dashed mini pad; disabled fade) and broken config (§ Issue states).
4. **`MenuBarController`** per the stage-2 brief.

## Acceptance
- Snapshots (light + dark) in `build-shots/batch-17/`: glyph sheet (all states at 1× and 2×), popover normal, Test Mode on, Test Mode + "Don't run actions", paused, No Accessibility, no trackpad, disabled, broken config, an app chip live.
- ≥ 14 tests: glyph precedence table; time-left copy (47 min, 1 min, under a minute); "Don't run actions" visibility + reset on Test Mode off; Pause row hidden while paused; chip order; list actions call the closures.
- Bones checklist + reader-first review vs E, F, S5; token greps clean; verification triple + denylist.
