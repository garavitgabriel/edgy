# Batch 20 — EDGY-FEEL: slide feel (short strokes, speed, end-of-edge stepping) and reliable holds

Read `CLAUDE.md`, `.parallel-plans/2026-11-07-edgy-v05.md` (hard rules), then `done-batch-9/10/11/13.md`, `scripts/record-traces.md`, and `Fixtures/traces/` (Gabriel's recorded traces on the Magic Trackpad, if present). **Starts after batch 13 merges** (same files). Runs in parallel with stage-2 UI batches 17–19 (no shared files).

You own `Sources/Gestures/**`, `Tests/GesturesTests/**`, `Sources/Actions/**`, `Tests/ActionsTests/**`, `Sources/EdgyRuntime/**`, `Tests/EdgyRuntimeTests/**`, `Fixtures/traces/**`, `scripts/record-traces.md`, `scripts/smoke-actions.sh`, `docs/settings-reference.md`.

## Why
Hardware use (Gabriel, 2026-11-07): the app switcher runs out of edge with many apps open, because lifting selects and closes it; volume doesn't have this problem because its level stays where you left it, so short repeated strokes work. Push-to-talk holds end when another finger points, and the 500 ms hold delay is slow for talking. Goal: every slide feels like volume — short strokes continue, quick flicks go further, resting at the end keeps going — and holds stay held.

## Contracts already on `main` (chief)
- `GestureEvent.zoneLengthMM` and `GestureEvent.atEnd` (-1/0/+1 while the finger rests at the low/high end of a slide zone).
- `ActionContext.motion: SlideMotion?` (deltaMM, timestamp, atEnd).
- `GestureContext.longPressMSByZone`.

## Build
1. **One shared slide-feel model** (pure, in Actions, fully unit-tested): travel in mm → steps, with
   - a **step size in mm** (stepped actions; same on every pad and segment),
   - **speed-up**: a gain curve on speed (mm/s from `motion`), gentle and continuous — slow = precise, quick flick = more steps/level; parameters documented as named constants,
   - **end-of-edge stepping**: while `atEnd ≠ 0`, keep stepping at a steady rate (named constant, e.g. 6 steps/s, easing in) until the finger moves away or lifts.
2. **Per kind of slide** (parameters per binding, catalog descriptors updated, all optional with defaults):
   | Kind | Actions | Gets | New parameters |
   |---|---|---|---|
   | App switcher | `apps.switcher` | mm steps, speed-up, end stepping, **keep open between strokes** | `stepMM` (4…20, default 8), `speedUp` (on/off, on), `keepOpenMS` (0…1000, default 400) |
   | Repeated keys | `keyboard.slideSteps` | mm steps, speed-up, end stepping | `stepMM` (replaces the fraction `step`; migrate: keep reading `step` if present, convert with the zone length), `speedUp` (on) |
   | Levels | `audio.volume`, `display.brightness`, `keyboard.backlight` | gentle speed-up only | `speedUp` (on/off, default on, gentle) |
   - **Keep open between strokes (switcher):** on `.ended` the command key stays down for `keepOpenMS`; a new `.began` on the same binding within that time continues the same switcher session (no new cmd-down, no selection). It selects (cmd up) when the window passes, or immediately on a click or pointer movement (a listen-only source behind a protocol, installed only while a session is open), or Esc cancels. An interruption (`.cancelled`: palm, second finger) **keeps the session open** like an end. Sliding back past the starting point by one step cancels. Never leave cmd stuck: all exits release; the existing 10 s watchdog stays.
   - Haptics: one crisp tick per app/step passed; a stronger click when the switcher wraps or end stepping starts.
3. **Gestures:** fill `zoneLengthMM` and `atEnd` on slide events (resting within the end band of the zone, using the existing rest logic — document the band). Honour `longPressMSByZone`.
4. **Reliable holds:**
   - Once a long-press has **begun**, another finger moving no longer revokes it (`foreignMotionMM` applies only before the hold begins); a palm, click or extra resting fingers still cancel per the existing rules — document every cancel reason that remains.
   - Runtime: release the pointer guard once a hold has begun (the held finger is still), so another finger can point while talking; re-engage nothing until the next claim.
   - Runtime passes `longPressMSByZone` from a per-binding `holdMS` parameter (100…1500; `keyboard.hold` suggests 300 ms in its descriptor default; other long-press bindings keep the global setting unless set).
5. **Tune against real traces:** replay every `Fixtures/traces/*.json`; set `longPressMaxTravelMM`, the end band and the speed curve from them; each change with before/after in the done report. If no traces exist yet, keep current values and list the scenarios needed.
6. **Copy and presentation** come from `docs/BRIEF.md` § Binding parameters → "Slide feel and hold timing (batch 20)": every new parameter's `displayName`, `helpText` and `unit` exactly as the table there, `zeroLabel: "Off"` on `keepOpenMS`, and `holdMS` with `fallback: .longPressMS` on long-press bindings other than `keyboard.hold` (which defaults to 300). Add a validation **info** note `slideAndSwipes` (stable code, documented) when an edge has both a slide and a swipe, with BRIEF's copy, and make the swipe threshold stricter on such edges.
   Also relabel `keyboard.hold`'s existing `maxSeconds` per BRIEF: "Let go after", unit "s", BRIEF's helper line, ordered last before the haptics row.
   Normalise catalog `displayName` spellings so the UI never re-spells them (e.g. pick one of "Play / Pause" / "Play/Pause" and use it consistently; document the rule).
7. `scripts/smoke-actions.sh`: steps for short-stroke switching with many apps open, flick speed, end stepping, push-to-talk while pointing, and confirming `fn` reaches a dictation app (if not, the done report recommends a non-fn push-to-talk key).

## Acceptance
- ≥ 35 new tests: mm stepping identical across two pad sizes and segment counts; speed-up monotonic, gentle, capped; end stepping rate, ease-in and stop; switcher keep-open (continue within window, select after, select on click/pointer move, Esc cancel, interruption keeps open, slide-back cancel, watchdog, cmd always released); slideSteps migration from `step`; level speed-up off = old behaviour exactly; Gestures `zoneLengthMM`/`atEnd`; per-zone hold time; hold survives foreign motion after begin and still cancels on palm/click; pointer guard released after hold begins; trace replays.
- Existing tests unchanged in intent (document any expectation that moves because the feel changed, with why).
- `docs/settings-reference.md` updated with every new parameter.
- Verification triple green, denylist clean.
- Done report "Needs Gabriel": the smoke steps; how short strokes / flicks / end stepping feel on the Magic Trackpad and the MacBook; push-to-talk while pointing.
