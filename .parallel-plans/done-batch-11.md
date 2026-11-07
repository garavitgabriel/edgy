---
batch: 11
branch: worktree-edgy-actions-v04
worktree_path: /Users/gabrielgaravit/Projects/edgy/.claude/worktrees/edgy-actions-v04
completed_at: 2026-11-07
verification: green — swift build, swift test (all suites, Actions 214), swift format lint --strict, denylist clean
---

## Acceptance criteria
- [✓] **Modifier-only hold.** `keyboard.hold` with `fn`, `ctrl+opt` or any modifier mix presses only the modifiers, in canonical order, and releases them in reverse. A double down releases the first hold before pressing again. Live route: each modifier is a **flags-changed** event with the modifier key's own code (fn = 0x3F). Its flags are the full held state *after* the change (fn = `.maskSecondaryFn`), plus the left-hand device bits a real keyboard sets (ctrl 0x1, shift 0x2, cmd 0x8, opt 0x20). The pure plan is `KeyCodes.modifierEvents`, which tests pin. `LiveKeyboardOutput.setModifiers` posts it and also sets `event.type = .flagsChanged` explicitly.
- [✓] **Event shape verified on this macOS (27.0), without posting.** I created synthetic keyboard events (never posted) with `CGEvent(keyboardEventSource:virtualKey:keyDown:)` for modifier key codes. macOS types them as `flagsChanged` (12), not `keyDown` (10). fn-down carries 0x800000 (secondary fn), ctrl-down 0x40001, opt-down 0x80020, and every up carries no modifier flags. The old code overwrote those flags and dropped the device bits. It now keeps them. **Listener side, verified:** a self-contained probe app delivered the exact `setModifiers` plan for `fn` only to its own pid (`postToPid`, so nothing went system-wide). The probe listened two ways, and both received the events:
  - A listen-only per-pid event tap got `type=12 code=63 flags=0x800000` (down), then `type=12 code=63 flags=0x0` (up).
  - An AppKit local monitor got `.flagsChanged` keyCode 63, with `.function` true on the down event and false on the up.

  So both ways an app can listen for keys, an event tap and AppKit's flags-changed events, get Edgy's fn as a press and release of the fn modifier. What a probe can't cover: an app that reads fn straight from the HID layer, below the event system, and the system-wide post path. Those are smoke step 24 (see Needs Gabriel).
- [✓] **`keyboard.shortcut` / `keyboard.slideSteps` with a modifier-only combo** → `ActionError.unavailable(id, "keys: \"fn\" is modifiers only; this action needs a key (holding works)")`, before anything is posted (`keyedCombo`).
- [✓] **Hold watchdog.** New parameter `maxSeconds`: `.number(5...600)`, optional, default `"120"`, displayName "Release after". If no up arrives in time, the hold is released and logged once (`hold: no release after N s; releasing …`). A normal up cancels it. An out-of-range value fails before anything is pressed.
- [✓] **Switcher watchdog.** `ActionRegistry.switcherIdleTimeout = 10` s. Every switcher event re-arms it. When it fires, it sends escape and then releases command. `.ended` / `.cancelled` disarm it.
- [✓] Both watchdogs use an injected `ActionScheduler` (`LiveActionScheduler` = private serial dispatch queue; tests use `MockScheduler`, a virtual clock). Key-session state is behind `keyLock`. A per-session generation token means a timer that fires late (racing a cancel) can't end a newer hold or switcher session. Tests check this with `fireLate`.
- [✓] **"Do nothing".** `BuiltInAction.doNothing = ActionID.doNothing` (`edgy.none`), displayName "Do nothing", category `.system`, shape `.trigger`, no parameters. It is always `.available` (the default availability path) and performing it is a no-op. It sits in the system group after Dictation. Catalog pinned at **34**.
- [✓] **Pickers** (public, `Sendable`, protocol + live impl + fake; building any of them has no side effects):
  - `InstalledAppsProviding` → `[InstalledApp]` (name, bundleID, path, isRunning). Sources: `/Applications`, `/Applications/Utilities`, `/System/Applications`, `/System/Applications/Utilities`, `~/Applications`, each searched one level deep (but never inside `.app`), plus running regular apps. One entry per bundle ID (case-insensitive): the first folder wins, running marks `isRunning`, and a running app found in no folder is added at its running path. Sorted Finder-style by name, then bundle ID. The work runs in a detached task. Live: `makeLiveInstalledAppsProvider()`.
  - `ShortcutsListing.shortcuts() async -> ShortcutsList(names, failure)` through `/usr/bin/shortcuts list` with a 10 s timeout (the process is killed on timeout). Names are kept exactly (spaces, emoji, CJK). Blank lines are dropped, CRLF handled, duplicates collapsed, sorted. Failure gives an empty list and a plain reason: launch failure, timeout, non-zero exit (first stderr line), or output that isn't UTF-8. Live: `makeLiveShortcutsListing()`.
  - `KeyComboRecording.start(timeout:) -> AsyncStream<KeyRecorderState>` / `cancel()`. The pure `KeyComboRecorderModel` records a key with the held modifiers (a bare key is fine). Releasing every modifier with no key records a modifier-only combo of the whole chord (`fn↓fn↑` → `fn`, `ctrl↓opt↓opt↑ctrl↑` → `ctrl+opt`). Escape alone cancels; escape with modifiers records. The recording times out, ignores key repeat and unnamed keys, and nothing changes after a final state. Modifiers come from the tracked flags-changed state, never from the key event's flags, so `left` isn't recorded as `fn+left`. The session wraps a `KeyEventSource`: the live one (`LiveKeyEventTap`) is a listen-only session tap on the main run loop, installed in `start` and removed on any final state. Missing permission ends `.unavailable(reason:)`. Live: `makeLiveKeyComboRecorder()`.
