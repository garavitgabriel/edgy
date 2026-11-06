---
batch: 5
branch: worktree-edgy-actions-v02
worktree_path: /Users/gabrielgaravit/Projects/edgy/.claude/worktrees/edgy-actions-v02
completed_at: 2026-11-05 21:09
verification: pass
---

## Acceptance criteria
- [✓] `available` lists all 28 actions (the original 8 + 20 new), each with the right shape, category and parameters. `availablePinsTheFullIdList` pins the ordered id list; `shapesAndCategories` and `parameterSpecs` pin the rest.
- [✓] ≥ 25 new tests, all on mocks: **53 new** in `Tests/ActionsTests/CatalogTests.swift` (Actions now has 89 tests).
  - each new action dispatches to the right output with the right arguments
  - a missing or invalid required parameter → `missingParameter`; an unparseable `KeyCombo` → `unavailable(id, reason: "<key>: \"<text>\" is not a key combination")`
  - `app.open`: hides when frontmost (default and explicit `hide`), stays with `stay`, activates when not frontmost
  - `keyboard.slideSteps`: press counts in both directions, partial steps carried across `.changed`, carry reset on `.began` and dropped on `.ended`, a reversal pays off the carry first, sensitivity scales travel, one tick per press
  - window geometry suite: halves, odd pixel sizes, fractional frames, a screen not at the origin, maximize, center keeps size / shrinks and clamps, AX↔AppKit flip
  - `window.restore` with and without a prior snap, chained snaps, a moved window, per-window memory, bounded memory
  - the key-code table covers all of `KeyCombo.keyNames`; codes are distinct
- [✓] No-live-outputs guard extended: `testRegistryHoldsOnlyMocks` checks all four new outputs, and the banned-name scan now covers every `Live*` output class.
- [✓] `makeLiveActionRegistry(settings:)` keeps its signature and wires the new outputs. Nothing happens at construction: AX, `NSWorkspace`, `Process` and `CGEventSource` are all touched only on first use.
- [✓] `scripts/smoke-actions.sh` adds steps 9–16: open a fresh TextEdit document, cmd+b on and off, snap left / right / restore, slide-to-repeat zoom, close the document without saving (and quit TextEdit if the script launched it), open https://example.com, Mission Control / App Windows / Show Desktop each toggled on and off, Spaces left and then right. I extracted its embedded Swift and typechecked it against the modules. I did not run the script.
- [✓] Verification triple green, denylist clean.

## Verification
- `swift build`: Build complete
- `swift test`: all suites pass (48 + 35 + 31 + 12 + 89 Actions = 215 tests)
- `swift format lint --strict -r Sources Tests Package.swift`: exit 0
- `git grep -niE -f ~/.config/edgy-names-denylist`: no output

## Diff summary
- Added: `Sources/Actions/ActionCatalog.swift` (ids, parameter keys, descriptors, ~170 lines), `KeyCodes.swift` (~50), `WindowGeometry.swift` (~50), `LiveDesktop.swift` (live keyboard / workspace / window / system, ~240), `Tests/ActionsTests/CatalogTests.swift` (~580)
- Modified: `ActionRegistry.swift` (new dispatch, `KeySteps`, snap memory, parameter helpers), `Outputs.swift` (4 protocols, `WindowID`, `WindowSnapshot`, `SystemCommand`), `Actions.swift` (factory body), `Mocks.swift` (4 mocks, Harness), `ActionRegistryTests.swift`, `scripts/smoke-actions.sh`
- About 1,540 lines added and 50 removed

