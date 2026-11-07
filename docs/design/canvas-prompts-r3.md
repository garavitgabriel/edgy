# Canvas prompts: round 3 (2026-11-06)

Round 2 was decided on taste. Gabriel picked **26-1TVB** (glass) as the base. 6-7F2S and 26x6-LHPU were killed ("outdated because of the sidebar"). For round 3 he asked for the same bones, style and structure, plus riskier skins: "this is a really polished product… you can be risky." He picked all four risky options offered, and a glass popover for the menu-bar dropdown.

Every render goes on a NEW canvas. Changes from round 2:
- **B8 rewritten.** The dropdown is now a glass popover, not a plain native menu. Gabriel: "very basic and very bland"; his day-one reference was a glass popover.
- **Critic r2 fixes folded into the bones.** That critic scored 26-1TVB 5/10 and FAILed B4 and B9.
  - B4: one hue only. Brand = live, or the brand stays neutral (r2 had a rust brand plus a blue live).
  - B9: no on-pad caption restating mappings, no "Recognized" chip, and the volume shown once.
  - B2: labels sit inside their zone.
  - B5: the popover leaves neighbouring zones visible.
- **Shared structure** (from 26-1TVB): no sidebar. The profile switcher sits top centre as tabs with app icons, and Enabled is top right. The large mirror is on the left. The inspector is on the right: zone name, split control, gesture rows. The bottom row holds Haptics, Launch at login, HUD and Advanced…
- **The menu glyph in every artboard is candidate 04 "Bite"**: the pad outline with a round notch taken from the bottom edge. Artboard F builds the app icon from it.
- **D is introduced by E.** E's popover shows Test Mode being switched on, so the overlay has a clear origin. Gabriel: "I don't get where those things will come from."

| Label | Direction | Seed |
|---|---|---|
| 26R-1TVB | Control: 26-1TVB revised (same seed, fixes only) | 1tVbfh9OK16JMqx3wSNSsMh00WABZ2fmW8W77evCGHZWCvp5 |
| OBJ-J9IQ | Risky: the pad as an object | j9IqvAknQJZmVMehAPDsk0zJjxG2yRXzN7inoEnY1MVGzca2 |
| FBG-DTQF | Risky: full-bleed glass | DtQFLLsLDS53mo1LBOnrUo444sTEac7ZAbr8s4EGr4PSvtgb |
| NITE-HRHA | Risky: night instrument | HRHAIO96ivlElnNLyIYzNTc9zjZgpZRGDX2I4KSLIZ3XUeY4 |
| EDIT-JUZW | Risky: warm editorial | juzwH4Cd9kRFcbJ7RtPGU6cTb0LIjqlW14AG73Lzh18P3oiZ |
| GLY-IM2G | Sheet: glyph 01 vs 04 refined + "Exact" icon built on Bite | Im2GYwgA7CRk739eaA3hRoyPkdrMUV12trHJzbpQyZ12N9WI |

---

## CONTEXT (identical in every prompt)

Edgy is a free, open-source menu-bar app for macOS 14+. It turns every edge and corner of a laptop trackpad into a control:
- Slide the right edge for volume.
- Slide the left edge for brightness.
- Swipe the bottom edge for previous/next track.
- Double-tap the bottom edge for play/pause.
- Double-tap the top-right corner to mute.
- Double-tap the top-left corner to mute the microphone.

That is only the default preset. Any zone can do any action, and each app can have its own profile (or disable Edgy entirely, e.g. for games).

The user is seated at a laptop, hands on the trackpad, eyes on the screen. They never look at the trackpad, so every surface must map screen to pad: same orientation, true proportions (the pad is a landscape rectangle roughly 160 × 100 mm). The emotion to sell is trust: nothing fires by accident. Feel is the product, and it should look like a really polished product.

Data the UI must express (frozen; use these exact terms and values):
- **Zones:** 4 edges (left, right, top, bottom), each an 8 mm strip. Each edge can be split into equal segments (e.g. the right edge in 2: the upper half and lower half do different things). 4 corners, each a 12 mm square. A mapped corner wins over its edges; an unmapped corner passes touches through to its edge.
- **Gestures:** slide (continuous, position 0–1), swipe up/down/left/right, tap, double-tap, long-press. 1 or 2 fingers (global).
- **Binding:** zone + gesture → action (+ parameters).
- **Actions (8):** Volume (continuous, sensitivity), Brightness (continuous), Mute, Microphone Mute, Play/Pause, Next Track, Previous Track, Run Shortcut (name parameter).
- **Profiles:** Default, plus per-app profiles that replace the default. Any profile can be disabled.
- **Settings:** enabled, show menu-bar icon, HUD (native / none), haptics on/off, launch at login.
- **Advanced tuning:** edge width 8 mm, corner size 12 mm, dwell 120 ms, palm size 18 mm, typing suppression 500 ms, double-tap window 300 ms, long-press 500 ms, fingers 1.
- **Reasons a touch is ignored:** started outside a zone, palm, too many contacts, typing, off-axis motion, too fast, handed off to a system gesture, zone disabled.

