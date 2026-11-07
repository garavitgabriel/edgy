# Batch 15 critique (inspector, picker at catalog scale, parameter editors)

Verdict: the picker is close to done. It's a single column with a pinned header and search, groups in catalog order, 11 pt group headers only, unavailable actions dimmed with their reason, parameter actions ending in "…", and the shape-mismatch disclosure at the end. It stays inside the pad's interior in both anchored shots, so ruling (b) holds. The parameter controls get the colour roles right. I sampled the pixels: defaults are `ink2`, changed values are `ink`, the recording ring is exactly #B4542B, and held modifiers plus "Press keys…" are `ink2`. Issue lines are told apart by icon and wording, not colour. Dark mode matches light. `ink2` measures about 6.6:1 in light and 9.5:1 in dark. Not ready: ruling (a) is broken in every multi-row shot, the path editor's layout is broken, and "Do nothing here" never appears. Fix the 3 items below and re-shoot.

## Must fix

1. **Parameter rows show under every binding.** Shots: `inspector-bottom-edge-note-*` and `inspector-bottom-edge-picking-*` (all four rows show "Haptics for this gesture"), `inspector-wayfare-sources-*` (Long-press and Swipe left are both expanded, Swipe left with its Keys field), and `inspector-corner-needs-keys-*` (Double-tap and Long-press are both expanded). BRIEF: "The parameter rows, including 'Haptics for this gesture', appear only under the **open** binding… Opening another row closes the first. A binding with an empty required parameter opens automatically." Fix: keep one `openBindingID` in the inspector. Only that row renders its parameter block. Set it on row click, on picker commit, and on load to the first binding whose required parameter is empty. In the corner shot, only Long-press ("Needs keys") should be open, and Double-tap should collapse to "Double-tap · Open App…".
2. **The path editor's layout is broken.** Shots: `param-path-*`. The field is cut off at "~/Documents/No" and "Choose…" wraps onto two lines as "Choos / e…", drawn as loose text rather than a button. BRIEF: "a text field with the placeholder '~/Documents', plus a **Choose…** button". Each parameter "takes one 28 pt row". Fix: make Choose… a fixed-size bordered button that never wraps (`.fixedSize()`). Let the field take the remaining width and truncate the path in the middle so the file name stays visible.
3. **"Do nothing here" is never shown.** Shots: `picker-app-tab-do-nothing-*` are searched for "mi", which filters the row out. BRIEF: "'Do nothing' appears only on app tabs, last, after a separator, labelled 'Do nothing here'." This can't be checked. Fix: re-shoot the app-tab picker with an empty search, scrolled to the end, so the separator and "Do nothing here" are visible below the disclosure row.

## Should fix

1. **"Keep open between strokes" has no helper line.** Shots: `param-presentation-fields-*`. The batch-20 table gives "Lift and slide again to keep going; it picks the app when you stop, click or move the pointer." Fix: always show it, including at "Off".
2. **The Hold Keys timing row is missing.** Shots: `inspector-corner-needs-keys-*`. The table lists `holdMS` for Hold Keys: "Hold before it starts", 100–1500 ms slider, preset 300 ms, helper "How long to press before the keys go down." The build shows "Release after 120 s" instead (see Q2).
3. **Action names have spaced slashes.** Shots: the inspector and picker shots ("Play / Pause", "Keyboard Backlight On / Off"). BRIEF writes "Play/Pause" everywhere. Fix: no spaces around the slash in catalog display names.
4. **Some parameter labels are in title case.** Shots: `param-shortcut-*` ("Shortcut Name") and `param-path-*` ("File or Folder"). The other labels use sentence case ("Keys to hold", "If already in front", "Distance per app"). Fix: "Shortcut name" and "File or folder".
5. **Labels in two-line rows sit too low.** Shots: `param-url-error-*` and `param-recorder-error-*`. The label is centred on the field and its message together. BRIEF: the label sits on the left of a 28 pt row, with validation "under its control". Fix: align the label to the field's row and let the message hang below.
6. **The recorder error's demo data is incoherent.** Shots: `param-recorder-error-*`. The field shows "⌘ K", which already has a key, beside "Add a key. Modifiers alone work only on Hold Keys." Fix: show "⌘" alone in the field. The input is kept, per § Issue states.
7. **The disclosure chevron is wrong while expanded.** Shots: `picker-searched-*`. Search expands the "3 more need a slide or long-press" section, but the chevron still points right. The `-full` shots point it down. Fix: drive the chevron from the effective expanded state, search included.
8. **The overlap copy has an extra "The".** Shots: `inspector-overlap-warning-*` ("The whole edge and the upper half both use Slide."). The pattern ruled after batch 16 is "<part> and <part> both use <gesture>." Fix: "Whole edge and upper half both use Slide."
9. **The app list has an empty row.** Shots: `param-app-list-*` show a blank row-height gap between "All apps" and Wayfare. Fix: remove the empty item, or show the running app in All apps as well.
10. **Slider tracks start at different x positions.** Shots: `param-presentation-fields-*`. The value text's width moves the track. Fix: give the value column a fixed trailing width so every track lines up.

