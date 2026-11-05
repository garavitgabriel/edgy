---
batch: 4
tag: EDGY-APP
branch: feat/edgy-v01-batch-4
completed_at: 2026-11-03 23:14
verification: pass
---
## Acceptance criteria
- [✓] ≥ 12 tests in `Tests/EdgyRuntimeTests/` with fakes for every collaborator: 26 tests (25 new + the skeleton `moduleLinks`), all collaborators faked (`FakeTouchSource`, `FakeRecognizer`, `FakeActions`, `FakePointerGuard`, `FakeTyping`, `FakeFrontmost`, `RecordingLogger`).
  - Config: `firstRunCreatesDefaultsOnDisk`, `saveThenLoadRoundTrips`, `unknownSchemaVersionThrowsAndKeepsBackup`, `reloadPicksUpEdits`, plus `fileIsPrettyPrintedWithSortedKeys`, `malformedJSONThrowsAndKeepsBackup`, `watcherReloadsAfterExternalEdit`, `ownSaveDoesNotEchoAsReload`.
  - Router: `defaultProfileUsedWhenNoAppProfileMatches`, `appProfileReplacesDefault`, `disabledProfileDropsEverything`, `slideBecomesDeltaWithPhase`, `doubleTapBecomesExactlyOneTrigger`, `unmatchedGestureIsIgnored`, `bindingParametersAreForwarded`, `actionErrorIsSwallowedAndLogged`, plus `cancelledDiscreteGestureDoesNotFire`.
  - Engine: `pointerGuardEngagesOnClaimAndReleasesOnUnclaim`, `pauseReleasesGuardAndStopsRouting`, `configReloadRebuildsContext`, plus `stopReleasesGuardAndStopsSource`, `configReloadReleasesEngagedGuard`, `contextFollowsFrontmostAppAndTyping`, `disabledAppSettingStopsProcessing`, `framesFromUnknownDevicesAreDroppedUntilConnected`.
