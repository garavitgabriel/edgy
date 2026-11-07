# Blockers — batch 7 (EDGY-ACTIONS-3)

## 1. `Tests/IntegrationTests/CatalogValidationTests.swift` fails once a `.hold` action exists (chief-owned file)

**Status:** not blocking the batch; the rest of batch 7 is done. `swift test` is red on this one
test until the chief applies the fix below on `main`.

The brief requires `keyboard.hold` with `ActionDescriptor.Shape.hold` (the contract the chief
added in v0.3). The integration test `everyActionHasAtLeastOneCompatiblePlacement` predates
`.hold`; it assumes every non-continuous action is a trigger:

```swift
// Tests/IntegrationTests/CatalogValidationTests.swift:83
#expect(
  validator.validate(Binding(zone: zone, gesture: .slide, action: descriptor.id)).map(\.code)
    .contains(.shapeMismatch) == (descriptor.shape == .trigger))
```

A hold action on a slide *is* a shape mismatch (the validator says so, correctly), so the
expectation is wrong for `keyboard.hold`:

```
✘ Test everyActionHasAtLeastOneCompatiblePlacement() recorded an issue at CatalogValidationTests.swift:83:5
```

**Fix (one line, chief on `main`):** `== (descriptor.shape != .continuous)`.

Related, also outside my glob, for whoever owns them:

- `placement(for:)` in the same file puts every non-continuous action on `.doubleTap`. A hold action
  should be placed on `.longPress`.
- `Sources/EdgyRuntime/Validation.swift:212` checks only `(shape == .continuous) != isSlide`, so it
  accepts `keyboard.hold` on a double tap and `system.dictation` on a long press. The contract says
  `hold ↔ .longPress only`. That file belongs to batch 9 (EdgyRuntime).