**The Edgy menu glyph (use it in every menu bar):** a small landscape rounded-rectangle outline, about 16 × 11 pt, monochrome, with a round notch bitten out of the middle of its bottom edge. It is not filled and has no inner bar.

**Shared window structure (keep it; the skin is yours):**
- No sidebar.
- A profile switcher at top centre: Default plus app tabs with small invented app icons, and a "+".
- An Enabled switch at top right.
- The large live pad mirror on the left.
- An inspector on the right: the selected zone's name as the one confident line, a "Split into 1 2 3" control, and one row per gesture with its action.
- A bottom row: Haptics, Launch at login, HUD, Advanced…

Background for every artboard (except F):
- Draw your own desktop wallpaper as a soft abstract of layered warm dunes (oranges, terracotta, a little sky blue in one corner). The NITE direction may use the same dunes at dusk.
- Draw the OS menu bar across the top: a translucent strip with, on the right, the Edgy glyph, Wi-Fi, battery and a clock reading "Thu 5 Nov 9:41".
- No photos (none can be fetched); paint it. Use real, plausible text everywhere; no lorem ipsum. Invented app names only, never a real product name.

## DELIVERABLE (identical in every direction prompt)

Six artboards, each a standalone screen at the exact size given. No annotations, no labels outside the UI, no design-system callouts, no explanation text.

- **A. Editor, light mode, 1280 × 800.** The settings window (about 960 × 640) on the desktop. The live trackpad mirror shows the default preset. One finger is resting on the right edge, and the right-edge zone lights where it lands. The profile switcher shows Default plus two apps (a browser and a video-call app). The right edge is selected and its bindings are visible.
- **B. Editor, dark mode, 1280 × 800.** The same window in dark mode.
  - The right edge is split into 2 segments (upper: Volume slide; lower: Brightness slide).
  - The top-left corner is mapped (Microphone Mute, double-tap); the bottom-left corner is unmapped and passes through.
  - The user has clicked the bottom edge on the mirror to choose an action for its tap gesture. The action picker is open, anchored to that zone, listing the 8 actions, and is compact enough that the other zones stay visible.
  - The bottom edge also has double-tap → Play/Pause, so a conflict warning shows (the first tap always fires before the double-tap).
- **C. Onboarding, "Try the right edge", 1280 × 800.** A smaller onboarding window (about 640 × 520). Step 2 of 4: 1 Accessibility permission ✓, 2 Try it, 3 Pick a preset, 4 Launch at login. The user is mid-slide on the right edge and volume is at 64%. The mirror shows the recognized slide at the touch, and the system's own volume indicator responds beside the window at the same time.
- **D. Test-mode overlay, 1512 × 982.** The full screen of a 14-inch laptop.
  - Behind: live work (a text editor with a real paragraph of prose, the text cursor mid-paragraph).
  - The overlay sits on top, click-through, not taking focus. It shows two current touches, one recognized gesture (right edge, slide, Volume 64%), and one rejected touch near the bottom-left of the pad (palm, contact 21 mm wide, limit 18 mm).
  - A small persistent "Test mode" marker near the Edgy glyph makes it clear the overlay comes from Test Mode.
- **E. Menu-bar popover, 1280 × 800.** The Edgy glyph in the menu bar, with its popover open beneath it and anchored to it. It contains:
  - (1) A live mini mirror of the pad: the zones of the active profile, and the last touch shown where it landed.
  - (2) App-profile chips (Default active, the browser, the video-call app).
  - (3) Two primary controls: Enabled, and Test Mode, with the pointer on Test Mode as the user switches it on.
  - (4) Then a plain list: Pause for 1 hour, Settings…, Open config file, Reload config, About Edgy, Quit Edgy.
- **F. Icons, 1280 × 800.** F overrides the wallpaper rule: use a plain neutral board. Show the app icon in this direction's skin, built from the Bite glyph shape, at large size (~512 px) and at 128 and 32 px. Add the menu glyph at real size (16 pt and 2× zoom) on a light and a dark menu bar, each beside Wi-Fi and battery.

