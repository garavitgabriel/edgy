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

## Performance / system citizenship (measured 2026-11-09, Mac mini, build 16:10 2026-11-07)
- Edgy idles at ~19% of a core with ~2,700 idle wakeups/s while the onboarding window is open (uptime avg 0.3% CPU, so it's state-dependent). `sample` hot path: SwiftUI layout of PadMirrorView/MiniMirrorView every frame.
- Causes found:
  1. `OverlayController` runs `RunLoopClock` at 30 Hz forever (always on), even with no plate up.
  2. `takeDecisions()` writes `pendingDecisions = []` every tick and `receive(_:)` reassigns `liveTouches`/`pendingDecisions` even when unchanged → Observation invalidates every observing view 30×/s.
  3. Mirror bodies recompute `catalogByCategory` (sort) and `availability(of:)` → `LiveBrightnessOutput.builtInDisplay()` (CGGetOnlineDisplayList) per render.
  4. The pointer-guard event tap and the multitouch callback run on the MAIN run loop, the same thread doing (1)–(3): pointer events system-wide wait on Edgy's UI work (input lag; risk of tapDisabledByTimeout). Possible link to Gabriel's "settings freezes" report.
- Fix plan: batch 28 (event-driven overlay, Observation hygiene, cached mirror data, taps/callbacks on their own thread with timeout re-enable) + `scripts/measure-idle.sh` with a budget (idle, no window: <0.5% CPU and <50 wakeups/s; settings open and idle: <3%).

## Requested by Gabriel 2026-11-09 (after the setup review) → batch 32, after batch 28 merges
- **Key sequences** for Keyboard Shortcut: several combos sent in order ("ctrl+b, then n"), so a multiplexer's prefix commands work from one gesture. Stored in the existing `keys` parameter (combos separated by a space; one combo = today's behaviour, old files unchanged); small fixed gap between combos; all keys released on any error; max 4 combos. Recorder UI: record step by step, shown as "⌃B  N" chips (design to spec). Engine = Actions; UI = Inspector (after batch 29).
- **Last App** action (Apps group): back to the app you were in before (one press of the app switcher, no slide). Tap / double-tap / long-press. His main loop is terminal ↔ browser.
- Not possible to split an edge differently per app (he keeps ⌃Tab on the left edge's upper half for the browser's tab overview): consider per-app splits for v1.x.

## Before going public (from batch 31's scan, 2026-11-09)
- Fill `DOWNLOAD_URL` (README) and `SECURITY_CONTACT` (SECURITY.md); add "It updates itself." once the updater ships.
- History has 5 commits with denylist hits (1 message, 4 diffs), private notes in `.parallel-plans/`, home paths in done reports, and a personal email as author on every commit. **Plan: the public repo starts from ONE clean first commit** (noreply author, no `.parallel-plans/`, denylist + home-path grep on that tree); this private repo stays the working one. Needs Gabriel's OK at launch.
