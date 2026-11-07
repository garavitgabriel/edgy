---
batch: 14
tag: EDGY-MIRROR
branch: worktree-edgy-mirror
worktree_path: ~/Projects/edgy/.claude/worktrees/edgy-mirror
completed_at: 2026-11-07
verification: swift build ✓ · swift test ✓ (all suites; EdgyUITests 147 tests, 15 suites, after merging batch 15) · swift format lint --strict ✓ · token greps empty · denylist empty
---

# Done — batch 14: the pad mirror (big and mini)

## Acceptance criteria

| Criterion | Status | Evidence |
|---|---|---|
| `PadMirrorView` to scale from `mirroredDevice.sensorSizeMM` × `Tokens.mirrorPointsPerMM` (3.7 after a647756), trackpad orientation, lit slab, no rulers | ✓ | `MirrorGeometry.size`; test `mirrorIsToScale`; `pad-default-idle-*` |
| Zone geometry only from `Gestures.PadLayout` | ✓ | `MirrorGeometry.frame(for:)` is `PadLayout.rect` scaled and flipped; test `zoneFramesArePadLayoutScaledAndFlipped` (2 pads × 1–4 segments); the live zone comes from `PadLayout.zone(atMM:mapped:)` (test `liveZoneIsTheRecognizersAnswer`) |
| Zones = effective profile of `selectedProfile` | ✓ | `SettingsModel.mirrorZones(forApp:)` uses `effectiveBindings(forApp:)` for Default (`nil`) and app tabs alike |
| Zone states by shape; separate segment bars | ✓ | `MirrorPad.edgeShape` / `cornerTile` / `selectionRing`; `pad-split-bottom2-right3-*` |
| Labels joined to zones; label rule written | ✓ | `ZoneLabel` doc comment (rule below); tests `defaultLabelsReadAsInTheRender`, `labelRuleOrders…`, `labelsAreJoinedToTheirZone` |
| App-profile marks (ink dot, "Off here") | ✓ | `pad-wayfare-*`; test `appTabShowsEffectiveBindingsWithSourceMarks` |
| Live touches: recognized filled + press-in, rejected hollow struck | ✓ | `pad-live-slide-right-*`, `pad-rejected-touch-*`; `ContactView` |
| Click selects; zone frame published for the picker | ✓ | `SettingsModel.selectZone`; test `clickingAZoneSelects…`; batch 15's `.pickerAnchor(for:)` on every zone + `.pickerMirrorBounds()` on the pad (and `PadMirrorView.ZoneAnchor`); `window-picker-bottom-*` shows the real window with the picker anchored to the bottom bar with its arrow (render B's state) |
| States: no trackpad, disabled, off in app | ✓ | `pad-no-trackpad-*`, `pad-disabled-*`, `pad-huddle-off-*`; test `systemStatesFollowThePrecedence` |
| Two pads: outline cross-fades 150 ms | ✓ (code) | `.id(device?.id).transition(.opacity)` with `.animation(.easeInOut(duration: 0.15), value: device?.id)`; motion is judged on the device |
| `MiniMirrorView`: same drawing at `miniMirrorPointsPerMM`, no labels, active profile + last touch | ✓ | `MiniMirrorView(model:)` follows the frontmost app itself: read on appear and on every activation (read-only `NSWorkspace` observation, Edgy's own activations ignored). It draws `effectiveBindings(forApp:)` for that app, which is Default when the app has no profile. Tests `miniMirrorFollowsTheFrontmostAppButNotEdgyItself` and `miniMirrorDrawsTheActiveProfilesZones`; `mini-wayfare-active-*`, `mini-idle-*`, `mini-last-touch-*`, `mini-no-trackpad-*`, `mini-paused-*`, `mini-huddle-off-*` |
| Snapshots light + dark, every listed state | ✓ | `docs/design/build-shots/batch-14/` (16 pairs, below) |
| ≥ 12 tests | ✓ | 19 test functions in `MirrorTests.swift` + `MiniMirrorProfileTests.swift` + 20 snapshot tests |

Snapshots (each `-light.png` and `-dark.png`): `window-picker-bottom` (whole window, picker open on the bottom edge), `pad-default-idle`, `pad-split-bottom4-long-label` (in-bar text truncates inside a quarter bar), `pad-right-selected`, `pad-live-slide-right`, `pad-rejected-touch`, `pad-split-bottom2-right3`, `pad-wayfare`, `pad-huddle-off`, `pad-no-trackpad`, `pad-disabled`, `pad-built-in` (134 × 87 mm with a live bottom touch), `mini-idle`, `mini-last-touch`, `mini-no-trackpad`, `mini-paused`, `mini-huddle-off`, `mini-wayfare-active` (Wayfare in front), `pad-switched-to-built-in` (second pad touched), `preset-media-minimal`.

## Verification (run in this session, after the last change)

```
swift build                                     → Build complete!
swift test                                      → every suite passed (EdgyUITests: 147 tests in 15 suites, after merging main 50776d9)
swift format lint --strict -r Sources Tests Package.swift → exit 0, no output
token greps (shared brief rule 7, plus no .custom fonts / second hue / Unicode arrows in Mirror) → no output
git grep -niE -f ~/.config/edgy-names-denylist → no output
git diff --name-only main...HEAD outside the batch-14 glob → none
```

## Bones checklist

1. **The mirror is the pad.**
   - [x] To scale from the device's real sensor size: `pad-default-idle`, `pad-built-in`.
   - [x] Trackpad orientation (origin bottom-left, flipped once in `MirrorGeometry`): test `touchMappingFlips…`.
   - [x] No rulers, dimension lines or mm callouts: every `pad-*` shot.
2. **Zone states by shape.**
   - [x] Mapped edge = solid inset bar with rounded ends: `pad-default-idle` (left, right, bottom).
   - [x] Unmapped edge = hairline: `pad-default-idle` (top), `pad-split-bottom2-right3` (right middle).
   - [x] Mapped corner = solid rounded square with its icon: `pad-default-idle` (Mic off, Mute), `pad-wayfare` (Hold Keys).
   - [x] Pass-through corner = dashed rounded square, and dashed means nothing else: `pad-default-idle` (bottom corners). A turned-off corner is a solid hairline, not dashed.
   - [x] Selected = `ink` ring with a gap: `pad-right-selected`, `pad-split-bottom2-right3`.
   - [x] Live = accent contact + thin accent border on the lit bar: `pad-live-slide-right`, `pad-built-in`.
   - [x] Selection and live never look alike: ink ring outside with a gap vs accent border on the bar plus accent fill (`pad-live-slide-right` shows both at once).
3. **Labels joined to their zone.**
   - [x] Side labels are tabs from the strip's inner side, same fill, no gap: `pad-default-idle` (Brightness, Volume).
   - [x] Top/bottom labels inside the bar: `pad-default-idle` ("Tracks and Play/Pause").
   - [x] Corner labels are tabs flush to the tile: `pad-default-idle` (Mic off, Mute), `pad-wayfare` (Hold Keys).
   - [x] Never floating pills, never rotated, ≥13 pt (`Tokens.typeBody`): all `pad-*`.
   - [x] No chip for the selected zone: `pad-right-selected`.
4. **Recognized vs rejected by shape.**
   - [x] Recognized = filled accent contact, louder: `pad-live-slide-right`.
   - [x] Rejected = hollow struck circle (`ink2`): `pad-rejected-touch`.
   - [ ] Rejection plate copy — n/a for this batch (overlay/plates, stage 2).
5. Map on the pad — [x] clicking a zone selects it (test); the picker popover is batch 15, anchored via `PadMirrorView.ZoneAnchor`.
6. The inspector — n/a for this batch.
7. Interaction notes — n/a for this batch.
8. Each status said once — [x] the mirror doesn't repeat the window's Paused / "Edgy is off in <App>" lines (see Decisions); live feedback is at the touch.
9. The overlay — n/a for this batch.
10. Popover — [x] mini mirror (zones + last touch) is ready; [x] two trackpads: mirrors show the pad touched last with a 150 ms cross-fade. Chips and switches are a later batch.

Kill list: no rulers, no grey drop-shadowed rectangle (warm slab gradient from tokens), no glow on the touch dot, no emoji or Unicode arrows (SF Symbols only), no rotated labels, no second hue, no third-party names. ✓

## Reader-first review (my shots next to the renders)

**Settings mirror vs A (light) and B (dark).**
- **Matches:**
  - The slab is a warm gradient, lit top-left, with a soft lower lip and a short shadow.
  - Inset pill bars stop at the corner tiles. The top edge is hairline. The bottom corners are dashed.
  - "Mic off" and "Mute" are tabs hanging from their tiles. "Brightness" and "Volume" are tabs merged into the bar on its inner side.
  - "Tracks and Play/Pause" sits inside the bottom bar, word for word.
  - The live right bar has the accent tint and border with a filled, pressed contact. With selection on, the ink ring sits outside it, as in A.
- **Differs:**
  - Side tabs sit at the middle of their bar; A puts Brightness high and Volume low. The middle is a rule that holds for 1–4 segments without colliding with the corner tabs.
  - The contact is a little smaller than A's.
  - The B dark shot of the same state (`pad-*-dark`) uses the dark tokens. B's two-column picker and old conflict copy are not this batch's.
- **Split (B shows the right edge split into 2):** separate pills with the PadLayout boundaries and an unmapped middle segment as a hairline (`pad-split-bottom2-right3`). Matches the intent.

**Inside the real window (batch 16's `window-default` shot, regenerated locally at 3.7 pt/mm, not committed).**
- The mirror fills the window's mirror column as in render A.
- Tabs (≥13 pt) and corner icons read at 10 mm corners and 8 mm strips.
- The right edge's selection ring shows.
- Batch 16's committed window shots predate this mirror (they show the stub), so they will change after merge.

**App tab vs S1.**
- **Matches:** an ink dot before the overridden tab's text ("• Keyboard Shortcut, Next Track and Play/Pause" in `pad-wayfare`), and "Off here" in `ink2` text-only beside a hairline zone, as S1 draws it.
- **Differs:** the demo data. S1's data is illustrative; ours is `PreviewFixtures`.
- **Huddle (off):** a 40% fade with every zone a hairline. The words are drawn by the window (see Decisions).

**Mini mirror vs E and S5.**
- **Matches:** the same drawing at 2.6 pt/mm, with no labels, small corner icons and the last touch on the right bar (`mini-last-touch`). No trackpad gives a dashed outline at the default proportion with "No trackpad connected", as in S5. Paused gives a faded pad, as in S5 (the popover writes the line under it).

**Preset minis vs S7.**
- **Matches:** `PresetMirrorView` at 120 pt shows the preset's zones with normal shapes and no labels.
- **Differs:** at 0.75 pt/mm the control radius makes corner tiles read as dots. S7's tiles are similar. Judge at real size.

## Diff summary

- `Sources/EdgyUI/Mirror/MirrorGeometry.swift`: PadLayout → points (flip), drawn-shape insets, touch mapping, live-zone lookup.
- `Sources/EdgyUI/Mirror/MirrorContent.swift`:
  - zone list from effective bindings (segments per edge, mapped / unmapped / offHere, override dot)
  - `ZoneLabel` (the label rule, SF Symbol per action)
  - `ZoneName`
- `Sources/EdgyUI/Mirror/MirrorPad.swift`:
  - the shared drawing: slab, bars, tiles, ring, tabs, contacts, message
  - `ZoneAnchorKey` (public) and `PadMirrorView.ZoneAnchor`
- `Sources/EdgyUI/Mirror/SettingsModel+Mirror.swift`: `mirrorZones(forApp:)`, `mirrorState(forApp:includesPaused:)`, `selectZone`, copy.
- `Sources/EdgyUI/Mirror/PadMirrorView.swift`, `MiniMirrorView.swift` (+ `MiniMirrorView(model:frontmostApp:)`, + public `PresetMirrorView(config:sensorSizeMM:width:)` for onboarding step 3).
- `Tests/EdgyUITests/Mirror/MirrorTests.swift`, `MirrorSnapshotTests.swift`; `docs/design/build-shots/batch-14/*`.

## Decisions I made (and why)

1. **Two frames per zone.**
   - Hits and tests use the exact `PadLayout` rect. Drawing uses that rect inset by 16% of the strip depth, with corner squares trimmed off the strip ends, so bars stop at the tiles as in render A.
   - Segment boundaries are never moved. This is presentation only and is documented on `MirrorGeometry`.
2. **Label rule** (also in the `ZoneLabel` doc comment):
   1. Pad order: slide, swipes up/down/left/right, tap, double-tap, long-press.
   2. Short names: "Mic off", "Mute", "Play/Pause"; otherwise the catalog name with " / " closed up. "…" when a required parameter is empty.
   3. Pairs collapse: Previous + Next → "Tracks", Space Left + Right → "Spaces", Left + Right Half → "Halves".
   4. Duplicates are dropped.
   5. Joined as "A, B and C".
3. **Segments per edge** = the largest `segments` among that edge's effective bindings (1 if none). Unbound segments of a split edge are hairlines.
4. **Paused and "Edgy is off in <App> · Turn on" are not drawn by `PadMirrorView`.**
   - The chief's a647756 message said the window (batch 16) fades and labels Paused. Its `WindowStatus.padLine` also writes the off-in-app line with real app names.
   - So the mirror draws only the off-in-app fade and hairlines, and no text, to say each status once.
   - The mini mirror still fades for paused (S5).
5. **Turned-off corner** = a solid hairline tile (S1), because dashed means pass-through only.
6. **`.down` touches** (on the pad, not a gesture): a `line` hairline circle with no strike. Not specced; quiet, so recognized stays loudest.
7. **Rejected mark colour** = `ink2` (BRIEF 2026-11-07 Test Mode update), never accent.
8. **Pills** are drawn as `RoundedRectangle(cornerRadius: shortSide/2, style: .circular)`. A stroked `Capsule()` rendered flattened ends in `NSHostingView` at these aspect ratios (seen in the ring). The radius is computed, not a literal.
9. **App name on the pad** falls back to the bundle ID's last component, capitalised. It's only used for the mini-mirror state value now.
10. Clicking a zone sets `selectedZone` only. It never touches `picking` (batch 15 owns opening the picker).
11. **Whole edge plus segments on the same edge:** a config holding both `.edge(.bottom)` and split `.edge(.bottom, segment:, segments: 2)` bindings is drawn at the finest split. The whole-edge binding isn't drawn. The validator's `overlappingZones` warning fires only when the two share a gesture, so the chief may want a mirror rule here (open question).
12. **In-bar labels truncate** with "…" inside their bar (`pad-split-bottom4-long-label`). Tabs keep their natural width.
13. **`PadMirrorView` calls `model.startFeed()` on appear and never `stopFeed()`.** The feed is shared, and the window that hosts the mirror should own stopping it.

## Picker anchoring (after batch 15 merged)

- **Found:** `.pickerMirrorBounds()` is an `anchorPreference`, which replaces its subtree's value for the key. Applied on the pad itself, it erased every zone's `.pickerAnchor(for:)`, and the picker never appeared.
- **Fix (inside the Mirror folder):** the mirror bounds are published from a `Color.clear` background sibling, so the values merge through `PickerAnchorKey.reduce`.
- **Batch 15 may want:** to switch `pickerMirrorBounds()` to `transformAnchorPreference` so it is safe on any container.
- **Reader-first, `window-picker-bottom` vs B:**
  - Matches: the popover is anchored to the bottom bar with the arrow down, the bar carries the ink ring, and the header reads "Tap, bottom edge".
  - Differs: the bubble overlaps the middle of the top bar and comes close to the side tabs. That placement is batch 15's `PickerPlacement`; bone 5 says it never covers neighbouring zones.

## Needs Gabriel (human-only)

- Slab depth on a real display (subtle vs flat), and the lip/shadow amount (G1 cut list).
- The 150 ms cross-fade when switching between two attached trackpads.
- Contact press-in feel and size at 3.7 pt/mm.
- Preset minis at 120 pt: are dot-like corner tiles acceptable (S7)?

## Open questions

- See `.parallel-plans/blockers-batch-14.md`:
  1. Resolved in the Mirror folder: the mini mirror observes the frontmost app itself. A model field would still be cleaner.
  2. Last-known pad size / default proportion has no home in the model or tokens.
  3. Dry-run flag for the outline contact mark.
- The window's paused copy (`WindowCopy.paused`) floors the minutes. BRIEF says whole minutes. The mirror's own copy rounds up so the countdown never reads "0 min" early. Which rounding should both use?
