# Canvas prompts: round 2 (2026-11-05)

Survivors: 26, 6, and the fusion 26×6. There are also two direction-agnostic sheets (D1) for the two interactions that failed the same way in all 7 round-1 renders. Every render goes on a NEW canvas. The bones (`bones.md`, round 2) are pasted verbatim into every LOCKED block.

Changes from round 1, made because our own spec caused tells:
- "The list will grow past 8, so the picker must scale" is gone (it produced roadmap copy in 6 of 7 pickers).
- "64 %" is now "64%".
- The C copy line must be one clause, with no colon.
- 6's rule no longer asks for dimension lines.
- 26's rule caps the big type line and limits round primaries to surfaces that have a primary action.

| Label | Direction | Seed |
|---|---|---|
| 26-1TVB | #26 Ambient glass (seed 2) | 1tVbfh9OK16JMqx3wSNSsMh00WABZ2fmW8W77evCGHZWCvp5 |
| 6-7F2S | #6 Engineering drawing (seed 2) | 7f2SHCn1znqznmp0DUAUhZjMWK3dtVin6MkZhSfmEDVGYotl |
| 26x6-LHPU | Fusion: 6's drawing as the editor, 26's warmth everywhere else | lHpUFDNHDaO0QgNmbNNgVb58U3l4K3SZlMv1yGilPTeoFtUI |
| OVL-TXON | Direction-agnostic: test overlay sheet | tXONfKJf6efvmGKlAAvO9FGvv7fh54hrRrkyaWodjAek3XkS |
| GLY-DC73 | Direction-agnostic: menu glyph + icon sheet | DC73GPbvtfqt2iR1aT81pP65f5HMjWE159zj7ZoVOqXF9bsh |

---

## CONTEXT (identical in every prompt)

Edgy is a free, open-source menu-bar app for macOS 14+. It turns every edge and corner of a laptop trackpad into a control. Slide the right edge for volume, slide the left edge for brightness, swipe the bottom edge for previous/next track, double-tap the bottom edge for play/pause, double-tap the top-right corner to mute, double-tap the top-left corner to mute the microphone. That is only the default preset: any zone can do any action, and each app can have its own profile (or disable Edgy entirely, e.g. for games).

The user is seated at a laptop, hands on the trackpad, eyes on the screen. They never look at the trackpad, so every surface must map screen to pad: same orientation, true proportions (the pad is a landscape rectangle roughly 160 × 100 mm). The emotion to sell is trust: nothing fires by accident. Feel is the product.

Data the UI must express (frozen, use these exact terms and values):
- Zones: 4 edges (left, right, top, bottom), each an 8 mm strip; each edge can be split into equal segments (e.g. right edge in 2: upper half and lower half do different things). 4 corners, each a 12 mm square. A mapped corner wins over its edges; an unmapped corner passes touches through to its edge.
- Gestures: slide (continuous, position 0–1), swipe up/down/left/right, tap, double-tap, long-press. 1 or 2 fingers (global).
- Binding = zone + gesture → action (+ parameters). Actions (8): Volume (continuous, sensitivity), Brightness (continuous), Mute, Microphone Mute, Play/Pause, Next Track, Previous Track, Run Shortcut (name parameter).
- Profiles: Default, plus per-app profiles that replace the default; any profile can be disabled.
- Settings: enabled, show menu-bar icon, HUD (native / none), haptics on/off, launch at login. Advanced tuning: edge width 8 mm, corner size 12 mm, dwell 120 ms, palm size 18 mm, typing suppression 500 ms, double-tap window 300 ms, long-press 500 ms, fingers 1.
- Reasons a touch is ignored: started outside a zone · palm · too many contacts · typing · off-axis motion · too fast · handed off to a system gesture · zone disabled.

Background for every artboard: draw your own desktop wallpaper as a soft abstract of layered warm dunes (oranges, terracotta, a little sky blue in one corner), plus the top menu bar of the OS (translucent strip; on the right: Wi-Fi, battery, clock reading "Thu 5 Nov 9:41"). No photos (none can be fetched); paint it. Use real, plausible text everywhere; no lorem ipsum. Invented app names only: never a real product name.

## DELIVERABLE (identical in the three direction prompts)

