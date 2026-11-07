# Batch 13 — EDGY-ENGINE-5: the data the designed UI shows

Read `CLAUDE.md`, `.parallel-plans/2026-11-07-edgy-v05.md`, `docs/BRIEF.md` § Bones 4, § Level plate and display check, § Test Mode, § Onboarding steps, § Issue states; then `done-batch-10..12.md`. You own Gestures, Actions, Displays (implementation; the contract types are frozen except as noted), EdgyRuntime and their tests, plus `docs/settings-reference.md`. Three deliverables:

## 1. Measured rejections and action outcomes, end to end into the feed
- **Gestures:** fill `GestureOutput.rejectionMeasures` for every rejection where a number means something, in the units BRIEF's copy table uses. Find out what each `RejectionReason` *actually* measures in the pipeline (e.g. `tooFast` is decided where? by speed in mm/s, or by time vs dwell?; `offAxisMotion` is travel in mm, not an angle) and report the real measure + limit for each reason in the done report as a table — the chief forwards it to the design session to fix BRIEF's copy where it guessed. `physicalClick` and `systemGestureHandoff` carry none.
- **Actions:** implement `performReporting` for level actions (volume, display brightness — built-in and external —, keyboard backlight: `level` after the change; `systemHUDShown` true when the system drew its HUD; external brightness `detail` = the display's name), `keyboard.hold` (`detail` = the combo's display text, e.g. "fn"), `apps.switcher` (no level). Everything else may report nil.
- **Runtime:** the router calls `performReporting`; `LiveDecision` carries the outcome on `actionRan` and the measure on `rejected` (additive fields/cases in your module; keep the existing cases' meaning). Tests from fake recognizers/actions through the feed.

## 2. Honest external brightness (backlog item, `.parallel-plans/backlog.md`)
- **Displays:** fill `DisplayInfo.key` with an identity that survives reconnects (vendor + model + serial from the display's own info where available; the name otherwise). DDC-only displays report `brightnessControllable` as today, but Actions' availability for them becomes `limited("May not respond: some monitors accept brightness commands without applying them.")` until confirmed.
- **Actions:** brightness skips any display whose key is in `AppSettings.unresponsiveDisplays` (unavailable, reason "Turned off for this display."), and for an unconfirmed external display reports in its outcome that a check is due (additive field in your module or the outcome `detail` — document) when `displayCheckAsks[key] < 3` and the key isn't in `confirmedDisplays`.
- **Runtime:** `SettingsEditor` API to record a check answer (yes → confirmed; no → unresponsive), to count an ask, and to "Turn back on" a display; a feed decision (`displayCheckDue(key:name:)` or similar) the overlay batch will draw. Tests on fakes.

## 3. Presets and the broken-config state
- **Presets** (onboarding step 3): `Presets.media` = `EdgyConfig.defaults`; `Presets.windows` and `Presets.minimal` exactly as BRIEF § Onboarding steps lists them (already corrected to supported gestures: bottom long-press → maximize, top double-tap → Mission Control) — **validate every binding** and report any that fail. Each preset passes `MachineDefaults` before it's applied. A `SettingsEditor` method applies a preset (one undo step).
- **Broken config on reload** (BRIEF § Issue states): when the file on disk stops decoding or validating, keep the last working config running, expose `configProblem` (message + line if available) on `SettingsEditor`, make edits throw a read-only error while it stands, and offer `replaceFileWithCurrentSettings()` (writes the running config; the UI confirms first). Clears when the file is fixed and reloads.

## Acceptance
- ≥ 30 new tests: a measure for each reason that has one (and none for click / handoff); outcome for each level action, hold and the default nil; feed carries both; display key stability on fakes; unresponsive skip; limited availability copy; check-due counting (stops at 3, never for confirmed); editor answer / turn back on; presets validate clean on the real-catalog-shaped fake and survive `MachineDefaults`; broken-config: running config kept, edits refused, replace works, recovery on fix.
- Existing tests unchanged in intent; `docs/settings-reference.md` updated (new editor methods, presets, the measure table).
- Verification triple green, denylist clean.
- Done report: the measure table; "Needs Gabriel": none expected beyond the Samsung re-check after merge.
