# Canvas prompts — round 1 (2026-11-05)

One self-contained prompt per direction. Every render goes on a NEW canvas. The CONTEXT and DELIVERABLE blocks are identical in every prompt. LOCKED is direction-specific. The draft kill list sits inside LOCKED for every direction.

| Label | Direction | Seed |
|---|---|---|
| 1-CTRL | #1 Native settings (control, no seed) | none |
| 23-67PL | #23 Edge-only | 67plkrwhQFsbGcg8rKiUsFdm78HIDkTvTYVB32yrxIp8fWR1 |
| 6-MG2X | #6 Engineering drawing | mg2xyDTKKkqXs3vIcaTWPtMssOYrCeXVdmgKPxW30QbfKw2J |
| 13-VZC3 | #13 Keycap legends | VZC3HHTKc6JRs6o7cKJzhnD8jKoS5pjIjPqGHAJAXTcovKTT |
| 12-NEJH | #12 Machined object | NejH4Z5wMKEEjQ9HHn4SOWlUE3btPqVF07zmZ97W0HDti3MG |
| 23F-MGWV | #23 + #22 fusion | MGWVFIo7r8EK8zwZ8ckkenaLwiegHHAgOTQjredSqKKb1jLJ |
| 26-OIID | #26 Ambient glass | oIiDI4tI4pVuHlyZSLVNnLW5WbSfI6arG2AiFuG54rGO1wKy |

---

## CONTEXT (identical in every prompt)

Edgy is a free, open-source menu-bar app for macOS 14+. It turns every edge and corner of a laptop trackpad into a control. Slide the right edge for volume, slide the left edge for brightness, swipe the bottom edge for previous/next track, double-tap the bottom edge for play/pause, double-tap the top-right corner to mute, double-tap the top-left corner to mute the microphone. That is only the default preset: any zone can do any action, and each app can have its own profile (or disable Edgy entirely, e.g. for games).

The user is seated at a laptop, hands on the trackpad, eyes on the screen. They never look at the trackpad, so every surface must map screen to pad: same orientation, true proportions (the pad is a landscape rectangle roughly 160 × 100 mm). The emotion to sell is trust: nothing fires by accident. Feel is the product.

Data the UI must express (frozen, use these exact terms and values):
- Zones: 4 edges (left, right, top, bottom), each an 8 mm strip; each edge can be split into equal segments (e.g. right edge in 2: upper half and lower half do different things). 4 corners, each a 12 mm square. A mapped corner wins over its edges; an unmapped corner passes touches through to its edge.
- Gestures: slide (continuous, position 0–1), swipe up/down/left/right, tap, double-tap, long-press. 1 or 2 fingers (global).
- Binding = zone + gesture → action (+ parameters). Actions: Volume (continuous, sensitivity), Brightness (continuous), Mute, Microphone Mute, Play/Pause, Next Track, Previous Track, Run Shortcut (name parameter). The list will grow past 8, so the picker must scale.
- Profiles: Default, plus per-app profiles that replace the default; any profile can be disabled.
- Settings: enabled, show menu-bar icon, HUD (native / none), haptics on/off, launch at login. Advanced tuning: edge width 8 mm, corner size 12 mm, dwell 120 ms, palm size 18 mm, typing suppression 500 ms, double-tap window 300 ms, long-press 500 ms, fingers 1.
- Reasons a touch is ignored: started outside a zone · palm · too many contacts · typing · off-axis motion · too fast · handed off to a system gesture · zone disabled.

Background for every artboard: draw your own desktop wallpaper as a soft abstract of layered warm dunes (oranges, terracotta, a little sky blue in one corner), plus the top menu bar of the OS (translucent strip, clock on the right reading "Thu 5 Nov 9:41"). No photos (none can be fetched); paint it. Use real, plausible text everywhere; no lorem ipsum.

## DELIVERABLE (identical in every prompt)

Six artboards, each a standalone screen at the exact size given. No annotations, no labels outside the UI, no design-system callouts, no explanation text.