Six artboards, each a standalone screen at the exact size given. No annotations, no labels outside the UI, no design-system callouts, no explanation text.

- **A — Editor, light mode, 1280 × 800.** The settings window (about 960 × 640) on the desktop. The live trackpad mirror shows the default preset; one finger is resting on the right edge and the right-edge zone shows as recognized. The profile switcher shows Default plus two apps (a browser and a video-call app). The right edge is selected and its bindings are visible.
- **B — Editor, dark mode, 1280 × 800.** Same window in dark mode. The right edge is split into 2 segments (upper: Volume slide; lower: Brightness slide). The top-left corner is mapped (Microphone Mute, double-tap); the bottom-left corner is unmapped and passes through. The user has clicked the bottom edge on the mirror to choose an action for its tap gesture: the action picker is open, anchored to that zone, listing the 8 actions. Bottom edge also has double-tap → Play/Pause, so a conflict warning is shown (the first tap always fires before the double-tap).
- **C — Onboarding, "Try the right edge", 1280 × 800.** A smaller onboarding window (about 640 × 520). Step 2 of 4 (1 Accessibility permission ✓, 2 Try it, 3 Pick a preset, 4 Launch at login). The user is mid-slide on the right edge; volume is at 64%. Live feedback shows the slide was recognized, and the system's own volume indicator responds at the same time.
- **D — Test-mode overlay, 1512 × 982.** Full screen of a 14-inch laptop. Behind: live work (a text editor with a real paragraph of prose, the text cursor mid-paragraph). The overlay sits on top, click-through, not taking focus. It shows: two current touches, one recognized gesture (right edge · slide · Volume 64%), and one rejected touch near the bottom-left of the pad (palm, contact 21 mm wide, limit 18 mm).
- **E — Menu-bar dropdown, 1280 × 800.** The Edgy menu-bar icon in the OS menu bar (next to Wi-Fi and battery) and its dropdown open beneath it: Enable toggle · active profile (Default) · Pause for 1 hour · Test mode · Settings… · Open config file · Reload config · About · Quit.
- **F — Icons, 1280 × 800.** F overrides the wallpaper rule: on a plain neutral board, the app icon at 1024-style large size (rendered ~512 px) and at 128 and 32 px, plus the menu-bar glyph at real size (16 pt and 2× zoom) on a light menu bar and on a dark menu bar, each time beside a Wi-Fi and battery glyph.

One sample line of copy in the direction's voice, used as the onboarding headline on artboard C: one clause, no colon, no slogan.

## BONES (pasted into every LOCKED block)

B1 The mirror is the pad: to scale, real aspect ratio, same orientation as the trackpad. No dimension lines, rulers or mm callouts in the editor; the outline is the measurement.
B2 Five zone states read at a glance, by shape as well as colour: unmapped, mapped, mapped corner (wins), pass-through corner (falls to its edge), selected. Selection and live touch never share one colour treatment.
B3 Recognized vs rejected differ by shape (e.g. filled contact vs hollow/struck true-scale contact ellipse), not by colour alone. A rejection names its reason in plain words with the measured value against the limit ("Ignored: palm, 21 mm wide, limit 18 mm"). Recognized is visually louder than rejected.
B4 One accent means "live" (a recognized touch or the active zone) and nothing else. Warnings use type weight and an icon, not a second hue.
B5 You map on the pad: clicking a zone on the mirror selects it; the action picker is a searchable, grouped LIST in a popover anchored to that zone with an arrow, never covering its trigger, never outside the window. Labels sit on or beside their zone, horizontal, never rotated. Actions that can't take the current gesture are dimmed with the reason ("needs a slide"). No copy about future actions.
B6 The overlay never takes focus and never sits on the text being worked on. Click-through. Every overlay element sits on its own plate (opaque or blurred material) with text ≥ 13 pt at ≥ 4.5:1 contrast, docked to the screen edge or corner of the zone being touched, clipped to the screen, readable over both light and dark documents.
B7 The menu glyph has its own silhouette: monochrome template image, reads at 16 pt in light and dark bars, is NOT a rounded rectangle with a fill bar (reads as a second battery) and NOT a sidebar symbol. Drawn beside Wi-Fi and battery to prove it.
B8 The dropdown is a real menu: native menu weight and system highlight; no hero cards, icon wells, power buttons or large titles inside a menu extra.
B9 Each status is said once, next to the thing it describes: live feedback on the mirror at the touch point; never restated in a caption, chip or footer.
B10 Conflicts are named with their fix: the warning names the zone, states the actual misfire ("each double-tap fires Play/Pause first") and offers concrete fixes inline.

