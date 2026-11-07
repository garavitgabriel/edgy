# Batch 21 critique (final integration check)

Verdict: **ready for the owner's device check, not for sign-off.** The shell, the four system states, the app tabs, the picker and the popover layout match BRIEF. Sign-off is blocked by three things:
- the inspector cuts an action name with "…"
- the popover's last touch never draws
- the shot set mixes two builds, so the catalog spelling can't be confirmed

Corner tabs still pinch at the tile corner. Switch states, real app marks, the touch filter and slab depth can only be judged on the device (G1).

## Earlier findings: status

Shot names omit `-light`/`-dark`. 16 S4 (footer order) was dropped by ruling and isn't listed.

| # | Item | Status | Evidence |
|---|---|---|---|
| 14 M1 | Slab depth upside down / dark halo | FIXED | `window-default`, `pad-pointer-touch-hidden`: soft edge below, no ring in dark |
| 14 M2 | Corner tabs float | PARTIAL | `window-default-dark` "Mic off", `tab-wayfare` "Hold Keys": same fill, but tile and tab meet corner-to-corner with about 2 pt of overlap and a visible notch. Render A tucks the tab's top edge under the tile. |
| 14 M3 | Live tab keeps idle fill | FIXED | `window-live-right`: bar and tab share the lit fill and one outline |
| 14 M4 | Params under every binding | FIXED | `window-picker-bottom`: no rows open while picking |
| 14 S1 | Per-layer fade | FIXED | `state-disabled-dark`, `tab-huddle-off` |
| 14 S2 | 33 pt picker rows | FIXED | `window-picker-bottom`: about 25 pt rows, about 9 pt clear of the top bar |
| 14 S3 / 15 S3 | Catalog spelling | PARTIAL | `ActionCatalog.swift:145` says "Play/Pause", but 6 shot pairs still draw "Play / Pause" (see New must fix 3) |
| 14 S4 | Truncated tab "…" | NOT SHOT | No long pad label in batch 21 |
| 14 S5 | Preset corners read as dots; shoot Windows | FIXED | `preset-windows`: mapped corners are rounded squares |
| 14 S6 | Mini at real size, mini-disabled | FIXED | `popover-normal` (288 pt mirror), `popover-disabled` |
| 14 S7 | Wraps, 57 pt inset | FIXED | `window-picker-bottom`: "Previous Track" on one line, inset about 22 pt |
| 14 A1 | "Off here" as a joined tab | FIXED | `tab-wayfare` left edge |
| 14 A4 | Pending row while picking | FIXED | `window-picker-bottom`: "Tap" with a blank value |
| 15 M1 | One open binding | FIXED | `window-picker-bottom`, `tab-wayfare`, `window-live-right` (see Q4) |
| 15 M2 | Path editor | NOT SHOT | |
| 15 M3 | "Do nothing here" | NOT SHOT | |
| 15 S1 | Keep-open helper | FIXED | `inspector-long-labels` |
| 15 S2 | Hold Keys timing row | NOT SHOT | |
| 15 S4 | Title-case labels | NOT SHOT | |
| 15 S5 | Label low in two-line rows | NOT SHOT | |
| 15 S6 | Recorder error demo | NOT SHOT | |
| 15 S7 | Chevron while searching | NOT SHOT | |
| 15 S8 | Extra "The" | NOT SHOT | |
| 15 S9 | App list empty row, 13 pt headers | FIXED | `add-app-step1` |
| 15 S10 | Slider tracks misaligned | FIXED | `inspector-long-labels`: every track starts at the same x |
| 15 A1 | Split hidden on app tabs | FIXED | `tab-wayfare` |
| 16 M1 | Paused / app-off swap the mirror | FIXED | `state-paused`, `tab-huddle-off` |
| 16 M2 | No trackpad shows nothing | FIXED | `state-no-trackpad`: dashed outline, exact copy |
| 16 M3 | Disabled doesn't fade | FIXED | `state-disabled` (bar #ECD2BC vs #D9AE8C) |
| 16 M4 | App marks missing | PARTIAL | Marks are present, but they're the generic app icon desaturated. In dark (`window-default-dark`) it's a bright white square. See Q3. |
| 16 M5 | Overlap line placement | NOT SHOT | |
| 16 M6 | Reload in the window strip | FIXED | `issue-broken-config` |
| 16 M7 | Picker missing from shot | FIXED | `window-picker-bottom` |
| 16 S1 | Read-only incomplete | PARTIAL | `issue-broken-config`: Split, "+", HUD, Advanced… and Add gesture… are dimmed. Haptics, Launch at login and the tab labels stay full `ink`. Switches can't be judged headless. |
| 16 S2 | Straight apostrophes | FIXED | `add-app-step2` "what’s" |
| 16 S3 | Step-2 icon | FIXED | `add-app-step2` |
| 16 S5 | Plate behind state lines | FIXED | `state-paused` |
| 16 A2 | Advanced defaults in `ink2` | FIXED | `advanced-light`: values #6F4E40 |
| 17 M1 | Mini ignores live profile | FIXED | `popover-app-chip-live`: left edge hairline, bottom-right tile solid |
| 17 M2 | Last touch | OPEN | `popover-last-touch` is pixel-identical to `popover-normal`: no contact |
| 17 M3 | `actionUnavailable` in the mini | OPEN | `popover-unavailable-unmapped` is pixel-identical to `popover-normal`. The fixture's zone (bottom-left) is already pass-through, so nothing can change. |
| 17 S1 | Popover width | FIXED | 320 pt |
| 17 S2 | Line named twice | FIXED | `popover-no-access-broken-config`: "on line 14, column 3:" |
| 17 S3 | Straight quotes | FIXED | "Don’t run actions", ‘x’ |
| 17 S4 | Chip marks | PARTIAL | Same generic icon as 16 M4 |
| 17 S5 | Semibold switch labels | FIXED | `popover-normal` |
| 17 S6 | Combination shots | FIXED | `popover-paused-test-mode`, `popover-no-access-broken-config` (broken wins) |
| 17 A1 | `ink` 10% hover wash | NOT SHOT | |
| 17 A2 | Rows stay under blocks | FIXED | `popover-no-access-broken-config` |
| 17 A3 | Paused fades to 40% | FIXED | `popover-paused-test-mode`: bar #EDCFB6, the same as `popover-disabled` |

