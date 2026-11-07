# Edgy brand book

Start here before you make anything that looks or sounds like Edgy: app UI, an icon, a screenshot, the website, the landing page, a social post, a launch video.

- **Product UI:** `docs/BRIEF.md` § Design is canonical. It holds the exact tokens, the 10 bones (hard rules every UI PR is checked against), every surface spec and the copy tables. This book summarises it and never overrides it. **When this file and BRIEF disagree, BRIEF wins.**
- **Everything outside the app** (website, landing page, social, README screenshots): this book is the guide. See § Applying it outside the app.

---

## What Edgy is

**Every edge and corner of your trackpad, mapped to whatever you want.** An open-source (MIT) macOS menu-bar app.

## Personality

- **A warm, friendly object you like seeing.** Not a tool panel, not a dashboard. Something you're glad to find in your menu bar.
- **Trust.** Edgy acts on your volume, your music and your windows while you're on a call or mid-sentence. The design sells one feeling: it does exactly what you meant.
- **Nothing fires by accident.** Every rejected touch has a reason, a measurement and a limit, and Edgy will tell you which. Showing that it said no is as much the brand as showing that it said yes.
- **Calm and exact, never cold.** Real units (mm, ms), real numbers, plain words. Warmth comes from material and colour, not from jokes or exclamation marks.

## The look

**Warm glass that borrows your desktop's colour, with one rust accent that means "live".**

- The window, the popover and the overlay plates are translucent material tinted by what's behind them. Edgy owns no palette: your wallpaper supplies the colour; Edgy supplies an ink colour and one accent.
- The trackpad is drawn as a **mirror**: to scale, in its real orientation, a softly lit slab with subtle depth. You map gestures by clicking zones on that mirror.
- **One hue.** No blue selection, no amber warning, no red error. Hierarchy comes from type size, weight, shape and the single accent.

**Why this look.** It was picked on taste in all three rounds of the design sprint, over a blueprint direction, a blueprint/glass fusion and four riskier skins. The critic score went from 5/10 to 7/10 as the structure (the bones) was fixed underneath it. The product needs both things this look gives: an editor you trust, and a menu-bar presence you like.

---

## Colour

### Tokens

Copied from `docs/BRIEF.md` § Tokens. **BRIEF is canonical; if a value here ever differs, BRIEF wins.** In code, use `Sources/EdgyUI/Shared/Tokens.swift` (transcribed from BRIEF), never literals.

| Token | Light | Dark | Use |
|---|---|---|---|
| `ink` | `#3B2219` | `#FBEADB` | primary text, selection ring, glyph |
| `ink2` | `#6B4A3B` | `#D9BFAE` | secondary text (must still be ≥4.5:1 on its actual background) |
| `accent` / live | `#B4542B` | `#B4542B` | **only:** recognized touch, the live zone, ON switches, the icon dot |
| `bar` (mapped edge) | `#D9AE8C` | `#7A5646` | mapped zone fill |
| `line` (outlines) | `#8E6B58` | `#A58676` | unmapped hairlines, dashed pass-through (≥3:1 on the pad) |
| pad slab | `#F8E3CE → #EFCCAB` | `#4A3026 → #3A251D` | the mirror's surface, top-left lit |
| window material | warm translucent, ~0.8 opacity over blur | `rgba(42,27,21,.82)` | system window material tinted warm; never let text drop below 4.5:1 |

### The accent rule

Rust `#B4542B` means **live** and nothing else:
- a recognized touch (the filled contact on the mirror or an overlay plate),
- the zone being touched right now (a thin accent border on the lit bar),
- ON switches, the key recorder while it's recording, the level bar,
- the contact dot on the app icon.

It is the same value in light and dark. It never marks selection (selection is an `ink` ring), never decorates, and never carries an error or warning. If you're tempted to use it for emphasis, use weight instead.

**Warnings and errors** are told apart by icon and wording, never by colour: error = error icon + `ink`; warning = warning icon + `ink2`; info = info icon + `ink2`.

### The material and the legibility rule

- The material is the system's translucent window material, tinted warm. Over a busy or dark wallpaper it shifts with it, and that's the point.
- **Legibility beats translucency, always.** Every line of text sits on enough opacity to reach ≥4.5:1 against what's actually behind it (≥3:1 for outlines on the pad). If a wallpaper breaks that, add opacity, not a second colour.
- Overlay plates must read over both a light and a dark document. That's the worst-case test frame.
- No glass stacked on glass: one material layer, then content.

---

## Type

- **The system font only.** One family. No display face, no serif, no monospace in the UI.
- **One scale:** **11 / 13 / 17 / 26**.
  - **11:** picker group headers only.
  - **13:** everything else. **This is the floor**: no label, caption or plate text below 13.
  - **17:** plate values ("Volume 64%"), the Continue button.
  - **26:** the one confident line per surface: the selected zone's name, or the onboarding headline.
- **Weights:** regular and semibold.
- **Numerals:** proportional figures everywhere. No space before % ("64%", never "64 %"). Units take a space ("21 mm", "300 ms").
- Labels are never rotated.

