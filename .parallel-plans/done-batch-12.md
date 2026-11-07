---
batch: 12
tag: EDGY-RUNTIME-2
branch: worktree-edgy-runtime-v04
worktree_path: /Users/gabrielgaravit/Projects/edgy/.claude/worktrees/edgy-runtime-v04
completed_at: 2026-11-07
verification: pass
---

## Acceptance criteria
- [✓] **≥ 30 new tests: 81 new** (EdgyRuntimeTests 114 → 195).
  - Overrides, turn off, revert, effective-binding sources, undo: `ProfileOverrideTests` (15), including `fullReplaceProfilesStillBehaveExactlyAsBefore`, `convertToInheritingKeepsTheAppBehavingTheSame` and `undoAndRedoCoverOverrideTurnOffAndRevert`.
  - Validation: `DoNothingValidationTests` (5), `ModifierOnlyComboTests` (4), `ConflictNoteTests` (8), `InheritingValidationTests` (4).
  - Engine context `doubleTapZones` and routing through resolved profiles: `DoubleTapZonesContextTests` (5).
  - Feed: `LiveFeedTests` (13) and `FeedZoneGeometryTests` (3). They cover the 60 Hz throttle, decisions that are never throttled, no cost without observers, decisions mapped from `GestureOutput` and router results, sticky rejection state, and the zone where a touch landed.
  - Test Mode: `TestModeTests` (8). Nothing runs, holds get no down/up, the caught tick still fires, toggling mid-hold or mid-slide is safe, status reflects the mode, and the mode survives a registry swap.
  - Availability notifications: `AvailabilityNotificationTests` (3).
  - Audit walk: `SettingsAuditTests` (6).
- [✓] `docs/settings-reference.md` is complete. `theReferenceDocumentsEverySettingAndCode` fails if a field, validation code or editor method goes undocumented. The Mirror walks fail if a field is added to `AppSettings` or `GestureSettings` without an edit entry.
- [✓] Existing runtime tests keep their intent. 5 were edited (listed below).
- [✓] Verification triple green, denylist clean.
- [~] **One blocker, partial:** the audit walk covers every parameter *kind* (fake catalog) but not the real catalog. Runtime tests can't import `Actions`, and `IntegrationTests` is off-limits. A ready-to-paste test for the chief is in `blockers-batch-12.md`. Nothing outside the allowed glob was touched.

## Verification
- `swift build`: `Build complete!`
- `swift test`: every target passes: 48, 6, 64, **195 EdgyRuntimeTests**, 19, 50, 156 (integration).
- `swift format lint --strict -r Sources Tests Package.swift`: exit 0.
- `git grep -niE -f ~/.config/edgy-names-denylist`: no output.
- `git diff --name-only 7432e8a..HEAD` lists only `Sources/EdgyRuntime/**`, `Tests/EdgyRuntimeTests/**` and `docs/settings-reference.md`.

## Existing tests edited (intent unchanged)
| Test | Change | Why |
|---|---|---|
| `SettingsEditorTests.appProfilesAddRemoveAndDisable` | calls `addAppProfile(bundleID:copyingDefault: false)` | The bare call now makes an inheriting profile. The explicit old path still tests exactly the old behaviour. |
| `SettingsEditorTests.resetProfileAndResetAll` | same | same |
| `SettingsEditorTests.preexistingErrorsAreExposedButDontBlockOtherEdits` | filters `.info` issues | Its bottom-edge tap now also gets a `tapWaitsForDoubleTap` note, which is not a problem. |
| `SettingsEditorTests.catalogQueries` | expects `doNothing` last; count 7 → 8 | `compatibleActions` lists "do nothing" last (brief). |
| `HoldValidationTests.compatibleActionsOfferHoldsOnLongPressOnly` | count + 1, `.last == .doNothing`, slide check uses `dropLast()` | same |

`everyCodeIsReachable` needed no edit. Its config already has a tap and a double-tap on the top edge, so it reaches the new code.

## Public API (additive unless noted)
- **Validation:** `ValidationIssue.Severity.info`; `Code.tapWaitsForDoubleTap`; `ValidationIssue.detail` (a defaulted init parameter); `ValidationIssue.modifierOnlyNeedsHold`; `ConfigValidator.conflictNotes(in:as:settings:involving:)`; `ConfigValidator.doNothingFallback`.
- **SettingsEditor:**
  - **Behaviour change:** `addAppProfile(bundleID:)` now creates an *inheriting* profile. `addAppProfile(bundleID:startingAs: .inheriting | .copyOfDefault | .empty)` is new, and `addAppProfile(bundleID:copyingDefault:)` keeps the old full-replace path.
  - New: `overrideBinding(_:forApp:)`, `turnOff(_:forApp:)`, `revertToDefault(_:forApp:)`, `convertToInheriting(bundleID:)` and `effectiveBindings(forApp:) -> [EffectiveBinding]` (`source`: `inherited` / `overridden` / `turnedOff` / `appOnly`, plus `defaultBinding`).
  - `refreshAvailability()` now returns `Bool` (`@discardableResult`) and notifies with the new `SettingsChange.Cause.availability`.
