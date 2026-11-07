---
batch: 16
tag: EDGY-WINDOW
branch: worktree-edgy-window
worktree_path: /Users/gabrielgaravit/Projects/edgy/.claude/worktrees/edgy-window
completed_at: 2026-11-07
verification: swift build ✔ · swift test ✔ (0 failures; 46 tests in EdgyUITests incl. 43 new) · swift format lint --strict ✔ · token greps clean · denylist clean
---

# Done — batch 16: settings window shell, app-profile flows, window states, Advanced…

Merged `main` (4ea5194, supplement renders S1–S8) into the branch before building, per the chief's message; S1, S2 and S5 were used alongside A/B.

## Acceptance criteria

| Criterion | Status |
|---|---|
| `SettingsWindowView`: no sidebar, tabs top centre (Default, apps A–Z, "+"), switch follows tab, mirror left / inspector right, footer (Haptics, Launch at login, HUD Native/None, Advanced…), `WindowMaterial` (NSVisualEffectView + `Tokens.windowTint`), min size fits the larger pad to scale | ✔ `SettingsWindowView.swift`, `WindowParts.swift` |
| Add-app popover: search, Running then All apps, "Has a profile" rows, step 2 "Start from" (Default, with changes preselected / A copy of Default / Empty), Add + Back, new tab opens selected | ✔ `AddAppView.swift` |
| Tab context menu: "Reset <App> to Default", "Remove <App> profile…" with a confirm | ✔ |
| Legacy note + Follow Default (`convertToInheriting`) | ✔ |
| "Edgy is off in <App>" + Turn on; inspector empty | ✔ |
| System states: Accessibility strip + Open Settings (gone when granted), Paused line + Resume, no trackpad, disabled | ✔ (see decisions on mirror fade ownership) |
| Issue states: overlapping-zones line + Show; broken config strip, read-only window, Open config file / Reload / Replace with current settings… behind a confirm | ✔ against `\.windowConditions` until batch 13 lands (`blockers-batch-16.md`) |
| Advanced… sheet: edge width, corner size, dwell, palm size, typing suppression, double-tap window, long-press, fingers, haptic events, tick/click strength, units, ranges from `GestureSettingsLimits` / `AppSettings.hapticStrengthRange`, all via `updateGestureSettings` / `updateAppSettings`, drag = one undo step, out-of-range note | ✔ `AdvancedSettingsView.swift` |
| Snapshots light + dark (15 shots × 2) | ✔ `docs/design/build-shots/batch-16/` |
| ≥ 15 tests | ✔ 30 behaviour tests (43 incl. the 7-case parameterized Advanced test and 13 snapshot tests) |

Snapshot index: `window-default` (A-like), `window-picker` (B-like, dark), `tab-wayfare`, `tab-huddle-off`, `add-app-step1`, `add-app-step2`, `legacy-note`, `state-no-accessibility`, `state-paused`, `state-no-trackpad`, `state-disabled`, `issue-overlapping-zones`, `issue-broken-config`, `advanced`, `advanced-out-of-range` — each `-light.png` / `-dark.png`.

## Verification (run in the transcript)

```
swift build                                   → Build complete!
swift test                                    → every run "passed", 0 ✘ (EdgyUITests: 46 tests in 5 suites)
swift format lint --strict -r Sources Tests Package.swift → exit 0
token greps (shared brief rule 7)             → nothing printed
git grep -niE -f ~/.config/edgy-names-denylist → nothing printed (exit 1)
```

Tests cover: tab order (alphabetical, by installed name), app-name fallback, switch on Default (global Enabled) and on app tabs ("On in Wayfare", `setProfileDisabled`, global untouched), picker closes on tab change; add inheriting / copy / empty + tab selected, duplicate refused with no change; remove (back to Default), reset; Follow Default converts and keeps behaviour; add-app list sections + search; Start-from copy word for word; state precedence (all six at once), Accessibility strip denied-only, paused outranks off-in-app, disabled/test mode add no line, mouse-only = no trackpad; paused copy (47 min / 1 min / less than a minute); broken-config sentence; overlap line + Show target; part names; footer writes; every Advanced field clamps at both ends; fingers, haptic events, strengths; one undo step per drag; out-of-range note; min size fits the pad.

