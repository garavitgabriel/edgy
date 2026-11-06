# Batch 5 — EDGY-ACTIONS-2: grow the action catalog

Read `CLAUDE.md` and `.parallel-plans/2026-11-05-edgy-v02.md` first. You own `Sources/Actions/**`, `Tests/ActionsTests/**`, `scripts/smoke-actions.sh`. Study the existing registry and outputs before adding to them; keep their style (protocol per output, live impl, mock, registry dispatch).

## Build

1. **Describe the existing 8 actions** with `category` and `parameters` (e.g. `shortcut.run` → `name`, `.text`, required). Cross-cutting parameters (`haptics`, `sensitivity`) are NOT listed per action.

2. **New actions** (ids are final; the UI and docs will use them):

   | id | shape | category | parameters |
   |---|---|---|---|
   | `keyboard.shortcut` | trigger | keyboard | `keys` keyCombo, required |
   | `keyboard.slideSteps` | continuous | keyboard | `upKeys` keyCombo req., `downKeys` keyCombo req., `step` number 0.02…0.5 default `0.0625` (fraction of zone length per key press) |
   | `app.open` | trigger | apps | `bundleID` appBundleID req., `whenFrontmost` choice `["stay","hide"]` default `hide` |
   | `url.open` | trigger | apps | `url` url req. |
   | `file.open` | trigger | apps | `path` filePath req. |
   | `system.missionControl` | trigger | system | — |
   | `system.appWindows` | trigger | system | — (windows of the frontmost app) |
   | `system.showDesktop` | trigger | system | — |
   | `spaces.left` / `spaces.right` | trigger | system | — |
   | `system.lockScreen` | trigger | system | — |
   | `system.sleepDisplay` | trigger | system | — |
   | `window.leftHalf` / `window.rightHalf` / `window.topHalf` / `window.bottomHalf` | trigger | windows | — |
   | `window.maximize` / `window.center` / `window.minimize` | trigger | windows | — |
   | `window.restore` | trigger | windows | — (back to the frame before this binding's last snap; no-op if none) |

   `keyboard.slideSteps` is the generic "slide does repeated keys": one key press per `step` of travel, sign picks `upKeys`/`downKeys` (toward top/right = up). Reuse the level-step idea but unbounded; one `slideSteps` haptic tick per press when allowed. This covers zoom (cmd+= / cmd+-), tab switching, video scrubbing (left/right) without per-app code.

3. **New outputs**, each a protocol + live impl + mock:
   - `KeyboardOutput`: post a `KeyCombo` (down/up with modifier flags). Live: `CGEvent` posted to the HID tap. Map every `KeyCombo.keyNames` entry to an ANSI virtual key code in a table in this module; a test proves the table covers the whole vocabulary.
   - `WorkspaceOutput`: open/activate/hide app by bundle ID (+ is-frontmost), open URL, open file (missing file → `OutputError`). Live: `NSWorkspace` / `NSRunningApplication`.
   - `WindowOutput`: frontmost window frame get/set/minimize, plus the visible frame of the screen containing it. Live: Accessibility API (`AXUIElement`, focused app → focused window, `kAXPositionAttribute`/`kAXSizeAttribute`/`kAXMinimizedAttribute`). Edgy already has Accessibility. No window → `OutputError`.
   - `SystemOutput`: Mission Control / app windows / show desktop / Spaces left/right / lock / sleep display. Pick the most robust public approach for each and document why in a comment (e.g. launching the system Mission Control app with an argument, the standard keyboard shortcuts via `KeyboardOutput`, `pmset displaysleepnow` via `Process`). If an approach depends on a user-changeable system shortcut, say so in the descriptor's doc comment and in the done report.

4. **Pure geometry** for window snapping: a function from (visible screen frame, current window frame, action) → target frame, in its own file, fully unit-tested (halves, maximize, center keeps size and clamps to screen, odd pixel sizes, a screen not at origin, flipped-coordinate correctness between AX top-left and AppKit bottom-left). Snap memory for `window.restore` is keyed by window identity the output provides.

5. `makeLiveActionRegistry(settings:)`: same signature, wires the new outputs. Still no side effects at construction.

6. `scripts/smoke-actions.sh`: add interactive, ask-before-each steps: open a fresh TextEdit document, send it a harmless shortcut (e.g. `cmd+b` toggling bold), snap that window left / right / restore, open `https://example.com`, Mission Control, Spaces left and back. Close what it opened and restore state at the end where possible.

## Acceptance
- `available` lists every action above plus the original 8, each with the right shape, category and parameters; a test pins the full id list.
- ≥ 25 new tests, all on mocks: each new action dispatches to the right output with the right arguments; missing/invalid required parameter → `missingParameter` (or `unavailable` for an unparseable `KeyCombo`, with a clear reason); `app.open` hide-when-frontmost vs stay; `keyboard.slideSteps` press counts across steps in both directions, partial steps carried across `.changed` events and reset on `.began`; window geometry suite above; `window.restore` with and without a prior snap; key-code table covers all of `KeyCombo.keyNames`.
- The no-live-outputs guard test is extended to every new output.
- Verification triple green, denylist clean.
- Done report "Needs Gabriel": run the updated `scripts/smoke-actions.sh`; any action whose live path depends on a system keyboard shortcut being enabled.
