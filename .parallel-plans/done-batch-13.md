---
batch: 13
tag: EDGY-ENGINE-5
branch: worktree-edgy-engine-v05
worktree_path: /Users/gabrielgaravit/Projects/edgy/.claude/worktrees/edgy-engine-v05
completed_at: 2026-11-07
verification: pass
---

## Acceptance criteria
- [✓] **≥ 30 new tests: 89 new test functions** (cases: Gestures 90 → 111, Displays 50 → 57, Actions 214 → 238, EdgyRuntime 195 → 232).
  - A measure for each reason that has one, and none for click / handoff / disabled zone / size-only palm: `RejectionMeasureTests` (21).
  - Display key stability on fakes (new id on reconnect, serial from the EDID, name fallback, two identical monitors): `DisplayKeyTests` (7).
  - Outcome for each level action (volume, built-in and external brightness, keyboard backlight, the HUD-off case, a pinned level), hold, switcher and the default nil: `LevelOutcomeTests` (8), `OtherOutcomeTests` (5).
  - Unresponsive skip, limited-availability copy, check due stops at 3, never for confirmed, settings applied live: `HonestBrightnessTests` (11).
  - The feed carries both (measure on `rejected`, outcome on `actionRan`), slide updates per whole percent, the display check at the end of a slide that moved the level, Test Mode, reset: `OutcomeFeedTests` (14).
  - Editor answer / count / turn back on, one undo step each: `DisplayCheckEditorTests` (6).
  - Presets validate clean on the real-catalog-shaped fake, survive `MachineDefaults` (all available, and no brightness), apply in one undo step: `PresetTests` (8 functions, 14 cases).
  - Broken config: running config kept, edits / undo / redo refused, replace works, recovery on fix (also when the fix equals the running config), a file that stops validating, the watcher path end to end: `BrokenConfigTests` (9).
- [✓] Existing tests unchanged in intent. Three edits, listed below.
- [✓] `docs/settings-reference.md` updated: display check and its editor methods, presets, the broken-config state, feed outcomes with an outcome table, and the measure table.
- [✓] Verification triple green, denylist clean (below).
- [✓] Nothing outside the allowed glob changed (`git diff --name-only bcd048e..HEAD`: only `Sources/{Gestures,Actions,Displays,EdgyRuntime}`, their tests, `docs/settings-reference.md`, and this file).

## Verification
- `swift build`: `Build complete!`
- `swift test`: exit 0. Every target passes: 56, 7, **111 Gestures**, 3, **232 EdgyRuntime**, 19, **57 Displays**, **238 Actions**.
- `swift format lint --strict -r Sources Tests Package.swift`: exit 0, no output.
- `git grep -niE -f ~/.config/edgy-names-denylist`: no output (exit 1).

## The rejection-measure table (for the design session: BRIEF § Bones 4's copy guessed some of these)

What each `RejectionReason` really measures, as `RejectionMeasure` (`measured`, `limit`, `unit`). Defaults in brackets.

| Reason | Where the pipeline decides it | measured | limit | unit |
|---|---|---|---|---|
| palm | contact shape, at landing or as it spreads | major axis | `palmMajorAxisMM` [18] | mm |
| palm (round blob) | same | minor axis | fixed 14 | mm |
| palm (size or density only) | same | — (unitless device readings) | — | none |
| typing | at landing, and while unclaimed | time since the last key | `typingSuppressionMS` [500] | ms |
| tooManyContacts | every frame | non-palm contacts on the pad | `fingers` [1] | fingers |
| offAxisMotion, corner | a corner touch moving before a long-press | travel from landing | fixed 3 | mm |
| offAxisMotion, edge outward | before the claim | sideways travel toward the edge | fixed 2.5 | mm |
| offAxisMotion, edge diagonal | before the claim, no axis wins | total travel | fixed 3 | mm |
| offAxisMotion, swipe that veered | swipe candidate lifting | travel across the edge | travel along it | mm |
| tooFast, held too long | swipe candidate still down | time since landing | 350 (600 where no slide is bound) | ms |
| tooFast, too short | swipe candidate lifting | travel along the edge | fixed 6 | mm |
| tooFast, no clear axis at lift | swipe candidate lifting | — | — | none |
| startedOutsideZone | a touch drifting into a mapped zone | how far in from that edge it landed | `edgeWidthMM` [8], or `cornerSizeMM` [10] for a corner | mm |
| disabledZone | landing in an unmapped part of an edge | — | — | none |
| systemGestureHandoff | inward motion before the claim | — | — | none |
| physicalClick | the button went down | — | — | none |

