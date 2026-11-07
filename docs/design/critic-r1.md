# Critic round 1: Edgy

Blind `design-critic` agents on Opus, read-only. Each got one direction's PNGs and a one-line context ("a seated laptop user… hands on the pad, eyes on the screen; ignore the wallpaper"). They did not get the prompts, seeds, sibling renders or Gabriel's lines. They ran after Gabriel's gut lines were logged (sprint-log, 2026-11-05 22:18).

**Coverage defect (logged as a skill learning).** The agent definition said "One image only", so 6 of 7 critics read screen A (the light editor) and skipped B–F. 12-NEJH read all six. The definition was fixed on 2026-11-05. A second pass covers B–F per direction (§ Pass 2 below). In pass 1, scores for A-only critics are **editor-only** scores.

## Pass 1

### 26-OIID: #26 Ambient glass (A only), 5/10
- **AESTHETIC:** a warm, translucent macOS window: peach-tinted glass, an oversized display heading and soft pill controls everywhere.
- **STUDIO:**
  - Draw the pad as an exact, quiet model, and put the action labels inside tinted bands.
  - Shrink the 72pt "Right edge" to a 20pt pane title.
  - Write the mapping as one grammar sentence built from inline pop-up menus.
  - Show touch feedback as a fingertip ring on the pad (green for recognized, grey with a strike for rejected).
- **AI TELLS:**
  - Middot-chained metadata on every string.
  - A 72pt hero heading in a prefs pane.
  - Pills everywhere, with no hierarchy between control kinds.
  - A "Free on this edge" chip cloud.
  - A three-swatch legend, needed because the diagram can't explain itself.
  - Three identical toggle rows plus "HUD Native" with no control.
  - A lone teal accent in an all-peach system that reads as the default selection colour.
  - Placeholder-looking dashed bottom corners.
  - About 250px of dead space.
- **LEGIBILITY:**
  - Secondary text is about 3:1 or lower on the peach gradient and gets worse as the glass picks up the wallpaper.
  - The recognition signal is a 10px dot with a caption 40px below the pad.
  - The Brightness strip is almost invisible.
- **KEY INTERACTION:**
  - The selected zone is drawn as a teal slider with a thumb, so "this is the zone" gets confused with "this is the value".
  - The mapping is split across 4 places.
  - It borrows from the system Trackpad pane plus a trigger→action tool.
  - No rejected state is shown.
- **GAPS:**
  1. Put the fingertip ring on the pad and delete the caption.
  2. Draw the selected zone as a tinted band with its label, and move the thumb into Sensitivity.
  3. Collapse the heading, subtitle and chips into one editable row, with secondary text at 4.5:1 or better on a more opaque surface.
- **KEEP:** action labels placed on the pad edges they map to.

### 6-MG2X: #6 Engineering drawing (A only), 6/10
- **AESTHETIC:** an engineering-drawing macOS: a dimensioned trackpad plan, hatched edge strips, serif section heads and monospaced figures on warm paper.
- **STUDIO:**
  - Draw the pad at true scale with one dimension line, on the selected edge only.
  - Drop the 160 mm and 100 mm rulers and the 12/8 callouts.
  - Hatch the selected edge only.
  - Set each gesture label on its own edge.
  - Move Advanced tuning into an inline inspector section instead of a heavy black-bordered table.
- **AI TELLS:**
  - Dimension lines are blueprint cosplay and give the user nothing to act on; the 12/8 arrows collide.
  - Every strip is hatched.
  - Three typefaces fight (serif, SF and mono), with a stray space in "100 %".
  - Dashed "Add a gesture" chips.
  - "resting at 0.52 · dwell 120 ms passed" is telemetry on show.
  - The black-bordered tuning table is the darkest thing on screen.
  - The corner treatments don't match each other.
  - A floating arrow in "Slide → Volume".
  - About 180px of dead space in the right panel.
- **LEGIBILITY:**
  - Main text is fine; light grey secondary text is about 3:1.
  - The recognized touch is a 6px dot plus a status line far from the hand position.
  - The crosshair ring is thin, teal on teal hatching.
- **KEY INTERACTION:**
  - Click an edge, then configure it in an inspector (the familiar design-tool inspector pattern). Solid.
  - The drawing as the editing surface is the most product-specific idea here.
  - No segment boundaries are drawn, and no rejected touch is shown.
- **GAPS:**
  1. Put labels on their edges, with segment dividers when the edge is split.
  2. Draw recognized and rejected touches on the diagram, and drop the coordinate readout.
  3. Remove the dimension lines and the black table, collapse tuning, and use one display face.
