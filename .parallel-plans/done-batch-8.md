---
batch: 8
branch: worktree-edgy-displays
worktree_path: /Users/gabrielgaravit/Projects/edgy/.claude/worktrees/edgy-displays
completed_at: 2026-11-06 20:49
verification: pass
---

## Acceptance criteria
- [✓] **≥ 20 tests on fakes:** 49 new (50 in `Tests/DisplaysTests`; the existing `placeholderReportsNoDisplays` is unchanged and passes). Seams faked: `FakeDisplaySystem` (CoreGraphics), `FakeBacklight` (DisplayServices), `FakeRegistry` (IORegistry), `FakeMonitor` (I²C/DDC transport), `ManualScheduler` (clock).
  - Classification built-in / Apple / third-party: `classifiesBuiltInAppleAndThirdPartyDisplays`.
  - DDC packet build + reply parse (fixtures hand-computed, not built by the code under test): `setVCPPacketMatchesHandComputedBytes`, `setVCPPacketSplitsSixteenBitValues`, `getVCPRequestMatchesHandComputedBytes`, `parsesValidGetVCPReply`, `parseIgnoresTrailingPadding`, `parseRejectsBadChecksum`, `parseRejectsCorruptedPayloadThroughChecksum`, `parseRejectsWrongVCPCode`, `parseRejectsWrongOpcode`, `parseRejectsShortReply`, `parseReportsUnsupportedFeature`, `parseAcceptsMaximumZeroForTheCallerToReject` + `zeroMaximumIsNotControllable` (max = 0).
  - Coalescing (10 rapid sets → 1–2 writes, last wins): `tenRapidSetsCoalesceToOneWriteWithTheLastValue`, `setsArrivingDuringAWriteCoalesceBehindIt`, `rapidSlideCoalescesAtTheMonitor` (through the controller).
  - Write spacing via injected clock: `writesAreSpacedByTheConfiguredInterval`, `idleQueueWritesImmediately`.
  - Bounded retry then error: `failedWriteRetriesBoundedTimesThenReportsOnce`, `retrySucceedsWithoutReportingFailure`, `newerValueReplacesAPendingRetry`, `failedWritesSurfaceOnceOnTheNextCall`.
  - Never blocks: `submitNeverWritesOnTheCallersStack`, `ddcSetUpdatesCacheAtOnceAndWritesLater`.
  - Probe failure → not controllable with the right reason: `silentMonitorIsNotControllableWithDDCReason`, `readErrorIsNotControllable`, `unsupportedLuminanceGetsItsOwnReason`, `zeroMaximumIsNotControllable`, `monitorWithoutAnAVServiceIsBlamedOnTheConnection`, `unopenableAVServiceIsNotControllable`, `unreadableBacklightIsNotControllable`.
  - Reconfiguration re-probes (debounced): `reconfigurationBurstReprobesOnceAfterDebounce`, `reprobePicksUpAMonitorThatStartedResponding`.
  - `activeDisplayID`: `activeDisplayIsTheOneUnderThePointer`, `activeDisplayFallsBackToMain`, `noDisplaysMeansNoActiveDisplay`.
  - Intel reason: `intelMacReportsAppleSiliconReasonWithoutTouchingTheRegistry`.
  - Also: reads cached (`ddcReadsAreCachedAfterTheProbe`), naming (`namesComeFromMacOSThenRegistryThenFallback`, `unnamedExternalFallsBackToDisplayNumber`), registry pairing + matching incl. two identical monitors and serial tiebreak (`AVServiceMatchingTests`), errors, lazy construction (`constructionHasNoSideEffects`, `liveFactoryReturnsTheLiveControllerWithoutProbing`).