Where BRIEF's copy table guessed wrong:
- **too fast (dwell)** — "Ignored: too quick, 60 ms, needs 120 ms" is not what happens. `tooFast` never involves the dwell or a speed limit. A touch fast enough to be a swipe candidate (≥ 180 mm/s along the edge) is rejected when it then **stays down too long** (e.g. "410 ms, limit 350 ms") or **lifts too short** ("4 mm, needs 6 mm"). A slow touch that never reaches the dwell just ends as a tap or nothing; it isn't rejected. Suggested copy: "Ignored: swipe too slow, 410 ms, limit 350 ms" / "Ignored: swipe too short, 4 mm, needs 6 mm".
- **off-axis** — the runtime has no angle. It's distance: "Ignored: off-axis, moved 3.4 mm sideways, limit 3 mm" (diagonal, corner), "… 2.8 mm toward the edge, limit 2.5 mm" (outward), or "… 9 mm across, 5 mm along" for a swipe that veered (the limit there is the along travel; across must stay smaller).
- **too many contacts** — matches: "Ignored: 2 fingers, set to 1". Its measured is all non-palm contacts on the pad, so a resting thumb counts.
- **palm** — matches, but the limit is 14 mm when the minor axis decided it ("Ignored: palm, 15 mm across, limit 14 mm"). Size-only palms have no number: "Ignored: palm".
- **started outside a zone** — matches ("started 25 mm in, edge is 8 mm"), but **the feed never reports this reason** (batch 12 kept it out as ordinary pointer use). The measure is in the recognizer output only. If the overlay should show it, that's a decision for the chief.
- **zone disabled / Edgy off in app** — no number, as BRIEF says.

## Existing tests edited (intent unchanged)
| Test | Change | Why |
|---|---|---|
| `NativeTests.AvailabilityTests.connectingAControllableMonitorFlipsTheCache` | expects `.limited(mayNotRespond)` instead of `.available` after connecting the DDC monitor | The brief: a DDC monitor is limited until confirmed. The test still checks the cache flips from unusable to usable and back. |
| `SettingsAuditTests.theReferenceDocumentsEverySettingAndCode` | 14 v0.5 names added to its method list | It now also fails if the new API goes undocumented. Nothing removed. |
| `Tests/EdgyRuntimeTests/Fakes.swift` `FakeActions` | optional `outcome` hook and a `performReporting` that calls `perform` first | With no hook set it behaves exactly like the protocol default, so every old test sees the same thing. |

## Diff summary

**Gestures** (`GesturePipeline.swift`): every reject path passes a measure; `FrameStep.measures` goes out as `rejectionMeasures`. Only contacts rejected in that output get one. `isPerpendicularDominant` became `failedSwipe`, which returns the reason and its measure (same reasons as before).

**Displays**: `DisplayKey.make` fills `DisplayInfo.key` in the probe. It uses the CoreGraphics vendor, model and serial, then the paired EDID's serial when CoreGraphics has none, then the name. The format is lowercase hex, e.g. `4c2d-7154-9`.

**Actions**:
- **Outcomes.** `ActionRegistry.performReporting` does the work now, and `perform` calls it. Level slides report `level` after each update. `systemHUDShown` is true for volume and built-in brightness while HUD is `native`. External brightness reports `detail` = the display's name. The keyboard backlight reports no detail.
  - `keyboard.hold` reports `detail` = `KeyCombo.displayText`. The text is "fn" first, then ⌃⌥⇧⌘ in the system's order, a space and the key name: "⌃⌥ Space", "⇧⌘ 4". The release never needs parameters.
  - `apps.switcher` reports `ActionOutcome(systemHUDShown: true)`.
- **Turned-off displays.** Brightness throws unavailable "Turned off for this display." for a display in `unresponsiveDisplays`.
- **Availability.** `display.brightness` treats turned-off displays as unplugged. If nothing else can take brightness, it's unavailable with the same copy. A result that would be `.available` becomes `.limited("May not respond: …")` while any working third-party (DDC) monitor is unconfirmed. The cache key now includes those two settings sets, so `apply(settings:)` takes effect at once.
- **Check due** (`DisplayCheck.swift`). It applies to third-party monitors only, when not confirmed, not turned off, and asks < 3.