- **KEEP:** the pad diagram as the editing surface.

### 1-CTRL: #1 Native (control) (A only), 5/10
- **AESTHETIC:** a close copy of System Settings: a sidebar of coloured squircles, grouped inset lists, and a flat grey trackpad drawing in the centre.
- **STUDIO:**
  - Give the pad true proportion and a little material (faint gradient and inner highlight).
  - Put labels outside the pad on leader lines, never as 9pt text rotated inside strips.
  - Anchor the action popover to the clicked zone.
  - Give live touch its own colour, separate from the selection colour.
- **AI TELLS:**
  - Invented apps with lightly altered system browser and video-call glyphs.
  - An unexplained "Live" dot.
  - Rotated labels in 24px strips.
  - 9pt corner text.
  - Empty dashed zones with no "+".
  - A dash-joined status sentence with a blue check.
  - "1 (whole edge)" in parentheses.
  - A "Use this profile" toggle on Default, which makes no sense.
  - About 220px of dead space on each side.
  - A floating "Add Gesture…".
- **LEGIBILITY:**
  - Edge labels are 8–9pt at about 2:1 contrast.
  - The touch dot is blue on the blue selected strip, so it disappears.
- **KEY INTERACTION:** a picture on top and a form below; the diagram only selects. Selection and touch share one blue. No rejected touch is shown. It works, but it's a template.
- **GAPS:**
  1. A separate visual system for selection, recognized touch and rejected touch (with its reason).
  2. Labels on leader lines at 11pt or larger and 4.5:1, plus a "+ Assign" hint on empty zones.
  3. A picker anchored to the zone, with the form below shrunk to sensitivity only.
- **KEEP:** the perimeter-zone model (4 strips and 4 corners around a dead centre).

### 23-67PL: #23 Edge-only (A only), 6/10
- **AESTHETIC:** a warm-paper macOS utility with a spatial layout: a schematic pad in the centre, and each zone's settings on the matching side of the window.
- **STUDIO:**
  - Use the true aspect ratio, with bands sized to the real detection widths.
  - Draw hairline leader lines from each band to its label, and left-align every column.
  - Show the live touch as a fading trail, and a rejected touch as a hollow grey ring with an inline reason.
- **AI TELLS:**
  - The right column is mirrored right-to-left.
  - Black corner squares are the heaviest marks on screen and mark an inactive state.
  - Monospace "1.0×".
  - Copy is inconsistent ("Microphone Mute" vs "Mute"; "not mapped" vs "Not mapped.").
  - A stray teal stroke on the window edge.
  - A glow halo on the touch dot.
  - Dashed boxes overlap the edge bands.
  - The centre is empty.
- **LEGIBILITY:**
  - Secondary grey is about 3:1.
  - The status line sits about 250px from its dot.
  - Black corners read as active when they only mean mapped.
- **KEY INTERACTION:**
  - The perimeter layout borrows from the hot-corners sheet: sensible and native.
  - Nothing connects a zone to its settings.
  - "Add a gesture" is a text link.
  - No rejected state is shown.
- **GAPS:**
  1. A rejected-touch state on the diagram.
  2. Recoloured zone states (unmapped dashed / mapped tint / live accent), and secondary text at 4.5:1.
  3. Leader lines, a left-aligned right column, and unified copy.
- **KEEP:** the perimeter layout, settings on the matching side of the window ("a map of the user's hand").

### 23F-MGWV: #23 + #22 telestrator (A only, so the fusion screens C/D are unjudged), 5/10
- **AESTHETIC:** a technical-drawing control panel: a plan view of the pad, leader lines out to a 3×3 grid of panels, warm paper greys and one safety-yellow highlight.
- **STUDIO:**
  - Make the zones clickable and replace the 8 panels with one inspector.
  - Show a single hairline only to the selected zone.
  - Use true scale with mm callouts in tabular monospace.
- **AI TELLS:**
  - Decorative diagonal leader lines.
  - 8 equal panels, the bottom ones mostly empty.
  - Corner cells that disagree with each other.
  - An unlabeled Whole/2/3/4 control, repeated on both sides.
  - A web-link "Add a gesture".
  - "58 %" spacing and mono "1.0×".
  - Confusing pass-through copy.
  - Inconsistent zone glyphs.
  - A crammed title bar whose status strings look like buttons.
- **LEGIBILITY:**
  - Only the yellow strip and its dot read at a glance.
  - Everything else is 10–11pt grey at about 3.5:1.
  - The left Brightness strip is grey on grey.
