# Blockers — batch 16 (EDGY-WINDOW)

None stopped the batch. These are wiring items for the chief at merge; each needs a file outside my glob.

1. **Accessibility state isn't on `SettingsModel`.** The window reads it from `\.windowConditions.accessibility` (`Sources/EdgyUI/Window/WindowEnvironment.swift`). EdgyApp must set it from `PermissionMonitor` (`.denied` shows the strip; `.unknown` doesn't) and pass `\.windowCommands.openAccessibilitySettings`. Frozen file: `Sources/EdgyApp/**` (or `SettingsModel` if you'd rather it lived there).
2. **Broken config file.** Until batch 13's `SettingsEditor.configProblem` lands, the window reads `\.windowConditions.configProblem` (`ConfigProblem(fileName:line:message:)`). At merge: map the editor's value onto it (or replace the environment read with `model.editor.configProblem`) and wire `\.windowCommands.openConfigFile / reloadConfig / replaceWithCurrentSettings` (the last to `replaceFileWithCurrentSettings()`; the window already confirms first). The window disables every edit control while it's set; batch 13's read-only error is the second guard.
3. **Hosting.** `SettingsWindowView.minimumSize` (1285 × 845 pt) is the content min size; host it in an `NSWindow` with a transparent, full-size-content title bar so the tabs share the title bar (84 pt leading room is left for the traffic lights). `Sources/EdgyApp/**`.
