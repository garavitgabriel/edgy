---
batch: 17
tag: EDGY-POPOVER
branch: worktree-edgy-popover
worktree_path: /Users/gabrielgaravit/Projects/edgy/.claude/worktrees/edgy-popover
completed_at: 2026-11-07
verification: swift build ✔ · swift test ✔ (all suites; EdgyUITests 80 tests, 33 of them batch 17) · swift format lint --strict ✔ (exit 0) · token greps empty · denylist empty
---

# Done — batch 17: menu-bar glyph, popover, system/issue states, MenuBarController

Merged `main` twice while building: fast-forward to batch 16 (4bba3d2), then `git merge main` for batch 13 (ab0145c: `SettingsEditor.configProblem`) on a teammate's note. No rebase.

## Acceptance criteria

| Criterion | Status |
|---|---|
| `MenuGlyph.image(for:)`: template image per state from the bundled PDFs (`EdgyUIResources.glyphPDF`), 16 × 11 pt; disabled / no trackpad = normal at 40% in code | ✔ `Glyph/MenuGlyph.swift`; tests `glyphImagesAreSixteenByElevenTemplates`, `disabledAndNoTrackpadAreNormalAtFortyPercent` (measured ink ratio 0.4 ± 0.03) |
| Precedence as a pure function, inputs documented: Broken config > No Accessibility > No trackpad > Paused > Disabled > Test Mode | ✔ `MenuGlyph.state(brokenConfig:…)` (pure) + `MenuGlyph.state(engine:editor:testMode:accessibility:configProblem:)` (doc comment lists each input); tests: every state alone, every pair (15), all at once, live facts |
| `MenuPopoverView`: mini mirror + chips (live filled, others outlined, frontmost app's chip first, click opens Settings on that tab via closure) + Enabled + Test Mode + "Don't run actions" (indented 24 pt, only while Test Mode, off by default, not persisted, resets when Test Mode turns off) | ✔ `Popover/MenuPopoverView.swift`, `MenuBarState.swift`, `PopoverContent.swift` |
| Test Mode on = overlay on, actions run; `model.isTestMode` false unless the box is checked (`model.setTestMode(true)`); overlay flag exposed for batch 18 | ✔ `MenuBarState.testMode` / `onTestModeChange`; `MenuBarController.isOverlayVisible` / `onOverlayVisibleChange` |
| Plain list with system highlight: Pause for 1 hour (hidden while paused), Settings… ⌘,, Open config file, Reload config ⌘R, About Edgy, Quit Edgy ⌘Q. No power button, hero numeral, cards on cards | ✔ `Popover/MenuListView.swift`, `MenuRow` |
| States: paused line + Resume (whole minutes / "less than a minute left"); No Accessibility block + Open Settings + "Touches still show in Test Mode."; no-trackpad dashed pad; disabled fade; broken config | ✔ all nine shots below |
| `MenuBarController` (`@MainActor`, `init(model:)`, `install()`/`uninstall()`): status item with glyph for the current state, transient popover hosting the view; `MenuBarActions` (openSettings, openConfigFile, reloadConfig, about, quit) | ✔ `Popover/MenuBarController.swift` (`init(model:actions:state:)`, both extra params defaulted, so `init(model:)` works); also `showPopover()` for onboarding's Done |
| Snapshots light + dark | ✔ `docs/design/build-shots/batch-17/`: `glyph-sheet` (every state at 1× and 2×), `popover-normal`, `popover-test-mode`, `popover-test-mode-dont-run`, `popover-paused`, `popover-no-accessibility`, `popover-no-trackpad`, `popover-disabled`, `popover-broken-config`, `popover-app-chip-live` (each `-light` / `-dark`) |
| ≥ 14 tests | ✔ 33 (`Tests/EdgyUITests/Glyph/MenuGlyphTests.swift` 8, `Popover/PopoverBehaviourTests.swift` 16, `Popover/PopoverSnapshotTests.swift` 9): glyph precedence table; time-left copy (47 min, 1 min, under a minute); "Don't run actions" visibility + reset on Test Mode off + ignored while off; dry run reaches the engine only via the box; Pause row hidden while paused; chip order (default first / frontmost first); list rows call their closures (Pause → `engine.pause(until: now + 1 h)`); controller closes the popover before each command; overlay flag reported; off-app-in-front fade; top-half precedence; Enabled is global |
| Tests never touch the real system | ✔ No test calls `install()` (no status item). The engine is a scripted `FakeEngine` (`LiveEngine` mock); everything else uses `PreviewFixtures` |

## Verification (run in this transcript)

```
swift build                                            → Build complete!
swift test                                             → every suite passed (EdgyUITests: 80 tests in 6 suites)
swift format lint --strict -r Sources Tests Package.swift → exit 0
grep -rnE 'Color\(red|Color\(\.sRGB|NSColor\(red|NSColor\(srgb|0x[0-9A-Fa-f]{6}|#[0-9A-Fa-f]{6}' Sources/EdgyUI --include='*.swift' | grep -v Shared/Tokens.swift → (nothing)
grep -rnE '\.font\(\.system\(size:|Font\.system\(size:|\.custom\(' Sources/EdgyUI | grep -v Shared/Tokens.swift → (nothing)
grep -rnE '\.(blue|red|orange|yellow|green|accentColor)\b|Color\.accentColor' Sources/EdgyUI/Popover Sources/EdgyUI/Glyph → (nothing)
emoji / Unicode-arrow grep over Popover + Glyph → (nothing)
git grep -niE -f ~/.config/edgy-names-denylist         → (nothing)
git diff --name-only main...HEAD outside my glob        → (nothing)
```

## Bones checklist

1. **The mirror is the pad** (to scale, orientation, no rulers): the mini mirror is framed at the device's sensor size × `Tokens.miniMirrorPointsPerMM`; no-trackpad draws the default 160 × 115 mm proportion. No rulers anywhere. Drawing is batch 14's. — `popover-normal-*`, `popover-no-trackpad-*`
2. **Zone states by shape**: n/a (batch 14 draws `MiniMirrorView`; a stub here).
3. **Labels joined to their zone**: n/a (the mini mirror has no labels).
4. **Recognized vs rejected by shape**: n/a (overlay, batch 18).
5. **You map on the pad**: n/a.
6. **Inspector**: n/a.
7. **Interaction notes**: n/a.
8. **Each status said once, next to the thing**: ✔ Test Mode is said only by the switch and the glyph dot (no pill) — `popover-test-mode-*`, `glyph-sheet-*`; Paused once under the mini mirror — `popover-paused-*`; No Accessibility / broken config once, replacing the top half — `popover-no-accessibility-*`, `popover-broken-config-*`; Disabled said only by the switch + fade, no extra line — `popover-disabled-*`.
9. **Overlay**: n/a (batch 18), but the overlay flag it needs is exposed (`MenuBarController.isOverlayVisible` / `onOverlayVisibleChange`).
10. **Menu-bar popover**: ✔ top half mini mirror + chips + Enabled + Test Mode; chips don't select (they open Settings on that tab); live chip filled, others outlined; frontmost app's chip first — `popover-app-chip-live-*`; bottom half plain list with the six rows and shortcuts; no power button, no hero numeral, no cards on cards — `popover-normal-*`. Two-pad cross-fade: n/a here (batch 14, `mirroredDevice`).

**Kill list:** no eyebrow micro-caps, no grey trackpad, no sidebar, no cards, no glow, no emoji/arrows as icons (shortcut glyphs ⌘ are key symbols, not icons), no middot strings, no rulers, no space before %, one typeface, no rotated labels, no hero numerals, no launcher grid, no filler copy, no generic coloured squares (chips show an app mark only when the app is installed, like batch 16), one hue (see decision 1), no third-party names.

## Reader-first review

**E (popover, Test Mode switching on)** vs `popover-test-mode-light`, `popover-normal-light`:
- Matches: order (mini mirror → chips → Enabled → Test Mode → separator → list → separator → About/Quit); chip treatment (filled ink Default, outlined others); row copy and shortcuts in `ink2`, right-aligned; no pill under the glyph.
- Differs: the mini mirror is batch 14's stub, so the slab, bars and touch aren't in my shots. The popover is 448 pt wide because the mini mirror is to scale at the 2.6 pt/mm token for a 160 mm pad; E's popover reads narrower — a token question for the G1 check, not something to fudge here. ON switches render grey in headless shots (the snapshot window is never key); the code tints them `accent` (as batch 16 does). E's chip order is Default, Wayfare, Huddle; mine is Default, then alphabetical (Huddle, Wayfare) per BRIEF § App profiles' tab order — BRIEF wins. Huddle's chip carries the slashed-circle mark in `ink2` (Edgy is off there), as on the window's tabs; E predates that spec. Chip app marks are absent because the demo apps aren't installed (batch 16's rule: no placeholder squares).
- Added (not in E): "Don't run actions" checkbox indented 24 pt under Test Mode — `popover-test-mode-dont-run-*`.

**S5 (glyph + system states)** vs `glyph-sheet-*`, `popover-paused-*`, `popover-no-accessibility-*`, `popover-no-trackpad-*`:
- Glyph sheet matches S5 shape for shape: normal, dot, two dashes for paused, 40% for disabled and no trackpad, exclamation for No Accessibility and broken config, at 1× and 2×, light and dark.
- Paused: "Paused, 47 min left" left, **Resume** right, under the mini mirror; Pause row gone. Matches S5. S5 also faded the paused mini mirror slightly; BRIEF's popover column says only the line, so no fade.
- No Accessibility: info icon, sentence, bordered **Open Settings**, `ink2` "Touches still show in Test Mode.", list unchanged. Matches S5.
- No trackpad: dashed outline at the default proportion with "No trackpad connected"; chips and switches stay. Matches S5.
- Broken config (no render; BRIEF § Issue states): same block form as No Accessibility with an error icon and `ink` text, **Open config file** + **Reload**.

**F (icon + glyph)**: the glyph is the exported artwork untouched; template rendering takes the menu bar's ink in both appearances (`glyph-sheet-dark` shows the light-on-dark form F shows). The app icon isn't in this batch's scope.

## Diff summary

- `Sources/EdgyUI/Glyph/MenuGlyph.swift` — PDF-backed template images (cached), 40% dim for disabled/no trackpad, VoiceOver labels, pure + live precedence functions.
- `Sources/EdgyUI/Popover/MenuBarState.swift` — `MenuBarActions` (+ `\.menuBarActions`), `MenuBarState` (Test Mode switch, dry-run box, accessibility, config problem, frontmost app, installed apps, injectable clock, overlay callback).
- `Sources/EdgyUI/Popover/PopoverContent.swift` — `MenuRow`, `ProfileChip.chips`, `PopoverTop`, `PopoverMirror`, `PopoverCopy`.
- `Sources/EdgyUI/Popover/MenuPopoverView.swift` — the view, `SettingsModel.setEnabled` (global), parts (no-trackpad pad, issue block, switch row, chip, wrapping chip layout).
- `Sources/EdgyUI/Popover/MenuListView.swift` — the plain list with the system highlight and ⌘ shortcuts.
- `Sources/EdgyUI/Popover/MenuBarController.swift` — status item, transient popover, glyph follows state via observation tracking.
- Tests + shots as listed.

## Decisions I made (and why)

1. **List highlight = the system's menu selection colour** (`selectedContentBackgroundColor` / `selectedMenuItemTextColor`) on hover. BRIEF says "a plain list with the system highlight", and § Tokens exempts system-drawn chrome from one hue. It's blue for most users. If design wants an `ink`-tint hover instead, it's a two-line change in `MenuHighlight`. **Flag for design.**
2. **Reused batch 16's `ConfigProblem` (EdgyUI), `WindowCopy.paused/noAccessibility`, `AppMark`, `TextButtonStyle`, `profileTabs/tabName/isProfileOff/selectProfile`**, so the window and popover say the same thing and sort the same way. No second precedence enum.
3. **Broken config source:** `MenuBarState.configProblem` (the app's mapped value with the real file name, as for the window), else `editor.configProblem` mapped as "config.json". The glyph checks both.
4. **Broken config and No Accessibility replace the whole top half** (the same form, so each is said once); if both apply only broken config shows (precedence).
5. **Accessibility `.unknown` shows nothing** (glyph and popover), matching the window, so there's no flash at launch.
6. **Disabled and off-in-front-app fade the mini mirror in the popover** (`opacity 0.4` on `MiniMirrorView`), because the mini mirror can't know the frontmost app. **Merge check:** if batch 14's `MiniMirrorView` also fades on disabled, drop one (it would stack to 16%). No trackpad is drawn by the popover (dashed pad), not by `MiniMirrorView`.
7. **Feed:** the popover calls `model.startFeed()` when it opens and never stops it, because `SettingsModel` has one shared feed the window and overlay also read. The app owns stopping it.
8. **Chips wrap** onto a second line (a small flow layout) rather than scroll, so many app profiles never clip.
9. **`MenuBarController.init(model:actions:state:)`** with defaults: `init(model:)` per the brief still works; `actions` is also a settable property. Each command closes the popover first.

## Needs Gabriel

- The glyph at real size in the real menu bar, light and dark, including the "CI" read risk (BRIEF G1 list) and the 40% disabled look next to system icons.
- Popover material over real wallpapers (shots are flat: tint only) and the 448 pt width that the 2.6 pt/mm token produces.
- ON switches in `accent` on a key window (headless shots draw them grey).
- The list hover colour (decision 1).

## For the chief at wiring (EdgyApp; outside my glob)

- Create `MenuBarController(model:actions:)`, set `state.accessibility` from `PermissionMonitor`, `state.configProblem` the same way the window's is set (AppDelegate line ~147), `state.frontmostBundleID` on app activation, `state.installedApps` from `model.installedApps`; call `install()`.
- Batch 18: start/stop `OverlayController` from `onOverlayVisibleChange` (and read `isOverlayVisible` at launch: always false; Test Mode isn't persisted).
- Batch 19: on Done call `menuBar.showPopover()`.

## Open questions

1. List hover: system highlight (as built) or an `ink`-tint hover?
2. Should the paused mini mirror fade (S5 shows a slight fade; BRIEF's popover column doesn't ask for it)? Built without.