**EdgyRuntime**:
- **`LiveDecision`**:
  - `rejected(…, measure: RejectionMeasure? = nil)` and `actionRan(…, outcome: ActionOutcome? = nil)` gain defaulted trailing fields.
  - New cases: `actionUpdated(id, zone:, kind:, outcome:)` (a slide's later steps, only when the whole percent or the detail changes) and `displayCheckDue(key:name:)`.
- **Router** calls `performReporting` for discrete gestures, slides and hold presses. Releases still use `perform`. It splits the display-check request out of the detail and sends `displayCheckDue` when a slide that moved the level ends. Test Mode is unchanged.
- **Engine** puts `rejectionMeasures[contactID]` on `rejected`.
- **`SettingsEditor`**:
  - Display check: `displayCheckDue(key:)`, `countDisplayCheckAsk(key:)` (caps at 3), `answerDisplayCheck(key:responds:)`, `turnDisplayBackOn(key:)`.
  - `applyPreset(_:)`.
  - Broken config: `configProblem: ConfigProblem?` (message, line), `SettingsEditorError.readOnly`, `reportConfigProblem(_:)`, `replaceFileWithCurrentSettings()`, and `SettingsChange.Cause.configProblem`.
- **`Presets`**: `.media` / `.windows` / `.minimal`, and the `Presets.Preset` enum.
- **`ConfigStore`**:
  - `startWatching(onChange:onFailure:)`; the old signature stays.
  - Parse errors now carry the parser's own message with its line ("Unexpected character 'n' around line 4, column 16.").

## Decisions I made (and why)
- **How the check-due request crosses from Actions to the runtime: through `ActionOutcome.detail`.**
  - The outcome is frozen and EdgyRuntime can't import Actions, so the detail reads "name" + `"\u{1E}displayCheck:"` + "key" when a check is due. The brief allowed "or the outcome detail — document".
  - The router strips it: the feed's outcome detail is always the plain name, and the request arrives as `displayCheckDue(key:name:)`.
  - A test pins the marker literal in each module. **Chief: a one-line cross-check in `IntegrationTests` (`DisplayCheckRequest.marker == DisplayCheckDetail.marker`, after `@testable import EdgyRuntime`) would lock it**; I couldn't add it (off-limits).
  - I chose this over a protocol, which would need an EdgyApp adapter that could silently go missing.
- **When the check is due:** at the end (`.ended` or `.cancelled`) of a brightness slide that actually changed the level. The user can't judge "did it change" before they've moved it. The plate shows at most once per slide.
- **Apple external displays and the built-in panel are never checked.** The failure (writes accepted, nothing applied) is a DDC failure; Apple displays go through the system's own brightness path.
- **"Turn back on"** removes the display from `unresponsiveDisplays` only. It doesn't confirm the display or reset asks, so the question can come back while asks remain.
- **`actionUpdated` instead of an `actionRan` per frame.** It goes out only when the whole-percent level (what the plate shows) or the detail changes, so a slide yields about one decision per percent, not one per frame.
- **"Stops validating" means a reload that *introduces* errors** (the editor's existing gate). That reload is not adopted. Errors the running config already had (e.g. from first load) stay exposed and never block, as before.
  - This changes `adoptExternal`'s behaviour for invalid files: before, it adopted them with the errors exposed. No existing test relied on that.
- **The read-only state blocks `undo` / `redo` too.** Both save the file, which would overwrite the user's broken edit.
- **`replaceFileWithCurrentSettings` works even without a problem** (it just saves) and isn't an undo step.
- **`apps.switcher` reports `systemHUDShown: true`**: the system's switcher is on screen, so the UI must not draw a plate.

## Needs Gabriel
- After merge, re-run the third-party monitor check on the Mac mini (the backlog's "Mac mini" monitor):
  - brightness should show "May not respond…" in the picker;
  - the first slide should end with a `displayCheckDue` decision, and "No" should make the slide report "Turned off for this display.".
  - The plate itself lands with stage 2.

## Open questions / for the chief
1. **EdgyApp wiring** (outside my glob):
   - `store.startWatching(onChange: …, onFailure: { error in Task { @MainActor in editor.reportConfigProblem(error) } })`. `ConfigStoreError` isn't `Sendable`; wrap it or pass `String(describing:)` through a small error type, as `BrokenConfigTests.watcherReportsBrokenFilesAndRecovers` does.
   - `reloadConfig()` can drop its alert: the editor now holds the problem for the window and popover.
2. **New `SettingsChange.Cause.configProblem` and `LiveDecision` cases.** No code outside my modules switches over `Cause` or `LiveDecision` today (grep). A sibling batch that adds an exhaustive switch will need the new cases.
3. **Glyph precedence:** BRIEF puts the broken config above No Accessibility. `EngineStatus` doesn't carry it. The popover can read `editor.configProblem` directly. Adding it to the status would be a frozen-contract change, so I left it.
4. **`startedOutsideZone` in the feed:** see the measure table above.
