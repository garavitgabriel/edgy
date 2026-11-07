# Batch 8 — EDGY-DISPLAYS: brightness for every attached display

Read `CLAUDE.md` and `.parallel-plans/2026-11-06-edgy-v03.md` first. You own `Sources/Displays/**`, `Sources/EdgyDisplaysCLI/**`, `Tests/DisplaysTests/**`, `scripts/smoke-displays.sh`. The contract types in `Sources/Displays/Displays.swift` (`DisplayInfo`, `DisplayBrightnessControlling`, `DisplayBrightnessError`) and the `makeLiveDisplayBrightness()` signature are **frozen** — Actions is building against them now. Replace the factory body; add everything else in new files.

Context: Gabriel's Mac mini drives a third-party monitor; the keyboard brightness keys do nothing on it. A MacBook's built-in panel already works through DisplayServices in Actions — your module must also handle it so Actions can route every display through one place.

## Build

1. **Discovery.** Enumerate online displays (CoreGraphics), classify `builtIn` / `appleExternal` / `thirdParty`, give each a human name (from the display's own info, fallback "Display N"). Re-probe on reconfiguration (`CGDisplayRegisterReconfigurationCallback`), debounced. `activeDisplayID()` = display containing the pointer, else main.
2. **Built-in + Apple external:** DisplayServices brightness get/set (runtime lookup by name). Probe = a successful read.
3. **Third-party (DDC/CI) on Apple silicon:** find the display's AV service in the IORegistry and talk DDC/CI over I²C with the private IOAVService read/write functions (runtime lookup). VCP code `0x10` (luminance): read current + max, write current. Implement the DDC packet framing and checksum yourself (pure, unit-tested: build a set-VCP packet, parse a get-VCP reply incl. bad checksum / wrong opcode / short reply). Monitors are slow and flaky: a write queue per display that **coalesces** (only the latest value matters), spaces writes (≥ ~50 ms, constant), retries a failed write a bounded number of times, and never blocks the caller. Reads cached after the first successful read; writes update the cache optimistically.
   Intel Macs: out of scope — report `brightnessControllable: false`, reason "External brightness needs an Apple silicon Mac."
4. **Probing and reasons.** A display is controllable only if a probe read succeeded. Reasons are plain language, ready for the settings UI ("This monitor doesn't respond to brightness control over its cable. Some monitors need DDC/CI turned on in their own menu.", "Connected through an adapter or dock that blocks brightness control." when you can tell).
5. **Software dimming: not in this batch.** Leave a short design note in the done report on whether a gamma-based dimming fallback is worth it (it can't brighten, and it fights night-shift-like features).
6. Replace the factory body to return the live implementation. Construction has no side effects; everything probes lazily on first call.
7. **`edgy-displays` CLI** (`Sources/EdgyDisplaysCLI/**`, yours; target already in `Package.swift`): `list` (kind / controllable / reason / current brightness), `get <id>`, `set <id> <0…1>`, `nudge` (active display −10% then back). `scripts/smoke-displays.sh` (manual, asks before each step) drives it: list, read, nudge each controllable display and restore.

## Acceptance
- ≥ 20 tests on fakes (inject the IORegistry / I²C / DisplayServices / CoreGraphics layers behind internal protocols): classification of built-in / Apple / third-party; DDC packet build + reply parse (valid, bad checksum, wrong VCP, short, max = 0); coalescing (10 rapid sets → 1–2 writes, last value wins); write spacing via an injected clock; bounded retry then error; probe failure → not controllable with the right reason; reconfiguration re-probes; `activeDisplayID` choice; Intel path reason.
- No test touches real displays or I²C.
- Verification triple green, denylist clean.
- Done report "Needs Gabriel": run `scripts/smoke-displays.sh` on the Mac mini with his monitor (record the monitor model and whether DDC/CI worked) and on the MacBook Pro (built-in).