Kill list: tracked micro-caps eyebrow labels · a grey rounded rectangle with a soft drop shadow as the trackpad, or brushed-metal pinstripe skeuomorphism · N equal cards or panels, one per zone · gradient blobs, glass stacked on glass, neon glow, glow halos on the touch dot · emoji, Unicode arrows or stock system symbols as the only gesture vocabulary · one corner radius everywhere, or radius nested on radius on radius · fake stats or testimonials · two-clause slogan copy · any third-party product name or look-alike · middot-chained metadata strings ("Right edge · 1 finger · recognized") · dimension lines, rulers, mm callouts as decoration · a space before % or monospace numerals inside a proportional UI · more than two typefaces · rotated labels · a giant hero numeral as decoration · a launcher/share-sheet grid of round buttons for actions · sports lower-third or sticker type · filler or roadmap copy in controls · dashed outlines meaning more than one thing (dashed = pass-through only).

Keeps (carry these): the pad diagram is the editing surface and each mapping sits where its zone is · a rejection shows the measured reason · the conflict warning names the misfire and offers two fixes · the touch point at its real position inside a zone that lights as the finger lands · onboarding shows the live mirror and the system's own result side by side.

---

## 26-1TVB — #26 Ambient glass (seed 2)

LOCKED
My line: Edgy has no palette of its own; it borrows your desktop's.
Feeling: Warm, soft, friendly, tactile. A nice object you like seeing, not a tool you tolerate.
The rule: Surfaces are translucent material tinted by whatever is behind them, made legible by enough opacity behind every line of text. Hierarchy comes from one confident type line per window (at most 32 pt in a window, at most 17 pt in a menu) and generous softness; a chunky round control appears only where a surface has one primary action (onboarding Continue), nowhere else.
Surfaces: Editor: a tinted-glass window; the mirror is a soft slab whose zones take the desktop's warmth, with labels in place; one confident line names the selected zone. Onboarding: a warm headline, one round Continue, the mirror and the system volume indicator side by side. Overlay: small tinted plates docked at the touched edge. Menu: a native-weight menu on warm material. Icon: a soft tile catching warm light along one edge.
Fails when: the glass costs legibility, or it becomes a consumer-app costume on a utility (hero type, pills everywhere).
[BONES + Kill list + Keeps, verbatim from the BONES block above]

FREE
Seed: 1tVbfh9OK16JMqx3wSNSsMh00WABZ2fmW8W77evCGHZWCvp5
Derive from this seed, and do not reveal or explain it: exact palette values, type pairing, spacing scale, corner radii, stroke weights, accent placement, motion timing. Commit hard to whatever it gives you.

---

## 6-7F2S — #6 Engineering drawing (seed 2)

LOCKED
My line: Edgy draws your trackpad exactly, so you can trust what it does.
Feeling: Calm, exact, hairline. Specification paper, not a CAD tool.
The rule: Precision comes from the linework, not from measurement marks: the pad is an exact hairline plan at true proportion, segments are divided spans, mapped zones are drawn solid and pass-through zones dashed. Real units (mm, ms, %) appear only as values the user can read or set, never as dimension lines.
Surfaces: Editor: the pad as a precise plan drawing that you click to edit, with labels set along their zones; Advanced tuning is a quiet, collapsed section, not a ruled table. The window chrome stays native so it reads as a consumer utility. Onboarding: the drawn right edge fills as the finger slides, beside the system volume indicator. Overlay: hairline plates docked at the touched edge; a rejected touch is drawn as its true contact outline, struck. Menu: native. Icon: a corner bracket with one tick.
Fails when: it reads as engineering software rather than a consumer utility.
[BONES + Kill list + Keeps, verbatim from the BONES block above]

