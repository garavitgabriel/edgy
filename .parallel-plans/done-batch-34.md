---
batch: 34
name: EDGY-THEN — the key-sequence button people can find
branch: worktree-edgy-then
worktree_path: .claude/worktrees/edgy-then
completed_at: 2026-11-10
verification: swift build ✔ · swift test ✔ (all 8 test runs green: 58, 7, 134, 509, 270, 20, 57, 332 tests) · swift format lint --strict ✔ · token greps clean · denylist prints nothing
---

# Done — batch 34

## Layout chosen (Build item 3): own line under the field, at every width

The button can't sit beside the field. The inspector is a fixed 360 pt. The parameter column right of the 80 pt "Keys" label is about 253 pt, but the field (186 pt) + 8 pt gap + the bordered "Add another key" (about 122 pt) needs about 316 pt. So **"Add another key" always sits on its own line under the field, left-aligned with it, with the hint under that.** There's one layout and no `ViewThatFits`.

A sequence field now sits at the start of its column, where the old reserved "+ Then…" width kept it. It's about 6 pt left of the batch-29 x, because the reserved quiet button was about 6 pt narrower than the column. Nothing sits beside the field any more, so the batch-33 reserved width is gone: the field's x is the same with the button shown or hidden by construction, and a test measures it (below). Hold Keys and the other one-combo fields are unchanged (trailing, as before).

## Build

- [x] **1. "Add another key"** is the bordered button (`.buttonStyle(.bordered)`, 13 pt, `.fixedSize()`, the same treatment as "Choose…", the only other bordered button in the inspector) with an `ink` label, the same tooltip "Send another shortcut after this one", and the same action (`controller.start(after:)`). It's `AddAnotherKeyButton` in `ParameterEditors.swift`, still a plain `Button`, so the accessibility action is unchanged. The rules are the same `KeyRecorderController.showsThen` as before: Keyboard Shortcut only, 1–3 steps, idle.
  - Tests: `Batch34RecorderTests.labelIsAddAnotherKeyWithTheSameTooltip` and `buttonShowsByTheSameRules`. The second checks the rule and the rendered view: present at 1, 2 and 3 steps; absent when empty, at 4 steps, while recording and on Hold Keys. `buttonIsTheBorderedInkButton` checks it has a bezel and the quiet button didn't.
  - `Batch29RecorderTests.oneStepShowsThen` now expects "Add another key". The old `"+ Then…"` assertion is kept beside it as a comment naming the 2026-11-10 ruling.
  - Not literally a "small" control size: "Choose…" doesn't use `.controlSize(.small)` either, so I matched it. Say if you want `.small`.
- [x] **2. The hint** is "Sends these one after another." (`KeyRecorderField.sequenceHint`), 13 pt `ink2`, one line (`fixedSize`, never truncated). It shows while the button shows or the value has 2+ steps. Never while recording (Use Escape is alone there), never on Hold Keys, never when empty.
  - Tests: `hintShowsWithTheButtonAndWithFourSteps` (1–4 steps, rule and rendered) and `hintNeverWhileRecordingNorOnHoldKeysNorEmpty` (rule and rendered, plus row heights: Hold Keys equals an empty field, and 1 step is taller than 4 steps, which is taller than empty).
- [x] **3. Field x:** `fieldXIsIdenticalWithTheButtonShowingAndHidden` measures the field's real frame through an anchor preference (`RecorderPartBounds`, new in `ParameterEditors.swift`). It checks the field's minX is identical at 1, 2, 3 and 4 steps, while recording and when empty. It also checks the button's minX equals the field's, the button sits below the field and the hint below the button, and the hint gets its full ideal width inside the 340 pt row.
  - **Batch-33 test changed (for the chief to rule on):** `Batch33InspectorTests.fieldKeepsItsWidthWhenThenHides` measured the reserved width *beside* the field. That premise no longer exists, so its body is kept in full as comments naming the 2026-11-10 ruling. It now measures the field's real frame at 2 vs 4 steps (minX and width, within 0.5 pt), which still checks the batch-33 guarantee. Nothing was loosened.
- [x] **4. `docs/settings-reference.md`:** the key-sequence paragraph now names the **Add another key** button and the hint line.

## Shots (light + dark)

All are in `docs/design/build-shots/batch-34/` and come from `Batch34RecorderTests.recorderShots` / `recordingUseEscapeShot`.

- [x] **`recorder-one-step-add-another`:** "⌃B" in the field at the start of the column. Under it is a soft bordered "Add another key", left edges lined up, then "Sends these one after another." in `ink2`. The button reads as clickable at a glance, where the old quiet text didn't.
- [x] **`recorder-two-steps`:** "⌃B, N", the same button and hint, and the field at the same x.
- [x] **`recorder-four-steps`:** "⌃B, N, ⌘K, X". No button; the hint is still there, so it's clear why four combos are listed. The field is at the same x.
- [x] **`recorder-recording-use-escape`:** the accent-ringed "Press keys…" and "Use Escape" under it. No button, no hint.
- [x] **`recorder-hold-keys`:** Hold Keys "fn Space", trailing as before. No button, no hint. The two slider rows and their helpers are unchanged.
- [x] **Re-shot batch-29** (only these changed): `recorder-one-step`, `recorder-two-steps`, `recorder-four-steps`, `recorder-escape-recorded`, `recorder-use-escape`. No batch-33 shot changed in bytes, and no other shot changed.
- App names: none appear in these shots (the inspector shows the default profile).

## Bones tick list

1. Mirror is the pad: not touched ✔
2. Zone states by shape: not touched ✔
3. Short values / pad tab: "⌃B, N" from the one formatter, unchanged ✔
4. One accent: the button is `ink` on the system bezel. The only accent is the recording ring, as before ✔
5–10: no new surface, colour, icon or copy beyond the two strings the brief names ✔
- Tokens only: no colour or size literal added. The `+ 16` for the field's chrome width was already there. The colour grep, the `.font(.system(size:` grep and the second-hue grep are clean.

## For the chief

- **BRIEF § Key sequences** still says the button "appears right of the field" and "its width stays reserved". With this layout it's under the field and no reservation is needed. BRIEF is frozen to me; please update the wording.
- BRIEF line 280 ("No helper line … The button and its tooltip explain themselves") now contradicts the hint. Same request.
- The sequence field moved about 6 pt left of its batch-29 x (it now starts its column). It's the same in every state.

## Files

- `Sources/EdgyUI/Inspector/ParameterEditors.swift`: layout, `AddAnotherKeyButton`, `sequenceHint`, `showsSequenceHint`, `RecorderPartBounds`, `fieldWidth`.
- `Sources/EdgyUI/Inspector/KeyRecorderController.swift`: doc comments only.
- `Tests/EdgyUITests/Inspector/Batch34RecorderTests.swift` (new, 8 tests); `Batch29RecorderTests.swift` and `Batch33InspectorTests.swift` (updated, old expectations kept as comments).
- `docs/settings-reference.md`; shots in `batch-29/` and `batch-34/`.
