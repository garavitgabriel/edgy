---
batch: 7
branch: worktree-edgy-actions-v03
worktree_path: /Users/gabrielgaravit/Projects/edgy/.claude/worktrees/edgy-actions-v03
completed_at: 2026-11-06 (evening)
verification: partial — build, lint and denylist pass; `swift test` passes except one chief-owned integration test (blockers-batch-7.md §1)
---

## Acceptance criteria
- [✓] **Native volume HUD.** When HUD is `.native`, `audio.volume` slides post system-defined volume-up/down key events with the fine-step modifiers (shift+option, 1/64 per press), so macOS changes the level and draws its own current HUD. Presses are the 1/64 boundaries the slide crosses (`FineSteps.presses`), scaled by `sensitivity`. Partial steps carry across updates because the session keeps its own level. `audio.mute` works the same way through the mute key. Fallbacks: if posting throws, CoreAudio plus the legacy OSD HUD (logged once). When HUD is `.none`, CoreAudio is set silently and no keys are posted.
- [✓] **Haptics.** One `slideSteps` tick per 4 fine steps (`FineSteps.perTick = 4`, which is the existing 1/16 grid). `slideLimits` clicks at 0 and 1. The start level is read back through CoreAudio at `.began`.
- [✓] **Native brightness HUD (built-in panel).** Same approach using the brightness keys, with the DisplayServices + OSD fallback. `// HUD for external displays: design sprint` is in `brightnessTarget()`.
- [✓] **External brightness through `Displays`.** `makeLiveDisplayBrightness()` is injected in the live factory; tests use a mock. The target is resolved at `.began` from `activeDisplayID()` and kept for the whole slide. A built-in display goes to the key path. A controllable external display gets `setBrightness`, with the same 0…1 mapping and haptics. A display that can't be controlled gives `ActionError.unavailable` with the display's `reason`, or "<name> doesn't accept brightness control" if it has none. If `Displays` doesn't know the active display (as with today's placeholder), it falls back to the built-in panel, else "no built-in display". `DisplayBrightnessError` is turned into its plain reason.
- [✓] **`availability(of:)`** for every catalog id, cached per `HardwareFacts` (built-in panel present, `[DisplayInfo]`, backlit keyboard) and rebuilt when the facts change. Brightness is available, limited (names the monitors that refuse), or unavailable, with plain copy for no monitor / one / several. Keyboard backlight and toggle are unavailable without a backlit keyboard. Spaces left/right and Lock Screen are `.limited`, naming the exact system shortcut. Dictation is `.limited` (it depends on the Dictation setting). Mission Control, App Windows and Show Desktop are `.available`, because they ask the Dock directly. Everything else is available, and unknown ids are unavailable. All probes are injected.
- [✓] **New actions (33 total):** `apps.switcher`, `keyboard.hold`, `system.dictation`, `keyboard.backlight`, `keyboard.backlightToggle`, with the ids, shapes, categories and parameters from the brief.
  - `apps.switcher`: command goes down at `.began`, followed by one tab. Each `step` of travel then sends tab or shift-tab. `.ended` releases command; `.cancelled` sends escape, then releases. Every error path releases command. A stray `.began` cancels the old session first. Each tab gives one haptic tick.
  - `keyboard.hold`: modifiers go down, then the key; release is the key, then modifiers in reverse. A double down releases first. An up never needs the parameters. A partial failure releases whatever went down.
  - `system.dictation`: `LiveDictationOutput` posts the dictation (microphone) key, key code 0xB0. Dependencies are documented in code and below.
  - `keyboard.backlight` / `…Toggle`: CoreBrightness `KeyboardBrightnessClient`, loaded by name. Selectors were checked against this macOS: `copyKeyboardBacklightIDs`, `brightnessForKeyboard:`, `setBrightness:forKeyboard:`, `isKeyboardBuiltIn:`. One log line on failure. The toggle remembers the last non-zero level, including levels set by slides; if nothing is remembered it goes to 0.5.