One sample line of copy in the direction's voice, used as the onboarding headline on artboard C: one clause, no colon, no slogan.

## BONES (pasted into every LOCKED block)

**B1.** The mirror is the pad: to scale, at the real aspect ratio, in the same orientation as the trackpad. No dimension lines, rulers or mm callouts in the editor; the outline is the measurement.

**B2.** Five zone states read at a glance, by shape as well as colour:
- unmapped
- mapped
- mapped corner (wins)
- pass-through corner (falls to its edge; dashed, and dashed means only this)
- selected

Selection and live touch never share one colour or treatment. Each label sits INSIDE or directly on its own zone, horizontal; never floating in the middle of the pad.

**B3.** Recognized vs rejected:
- They differ by shape, e.g. a filled contact vs a hollow or struck true-scale contact ellipse, not by colour alone.
- A rejection names its reason in plain words, with the measured value against the limit ("Ignored: palm, 21 mm wide, limit 18 mm").
- Recognized is visually louder than rejected.

**B4.** ONE accent hue in the whole design. It means "live" (a recognized touch, the active zone, an on switch) and nothing else. Either the brand IS that hue, or the brand is neutral. No second hue anywhere, including warnings: warnings use type weight and an icon.

**B5.** You map on the pad:
- Clicking a zone on the mirror selects it.
- The action picker is a compact, searchable, grouped LIST in a popover anchored to that zone with an arrow. It never covers its trigger, never spills outside the window, and leaves the neighbouring zones and their labels visible.
- Labels are horizontal, never rotated.
- Actions that can't take the current gesture are dimmed with the reason ("needs a slide").
- No copy about future actions.

**B6.** The overlay never takes focus and never sits on the text being worked on. It is click-through. Every overlay element:
- sits on its own plate (opaque or blurred material), with text ≥ 13 pt at ≥ 4.5:1 contrast;
- is docked to the screen edge or corner of the zone being touched;
- is fully inside the screen (nothing clipped);
- is readable over both light and dark documents.

**B7.** The menu glyph is the Bite: a monochrome template image, readable at 16 pt in light and dark bars. It is never a rounded rectangle with a fill bar (that reads as a second battery).

**B8.** The menu-bar surface is a popover anchored to the glyph. Its top half is live: the mini mirror, profile chips, Enabled and Test Mode. Its bottom half is a plain native-weight list with the system highlight. No power button, no hero numeral, no large title, and no cards stacked on cards.

**B9.** Each status is said once, next to the thing it describes:
- Live feedback appears on the mirror, at the touch point.
- No caption on the pad restates the mappings. No "Recognized" chip floats away from the touch.
- Volume 64% is said in one place per screen (the system indicator counts as that place on C).

**B10.** Conflicts are named with their fix. The warning names the zone, states the actual misfire ("each double-tap fires Play/Pause first") and offers two concrete fixes inline, as one compact note, not a big alert card.

Kill list:
- tracked micro-caps eyebrow labels
- a grey rounded rectangle with a soft drop shadow as the trackpad, or brushed-metal pinstripe skeuomorphism
- N equal cards or panels, one per zone
- gradient blobs, neon glow, blurred glow halos on the touch dot
- emoji, Unicode arrows or stock system symbols as the only gesture vocabulary
- one corner radius everywhere, or radius nested on radius on radius
- fake stats or testimonials
- two-clause slogan copy
- any third-party product name or look-alike
- middot-chained metadata strings
- dimension lines, rulers, mm callouts as decoration
- a space before %, or monospace numerals inside a proportional UI
- more than two typefaces
- rotated labels
- a giant hero numeral as decoration
- a launcher grid of round buttons for actions
- sports lower-third or sticker type
- filler or roadmap copy
- generic coloured squares as app icons (draw small distinct invented app marks)
- a sidebar

Keeps (carry these):
- The pad diagram is the editing surface, and each mapping sits where its zone is.
- A rejection shows the measured reason.
- The conflict note names the misfire and offers two fixes.
- The touch point sits at its real position inside a zone that lights as the finger lands.
- Onboarding shows the live mirror and the system's own result side by side.
- The profile tabs at top centre, with app icons.

Structural reference: the image `r2/26-1TVB-A.png` in the design root shows the window structure to keep: tabs top centre, mirror left, inspector right, bottom settings row. Use it for layout ONLY. Do not copy its palette, type, material or radii (except the 26R control, which keeps its skin).

---

## 26R-1TVB — Control: 26-1TVB revised

