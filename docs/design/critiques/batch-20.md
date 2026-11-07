# Batch 20 critique (slide feel + hold timing rows)

Verdict: what's visible is right; most of the batch is unproven. There are no batch 20 shots, so the proof is batch 21's `inspector-long-labels-*` (Switch Apps) and `window-default-*` (Volume). Those rows match BRIEF character for character, defaults are `ink2`, and stacking holds. Eight of twelve spec items are NOT SHOT, including every hold-timing row and the slide-plus-swipes note. That blocks sign-off.

## Must fix

1. **Shoot the missing rows.** Add batch-21 harness fixtures that cover every NOT SHOT item below: Hold Keys open (300 ms, 120 s), a long-press at "Default (500 ms)" and changed with **Reset**, keep-open at 0, one changed slider, Repeat Keys open, and an edge with a slide plus a swipe.

## Should fix

1. **Helper lines crowd the next row.** Shots: `inspector-long-labels-*`. This repeats batch 21 New S2. With no extra space after it, a helper line reads as a caption for the next label.
2. **Checkbox helpers start under the box, not under the label.** Shots: `inspector-long-labels-*`, `window-default-*`. "A quick flick skips several apps." starts at the checkbox's x, about 20 pt left of "Faster when you flick". Fix: indent checkbox helpers to the label's text start.

## Matches BRIEF

- Switch Apps: "Distance per app", "8 mm", "Slide this far to move one app."; "Faster when you flick", "A quick flick skips several apps."; "Keep open between strokes", "400 ms", "Lift and slide again to keep going; it picks the app when you stop, click or move the pointer." All are exact.
- Volume: "Faster when you flick" is checked by default, with "A quick flick moves the level further." (exact).
- Default values (8 mm, 400 ms, 100%) draw in `ink2` (sampled at about #6D4D3E).
- Stacking: in Switch Apps, "Keep open between strokes" doesn't fit beside its slider, so every slider label in that binding stacks. In Volume, "Sensitivity" stays inline. No label breaks mid-word. Slider tracks share one x.
- Helper lines are 13 pt `ink2`, one per row, and appear only under the open binding.

**NOT SHOT:** `stepMM` / `speedUp` for Slide to Repeat Keys ("Distance per press", "Slide this far for one key press.", "A quick flick sends several presses."); `holdMS` for Hold Keys ("Hold before it starts", 300 ms, "How long to press before the keys go down."); `holdMS` "Press time" with "Default (500 ms)" / **Reset** / "How long to press before it runs."; `maxSeconds` "Let go after", "120 s", "If a lift is missed, the keys come back up after this long."; `keepOpenMS` "Off"; a changed value in `ink`; the note "Quick slides can look like swipes here, so swipes need a clearer flick on this edge." with "Move swipes to another edge".

## Questions for design

1. **Is `speedUp` on by default for Switch Apps?** BRIEF marks only Volume, Brightness and Keyboard Brightness "on by default", but the fixture shows it checked. If it was turned on in the fixture, it's a changed value with no visible mark. A checkbox has no `ink2`/`ink` value to carry one. Is that acceptable for checkboxes?
2. **Switch Apps also shows "Sensitivity 100%".** BRIEF's batch 20 table lists only `stepMM`, `speedUp` and `keepOpenMS` for Switch Apps. Does Sensitivity belong on Switch Apps when "Distance per app" already sets how far one step is, or is it a leftover generic number row?

## Design answers (chief, 2026-11-07)
1. **`speedUp` defaults:** **off** for Switch Apps and Slide to Repeat Keys (predictable stepping), **on** for the levels (Volume, Brightness, Keyboard Brightness), as BRIEF says. Checkboxes carry no default/changed mark; their state is the mark. That's acceptable.
2. **Sensitivity on Switch Apps:** hide it. Wherever `stepMM` is shown (Switch Apps, Slide to Repeat Keys), the generic `sensitivity` row is hidden, because "Distance per app/press" already sets travel. Sensitivity stays on the levels.
