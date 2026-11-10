---
batch: 32
branch: worktree-edgy-sequence
worktree_path: /Users/gabrielgaravit/Projects/edgy/.claude/worktrees/edgy-sequence
completed_at: 2026-11-09
verification: swift build green; swift format lint --strict green; swift test green except the ONE expected failure, EdgyUITests `everyCatalogActionHasAnIcon` (the `app.last` icon lands on main separately, per the brief); denylist prints nothing
---

## Acceptance criteria
- [✓] **Key sequences on `keyboard.shortcut`**: 1–4 combos separated by one space, e.g. `ctrl+b n` (`ActionRegistry+Sequences.swift`).
  - **One combo is byte-for-byte as before**: one `post`, no scheduling, the same errors, a nil outcome. Text that today's parser reads as one combo (it trims around `+`, so `cmd + c` counts) takes the old path untouched.
  - **2–4 combos**: every step is validated before anything is sent. Step 1 posts synchronously, so its failure throws exactly like a single shortcut's. Each later step is a full `post` (press and release), scheduled `sequenceStepGap` = 40 ms after the previous one on the action scheduler; nothing sleeps.
  - **Failure**: the failed step's key and modifiers are released, minus any a live Hold Keys or open switcher owns, and the rest is dropped.
  - **Re-trigger** while sending is ignored and logged, for any Keyboard Shortcut binding.
  - **Refused** through the existing `ActionError.unavailable`: more than 4 combos, an unparseable step, a modifier-only step, or an empty step from a double space.
- [✓] **`keyboard.hold` and `keyboard.slideSteps` take one combo**: any space in their keys is `unavailable` (`singleCombo`).
- [✓] **`app.last` "Last App"**: Apps category, trigger shape, no parameters, placed right after Open App. Because it is a trigger, it takes tap, double-tap and long-press. With no previous app it returns a nil outcome and never throws.
- [✓] **Smoke steps 35–37** in `scripts/smoke-actions.sh`:
  - 35: a two-step sequence into a terminal multiplexer (prefix you type, then `c`).
  - 36: four steps into a text field (`h i shift+1 return`), with an automatic check that no modifier is stuck.
  - 37: Last App back and forth between two apps, then after one quits.
  - Checked with `bash -n`, plus a typecheck-only compile of the embedded Swift in the scratchpad. I did not run it (human-only).
- [✓] No existing test deleted or weakened.
  - The three catalog pins went from 34 to 35, and `app.last` was added to the ID-order list and the category table. That is the new action being counted, not a looser test.
  - I added a one-shot `failOnPost` to `MockKeyboardOutput` and a `MockAppActivations` mock. Existing mock behaviour is unchanged.
- [✓] Idle budget: the activation observer is a workspace did-activate notification subscription. It never polls and has no timer.

## Last App: the path that ships
**Direct activation, with a command-tab press only on refusal.**
- `LiveAppActivations` subscribes to `NSWorkspace.didActivateApplicationNotification`, seeded with the current frontmost app.
- The pure `AppHistory` keeps regular apps, most recent first, up to 16. Edgy's own pid and non-regular apps never count.
- On a trigger it activates the most recent app that is still running and isn't in front, through `NSRunningApplication.unhide()` + `activate()`. It never launches anything, so an app that quit isn't relaunched. "Still running" also checks the bundle ID, so a reused pid doesn't count.
- The target is recorded at trigger time, so two quick triggers toggle A → B before the system notification arrives. A late notification just re-records the same app.
- Only if `activate()` returns false does it post one `cmd+tab` (`keyboard.post`, a quick press).
- **Whether macOS 27 ever refuses that activation from Edgy (an accessory app) is unverified on device**: see Needs Gabriel.

## Tests (`Tests/ActionsTests/Batch32Tests.swift`, all green)
KeySequenceTests:
- `gapIsFortyMilliseconds`: the gap is 0.040 s and at most 4 steps.
- `oneComboIsThePreBatchEventList`: `posted == ["cmd+c"]`, no low-level events, nothing scheduled, nil outcome; `cmd + v` is still one combo.
- `oneComboKeepsItsErrors`: missing → `missingParameter`; `zz` → the same unavailable text as before; an output failure → the same unavailable.
- `twoCombosInOrderWithTheGap`: `ctrl+b`, nothing at 39 ms, `n` at 40 ms, all released.
- `fourCombosInOrderWithTheGap`: in order, one per 40 ms on the fake scheduler, delays `[gap, gap, gap]`.
- `failureMidSequenceReleasesEverythingAndStops`: step 2 breaks halfway, so `x up` and `ctrl up` are sent, `allReleased`, nothing more is sent, and the action works again afterwards.
- `failureOnTheFirstStepThrowsReleasesAndStops`: throws unavailable, everything is released, nothing is scheduled, and the next trigger works.
- `retriggerWhileSendingIsIgnored`: the same binding and another shortcut are both ignored while sending; once the sequence finishes, triggers work again.
- `refusedSequences` (5 arguments): five combos, `ctrl+b zz`, `ctrl+b ctrl`, `fn n`, a double space. Each is unavailable, posts nothing, schedules nothing, and leaves no sequence in flight.
- `holdAndSlideStepsRefuseASpace`: hold with `ctrl+b n` or `ctrl + b`, and slide-steps with a spaced up or down key, are refused with no events. One combo still works on both.