- **A — Editor, light mode, 1280 × 800.** The settings window (about 960 × 640) on the desktop. The live trackpad mirror shows the default preset; one finger is resting on the right edge and the right-edge zone shows as recognized. The profile switcher shows Default plus two apps (a browser and a video-call app). The right edge's bindings are visible.
- **B — Editor, dark mode, 1280 × 800.** Same window in dark mode. The right edge is split into 2 segments (upper: Volume slide; lower: Brightness slide). The top-left corner is mapped (Mic mute, double-tap); the bottom-left corner is unmapped and passes through. The user is choosing an action for a zone and the action picker is open, showing all 8 actions plus a hint that more exist. A warning is shown because tap and double-tap are both bound on one zone (the first tap always fires before the double-tap).
- **C — Onboarding, "Try the right edge", 1280 × 800.** A smaller onboarding window (about 640 × 520). Step 2 of 4 (1 Accessibility permission ✓, 2 Try it, 3 Pick a preset, 4 Launch at login). The user is mid-slide on the right edge; volume is at 64 %. Live feedback shows the slide was recognized.
- **D — Test-mode overlay, 1512 × 982.** Full screen of a 14-inch laptop. Behind: live work (a text editor with a real paragraph of prose). The overlay sits on top, click-through, not taking focus. It shows: the zones, two current touches, one recognized gesture (right edge · slide · Volume 64 %), and one rejected touch with its reason ("palm") near the bottom-left of the pad.
- **E — Menu-bar dropdown, 1280 × 800.** The Edgy menu-bar icon in the OS menu bar and its dropdown open beneath it: Enable toggle · active profile (Default) · Pause for 1 hour · Test mode · Settings… · Open config file · Reload config · About · Quit.
- **F — Icons, 1280 × 800.** F overrides the wallpaper rule: on a plain neutral board, the app icon at 1024-style large size (rendered ~512 px) and at 128 and 32 px, plus the menu-bar glyph at real size (16 pt and 2× zoom) on a light menu bar and on a dark menu bar.

One sample line of copy in the direction's voice, used as the onboarding headline on artboard C.

---

## 1-CTRL — #1 Native settings (CONTROL, no seed)

LOCKED
My line: Edgy should look like it shipped with the operating system.
Feeling: Neutral, familiar, invisible. Sidebar, grouped forms, the system font and the system blue accent.
The rule: Use only standard OS settings-window patterns: sidebar list, grouped inset forms, popup buttons, switches, a translucent sidebar.
Surfaces: Editor: sidebar (Default, app profiles, General, Advanced) and a detail pane with a grey to-scale trackpad diagram showing zone outlines; a selected zone shows its bindings as a grouped form below. Onboarding: a standard multi-step setup window. Overlay: a frosted panel in a screen corner with a small pad and touch dots. Menu: a standard menu. Icon: a rounded-square app icon with a stylised trackpad and one highlighted edge.
Fails when: it's indistinguishable from any system pane.
Kill list: (none for the control; draw it the way the OS would.)

FREE
No seed. Use the system's defaults.

---

## 23-67PL — #23 Edge-only

LOCKED
My line: Edgy is about edges, so its interface lives on them.
Feeling: Quiet, luminous, almost absent. Light where your finger is, nothing elsewhere.
The rule: Nothing in the centre. Every control and label sits on a perimeter.
Surfaces: Editor: the pad sits centred in the window; each zone's binding sits on the matching window edge (the right-edge binding on the window's right edge, top-left corner binding in the window's top-left corner), so the window is the pad blown up. Mapped corners are lit; pass-through corners are hollow. Onboarding: a single light line on the real screen edge invites the first slide. Overlay: only a thin line of light on the real screen edge being touched; a rejection is a short dim flicker plus a few words at that edge. Menu: glyph is a rounded square with one lit edge. Icon: dark tile, one glowing edge.
Fails when: forms and the 8+ action picker can't fit on a perimeter without breaking the rule.
Draft bones:
B1 The mirror is drawn to scale and in the same orientation as the pad under the hands.
B2 Edges, segments and corners are distinguishable in a blurred thumbnail; mapped vs pass-through corners differ.
B3 Recognized vs rejected touches are clearly different; a rejection names its reason in plain words next to the touch.
B4 One accent, meaning "live / recognized" only. Never on buttons, headers or decoration.
B5 Zone → gesture → action → parameters edits in place, no modal chain; the action picker scales past 8.
B6 The overlay never takes focus and leaves live work readable.
B7 The menu glyph is a monochrome template image that reads at 16 pt in light and dark bars.
Kill list: tracked micro-caps eyebrow labels above blocks · a grey rounded rectangle with a soft drop shadow as the trackpad · N equal cards in a grid, one per zone · gradient blobs, stacked glass, neon glow on everything · emoji or stock system symbols as the only gesture vocabulary · one corner radius on every surface · fake stats or testimonials · two-clause slogan copy ("Your edges. Your rules.") · any third-party product name or look-alike.