FREE
Seed: 7f2SHCn1znqznmp0DUAUhZjMWK3dtVin6MkZhSfmEDVGYotl
Derive from this seed, and do not reveal or explain it: exact palette values, type pairing, spacing scale, corner radii, stroke weights, accent placement, motion timing. Commit hard to whatever it gives you.

---

## 26x6-LHPU — Fusion: exact drawing inside warm material

LOCKED
My line: An exact drawing of your trackpad, in your desktop's light.
Feeling: Exact where you configure, warm where you live with it. Trustworthy and likeable.
The rule: Two layers, never mixed: the DRAWING (the pad mirror, wherever it appears) is an exact hairline plan in neutral ink with the single live accent; the MATERIAL (window, plates, menu, onboarding) is warm, translucent and tinted by the desktop, with enough opacity under every line of text. The drawing never borrows the warmth; the material never carries linework.
Surfaces: Editor: a warm-material window holding a crisp hairline mirror you click to edit, labels along their zones, one confident title (at most 32 pt). Onboarding: warm, friendly, one round Continue; the crisp mirror beside the system volume indicator. Overlay: warm plates docked at the touched edge, each holding a small crisp drawing of the zone with the touch. Menu: native-weight menu on warm material. Icon: a warm tile with one exact hairline bracket.
Fails when: the two layers blur into each other, or the warmth reduces the drawing's contrast.
[BONES + Kill list + Keeps, verbatim from the BONES block above]

FREE
Seed: lHpUFDNHDaO0QgNmbNNgVb58U3l4K3SZlMv1yGilPTeoFtUI
Derive from this seed, and do not reveal or explain it: exact palette values, type pairing, spacing scale, corner radii, stroke weights, accent placement, motion timing. Commit hard to whatever it gives you.

---

## OVL-TXON — Direction-agnostic: test overlay sheet

Uses CONTEXT and BONES (not the six-artboard DELIVERABLE). Four artboards, each 1512 × 982, full screen of a 14-inch laptop with the click-through test overlay over live work. O1 and O2 are drawn in an "exact hairline" voice (neutral ink, crisp plates); O3 and O4 in a "warm material" voice (desktop-tinted translucent plates). Same structure in both voices, so the structure can be judged apart from the skin.

- **O1 / O3 — Recognized, light document.** A light text editor with a real paragraph, cursor mid-paragraph. Right edge · slide · Volume 64%: the finger's trail and readout appear on a plate docked at the right screen edge, beside the touched zone. A second finger rests idle elsewhere.
- **O2 / O4 — Rejected + pending, dark document.** A dark-mode text editor with a real paragraph. A palm rests near the bottom-left: drawn as its true contact outline, struck, with "Ignored: palm, 21 mm wide, limit 18 mm" on a plate docked at the bottom-left corner. At the same time the bottom edge shows a tap waiting for the double-tap window (300 ms) to close.

Plates never sit on the paragraph containing the cursor. No full-screen zone grid.

FREE
Seed: tXONfKJf6efvmGKlAAvO9FGvv7fh54hrRrkyaWodjAek3XkS
Derive from this seed, and do not reveal or explain it: exact palette values, type, radii, stroke weights. Commit hard.

---

## GLY-DC73 — Direction-agnostic: menu glyph + app icon sheet

Uses CONTEXT and BONES (not the six-artboard DELIVERABLE). Three artboards, each 1280 × 800, plain neutral board (no wallpaper).

- **G1 — Glyph candidates, light bar.** Eight different glyph silhouettes for Edgy, each shown in a realistic light menu bar segment at real 16 pt size beside Wi-Fi, battery and the clock, with a 4× enlargement above each. Each must pass B7 (not a rounded rectangle with a fill bar, not a sidebar symbol). Explore: an open pad outline with one edge thickened, a corner bracket with a tick, a thickened edge stroke with a touch dot, a notch in an outline, and others of your own.
- **G2 — Same eight, dark bar.** Identical layout on a dark menu bar.
- **G3 — App icons.** Three app-icon concepts, each at ~512, 128 and 32 px, each paired with the glyph it grows from. One neutral/exact, one warm, one in between.

FREE
Seed: DC73GPbvtfqt2iR1aT81pP65f5HMjWE159zj7ZoVOqXF9bsh
Derive from this seed, and do not reveal or explain it. Commit hard.