LastAppTests:
- `catalogEntry`: right after Open App, named "Last App", Apps category, trigger, no parameters.
- `togglesBetweenTheLastTwoApps`: A→B, trigger → A, trigger → B, with no switcher press.
- `lateNotificationKeepsTheToggle`: the system's notification arriving after the trigger doesn't break the toggle.
- `previousAppQuitGoesToTheOneBefore`: C, A, B with A quit → C.
- `previousAppQuitWithNoneBeforeIsANoOp`: nil outcome, no activation, no keys.
- `edgysOwnWindowsNeverCount`: Edgy's pid and a non-regular app are never activated or counted.
- `fromEdgysWindowGoesToTheAppBeforeIt`: with Edgy in front → the app that was in front before Edgy.
- `noHistoryIsANoOp`: with nothing, or only the current app, known: nil outcome, no error, no keys.
- `refusedActivationFallsBackToOneSwitcherPress`: `posted == ["cmd+tab"]`, all released.
- `registryObservesFromTheStart`: the registry subscribes when it's built.
- `historyIsBounded`: the history holds 16 apps, newest first.

## Verification
- `swift build`: Build complete.
- `swift test`:
  - ActionsTests: 328 tests in 44 suites, passed.
  - EdgyUITests: 425 tests, 1 issue, `everyCatalogActionHasAnIcon` (`ActionIcons.has("app.last")`). This is the expected failure the brief names; it clears when the chief lands the icon.
  - Every other run passed.
- `swift format lint --strict -r Sources Tests Package.swift`: clean. I formatted only `Sources/Actions` and `Tests/ActionsTests`.
- `git grep -niE -f ~/.config/edgy-names-denylist`: prints nothing.
- `git diff --name-only main...`: only `Sources/Actions/**`, `Tests/ActionsTests/**`, `scripts/smoke-actions.sh` (and this file).
- A full `swift test` rewrites snapshot PNGs under `docs/design/build-shots/` (the picker now lists Last App). I restored them; they aren't mine to commit. The chief will see them change when the icon lands.

## Diff summary
- New:
  - `ActionRegistry+Sequences.swift`: parse, send, release, and the in-flight guard.
  - `ActionRegistry+LastApp.swift`: the Last App action.
  - `AppHistory.swift`: the protocol, the no-op tracker and the pure history.
  - `LiveAppActivations.swift`: the workspace observer and running-only activation.
- Changed:
  - `ActionCatalog.swift`: `BuiltInAction.lastApp` and its descriptor.
  - `ActionRegistry.swift`: state, an `apps:` init parameter (defaults to the no-op tracker), dispatch, and slide-steps through `singleCombo`.
  - `ActionRegistry+Keys.swift`: hold goes through `singleCombo`.
  - `Actions.swift`: the factory body passes `LiveAppActivations()`; the signature is unchanged.
- Tests: `Batch32Tests.swift`, `Mocks.swift`, and the count/list pins.
- Smoke: `smoke-actions.sh` steps 35–37.

## Decisions I made (and why)
- **Spaced single combos (`cmd + c`) stay valid on Keyboard Shortcut.** Today's parser accepts them, and "one combo byte-for-byte" outranks the split. Text is split into a sequence only when it isn't already one combo.
- **Hold Keys and Slide Steps refuse any space, including `ctrl + b`.** That is the brief's literal rule. Nothing in the repo writes spaced combos (the recorder writes canonical `ctrl+b`), so no stored config should break.
- **Failure release is belt and braces.** The live `post` builds every event before posting any, so it can't leave a key down today. The sequence still sends key-up and modifier-up for the failed step, so a future change to `post` can't strand a key. A single combo keeps its exact pre-batch failure behaviour, with no extra events.
- **A later step's failure is logged, not surfaced.** The gesture's outcome was already reported when step 1 went out, and there is no async error path to the UI.
- **The activation observer starts when the live registry is built**, not on the first trigger. Otherwise the first Last App after launch would always do nothing. It is listen-only and event-driven; I updated the factory comment to say so. Previews and tests that call the factory register an inert observer and touch nothing.
- **No did-terminate observer.** Apps that quit are pruned lazily when Last App is triggered (running check plus bundle-ID match), which saves one more notification wakeup.
- **The sequence parser is internal**, so it can't collide with anything batch 29 adds for display and validation. The format is the fixed shared one.

## Needs Gabriel
- Run `scripts/smoke-actions.sh` steps 35–37:
  - the multiplexer prefix sequence actually reaches the multiplexer at 40 ms;
  - the four-step typing comes out in order with no stuck modifier;
  - Last App activates directly. If the log ever says "was refused; pressing the switcher shortcut", the fallback is what you're feeling.
- If 40 ms proves too short for some app, `ActionRegistry.sequenceStepGap` is the one constant to change.

## Open questions
- Should a sequence re-trigger also produce no plate in the UI? The engine reports the same nil outcome as a single shortcut; the plate is batch 29's call.
