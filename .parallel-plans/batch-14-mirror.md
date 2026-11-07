# Batch 14 — EDGY-MIRROR: the pad mirror (big and mini)

Read `CLAUDE.md`, `.parallel-plans/2026-11-07-edgy-v05.md`, then **`docs/BRIEF.md` § Design in full**, and look at `docs/design/final/26F-1TVB-A.png`, `-B.png`, `-C.png`, `-E.png`. You own `Sources/EdgyUI/Mirror/**`, `Tests/EdgyUITests/Mirror/**`, `docs/design/build-shots/batch-14/**`.

## Build
1. **`PadMirrorView`** (settings window size) — bones 1–4 exactly:
   - To scale from `model.mirroredDevice.sensorSizeMM` × `Tokens.mirrorPointsPerMM`, trackpad orientation, the slab (top-left lit gradient, soft lower edge, subtle depth), no rulers or mm callouts.
   - Zone geometry **only** from `Gestures.PadLayout` (current `editor.config.gestures`). Zones = the effective profile of `model.selectedProfile` (`editor.effectiveBindings(forApp:)` for app tabs).
   - Zone states by shape: mapped edge = solid inset bar with rounded ends; unmapped edge = hairline; mapped corner = solid rounded square with the action's icon; pass-through corner = dashed rounded square (dashed means pass-through and nothing else); selected = `ink` ring; live = accent contact + thin accent border on the lit bar. Selection and live never look alike. Edge segments (1–4) drawn as separate bars.
   - Labels joined to their zone (bone 3): side-strip labels are tabs growing from the strip's inner side in the same fill with no gap; top/bottom labels inside the bar; corner labels are tabs flush to the corner tile; never floating pills, never rotated, ≥13 pt. Label text = the zone's action names in plain words (e.g. "Tracks and Play/Pause" for a bottom edge with previous/next/play-pause — write the joining rule and document it).
   - App-profile marks (§ App profiles): ink dot on an overridden zone's tab; "Off here" on a turned-off zone.
   - Live touches from `model.liveTouches` (normalized, origin bottom-left): recognized/claimed = filled accent contact, slight press-in, no glow; rejected = hollow struck circle.
   - Interaction: click a zone → `model.selectedZone`; the zone's frame is published (an anchor preference or `PadMirrorView.ZoneAnchor` API — document) so the picker popover (batch 15) can anchor to it with an arrow.
   - States: no trackpad (dashed pad + "Connect a trackpad…", bindings still editable — § System states), disabled/off-in-app (faded per § System states / § App profiles).
   - Two pads: outline cross-fades 150 ms when `mirroredDevice` changes.
2. **`MiniMirrorView`** (popover) — same drawing code at `Tokens.miniMirrorPointsPerMM`, no labels, zones of the active profile + the last touch where it landed.

## Acceptance
- Snapshots (light + dark) in `docs/design/build-shots/batch-14/` for: default profile idle; right edge selected; live slide on the right edge (simulated touch); a rejected touch; bottom edge split into 2 and right edge into 3; Wayfare tab (override dot, "Off here", hold corner); Huddle (off); no trackpad; built-in pad size; mini mirror idle + with last touch.
- ≥ 12 tests: geometry agrees with `PadLayout` for both pad sizes and segments; label text rule; selection sets `selectedZone`; effective-profile marks; touch mapping normalized → points; snapshot tests above.
- Bones checklist + reader-first review vs A/B/C/E in the done report; token greps clean.
- Verification triple green, denylist clean.