## Bones checklist

1. **The mirror is the pad** (to scale, orientation, no rulers): n/a for drawing (batch 14). The window *frames* it to scale: `minimumSize` fits 160 × 115 mm × `Tokens.mirrorPointsPerMM` + margins (`minimumSizeFitsTheLargerPadToScale`); larger devices grow the region. No rulers anywhere: all shots.
2. **Zone states by shape**: n/a (batch 14).
3. **Labels joined to their zone**: n/a (batch 14).
4. **Recognized vs rejected**: n/a (batch 14 / overlay).
5. **You map on the pad**: n/a (batch 15 picker); the window keeps `model.picking` and closes it on tab change (`window-picker-*`).
6. **The inspector**: n/a (batch 15); the window composes `InspectorView` and puts only the legacy note and overlap line above it (`legacy-note-*`, `issue-overlapping-zones-*`).
7. **Interaction notes named with their fix**: n/a (batch 15's tap-wait note). The window's notes follow the same icon + wording rule: info icon in `ink2` (legacy), warning icon + `ink2` (overlap), error icon + `ink` (broken config).
8. **Each status said once, next to what it describes**: ✔ one strip under the tabs (top of broken config / Accessibility), one line on the pad (paused / off in app), the switch carries Disabled and "On in <App>", no extra lines for Disabled or Test Mode: `state-*`, `tab-huddle-off-*`, `issue-broken-config-*`.
9. **Overlay**: n/a.
10. **Menu-bar popover**: n/a.

**Kill list:** no micro-caps eyebrows (section headers are 13 pt semibold sentence case), no sidebar, no cards per zone, no glow, no emoji/Unicode arrows (SF Symbols only; grep clean), no middot strings, no dimension lines, no space before %, one typeface, no rotated labels, no hero numerals, no launcher grid, no filler copy, **no generic squares as app marks** (see decisions), one hue (accent only on ON switches; default buttons are `ink`), no third-party names.

## Reader-first review (my PNGs beside A, B, S1, S2, S5)

- **Window default vs A:** matches: no sidebar, tab group top centre with the selected tab filled and semibold, "Enabled" + switch top right, divider and lighter inspector column, footer with Haptics / Launch at login / HUD Native / Advanced…. Differs: mirror and inspector are stubs (batches 14/15). Switches render with the inactive-window look headlessly (no accent fill); on a key window they take `Tokens.accent`. Material renders flat headlessly. The window is larger than A's (1285 × 845 pt vs ~960 × 640 pt in the render) because the frozen token `mirrorPointsPerMM = 5.4` makes the external pad 864 × 621 pt; A draws it at ≈3.7 pt/mm. Flagged under Open questions.
- **Picker (B layout, dark):** tabs/footer/columns match B's layout in dark; the popover itself is batch 15's.
- **Tabs vs S1:** order Default, then A–Z (S1: Default, Huddle, Wayfare ✔), switch reads "On in Huddle" ✔. Differs: no app marks in my shots, since fixture apps have no icons (decision below); S1 shows marks.
- **Huddle off:** name in `ink2` + slashed circle ✔, switch "On in Huddle" off ✔, line "Edgy is off in Huddle · Turn on" centred ✔, inspector empty ✔. The 40% fade and hairline zones are the mirror's (batch 14).
- **Add app vs S2:** step 2 matches S2: app name header, "Start from" in `ink2`, three radio rows with the selected row filled, sub-lines word for word, Back (bordered) + Add (`ink` fill). Step 1 follows BRIEF (no render): "Add an app", search, Running, All apps, "Has a profile" rows in `ink2` (kept ≥4.5:1, not double-dimmed).
- **System states vs S5 (popover forms):** paused line copy and Resume placement mirror S5's "Paused, 47 min left · Resume"; Accessibility strip uses S5's sentence and "Open Settings". No-trackpad and disabled shots show the stub (the mirror owns those treatments).
- **Broken config:** strip with error icon + the BRIEF sentence + three buttons; footer and switch visibly disabled; tabs stay clickable (viewing is safe).
- **Advanced…:** plain two-section sheet, labels `ink2`, values with units on the right in proportional figures, the out-of-range warning under its field ("The config file said 90 mm; using 20 mm.").

## Diff summary

- `Sources/EdgyUI/Window/SettingsWindowView.swift`: the window (tabs, switch, strips, mirror column with pad line, inspector column with notes, footer, sheets/alerts).
- `WindowParts.swift`: `WindowMaterial`, `WindowMetrics`, text/ink button styles, strip, pad line, legacy note, overlap note, `AppMark`.
- `WindowStatus.swift`: `SystemState` precedence, `WindowStatus.resolve`, `WindowCopy`, `OverlapNote`.
- `WindowEnvironment.swift`: `WindowConditions`, `ConfigProblem`, `WindowCommands`, environment keys.
- `SettingsModel+Window.swift`: tabs, switch, add/remove/reset/follow, footer and Advanced setters, overlap, out-of-range note.
- `AddAppView.swift`, `AdvancedSettingsView.swift`.
- `Tests/EdgyUITests/Window/*`: support fixtures, behaviour tests, snapshot tests.
- `docs/design/build-shots/batch-16/*`: 30 PNGs.

## Decisions I made (and why)

1. **Fade ownership (merge check).** Batch 14's brief owns the fade for Disabled / off-in-app and the whole no-trackpad treatment, so the window doesn't fade those (it would stack to 16%). Paused fade is in no brief; the window takes it (`.opacity(0.4)` on the mirror, paused only). If batch 14 also fades on paused, drop one.
2. **Strip vs pad line can co-show** (different places, each said once). Only the top strip shows (broken config hides Accessibility until fixed). No pad line while there's no trackpad (the mirror's own line says it).
3. **Accessibility and broken config arrive via SwiftUI environment** (`\.windowConditions`), since `init(model:)` is frozen and the model has neither. `.unknown` permission shows no strip (avoids a flash before the first check).
4. **Overlap line placement:** top of the inspector column, above `InspectorView`. BRIEF puts it under the split control (inside the inspector); batch 15 may render issue states too: **chief, keep one at merge.**
5. **No placeholder app marks.** A mark appears only when the real icon is known (desaturated). The SF "app" placeholder read as a checkbox in the first shots, and generic squares are on the kill list.
6. **Default buttons (Add, Done) are `ink`-filled**, matching S2; sliders tinted `ink`; only switches use the accent.
7. **Read-only window:** tabs stay selectable; mirror, inspector, footer, switch, "+" and context-menu items are disabled.
8. **Copy I wrote** where BRIEF gives none (one clause, plain): remove confirm "Remove the Huddle profile?" / "Its gestures go back to what Default does."; replace confirm "Replace the config file with the current settings?" / "Edgy writes the settings it is running now. The text in the file is lost."; Advanced labels ("Wait before a slide", "Ignore after typing", "Fingers for a slide"; haptic moments "Each step of a slide", "A level reaches its end", "A slide is caught", "An action runs"); strengths "4 of 6"; overlap part names ("Whole edge and upper half both use Slide.").
9. **Sliders snap in the setter** (1 mm / 10–50 ms) rather than `step:`, which drew hundreds of tick marks.

## Needs Gabriel

- Window material over real wallpapers (light/dark): text contrast on the tinted glass.
- Switches with the accent fill on a key window (headless shots show the inactive look).
- App marks with real app icons at 16 pt, desaturated: do they read as "small monochrome marks"? (Render S1 suggests line-art marks; a desaturated full-colour icon may look heavier.)
- Window size on a 13–14" display (1285 × 845 pt minimum; see Open questions).

## Open questions

1. **Mirror scale vs render size.** `Tokens.mirrorPointsPerMM = 5.4` makes the minimum window 1285 × 845 pt; render A is ≈960 × 640 pt (≈3.7 pt/mm). Keep the token (bigger window) or lower it in Tokens (chief)?
2. **Overlap line**: inspector (batch 15) or window (here)? One must go at merge.
3. **Paused fade**: window or mirror? (Decision 1.)