- **Engine:** `setTestMode(_:)`, `isTestMode`, `EngineStatus.testMode`, `observeFeed(on:_:) -> UUID`, `removeFeedObserver(_:)`, `Engine.feedTouchInterval`. Feed types are in `LiveFeed.swift`: `LiveFeedUpdate`, `LiveTouchFrame`, `LiveTouch`, `LiveDecision`.
- **Router:** `testMode` (`public internal(set)`, set only through the engine).

### Feed example (chief wires into the settings window)
```swift
let token = engine.observeFeed { update in          // main queue by default
  if let frame = update.touches {                    // ≤ 60 Hz per device; empty touches = clear
    mirror.show(frame.deviceID, frame.touches)       // LiveTouch: id, position (0…1), .down/.claimed/.rejected
  }
  for decision in update.decisions {                 // never throttled
    switch decision {
    case .recognized(let zone, let kind, let phase, _): log.add("\(kind) \(phase) at \(zone)")
    case .rejected(_, let zone, let reason, _): log.add("rejected \(reason) \(zone.map { "\($0)" } ?? "")")
    case .wouldRun(let id, _, _), .actionRan(let id, _, _): log.add("\(id.rawValue)")
    case .actionFailed(let id, _, _, let message): log.add("\(id.rawValue) failed: \(message)")
    case .actionUnavailable(let id, _, _, let reason): log.add("\(id.rawValue): \(reason)")
    }
  }
}
// window closes:
engine.removeFeedObserver(token)
```

### Test Mode example (menu item + window toggle)
```swift
menuItem.action = { engine.setTestMode(!engine.isTestMode) }    // not persisted
engine.onStatusChange { status in DispatchQueue.main.async { menuItem.state = status.testMode ? .on : .off } }
```

## Late addition: waking the recognizer for a held tap (chief's request after batch 10 merged)
Merged `main` (9c958d8) into this branch, without a rebase. Tests: `DeferredFlushTests` (7). They cover:
- a held tap routes exactly once after the window with no further frames;
- a double-tap routes only the double-tap;
- a newer frame supersedes the wake-up;
- an app change before the flush drops the tap;
- pause, apply, stop and Test Mode each cancel the timer;
- a flushed tap reaches the feed;
- a recognizer that can't flush never schedules.

How it works:
- **`GestureFlushing` (EdgyRuntime) mirrors `DeferredGestureFlushing`.** EdgyRuntime can't import Gestures, and `GesturePipeline` is internal, so the engine checks `recognizer as? GestureFlushing`. **The chief must hand the engine an adapter in EdgyApp**, or the flush never runs:
  ```swift
  final class FlushingRecognizer: GestureRecognizing, GestureFlushing {
    private let inner: GestureRecognizing & DeferredGestureFlushing
    init?(_ r: GestureRecognizing) {
      guard let f = r as? (GestureRecognizing & DeferredGestureFlushing) else { return nil }
      inner = f
    }
    func process(_ f: TouchFrame, device: TouchDeviceInfo, context: GestureContext) -> GestureOutput {
      inner.process(f, device: device, context: context)
    }
    func reset() { inner.reset() }
    var nextFlushDeadline: Double? { inner.nextFlushDeadline }
    func flush(now: Double) -> GestureOutput { inner.flush(now: now) }
  }
  let base = makeGestureRecognizer()
  let recognizer: GestureRecognizing = FlushingRecognizer(base) ?? base
  ```
- **Scheduling:**
  - `Engine.init` gains a defaulted `timer: EngineTimer = DispatchEngineTimer()` (monotonic uptime clock plus a one-shot; tests inject a manual one).
  - After each `process` and each `flush`, the engine reads the deadline and schedules `(deadline − lastFrame.timestamp) − elapsed since that frame arrived + 1 ms of slack`. Without the slack, clock rounding could make a wake-up land a hair early and need a second one.
  - A newer frame cancels and reschedules the wake-up. A generation counter makes a superseded wake-up that already fired do nothing.