- **KEY INTERACTION:**
  - The touch (yellow strip, ringed dot at the true position, "Finger resting · 58 %" in the zone panel) is drawn well and is the most native moment.
  - Mapping is weaker: the pad only displays, so it reads as a forms tool with a drawing on top.
  - No rejected touch is shown.
- **GAPS:**
  1. Clickable zones with one inspector.
  2. Idle, rejected and unmapped states on the pad, drawn with the same weight as the active state.
  3. One row pattern (glyph → gesture → action), with the segment control labelled or removed.
- **KEEP:** the single safety-yellow active strip with a ringed dot at the real touch position.

### 12-NEJH: #12 Machined object (A–F, all six read), 6/10
- **AESTHETIC:** a system-settings-style utility built around a brushed-aluminium skeuomorphic trackpad, with one teal accent.
- **STUDIO:**
  - A flat, precise line drawing at real proportions: hairlines for unmapped zones, solid for mapped, teal for selected. Drop the pinstripe and the legend.
  - A native form with standard pop-up buttons and horizontal labels.
  - One status line.
  - Fading finger trails of about 600 ms in test mode.
  - A glyph that can't be mistaken for anything else, e.g. a pad outline with only the right edge thickened.
- **AI TELLS:**
  - The pinstripe texture appears everywhere.
  - Middot separators everywhere.
  - Status is repeated in A and D.
  - Mono numbers mixed with inconsistent % spacing.
  - Rotated labels.
  - A legend for an invented visual language.
  - Filler picker footer copy.
  - B continuity errors: a clipped "E", an extra Brightness segment, and text running into its arrow.
  - Custom ▼ triangles.
- **LEGIBILITY:**
  - Settings and onboarding hold up, and the 64 % readout in C reads at a glance.
  - Dark rails in B nearly vanish.
  - D's grey-on-brown text is too small.
  - **Worst case: the menu glyph** looks like the battery icon next to it, or a generic sidebar symbol, in both bars.
  - The small app icon loses its teal edge.
- **KEY INTERACTION:**
  - The inspector pattern is competent but borrowed.
  - **The B picker's "needs Slide / on Double-tap" hints and the "Tap fires first" conflict warning are the best product-specific thinking.**
  - D's recognized touch (solid teal) vs rejected touch (hatched ellipse with ✕) is product-specific, but it is buried under duplicate chips.
- **GAPS:**
  1. One place for touch status, with D's footer at 4.5:1 or better.
  2. A glyph and small icon that are distinct from the battery icon at 16–32px.
  3. Clean up B: native pop-ups and horizontal labels.
- **KEEP:** the recognized vs rejected distinction (solid vs hatched ✕) with a plain-language reason ("contact wider than 18 mm").

### 13-VZC3: #13 Keycap legends (A only), 6/10
- **AESTHETIC:** engineering-drawing utilitarianism: a dimensioned spec sheet with mm rulers, monospace annotations and condensed-sans callouts on warm paper-grey.
- **STUDIO:**
  - One hairline weight, with legends on leader lines tied to their zones.
  - Mono for measurements only.
  - Drop the rulers.
  - The bottom row becomes an inspector for the selected zone.
- **AI TELLS:**
  - Every label is in mono, so type style marks a category rather than hierarchy.
  - A duplicate arrow strip along the bottom.
  - Edge legends floating about 60px from their zones.
  - Wireframe dashed "+ gesture" links.
  - Default "sensitivity 1.0" repeated as filler.
  - A centre caption in the most valuable spot.
  - Two ruler rhythms that measure nothing.
  - A mixed global, profile and gesture settings row.
  - An ambiguous "Profile on".
- **LEGIBILITY:**
  - Mono annotations are 9-10pt at about 3:1; ruler numerals are about 8pt.
  - Action names (12pt bold condensed) hold up.
  - Live feedback sits outside the pad, at the bottom.
- **KEY INTERACTION:**
  - Recognition is drawn well (teal zone, ringed point at the true position, green "resting" under Volume): a live mirror, not a template.
  - Mapping is list editing laid over a picture.
  - No rejected touch is shown.
- **GAPS:**
  1. Legends anchored to their zones, with the duplicate strip deleted.
  2. The live readout on the canvas next to the touch point, at 13pt or larger and 4.5:1, plus an explicit rejected ring with its reason.
  3. A per-zone inspector, with app-wide prefs in their own pane.
- **KEEP:** the touch point at its real position inside a zone that lights up as the finger lands.

