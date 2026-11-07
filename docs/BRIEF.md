# Edgy brief

## Design

This section was locked on 2026-11-07 by a three-round design sprint. The full record is in `docs/design/`:
- the bones
- the prompts for every round
- the critiques
- the final reference renders in `docs/design/final/26F-1TVB-A..F.png`

The editable canvas is the claude.ai Design artifact "Edgy final · 26F-1TVB" (owner-private). When this section and a render disagree, **this section wins**; the render shows the feel.

### The look in one line

**Warm glass that borrows your desktop's colour, with one rust accent that means "live".** The window, popover and plates are translucent material tinted by what's behind them. Every line of text sits on enough opacity to read. The app owns no palette, only an ink colour and one accent.

Why this look: the owner picked it on taste in every round (rounds 1, 2 and 3; the other directions were killed or parked). It is a warm, friendly object you like seeing, on a utility you must trust. The critic score went from 5/10 (round 2) to 7/10 (final v2), with 0 bone FAILs from round 3 onward.

### Tokens

| Token | Light | Dark | Use |
|---|---|---|---|
| `ink` | `#3B2219` | `#FBEADB` | primary text, selection ring, glyph |
| `ink2` | `#6B4A3B` | `#D9BFAE` | secondary text (must still be ≥4.5:1 on its actual background) |
| `accent` / live | `#B4542B` | `#B4542B` | **only:** recognized touch, the live zone, ON switches, the icon dot |
| `bar` (mapped edge) | `#D9AE8C` | `#7A5646` | mapped zone fill |
| `line` (outlines) | `#8E6B58` | `#A58676` | unmapped hairlines, dashed pass-through (≥3:1 on the pad) |
| pad slab | `#F8E3CE → #EFCCAB` | `#4A3026 → #3A251D` | the mirror's surface, top-left lit |
| window material | warm translucent, ~0.8 opacity over blur | `rgba(42,27,21,.82)` | system window material tinted warm; never let text drop below 4.5:1 |

