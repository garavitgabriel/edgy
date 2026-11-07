# Batch 7 — EDGY-ACTIONS-3: native HUD, availability, new actions

Read `CLAUDE.md` and `.parallel-plans/2026-11-06-edgy-v03.md` first. You own `Sources/Actions/**`, `Tests/ActionsTests/**`, `scripts/smoke-actions.sh`. Keep the module's style: protocol per output, live impl, mock, registry dispatch, catalog descriptors.

## Build

1. **Native volume HUD.** Today a volume slide sets CoreAudio directly and shows the legacy overlay via the OSD helper. On current macOS that overlay is outdated; the volume keys show the current system animation (including per-device variants such as wireless earbuds). Change `audio.volume` slides to move the volume **the way the keys do**: post system-defined volume-up/down key events, using the system's fine-step modifier so one step is 1/64 (verify the modifier combination on this macOS and document it). Map slide travel to fine steps (respecting `sensitivity`); one `slideSteps` haptic tick per fine step crossed, or per 4 fine steps if that's more natural — choose, justify, make it a named constant. `slideLimits` click at 0 and 1 (read the level back through CoreAudio). Mute toggling likewise via the mute key event so the system HUD shows. Keep the old CoreAudio + OSD path as a fallback when posting events fails, and when `HUDMode` is `.none` (then set the level silently through CoreAudio, no HUD).
2. **Native brightness HUD (built-in display).** Same approach for `display.brightness` on a built-in panel: brightness key events with fine steps. External displays go through `Displays` (below) and show no system HUD; leave a `// HUD for external displays: design sprint` note — no custom overlay in this batch.
3. **External brightness via `Displays`.** Inject a `DisplayBrightnessControlling` (from `makeLiveDisplayBrightness()` in the live factory; a mock in tests). `display.brightness` targets the display under the pointer (`activeDisplayID()`): built-in → step 2; controllable external → `setBrightness` with the same 0…1 slide mapping and haptics; not controllable → `ActionError.unavailable` with the display's `reason`. Today the factory is a placeholder that reports no displays — your code must be correct against the protocol, not the placeholder.
4. **`availability(of:)`** for every catalog action: brightness → available if the built-in panel exists or any display is controllable, else `unavailable(reason:)` with plain-language copy (e.g. "This Mac has no built-in display, and the connected monitor doesn't accept brightness control."); keyboard backlight → unavailable without a backlit keyboard; Spaces / Lock Screen / Mission Control → `limited(reason:)` naming the system shortcut they depend on, if they do; everything else → available. Cache per display/keyboard configuration; never touch hardware in tests (inject probes).
5. **New actions** (ids final):

   | id | shape | category | parameters |
   |---|---|---|---|
   | `apps.switcher` | continuous | apps | `step` number 0.04…0.5 default `0.1` |
   | `keyboard.hold` | hold | keyboard | `keys` keyCombo, required |
   | `system.dictation` | trigger | system | — |
   | `keyboard.backlight` | continuous | display | — |
   | `keyboard.backlightToggle` | trigger | display | — |

   - `apps.switcher`: on `.began` press and keep the command modifier down and send one tab (switcher opens on the next app); each `step` of travel sends tab (toward top/right) or shift-tab; on `.ended` release the modifier (selects); on `.cancelled` send escape, then release. Never leave a modifier stuck: release on every exit path, including errors and a new `.began` without an end.
   - `keyboard.hold`: `press(down: true)` → key-down of the combo (modifiers then key); `press(down: false)` → key-up in reverse. Track what's held; a second down without an up releases first. This is the push-to-talk for dictation apps (they ask the user to hold a key).
   - `system.dictation`: start/stop macOS Dictation by the most robust route you can verify (e.g. the dedicated dictation key event); document what it depends on.
   - `keyboard.backlight` / `…Toggle`: keyboard backlight level 0…1 through the private brightness framework loaded by name (find the client class/selectors yourself; degrade with one log line). Toggle remembers the last non-zero level.
6. **Full-screen snap.** `window.*` snap actions on a full-screen window: take it out of full screen (AX full-screen attribute), wait for the transition to finish (poll the attribute with a bounded timeout, off the action thread), then snap. `window.restore` returns it to its pre-snap frame, not to full screen. `window.minimize` on full screen: exit then minimize.
7. Extend `scripts/smoke-actions.sh` with interactive steps for each new behaviour (volume HUD with headphones note, app switcher, hold, dictation, backlight on a MacBook, full-screen snap).

## Acceptance
- ≥ 30 new tests on mocks: fine-step mapping both directions + sensitivity + haptic counts + limit clicks; fallback path when event posting fails and when HUD is `.none`; brightness routing built-in vs external-controllable vs not-controllable (reason surfaced); availability for every catalog id (pin with a table test); app switcher full lifecycle incl. cancel → escape, new began without end, error mid-slide — modifier always released; hold down/up pairing incl. double-down; backlight level mapping and toggle memory; full-screen exit → wait → snap ordering and timeout; catalog id list pinned (33 actions).
- Existing tests unchanged in intent (update the pinned id list; never weaken assertions).
- No-live-outputs guard covers every new output.
- Verification triple green, denylist clean.
- Done report "Needs Gabriel": every smoke step that needs eyes/fingers, and which system settings each action depends on.