LOCKED
My line: Edgy has no palette of its own; it borrows your desktop's.

Feeling: Warm, soft, friendly, tactile. A nice object you like seeing, not a tool you tolerate.

The rule:
- Surfaces are translucent material tinted by whatever is behind them, made legible by enough opacity behind every line of text.
- Hierarchy comes from one confident type line per window (≤ 32 pt in a window, ≤ 17 pt in the popover).
- A chunky round control appears only on onboarding Continue.

This is a REVISION of an existing render (`r2/26-1TVB-A..F.png`). Keep its skin: palette, type, materials and layout. Fix only these:
- (a) Choose one accent hue. Either the warm rust becomes the live hue and the blue goes, or the reverse.
- (b) Give the zone states distinct shapes, with labels inside their zones.
- (c) Remove the on-pad caption, the floating "Recognized" chip and the duplicated volume readouts.
- (d) Make the B picker compact so the other zones stay visible, and turn the conflict alert card into one compact note.
- (e) Replace the D overlay plates so none is clipped by the screen edge.
- (f) Make E the new popover (B8).
- (g) Use the Bite glyph everywhere.

Surfaces: as in the original.

Fails when: the glass costs legibility, or it turns into a consumer-app costume.

[BONES + Kill list + Keeps]

FREE
Seed: 1tVbfh9OK16JMqx3wSNSsMh00WABZ2fmW8W77evCGHZWCvp5. The skin is already derived from this seed; keep it.

---

## OBJ-J9IQ — Risky: the pad as an object

LOCKED
My line: The trackpad is a thing in your hands, so Edgy draws it as a thing.

Feeling: Tactile, crafted, a little playful. A beautifully lit object on a calm stage, like a product photo of a precious instrument, but drawn, not photographed.

The rule:
- The mirror is a physical slab seen straight on, lit softly from above-left: a real material (choose from the seed: frosted ceramic, satin glass, soft-touch polymer, or warm anodized, but NOT brushed metal pinstripes and NOT a grey slab with a drop shadow).
- The zones are inlaid into that material: grooves, raised strips, or a different finish where a zone is mapped.
- Touches press into the surface as soft dents or ripples (the recognized one deeper and lit by the accent; the rejected one a shallow hollow ring).
- Everything around the slab stays quiet and flat, so the object is the only rich thing on screen.

Surfaces:
- Editor: the slab is the hero, with the inspector in plain flat type.
- Onboarding: the slab, smaller, with a finger dent mid-slide.
- Overlay: small flat plates. The object never appears over work.
- Popover: a tiny version of the slab as the mini mirror.
- Icon: the slab as an object, with the Bite notch cut into its edge.

Fails when: it reads as kitsch skeuomorphism, or the material fights the labels for legibility.

This sounds bad, and that is why it is here.

[BONES + Kill list + Keeps]

FREE
Seed: j9IqvAknQJZmVMehAPDsk0zJjxG2yRXzN7inoEnY1MVGzca2

Derive from this seed, and do not reveal or explain it: exact palette values, material, type pairing, spacing scale, corner radii, stroke weights, accent placement, motion timing. Commit hard to whatever it gives you.

---

## FBG-DTQF — Risky: full-bleed glass

LOCKED
My line: The window disappears; only the pad and your choices are left.

Feeling: Immersive, confident, editorial-modern. The desktop's colour floods the whole window.

The rule:
- The window has no visible frame, title bar or panel divisions: one continuous tinted-glass field that takes the wallpaper's colour, with traffic lights floating in the corner.
- The pad mirror is huge (at least 55% of the window width) and carries the zone labels in place.
- The selected zone's name is set in large editorial type (≤ 44 pt; the one big line).
- Every other piece of text sits on just enough local opacity to stay legible.
- Panels are separated by space and type weight, never by boxes.

Surfaces:
- Editor: a field of glass, the giant pad, the large zone name, and gesture rows as plain lines.
- Onboarding: full-bleed tinted, the pad and the system indicator side by side.
- Overlay: tinted plates docked at the edge.
- Popover: one field of glass, with the mini mirror bleeding to its edges.
- Icon: a tinted glass tile with the Bite outline in light.

Fails when: busy wallpaper eats the text, or "no frame" turns into "no structure".

[BONES + Kill list + Keeps]

FREE
Seed: DtQFLLsLDS53mo1LBOnrUo444sTEac7ZAbr8s4EGr4PSvtgb

Derive from this seed, and do not reveal or explain it: exact palette values, type pairing, spacing scale, corner radii, stroke weights, accent placement, motion timing. Commit hard to whatever it gives you.