- **One hue.** No second colour anywhere: no blue selection, no amber warnings, no red errors. Warnings use weight plus an icon. The window buttons are neutral.
- **Type:** the system font only. One scale: **11** (picker group headers only) / **13** (everything else, the floor) / **17** (plate values, Continue) / **26** (the one confident line: the selected zone's name or the onboarding headline). Weights are regular and semibold. Use proportional figures everywhere, with no space before % ("64%").
- **Radii:** the window has the system radius; controls 6–8; plates 12–14; zone bars fully rounded ends. Never one radius for everything, and never a radius nested inside a radius.
- **Gesture icons:** one family, one stroke weight and one grid. Swipe up and swipe down must differ clearly.

### Bones (hard rules; every PR touching UI is checked against these)

The full text and evidence are in `docs/design/bones.md` and `docs/design/canvas-prompts-r3.md` § BONES.

1. **The mirror is the pad.**
   - It is to scale, from the device's real sensor size.
   - It uses the trackpad's orientation.
   - No rulers, dimension lines or mm callouts.
2. **Zone states by shape** (the build must match the final render):
   - **Mapped edge:** a solid inset bar with rounded ends.
   - **Unmapped edge:** a hairline outline.
   - **Mapped corner:** a solid rounded square with its action icon inside.
   - **Pass-through corner:** a dashed rounded square. Dashed means pass-through and nothing else.
   - **Selected:** an `ink` ring around the zone.
   - **Live:** the accent contact, plus a thin accent border on the lit bar.
   - Selection and live never look alike.
3. **Labels are joined to their zone.**
   - Side strips are 8 mm, about 30 pt, too narrow for text. Their labels are tabs growing from the strip's inner side, in the same fill and with no gap.
   - Top and bottom labels sit inside the bar.
   - Corner labels are tabs flush to the corner tile.
   - Labels are never floating pills, never rotated, and ≥13 pt.
   - The selected zone needs no chip, because the inspector names it.
4. **Recognized vs rejected by shape.**
   - **Recognized:** a filled accent contact.
   - **Rejected:** a hollow, struck circle.
   - A rejection states the measured value against the limit: **"Ignored: palm, 21 mm wide, limit 18 mm"**. This plate was every critic's KEEP; build it exactly like that.
   - Recognized is louder.
5. **You map on the pad.**
   - Clicking a zone selects it.
   - The action picker is a popover anchored to that zone on the mirror, with an arrow.
   - It has a header naming what it sets ("Tap, bottom edge"), a search field and grouped rows.
   - **Build it as a single-column list that scrolls if needed.** The render's two columns were a canvas-space workaround that the critic marked down.
   - Actions that can't take the gesture are dimmed, with **one** group note ("These need a slide.").
   - The picker never covers its trigger or the neighbouring zones, and never leaves the window.
6. **The inspector:**
   - It shows the selected zone's name (26), "Split into 1 2 3 4" (the runtime allows 1…4 segments), and **only the mapped gestures** with their actions in plain text.
   - It ends with "Add gesture…".
   - Clicking a row opens the same pad popover. There is one place to map, not two.
   - While the picker is open, the row's value is blank (the popover header already says it).
7. **Conflicts are named with their fix:**
   - It's a compact note in the inspector with a warning icon.
   - It states the real misfire ("Mapping Tap here makes every double-tap fire the tap action first, then Play/Pause.").
   - It gives two inline fixes ("Delay tap by 300 ms", "Use long-press instead").
   - It doesn't repeat the zone name.
8. **Each status is said once, next to the thing it describes.**
   - Live feedback appears on the mirror at the touch.
   - In onboarding, the system's own volume indicator carries "64%"; Edgy doesn't repeat it.
   - In Test Mode, the menu glyph's dot is the only "test mode is on" marker. **Drop the "Test mode" pill shown in render D.**
9. **The overlay (Test Mode):**
   - It is a click-through, non-activating panel that never takes focus and never sits over the text being worked on.
   - Each element is its own plate, docked to the screen edge or corner of the touched zone and fully on-screen.
   - Plate text is ≥13 pt at ≥4.5:1, readable over light and dark documents.
   - **One plate component** is shared by the overlay and the onboarding feedback: same radius, same 17/13 type pair, same inset. In the render, C and D look like two products; don't build that.
10. **The menu-bar popover** (not a plain menu):
    - **Top half:** a live mini mirror (zones of the active profile plus the last touch where it landed), profile chips, and **Enabled** and **Test Mode** switches.
    - **Bottom half:** a plain list with the system highlight: Pause for 1 hour, Settings… ⌘,, Open config file, Reload config ⌘R, About Edgy, Quit Edgy ⌘Q.
    - No power button, hero numeral or cards on cards.

### Surfaces

| Surface | Reference | Notes for the build |
|---|---|---|
| Settings editor, light | `final/26F-1TVB-A.png` | No sidebar. Profile tabs sit top centre (Default, then per-app tabs with small monochrome app marks, then "+"), with Enabled at top right. The mirror is on the left, the inspector on the right, and a footer row holds Haptics, Launch at login, HUD and Advanced…. The pad slab has subtle depth: a soft lower edge, top-left light, and a touch that presses in slightly with no glow halo. |
| Settings editor, dark, picker + conflict | `final/26F-1TVB-B.png` | A and B are deliberately different states: B shows the right edge split into 2. In demo data, avoid mapping Brightness twice (left edge and lower right). The critic read that as incoherent. |
| Onboarding, step 2 "Try it" | `final/26F-1TVB-C.png` | Four steps: Accessibility ✓, Try it, Pick a preset, Launch at login. The live mirror and the system volume indicator appear side by side. One round Continue, the only chunky round control in the app. Headline: one clause, no colon. |
| Test Mode overlay | `final/26F-1TVB-D.png` | It's entered from the popover's Test Mode switch. Its plates dock at the touched edge. Remove the pill under the glyph (rule 8). |
| Menu-bar popover | `final/26F-1TVB-E.png` | Shows Test Mode being switched on. |
| Icon + glyph | `final/26F-1TVB-F.png` | See below. |

### Menu glyph and app icon

- **Glyph: "Lit edge" (01a, with 01b's wider gap).**
  - A rounded-rectangle outline of the pad, open on the right, with a separate heavy vertical bar standing for the lit right edge.
  - It's a monochrome template image, about 16 × 11 pt.
  - In Test Mode it adds a small solid dot inside the outline. **Make that dot ≥2 pt at 1×**, because the render's ~1.5 pt dot disappears.
  - Note for the G1 device check: one critic read it as the letters "CI" before reading it as a pad. Judge it at real size in the real menu bar before freezing it.
- **App icon: "Exact".**
  - A pale-stone rounded tile with a gentle light-to-shade gradient.
  - A graphite line drawing of the pad at true proportion, with a heavy right edge (the glyph, enlarged).
  - At ≥128 px, add one rust contact dot on the heavy edge. Leave the dot off at 32 px and below.
  - No banding at the tile edge.

### Kill list (never ship these)

- Tracked micro-caps eyebrow labels.
- A grey rounded rectangle with a drop shadow as the trackpad, or brushed metal.
- A sidebar.
- N equal cards, one per zone.
- Gradient blobs, neon glow, or halos on the touch dot.
- Emoji or Unicode arrows as gesture icons.
- Middot-chained metadata strings.
- Dimension lines or rulers.
- A space before %.
- More than one typeface family.
- Rotated labels.
- Hero numerals.
- A launcher grid of round buttons.
- Filler or roadmap copy ("more actions coming").
- Generic coloured squares as app icons.
- A second hue.
- Any third-party product name or look-alike.

### Copy voice

Plain, specific and measured. Name the thing, the number and the limit.
- "Ignored: palm, 21 mm wide, limit 18 mm."
- "These need a slide."
- "Run one finger up the right edge."

Use one clause, no slogans, and no two-part oracular lines.

### Not yet designed (the sprint drew 8 actions; the real catalog is bigger)

The sprint's renders assumed 8 actions and simple app profiles. The runtime (`docs/settings-reference.md`) has more, and these surfaces still need design. They must follow every rule above:

1. **The picker at catalog scale:** 34 actions in 8 categories (sound, display, media, system, windows, apps, keyboard, shortcuts), unavailable actions greyed out with their reason, and "Do nothing" last in app profiles.
2. **Binding parameter editors** in the inspector: a key-combo recorder (including modifier-only for holds), an app chooser, URL and file-path fields, number and choice controls, a shortcut name, a per-binding haptics toggle, and sensitivity.
3. **App profiles:**
   - Inheriting rows showing their source (inherited / overridden / turned off / app-only), with Turn off and Revert actions.
   - The "Edgy off in this app" state.
   - The add-app flow (choose the app; inherit / copy default / empty).
   - Converting a legacy full-replace profile.
4. **The Advanced… sheet:** gesture tuning (edge width, corner size, dwell, palm size, typing suppression, double-tap window, long-press, fingers) and haptics (events, tick and click strength).
5. **Issue states:** errors that block an edit, warnings (`actionUnavailable`, `overlappingZones`, `settingOutOfRange`), info notes (`tapWaitsForDoubleTap`, already designed as the conflict note), and a broken config file on reload.
6. **System states:** missing Accessibility permission, paused (with the time left), no trackpad attached, and disabled. Each appears in the popover, the glyph and the window.
7. **Onboarding steps 1, 3 and 4:** the permission grant, picking a preset, launch at login.
8. **A hold action in Test Mode and the overlay:** long-press push-to-talk (down/up).

### Open for the G1 cut list (decide on the device)

- Glyph legibility at 16 pt in the real menu bar, light and dark (the "CI" risk).
- The amount of slab depth on a real display (subtle, or flat).
- Window material over busy or very dark wallpapers. The full-bleed direction was parked on exactly this risk. Check text contrast on the owner's real wallpapers.
- What ships in v1: per-app profile tabs, the edge split (1–4), the onboarding flow, Test Mode, and the popover's mini mirror.