- [✓] **No test touches real displays or I²C.** Tests construct `LiveDisplayBrightness` only with fakes. The one live-factory test only constructs: every live type is an empty value and private symbols are `static let` (resolved on first method call).
- [✓] Discovery (CoreGraphics), classification, names, debounced re-probe on `CGDisplayRegisterReconfigurationCallback`, `activeDisplayID` = display under the pointer → main → first.
- [✓] Built-in + Apple external through DisplayServices (runtime lookup); probe = a successful read.
- [✓] Third-party through DDC/CI on Apple silicon: IORegistry AV service + `IOAVServiceReadI2C` / `IOAVServiceWriteI2C` / `IOAVServiceCreateWithService` (runtime CFBundle lookup in IOKit, never linked); VCP `0x10` read current + max, write current; per-display coalescing write queue (50 ms spacing, 3 attempts, never blocks); reads cached after the probe, writes update the cache optimistically.
- [✓] Intel: third-party displays report `brightnessControllable: false`, "External brightness needs an Apple silicon Mac."
- [✓] Factory body replaced (`LiveDisplayBrightness(environment: .live())`); contract types and signature untouched; construction has no side effects.
- [✓] `edgy-displays` CLI: `list`, `get <id>`, `set <id> <0…1>`, `nudge [id]`. `scripts/smoke-displays.sh` (asks before each step, restores on exit/Ctrl-C).
- [✓] Verification triple green, denylist clean.

## Verification
Run in this session, on the final tree:
- `swift build` → `Build complete!`, exit 0.
- `swift test` → exit 0. Per target: 6, 35, 75, 13, **50 (Displays)**, 89 — all passed.
- `swift format lint --strict -r Sources Tests Package.swift` → exit 0, no output.
- `git grep -niE -f ~/.config/edgy-names-denylist` → no output.
- `edgy-displays` with no arguments prints usage (no display access). I did **not** run `list`/`get`/`set`/`nudge`: they talk to real displays and I²C.

## Diff summary
- `Sources/Displays/Displays.swift` — factory body only.
- `Sources/Displays/DDC.swift` — pure DDC/CI framing: set-VCP / get-VCP request builders, checksum, get-VCP reply parser with typed errors.
- `Sources/Displays/Scheduler.swift` — `Scheduler` protocol (monotonic clock + deferred work) and `DispatchScheduler`.
- `Sources/Displays/DDCWriteQueue.swift` — coalescing, spaced, retrying per-monitor write queue.
- `Sources/Displays/Seams.swift` — internal seams: `DisplaySystem`, `BacklightService`, `DDCTransport`, `AVServiceRegistry`, `RegistryNode`, `DisplayEnvironment`.
- `Sources/Displays/AVServiceMatching.swift` — pairs registry AV services with display attributes; assigns them to CoreGraphics displays.
- `Sources/Displays/DisplayBrightnessController.swift` — `LiveDisplayBrightness`, `DDCDevice` (read retries), `DDCDisplayChannel` (cache + queue), user-facing reasons.
- `Sources/Displays/LiveSystem.swift` — live CoreGraphics, DisplayServices, IORegistry walk, I²C transport.
- `Sources/EdgyDisplaysCLI/main.swift`, `scripts/smoke-displays.sh`.
- `Tests/DisplaysTests/` — `DDCTests`, `DDCWriteQueueTests`, `DisplayBrightnessControllerTests`, `AVServiceMatchingTests`, `Fakes`, `ManualScheduler`.