## Shape

- **Radii:** the window uses the system radius; controls 6–8; plates 12–14; zone bars have fully rounded ends. Never one radius for everything, and never a radius nested inside a radius.
- **The pad drawing (the mirror):** to scale from the device's real sensor size, in the trackpad's orientation. A softly lit slab: top-left light, a soft lower edge, a touch that presses in slightly. No rulers, dimension lines or mm callouts; the outline is the measurement. No glow halos.
- **Zone shapes** (state is carried by shape, not only colour):

| State | Shape |
|---|---|
| Mapped edge | solid inset bar with rounded ends |
| Unmapped edge | hairline outline |
| Mapped corner | solid rounded square with its action icon inside |
| Pass-through corner | dashed rounded square (dashed means pass-through and nothing else) |
| Selected | `ink` ring around the zone |
| Live | accent contact plus a thin accent border on the lit bar |
| Recognized touch | filled accent contact |
| Rejected touch | hollow, struck circle |

- Labels join their zone: tabs growing from the strip in the same fill, no gap, never floating pills.
- **Gesture icons:** one family, one stroke weight, one grid. Swipe up and swipe down must differ clearly. No emoji or Unicode arrows.

---

## Iconography

### Menu-bar glyph: "Lit edge"

A rounded-rectangle outline of the pad, open on the right, with a separate heavy vertical bar standing for the lit right edge. A monochrome template image, about 16 × 11 pt, tinted by the system for light, dark and highlighted bars.

States change the **shape**, never the colour:

| State | Glyph |
|---|---|
| Normal | outline plus the heavy right bar |
| Test Mode | adds a small solid dot inside the outline (3.2 pt; must be ≥2 pt at 1×) |
| Paused | the heavy bar becomes two short stacked dashes |
| Disabled / No trackpad | normal artwork at 40% opacity (applied in code) |
| No Accessibility / Broken config | the heavy bar becomes an exclamation (a short bar plus a dot) |

Precedence when several apply: Broken config > No Accessibility > No trackpad > Paused > Disabled > Test Mode. Show the top one only.

### App icon: "Exact"

A pale-stone rounded tile with a gentle light-to-shade gradient, carrying a graphite line drawing of the pad at true proportion with a heavy right edge (the glyph, enlarged). At ≥128 px it adds one rust contact dot on the heavy edge; at 64 px and below there is no dot, and a heavier small-size drawing is used. No banding at the tile edge.

### Where the assets live

`docs/design/assets/` (spec and export notes in its `README.md`):
- `glyph-<state>.pdf`: 7 template-image PDFs, 16 × 11 pt, pure vector.
- `AppIcon.icns`, `AppIcon.iconset/`, `icon-1024.png`.
- `svg/`: the vector sources (glyph per state, `app-icon.svg` with the dot as group `#contact-dot`, `app-icon-small.svg`).

Use these files. Don't redraw the glyph or icon in code or in a web page; export from the SVG sources.

### Open: the "CI" question (G1 device check)

One critic read the glyph as the letters "CI" before reading it as a pad. The same reading is worth checking on the app icon at large sizes. **Judge both at real size, in the real menu bar and Dock, light and dark, before freezing them.** Until that check passes, treat the glyph and icon as provisional for marketing: don't build a logo lockup or wordmark around them.

---

## Voice and copy

**Plain, specific, measured.** Name the thing, the number and the limit.

- **One clause.** No colon headlines, no two-part lines, no slogans.
- **Real units.** "21 mm", "300 ms", "47 min left". The number is the reassurance.
- **Say it once,** next to the thing it describes. Don't restate a status in a caption, chip or footer.
- **Inform, don't alarm.** Interaction notes use an info icon and calm wording; they never read as an error.
- **Describe what the user feels,** not the mechanism ("Slide this far to move one app.").

### Do

- "Ignored: palm, 21 mm wide, limit 18 mm"
- "Ignored: typing, last key 200 ms ago, limit 500 ms"
- "These need a slide."
- "Run one finger up the right edge."
- "Tap waits 300 ms here to tell it from a double-tap."
- "Let Edgy run your actions" (onboarding headline)
- "Paused, 47 min left"
- "Would set Volume" (Test Mode dry run)

### Don't

| Don't | Why |
|---|---|
| "Precision you can read: every zone has a real size." | Two-part oracular line, and a slogan |
| "More actions coming soon" | Filler or roadmap copy |
| "Right edge · 1 finger · recognized · Default profile" | Middot-chained metadata |
| "Rejected!" / "Error: palm detected" | Alarm wording; no measurement, no limit |
| "64 %" | Space before % |
| "Test mode" pill next to the glyph | Restates what the glyph's dot already says |

The full rejection-copy table (every reason, its measure and its limit) is in BRIEF bone 4.

---

## Kill list (never ship these)

Copied from `docs/BRIEF.md` § Kill list; BRIEF wins.

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

---

## Applying it outside the app

