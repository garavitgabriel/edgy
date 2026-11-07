# Blockers — batch 15 (EDGY-INSPECTOR)

Nothing stopped the batch. Two items need the chief on `main`; both have a working interim inside batch 15's glob.

## 1. Draft bindings need a home on `SettingsModel` (frozen)

**Why:** BRIEF § Binding parameters says a binding whose required parameter is still empty reads "Needs keys" / "Needs an app". `SettingsEditor` refuses that binding (`missingParameter` is an error an edit would introduce), so it can't live in the config. The picker writes it and the inspector shows it; they are siblings, so they need shared state. `SettingsModel` is frozen and the batch rules say "new stored state: keep it in your views, or write a blocker".

**Interim (in my glob):** `InspectorDrafts` in `Sources/EdgyUI/Inspector/InspectorModel.swift`, a per-model side table (`NSMapTable`, weak keys). It holds drafts keyed by (profile, slot), the field to focus after the picker hands off, and the row whose "…" menu is open.

**Ask:** add to `SettingsModel` something like `public var draftBindings: [ProfileRef: [BindingKey: Binding]]`, `public var focusField: BindingKey?` and `public var openRowMenu: BindingKey?`. Then `InspectorDrafts.of(model)` becomes a thin forwarder (a ~10-line change in my folder).

## 2. The window must host the picker

`ActionPickerView` is shown through `.actionPickerHost(model:)` (`Sources/EdgyUI/Picker/PickerPopover.swift`). The mirror publishes each zone's bounds with `.pickerAnchor(for:)` and its own bounds with `.pickerMirrorBounds()`.

**Ask:**
- Batch 14 (mirror): attach those two modifiers.
- Batch 16 (window), or the chief: put `.actionPickerHost(model:)` on the view that contains the mirror. Neither glob is mine.
- If batch 14 published its own anchor API instead, bridge it by mapping it onto `PickerAnchorKey`.