## Pass 2: screens B–F (fixed definition, Opus)

### 6-MG2X B-F, 7/10
- **AESTHETIC:** engineering-drawing minimalism: real dimension lines, hatched zones, editorial serif and mono readouts on cream and slate.
- **STUDIO:**
  - The pad at true 1:1 scale with outside leader-line callouts, so the inside stays empty.
  - The overlay on real HUD material (dark vibrancy, 1.5pt strokes) over the frontmost window, with touches drawn as measured contact ellipses: a teal trail when recognized, crossed out and fading when rejected.
  - A real system menu, with the glyph cut down to a corner bracket and one tick.
  - Serif on window titles only.
- **AI TELLS:**
  - The C headline "Precision you can read: every zone has a real size." is a slogan in setup.
  - Apologetic picker footer filler.
  - Inconsistent unit padding.
  - Three typefaces, plus a ruled serif tuning table.
  - Design-tool resize handles on a corner that nothing supports.
  - The pad is filled with negative-state labels.
  - A "Pause for 1 hour" row highlighted for no reason, in custom navy.
  - A double bezel on the icon, with an empty quadrant.
  - Awkward breaks in narrow C columns.
- **LEGIBILITY:**
  - Settings and onboarding hold up.
  - **The D overlay fails first:** thin grey strokes and a peach fill at low contrast, with 13px grey chips. It is drawn *beside* the document, not over it, so the worst case was never designed.
  - The glyph's arrow becomes a dash at 16px and reads as a flag or "F", though it passes in both bars.
- **KEY INTERACTION:**
  - The picker is a search-launcher popover: competent.
  - Dimmed rows that say why ("Brightness - needs a slide") are good.
  - Recognized vs rejected is native to the product: a teal callout with a 0.64 flag vs a dashed ellipse with ✕ and "Ignored: palm - Contact 21 mm, limit 18 mm".
  - The two get equal visual weight, so there is no hierarchy.
- **GAPS:**
  1. Rebuild the overlay over live content with an opaque or vibrant backing, strokes of 1.5pt or more and 13pt+ labels at 4.5:1.
  2. Redraw the glyph for 16px (bracket and tick), plus the 32px icon.
  3. Take the labels out of the pad, put tuning behind a disclosure, and delete the footer copy.
- **KEEP:** the rejection with a measured reason (the number against the threshold).

### 13-VZC3 B-F, 5/10
- **AESTHETIC:** an instrument-panel macOS utility: a measured blueprint pad with keycap-style condensed legends, warm paper and charcoal, and one teal accent.
- **STUDIO:**
  - True scale with no rulers.
  - Two typefaces.
  - A native popover pointing at the zone.
  - A native menu.
  - Test mode as a frosted HUD hugging the screen edge, never over live text, with the event log pinned to a corner.
- **AI TELLS:**
  - Ruler cosplay.
  - Three type voices inside the pad.
  - The same state shown three times (breadcrumb, chip row and tag).
  - Roadmap copy in the picker footer.
  - Unicode glyphs used as icons.
  - A footer settings dump.
  - C: a "64 %" dashboard stat and a stock four-step stepper.
  - D: the overlay runs off the window.
  - E: a fake menu with a header card and a black selection bar.
  - F: the glyph equals a stock right-sidebar symbol, and the icon stacks four ideas.
- **LEGIBILITY:**
  - **D fails first:** the banner, chips, log and pill sit on body text with no scrim, and the corner labels are 9–10px.
  - The glyph holds up in both bars but reads as a sidebar icon.
- **KEY INTERACTION:**
  - The picker is a borrowed command palette floating mid-pad.
  - **The conflict banner** ("Each double-tap fires Play/Pause first", Move to hold / Keep both) is native to the product and the best thing here.
  - The recognized vs rejected language is right (teal edge and pill vs hatched dashed palm with "✕ Ignored: palm"), but it sits on text.
- **GAPS:**
  1. Re-site the overlay as an edge-hugging HUD with a scrim, clipped to the screen.
  2. Two typefaces, no rulers or triple breadcrumb, and an anchored picker.
  3. A new glyph (a thickened edge stroke plus a touch dot) and a native menu.
- **KEEP:** the conflict banner (names the zone, states the misfire, offers two fixes).

