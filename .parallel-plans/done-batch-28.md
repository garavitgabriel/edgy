---
batch: 28
branch: worktree-edgy-quiet
worktree_path: .claude/worktrees/edgy-quiet
completed_at: 2026-11-09
verification: swift build ✔ · swift test ✔ (0 failures) · swift format lint --strict ✔ · denylist prints nothing
status: code items done; live after-measurements of the five states with hands off open (chief/Gabriel run them; see blockers-batch-28.md)
---

# Done: batch 28, EDGY-QUIET

## Items

- [x] **1. Measure.** `scripts/measure-idle.sh [max-cpu] [max-wakeups] [seconds]`: `top -l` samples once a second for 20 s, prints the averages, exits 1 over budget (2 if Edgy isn't running). Read-only.
  - **Before** (the Edgy already running on this Mac, pid 59025, started 20:06, pre-batch-28 build; window state not checked): **0.37% CPU, 732 idle wakeups/s**. Over the 50/s no-window budget.
  - **Before, explained:** `sample Edgy 5` of that process. The main thread's timer work is the 30 Hz `RunLoopClock` calling `OverlayController.pump()` (`__CFRunLoopDoTimer → __NSFireTimer → RunLoopClock.startTicking closure → OverlayController.pump`, 37 of 43 timer samples). That is cause 1 in the backlog, and item 2 removes it.
  - **After (partial, not a valid idle reading):** this branch's release build (`scripts/bundle.sh`, Apple Development signed), launched briefly in place of the running app and measured twice for 20 s each: **0 idle wakeups/s** both times (before: 732/s), CPU 1.74% then 6.85%. Not idle: `ioreg` HIDIdleTime read 0 s (Gabriel was using the trackpad) and a mirror view was open. The sample shows the CPU was SwiftUI layout of `PadMirrorView`/`MiniMirrorView` driven by `SettingsModel.receive` (live touch frames: real changes, the mirror following fingers). No timer frames. The no-window and window-open budgets still need a measurement with hands off the Mac and the window state known.
  - Per the chief (2026-11-09): the live states are run by the chief or Gabriel. This session no longer launches or quits Edgy.
- [x] **2. Event-driven overlay.** `OverlayController` no longer ticks from `start()`. A `withObservationTracking` on `model.decisionSerial` wakes it, and it registers again on every wake. The clock starts when a plate is up and stops when the timeline is empty and no display check is showing. `LiveScreens` is read at start, when a new plate appears and on `didChangeScreenParametersNotification`, never on a tick. Fades are unchanged (same timeline, same 30 Hz while something is up).
  - Tests: `overlayClockIsStoppedWhenIdleAndStartsOnADecision` (fake clock: `starts == 0` while idle), `overlayWakesOnADecisionWithoutAClock`, `overlayReadsScreensOnlyWhenAPlateAppears`.
  - Ruling change: `stopTakesEverythingDown` now expects `!clock.ticking` after `start()`. The old `#expect(clock.ticking)` is kept beside it as a comment naming batch 28.
  - Onboarding no longer calls `model.stopFeed()` on close (old line kept as a comment). The overlay used to restart the feed on every tick. It no longer ticks, so a stopped feed would leave it deaf. The feed costs nothing while no finger is down.
- [x] **3. Redraw only on real change.** `mirrorCatalog`, `mirrorGroups` (cached `catalogByCategory`), `mirrorAvailability(of:)` and `mirrorZones(...)` are cached in a `MirrorDataCache` keyed by `(revision, engineStatus)`. The model's stored state is frozen, so the cache sits beside it in a per-model table with weak owners. The picker and inspector read the cached groups and availability. `LiveBrightnessOutput.builtInDisplay()` goes through `BuiltInDisplayCache`, which is invalidated by `CGDisplayRegisterReconfigurationCallback`. The remaining observation loops (menu glyph, onboarding Try it) are already event-driven.
  - Tests: `mirrorDataIsComputedOnceForManyBodyEvaluationsAtOneRevision`, `cachedMirrorDataMatchesTheEditor`, `identicalFramesProduceNoObservationChange`, `builtInDisplayIsReadOnceUntilTheDisplaysChange`.
- [x] **4. Input off the main thread.** New `TouchKit/InputRunLoop` is a dedicated user-interactive thread with its own CFRunLoop. The pointer-guard tap (`LiveEventTap`) and the opt-in run-loop multitouch scheduling (`EDGY_MT_RUNLOOP=1`) now run on it. The default multitouch callback was already off main. The key-recorder tap runs on `Actions.KeyTapRunLoop`, the same shape, because Actions doesn't depend on TouchKit and `Package.swift` is frozen. All shared state was already lock-protected (`PointerGuardCore.lock`, `LiveEventTap.lock`, `KeyComboRecorder` recursive lock), so ordering is unchanged. A tap disabled by timeout or user input is re-enabled every time and logged once. The switcher's interrupt monitors are listen-only `NSEvent` global monitors that never hold a pointer event, so they stay on main. No EdgyCore/Gestures contract change was needed.
  - Tests: `inputRunLoopRunsWorkOffTheMainThread`, `pointerGuardTapDisabledByTimeoutIsReEnabledEveryTime` (plus the existing `reEnablesTapWhenSystemDisablesIt`), `keyTapDisabledByTimeoutIsReEnabled`, `keyTapRunLoopIsNotMain`.
- [x] **5. App chooser empty list.** **Not reproduced live in this session** (no UI driving). Cause from reading the code: the list was loaded by the *field's* `.task` and handed to the popover by value. The popover opened with `apps == []`, and nothing in the open popover owned the load. The parent inspector was re-rendering 30×/s (causes 1–2 in the backlog) while ~200 non-lazy rows each read an icon synchronously on main. Fix: `AppListView` loads from the provider when it opens and shows "Loading apps…" in `ink2` until the apps arrive. Rows sit in a `LazyVStack` with section-scoped stable IDs (`"Running|id"`, `"All apps|id"`). Live lists read icons off main through `AppIconCache`, which caches them (environment `appIconsLoadOffMain`). Fixed lists in snapshots still read in place, so the shots don't change.
  - Tests: `threeHundredAppsLoadWellWithinTheBudget`, `rowIDsAreUniqueAcrossTheTwoSections`, `searchFiltersBothSections`, `aSlowProviderShowsLoadingUntilTheAppsArrive`, `iconsAreReadOnceAndCached`.
  - Add-app was already lazy, with section-scoped IDs (`ListRow(section:app:)`), and already loads on show. Its live list now loads icons off main (`appIconsLoadOffMain` when it loads from `model.installedApps`). `AppMark` (add-app rows, popover chips, window tabs) reads each icon once through `AppIconCache` instead of calling `NSWorkspace.icon` on every body evaluation. Fixed lists in snapshots still read in place, and no shot changed. The 300 ms open-to-visible check is not asserted in tests: an await under the parallel runner measured 0.69 s of runner contention. Only the synchronous row build is timed (< 30 ms).
- [x] **6. Batch 26 follow-ups.** The Router keeps a Switch Apps slide (`opensOnTravel = ["apps.switcher"]`) silent until the action first reports an outcome. That means no `gestureCaught` and no `actionRan(outcome: nil)` at `.began`, and the opening's update is reported as the gesture's first step. Failures at the start are still reported. Test Mode still reports `wouldRun` at the start. `switcherAppCount()` is read in `openSwitcher`. settings-reference covers both and notes that sensitivity scales the opening travel (×2 opens at 4 mm).
  - Tests: `Batch28RouterTests` (4), `switcherCountsAppsOnlyWhenItOpens`.

## Verification
`swift build && swift test && swift format lint --strict -r Sources Tests Package.swift` ran green in this transcript (0 ✘). `git grep -niE -f ~/.config/edgy-names-denylist` printed nothing. `git status` shows no build-shot changes, so no shot was re-rendered differently.

## Needs Gabriel (live)
1. Build release, install, launch. Then, touching nothing, run each of these:
   - No window: `scripts/measure-idle.sh 0.5 50`
   - Popover open: `scripts/measure-idle.sh 3 150`
   - Settings open: `scripts/measure-idle.sh 3 150`
   - Settings with Open App → "Choose an app" open: `scripts/measure-idle.sh 3 150`
   - Onboarding open (`defaults delete com.garavit.edgy onboardingDone` or the app's key, relaunch): `scripts/measure-idle.sh 3 150`

   For the "before" column, run the same five states on the previous build. If one is over budget: `sample Edgy 5 -file /tmp/edgy.sample` and check what remains.
2. App chooser: open Open App → "Choose an app" and confirm the list appears (with "Loading apps…" first if slow). If it was empty before, note whether this fixes it.
3. Pointer feel with Settings open while sliding: no lag. Check `log show` for "turned it back on".

## Decisions
- The mirror cache is keyed on `engineStatus` as well as `revision`. A status change (device or pause) recomputes once, which is cheap and correct for availability.
- The key-tap thread is duplicated in Actions rather than shared, because the frozen Package.swift forbids a new dependency.
