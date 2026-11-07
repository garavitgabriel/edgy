# Blockers — batch 21 (EDGY-POLISH)

None stopped the batch. Each item below needs a file outside my glob.

1. **Catalog spellings (Actions).** The catalog still says "Play / Pause", "Keyboard Backlight On / Off", "Up / Right Keys", "Shortcut Name", "File or Folder", "When Already in Front" and "Release after". Batch-14 ruling 6 says the UI never re-spells a name, so the pad, picker and inspector now show the catalog's spelling exactly ("Tracks and Play / Pause"). Fix it in `Sources/Actions/ActionCatalog.swift` (owner: chief or the actions batch): "Play/Pause", "Keyboard Backlight On/Off", sentence-case parameter names. Parameter labels are already sentence-cased in the UI, and "Let go after" plus its helper line are supplied by the UI until the catalog carries them.
2. **A shadow token.** The slab's lower edge is drawn with `Color.black` at 3.5–5% opacity per layer (neutral, darker than the material in both modes, so it can't halo). If the chief wants every colour in `Tokens`, add `Tokens.shadow` and I'll switch to it (a one-line change in `MirrorPad.shadowLayers`).
3. **`InspectorDrafts` stays a side table** (chief ruling 3). It now also holds `open`, the one open binding.