## Matches BRIEF

- Picker height ruling (b): `picker-anchored-bottom-*` and `picker-anchored-right-*` sit between the inner edges of the top and bottom bars and cover no bar or neighbouring zone.
- Picker: "Tap, bottom edge" header, "Search actions", Sound, Display, Media, System, Windows, Apps, Keyboard, Shortcuts; "Needs a backlit keyboard" and "Uses the system Control–Left shortcut" as 13 pt second lines; "6 more need a slide or long-press" at the end.
- App-tab rows: "Next Track · from Default"; the overridden dot with **Revert** and "Default: Previous Track"; "Off here" with **Revert**; app-only "Show Desktop" in `ink` with no caption; "…" on every row.
- While picking, the row's value is blank (bone 6).
- "Needs keys" in `ink2`; "Click to record"; "⌃⌥ Space"; "fn"; "Press keys…" with a 2 pt accent ring.
- App chooser: pop-up plus "If already in front", **Hide it** / **Stay**; app list with search, Running, then All apps.
- URL placeholder "https://…" and "Needs a scheme, like https://" (error icon, `ink`). Unavailable is a warning icon plus `ink2`. The interaction note copy is exact, with an info icon in `ink2` and "Use long-press instead".
- Batch-20 copy: "Distance per app" "8 mm", "Off" at 0 ms, "Default (500 ms)", "800 ms" **Reset**, and both helper lines exact.
- Add gesture: Swipe up and Swipe down icons differ clearly.
- Kill list: no middots, rotated text or second hue; "100%" and "13%" have no space before %.

## Questions for design

1. **Split control on an app tab.** `inspector-wayfare-sources-*` shows "Split into" disabled on Wayfare. BRIEF doesn't say whether an app profile can split an edge differently from Default. If it can't, should the control be hidden rather than greyed out?
2. **"Release after" on Hold Keys.** `inspector-corner-needs-keys-*` has a "Release after" slider showing "120 s". BRIEF doesn't list this parameter. Is it a real runtime parameter (a safety auto-release)? If so, it needs a label, range and helper line in the batch-20 table, and its default should read in `ink2`.
3. **11 pt section headers in the app list.** "Running" and "All apps" in `param-app-list-*` are 11 pt, the same as the picker group headers. BRIEF reserves 11 for "picker group headers only". Does the app-list popover, shared with add-app, count as a picker, or should these be 13 semibold?

## Design answers (chief, 2026-11-07)
1. **Split on an app tab.** If the runtime can lay out an app profile's split independently (the split re-lays bindings, so an inheriting app would get overrides), **enable it** on app tabs; it behaves like any other override. If it can't, **hide** the control on app tabs rather than greying it out. A disabled control with no reason breaks "each status said once, next to the thing". Build chief's call based on the runtime; tell design which.
2. **"Release after" (Hold Keys, `maxSeconds`)** is a real runtime safety parameter. Spec, added to BRIEF's batch-20 table:
   - Label: "Let go after".
   - Control: a slider over the runtime's `holdMaxSecondsRange`, value "120 s"; default in `ink2`.
   - Helper line: "If a lift is missed, the keys come back up after this long."
   - It sits last before the haptics checkbox.
3. **The 11 pt rule covers only the action picker's group headers.** The app-list popover (parameter chooser and add-app) uses **13 pt semibold `ink2`** for "Running" and "All apps".
