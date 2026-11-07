# Batch 24 critique (onboarding polish)

Verdict: ready, with one question about BRIEF itself (Q1). Every critique-19 must-fix and should-fix is fixed. Step 1's mirror is now an illustration, steps 1 and 2 draw the same mirror, Continue never gates, and a rejection shows the struck contact plus the one dark plate. Two placement nits follow.

Measured at 2× in a 640 × 520 window. The mirror is **320 × 230 pt** in every step 1 and step 2 shot, and step 3's mini mirrors are **120 pt**. Continue is pixel-identical across try-it, after-slide and rejected. The plate fill is `#2A1B15` at about 0.92, as in batch 23. The plate has a 0.5 pt light edge in dark and a radius of about 12.5 pt.

## Critique-19 items: status

| Item | Status | Evidence |
|---|---|---|
| M1 Step 1 clips labels | FIXED | `batch-19/step1-*`: no tabs at all, so nothing clips. |
| S1 Steps 1 and 2 at one scale | FIXED | `step1-*` and `step2-*`: both are 320 × 230 pt. |
| S2 Bottom label overflows its bar | FIXED | `step1-*`: there's no label left to overflow. |
| S3 Corner tabs not flush | FIXED | `step1-*`: the mic and mute icons sit inside their tiles, with no tabs. |
| S4 Step 4 switch floats | FIXED | `step4-launch-at-login-*`: the switch's right edge is at 607.5 pt, flush with Done. |
| S5 Step 3 rows cramped | FIXED | `step3-*`: there's about 7.5 pt between the selected outline and the mirror, and 14.5 pt between the mini mirrors. |
| A1 Step 1 mirror has no label tabs | FIXED | `step1-*`: zone shapes plus the mic and mute corner icons only. |
| A2 Steps 1–3 share one fitted scale | PARTIAL | Steps 1 and 2 match exactly. `step3-*` mini mirrors are 120 pt, as BRIEF's step 3 asks. See Q1. |
| A3 Continue always enabled | FIXED | `step2-try-it-*`: enabled before any slide, and pixel-identical to after-slide. A landed slide adds only the ✓ (`step2-after-slide-*`). |
| A4 Rejected slide: struck contact plus dark plate | FIXED | `batch-24/step2-rejected-*`: a hollow struck `ink2` circle on the right bar, and below it a dark plate reading "Ignored: swipe too short, 4 mm, needs 6 mm". The circle has no rim, per the ruling. See New should fix 1–2. |
| A5 Volume indicator wherever the system draws it | NOT SHOT | System-drawn, so it needs the device. Nothing in Edgy repeats "64%" (bone 8). |
| A6 Step 4 switch colour, G1 device check | NOT SHOT | Device check, as agreed. |
| Carried over: Done → popover; the live permission flip | NOT SHOT | Only end states are shot. |

Counts: 10 FIXED, 1 PARTIAL, 0 OPEN, 3 NOT SHOT.

## New must fix

None.

## New should fix

1. **The struck contact touches the Volume tab.** Shots: `batch-24/step2-rejected-*`. The circle (y 229–247 pt) overlaps the tab's top-right corner and sits about 0.5 pt from the "e", so it reads as part of the label. Fix: stage the demo contact clear of the tab.
2. **The plate is off the mirror's axis.** Shots: `batch-24/step2-rejected-*`. It spans x 133–479.5 pt (347 pt wide, hugging its text with 18 pt inset). Its right edge is flush with the mirror's, but its left edge overhangs the mirror by 27 pt, so its centre sits 14 pt left of the window and mirror centre (320 pt). Fix: centre the plate under the mirror.

## Matches BRIEF

- All copy matches BRIEF character for character: steps 1–4, the granted state ("Access granted."), the step 2 headline (render C), and the plate (the bone-4 row "Ignored: swipe too short, 4 mm, needs 6 mm").
- Step row: done steps take ✓, and the current step is semibold. "Try it" has no ✓ after the rejection, which is correct.
- Bone 4: the struck `ink2` circle and its one 13 pt line match batch 18's overlay plate. The filled accent contact (after-slide) stays louder.
- Bone 9: one dark plate in both appearances, with the 0.5 pt edge over dark.
- Bone 1: no rulers, and the mirror doesn't move when the plate appears.
- Preset zones are correct, and radios and primaries are `ink` or cream, never accent.
- The menu glyph isn't in frame (these are window-only captures).

## Questions for design

1. **BRIEF contradicts itself on step 3's scale.** "Mirrors in onboarding" says steps 1–3 use "one scale for all of them", but step 3 specifies "a 120 pt mini mirror" per row. The build draws steps 1–2 at 320 pt and step 3 at 120 pt. I'd keep the 120 pt thumbnails, which bone 3 covers for mirrors under about 200 pt, and reword the line to "steps 1 and 2 share one scale".
2. **Plate "beside the mirror" vs under it.** BRIEF's Step 2 extras say "beside the mirror". The build puts the plate under it, because a 347 pt plate can't fit beside a 320 pt mirror in a 640 pt window. Accept "under the mirror" and update BRIEF?

## Design answers (chief, 2026-11-07)
1. **Step 3 scale:** agreed. BRIEF is reworded so **steps 1 and 2 share one scale**, and step 3 keeps its 120 pt preset thumbnails (the under-200 pt mirror rule). The PARTIAL is closed as FIXED.
2. **Plate placement:** accepted. The rejected-slide plate sits **under the mirror, centred on it** (fix the 14 pt offset, should-fix 2). BRIEF is updated.
