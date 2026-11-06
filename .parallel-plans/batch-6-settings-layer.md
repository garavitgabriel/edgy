# Batch 6 — EDGY-SETTINGS: the layer the settings window binds to

Read `CLAUDE.md` and `.parallel-plans/2026-11-05-edgy-v02.md` first. You own `Sources/EdgyRuntime/**`, `Sources/EdgyApp/**`, `Tests/EdgyRuntimeTests/**`. **Do not design or build any window, view or onboarding** — the design session owns that. You build the model it will bind to, and route the existing menu items through it.

The action catalog is growing in a sibling batch. Get it only through `ActionPerforming.available` (descriptors with `shape`, `category`, `parameters`); never import or name concrete action ids beyond what `EdgyConfig.defaults` already uses. Tests use fake catalogs.

## Build — `Sources/EdgyRuntime/` (testable, no AppKit)

1. **`SettingsEditor`** — single source of truth for edits, main-thread/queue-confined like the rest of the runtime:
   - Holds the current `EdgyConfig` and the catalog. Every mutation validates, saves through `ConfigStore`, and calls an injected `apply(EdgyConfig)` (the engine) — or throws and changes nothing.
   - Profiles addressed by `ProfileRef` (`.default`, `.app(bundleID)`).
   - Mutations: set binding (replaces an existing one with the same zone + gesture), remove binding, add app profile (empty or copy of default), remove app profile, set profile disabled, update `AppSettings` (closure), update `GestureSettings` (closure, values clamped to sane ranges you define and document), reset a profile, reset everything to defaults.
   - **Undo / redo**, bounded (50). One user intent = one step.
   - **Coalesced edits** for sliders: `beginContinuousEdit(key)` … many updates … `endContinuousEdit()` = one undo step; saves during the drag are debounced (injected scheduler), the final value always saved.
   - **External edits**: when `ConfigStore`'s watcher reports a change made outside the editor (hand-edited JSON), the editor adopts it as a new undoable step and notifies observers; its own saves never echo back as external changes.
   - Observation: a simple change callback (or `AsyncStream`) carrying the new config + what changed; no Combine/SwiftUI dependency in this module.

2. **Validation** — `validate(_ binding:, in:)` and `validate(_ config:)` returning issues with severity (error blocks saving, warning doesn't) and a stable code the UI can map to copy:
   - unknown action; shape mismatch (continuous ↔ `.slide` only; trigger ↔ everything but `.slide`); `zone.supports(gesture)` false; edge segment out of range (`segments` 1…4, `0..<segments`);
   - missing required parameter; parameter kind check (`keyCombo` parses via `KeyCombo`, `url` has a scheme, `number` in range, `choice` member, `appBundleID` non-empty with a dot, `filePath` absolute or `~`-prefixed); unknown parameter keys → warning (ignore `haptics`, `sensitivity`);
   - duplicate zone + gesture in one profile → error; a whole edge and a segment of the same edge both bound for the same gesture → warning.
   - Loading a config with errors must not crash or drop it: the editor exposes the issues; the engine already ignores bindings it can't run.

3. **Queries for the UI**: bindings in a profile grouped by zone; the effective profile for a bundle ID; catalog grouped by `ActionCategory` in a stable order; actions compatible with a given zone + gesture; gestures a zone supports.

4. **`PermissionChecking`** protocol (`accessibility` state: granted / denied / unknown) + `PermissionMonitor` that polls on an injected timer while not granted and reports transitions. Live impl in EdgyApp.

5. **`EngineStatus`** snapshot from `Engine`: running, paused (until), touch devices present (count + kinds), last start error. Expose a change callback. Keep the existing `Engine` API working.

## Build — `Sources/EdgyApp/` (functional only, no design)

6. Live `PermissionChecking` via `AXIsProcessTrusted()`; a helper that opens the Accessibility pane in System Settings.
7. `AppDelegate` creates the `SettingsEditor` and routes every existing config write through it (Enabled toggle, reload). Config-watcher reloads go to the editor's external-edit path.
8. `StatusMenu`: when Accessibility is not granted, one plain item "Grant Accessibility…" that opens the pane; it disappears once granted (via the monitor). When no trackpad is found, a disabled "No trackpad found" line. Plain text only.

## Acceptance
- ≥ 25 new tests in `Tests/EdgyRuntimeTests/` with fakes (fake catalog, temp-dir `ConfigStore`, fake scheduler, fake permission checker): each mutation saves + applies; invalid mutation throws and changes nothing on disk or in memory; undo/redo across several mutation kinds incl. redo cleared by a new edit and the 50-step bound; coalesced slider edit = one undo step + debounced saves + final save; external edit adopted and undoable, own save not echoed; every validation code at least once; reset profile / reset all; permission monitor transitions and stops polling once granted; engine status reflects pause/resume and device changes.
- Existing runtime tests still pass unchanged (don't weaken or delete any).
- Verification triple green, denylist clean.
- Done report "Needs Gabriel": launch with Accessibility revoked → menu shows the grant item → grant → it disappears; hand-edit the JSON while running → change applies.