The website, the landing page, social posts, launch video frames and README screenshots should feel like the app is sitting on the page. Translate the system; don't invent a second brand.

- **Background:** warm, wallpaper-like fields: soft desert-dune tones (sand, clay, dusk) or a generic photographic wallpaper feel. The page plays the role of the user's desktop. Never a flat grey, never a gradient blob.
- **Panels:** glass panels on that background, with enough opacity that text reaches ≥4.5:1 everywhere, including on narrow phone widths where the background shifts behind the text. One material layer; no glass on glass.
- **Colour:** `ink` and `ink2` for text, rust `#B4542B` **only** for "live" (the touch on the hero mirror) or the single primary action (download / buy). One rust thing per view. No second hue, no link blue: links are `ink` with an underline.
- **Type:** the system font stack, `font-family: system-ui, -apple-system, sans-serif;` (`-apple-system` is a CSS keyword, not a product name, and passes the denylist). Same scale idea: one 26-equivalent confident line per section (scale it up for a hero, but keep one size per role), body at the 13-equivalent floor or above, regular and semibold only.
- **Hero:** the to-scale trackpad mirror with a live touch on it: the slab, the zone shapes, a rust contact sliding up the right edge, and a plate reading the real result ("Volume 64%" / "Right edge, slide"). Show a rejection too ("Ignored: palm, 21 mm wide, limit 18 mm"); it's the most convincing frame Edgy has.
- **Headline:** one confident clause. No colon, no tagline pair, no slogan. "Every edge and corner of your trackpad, mapped to whatever you want." is the reference.
- **Product names and imagery:** no third-party product names or logos, no device photos of branded hardware, no look-alike UI of other apps. Draw the trackpad as Edgy's own mirror, never photograph one. Screenshots must not show other apps' names or icons (use invented app names, as the design renders do).
- **README screenshots:** capture the real app on a warm wallpaper, light and dark, at 2×. Crop to the window or the popover; don't add drop-shadow frames, device mockups or arrows.
- **Social and video:** the overlay plates and the live mirror are the screenshot-able moments. Keep plate text ≥13-equivalent and the one accent; no lower-third sports graphics, no neon, no glow.
- **The kill list applies to the web too.** Especially: no eyebrow micro-caps, no N equal feature cards, no hero numerals, no roadmap copy.
- **Glyph and icon:** use the exported assets as they are (see Iconography). Respect the open "CI" check before building a logo around them.

---

## Assets index

- **Final reference renders** (look 26F-1TVB), `docs/design/final/`:
  - `26F-1TVB-A.png`: Settings editor, light
  - `26F-1TVB-B.png`: Settings editor, dark, with the picker and an interaction note
  - `26F-1TVB-C.png`: Onboarding step 2, "Try it"
  - `26F-1TVB-D.png`: Test Mode overlay
  - `26F-1TVB-E.png`: Menu-bar popover
  - `26F-1TVB-F.png`: App icon and menu glyph
- **Supplement renders** (approved 2026-11-07), `docs/design/final/supp/`:
  - `26F-SUPP-S1.png`: an app profile tab (inheriting)
  - `26F-SUPP-S2.png`: the add-app popover, step 2 ("Start from")
  - `26F-SUPP-S3.png`: binding parameter editors, dark
  - `26F-SUPP-S4.png`: the picker at catalog scale, light
  - `26F-SUPP-S5.png`: system states (glyph in every state, plus paused / no Accessibility / no trackpad popovers)
  - `26F-SUPP-S6.png`: onboarding step 1, Accessibility
  - `26F-SUPP-S7.png`: onboarding step 3, presets
  - `26F-SUPP-S8.png`: plates and issues (level plate, display check, hold plate)
- **Production assets:** `docs/design/assets/` and its `README.md`.
- **Build snapshot critiques:** `docs/design/critiques/batch-N.md` (created per merged UI batch, checked against the final renders), with the snapshots in `docs/design/build-shots/`.
- Renders show the feel; when a render and BRIEF disagree, BRIEF wins.

## Provenance

- A three-round design sprint ran 2026-11-04 → 11-07. 25 design languages were narrowed to 7 directions, rendered blind and critiqued by blind critics after the owner's gut reactions were recorded.
- Round 1 (7 directions) produced the bones and the kill list: `docs/design/bones.md`, `docs/design/critic-r1.md`, `docs/design/canvas-prompts-r1.md`.
- Round 2 kept warm glass as the base and killed the sidebar directions; separate sheets fixed the overlay and the glyph: `critic-r2.md`, `canvas-prompts-r2.md`.
- Round 3 tested warm glass against four riskier skins and picked it again on taste (taste-only stop rule), merging subtle slab depth: `critic-r3.md`, `canvas-prompts-r3.md`.
- The final render (`canvas-prompts-final.md`) went through one polish pass; the critic score went 5 → 6 → 7/10, with 0 bone FAILs from round 3 on.
- The remaining gaps became build rules in `docs/BRIEF.md` § Design, the supplement screens were approved, and the production assets were exported to `docs/design/assets/`.
