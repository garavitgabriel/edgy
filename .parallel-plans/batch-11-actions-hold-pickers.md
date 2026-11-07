# Batch 11 — EDGY-ACTIONS-4: modifier-only hold, watchdogs, "Do nothing", pickers for the UI

Read `CLAUDE.md`, `.parallel-plans/2026-11-07-edgy-v04.md`, then `done-batch-7.md`. You own `Sources/Actions/**`, `Tests/ActionsTests/**`, `scripts/smoke-actions.sh`. Keep the module's style: protocol per output, live impl, mock, registry dispatch, catalog descriptors.

## Build

1. **Modifier-only hold.** `KeyCombo` can now be modifiers alone (`"fn"`, `"ctrl+opt"`). `keyboard.hold` with a modifier-only combo must press and release those modifiers the way the physical keys do, so a dictation app that listens for its push-to-talk key (often `fn` alone) sees it: modifier key-down/up events with the right key codes **and** the matching flags-changed state (fn = the secondary-fn flag). Verify on this macOS which event shape a listening app sees for `fn` and document it; pick the route a key-listening app actually receives. `keyboard.shortcut` / `slideSteps` with a modifier-only combo → `ActionError.unavailable("…needs a key…")` (validation will also flag it; see batch 12).
2. **Watchdogs.** `keyboard.hold`: new optional parameter `maxSeconds` (number 5…600, default 120, displayName "Release after"): if no up arrives, release and log once. `apps.switcher`: if a session gets no event for 10 s (named constant), release the command key (and send escape) — never leave a modifier stuck. Both use an injected clock/scheduler; tests drive time.
3. **"Do nothing".** Add a catalog descriptor for `ActionID.doNothing` (`edgy.none`), display name "Do nothing", category `system`, shape `trigger`, no parameters, availability always `.available`; performing it is a no-op (it is normally dropped before it reaches you). Pin the catalog (34 actions). Runtime (batch 12) makes it compatible with every gesture.
4. **Pickers (data for the UI, no views).** Public, `Sendable`, behind protocols with live impl + fake, constructed without side effects:
   - `InstalledAppsProviding`: apps the user can choose for `app.open` and for per-app profiles — name, bundle ID, path, whether running — from the standard application folders + running apps, deduplicated by bundle ID, sorted by name. Async, off main.
   - `ShortcutsListing`: the user's Shortcuts names for `shortcut.run` (via the system `shortcuts` command with `list`; timeout; empty list + reason on failure).
   - `KeyComboRecording`: a recorder model for the "press keys" field — `start` → stream of live states (modifiers held so far) → completes with a `KeyCombo` when a key goes down with modifiers, or with a **modifier-only** combo when all held modifiers are released without a key (e.g. press and release `fn`), cancels on escape alone, times out. Pure state machine (input = key/flags events) fully unit-tested; the live event source (listen-only tap) behind a protocol, installed only while recording.
5. `scripts/smoke-actions.sh`: steps for `fn`-only hold (with a dictation app set to `fn`), the hold watchdog (set `maxSeconds` 5), the recorder (prints the recorded combo), installed-apps and Shortcuts listing.

## Acceptance
- ≥ 25 new tests on mocks: modifier-only hold down/up event order and flags for `fn`, `ctrl+opt`, mixed; double-down releases first; watchdog fires once at `maxSeconds` and not after a normal up; switcher watchdog releases + escape; `doNothing` descriptor + no-op; recorder state machine (combo, modifier-only on release, escape cancel, timeout, ignores key-repeat); installed apps dedup/sort on a fake filesystem/workspace; Shortcuts parsing (names with spaces/unicode, empty, failure, timeout) on a fake process runner.
- Catalog pinned at 34; existing tests unchanged in intent; no-live-outputs guard covers every new live type.
- Verification triple green, denylist clean.
- Done report "Needs Gabriel": the smoke steps; which event route a dictation app's `fn` listener receives.
