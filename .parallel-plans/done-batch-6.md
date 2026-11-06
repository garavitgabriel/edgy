---
batch: 6
branch: worktree-edgy-settings
worktree_path: /Users/gabrielgaravit/Projects/edgy/.claude/worktrees/edgy-settings
completed_at: 2026-11-05 21:13
verification: pass
---

## Acceptance criteria
- [✓] ≥ 25 new tests in `Tests/EdgyRuntimeTests/` with fakes: **49 new** (75 total in the target; the 26 existing pass unchanged). Fakes: `FakeCatalog` (defaults' ids + `fake.*` actions covering every parameter kind, served via a fake `ActionPerforming.available`), temp-dir `ConfigStore`, `FakeScheduler` (manual clock), `FakePermissionChecker`, `FailingStore`.
  - Each mutation saves + applies: `setBindingSavesAppliesAndNotifies`, `setBindingReplacesItsSlotInPlace`, `setBindingCanMoveABindingToAnotherSlot`, `removeBindingSavesAndApplies`, `appProfilesAddRemoveAndDisable`, `appSettingsEditsSaveAndClampStrength`, `gestureSettingsEditsAreClamped`.
  - Invalid mutation throws, nothing changes on disk or in memory: `invalidEditThrowsAndChangesNothing`, `failedSaveChangesNothing`.
  - Undo/redo across mutation kinds, redo cleared by new edit, 50-step bound: `undoAndRedoAcrossMutationKinds`, `newEditClearsRedo`, `undoHistoryIsBoundedToFifty`.
  - Coalesced slider edit = one step + debounced saves + final save: `sliderDragIsOneUndoStepWithDebouncedSaves`, `continuousEditWithNoChangeAddsNoStepAndNewKeyEndsTheOld`, `undoDuringDragClosesTheDragFirst`.
  - External edit adopted + undoable, own save not echoed: `externalEditIsAdoptedAndUndoable`, `externalEditMidDragWinsOnDisk`, `reloadFromDiskAdoptsTheFile`, `watcherDeliversHandEditsButNotOwnSaves` (real file watcher, end to end).
  - Every validation code at least once: one test per code group in `ValidationTests` plus `everyCodeIsReachable` (asserts the found set == `ValidationIssue.Code.allCases`).
  - Reset profile / reset all: `resetProfileAndResetAll`.
  - Permission monitor transitions + stops polling once granted: `pollsWhileDeniedAndStopsOnceGranted`, `grantedFromTheStartNeverPolls`, `unknownIsPolledAndRevocationSeenOnRefresh`.
  - Engine status reflects pause/resume and device changes: `statusFollowsStartPauseResumeAndStop`, `statusTracksDeviceHotPlug`, `startFailureIsRecordedAndClearedByASuccessfulStart`.
- [✓] `SettingsEditor` (`Sources/EdgyRuntime/SettingsEditor.swift`): `ProfileRef`, all listed mutations, undo/redo (50), continuous edits with injected scheduler, external-edit adoption, observer callback (`observe` → `SettingsChange` with cause, previous/new config, changed profiles / app / gesture flags). No Combine/SwiftUI.
- [✓] Validation (`Validation.swift`): `ConfigValidator.validate(_:in:)` / `validate(_ config:)`, severities, 17 stable codes (raw values are the contract).
- [✓] UI queries (`SettingsQueries.swift` + editor passthroughs): `bindingsByZone(in:)`, `effectiveProfile(for:)`, `catalogByCategory`, `compatibleActions(zone:gesture:)`, `supportedGestures(for:)`.
- [✓] `PermissionChecking` + `PermissionMonitor` (`Permissions.swift`); live `AccessibilityPermissionChecker` (`AXIsProcessTrusted`) + `AccessibilitySettings.open` in EdgyApp.
- [✓] `EngineStatus` + `Engine.status` / `onStatusChange(_:)`; existing `Engine` API unchanged (`pause()` still compiles — now `pause(until: Date? = nil)`).
- [✓] `AppDelegate` creates the editor; Enabled toggle and Reload Config go through it; watcher reloads go to `adoptExternal`. No direct `store.save` left in the app.
- [✓] `StatusMenu`: "Grant Accessibility…" while not granted (refreshed by the monitor's transitions), disabled "No trackpad found" when the engine sees no trackpad. Plain text.
- [✓] No window, view or onboarding UI built.
- [✓] Verification triple green, denylist clean.

## Verification
- `swift build` → BUILD=0
- `swift test` → TEST=0; five targets all pass (48, 35, **75 EdgyRuntimeTests**, 12, 36)
- `swift format lint --strict -r Sources Tests Package.swift` → LINT=0
- `git grep -niE -f ~/.config/edgy-names-denylist` → no output

## Diff summary
- Added `Sources/EdgyRuntime/`: `Scheduling.swift` (~35), `Validation.swift` (~300), `SettingsQueries.swift` (~90), `SettingsEditor.swift` (~400), `Permissions.swift` (~75).
- Modified `Sources/EdgyRuntime/Engine.swift` (+~90: `EngineStatus`, status callback, `pause(until:)`, `lastStartError`).
- Modified `Sources/EdgyApp/`: `AppDelegate.swift` (rewired through editor, monitor, engine status), `StatusMenu.swift` (two new lines), `SystemIntegration.swift` (live checker + pane opener).
- Tests: added `SettingsFakes.swift`, `ValidationTests.swift`, `SettingsEditorTests.swift`, `StatusTests.swift`; `Fakes.swift` gained an additive `startError` on `FakeTouchSource`.
- ~1,960 lines added across 14 files.

## Decisions I made (and why)
- **`SettingsEditor` is `@MainActor`**, not queue-confined like `Engine`: the app delegate and the future window are main-actor, and the scheduler's closures are `@MainActor @Sendable`. The live scheduler uses `DispatchQueue.main.asyncAfter` + `MainActor.assumeIsolated`.
- **Validation gate = "no new errors".** An edit is refused only for error issues that aren't already in the current config (issue identity = code + profile + zone/gesture + action + parameter). Pre-existing errors from a hand-edited file are exposed in `issues` but never block other edits, so the user can always fix or remove them. Warnings never block.
- **Gesture setting ranges** (`GestureSettingsLimits`; the editor clamps, a hand-edited out-of-range value is a `settingOutOfRange` warning; non-finite → default):

  | Setting | Range |
  |---|---|
  | `edgeWidthMM` | 3…20 mm |
  | `cornerSizeMM` | 5…30 mm |
  | `dwellMS` | 0…1000 ms |
  | `palmMajorAxisMM` | 10…40 mm |
  | `typingSuppressionMS` | 0…3000 ms |
  | `doubleTapWindowMS` | 150…800 ms |
  | `longPressMS` | 250…2000 ms |
  | `fingers` | 1…2 |
- **Reset app profile** = copy of the current default profile's bindings, enabled (matches "add profile, copying default"). Reset default = built-in preset. Reset all = `EdgyConfig.defaults` including app settings.
- **Overlap check is general**: any two different zones on one edge whose segment intervals overlap, same gesture → `overlappingZones` warning (covers whole edge + segment, and e.g. halves vs. thirds).
- Extra codes beyond the brief: `invalidProfileID` (error; app-profile key not a bundle ID) and `settingOutOfRange` (warning).
- `setBinding(_:in:replacing:)` takes an optional old slot so the UI can move a binding to another zone/gesture as one undo step; the binding keeps its list position.
- A continuous edit is closed by `endContinuousEdit`, by starting a different key, by undo/redo, or by an external edit. An external edit mid-drag closes the drag as its own undo step **without** saving it, so the hand edit stays on disk.
- If the final save of a drag fails, the undo step is still recorded (engine and memory already have the value) and the error is rethrown.
- Pause timing stays in `AppDelegate` (it owns the timer); `Engine` just records `pausedUntil` for the status snapshot, and the menu reads it from there.

## Needs Gabriel
- Launch with Accessibility revoked → the menu shows "Grant Accessibility…" → click it (opens Privacy & Security → Accessibility) → grant → the item disappears within ~1.5 s.
  - The item only opens the pane; it does not trigger the system prompt. If Edgy is **not already in the list** (nothing has yet tried an accessibility-gated API), you'll need to add it with "+". Please note which case you hit — if it's the "+" case, we should call the prompting API once on click.
- Hand-edit `~/Library/Application Support/Edgy/config.json` while running → the change applies (and logs "Config reloaded from disk").
- With no trackpad visible to the engine (e.g. lid closed with only a mouse), the menu shows "No trackpad found".

## Open questions / followups
- Undo steps carry no label; if the window wants "Undo Change Binding", add an intent tag per step.
- Catalog is a snapshot taken at launch from `actions.available`; if the registry is ever rebuilt with a different catalog the editor needs an `updateCatalog`.
- `PermissionMonitor` stops polling once granted; a later revocation is seen only through `refresh()` (wired to app activation). Edgy is an accessory app and rarely activates, so a revocation mid-session may go unnoticed until relaunch.
- Chief's planned integration test (every real catalog descriptor through `SettingsEditor` validation) should pass: `ConfigValidator` reads only `id`, `shape`, `category`, `parameters`.