## Decisions I made (and why)
- **`availableListsExactlyTheEightActions` kept** with its name and its original assertions: `count == 8`, exact equality of the shape dictionary, and non-empty display names. The assertions now apply to the first 8 entries of `available`, where the v0.1 actions still sit in their original order, and the test also asserts `available.count == 28`. The old unscoped `available.count == 8` contradicts the brief's acceptance criterion of 28 actions, so the two can't both hold. `availablePinsTheFullIdList` pins the exact ordered 28-id list.
- **`BuiltInAction` moved** from `ActionRegistry.swift` to `ActionCatalog.swift`. It is still public and keeps the same names, with new ids added. I also added a public `ActionParameterKey` enum so the settings layer can share the parameter key strings.
- **Invalid optional values** (`step` that isn't a number or falls outside 0.02…0.5, a `whenFrontmost` value outside `stay`/`hide`) → `missingParameter`, because there is no usable value. An *absent* optional parameter falls back to its default.
- **Invalid URL** (no scheme) and **relative path** (after `~` expansion) → `missingParameter`, following the brief's "invalid required → missingParameter". A file that doesn't exist → `unavailable("nothing at …")` from the output.
- **`keyboard.slideSteps` applies `sensitivity`**, so `step` is a fraction of the zone length at sensitivity 1. Every continuous binding gets a sensitivity control, and ignoring it here would leave that control doing nothing. It reads and validates its parameters on every update, `.began` included, so a bad binding fails as soon as the slide starts. At most 64 presses per update.
- **`window.restore` memory is per window and per chain.** The first snap saves the window's frame. Further snaps keep that saved frame while the window is still roughly where Edgy put it (within 32 pt per edge, because apps round frames to text grids and minimum sizes). So left → maximize → restore returns to the original frame. If the user moves the window between snaps, a new chain starts. Restore clears the entry. With no saved frame, restore does nothing and doesn't even query the window. Memory is capped at 32 windows.
- **Window identity** = pid + `CFHash` of the window's AX element. This uses public API only; no private window-number lookup.
- **Snap geometry** is computed in top-left (AX) coordinates. The live output converts the screen's AppKit `visibleFrame` with `WindowGeometry.flip`, which is tested on its own. Odd sizes give the left/top half the smaller share, with no gap and no overlap. The target screen is the one the window overlaps most.
- **Live keyboard** posts the modifier key-downs one by one, then the key, then releases in reverse. Arrows carry the numeric-pad + fn flags and nav/F-keys carry fn, as hardware events do, because the Spaces shortcuts only match events that look like real ones.
- **System commands**:
  - Mission Control / App Windows / Show Desktop run the system Mission Control app's executable with no argument / `2` / `1`. This works whatever the user's shortcuts or hot corners are.
  - Spaces left/right post ctrl+left/right, and Lock Screen posts ctrl+cmd+q. There is no public API for these.
  - Sleep Display runs `pmset displaysleepnow`.
- **`app.open`** asks the workspace whether the app is frontmost and doesn't use `context.frontmostBundleID`. The workspace is live, while the context value can be stale.
- **Fixed the smoke script**. Its `haptics.tick()` / `strongTick()` calls had no `strength:` and no longer compiled, and its `ActionRegistry(...)` call used the old init.

## Needs Gabriel
- Run `scripts/smoke-actions.sh` (steps 9–16 are new). Check in particular:
  - the TextEdit document opens and cmd+b reaches it
  - snap left / right / restore lands correctly, including on a second display if you have one. If restore does nothing after a snap, look first at the `CFHash`-based window identity.
  - Mission Control, App Windows and Show Desktop open and close with the executable-argument approach (`2` and `1` are the least certain part)
  - Spaces move with the synthesized ctrl+arrow
- Actions that depend on a system keyboard shortcut being enabled and unchanged (System Settings → Keyboard → Keyboard Shortcuts):
  - `spaces.left` / `spaces.right`: Mission Control → "Move left a space" / "Move right a space" (ctrl+←/→)
  - `system.lockScreen`: the system Lock Screen shortcut (ctrl+cmd+q)
- Try `system.lockScreen` and `system.sleepDisplay` by hand from a binding. The script skips them because they end the session.

## Open questions / followups
- `ActionDescriptor` has no doc/help field, so the "depends on a system shortcut" notes exist only as source comments next to the descriptors. If the settings window should show them, it needs a contract change (an optional `note` on `ActionDescriptor`). That would be chief work on `main`.
- Chief's planned integration test (catalog descriptors through `SettingsEditor` validation) should expect the behaviour above: absent optional parameters take their default, and out-of-range or unknown optional values are rejected.

## Session goal conditions not met (cannot be met as written)
- **"Don't weaken any existing test" conflicts with the brief.** The old test `availableListsExactlyTheEightActions` asserted that the whole catalog holds exactly 8 actions, which contradicts the brief's 28-action acceptance criterion. It now applies its original assertions to the 8 v0.1 actions, which still come first, and also checks the catalog total is 28. The alternative is restoring the old test word for word, which makes `swift test` fail. Chief to rule.
- **"Don't modify files outside the allowed list" was breached once.** `/builder-close` (plan rule 10) wrote a return file to the vault and its sync committed 145 vault paths (`8074214`, never pushed). I reversed it: the vault is back at `a837c49`, the return file is deleted, and the 144 other paths are back to the uncommitted state they were in before. The return's content (smoke-script rot, worktree-guard friction) is captured in this report instead.