FREE
Seed: 67plkrwhQFsbGcg8rKiUsFdm78HIDkTvTYVB32yrxIp8fWR1
Derive from this seed, and do not reveal or explain it: exact palette values, type pairing, spacing scale, corner radii, stroke weights, accent placement, motion timing. Commit hard to whatever it gives you.

---

## 6-MG2X — #6 Engineering drawing

LOCKED
My line: Precision you can read: every zone has a real size.
Feeling: Calm, exact, hairline. Specification paper, not a CAD tool.
The rule: Every zone carries its true dimension, and every number is a real unit (mm, ms, %).
Surfaces: Editor: the pad as a dimensioned drawing with dimension lines and arrowheads (8 mm edge, 12 mm corner); segments are divided spans with tick marks; the Advanced tuning pane is the drawing's title-block table. The window chrome around the drawing stays quiet and native so it reads as a consumer utility. Onboarding: a dimension line measures the first slide live. Overlay: a live dimension line along the slide showing position 0–1 and the value. Menu: corner-bracket glyph. Icon: a corner bracket with a dimension tick.
Fails when: it reads as engineering software rather than a consumer utility.
Draft bones: (B1–B7 exactly as listed under 23-67PL)
B1 The mirror is drawn to scale and in the same orientation as the pad under the hands.
B2 Edges, segments and corners are distinguishable in a blurred thumbnail; mapped vs pass-through corners differ.
B3 Recognized vs rejected touches are clearly different; a rejection names its reason in plain words next to the touch.
B4 One accent, meaning "live / recognized" only. Never on buttons, headers or decoration.
B5 Zone → gesture → action → parameters edits in place, no modal chain; the action picker scales past 8.
B6 The overlay never takes focus and leaves live work readable.
B7 The menu glyph is a monochrome template image that reads at 16 pt in light and dark bars.
Kill list: tracked micro-caps eyebrow labels above blocks · a grey rounded rectangle with a soft drop shadow as the trackpad · N equal cards in a grid, one per zone · gradient blobs, stacked glass, neon glow on everything · emoji or stock system symbols as the only gesture vocabulary · one corner radius on every surface · fake stats or testimonials · two-clause slogan copy · any third-party product name or look-alike.

FREE
Seed: mg2xyDTKKkqXs3vIcaTWPtMssOYrCeXVdmgKPxW30QbfKw2J
Derive from this seed, and do not reveal or explain it: exact palette values, type pairing, spacing scale, corner radii, stroke weights, accent placement, motion timing. Commit hard to whatever it gives you.

---

## 13-VZC3 — #13 Keycap legends

