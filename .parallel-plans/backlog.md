# Edgy backlog (chief)

Items found in testing or left open by builders, to fold into a future round.

## External brightness honesty (found 2026-11-07, Mac mini)
- A third-party monitor (S34CG50) passes the DDC probe and reports writes back (set 0.6 → get 0.600), yet the screen doesn't change. Edgy marks it `controllable`; for the user it isn't.
- Fix: availability for DDC-only displays becomes `limited("may not respond — some monitors accept brightness commands without applying them")`, and the first real brightness slide on an unconfirmed external display asks once "Did the screen change?" (settings UI / onboarding), remembering the answer per display (persisted, keyed by display identity), so a "no" turns brightness off for that monitor.
- Second monitor (LG) fails the probe; reason text is already right.

## Keys
- Right-hand modifiers (right option etc.) for push-to-talk: `KeyCombo` contract change (batch 11 open question).
- Key recorder can't swallow keys: recording cmd+space also fires the system shortcut (batch 11). Needs an active (not listen-only) tap while recording.

## Gestures
- `longPressMaxTravelMM` 1.0 and `foreignMotionMM` 3 unconfirmed against real traces; Gabriel hasn't recorded traces yet (`scripts/record-traces.md` §1–29).
- `foreignMotionMM` revokes a hold when another finger moves: push-to-talk while pointing isn't possible (batch 9).

## Hardware not yet run
- MacBook Pro: keyboard backlight, built-in brightness HUD, `scripts/smoke-displays.sh`, smoke-actions steps 17–28 (MBP was unreachable over SSH 2026-11-07).

## From batch 20 (2026-11-07)
- `GestureContext.swipeZones` so the stricter swipe threshold applies only on edges that also have a swipe (today: every slide edge).
- Tune slide feel / hold stillness against real traces (scenarios 30–34 in scripts/record-traces.md).

## Gabriel's hardware verdicts (2026-11-07, MacBook Pro)
- Slide feel (batch 20 defaults): "feels good overall" — keep 8 mm per app, 0.4 s keep-open, speed-up curves; speed-up now off by default for stepped slides (design ruling).
- Menu-bar glyph: reads as "CI" some of the time → design session runs a glyph pass (variants at true 16 pt); swap the exported PDFs when picked.
- Touch traces: deferred to the pre-launch pass (v1). Record the 10 priority scenarios in scripts/record-traces.md, then tune hold stillness, swipe thresholds and the end band.

## Overlay follow-ups (critique 23 should-fix, chief to do after 22/24)
- Parameterised run plates: past-tense verb + object ("Opened Quillpad", "Pressed ⇧⌘ 4", "Ran <name>"); plain triggers stay bare.
- plate-component shot gets the black-document half.

## From batch 24
- `SettingsModel.decisionSerial` (monotonic) so onboarding step 2 counts new decisions exactly (today: overlap inference, can only miss a decision repeating a full 32-window).
- ~~Rejected mark rim?~~ Resolved by design: no rim on the struck mark (ink2 on the dark plate already clears 3:1); PlateView stays as is.

## Switch Apps opens on contact (Gabriel, MBP, 2026-11-07) → batch 26
- Top-edge Switch Apps opens without a real slide: a 120 ms rest claims the slide and `.began` opens the switcher. Fix in batch 26: it opens after one `stepMM` of travel; strokes that never reach that press nothing.

## From batch 26 (2026-11-07)
- Router still plays `gestureCaught` on every slide `.began` (a resting finger ticks once on the switcher edge) and emits `actionRan(outcome: nil)` on `.began`; full silence until the switcher opens needs a Router change (EdgyRuntime).
- `switcherAppCount()` still runs on every `.began`; move it to the opening.
- Sensitivity scales the opening travel (sensitivity 2 opens at 4 mm of real travel) — note in settings-reference.
- EdgyUI `ParameterPresentationTests` / `Batch15SnapshotTests` hardcode the old Switch Apps helper line in their own descriptors; re-point at the catalog and re-shoot `batch-22/inspector-switch-apps-keep-open-off`.
