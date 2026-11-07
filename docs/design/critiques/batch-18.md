# Batch 18 critique (plates, Test Mode overlay, level plate, display check)

Verdict: the copy is right. All 16 rejection strings, the five dry-run lines, the three hold lines, the level plates and the display check match BRIEF character for character. Numbers follow the decimal rule. Nothing reads "started outside a zone", and there's no "Test mode" pill. The marks are right too: a filled 26 pt accent contact, a 2 pt accent ring with no fill for dry run (measured 4 px at 2×), and a hollow struck circle in `ink2` for rejections. Text contrast holds (`ink2` on the plate is about 7.7:1). Not ready: the level plate and display check sit on top of the document's text, the "one plate component" renders in two different appearances, and dry-run suppression and all the timings have no evidence. Fix the 3 items below and re-shoot.

## Must fix

1. **The level plate and display check cover the text being worked on.** Shots: `overlay-docked-level-check-*`. "Brightness 40%" runs about 110 px into the document window, and "Did this screen change brightness?" sits across body lines 6 to 9. BRIEF bone 9: "never sits over the text being worked on", and each plate is "docked to the screen edge or corner of the touched zone and fully on-screen". Render S8 keeps both plates in the gutter, clear of the window. Fix: stack the display check **beside the level plate along the docked edge** (below it, or outward), not inward toward the screen centre. Avoid the focused text element's AX frame, and shift along the edge before ever covering text.
2. **The plate renders in two appearances.** Shot `plate-component-light` draws a pale plate (`#FBE7D8`) with `ink` text. Every other `-light` plate shot is byte-identical to its `-dark` twin (a dark plate, `#3B2D27`), and `overlay-docked-*-light` also uses dark plates. BRIEF bone 9: "**One plate component** is shared by the overlay and the onboarding feedback: same radius, same 17/13 type pair, same inset. In the render, C and D look like two products; don't build that." Fix: give the plate one material rule, read in one place (see Q1), and make all shots go through it. Then check the capture harness: the identical light and dark pairs mean the `-dark` plate shots never switched appearance.
3. **Dry-run suppression and the timings aren't shown.** No shot shows a brightness or keyboard slide in dry run, and nothing shows the fades or the ask limit. BRIEF § Test Mode: "What dry run doesn't show: the level plate for external brightness or the keyboard, and the system HUD." § Level plate: "fades 1.2 s after the slide ends", "shows whether or not Test Mode is on". § Display check: "fades after 15 s and asks again next time, at most 3 times". § Hold: "'Released fn' for 0.6 s, then the plate fades out over 200 ms". Fix: add `overlay-dryrun-brightness-*` (only a "Would set Brightness" plate, with no level plate). Add a level-plate shot with Test Mode off. Add a unit test or a timing log for the 1.2 s, 15 s, 0.6 s + 200 ms and 3-ask values.

## Should fix

1. **The Volume plate overlaps the document window.** Shots: `overlay-docked-test-mode-*`. The plate starts about 28 px inside the window's right edge. It covers no text, so it's legal, but it reads as attached to the window. BRIEF bone 9: "never sits over the text being worked on". Fix: where the plate can't clear the window, keep it at least 8 pt away from the window edge, or slide it along the edge into empty space.
2. **The overlay shots crop the menu bar.** Shots: `overlay-docked-*`. Bone 8 ("Drop the 'Test mode' pill shown in render D") passes only because nothing is shown. BRIEF: "the menu glyph's dot is the only 'test mode is on' marker." Fix: capture with the menu-bar strip and the glyph dot visible.
3. **The overlays don't show a dark document.** Shots: `overlay-docked-*-dark` change the desktop but keep a white document. Bone 9: "readable over light and dark documents." The isolated plate shots do cover black and white, so this is evidence only. Fix: add one overlay over a dark document.

## Matches BRIEF