- [✓] **`scripts/smoke-actions.sh`** passes the live scheduler and adds steps 24–28: fn-only hold, the hold watchdog at `maxSeconds` 5, the key recorder (prints the recorded combo), the installed-apps listing, and the Shortcuts listing. I extracted the embedded Swift and compiled it. I did not run it.
- [✓] **≥ 25 new tests: 58 new** (Actions 156 → 214), in `Tests/ActionsTests/V04Tests.swift` and `PickerTests.swift`. They cover modifier-only down/up order and flags for fn, ctrl+opt and mixed; double-down; partial failure; key-required errors; the event plan with device bits; the hold watchdog (fires once at default and at `maxSeconds`, not after a normal up, stale fire, bad values, failed press); the switcher watchdog (release + escape, deadline pushback, disarm, stale fire); `doNothing` descriptor, availability and no-op; the recorder model (combo, bare key, modifier-only fn and chord, escape both ways, timeout, repeat/unnamed, final-state freeze, implicit-fn arrow, raw-event translation); the recorder session (lazy listening, stop on finish, timeout, cancel, restart with late events, no permission, repeat); installed apps (sort, dedup, running, depth, missing bundle ID, standard folders, lazy); and Shortcuts (arguments + timeout, spaces/unicode, CRLF/dedup/sort, empty, exit failure, timeout, launch failure, non-UTF-8).
- [✓] **Existing tests unchanged in intent.** The only edits extend pins: the id list and category map gain `edgy.none`, `count == 33` → `34` in three places, and the `keyboard.hold` parameter spec gains `maxSeconds`. Harness passes a `MockScheduler`.
- [✓] **No-live-outputs guard** asserts `r.scheduler is MockScheduler` and bans `LiveActionScheduler`, `LiveAppFolderReader`, `LiveRunningApps`, `LiveProcessRunner`, `LiveKeyEventTap`, and the three `makeLive…` picker factories in test sources.

## Verification
- `swift build`: Build complete
- `swift test`: all suites pass (48, 6, 64, 114, 19, 50, and Actions 214; integration tests included)
- `swift format lint --strict -r Sources Tests Package.swift`: exit 0
- `git grep -niE -f ~/.config/edgy-names-denylist`: no output

## Diff summary
- `Sources/Actions/KeyCodes.swift`: `deviceBits`, `heldFlags`, `ModifierEvent` + `modifierEvents` (the pure flags-changed plan), `name(for:)`, `modifiers(in:)`.
- `Sources/Actions/LiveDesktop.swift`: `setModifiers` posts the plan as flags-changed events; `held` behind a lock; key events carry device bits.
- `Sources/Actions/Outputs.swift`: `ActionScheduler`, `ScheduledWork`.
- `Sources/Actions/LiveNative.swift`: `LiveActionScheduler`.
- `Sources/Actions/ActionRegistry.swift`: `scheduler` dependency, `keyLock`, session generation + watchdog handles, `keyedCombo`, `doNothing` no-op.
- `Sources/Actions/ActionRegistry+Keys.swift`: watchdogs for hold and switcher, locking.
- `Sources/Actions/ActionCatalog.swift`: `doNothing` id + descriptor, `maxSeconds` key/range/default/parameter.
- `Sources/Actions/Actions.swift`: the factory body passes `LiveActionScheduler()` (signature unchanged).
- `Sources/Actions/Pickers.swift` (new): picker models, protocols, scanner, Shortcuts listing, recorder model + session.
- `Sources/Actions/LivePickers.swift` (new): `makeLiveInstalledAppsProvider`, `makeLiveShortcutsListing`, `makeLiveKeyComboRecorder`, and the live folder reader, running apps, process runner and key-event tap.
- Tests: `Mocks.swift` (`MockScheduler`, Harness), `V04Tests.swift`, `PickerTests.swift` (new), and pin updates in `CatalogTests.swift`, `ActionRegistryTests.swift`, `NativeTests.swift`.
- `scripts/smoke-actions.sh`: scheduler argument, steps 24–28.