LOCKED
My line: The pad is labelled like a keyboard: you read the binding where it lives.
Feeling: Small, exact, printed. Dense without clutter.
The rule: Every binding is a printed legend on the pad itself. No side panel holds binding info.
Surfaces: Editor: legends printed along each edge and in each corner of the mirror, like keycap sublegends; clicking a legend edits it inline right there. A split edge shows divided legends. The tap + double-tap conflict shows as two legends stacked on one spot. Onboarding: legends appear one by one as you try them. Overlay: the legend being touched brightens. Menu: keycap glyph. Icon: a keycap with an edge legend.
Fails when: legend type falls below a readable floor, or inline editing gets cramped.
Draft bones:
B1 The mirror is drawn to scale and in the same orientation as the pad under the hands.
B2 Edges, segments and corners are distinguishable in a blurred thumbnail; mapped vs pass-through corners differ.
B3 Recognized vs rejected touches are clearly different; a rejection names its reason in plain words next to the touch.
B4 One accent, meaning "live / recognized" only. Never on buttons, headers or decoration.
B5 Zone → gesture → action → parameters edits in place, no modal chain; the action picker scales past 8.
B6 The overlay never takes focus and leaves live work readable.
B7 The menu glyph is a monochrome template image that reads at 16 pt in light and dark bars.
Kill list: tracked micro-caps eyebrow labels above blocks · a grey rounded rectangle with a soft drop shadow as the trackpad · N equal cards in a grid, one per zone · gradient blobs, stacked glass, neon glow on everything · emoji or stock system symbols as the only gesture vocabulary · one corner radius on every surface · fake stats or testimonials · two-clause slogan copy · any third-party product name or look-alike.

FREE
Seed: VZC3HHTKc6JRs6o7cKJzhnD8jKoS5pjIjPqGHAJAXTcovKTT
Derive from this seed, and do not reveal or explain it: exact palette values, type pairing, spacing scale, corner radii, stroke weights, accent placement, motion timing. Commit hard to whatever it gives you.

---

## 12-NEJH — #12 Machined object

LOCKED
My line: It's a physical thing under your hand; show it as one.
Feeling: Heavy, cool metal, precise detents. Restrained skeuomorphism, not glossy and dated.
The rule: Every zone is a physical feature of the slab (rail, detent, button), and haptic notches are visible.
Surfaces: Editor: the pad as a machined aluminium slab; each edge milled as a rail with small notches at 0 %, 100 % and a saved "home" value; corners are machined buttons (pressed-in = mapped, flush = pass-through). Binding controls are equally restrained, precise, physical. Onboarding: light rakes along the rail as you slide. Overlay: a small slab view in a screen corner; the touched rail catches light. Menu: slab-outline glyph. Icon: an aluminium slab with one lit chamfer.
Fails when: it looks like dated gloss, or rendering effort replaces clarity.
Draft bones:
B1 The mirror is drawn to scale and in the same orientation as the pad under the hands.
B2 Edges, segments and corners are distinguishable in a blurred thumbnail; mapped vs pass-through corners differ.
B3 Recognized vs rejected touches are clearly different; a rejection names its reason in plain words next to the touch.
B4 One accent, meaning "live / recognized" only. Never on buttons, headers or decoration.
B5 Zone → gesture → action → parameters edits in place, no modal chain; the action picker scales past 8.
B6 The overlay never takes focus and leaves live work readable.
B7 The menu glyph is a monochrome template image that reads at 16 pt in light and dark bars.
Kill list: tracked micro-caps eyebrow labels above blocks · a grey rounded rectangle with a soft drop shadow as the trackpad · N equal cards in a grid, one per zone · gradient blobs, stacked glass, neon glow on everything · emoji or stock system symbols as the only gesture vocabulary · one corner radius on every surface · fake stats or testimonials · two-clause slogan copy · any third-party product name or look-alike.

FREE
Seed: NejH4Z5wMKEEjQ9HHn4SOWlUE3btPqVF07zmZ97W0HDti3MG
Derive from this seed, and do not reveal or explain it: exact palette values, type pairing, spacing scale, corner radii, stroke weights, accent placement, motion timing. Commit hard to whatever it gives you.

---

## 23F-MGWV — #23 Edge-only + #22 Broadcast telestrator (fusion)