- [✓] ConfigStore: `~/Library/Application Support/Edgy/config.json` (path injectable), defaults on first run, unknown `schemaVersion` → `ConfigStoreError.unsupportedSchemaVersion` + `config.json.bak` (malformed JSON too), debounced file watcher (directory + file sources, so rename-saves are seen; own saves don't echo), pretty-printed + sorted keys.
- [✓] Router: profile lookup, disabled profile drops, zone + kind match, `.delta(…, phase:)` for slides, `.trigger` for discrete, parameters + frontmost bundle ID in `ActionContext`, errors logged never thrown.
- [✓] Engine: TouchSource → GestureRecognizing (per-frame `GestureContext` from config + active profile's zones + typing source) → Router; edge-triggered pointer guard engage/release (also released on pause, stop, config apply); `pause()`/`resume()`; `apply(_:)` resets recognizer + router; `replaceActions(_:)`; device map from `devices` + `onDevicesChanged`. All collaborators injected; one serial queue (main in the app, private in tests).
- [✓] `FrontmostAppProviding` protocol in EdgyRuntime; live `WorkspaceFrontmostAppProvider` in EdgyApp.
- [✓] Menu-bar app: accessory policy, text-only `NSStatusItem` "Edgy" with Enabled, Pause for 1 Hour (→ "Paused until …" + Resume Now), Open Config File, Reload Config, About Edgy, Quit Edgy. No settings/onboarding UI designed.
- [✓] Launch at login via `SMAppService.mainApp`, synced to `AppSettings.launchAtLogin` on launch and on config change.
- [✓] `Resources/Info.plist`: `com.garavit.edgy`, `LSUIElement`, `LSMinimumSystemVersion` 14.0, name Edgy, version 0.1.0.
- [✓] `scripts/bundle.sh` → signed `build/Edgy.app` (exit 0); `codesign -dvv` shows `Authority=Apple Development: …`. Fails loudly if no identity, never ad-hoc. Identity resolved at runtime, nothing personal committed. `scripts/run-dev.sh`: bundle, quit running copy, open.
- [✓] Sibling modules reached only via `makeLiveTouchSource`, `makeLivePointerGuard`, `makeLiveTypingActivitySource`, `makeGestureRecognizer`, `makeLiveActionRegistry(settings:)`.
- [✓] Verification triple green.

## Verification
- `swift build` — Build complete, `Edgy` executable produced
- `swift test` — exit 0; EdgyRuntimeTests 26 tests / 3 suites pass; all other targets' skeleton tests pass
- `swift format lint --strict -r Sources Tests Package.swift` — exit 0
- `scripts/bundle.sh` — exit 0, `codesign --verify --strict` passes

## Needs Gabriel (manual steps)
- `scripts/run-dev.sh` (or `open build/Edgy.app`) and confirm the "Edgy" item appears in the menu bar with no Dock icon; click through Enabled / Pause for 1 Hour / Resume Now / Open Config File / Reload Config / About / Quit.
- First launch writes `~/Library/Application Support/Edgy/config.json`; edit it by hand and confirm it reloads (watch with `log stream --predicate 'subsystem == "com.garavit.edgy"' --level debug`).
- After the TouchKit batch lands: grant Accessibility to `build/Edgy.app` (System Settings → Privacy & Security → Accessibility) for the pointer guard / typing source.
- Set `"launchAtLogin": true` in the config and confirm Edgy appears under Login Items.

## Diff summary
- `Sources/EdgyRuntime/`: `Logging.swift` (`EdgyLogging` + `SystemLogger`), `ConfigStore.swift`, `Router.swift`, `Engine.swift` (+ `FrontmostAppProviding`). `EdgyRuntimeInfo` kept.
- `Sources/EdgyApp/`: `main.swift` (AppKit entry), `AppDelegate.swift` (wiring, config apply, pause timer), `StatusMenu.swift` (placeholder menu), `SystemIntegration.swift` (frontmost provider, launch-at-login).
- `Tests/EdgyRuntimeTests/`: `Fakes.swift`, `ConfigStoreTests.swift`, `RouterTests.swift`, `EngineTests.swift`; skeleton test untouched.
- `Resources/Info.plist`, `scripts/bundle.sh`, `scripts/run-dev.sh`.

## Surprises / learnings (1–3)
- `swift format format -i -r Sources Tests Package.swift` (the CLAUDE.md format command) would rewrite files outside a batch's glob, including frozen `Package.swift`; I scoped formatting to my own dirs. Worth noting in briefs for every batch.
- Watching only the config file's fd goes stale after the first atomic save (temp + rename). The store watches the parent directory and re-arms the file source on every event; a byte-compare against the last loaded/saved data prevents save → reload echo loops.
- The engine runs on `DispatchQueue.main` in the live app so actions that touch AppKit (haptics, HUD) are on the main thread; tests inject a private queue and flush with `queue.sync {}` to stay deterministic.

## Open questions
- **Discrete-gesture phase policy (reconcile with batch 2):** the router fires a discrete action once per gesture — on `.began` if the recognizer emits one, else on `.ended`; `.changed`/`.cancelled` never fire. Correct for both "single `.ended` event" and "`.began` + `.ended`" recognizers; if the Gestures batch emits something else, adjust `Router.input(for:)`.
- **Bad config file:** the original is left in place and copied to `.bak`; in-memory defaults are used until a valid file appears. A later save from the menu (Enabled toggle) overwrites the file, `.bak` keeps the original. Is that the desired behaviour, or should a newer-schema file be treated read-only?
- `AppSettings.showMenuBarIcon == false` is not honoured yet — hiding the only UI entry point needs a way back in (design-sprint question).
- Pausing mid-slide drops the slide without sending a `.cancelled` delta to the action; harmless for current actions, revisit if an action holds state between phases.
- Action registry is rebuilt when any `AppSettings` field changes (HUD, haptics), since `makeLiveActionRegistry(settings:)` only takes settings at construction.