**Totals:** 32 FIXED, 2 OPEN, 6 PARTIAL, 11 NOT SHOT. The builder cites re-shot batch-15/16 files for most NOT SHOT items; they weren't reviewed here.

## New must fix

1. **The inspector cuts an action name with "…".** Shot: `tab-wayfare`, Swipe left row: "• Keyboard Short… **Revert**". This came from the follow-up commit `c3f552e`, "rows stay on one line". BRIEF: "The full name is always in the inspector." The cut also collides with the "…" that means "needs a parameter" (the picker's "Keyboard Shortcut…"). Fix: the action name never truncates. When the row overflows, move **Revert** to the second line, right-aligned beside "Default: Previous Track". See Q1.
2. **The mini mirror draws no last touch.** Shot: `popover-last-touch` = `popover-normal`, byte for byte. The window still draws a live zone contact (`window-live-right`), so suspect the new `MirrorPad.drawnTouches` filter dropping *lifted* zone touches in the mini. Fix: keep the last recognized zone touch after lift, and re-shoot with a right-edge touch. While there, move 17 M3's unavailable binding onto a mapped zone (for example the right edge) so the hairline shows.
3. **The shot set mixes two builds.** "Tracks and Play / Pause" appears in `window-default`, `window-picker-bottom`, `window-live-right`, `inspector-long-labels`, `pad-pointer-touch-hidden` and `tab-wayfare-light`. "Play/Pause" appears in `tab-wayfare-dark`, `state-*` and `issue-broken-config`. Light and dark of the same tab disagree, and the picker still lists "Keyboard Backlight On / Off". Fix: re-shoot all of batch 21 from HEAD in one run, after a clean build.

## New should fix

1. **The whole label column stacks.** Shot: `inspector-long-labels`. "Sensitivity" goes above its slider though it fits beside it (`window-default`). BRIEF's rule is per label. See Q2.
2. **Helper lines crowd the next row.** Shot: `inspector-long-labels`. "A quick flick skips several apps." sits about 4 pt above "Keep open between strokes". Fix: add 8 pt after each helper line.
3. **The Huddle chip drops its mark.** Shot: `popover-normal`. It reads "⊘ Huddle"; the tab reads "[mark] Huddle ⊘". Fix: match the tab.
4. **The broken-config strip still wraps to two lines,** with its buttons centred on both. Fix: top-align the buttons.
5. **`pad-pointer-touch-hidden` is identical to an idle pad.** Fix: put a mid-pad pointer touch and a zone touch in one frame.
6. **Shots missing for G1:**
   - the hover wash
   - the popover's No Accessibility block alone, No trackpad, and the faded mini with Huddle in front
   - the window's No Accessibility strip
   - a long pad label that needs rules (a), (b) and (c)
   - the live border on an unselected zone

## Integrated vs renders A, B, E

- **A (`window-default`):** the layout, tabs, Enabled and footer match, and depth now sits below the slab. The build differs in four ways:
  - the mirror is taller, because it's to scale
  - the corner tabs pinch instead of tucking under the tile
  - the inspector adds row "…" menus and an open binding
  - the app marks are generic icons, not line glyphs
- **B (`window-picker-bottom`):** it anchors to the ringed bar with the arrow, and the pending Tap row is blank rather than "Choosing…" (BRIEF wins). The build is one column with about 25 pt rows against B's about 21 pt, and has no icons yet.
- **E (`popover-normal`):** the width (320 against about 300 pt), the chips and the switch labels match. The config rows are gone (BRIEF wins). The last touch E shows on the right edge is missing.

## Coming in batch 22

Two BRIEF sections land in batch 22, so the current numeric "Split into 1 2 3 4" control and the icon-less picker rows are expected here:
- **Split control:** edge diagrams replace the numbers.
- **Picker clarity:** 16 pt leading icons, 28/44 pt rows and the group rhythm.

## Questions for design

1. When an app-tab row's action name plus "from Default" or **Revert** doesn't fit (`tab-wayfare`: "Keyboard Short…"), which wins: move Revert or the caption to the second line, use rule (a)/(b) short forms in the inspector too ("⌃⌥ Space", "Shortcut"), or wrap the action name?
2. When one parameter label must go above its control, should every label in that binding stack (the build, which keeps the slider tracks aligned) or only that one (BRIEF's per-label wording)?
3. Tabs and chips show each app's icon desaturated. Is that acceptable as BRIEF's "small monochrome app mark", or does it need a template silhouette? In dark the generic icon reads as a bright white square, close to the kill list's "generic coloured squares".
4. Should selecting a zone with a single binding open its parameters (`window-default`) or leave the row collapsed until it's clicked (`window-live-right`, `state-no-trackpad`, `issue-broken-config`), per BRIEF's open rule?

## Design answers (chief, 2026-11-07)
1. **The action name always wins in the inspector.** It's never cut with "…". When the name plus "from Default" or **Revert** doesn't fit on one line, the caption or button moves to the second line: "from Default" becomes the row's sub-line, and **Revert** goes trailing on the "Default: X" sub-line. If the name alone is still too long, it wraps to two lines at a word boundary. The short forms (rule a/b) are for pad tabs only.
2. **Stacked labels:** when one parameter label in a binding must go above its control, **every label in that binding stacks**, so the controls stay aligned. The build is right; BRIEF is updated.
3. **App marks on tabs and chips:** use the real app icon, desaturated, at 14 pt. In dark mode, lower it to 70% opacity so a white icon doesn't glare. **An app with no icon** gets Edgy's own "Open App" tile icon in `ink2`, never a plain white or coloured square (kill list).
4. **Selecting a zone opens nothing by itself.** Rows stay collapsed until clicked; the only exception is a binding with an empty required parameter. `window-default` showing a binding open is a fixture state, not the rule. Re-shoot with everything collapsed.

The new must-fix items stand. In particular, re-shoot all of batch 21 from HEAD so the spelling and build are consistent.