- **Firing:**
  - The flush time is `now = lastFrame.timestamp + (monotonic now − arrival)`.
  - The output is handled like a `process` output: pointer guard, routing and feed decisions (decisions only; there is no touch frame).
  - If the frontmost app changed since the last frame, the held gesture is **dropped** (chief's ruling) and the drop is logged.
  - No flush runs while paused, disabled or stopped.
- **Cancelling:** `quiesce` cancels the timer, which covers pause, apply, stop and Test Mode toggles.

## Decisions I made (and why)
- **No `holdAndTriggerOnLongPress` code.** A zone has one long-press slot. A hold fits only a long-press and a trigger would sit in the same slot, so a second binding there is already a `duplicateBinding` error. The combination can't happen within a resolved profile, and the doc says so.
- **"Do nothing"** is valid on every gesture, with or without a catalog entry. It skips `unknownAction`/`shapeMismatch` and is never flagged unavailable, but `gestureNotSupported` still applies. `compatibleActions` lists it last, using the catalog's descriptor when present and `ConfigValidator.doNothingFallback` otherwise. The fallback's display name, "Do Nothing", is placeholder copy, and batch 11's descriptor replaces it once merged. `catalogByCategory` leaves it out.
- **Modifier-only combos** are judged by catalog shape (`.hold`), not by action id. This covers every `keyCombo` parameter (e.g. `keyboard.slideSteps`).
- **Conflict notes are attributed to the profile whose binding causes them.**
  - The default's notes are reported once, on the default.
  - An inheriting app reports only the notes for zones where its own binding is involved, computed on the resolved profile. Turning the default's double-tap off in the app removes the note there.
  - A full-replace app gets its own notes.
  - `detail` is the wait in ms, taken from the clamped window so a non-finite hand-edited value can't trap.
- **Inheriting validation:** an override of a default slot is never a duplicate. Overlaps are checked between the app's own bindings and the default bindings still in effect. `doNothing` bindings never overlap anything.
- **`overrideBinding` / `turnOff` create an inheriting profile** when the app has none, in one undo step. `revertToDefault` needs an existing profile; in a full-replace profile it just removes the binding. `turnOff` always writes `doNothing`, in either profile kind.
- **`resetProfile(.app)`:** an inheriting profile goes back to no overrides. A full-replace profile still becomes a copy of the default, as before.
- **`setTestMode` drops in-flight gestures both ways** (the same quiesce a config apply does). Turning it on releases a real held key. Turning it off mid-slide keeps a continuous action from getting `.changed` without the `.began` it never saw. A finger still down is judged afresh, as after a reload.
- **Test Mode haptics:** one `gestureCaught` per would-be action (a slide at its start, a discrete gesture when it would fire, a hold at `.began`), and never `actionFired`.
- **Feed scope:**
  - The feed is silent while paused, disabled or stopped, because the pipeline isn't running.
  - `startedOutsideZone` rejections (ordinary pointer use) and slide `.changed` events are left out of decisions.
  - `actionRan`/`failed` are reported once per gesture (a discrete firing, a slide's first step, a hold's press). Releases aren't reported.
  - Touches are shown for `starting` / `touching` / `lifting` contacts.
  - The throttle runs on the device clock. One empty frame is sent at lift so the mirror clears.
- **Rejection zone:** the runtime computes it from the contact's landing point, sensor size and settings: a mapped corner square wins, then the finest enabled edge segment. The runtime can't import Gestures. This approximates the recognizer's geometry for display only.
- **Availability notifications** go through a `SettingsChange.Cause.availability` with `config == previous`, and only when the snapshot changed (including a `limited` reason). They are not applied to the engine and not an undo step.

## For the chief's merge step
- **Profile migration:** `editor.convertToInheriting(bundleID:)` migrates the existing copied app profile (keep the bundle ID out of the repo). The app behaves identically afterwards, which is tested.
- **Real-catalog walk:** the parameter walk against the real catalog belongs in `IntegrationTests`. `EdgyRuntimeTests` can't see `Actions`, so the audit walk uses the fake catalog, whose exhaustive `switch` over `ActionParameter.Kind` covers every kind.
- **Catalog docs:** `docs/settings-reference.md` lists main's 33 actions plus `edgy.none`. Add batch 11's new actions to the table.
- **IntegrationTests:** if they assert `compatibleActions` counts or `issues.isEmpty` on a config with a tap and a double-tap in one zone, expect the trailing `doNothing` entry or the `.info` note. Today's integration suite passes unchanged.

## Needs Gabriel
- None, beyond reading `docs/settings-reference.md`.

## Open questions
- Should the feed keep mirroring touches while Edgy is paused or disabled, so the window still shows fingers? It's off today, and turning it on means running a light path when the pipeline is idle.
- Should `turnOff` in a full-replace profile remove the binding instead of writing `doNothing`? Both have the same effect; `doNothing` keeps the effective-bindings row visible as "turned off".
