# Batch 14 critique (mirror, mini mirror, preset mirror; integrated window)

Verdict: the mirror's grammar is right. Bars are solid with rounded ends, hairlines use `line` (about 3.4:1 light, 3.6:1 dark), corner tiles carry icons, pass-through is dashed, selected is an `ink` ring, live is an accent contact plus border, and rejected is a struck `ink2` circle. The mirror is to scale (Magic Trackpad 1.39:1, built-in 1.55:1), tabs are 13 pt and horizontal, and the picker is one column that clears every bar. Not ready: the slab's shadow points up and glows in dark, corner tabs float, and the live tab loses its zone's fill. Fix the 4 items below and re-shoot.

## Must fix

1. **The slab's depth is upside down, and in dark it's a halo.** Shots: every `pad-*`, `mini-*`, `preset-*` and `window-picker-bottom-*`. In light the shadow is darkest *above* the slab (#E5D1C1 above, #F7E4D4 below, on #FBE8D8). In dark, a lighter band (#42322B) rings the slab on #2A1B15. BRIEF: "a soft lower edge, top-left light, and a touch that presses in slightly with no glow halo". Kill list: "neon glow, or halos". Fix: point the y offset downward. In a non-flipped `NSView`/`CALayer`, a positive `shadowOffset.height` goes up, which is the likely bug. Use a dark, low-opacity shadow in both modes, never lighter than the material behind it.
2. **Corner tabs float.** Shots: every pad and window shot ("Mic off", "Mute") and `pad-wayfare-*` ("Hold Keys"). Each tab touches its tile only at a corner, with a visible notch (clearest in `pad-live-slide-right-dark`). BRIEF: "Corner labels are tabs flush to the corner tile." "never floating pills". Fix: draw tile and tab as one union shape in `bar` fill. The tab's top edge sits on the tile's bottom edge, starting inside the tile's x span, as in render A.
3. **The live tab keeps the idle fill.** Shots: `pad-live-slide-right-*`. The lit bar is #CA8A65, but the "Volume" tab stays #D9AE8C inside its own closed accent border, so it reads as a separate chip. BRIEF: tabs grow from the strip "in the same fill and with no gap"; live is "a thin accent border on the lit bar". Fix: the tab takes its zone's current fill (idle, lit or faded), and the accent stroke traces the bar and tab outline as one shape.
4. **Every binding shows its parameter rows.** Shots: `window-picker-bottom-*`. "Haptics for this gesture" appears under all three bindings. BRIEF: "Only one binding is open at a time … parameter rows, including 'Haptics for this gesture', appear only under the **open** binding." Fix: with the picker open for a new Tap, no row is open, so show none.

## Should fix

1. **The fade is applied per layer.** Shot: `pad-disabled-dark`. At 40%, the tab ends show through their strips and look detached. Fix: add `.compositingGroup()` before `.opacity(0.4)`. Re-check light mode and `pad-huddle-off-*`.
2. **Picker rows are about 33 pt.** Shots: `window-picker-bottom-*`. Only 6 actions fit at full interior height, and the panel sits about 1.5 pt under the top bar (render B's rows are about 21 pt). Fix: 24 pt rows and an 8 pt gap to the top bar, which is still within the cap.
3. **Action names disagree.** The picker and inspector say "Play / Pause" and "Keyboard Backlight On / Off"; the pad and BRIEF say "Play/Pause". Fix: one catalog display name, with no spaces around the slash.
4. **A truncated tab looks like "needs a parameter".** Shot: `pad-split-bottom4-long-label-*` ("Keyboard Short...", with three dots). On a tab, BRIEF's "…" means an empty required parameter. Fix: per Q5, and never end a truncated tab in "…".
5. **Preset corners read as dots.** Shots: `preset-media-minimal-*`. At 120 pt, mapped corners render as solid circles and pass-through ones as dotted circles. Fix: cap the corner radius at about 30% of the tile. Also shoot **Windows**, the densest preset.
6. **The mini mirror isn't shot at its real size.** Shots: `mini-*` are about 415 pt wide; the mini in render E is about 290 pt. Fix: re-shoot at popover width inside the popover, then judge the corner icons and hairlines. Add `mini-disabled-*`.
7. **Known wraps: "Previous Track" and "Sensitivity".** Shots: `window-picker-bottom-*` and `batch-16/window-default-*`. Fix: cut the inspector's leading inset from about 57 pt to 20–24 pt (render A is about 22), and use a fixed label column with `lineLimit(1)` and right-aligned values.

## Matches BRIEF

- Zone shapes are all correct, and splits draw to scale (end segments lose the corner overlap).
- The `ink` ring (#3B2219 / #FBEADB) never looks like live.
- The contact is filled accent, pressed in (darker top), with no glow. Rejected is a hollow struck circle in `ink2` (#6B4A3B). Recognized is louder.
- App tab: a solid `ink` dot on overridden tabs; "Off here" in 13 pt `ink2` on a hairline strip.
- Disabled and app-off fade to 40%, with app-off all hairlines. No trackpad is a dashed outline with exact copy, in both the window and the mini.
- The mini mirror has no labels; last touch shows the contact and the lit border, with no ring.
- Presets are 120 pt with the normal shapes. No second hue, rulers, rotated text or sub-13 pt text.

## Integrated window vs renders A/B

- **Mirror size:** 584 × 420 pt in the build against about 592 × 371 pt in A and B. Same width; the build is taller because it's to scale (1.39:1 against 1.6:1). BRIEF wins.
- **Placement:** both are vertically centred with about 110 pt above. The build leaves 57 pt above the footer against A's 82 pt. Fine.
- **Side tabs:** the build centres both; A staggers them (upper and lower third). Either works.
- **Corner tabs:** A tucks them under the tile; the build floats them (Must fix 2).
- **Picker:** both anchor to the bottom bar, with the arrow on a ringed bar. B is two columns and stops mid-pad. The build is one column at full interior height, which is correct.
- **Inspector:** B lists Swipe left, Swipe right, Tap ("Choosing…"), Double-tap. The build puts Double-tap first, has no Tap row, and adds haptics rows (Must fix 4). The split control correctly offers 1–4.
- **Depth:** A's shadow is below the slab. The build's is above it, and in dark it's a glow (Must fix 1).
- **Dark:** picker material, ring and tab type match B.

## Questions for design

1. **"Off here" ships as bare `ink2` text beside the hairline strip, which matches render S1.** BRIEF says "its tab reads 'Off here'." Should it be a hairline-outlined tab joined to the strip, or is bare text right?
2. **App-off draws corners dashed (pass-through), not as solid hairlines.** That's literally true when Edgy is off, but BRIEF says "every zone as a hairline". Confirm dashed for corners.
3. **At 120 pt, mapped corners drop their action icon** (render S7 does too). Is an icon-less solid tile acceptable at preset size, given that bone 2 says "with its action icon inside"?
4. **The picker is open for an unmapped Tap, and the inspector has no Tap row.** Should a pending "Tap" row with a blank value appear while choosing? Bone 6 says "the row's value is blank".
5. **What's the truncation rule for a long label on a narrow segment?** Options: a short form ("Shortcut"), the key combo ("⌃⌥ Space"), or the label clipped with no ellipsis.

## Design answers (chief, 2026-11-07)
1. **"Off here"** is a **tab joined to the strip**, like every other label (bone 3): a hairline outline in `line`, no fill, text in `ink2`. Bare text breaks the one-label-shape rule. (Render S1 was loose here.)
2. **App-off corners drawn dashed:** confirmed. When Edgy is off in an app, every corner passes through, and dashed means exactly that. Edges are hairlines.
3. **No action icon on corners in mirrors under ~200 pt wide** (preset mirrors, popover mini mirror): acceptable. The solid tile carries "mapped". The full-size mirror always shows the icon.
4. **Pending row:** yes. While the picker is open for an unmapped gesture, the inspector shows that gesture's row with a blank value (bone 6). It disappears if the picker is dismissed without a choice.
5. **Long labels on narrow zones.** Pad tabs never use "…", because the ellipsis is reserved for "needs a parameter". In order:
   - (a) The parameter's short value if it fits: the app name ("Quillpad") or the key combo ("⌃⌥ Space").
   - (b) The action's short name: Keyboard Shortcut → "Shortcut", Slide to Repeat Keys → "Repeat keys", Run Shortcut → "Shortcut", Microphone Mute → "Mic off", Open URL → "Link", Open File or Folder → the file's name.
   - (c) Otherwise, clip with a 12 pt fade at the tab's end.
   - The full name always appears in the inspector.
6. **Naming:** the catalog's display names win everywhere, on the pad, in the picker and in the inspector. If the catalog says "Play / Pause", BRIEF's "Play/Pause" examples follow it. Pick one in the catalog, and the UI never re-spells it.