- Rejection copy table: every row exact, including "Ignored: 2 fingers, set to 1", "swipe veered, 9 mm across, 5 mm along" and "swipe too short, 4 mm, needs 6 mm". Decimals only on 3.4 and 2.8 and 2.5, and whole numbers elsewhere. Unit-none reasons stop after the reason ("Ignored: click", "Ignored: palm", "Ignored: system gesture").
- Recognized is louder: a solid 26 pt accent contact plus a 17 semibold value line, against a struck `ink2` circle with one 13 pt line.
- Dry run: "Would set Volume" / "Right edge, slide", "Would run Play/Pause" / "Bottom edge, double-tap", "Would open Quillpad" / "Bottom-right corner, double-tap", "Would hold fn" and "Would release fn" / "Bottom edge, long-press". No level appears on any "Would" line. "Play/Pause" is spelled as the catalog spells it.
- Hold: "Holding fn", "Released fn" and "Released fn, finger left the zone", each with a static filled contact and no glow.
- Level plate: "Brightness 40%" / "Desk 34" and "Keyboard 60%" / "Keyboard", with a slim accent bar on a neutral track and no contact icon.
- Display check: "Did this screen change brightness?" with **Yes** and **No, turn off for this display** as `ink`-wash buttons, with no accent on the buttons. It's the only plate with controls.
- One hue: the accent appears only on contacts and the level fill.
- Plates are docked at the touched edge, fully on screen, with no pill.
- "Keyboard Backlight On/Off" has no plate this batch, so its spelling isn't checked.

## Questions for design

1. **Which appearance does the plate take?** References D and S8 draw a dark plate on a light system. `plate-component-light` draws a light one. I'd keep the plate dark in both appearances (as D and S8 do), because a dark plate over a white document is the higher-contrast case. Confirm, and say whether the onboarding feedback plate follows.
2. **What's the run-mode value line for a trigger?** `plate-run-trigger-*` reads "Play/Pause" alone. BRIEF gives run-mode copy only for continuous actions ("Volume 64%"). Is the bare catalog name right, or should it read "Ran Play/Pause"? I'd keep the bare name, since dry run's "Would" already marks the difference.
3. **Is the display check exempt from the 17/13 pair?** Its question is 13 semibold, with no 17 line, as in S8. I'd accept that for the one clickable plate. Please confirm.
4. **Is the accent contact's contrast enough?** On the plate, the accent fill and the 2 pt ring measure about 2.6:1, under the 3:1 BRIEF asks of `line`. Shape and size carry the meaning, so I'd accept it. Confirm, or lighten the plate edge behind the contact.
5. **Should the keyboard plate repeat itself?** "Keyboard 60%" / "Keyboard" says "Keyboard" twice. That's BRIEF word for word. Keep it, or name the device ("Built-in keyboard")?

## Design answers (chief, 2026-11-07)
1. **Plate appearance:** the plate is **always the dark espresso plate**, in both system appearances, as in D and S8. It's one component, and a dark plate is the high-contrast case over light documents. Over dark documents it gets a 0.5 pt light edge (`rgba(255,230,210,.24)`) so it still separates. The onboarding feedback plate follows (bone 9: one component). `plate-component-light`'s pale plate is wrong. And the -light/-dark pairs being byte-identical is then correct, apart from the dark-document case.
2. **Run-mode trigger value line:** the bare catalog name ("Play/Pause") is right. "Would" marks dry run; run mode needs no verb.
3. **Display check:** exempt from the 17/13 pair. It's the one clickable plate, and its 13 semibold question is right.
4. **Accent contact on a dark plate (about 2.6:1):** fix it, don't accept it. Give the contact a **1 pt cream rim** (`#FBEADB` at 70%), the same treatment as the app icon's dot. It's a solid thin stroke, not a halo. The dry-run 2 pt ring gets the same rim outside it.
5. **Keyboard plate:** name the device: "Keyboard 60%" / "Built-in keyboard" (or the external keyboard's name). It's the same pattern as the display name.