LOCKED
My line: Quiet in daily use, loud on replay.
Feeling: Perimeter calm in the app; sports-replay energy in test mode.
The rule: Every normal surface follows the edge-only rule (nothing in the centre, everything on a perimeter). Test mode alone breaks it: it draws the finger's path live like a replay analyst's pen and slides in a bold caption bar naming zone · gesture · action, or the rejection reason.
Surfaces: Editor: pad centred, each zone's binding on the matching window edge; mapped corners lit, pass-through corners hollow; a small "replay" of the last gesture can play on the pad. Onboarding: "try the right edge" uses the telestrator stroke once. Overlay (artboard D): a drawn stroke following the finger up the right edge, a slanted caption bar "RIGHT EDGE · SLIDE · VOLUME 64 %", and a freeze-frame mark on the palm touch with "REJECTED · PALM". Menu + icon as edge-only: rounded square with one lit edge.
Fails when: the two halves read as two different products.
Draft bones:
B1 The mirror is drawn to scale and in the same orientation as the pad under the hands.
B2 Edges, segments and corners are distinguishable in a blurred thumbnail; mapped vs pass-through corners differ.
B3 Recognized vs rejected touches are clearly different; a rejection names its reason in plain words next to the touch.
B4 One accent, meaning "live / recognized" only. Never on buttons, headers or decoration.
B5 Zone → gesture → action → parameters edits in place, no modal chain; the action picker scales past 8.
B6 The overlay never takes focus and leaves live work readable.
B7 The menu glyph is a monochrome template image that reads at 16 pt in light and dark bars.
Kill list: tracked micro-caps eyebrow labels above blocks (the test-mode caption bar is the one sanctioned exception, and only there) · a grey rounded rectangle with a soft drop shadow as the trackpad · N equal cards in a grid, one per zone · gradient blobs, stacked glass, neon glow on everything · emoji or stock system symbols as the only gesture vocabulary · one corner radius on every surface · fake stats or testimonials · two-clause slogan copy · any third-party product name or look-alike.

FREE
Seed: MGWVFIo7r8EK8zwZ8ckkenaLwiegHHAgOTQjredSqKKb1jLJ
Derive from this seed, and do not reveal or explain it: exact palette values, type pairing, spacing scale, corner radii, stroke weights, accent placement, motion timing. Commit hard to whatever it gives you.

---

## 26-OIID — #26 Ambient glass

LOCKED
My line: Edgy has no palette of its own; it borrows your desktop's.
Feeling: Warm, soft, friendly, tactile. A nice object you like seeing, not a tool you tolerate.
The rule: Every surface is translucent material tinted by whatever is behind it; hierarchy comes from one big confident line of type and one chunky round primary control per surface, everything else small.
Surfaces: Editor: a tinted-glass window; the mirror is a glass slab whose zones glow faintly with the desktop's colour; one large type line names the selected zone ("Right edge"); the binding controls are round, chunky, glyph-led with one clear primary. Onboarding: big headline, one big round affordance, the pad mirror below. Overlay: a small tinted glass panel near the touched edge with one big readout ("64 %"). Menu: the dropdown is a tinted glass popover with the profile as the big line and grouped round controls in capsules. Icon: a glass tile catching warm light along one edge.
Fails when: the glass takes over and legibility suffers, or it's indistinguishable from the stock OS look.
Draft bones:
B1 The mirror is drawn to scale and in the same orientation as the pad under the hands.
B2 Edges, segments and corners are distinguishable in a blurred thumbnail; mapped vs pass-through corners differ.
B3 Recognized vs rejected touches are clearly different; a rejection names its reason in plain words next to the touch.
B4 One accent, meaning "live / recognized" only. Never on buttons, headers or decoration.
B5 Zone → gesture → action → parameters edits in place, no modal chain; the action picker scales past 8.
B6 The overlay never takes focus and leaves live work readable.
B7 The menu glyph is a monochrome template image that reads at 16 pt in light and dark bars.
Kill list: tracked micro-caps eyebrow labels above blocks · a grey rounded rectangle with a soft drop shadow as the trackpad · N equal cards in a grid, one per zone · gradient blobs, glass cards stacked on a glass panel, neon glow on everything · emoji or stock system symbols as the only gesture vocabulary · one corner radius on every surface · fake stats or testimonials · two-clause slogan copy · any third-party product name or look-alike.

FREE
Seed: oIiDI4tI4pVuHlyZSLVNnLW5WbSfI6arG2AiFuG54rGO1wKy
Derive from this seed, and do not reveal or explain it: exact palette values, type pairing, spacing scale, corner radii, stroke weights, accent placement, motion timing. Commit hard to whatever it gives you.
