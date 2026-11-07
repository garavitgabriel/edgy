# Batch 22 critique (icons, picker, split, identity, mini mirror)

Verdict: **ready to sign off on the window and the popover once one must-fix lands.** The icons match S11 (and CI diffs them against the SVGs). The picker, the Split control, the title-bar identity, the quiet Advanced button and the bone-10 mini mirror match BRIEF, and the gesture icons follow the edge. Every sampled pixel lands on its token, and dark matches light. All 7 batch-20 NOT SHOT items are now shot and exact. The one blocker: on most tabs and chips, the app mark is still a near-white generic square. The rest is spacing and fixture hygiene. Real app icons, the title-bar centring against real traffic lights, and hover feel stay G1 device checks.

## Carried items: status

All shot names omit `-light`/`-dark`. b22 = `batch-22/`, b21 = `batch-21/` (re-shot at HEAD).

| # | Item | Status | Evidence |
|---|---|---|---|
| 14 M2 | Corner tabs pinch | FIXED | b21 `window-default`, b22 `window-picker-left-edge`: tab tucks under the tile |
| 14 S3 / 15 S3 | Catalog spelling | FIXED | "Play/Pause", "Keyboard Backlight On/Off" in every re-shot file |
| 14 S4 | Long tab label | FIXED | `batch-14/pad-split-bottom4-long-label`: "⌘ Left Arrow, Nex" with fade, no "…" |
| 15 M2 | Path editor | FIXED | `batch-15/param-path`: whole field, bordered "Choose…" |
| 15 M3 | "Do nothing here" | FIXED | b22 `picker-app-tab-do-nothing`: last, after a separator |
| 15 S2 | Hold Keys timing | FIXED | b22 `inspector-hold-keys-open` |
| 15 S4 | Title-case labels | FIXED | `batch-15/param-shortcut` "Shortcut name"; `param-path` "File or folder" |
| 15 S5 | Label low in two-line rows | FIXED | `batch-15/param-url-error`, `param-recorder-error`: label on the field's row |
| 15 S6 | Recorder demo | FIXED | `param-recorder-error`: "⌘" alone |
| 15 S7 | Chevron while searching | FIXED | b22 `picker-searched-disclosure`: points down |
| 15 S8 | Extra "The" | FIXED | `batch-15/inspector-overlap-warning`: "Whole edge and upper half both use Slide." |
| 16 M4 | App marks | PARTIAL | Fallback works (`batch-17/popover-no-trackpad`, #6B4A3B); elsewhere a pale generic square (New must fix 1) |
| 16 M5 | Overlap line placement | FIXED | `batch-16/issue-overlapping-zones`: under Split, warning icon, `ink2` |
| 16 S1 | Read-only incomplete | PARTIAL | b21 `issue-broken-config`: footer and tab labels go `ink2` (#6D4C3D), but the "Enabled" label stays `ink` (#3F251D) |
| 17 M2 | Mini last touch | FIXED | b21 `popover-last-touch`: right-edge contact, accent border |
| 17 M3 | Unavailable in the mini | FIXED | b21 `popover-unavailable-unmapped`, b22 `mini-unavailable-zone`: hairline, no icon |
| 17 S4 | Chip marks | PARTIAL | Same as 16 M4 (b21 `popover-normal`) |
| 17 A1 | Hover wash | FIXED | b22 `popover-menu-hover-wash`: #E7D3C4 = `ink` 10% (see Should fix 6) |
| 21 New M1 | Action name cut | FIXED | b21 `tab-wayfare`: name whole, **Revert** on the sub-line |
| 21 New M2 | Mini draws no last touch | FIXED | b21 `popover-last-touch` |
| 21 New M3 | Mixed builds | FIXED | One spelling across batches 14–17, 21 and 22 |
| 21 S1 | Whole label column stacks | FIXED | Ruled correct; b21 `inspector-long-labels` |
| 21 S2 | Helper lines crowd the next row | PARTIAL | Slider helpers have 8 pt after them. Checkbox helpers don't (see Should fix 1). |
| 21 S3 | Huddle chip mark | FIXED | b21 `popover-normal`: "[mark] Huddle ⊘" |
| 21 S4 | Strip buttons centred | FIXED | b21 `issue-broken-config`: buttons on the first line |
| 21 S5 | Pointer touch shot | FIXED | b21 `pad-pointer-touch-hidden`: zone contact only |
| 21 S6 | G1 shots | FIXED | `batch-17/popover-no-accessibility`, `-no-trackpad`, `batch-14/mini-huddle-off`, `batch-16/state-no-accessibility` |
| 21 DA4 | Selection opens nothing | FIXED | b21 `window-default`: collapsed |
| 20 NS | Repeat Keys `stepMM`/`speedUp` | FIXED | b22 `inspector-repeat-keys-open`: copy exact, unchecked, no Sensitivity |
| 20 NS | Hold Keys `holdMS` | FIXED | `inspector-hold-keys-open`: "300 ms" `ink2` (#725243) |
| 20 NS | "Press time" Default/Reset | FIXED | `inspector-press-time-default` / `-changed`: "Default (500 ms)" `ink2`; "800 ms" `ink`, **Reset** |
| 20 NS | `maxSeconds` | FIXED | "Let go after", "120 s", helper exact |
| 20 NS | `keepOpenMS` "Off" | FIXED | `inspector-switch-apps-keep-open-off` |
| 20 NS | Changed value in `ink` | FIXED | same shot: "12 mm" and "Off" #3F261C |
| 20 NS | Slide + swipes note | FIXED | `inspector-slide-and-swipes-note`: copy exact, info icon `ink2`, fix in `ink` |

**Totals:** 31 FIXED, 4 PARTIAL, 0 OPEN, 0 NOT SHOT.

## New must fix

1. **App marks fall back only when the path is missing.** `AppMark.hasIcon` (`Window/WindowParts.swift:166`) checks only `fileExists`. Any bundle without its own icon gets NSWorkspace's generic icon, desaturated: a pale square on every tab and chip (b22 `window-*`, b21 `tab-wayfare`, `popover-normal`, light and dark). That is the kill list's "generic coloured squares", and design answer 21-3 asks for the Open App tile instead. Fix: treat a bundle with no `CFBundleIconFile`/`CFBundleIconName` (or the system's generic application icon) as having no icon. Give the fixtures one real-icon app and one iconless bundle.

## New should fix

1. **Checkbox helpers have no space after them, and they start at the box.** `inspector-switch-apps-keep-open-off`: "A quick flick skips several apps." is 7.5 pt above "Keep open between strokes". Slider helpers get about 18 pt. It's the same in `inspector-repeat-keys-open` and b21 `inspector-long-labels`. The helper also starts at the checkbox's x (46 pt), not the label's (67 pt); batch-20 S2 is still open. Fix: add 8 pt after every helper, and indent checkbox helpers to the label.
2. **The split preview's divider cuts through the label.** `window-split-hover-bottom`: "Tracks and | Play/Pause". Fix: draw the bar's label above the dividers, or fade it while previewing.
3. **The picker list is cut to a sliver at its bottom edge.** `window-picker-left-edge`: only the tops of the disclosure row's glyphs show. Fix: give the list a bottom inset equal to its top, or a 12 pt fade at the scroll edge.
4. **Read-only "Enabled" label.** Use the `ink2` rule the footer and tabs already use.
5. **The mini contact covers the edge icon.** In b21 `popover-last-touch`, the contact sits on the Volume icon. BRIEF: "The live zone keeps its icon." Fix: keep the icon readable, for example by drawing it above the contact or shifting it clear of the contact.
6. **Two fixtures don't use shipping code.**
   - `popover-menu-hover-wash` iterates `MenuRow.allCases`, so it shows "Open config file" and "Reload config ⌘R", which BRIEF removed. The real list (`popover-normal`) is right.
   - `strip-broken-config-wrapped` has a straight 'x', no "…" on Replace, and no button bezels, unlike the window (`issue-broken-config`: ‘x’, "Replace with current settings…").

   Fix: build both shots from the real views (`MenuRow.visible`, the window strip).
7. **Not shot:** two stacked icons on a side edge in the mini, and the horizontal slide icon in the top/bottom "Add gesture…" list.

## Matches BRIEF

- **Icons:** `icon-sheet` matches S11 glyph for glyph (34 actions, Do nothing here, Advanced). Keyboard Brightness and Backlight On/Off share one drawing, per the README. There are no stock symbols left.
- **Picker:**
  - Rows are 28 and 44 pt, with the sub-line under the name. Names and the checkmark are `ink` (#3D241B). Unavailable rows are `ink2` (#6B4A3B; dark #D9BFAE).
  - Headers are 11 semibold `ink2` with about 14 pt above, none first, and no separators. Search keeps only matching headers; empty: “No actions match “xyz”.”
  - It opens scrolled to the bound row. Side-edge placement clears the tiles, their tabs and its own tab.
- **Split:**
  - Diagrams are `ink` #3B2219 selected and `line` #8E6B58 unselected, with no numbers. Preview dividers are #896852, exactly `ink` at 50% over `bar`.
  - The note uses the info icon in `ink2`; the 13 semibold `ink2` segment headings match.
- **Identity:** an 18 pt icon, then "Edgy" in `ink`, about 8 pt apart. **Advanced:** `ink2` with no bezel; on hover, `ink` over the 10% wash.
- **Mini mirror:** icons are 10 pt `ink`; two in gesture order; one set per split segment; unavailable draws unmapped. The hover line is 13 `ink2` (#6B4A3C), faded, with its height reserved.
- **Gesture icons:** ↔ on top and bottom, ↕ on the sides. **Parameters:** Sensitivity is hidden under `stepMM`, `speedUp` is off for Switch Apps and Repeat Keys, and all batch-20 copy is exact.

## Questions for design

1. BRIEF's own hover example, "Bottom edge: Previous Track, Next Track, Play/Pause", doesn't fit the 288 pt mirror width and clips at "Play/P" (`mini-hover-line`). Should the line use the popover's full content width, shorten the zone name ("Bottom:"), or is clipping the intended answer?
2. Within a group the picker sorts alphabetically: Microphone Mute, Mute, Volume; Next Track, Play/Pause, Previous Track. S9 and BRIEF's icon table read Volume, Mute, Microphone Mute and play-pause, skip-forward, skip-back. Which order should ship?
3. SplitPlan copies the binding to every part, so the note says "All three thirds keep Volume." and the user ends up with three identical slides. Is copy-on-split the intended behaviour? BRIEF's example ("Upper half keeps Volume; lower half starts empty.") implies one part keeps it.
4. The disclosure copy now names every missing gesture. A slide slot reads "28 more need a tap, swipe or long-press", against BRIEF's "6 more need a slide". Accept the dynamic list?

## Design answers (chief, 2026-11-07)
1. **Mini-mirror hover line overflow:** use the popover's full content width, and **shorten the zone name** ("Bottom:", "Left:", "Top-left:", "Right, upper:"). If it still doesn't fit, use the pad-tab short action names (bone 3); clip with the 12 pt fade only as the last resort. So "Bottom: Previous Track, Next Track, Play/Pause" fits.
2. **Picker order within a group:** **not alphabetical.** Ship BRIEF's icon-table order (most-used first): Sound = Volume, Mute, Microphone Mute; Display = Brightness, Keyboard Brightness, Keyboard Backlight On/Off; Media = Play/Pause, Next Track, Previous Track; the rest in table order. Search results keep the same order.
3. **Split behaviour:** **the first part keeps the bindings; the other parts start empty.** That's top or upper for side edges, left for top/bottom. Copying a slide to every part leaves three identical slides, which is never what someone splitting an edge wants. The note follows: "Upper third keeps Volume; the other two start empty." Going back to fewer parts keeps the first part's bindings and drops the rest, and the note says so before the click. It's one undo step either way. This is a SplitPlan change, the build chief's call to schedule; BRIEF is updated.
4. **Dynamic disclosure copy:** accepted ("28 more need a tap, swipe or long-press"). It names the gestures that DO fit those actions, which is the useful part.

The must-fix stands: an app with no icon of its own gets the Open App tile in `ink2`, never the system's generic icon.