## New public API (additive, for batch 12 / EdgyApp)
`InstalledApp`, `InstalledAppsProviding`, `makeLiveInstalledAppsProvider()`; `ShortcutsList`, `ShortcutsListing`, `makeLiveShortcutsListing()`; `KeyRecorderInput`, `KeyRecorderState`, `KeyComboRecorderModel`, `KeyComboRecording`, `makeLiveKeyComboRecorder()`; `BuiltInAction.doNothing`; `ActionParameterKey.maxSeconds`.

## Decisions I made (and why)
- **Flags-changed route, with device bits.** The probe showed macOS already types modifier-key events as flags-changed. Setting the type explicitly guards against that inference changing. Keeping the left-hand device bits matters to apps that tell left from right modifiers. `post()` (shortcuts) is unchanged. `key()` (switcher tabs, held keys) now uses `heldFlags`, so those events also carry the device bits.
- **Watchdogs are timers, not polling,** with a generation token rather than relying on cancel alone. Cancelling a dispatch item can race a fire that already started.
- **The switcher watchdog cancels (escape) rather than selects,** the same rule as v0.3's stray `.began`: after a lost end, selecting an app the user never chose would be a misfire.
- **"Do nothing" placement:** in the system group after Dictation, so the v0.1 prefix and every existing group order stay put. The UI can surface it first if the design wants.
- **Recorder modifier-only = the whole chord** (every modifier down since none were), not the last set held, so releasing ctrl+opt in any order gives `ctrl+opt`.
- **Recorder escape:** escape alone cancels, and `cmd+escape` etc. record (the brief: "cancels on escape alone").
- **Shortcuts are sorted** for the picker, not kept in the command's order. A name is kept exactly, including leading spaces. Only whitespace-only lines are dropped.
- **Installed apps dedup is case-insensitive on bundle ID**, because the system treats bundle IDs that way. The first folder wins, so `/Applications` beats `/System/Applications`, and a running app's path is used only when it was found in no folder.
- **Recorder default timeout** `KeyComboRecorder.defaultTimeout = 10` s (internal). Callers pass their own to `start(timeout:)`.
- **Picker protocol method name** `ShortcutsListing.shortcuts()` returns a value with `failure` rather than throwing, so the UI always gets a list.

## Needs Gabriel
Run `scripts/smoke-actions.sh` (Accessibility for the terminal; Input Monitoring for step 26):
1. **Step 24, fn-only push-to-talk:** set a dictation app's hold key to fn and confirm it listens for the 3 s and stops on release. **This is the open question:** synthetic flags-changed events reach apps that use an event tap or a global flags monitor. An app that reads fn from the HID layer won't see them. If it does nothing, note which app and setting. Also try `ctrl+opt` via step 20.
2. **Hardware vs. hidSystemState:** the probe used a private-state source. The live output uses `.hidSystemState`, which may merge in real keyboard flags. Confirm nothing feels stuck after steps 20, 24 and 25 (type a few letters; check fn+arrow still works).
3. **Step 25, hold watchdog:** with `maxSeconds` 5 the dictation app stops by itself after about 5 s, and the log line appears.
4. **Step 26, recorder:** try `cmd+shift+4`, a bare `f5`, fn alone, `ctrl+opt` released in either order, and escape (cancels). Without Input Monitoring it should say "Edgy needs Input Monitoring permission to record keys."
5. **Steps 27–28:** installed-apps count and timing look sane, with no duplicates and running apps flagged. The Shortcuts names match the Shortcuts app, including emoji or non-Latin names.
6. **Regression: steps 12, 16, 19, 20.** Key events sent while modifiers are held (switcher cmd+tab, held keys) now carry left-hand device bits, as real keyboards do. Re-run these v0.3 steps to confirm nothing changed.
7. **Switcher watchdog:** hard to trigger by hand. It fires only if a switcher slide's end is lost for 10 s. Covered by tests.

## Open questions
- **Validation (batch 12):** `keyboard.shortcut` / `slideSteps` with a modifier-only combo should be flagged at save time. The registry already rejects them at perform time with "needs a key".
- **Right-hand modifiers:** some dictation apps default to *right* option or command. `KeyCombo` has no left/right distinction, so Edgy always presses the left key. Supporting this needs an `EdgyCore` change (e.g. `ropt`); I didn't need a blocker for v0.4.
- **Recorder and the system's own shortcuts:** a listen-only tap sees keys but can't stop them. Recording `cmd+space` will also open whatever the system binds to it. A filtering (non-listen-only) tap would need Accessibility and is a design call.