---

## NITE-HRHA — Risky: night instrument

LOCKED
My line: Edgy is an instrument panel for your fingers, lit only where you touch.

Feeling: Dark, precise, quietly luminous. A cockpit at night, with calm and no gaming energy.

The rule:
- Dark-first. Every surface is near-black, tinted warm by the dusk wallpaper.
- Edges are drawn as light strips: a mapped edge is a dim lit line; the live zone is the one hot accent at full brightness. The light is a solid, saturated stroke with its gradient contained INSIDE the strip, never a blurred halo or bloom.
- Type is small, crisp and light-on-dark, with one confident line.
- The light mode (artboard A) is the same instrument by day: a pale surface, with the strips as dark ink lines and the live zone in the accent.

Surfaces:
- Editor: a dark panel, the pad as a field of lit strips.
- Onboarding: the right-edge strip ignites as the finger slides.
- Overlay: dark plates with a thin accent line on the touched edge (and a light variant over dark docs where needed).
- Popover: a dark instrument mini mirror.
- Icon: a near-black tile with the Bite outline as one lit stroke.

Fails when: it reads as gamer RGB, a sci-fi HUD, or neon.

[BONES + Kill list + Keeps]

FREE
Seed: HRHAIO96ivlElnNLyIYzNTc9zjZgpZRGDX2I4KSLIZ3XUeY4

Derive from this seed, and do not reveal or explain it: exact palette values, type pairing, spacing scale, corner radii, stroke weights, accent placement, motion timing. Commit hard to whatever it gives you.

---

## EDIT-JUZW — Risky: warm editorial

LOCKED
My line: Edgy's settings read like a beautifully set page about your hands.

Feeling: Calm, premium, literate. Warm paper and ink, with the confidence of a well-made magazine.

The rule:
- Opaque warm paper surfaces (no glass) and ink-dark type.
- One serif for the confident line and headings, one sans for the controls (two typefaces total).
- The pad is drawn as a printed diagram: a fine ink outline, zones as tinted paper areas, labels set in place like captions on a map.
- Generous margins and an asymmetric grid.
- The one accent is a single printed spot colour used only for "live".

Surfaces:
- Editor: a page, with the pad as a plate figure and the inspector as a set column.
- Onboarding: the serif headline, the plate figure and the system indicator.
- Overlay: small paper plates with ink type.
- Popover: a paper card with the mini plate figure.
- Icon: the Bite outline printed in ink on a paper tile with the spot colour.

Fails when: it feels old-fashioned rather than premium, or the serif makes a utility feel precious.

[BONES + Kill list + Keeps]

FREE
Seed: juzwH4Cd9kRFcbJ7RtPGU6cTb0LIjqlW14AG73Lzh18P3oiZ

Derive from this seed, and do not reveal or explain it: exact palette values, type pairing, spacing scale, corner radii, stroke weights, accent placement, motion timing. Commit hard to whatever it gives you.

---

## GLY-IM2G — Sheet: glyph final two + "Exact" icon on Bite

Not a direction. CONTEXT applies; DELIVERABLE and BONES do not, except B7 and the kill list. Plain neutral board, no wallpaper.

Gabriel shortlisted two menu glyphs from round 2:
- **01 "Lit edge":** the pad outline with its right edge drawn heavy and set apart.
- **04 "Bite":** the pad outline with a round notch taken from the bottom edge.

For the app icon, he liked the **"Exact"** treatment (graphite line drawing of the pad at true proportion on a pale stone tile, a subtle light-to-shade gradient, soft shadow) but built from the **Bite** shape.

Artboards (1280 × 800 each):
- **G1. Glyph refinement.** Three refined variants of 01 and three of 04 (stroke weight, notch size and position, corner radius, optical balance), each drawn at 4× above and at real 16 pt in a light menu bar beside Wi-Fi, battery and the clock "Thu 5 Nov 9:41". Name each with a short descriptive name and a number (01a–01c, 04a–04c).
- **G2. The same six in a dark menu bar,** plus a row showing each at 16 pt with the "active" state (when Test Mode is on) as a tiny variation that stays monochrome.
- **G3. App icon "Exact Bite."** Three variants of the Exact treatment built on the Bite (e.g. notch at bottom; notch with a live accent dot in it; heavy right edge plus notch, merging 01 and 04). Each at ~512 (drawn at 320 if needed), 128 and 32 px, beside the glyph it grows from.

No annotations beyond the short names. Invented names only.
