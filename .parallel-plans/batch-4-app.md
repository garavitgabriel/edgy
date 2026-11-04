# Batch 4 — EDGY-APP: runtime + menu-bar shell + bundle

Read `CLAUDE.md` and `.parallel-plans/2026-11-03-2131-edgy-v01.md` first. Siblings are building TouchKit, Gestures and Actions in parallel: call **only** their frozen factories (`makeLiveTouchSource`, `makeLivePointerGuard`, `makeLiveTypingActivitySource`, `makeGestureRecognizer`, `makeLiveActionRegistry(settings:)`) and EdgyCore protocols. Today they return no-ops; after merge they return the real thing with no change on your side.

## Build — `Sources/EdgyRuntime/` (testable, no AppKit)
1. **ConfigStore**: load/save `EdgyConfig` JSON at `~/Library/Application Support/Edgy/config.json` (path injectable for tests); create defaults on first run; reject unknown `schemaVersion` with a clear error and keep a `.bak`; reload on file change (debounced); pretty-printed, sorted keys so the file is hand-editable.
2. **Router**: given a `GestureEvent` + frontmost bundle ID → pick profile (`EdgyConfig.profile(for:)`; `disabled` profile → drop) → match binding by zone + gesture kind → call `ActionPerforming.perform` with `.delta(…, phase:)` for slides or `.trigger` for discrete gestures, passing binding parameters in `ActionContext`. Errors are logged, never thrown into the pipeline.
3. **Engine**: wires `TouchSource` → `GestureRecognizing` (with `GestureContext` built from config + enabled zones + typing source) → Router; engages/releases `PointerGuarding` when `claimedContactIDs` becomes non-empty/empty; `pause()`/`resume()`; restarts cleanly on config reload. All collaborators injected.
4. **Frontmost-app provider** protocol (live impl lives in EdgyApp).

## Build — `Sources/EdgyApp/` + `Resources/` + scripts
5. Menu-bar app (`NSApplication`, accessory policy, `NSStatusItem`): Enabled toggle, Pause for 1 hour, Open Config File, Reload Config, About, Quit. Placeholder text-only icon is fine — the real icon and **all settings/onboarding UI come from the design sprint; do not design them.**
6. Live frontmost-app provider (NSWorkspace notifications). Launch-at-login via `SMAppService` wired to `AppSettings.launchAtLogin`.
7. `Resources/Info.plist`: bundle id `com.garavit.edgy`, `LSUIElement` true, min macOS 14, name Edgy.
8. `scripts/bundle.sh`: release build → `build/Edgy.app` (binary + Info.plist) → codesign with the first "Apple Development" identity from `security find-identity -v -p codesigning` (fail loudly if none; never ad-hoc). `scripts/run-dev.sh`: bundle + open.

## Acceptance
- ≥ 12 tests in `Tests/EdgyRuntimeTests/` with fakes for every collaborator: config first-run defaults, round-trip, bad schema → error + `.bak`, reload picks up edits; router: default vs app profile, disabled profile drops, slide → `.delta` with phase, double-tap → `.trigger`, unmatched gesture ignored, parameters forwarded, action error swallowed + logged; engine: pointer guard engages on claim and releases on unclaim (and on pause), pause stops routing, config reload rebuilds context.
- `swift build` produces the `Edgy` executable; `scripts/bundle.sh` runs to a signed `build/Edgy.app` (run it once in your transcript; `codesign -dv build/Edgy.app` shows the Apple Development authority).
- Verification triple green.
- Done report "Needs Gabriel": launch `build/Edgy.app`, confirm the menu-bar item, grant Accessibility when the live pieces land.