- [✓] **Full-screen snap.** `window.*` snaps and `window.minimize` on a full-screen window: `exitFullScreen` (the `AXFullScreen` attribute), then a `TransitionWaiter` polls off the action thread (every 0.05 s, 2 s timeout, and the live waiter needs 2 consecutive "not full screen" polls). The command then runs on a fresh snapshot. `window.restore` goes back to the frame the window had after leaving full screen, never back into full screen. On timeout the command is dropped with a log line. A second command while the window is still leaving replaces the first. Window memory is behind `windowLock`.
- [✓] **≥ 30 new tests on mocks: 67 new** in `Tests/ActionsTests/NativeTests.swift`, bringing Actions to 156 tests. They cover fine-step mapping in both directions, sensitivity, carry, reversal, ticks per 4 fine steps, limit clicks, and pinned. They cover the key path never touching CoreAudio or the legacy HUD (no double HUD); fallback when posting fails (at start and mid-slide); HUD `.none` for volume, brightness and mute; brightness routing (built-in, external controllable, not controllable with and without a reason, target held mid-slide, unknown active display, built-in reached only through Displays, error reasons); availability as a table over all 33 ids, plus Mac-mini cases, monitor counts, cache flip on connect/disconnect, and mixed/limited copy; the app switcher lifecycle (cancel → escape, new began without end, error mid-slide, error while opening, command failing to go down, bad step, sensitivity, ticks, orphan updates, wrong shape); hold (down/up order, double down, up without down, up with broken params, missing keys, partial failure, wrong shapes both ways); dictation; backlight mapping, toggle memory, default and unavailable; and full screen (exit → wait → snap ordering, still animating, timeout, restore, minimize, replace, window gone).
- [✓] **Existing tests unchanged in intent.** The pinned id list, category map, continuous/hold sets, parameter specs and `count == 33` are extended, never loosened. The default `Harness` uses a level-key mock that fails, so every v0.1/v0.2 volume, brightness, mute and HUD test still pins the same CoreAudio + OSD path. This is commented on `Harness`.
- [✓] **No-live-outputs guard** checks all five new mocks (`levelKeys`, `displays`, `backlight`, `dictation`, `waiter`). The banned-name scan now also covers `LiveLevelKeyOutput`, `LiveKeyboardBacklightOutput`, `LiveDictationOutput`, `LiveTransitionWaiter` and `makeLiveDisplayBrightness`.
- [✓] **`scripts/smoke-actions.sh`** now compiles `Displays` too and adds steps 17–23: fine-step measurement, volume HUD with headphones, app switcher (and cancel), hold, Dictation, backlight, full-screen snap. I extracted the embedded Swift and compiled it. I did not run it.
- [✗] **Verification triple green.** Build, lint and denylist pass. `swift test` has one failure, in `Tests/IntegrationTests/CatalogValidationTests.swift:83`. That file is chief-owned, and the test predates `Shape.hold`. The one-line fix is in `blockers-batch-7.md`. I knowingly committed past this red test (plan rule 7). The failure is in a file outside my glob, and it comes from the `.hold` contract the brief requires. The only in-glob way to make it pass would be to drop `keyboard.hold` from the catalog.

## Verification
- `swift build`: Build complete
- `swift test`: every suite passes (Actions 156, plus 48 + 35 + 75 + 13 + 1), except IntegrationTests: 5 of 6 pass, and `everyActionHasAtLeastOneCompatiblePlacement` fails as described in blockers-batch-7.md §1.
- `swift format lint --strict -r Sources Tests Package.swift`: exit 0
- `git grep -niE -f ~/.config/edgy-names-denylist`: no output

## Diff summary
- `Sources/Actions/Outputs.swift`: `KeyboardOutput.setModifiers/key`; `WindowSnapshot.isFullScreen`; `WindowOutput.snapshot(of:)/exitFullScreen`; new `LevelKey`, `LevelKeyOutput`, `KeyboardBacklightOutput`, `DictationOutput`, `TransitionWaiter`.
- `Sources/Actions/ActionRegistry.swift`: `FineSteps`, `LevelTarget`, level sessions with key / fallback / silent paths, brightness routing, mute key, backlight toggle, hold dispatch, `DisplayBrightnessError` reasons.
- `Sources/Actions/ActionRegistry+Keys.swift` (new): app switcher and hold-a-key sessions.
- `Sources/Actions/ActionRegistry+Windows.swift` (new): window commands, full-screen exit and wait, locked memory.
- `Sources/Actions/ActionRegistry+Availability.swift` (new): `HardwareFacts`, cached table, copy.
- `Sources/Actions/ActionCatalog.swift`: 5 ids and descriptors, switcher step range.
- `Sources/Actions/LiveNative.swift` (new): `LiveLevelKeyOutput`, `LiveKeyboardBacklightOutput`, `LiveDictationOutput`, `LiveTransitionWaiter`.
- `Sources/Actions/LiveDesktop.swift`: held-modifier key events; AX full screen, snapshot, locked element map.
- `Sources/Actions/Actions.swift`: factory wires the new outputs (signature unchanged).
- Tests: `Mocks.swift` (new mocks, harness), `NativeTests.swift` (new), pinned-list updates in `CatalogTests.swift` / `ActionRegistryTests.swift`.
- `scripts/smoke-actions.sh`: Displays module, steps 17–23.

