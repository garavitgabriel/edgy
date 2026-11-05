---
batch: 3
tag: EDGY-ACTIONS
branch: feat/edgy-v01-batch-3
completed_at: 2026-11-03 23:40
verification: pass
---
## Acceptance criteria
- [✓] ≥ 12 tests in `Tests/ActionsTests/`, all on mocks — 31 new tests (32 total with the skeleton test), 7 suites
- [✓] Each action id dispatches to the right output (`DispatchTests`: volume, brightness, mute, mic mute, play/pause/next/previous, shortcut)
- [✓] Continuous clamping at both ends (`clampsAtTop`, `clampsAtBottom`)
- [✓] Sensitivity scaling (`sensitivityScalesDelta`, `invalidSensitivityFallsBackToDefault`)
- [✓] Haptic tick counting across steps + strong ticks at 0 and 1, silent while pinned, none when disabled (`HapticTests`)
- [✓] HUD shown / not shown per `HUDMode`, settings changes apply live (`HUDTests`)
- [✓] `shortcut.run` missing / empty name → `missingParameter`
- [✓] Unknown id → `unknownAction`
- [✓] Trigger to continuous → `wrongInputShape` (and delta to trigger → `wrongInputShape`)
- [✓] `available` lists exactly the 8 actions with correct shapes
- [✓] Guard test: test registry holds only mocks; no test source references the live factory or live output types (`NoLiveOutputsGuard`)
- [✓] No test touches real audio, display, media keys, HUD, haptics or `shortcuts`
- [✓] `makeLiveActionRegistry(settings:)` builds from live outputs; signature unchanged; construction is side-effect free (everything loads/connects on first use)
- [✓] `scripts/smoke-actions.sh` written (asks before each step, restores prior values at end and on Ctrl-C). Never run by me; its driver was compiled with `-typecheck` only.
- [✓] Verification triple green

## Verification
- `swift build` — exit 0, no warnings
- `swift test` — 32 tests in 7 suites passed
- `swift format lint --strict -r Sources Tests Package.swift` — exit 0
- Denylist grep — no matches

## Needs Gabriel (manual steps)
- Run `scripts/smoke-actions.sh` (grant Accessibility to the terminal first so media keys post).
- Feel the haptic ticks (step 1, 4 and 8 of the script) — confirm tick vs strong tick are distinguishable.
- Confirm the HUD icons in step 7: image IDs `brightness = 1`, `volume = 3`, `muted = 4` in `LiveHUDOutput.Image` are unverified.
- Confirm next/previous use the right key codes (`NX_KEYTYPE_NEXT` / `NX_KEYTYPE_PREVIOUS`). If the player ignores them, try `NX_KEYTYPE_FAST` / `NX_KEYTYPE_REWIND`.
- Check mic mute on the built-in mic: many input devices have no mute control; the action then throws `unavailable("…has no mute control")`.

## Diff summary
- `Sources/Actions/Outputs.swift` — internal protocols: `AudioOutput`, `BrightnessOutput`, `MediaKeyOutput`, `HUDOutput` (+ `HUDKind`), `HapticOutput`, `ShortcutRunner`; `OutputError`.
- `Sources/Actions/ActionRegistry.swift` — public `ActionRegistry: ActionPerforming` (public `settings` var so the app can toggle HUD/haptics live), `BuiltInAction` ids, `LevelStep` value-mapping rule. Internal init takes injected outputs.
- `Sources/Actions/LiveAudio.swift` — CoreAudio volume (main element, falls back to channels 1+2), output/input mute, headphone data source.
- `Sources/Actions/LiveOutputs.swift` — DisplayServices via `CFBundle` lookup (built-in display only), media keys as system-defined events, OSD helper over NSXPC (logs once, then goes quiet), `NSHapticFeedbackManager` (hopped to main), `/usr/bin/shortcuts run <name>` on a background queue.
- `Sources/Actions/Actions.swift` — factory body now builds the live registry.
- `Tests/ActionsTests/Mocks.swift`, `Tests/ActionsTests/ActionRegistryTests.swift`.
- `scripts/smoke-actions.sh`.

## Surprises / learnings (1–3)
- The package has no library product and `Package.swift` is frozen, so the smoke script compiles `EdgyCore` and `Actions` straight from source with `swiftc` (`-enable-testing`) and builds a throwaway driver in `$TMPDIR`.
- Haptic tick counting needed asymmetric rounding (floor going up, ceil going down) so a step boundary counts once whichever way you slide; landing on 0/1 swaps that boundary's tick for a strong tick.
- `OSAllocatedUnfairLock` can't hold an `NSXPCConnection` under Swift 6 (not Sendable); the HUD uses `NSLock` + `@unchecked Sendable`.

## Open questions
- Behavior choices I made: raising volume while muted unmutes (as the hardware keys do); a slide keeps its own level for the whole session instead of re-reading the system each frame (avoids quantization jitter); mic mute shows no HUD (no known native mic image).
- Haptic patterns: tick = `.alignment`, strong tick = `.levelChange`. The public API doesn't let you set strength, so this needs a feel check.
- The app has to cast `ActionPerforming` to `ActionRegistry` to update `settings` at runtime. If the chief would rather have a factory/protocol hook for that, it's a contract change.
