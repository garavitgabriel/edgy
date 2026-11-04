# Edgy

Open-source macOS menu-bar app: every edge and corner of the trackpad, mapped to whatever you want. Swift 6, SwiftPM, macOS 14+. MIT (license file lands with the first public release).

**The bet:** the best-designed, best-feeling app in its niche. Configurability (any zone → any action, per-app profiles) and *no misfires* matter more than the action list.

## Layout

| Path | What | Owner during parallel builds |
|---|---|---|
| `Sources/EdgyCore/` | Shared contracts: touch, gesture, action, config, trace types | **Chief only — frozen** |
| `Sources/TouchKit/` + `Sources/EdgyTrace/` | Raw touch input, hot-plug, pointer guard, typing source, trace recorder CLI | EDGY-TOUCH |
| `Sources/Gestures/` | Pure gesture pipeline + misfire defense | EDGY-GESTURE |
| `Sources/Actions/` | Action registry + system outputs | EDGY-ACTIONS |
| `Sources/EdgyRuntime/` + `Sources/EdgyApp/` + `Resources/` | Config store, router, wiring, menu bar, `.app` bundling | EDGY-APP |
| `Fixtures/traces/` | Real recorded touch traces (JSON, `TraceFile` schema) | EDGY-TOUCH writes, everyone reads |
| `.parallel-plans/` | Shared build briefs, done reports, blockers | Chief writes briefs; batches write their own done/blocker files |

## Verification

```bash
swift build && swift test && swift format lint --strict -r Sources Tests Package.swift
```
Formatting: `swift format format -i -r Sources Tests Package.swift` (config in `.swift-format`).

## Hard rules

1. **Never touch the user's real system from tests.** Every system output (volume, brightness, mute, media keys, HUD, haptics, Shortcuts, event taps, cursor) sits behind a protocol. Tests use mocks only. Live paths are exercised by manual `scripts/smoke-*.sh` scripts that the human runs.
2. **Frozen contracts.** `Sources/EdgyCore/**`, `Package.swift`, and the `makeLive…` / `makeGestureRecognizer` factory signatures change only on `main`, by the chief. Need a change? Write a blocker note and stop.
3. **Own work only.** Outside open-source code is reference for learning, never copied or ported. Write everything fresh.
4. **No third-party product names** anywhere in this repo — code, comments, docs, commits. Before every commit: `git grep -niE "$(paste -sd'|' ~/.config/edgy-names-denylist)"` must return nothing. The denylist lives outside the repo on purpose (it contains the names).
5. **Units:** gesture geometry in millimetres (sensor size from the device), time in milliseconds in settings, seconds in timestamps.
6. **Private frameworks** (MultitouchSupport, DisplayServices, OSD helper) are loaded at runtime by name through `CFBundle` function lookup — never linked. Every lookup failure degrades gracefully with a logged reason.
7. **Signing:** dev builds are signed with the local "Apple Development" identity (so Accessibility grants survive rebuilds). Never ad-hoc for anything that needs TCC.
