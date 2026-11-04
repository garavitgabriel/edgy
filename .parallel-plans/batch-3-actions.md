# Batch 3 — EDGY-ACTIONS: action registry + outputs

Read `CLAUDE.md` and `.parallel-plans/2026-11-03-2131-edgy-v01.md` first.

## Build
1. **Output protocols** (internal to Actions, public only if the app needs them): `AudioOutput` (output volume get/set 0...1, output mute get/set, input mute get/set, output device is-headphones), `BrightnessOutput` (get/set 0...1, `isAvailable`), `MediaKeyOutput` (playPause/next/previous), `HUDOutput` (show volume / brightness / mute levels; no-op when `HUDMode.none`), `HapticOutput` (tick, strongTick), `ShortcutRunner` (run by name, async, never blocks the gesture thread).
2. **Live implementations**: CoreAudio for audio; DisplayServices loaded by name at runtime for brightness; system-defined media-key events for media; OSD helper XPC for the native HUD (degrade silently with one log line if unavailable); `NSHapticFeedbackManager`; `/usr/bin/shortcuts run <name>` via `Process`.
3. **Mocks** for every output, recording calls, used by all tests.
4. **Registry** implementing `ActionPerforming` with these actions: `audio.volume` (continuous), `audio.mute`, `display.brightness` (continuous), `mic.mute`, `media.playPause`, `media.next`, `media.previous`, `shortcut.run` (parameter `name`). Wrong input shape / unknown action / missing parameter → the matching `ActionError`.
5. **Value mapping** for continuous actions: delta → level with a sensitivity parameter (`parameters["sensitivity"]`, default 1.0), clamped 0...1; haptic tick on every 1/16 step crossed and a strong tick at 0 and at 1 (when haptics enabled); HUD update on each change.
6. `makeLiveActionRegistry(settings:)` builds the registry from live outputs; an internal initializer takes injected outputs for tests.
7. `scripts/smoke-actions.sh` (manual, interactive, asks before each step): nudges volume, toggles mute twice, nudges brightness, sends play/pause, shows the HUD — restoring prior values at the end.

## Acceptance
- ≥ 12 tests in `Tests/ActionsTests/`, all on mocks: each action id dispatches to the right output; continuous clamping at both ends; sensitivity scaling; haptic tick counting across steps and strong ticks at the ends; HUD shown/not shown per `HUDMode`; `shortcut.run` missing name → `missingParameter`; unknown id → `unknownAction`; trigger sent to a continuous action → `wrongInputShape`; `available` lists exactly the 8 actions with correct shapes.
- A guard test proving the test registry contains no live outputs.
- No test touches real audio, display, media keys, HUD, haptics or `shortcuts`.
- Verification triple green.
- Done report "Needs Gabriel": run `scripts/smoke-actions.sh`; feel the haptic ticks.
