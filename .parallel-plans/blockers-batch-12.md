# Batch 12 blockers

## Real-catalog audit walk (acceptance item 6, partial)

**What the brief asks:** an audit test that walks "every catalog parameter" and asserts each one is settable through `SettingsEditor` and survives a save and reload.

**What I could do in my glob:**
- `SettingsAuditTests.everyCatalogParameterIsSettableAndSurvivesReload` walks every parameter of the fake catalog. That catalog covers every `ActionParameter.Kind`, and `sampleValue(for:)` switches over the kinds exhaustively, so a new kind won't compile until the test handles it.
- `docs/settings-reference.md` lists every parameter of the real catalog by hand.

**Why the real catalog is out of reach:**
- `EdgyRuntimeTests` depends only on `EdgyRuntime` (`Package.swift`, frozen), so it can't import `Actions`.
- The only test target that sees both, `Tests/IntegrationTests/**`, is off-limits to every batch (shared brief).

**Proposed fix (chief, on main, after merge):** add the test below to `Tests/IntegrationTests/`. It reuses the runtime's sample values, so it needs `@testable import EdgyRuntime` plus a copy of `SettingsAuditTests.sampleValue(for:)`, or move that helper into `EdgyRuntime` as a public `ParameterSamples` API.

```swift
@MainActor @Test func everyRealCatalogParameterIsSettableAndSurvivesReload() throws {
  let registry = /* live catalog registry, as CatalogValidationTests builds it */
  let url = FileManager.default.temporaryDirectory.appendingPathComponent("edgy-\(UUID())/config.json")
  let store = ConfigStore(fileURL: url, debounce: 0.3, logger: SystemLogger(category: "test"))
  try store.save(.defaults)
  let editor = SettingsEditor(config: .defaults, catalog: registry.available, store: store,
                              scheduler: MainQueueScheduler(), apply: { _ in })
  for descriptor in registry.available where !descriptor.parameters.isEmpty {
    let gesture: GestureKind = descriptor.shape == .continuous ? .slide : descriptor.shape == .hold ? .longPress : .tap
    var parameters: [String: String] = [:]
    for p in descriptor.parameters { parameters[p.key] = sampleValue(for: p) }
    let binding = Binding(zone: .edge(.top), gesture: gesture, action: descriptor.id, parameters: parameters)
    try editor.setBinding(binding, in: .default)
    #expect(try store.load().defaultProfile.bindings.contains(binding), "\(descriptor.id.rawValue)")
  }
}
```

Avoid `store.load()` racing a debounced save: `SettingsEditor` saves synchronously on each edit, so the load after each `setBinding` sees it.

Everything else in batch 12 is done. See `done-batch-12.md`.
