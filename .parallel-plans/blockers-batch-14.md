# Blockers — batch 14 (EDGY-MIRROR)

Neither item stops the batch. Each has a local stand-in inside `Sources/EdgyUI/Mirror/`, documented there. The chief decides the real home.

## 1. The mini mirror's "active profile" has no source (resolved inside Mirror; model field still nicer)

- **Bone 10 says** the popover's mini mirror shows "zones of the active profile". § App profiles adds that the mini mirror shows the faded pad while an off app is in front.
- **Missing:** `SettingsModel` has no frontmost-app field, and `MiniMirrorView.init(model:)` is frozen.
- **Resolved (2026-11-07):** `MiniMirrorView(model:)` now follows the frontmost app itself. It reads `NSWorkspace.frontmostApplication` on appear and listens for `didActivateApplicationNotification` (read-only, ignores Edgy's own bundle), then draws that app's effective bindings (Default when the app has no profile, faded when its profile is off). `MiniMirrorView(model:frontmostApp:)` pins an app for tests or hosts.
- **Still worth it:** a `SettingsModel.frontmostApp` fed by the engine's `FrontmostAppProviding` would make every surface agree with the router, so the view wouldn't keep its own observer.

## 2. No-trackpad fallback size has no token or model field

- **§ System states says** "Bindings stay editable; the pad's zones still draw from the last-known size", and the mini mirror uses "the default proportion".
- **Missing:** `SettingsModel` keeps no last-known device. `mirroredDevice` becomes nil when the pad goes away.
- **Stand-in:** each mirror caches the last non-nil `mirroredDevice.sensorSizeMM` in view `@State`. On a cold start with no pad, it falls back to `MirrorGeometry.defaultSensorSizeMM` (160 × 115 mm, a full-size external pad).
- **Ask:** decide whether the last-known size belongs on `SettingsModel` (it would survive the view going away), and whether the default proportion should be a `Tokens` entry.

## 3. Dry-run Test Mode mark (BRIEF § Test Mode, 2026-11-07 update)

- **BRIEF says** a dry run draws the recognized contact as an outline (2 pt accent stroke, no fill).
- **Missing:** `SettingsModel` exposes only `isTestMode`, with no dry-run flag.
- **Stand-in:** the mirror always draws the filled contact. `ContactMark.dryRun` exists in `MirrorPad.swift`, so wiring it up is a one-line change once the model says so.
- **Ask:** add `SettingsModel.isDryRun` (or similar).
