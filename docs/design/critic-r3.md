# Critic round 3 (2026-11-07)

Stop rule: taste-only. The critic produces a fix list only. One Sonnet `design-critic` ran blind on the picked render, 26R-1TVB (A–F), with the r3 bones checklist.

## 26R-1TVB: 6/10 (r2 26-1TVB: 5/10)

| Bone | r2 | r3 | Reason (r3) |
|---|---|---|---|
| B1 | PASS | PASS | No rulers, lines or mm callouts |
| B2 | PARTIAL | PARTIAL | Five shapes read; chips straddle zone edges |
| B3 | PARTIAL | PASS | Slashed circle vs filled dot; measured |
| B4 | FAIL | PARTIAL | One hue, but the toggles use it for "on" (r3 B4 explicitly allows "an on switch"; the chief keeps it) |
| B5 | PARTIAL | PASS | Anchored popover, clear of neighbours |
| B6 | PARTIAL | PARTIAL | Plates dock and clear the text; secondary lines are about 12pt |
| B7 | PASS | PASS | Bite glyph (now replaced by 01a Lit edge; recheck in final) |
| B8 | PASS | PASS | Live top half, plain list below |
| B9 | FAIL | PARTIAL | "Volume" appears ×3; Play/Pause restated |
| B10 | PASS | PASS | Misfire named, two fix buttons |

Totals: r2 had 4 PASS, 4 PARTIAL and 2 FAIL. r3 has 6 PASS, 4 PARTIAL and 0 FAIL. The bones landed.

## Fix list carried into F2

1. Secondary text at ≥13pt and ≥4.5:1: disabled picker rows, section headers, "None", "Sensitivity", "Split into", the D plate sub-line and the Test mode chip. Add more opacity behind the inspector. The glass stays, because Gabriel's taste owns the gradient, but the text gets a solid enough base.
2. One orange value everywhere: the thumb and the plate dot match.
3. Zone chips snap to a fixed inset inside their own zone (none straddles an edge). Remove the duplicate labels the inspector already states. "Mic mute" goes on one line.
4. B: the trigger is the zone on the pad (a selection ring on the bottom edge, with the popover arrow pointing at it), not a row in the inspector. Drop "Play/Pause · on double-tap" from the picker.
5. C: replace the old 16-block volume HUD with a current-style system volume indicator.
6. E: move the cursor off the Test Mode knob so its state is visible.
7. F: fix the icon's right-edge gradient band. The icon and glyph change to the 01a "Exact" anyway.
8. D: replace the generic "Dunes" prose with plausible working text.

Rejected (taste overrides the critic): flattening the glass to paper, and recolouring the on-toggles to ink.

## Final v1 (26F-1TVB), Opus critic: 6/10

| Bone | Verdict | Reason |
|---|---|---|
| B1 | PASS | about 1.6:1 aspect, no rulers |
| B2 | **FAIL** | off-zone labels; edge states differ only by fill |
| B3 | PASS | struck circle vs filled dot |
| B4 | PASS | rust only for live and on |
| B5 | PARTIAL | inspector dropdowns also map |
| B6 | PARTIAL | C's HUD floats undocked (it's the system's own indicator, so the chief ignores this) |
| B7 | PASS | bracket and bar, not a battery |
| B8 | PASS | live top half, plain list below |
| B9 | PARTIAL | "Bottom edge:" repeats the heading |
| B10 | PARTIAL | the misfire is wrong: Tap is unmapped |

**Fixes for v2 (one polish pass, layout and glass unchanged):**
- **Edge states by shape.** Mapped edges are solid inset bars; unmapped edges are hairline outlines.
- **Labels joined to their zone.** Each label is a tab attached to its strip or corner.
- **A true conflict note.** No "Bottom edge:" prefix, and the popover header names its gesture.
- **The inspector shows only mapped gestures**, plus "Add gesture", and its rows open the pad popover.
- **One icon family; type at 13pt and above; ≥4.5:1 text and ≥3:1 graphics; spacing above section headers.**
- **D's document no longer talks about the product.**

## Final v2 (26F-1TVB), Opus critic, same prompt: **7/10** (v1: 6/10)

| Bone | Verdict | Reason |
|---|---|---|
| B1 | PASS | 1.6:1 pad, no rulers |
| B2 | PARTIAL | corner labels float below corners |
| B3 | PASS | dot vs slashed circle |
| B4 | PASS | single burnt orange, live only |
| B5 | PARTIAL | two-column grid, not list |
| B6 | PARTIAL | "Right edge, slide" under 13pt |
| B7 | PASS | open bracket, not battery |
| B8 | PASS | live top, plain list |
| B9 | FAIL | Test mode stated twice (D) |
| B10 | PASS | misfire plus two fixes |

The canvas polishing stops here: one pass, as agreed. These remaining gaps become build rules in BRIEF.md § Design:
- **Say each status once.** Test Mode shows as the glyph dot only, with no extra pill. While the picker is open, the inspector row shows nothing.
- **One HUD/plate component**, shared by the onboarding feedback and the overlay.
- **Corner labels attach flush to their corner tile.** All secondary text is ≥13pt at ≥4.5:1.
- **A single-column picker list** (scrolls if needed).
- **Unify the live-touch contact** with no halo, and make the Test Mode glyph dot ≥2pt at 1×.
- A vs B "incoherence" is intentional: they are different states (B is a split edge) and the brief says so. Its note that "the glyph reads as CI first" was recorded for the G1 device check.