### 26-OIID B-F, 5/10
- **AESTHETIC:** warm "desert dusk" consumer-Mac: terracotta and peach gradients, a heavy rounded grotesk, oversized numerals and one teal signal colour; "boutique utility between a launcher and a wellness app".
- **STUDIO:**
  - The pad diagram becomes the whole app: a full-bleed, to-scale pad with an inline action list in place.
  - E becomes a real native menu, with terracotta only on the zone highlight and the status dot.
  - The overlay is a translucent HUD in light and dark variants, with honest-sized contact ellipses that fade and hollow red-orange rejected touches.
  - The 64% numeral shrinks to a caption.
- **AI TELLS:**
  - E: icon wells, three nested radius levels, and a huge black power button with a 40pt "Default" in a menu extra.
  - C: a stock black-circle arrow CTA.
  - B: the picker is a 4×2 share-sheet grid of round buttons.
  - Filler picker footer.
  - The "Choose action" pill outweighs the bound actions.
  - Segments "2" vs "Segment 1 of 2" confusion.
  - A "HUD Native" token with no control.
  - The 64% hero numeral in C and D is decoration.
  - An icon seam, and a dune curve copied from the placeholder wallpaper.
- **LEGIBILITY:**
  - **The glyph fails first:** a rounded rect with a fill bar, read as a second battery.
  - B labels are about 12pt mid-grey on brown, about 3:1.
  - D captions are about 11pt grey on peach, below 3:1.
  - D is an opaque peach slab with no dark variant, so it would be the brightest object over a dark editor.
- **KEY INTERACTION:**
  - Clicking a zone on the pad with the label in place is right.
  - The popover is a generic launcher grid, covers the footer and has no arrow.
  - Recognition (teal bar with thumb) works.
  - Rejection is a sticker, not a touch: the palm is drawn fingertip-sized, so you can't see why it was rejected.
- **GAPS:**
  1. A glyph with no enclosing rounded rect, and E as a native-weight menu.
  2. A list picker anchored to the field, a quiet empty slot, and fixed segments.
  3. Rejected touches as true-scale contact shapes in a distinct hue, a dark overlay variant, and captions at 4.5:1.
- **KEEP:** the to-scale pad diagram with edge strips, corner squares, dashed pass-through outlines and a live teal thumb.

### 1-CTRL B-F, 6/10
- **AESTHETIC:** a faithful imitation of the current System Settings; the trackpad diagram is the only original element.
- **STUDIO:**
  - The diagram becomes the editor, with a popover whose arrow points at the zone.
  - A glyph on a 16pt grid, tested next to the battery.
  - A real HUD-material overlay: a red ring flashes about 400ms on rejection, and the log is one line that fades after 2s.
- **AI TELLS:**
  - Middot strings everywhere.
  - "64 %".
  - Dashes used for everything.
  - Explanatory filler copy.
  - The "23 mm contact, limit 18 mm" debug-style reason.
  - A default utility-icon recipe.
  - A template four-step stepper.
  - The right edge is mapped inconsistently between B and C.
- **LEGIBILITY:**
  - **The glyph fails first** (battery or right-sidebar look-alike).
  - D's blue 11pt text and grey on brown translucent are about 3:1 and change with the wallpaper.
  - Rotated 9pt rail labels.
  - The orange palm ✕ and blue check survive, because they differ in shape and colour.
- **KEY INTERACTION:**
  - The picker is drawn broken: it covers its trigger and runs off the window, and the chip vs gesture being edited is ambiguous.
  - D is borrowed from the system volume HUD, but recognized vs rejected reads clearly.
  - **C (a live mirror with the real system HUD responding) is the strongest moment.**
- **GAPS:**
  1. An outline glyph with one emphasised edge.
  2. A picker anchored to the zone chip that never covers its trigger, with the gesture label shown.
  3. A dark HUD overlay at 4.5:1 or better: cut the stats and mm values, and fade the log.
- **KEEP:** the C live mirror, with touch input and the system result side by side.

### 23-67PL B-F, 6/10
- **AESTHETIC:** restrained macOS-utility minimalism close to stock, with one teal accent for "touch detected".
- **STUDIO:**
  - The diagram becomes the control surface, with zones that light when touched on the real pad and the selected zone's gestures in the empty centre.
  - The overlay on a small vibrancy plate with a 1pt hairline, like the system volume HUD.
  - A glyph outline with a gap in its right edge.
- **AI TELLS:**
  - The picker footer is a design note.
  - "64 %" ×3.
  - Outlined-glyph overlay text instead of a plate.
  - An unexplained teal hairline and glow in C.
  - Mono slider readouts.
  - Mute vs Microphone Mute duplicates.
  - A fake cream menu with a duplicate green dot.
  - A bare "Advanced" label.