## Decisions I made (and why)
- **Ticks per 4 fine steps, not per fine step.** `HapticEvent.slideSteps` promises "every 1/16". It matches the 16 chiclets the system HUD draws and the grid the CoreAudio and external paths already tick on. 64 ticks per full slide felt like a buzz on paper. The constant is `FineSteps.perTick`.
- **Limits come from the session's level, not an immediate read-back.** Key events are applied asynchronously, so reading CoreAudio right after posting would be stale. The level is read back through CoreAudio at `.began` (the brief's "read the level back"). The session then predicts the level, and the click fires when that reaches 0 or 1. If the system rounds an off-grid start differently, the drift is at most one fine step, and the system HUD always shows the truth.
- **Default test harness = keys fail.** This keeps every v0.1/v0.2 assertion byte-for-byte while new tests opt in with `Harness(levelKeys: true)`.
- **A stray `.began` on the switcher cancels (escape) rather than commits.** If the end was lost, selecting an app the user never chose would be a misfire.
- **The brightness target is fixed per slide.** If the pointer drifts onto another display mid-slide, the target doesn't switch.
- **If the built-in panel is unreachable through DisplayServices but `Displays` says it is controllable**, brightness goes through `Displays`.
- **Full-screen timeout drops the command** instead of snapping a window that is still full screen, which would do nothing or fight the animation. The live waiter needs two consecutive clear polls so a mid-animation frame isn't snapped.
- **Window memory gets its own lock.** The registry is `@unchecked Sendable` only for this: the full-screen completion runs on the waiter queue. Everything else stays on the router's thread, as before.
- **Shift-tab is flagged** (cmd+shift on the tab event), not a pressed shift key. This is simpler and doesn't change the held-modifier state. It needs to be checked on hardware.

## Needs Gabriel
Run `scripts/smoke-actions.sh` (Accessibility for the terminal):
1. **Step 17:** confirm the fine-step size is ≈ 1/64 on macOS 27. The modifier combo (shift+option) can't be verified from tests.
2. **Steps 1, 4, 18:** confirm the volume and brightness slides show the *current* system HUD (with headphones or earbuds: the device's own HUD), and that there is never a second legacy overlay.
3. **Step 2:** confirm the mute key shows the system mute HUD.
4. **Step 19:** confirm the app switcher opens on the next app, steps both ways (check shift-tab), selects on release, escapes on cancel, and that command is never stuck afterwards.
5. **Step 20:** test hold-a-key with a dictation app's push-to-talk key. It depends on that app listening for a synthetic key down and up.
6. **Step 21:** test Dictation. It depends on **System Settings → Keyboard → Dictation** being on, with its shortcut including the microphone key, and on Accessibility. Key code 0xB0 is unverified on hardware. If it does nothing, the alternative is posting the user's configured Dictation shortcut.
7. **Step 22 (MacBook):** confirm the keyboard backlight slide and toggle, and that the system's own auto-brightness or idle dimming doesn't fight it.
8. **Step 23:** confirm the full-screen snap: it leaves full screen, waits, snaps, and restore goes back to the normal frame.
9. **Mac mini + external monitor:** after batch 8 lands, a brightness slide on the monitor should go through `Displays` (no HUD yet), and availability copy should show in settings.

System settings each action depends on:
- **Accessibility:** level keys, the app switcher, hold, Dictation, and window actions.
- **The Dictation setting:** Dictation.
- **Keyboard Shortcuts → Mission Control → Move left/right a space:** Spaces.
- **Keyboard Shortcuts → Lock Screen (Control–Command–Q):** Lock Screen.

## Open questions
- **Hold with a modifier only.** `keyboard.hold` can't hold a bare modifier (for example fn or right option, which some dictation apps use). `KeyCombo` requires a non-modifier key. Supporting this would need an `EdgyCore` change: a modifier-only combo, or a left/right distinction.
- **Validation for `.hold`.** `Validation.swift` (batch 9 / chief) should enforce `hold ↔ .longPress`, and the integration test needs the one-line fix (blockers-batch-7.md).
- **Stuck-key watchdog.** Should the switcher or hold release after a maximum duration in case the router never sends `.ended` or `.cancelled` (for example, the device disappears mid-gesture)? Not built; today it relies on the paired-input contract.
