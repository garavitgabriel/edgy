# Bones: Edgy (round 2)

B1–B7 were drafted on 2026-11-04 from the product constraints, before any render existed. On 2026-11-05 they were revised against 14 blind round-1 critiques (7 directions × screen A + screens B–F; see `critic-r1.md`). Each bone notes its evidence. Each bone must be something you can check by looking at a render.

## Hard structural rules

B1. **The mirror is the pad.** It's drawn to scale, at the real aspect ratio and in the trackpad's orientation. **No dimension lines, rulers or mm callouts in the editor.** The outline is the measurement. *(Draft. Rulers were flagged in 6, 13 and both 6 passes; Gabriel independently: "why 100 mm?")*

B2. **Five zone states read at a glance, by shape as well as colour:** unmapped, mapped, mapped corner (wins), pass-through corner (falls to its edge), and selected. Selection and live touch never share one colour treatment. *(Draft, sharpened. Selection and touch were the same blue in 1. Black corners in 23 read as active. Every critic said "mapped vs unmapped too faint".)*

B3. **Recognized vs rejected is the main signal.** They differ by **shape** (e.g. a filled contact vs a hollow or struck true-scale contact ellipse), not by colour alone. A rejection names its reason in plain words **with the measured value against the limit** ("Ignored: palm, 21 mm wide, limit 18 mm"). Recognized is visually louder than rejected. *(Draft, sharpened. KEEP from 6 and 12, independently. "REJECTED as loud as RECOGNIZED" in 23F. Colour-only in 23.)*

B4. **One accent means "live".** It marks a recognized touch or the active zone, and nothing else. Warnings use type weight and an icon, not a second hue. *(Draft. Amber/orange warnings in 23 and 23F; a lone teal in 26.)*

B5. **You map on the pad.** Clicking a zone on the mirror selects it. The action picker is a **list** (searchable, grouped) in a popover **anchored to that zone with an arrow**, never covering its trigger and never spilling outside the window. Labels sit on or beside their zone, horizontal, **never rotated**. Actions that can't take the current gesture are dimmed with the reason ("needs a slide"). The picker carries **no** copy about future actions. *(Draft, rewritten. 7/7 critics: the diagram only displays, the picker floats or covers its trigger or spills out, rotated labels. "More actions coming" footer in 6 of 7, which our own DELIVERABLE line caused.)*

B6. **The overlay never takes focus and never sits on the text you're working in.** It's click-through. Every overlay element sits on its **own plate** (HUD material: opaque or vibrancy) with **text ≥ 13 pt at ≥ 4.5:1**, in **light and dark** variants, **docked to the screen edge or corner of the zone being touched**, and clipped to the screen. Worst-case test frame: a dark document under a light overlay, and a light document under a dark one. *(Draft, rewritten. 7/7 critics: D failed first. No plate, about 1.5–3:1, sitting on the text column, running off the window.)*

B7. **The menu glyph has its own silhouette.** A monochrome template image, readable at 16 pt in light and dark bars. **It isn't a rounded rectangle with a fill bar** (it would read as a second battery), and it isn't a stock right-sidebar symbol. Draw it next to the battery and Wi-Fi icons to prove it. *(Draft, sharpened. 7/7 critics, the failure every direction shared.)*

B8. **The dropdown is a real menu.** It has native menu weight and the system highlight. No hero cards, icon wells, power buttons or large titles inside a menu extra. *(New. 13, 23, 26 and 6.)*

B9. **Each status is said once, next to the thing it describes.** Live feedback sits on the mirror, at the touch point. Nothing is restated in a caption, chip or footer. *(New. Duplicates in 12, 13, 26, 1; feedback 40–250px from the touch in 6, 13, 23, 26.)*

B10. **Conflicts are named with their fix.** A tap + double-tap (or similar) conflict names the zone, states the actual misfire ("each double-tap fires Play/Pause first") and offers concrete fixes inline. *(New. KEEP from 13; best thinking in 12; good in 23.)*

## Kill list (goes in LOCKED)

- Tracked micro-caps eyebrow labels: the most common machine-made tell.
- A grey rounded rectangle with a soft drop shadow for the trackpad, or brushed-metal pinstripe skeuomorphism.
- N equal cards or panels, one per zone, with no hierarchy (23F's 3×3 grid).
- Gradient blobs, glass stacked on glass, neon glow, glow halos on the touch dot.
- Emoji, Unicode arrows or stock system symbols as the only gesture vocabulary.
- One corner radius everywhere; also nested radius on radius on radius.
- Fake usage stats, testimonials or percentages.
- Two-clause "oracular" copy or slogans in setup ("Precision you can read: every zone has a real size.").
- Any third-party product name, logo or look-alike.
- **Middot-chained metadata strings** ("Right edge · 1 finger · recognized · Default profile"). *(6 of 7.)*
- **Dimension lines, rulers and mm callouts as decoration.**
- **A space before %, or monospace numerals inside a proportional UI.** Pick one numeric style. *(6 of 7.)*
- **More than two typefaces.**
- **Rotated labels.**
- **A hero numeral** (a giant "64%") as decoration.
- **A launcher or share-sheet grid** of round buttons for actions.
- **Sports lower-third / sticker type.**
- **Filler or roadmap copy** in controls ("More actions arrive with updates").
- **Dashed outlines meaning several different things.** Dashed means pass-through, and only that.

## Keeps (carry into every direction)

- **The pad diagram is the editing surface, and each mapping sits where its zone is** (perimeter layout, labels in place). Named independently by 6, 1, 23 (×2), 26 (×2) and 23F: 7 of 14 critiques. The strongest finding of the round.
- **A rejection with a measured reason**, the number against the threshold. From 6 (B–F) and 12, independently.
- **The conflict banner** that names the misfire and offers two fixes. From 13 (B–F), with support from 12 and 23.
- **The touch point at its real position inside a zone that lights up.** From 13 and 23F.
- **The onboarding live mirror, with the real system HUD responding beside it** (input and result side by side). From 1 (B–F).

## Direction-agnostic prompts (D1): failed identically everywhere

1. **Test overlay sheet.** Overlay states over live work. 7/7 failed the same way (no plate, on the text, low contrast).
2. **Menu glyph sheet.** 7/7 drew a battery look-alike.