- **LEGIBILITY:**
  - **The overlay fails first:** about 11px white on pale peach, about 1.5:1.
  - The glyph has the battery silhouette.
  - B is fine.
- **KEY INTERACTION:**
  - The palette grid fights its arrow-key hints, and a keyboard-first palette doesn't fit a hand on the trackpad.
  - Greying "slide only" actions and the amber "Tap and Double-tap share this edge" warning are good.
  - D tells recognized from rejected by colour only, with no plate.
  - It works in C on a calm canvas and breaks over live work.
- **GAPS:**
  1. Plates under every overlay readout at 13pt or more; tell recognized from rejected by shape and icon too.
  2. A glyph tested next to the battery.
  3. An interactive centre diagram that carries the editing.
- **KEEP:** the perimeter layout (each mapping sits where its zone is).

### 23F-MGWV B-F (fusion lives in C/D), 6/10
- **AESTHETIC:** a restrained technical-drawing utility with one loud yellow broadcast-graphics layer for live feedback.
- **STUDIO:**
  - The same to-scale pad drawing in B, C and D.
  - The overlay as roughly 70% vibrancy, docked to the screen edge nearest the touched zone, in SF Semibold rather than slanted sticker type.
  - Yellow means only "Edgy is acting on this touch".
  - A glyph with its own silhouette.
- **AI TELLS:**
  - **D's slanted black-and-yellow sticker labels look like a sports lower-third pasted on a Mac.**
  - A flat grey slab with no material.
  - Callouts run off the window.
  - Camera-focus brackets and a stray pause glyph.
  - An orphaned "3." in C.
  - A wobbly doodled trail.
  - Inconsistent zone icons and corner layouts.
  - Status and control are ambiguous in the title bar.
  - Filler footer.
  - The mono shortcut is inconsistent.
- **LEGIBILITY:**
  - The sticker labels read (28pt yellow on black), but the 50% grey slab sits on the text column and disappears on dark documents.
  - B's 9–10pt rotated labels.
  - **The glyph is a battery look-alike.**
- **KEY INTERACTION:**
  - The picker is a borrowed search list (the right borrow), but it hangs below the window and covers a row.
  - D's idea fits the product (trail and readout vs hatched contact with the measured reason "over 18 mm is treated as a palm").
  - The execution borrows TV graphics, and REJECTED is as loud as RECOGNIZED.
- **GAPS:**
  1. A vibrancy panel docked to the active edge, kept in bounds, in SF Semibold.
  2. An open pad-outline glyph.
  3. Unified zone cards, with the popover kept inside the window.
- **KEEP:** the to-scale pad drawing with leader lines from each zone to its settings.

## C2: Gut vs critic

Scores: pass 1 is screen A (editor) only; pass 2 is screens B–F. 12 had one critic on A–F.

| Label | Direction | Critic A / B–F | Gabriel's gut (short) | Agreement |
|---|---|---|---|---|
| 26-OIID | #26 Ambient glass | 5 / 5 | favourite: "really cool, modern… big headers… buttons very clear" | **Disagree.** His praised parts are the critic's tells (72pt hero heading, pills everywhere, the power button, the 64% hero numeral). Different layers: he's judging mood and warmth (skin), the critic is judging structure. |
| 6-MG2X | #6 Engineering drawing | 6 / **7** | second: "blueprint… clean… why 100 mm?" | **Agree.** Both like it, and both independently flag the dimension lines as decoration. |
| 1-CTRL | #1 Native (control) | 5 / 6 | "very basic… outdated" | Agree: "a faithful System Settings imitation". |
| 23-67PL | #23 Edge-only | 6 / 6 | "safe… looks very AI-generated" | Agree: "close to stock". |
| 13-VZC3 | #13 Keycap legends | 6 / 5 | "confusing… a measurement tool… fonts don't help" | Agree: three type voices and ruler cosplay. |
| 12-NEJH | #12 Machined object | 6 (A–F) | "safe… Windows-like" | **Split.** The critic calls the skin (pinstripe skeuomorph) a tell, agreeing with him, but credits 12 with the best product-specific *structure* (picker constraint hints, conflict warning, rejection with a reason). |
| 23F-MGWV | #23 + #22 telestrator | 5 / 6 | "safe… more interactive with the colors" | Partial. The broadcast idea in D is the critic's top tell (lower-third stickers). |

**C3: the scores are flat (5–7).** That's a bones finding: every direction shares the same structural failures. The signal is in GAPS and KEEPs, not the numbers.
