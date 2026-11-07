# Batch 16 critique (window shell, tabs, footer, app-profile flows, window states, Advanced)

Verdict: the shell is structurally right. There's no sidebar, tabs are top centre, the top-right switch follows the tab, the footer matches, and the window is 1013×650. Most copy is exact, there's no second hue, dark matches light, and text contrast holds (`ink2` is about 6.5:1 light, 9:1 dark). Not ready: in three system states the mirror is swapped out or untouched instead of faded, and the app marks are missing. Fix the 7 items below and re-shoot.

## Must fix

1. **Paused and app-off replace the mirror instead of fading it.** Shots: `state-paused-*`, `tab-huddle-off-*`. The `PadMirrorView` stub disappears and only the line is left. BRIEF, Paused: "The mirror fades to 40%, with one line centred on the pad." App off: "The mirror fades to 40% with every zone as a hairline. One line is centred on the pad." Fix: keep the mirror mounted at `.opacity(0.4)` and overlay the line plus its text button on top. Pass an `appOff` flag so the mirror draws hairlines.
2. **No trackpad shows nothing.** Shots: `state-no-trackpad-*` are pixel-identical to `window-default-*`. BRIEF: "The mirror becomes the same dashed outline, with 'Connect a trackpad to see it here.' Bindings stay editable." Fix: the shell must pass the no-trackpad state to the mirror. The shell shows the line, as it does for Paused.
3. **Disabled doesn't fade the mirror.** Shots: `state-disabled-*`. Only the switch changes; the stub label stays at full opacity. BRIEF: "The Default tab's Enabled switch is off and the mirror fades to 40%. Editing still works." Fix: apply 0.4 opacity to the mirror container when global Enabled is off, and keep hit-testing on.
4. **App marks are missing.** Shots: every window shot (tabs) and `add-app-step1-*` (rows). BRIEF: "app tabs alphabetically (app mark + name)" and "per-app tabs with small monochrome app marks". Add-app: "Rows show the real app icon and name." Fix: put a 16 pt monochrome template mark before each app tab's name. On Huddle, the slashed circle stays as the trailing mark. Add rows get the real 16 pt app icon, leading.
5. **The overlap warning is in the wrong place.** Shots: `issue-overlapping-zones-*`. It's a banner pinned to the top of the inspector, above everything. BRIEF: "one line under the split control: 'Upper and lower halves both use Swipe up.' · **Show**". Fix: hand the issue to the inspector and render it directly under "Split into". Keep the warning icon and `ink2`.
6. **The broken-config strip has a button the window shouldn't have.** Shots: `issue-broken-config-*` include **Reload**. BRIEF gives Reload to the popover only. The window gets "**Open config file** and **Replace with current settings**". Fix: drop Reload from the window strip. That also stops the sentence wrapping onto two lines at 1013 pt.
7. **The picker isn't in the picker shots.** Shots: `window-picker-*` are identical to `window-default-*`. Its anchoring and size limits (420 pt wide, mirror height − 16 pt) can't be checked. Fix: re-shoot with the popover open on a zone. A stub anchor rect is enough.

## Should fix

1. **Read-only isn't complete.** Shots: `issue-broken-config-*`. HUD, Advanced… and "+" are disabled, but Haptics and Enabled still look interactive. BRIEF: "The window is read-only while the file is broken." Fix: disable every control that writes config. See Q3 for Launch at login.
2. **Straight apostrophes.** Shots: `legacy-note-*` ("doesn't") and `add-app-step2-*` ("what's"). Render S2 uses ’. Fix: use typographic apostrophes in every shipped string.
3. **The add-app step 2 header has no icon.** Shot: `add-app-step2-*` shows "Quillpad" with no icon; render S2 has one. Fix: show the 16 pt app icon before the name, the same as the step 1 row.
4. **The footer switch order is reversed.** Shots: every window shot read "Haptics [switch]". Renders A, B and S1 put the switch first: "[switch] Haptics", "[switch] Launch at login". Fix: switch first, to match the renders.
5. **There's a near-invisible plate behind the centred state lines.** Shots: `state-paused-*` and `tab-huddle-off-*` show a faint rectangle around the text. BRIEF says "one line centred on the pad", with no container. Fix: drop the plate. The faded pad gives the contrast.

## Matches BRIEF

- Tab order Default, A–Z, "+"; Huddle-off in `ink2` with a slashed circle.
- Top-right switch: "Enabled" on Default, "On in <app>" on app tabs.
- App-off: "Edgy is off in Huddle" · **Turn on**, with the inspector empty.
- No Accessibility strip: full width, info icon in `ink`, copy exact.
- Broken config: error icon with `ink` text, and "Replace with current settings…" (a sheet follows).
- Legacy note: info icon in `ink2`, copy exact, **Follow Default** with its `ink2` sub-line.
- Add-app: both sections and "Has a profile". Step 2 copy is exact, with the first option preselected, then Back and Add.
- Advanced: out-of-range is a warning icon plus `ink2`. Primary buttons are `ink`, not accent.
- Type: nothing under 13, section headers 13 semibold (no micro-caps), "8 mm".

## Questions for design

1. **No title bar or traffic lights appear in any shot.** Is that the headless capture, or a missing toolbar row? The renders put the tabs inline with the traffic lights. This is acceptable only if the real window keeps them.
2. **Advanced value colour.** Every value is `ink`, including defaults. BRIEF's rule ("a slider set to its default shows the value in `ink2`") is scoped to binding parameters. Should Advanced follow it? I'd say yes, for consistency.
3. **Launch at login while the config is broken.** This is probably a system login item, not config. If so, leaving it live is correct. Confirm.
4. **The out-of-range warning says "using 20 mm" where BRIEF's example says 30 mm, and it sits under the slider rather than beside it.** 20 is the slider's real maximum, so I accept it. Placing it under the slider matches the validation rule. Update BRIEF's example.
5. **The overlap copy reads "Whole edge and upper half"**, which mixes split levels. If the runtime can report that, the copy pattern holds. Otherwise, check the demo data.

## Design answers (chief, 2026-11-07)
1. **No title bar or traffic lights in the shots.** The real window uses the standard system title bar and window controls. The system-drawn window buttons are **exempt from the one-hue rule**: don't recolour or fake them. The renders drew them neutral only because a mockup can't show the system's. (Added to BRIEF tokens.)
2. **Advanced defaults:** yes. A value at its default shows in `ink2`; a changed value shows in `ink` (the same rule as § Binding parameters, batch 20).
3. **Launch at login while the config is broken:** read-only like everything else in the window. One rule, no exceptions.
4. **Out-of-range example number:** BRIEF's "30 mm" is an example; show the real clamped value. 20 mm is fine.
5. **Overlap copy "Whole edge and upper half both use Swipe up.":** acceptable. The pattern is "<part> and <part> both use <gesture>."

**Should-fix revisions:**
- **Footer label before the switch:** drop this item. The native order (label, then switch) wins over the render.
- **Faint plate behind the centred state lines on a faded mirror:** acceptable for legibility, if it's the plate component at low opacity and not a new card.
