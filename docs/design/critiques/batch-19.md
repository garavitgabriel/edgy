# Batch 19 critique (onboarding)

Verdict: structurally right: four steps in 640 × 520, the step row correct, one 26 pt headline, and the round primary at bottom right. Every BRIEF string is exact, and dark matches light. Not ready: step 1's mirror clips labels that fit. Fix 1 item and re-shoot.

**Fitted 2.3 pt/mm mirror under bone 1: acceptable.** Each mirror has one constant scale at the true 1.39:1 proportion, with no rulers and 13 pt labels. Bone 1 lets the scale differ between surfaces. One catch: step 1 (about 297 × 213 pt) is about 82% the size of step 2 (about 363 × 261 pt), so both can't be 2.3 pt/mm. See Should fix 1.

## Must fix

1. **Step 1 clips labels that have room.** Shots: `step1-accessibility-*`, `step1-granted-*`. They read "Mic (", "Mute" (cut through the "e") and "Brightne". Bone 3 allows the fade only after the short value and short name fail. "Mic off" and "Mute" are short names, and "Brightness" fits easily on a mirror about 297 pt wide. Batch 21 draws all three in full. Fix: size each tab to its text, or drop the corner tabs as S6 does (Q1).

## Should fix

1. **Draw steps 1 and 2 at one scale.** Shots: `step1-*` vs `step2-*`. It's one pad in one window, and the mirror grows about 22% on Continue. That's legal, but it reads as a different device. Fix: one scale for both steps, and correct the 2.3 pt/mm note.
2. **The bottom label overflows its bar on step 1.** Shots: `step1-*`. The 13 pt "Tracks and Play/Pause" is taller than the bar and rises above its top edge. Bone 3 says top and bottom labels "sit inside the bar". S6 has the same flaw. Fix: grow the inset fill to the label's height, with the zone kept to scale.
3. **Step 1's corner tabs aren't flush to their tiles.** Shots: `step1-*`. "Mic" and "Mute" hang below and inboard of the corner tiles and sit over the side strips' tops. This is batch 21's 14 M2, and it's worse at this scale. Q1 removes it.
4. **The step 4 switch floats.** Shots: `step4-launch-at-login-*`. The switch sits near x ≈ 385 pt. Fix: right-align it to Done's right edge (about 608 pt).
5. **Step 3 rows are cramped.** Shots: `step3-*`. The 120 pt mini mirrors almost touch from row to row (about 6 pt apart), and the selected row's outline sits about 4 pt from the mirror tops. S7 breathes. Fix: about 8 pt padding inside each row.

## Matches BRIEF

- Step row: "Accessibility", "Try it", "Pick a preset", "Launch at login"; done steps take ✓; the current step is semibold with a filled number.
- Step 1: "Let Edgy run your actions" / "Edgy uses it to keep the pointer still while you slide and to send the keys most actions need." (one sentence; S6's two-sentence body is correctly not used) / **Open Settings** / "Skip for now". Granted: ✓ in the step row, "Access granted.", **Continue**.
- Step 2: the headline is one clause with no colon ("Rest a finger on the right edge and slide up"). Only the right edge is mapped, as in render C. Live state: an accent contact with a rim, the lit bar and Volume tab with a thin accent outline, and selection and live kept distinct. Edgy draws no "64%" itself (bone 8).
- Step 3: "Pick a starting point". Media is preselected. The row lines are exact. Mini mirrors are 120 pt and drop their corner icons, which bone 3 allows. Zones match each preset: Media has mic/mute corners, three mapped edges and an unmapped top. Windows has the top edge plus two corners mapped. Minimal maps only the sides, with every corner dashed. "You can change any of it in Settings." sits in `ink2` under the rows, then **Continue**. The radio uses `ink`, not accent.
- Step 4: "Keep Edgy running" / "Open Edgy when you log in" (the switch reads on) / **Done**.
- One hue only. No text under 13 pt. Primaries are `ink` in light and cream in dark, never accent.

**NOT SHOT:** the system volume indicator beside the window on step 2 (it's system-drawn, so it needs the device); Done → the window closes and the popover opens once; the live flip from Open Settings to granted (only the end states are shot); any step 2 rejection feedback (see Q3).

## Questions for design

1. **Corner tabs on the step 1 mirror:** keep them, sized to fit, or drop them the way S6 does and let the icons carry mapped corners? I'd drop them. Step 1 is about permission, not mapping, and this mirror is busy at about 297 pt.
2. **Step 2 Continue is disabled until a slide lands.** Shots: `step2-try-it-*`. Neither BRIEF nor render C asks for that gate, and a user who chose "Skip for now" may never get a slide to register. Should Continue always be enabled? I'd say yes.
3. **Feedback for a failed slide on step 2:** if a slide is rejected (palm, too short), does the step show anything? If it does, bone 9 says it must be the one dark plate, with the cream rim on its contact. None of these shots exercises that.
4. **Placing the volume indicator:** render C has the system indicator beside the window. Should the window open left of centre so it lands beside it rather than behind it, or do we accept wherever the system puts it?
5. **The step 4 switch track is neutral, not accent.** Batch 21 ruled switch colour device-only (headless), so I haven't flagged it. Confirm the step 4 switch gets the same G1 device check.

## Design answers (chief, 2026-11-07)
1. **Step 1 mirror:** drop **all** label tabs. Step 1 is about permission, so its mirror is an illustration: zone shapes and corner icons only, no text.
2. **Step 2 Continue is always enabled.** A landed slide only adds the ✓ in the step row. Nobody gets stuck, especially after "Skip for now".
3. **A rejected slide on step 2** shows the rejection the same way the app does: the struck contact on the mirror, plus **the one dark plate** beside the mirror with BRIEF's copy ("Ignored: swipe too short, 4 mm, needs 6 mm"), with its cream rim. Shoot it.
4. **The system volume indicator's position:** accept wherever the system draws it. Don't move the window to chase it.
5. **The step 4 switch colour:** yes, it goes to the G1 device check, like the others.

On the fitted scale: acceptable (one scale per mirror), but **steps 1 and 2 must share one scale.** Fix that should-fix.
