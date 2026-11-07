# Final render (F2): 26F-1TVB (2026-11-07)

This is the polished final of Gabriel's pick. It goes on a NEW Claude Design canvas. It is the reference the build follows.

## Base

- **The full brief is still** `r3-src/26R-1TVB/prompt.md` (CONTEXT, DELIVERABLE A–F, BONES, kill list, keeps). Keep all of it, except where a line below overrides it.
- **The skin source is** `r3-src/26R-1TVB/` (build.py and the A–F.html files). Its renders are `r3/26R-1TVB-A..F.png`. Keep the palette, type, layout and materials.

## Changes from 26R-1TVB

### 1. Glyph: 01a "Lit edge" (replaces Bite everywhere)

- A landscape rounded-rectangle outline, open on its right side, about 16 × 11 pt, monochrome template.
- Beside it on the right, a separate heavy vertical bar the height of the outline. That bar is the "lit" right edge.
- Use the wider gap from 01b between the outline and the bar, so at 16 pt it never reads as a battery.
- Reference images: `r3/GLY-IM2G-G1.png` (01a, 01b) and `r2/GLY-DC73-G1.png` (01).
- Test Mode state: a small solid dot inside the outline, still monochrome.

### 2. App icon: "Exact" (artboard F)

- Reference image: the left icon in `r2/GLY-DC73-G3.png`.
- A pale stone squircle tile with a subtle top-to-bottom light, and a graphite line drawing of the pad at true proportion with its right edge drawn heavy and set apart (the 01a glyph, enlarged).
- At ≥128 px, add one small rust "live" contact dot resting on the heavy right edge. Use the same rust as the app accent. Leave the dot off at 32 px.
- No gradient band or artefact at the tile edge.
- F shows: the icon at ~512 (it may be drawn at 320), 128 and 32. The glyph at 16 pt and at 2× zoom, on a light bar and a dark bar, beside Wi-Fi and battery. Plus the glyph's Test Mode state.

### 3. Slab depth on the pad mirror (merged from OBJ-J9IQ, `r3/OBJ-J9IQ-A.png`)

- The glass pad gains a subtle physical thickness: a soft lower edge or bevel and a gentle top-left light.
- A recognized touch presses in slightly: a soft inner shade around the filled accent contact. No glow halo.
- Keep it subtle, so the pad stays glass, not ceramic. Apply it everywhere the mirror appears: A, B, C and E's mini mirror.

### 4. Critic fixes (`critic-r3.md`)

- **(a) Text size and contrast.** Every piece of secondary text is ≥13 pt and ≥4.5:1: disabled picker rows, picker section headers, "None" values, "Sensitivity", "Split into", the D plate sub-lines and the Test mode chip. Add enough opacity behind the inspector column and the popover for that to hold. Keep the warm glass; just give the text a solid base.
- **(b) One accent value.** The rust is identical everywhere: the pad thumb, the plate dot, the toggles and the icon dot.
- **(c) Zone labels.** Each chip sits at a fixed inset inside its own zone and never straddles a zone edge. "Mic mute" fits on one line (a smaller chip or a shorter label such as "Mic off"). The inspector restates nothing the pad chip already says, and vice versa.
- **(d) B, mapping on the pad.** The bottom edge on the mirror shows the selection ring, and the popover's arrow points at that zone on the pad. The inspector row is not the trigger. Drop "Play/Pause · on double-tap" from inside the picker; the conflict note already says it.
- **(e) C, volume indicator.** Draw a current-style system volume indicator: a slim rounded capsule with a speaker symbol and a fill bar, not the old 16-block square. Say 64% once.
- **(f) E, cursor.** The pointer rests just beside the Test Mode switch, which is visibly ON.
- **(g) D, document text.** Use plausible working text: e.g. a project update or meeting notes in an invented text editor, with the cursor mid-paragraph. No literary filler.

## Unchanged

Everything else stays as in 26R-1TVB:
- the window structure
- the profile tabs with their monochrome app marks
- the conflict note wording
- the overlay plates
- the popover structure
- the onboarding headline
- the invented names (Wayfare, Huddle, Margin)