## Decisions I made (and why)
- **Write failures surface on the next call.** When a queued DDC write fails all 3 attempts, it is logged, and the next `brightness(of:)` or `setBrightness` for that display throws `.failed(id, "The monitor stopped accepting brightness changes.")` once (that call does nothing else); later calls work normally. The caller never blocks, and the error still reaches Actions.
- **Registry pairing keys off the `DisplayAttributes` property, not a framebuffer class name.** Class names differ between chip generations (this M4 Pro uses `IOMobileFramebufferShim`). Each external `DCPAVServiceProxy` (`Location = "External"`) is paired with the most recent attributes before it in registry order; internal services use up their attributes. The service class name is the one hard-coded registry class.
- **Matching to CoreGraphics:** vendor + product + serial (non-zero serial only), then vendor + product in order (identical monitors, zero serials), then attribute-less services in order. Vendor = `LegacyManufacturerID`, product = `ProductID`, serial = `SerialNumber`.
- **"Adapter or dock" reason** = a third-party display with no matching AV service. This is the only case we can tell from the Mac's side. Wording: "Edgy can't reach this monitor's controls. It may be connected through an adapter or dock that blocks brightness control." A monitor that has a service but doesn't answer gets the DDC/CI-menu reason from the brief. "Unsupported" (the monitor answered "no") and "max = 0" get their own reasons.
- **Classification:** built-in = `CGDisplayIsBuiltin`; Apple external = vendor `0x610`; everything else third-party. Apple externals still need a successful DisplayServices read to count as controllable.
- **Names:** `NSScreen.localizedName` only on the main thread (AppKit is main-actor), else the registry `ProductName`, else "Built-in Display" / "Display N". Never `DispatchQueue.main.sync`.
- **Probing:** lazy on first call, serialized by a probe lock so concurrent first callers probe once. The first call can block for one DDC read per third-party monitor (≈50 ms, up to 3 attempts ≈ 300 ms for a silent monitor). Re-probes after reconfiguration run on a background queue; callers keep the old snapshot until the new one is published. A definite "unsupported" reply is not retried.
- **Reconfiguration:** ignores the "begin configuration" callback; 0.5 s debounce, so a burst of callbacks re-probes once; a re-probe re-reads DDC (refreshing values changed with the monitor's own buttons) and makes fresh write queues.
- **Spacing** is measured from the end of one write to the start of the next (50 ms, constant). The idle queue writes at once (asynchronously).
- **One I²C transfer at a time across all monitors** (a process-wide lock in the live transport). This is simpler and safer than per-monitor locks, and fast enough at 50 ms spacing.
- Kept `UnavailableDisplayBrightness` (frozen file, and an existing test uses it).

### Design note: software (gamma) dimming fallback — not built
Worth it only as an explicit, opt-in "dim" for monitors that refuse DDC, not as a silent fallback. It can only darken (never above the monitor's own setting), so a "brightness" slide would be lopsided. It fights night-shift-like color temperature and color-profile tools: they own the same gamma table, and whichever writes last wins. Changes are lost when another app or a display reconfiguration resets the table, so it would need re-application. It also doesn't save power or reduce backlight glare. If built: label it "Dim (software)", reapply on reconfiguration, restore the table on quit/crash (atexit + signal), and expose it as `.limited(reason:)` availability. My recommendation: skip for v0.3, revisit if users with DDC-less monitors ask.

## Needs Gabriel
- **Mac mini + third-party monitor:** run `scripts/smoke-displays.sh`. Record the monitor model, the port/cable/adapter, what `list` reports (kind, controllable, reason), and whether the nudge was visible. If it says "not controllable", check the monitor's own menu for a DDC/CI setting and rerun.
- **MacBook Pro (built-in):** run `scripts/smoke-displays.sh`; the built-in should be `builtIn`, controllable, and nudge visibly. If an external monitor is attached, it exercises the DDC path too.
- Unplug or replug a monitor while the app is running (after Actions wires this in), then check that `/usr/bin/log show --last 5m --predicate 'subsystem == "com.garavit.edgy" && category == "displays"' --info` shows one re-probe.

## Open questions
- **Unverified on hardware** (each is a single named constant or line): the reply read sub-address (`LiveI2CTransport.readOffset = 0x51`), the reply read length (11 bytes, `DDC.getVCPReplyLength`), the 50 ms reply delay (`DisplayEnvironment.replyDelay`), and that `CGDisplayVendorNumber`/`ModelNumber` equal the registry's `LegacyManufacturerID`/`ProductID`. If the smoke test says "can't reach this monitor's controls" for a cable-connected monitor, matching is the first suspect: the registry dump showed the expected keys on this machine, but nothing compared the values.
- The registry-order pairing (display attributes listed before their AV service) matches this machine's tree. A different chip may lay it out differently. The fallback (attribute-less services in order) covers a single monitor, not two.
- **Registry-walk cost (unmeasured):** the first probe and every re-probe walk the whole IOService plane and read a property from each entry, synchronously on the first caller. With the DDC reads, the first `displays()` call from Actions at launch could take around half a second. If it's slow, find the `DCPAVServiceProxy` services first and locate their attributes with `IORegistryEntrySearchCFProperty` on their parents, or warm the probe at app launch off the action thread.
- For the chief: Actions can now route the built-in panel through `DisplayBrightnessControlling` too (DisplayServices behind the same API), so `LiveBrightnessOutput` could go. That's batch 7's call.
