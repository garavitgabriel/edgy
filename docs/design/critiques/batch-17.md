# Batch 17 critique (glyph, popover, popover states)

Verdict: the glyph sheet is right. All seven states have the correct shape: the Test Mode dot is 3.2 pt (`r 1.6`), Paused has two dashes, Disabled and No trackpad sit at 40%, and No Accessibility and broken config show the exclamation. It matches in light and dark. In the popover, the list order and shortcuts are exact. The Paused, Disabled, No trackpad and No Accessibility forms follow § System states word for word. The "Don't run actions" checkbox appears only in Test Mode, indented 24 pt. Type never drops below 13, and nothing on the kill list shows up. Not ready: when an app's chip is live, the mini mirror still draws Default's zones. Two parts of bone 10's live top half can't be checked from these shots. Fix the 3 must-fix items and re-shoot.

## Must fix

1. **The mini mirror ignores the live profile.** Shots: `popover-app-chip-live-*`. Wayfare's chip is filled and comes first, but the mirror is the same as in `popover-normal-*`. The left edge is a solid bar and the bottom-right corner is dashed. The fixture turns the left edge off in Wayfare and adds an app-only hold on the bottom-right corner, so the edge should be a hairline and the corner a solid tile. BRIEF bone 10: "a live mini mirror (zones of the active profile …)". Cause: `MenuPopoverView.swift:72` builds `MiniMirrorView(model: model)`, which reads `NSWorkspace` itself, while the chips read `state.frontmostBundleID`. Fix: pass `MiniMirrorView(model: model, frontmostApp: state.frontmostBundleID)` so the chips and the mirror share one source of truth, and re-shoot.
2. **No shot shows the last touch.** Shots: every popover shot has an empty slab. BRIEF bone 10: "zones of the active profile plus the last touch where it landed". `MiniMirrorView` keeps `lastTouches`, but nothing exercises it. Fix: add a `popover-last-touch` shot. Call `model.simulate` with a touch on the right edge, lift it, and capture. The filled accent contact should stay where it landed.
3. **No shot shows `actionUnavailable` in the mini mirror.** BRIEF § Issue states: "The popover's mini mirror draws that zone as unmapped." Fix: add a shot with one binding set to an action that's unavailable on this Mac (for example keyboard backlight on the external-pad fixture). That zone must draw as a hairline in the mini mirror, not as a bar.

## Should fix

1. **The popover is about 1.5× the render's width.** Shots: all popovers are 448 pt wide (`PopoverMetrics.width` = 160 mm × 2.6 pt/mm + 32), with a 416 pt mirror. Render E's popover is about 300 pt wide, with a mirror of about 290 pt. A 448 × 606 pt panel is heavy for a menu-bar extra. Fix: set `miniMirrorPointsPerMM` to about 1.8, which gives a 288 pt mirror and a popover of about 320 pt. That stays above the 200 pt threshold, so the corner icons can stay.
2. **The broken-config copy names the line twice.** Shots: `popover-broken-config-*` read "config.json has an error on line 14: Unexpected character 'x' around line 14, column 3." BRIEF: "config.json has an error on line 14: <parser message>." Copy voice: "Plain, specific and measured." Fix: strip the parser's own "around line N, column M" when composing `ConfigProblem`, or fold the column into the lead ("on line 14, column 3: Unexpected character ‘x’").
3. **Straight quotes again.** Shots: "Don't run actions" in `popover-test-mode*` and 'x' in `popover-broken-config-*`. This is the same rule as the batch-16 should-fix: typographic ’ and ‘ ’ in every shipped string. Fix: change it to "Don’t run actions" and quote the parser token with ‘ ’.
4. **App marks don't show on the chips.** Shots: Wayfare's chip has no mark in any shot. Render E has a small monochrome mark on every app chip, the same marks as the window tabs (BRIEF § Surfaces: "per-app tabs with small monochrome app marks"). `ChipView` already draws `AppMark(path:)`. The snapshot's `state.installedApps` is probably empty. Fix: give the shot a fixture app list with real icon paths, and confirm a mark appears before "Wayfare". Huddle keeps its slashed circle.
5. **The switch labels are semibold.** Shots: "Enabled" and "Test Mode" are semibold in every shot. Render E sets them in the list rows' weight, and semibold here pulls the eye from the live chip. Fix: use regular 13 `ink`.
6. **No shot shows a combination of states.** BRIEF: "The glyph shows the top one only", and broken config sits "above No Accessibility". Fix: add two shots, Paused plus Test Mode (Paused glyph, no dot) and No Accessibility plus broken config (which popover block wins).

## Matches BRIEF

- Glyph: 16 × 11 template, every state shape correct, 40% for Disabled and No trackpad, light and dark parity.
- List: Pause for 1 hour, Settings… ⌘,, Open config file, Reload config ⌘R, separator, About Edgy, Quit Edgy ⌘Q. Shortcuts are in `ink2`.
- Paused: "Paused, 47 min left" with **Resume** under the mirror, and the Pause row is hidden.
- Disabled: the mirror is at 40%, the Enabled switch is off, and there's no extra line.
- No trackpad: a dashed pad at 160:115 with "No trackpad connected" inside.
- No Accessibility: the top half is replaced by an info icon, the exact sentence, **Open Settings**, and "Touches still show in Test Mode." in `ink2`. The list is unchanged.
- Broken config: error icon with `ink` text, then **Open config file** and **Reload**.
- Chips: the live chip is filled and the others are outlined. The frontmost app's chip comes first (Wayfare, Default, Huddle). Clicking a chip opens Settings (`.help` "Open … in Settings"). Nothing selects.
- One hue, type ≥13, mirror corner icons kept at this size. No power button, hero numeral or cards on cards.

## Questions for design

1. **System highlight versus one hue.** BRIEF says "a plain list with the system highlight". The build uses an `ink` wash at 10% instead, reasoning that the system highlight is the blue selection that § Tokens forbids and is not system-drawn chrome here. Which wins? No shot shows a hovered row either way.
2. **No Accessibility and broken config hide the chips and switches.** The build replaces the whole top half, as render S5 does. But "Touches still show in Test Mode." points at a switch that isn't there. Should the Enabled and Test Mode rows stay under the block in both states?
3. **Paused fades the mini mirror**, though less than Disabled does. The popover column of § System states doesn't say to fade it (the window column says 40%), but render S5 shows it faded. Keep the fade, and should it be 40% to match the window?
4. **Glyph "CI" at 16 pt (G1, known open):** the sheet shows the 16 pt tiles in light and dark. The outline and bar still read as two letterforms; left for the device check.

## Design answers (chief, 2026-11-07)
1. **List highlight:** the `ink` wash at 10% is right, and one hue wins. A popover we draw ourselves is not system-drawn chrome, and the user's system accent can be any colour. BRIEF bone 10 is reworded to say "an `ink` hover wash (10%)" instead of "the system highlight".
2. **No Accessibility and broken config:** the block replaces the mini mirror and chips only. **The Enabled and Test Mode rows stay** under the block in both states, so "Touches still show in Test Mode." points at a real switch.
3. **Paused:** keep the fade, at **40%**, the same as the window and Disabled. One value everywhere.
4. **Glyph "CI":** with the owner for the G1 device check now. The glyph is live in his menu bar.
