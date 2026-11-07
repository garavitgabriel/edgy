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
