# Edgy production assets

Exported 2026-11-07 from the final design source. The menu glyph and the app-icon drawing are glyph round 2, variant **V3 "solid pad, lit strip"** (chosen by the owner), replacing the earlier outline drawing (look 26F-1TVB, render F); the icon tile is unchanged. Spec: `docs/BRIEF.md` § "Menu glyph and app icon" and § "System states".

## Menu glyph

| File | State | Shape |
|---|---|---|
| `glyph-normal.pdf` | Normal | Solid pad with a rounded left side, a transparent vertical strip (the lit edge), then the heavy right edge, rounded on the right |
| `glyph-testMode.pdf` | Test Mode | Normal with a round transparent **hole** cut out of the solid pad (not a dot) |
| `glyph-paused.pdf` | Paused | The heavy right edge splits into two stacked pieces with a gap at mid-height |
| `glyph-disabled.pdf` | Disabled | Same artwork as normal. **Dim to 40% in code.** |
| `glyph-noTrackpad.pdf` | No trackpad | Same artwork as normal. **Dim to 40% in code.** |
| `glyph-needsAccessibility.pdf` | No Accessibility | The heavy right edge becomes an exclamation: a shortened edge plus a round dot below it |
| `glyph-brokenConfig.pdf` | Broken config | Same exclamation artwork as needsAccessibility |

- **Size:** 16 × 11 pt page, viewBox `0 2.5 16 11` (the source glyph is drawn on a 16 × 16 grid; the page is that grid cropped vertically to the ink, y 2.5 to 13.5).
- **Format:** single-page vector PDF, pure black (`#000000`) on a transparent page, no raster content.
- **Template image:** add to the asset catalog with "Render As: Template Image" (or set `image.isTemplate = true`) so macOS tints it for light, dark and highlighted menu bars. The PDFs carry no opacity. Disabled and No trackpad look like Normal at 40% opacity; apply that in code (for example `button.appearsDisabled = true` or `alphaValue = 0.4`).
- **Transparent parts:** the strip between the pad and the right edge (x 11.4 to 12.6, 1.2 pt) and the Test Mode hole are true holes, not white fills. The Test Mode hole is a subpath of the pad filled with the even-odd rule, so the menu bar shows through it.
- **Test Mode hole:** 3.2 pt diameter at 1× (r 1.6, centred at x 5.4 on the pad). That clears the ≥2 pt rule in the brief, so it is the source size, unchanged.
- **Precedence** when several states apply (per BRIEF): Broken config > No Accessibility > No trackpad > Paused > Disabled > Test Mode. Show the top one only.

## App icon

| File | What |
|---|---|
| `icon-1024.png` | Master, 1024 × 1024 |
| `AppIcon.iconset/` | `icon_16x16.png`, `icon_16x16@2x.png`, `icon_32x32.png`, `icon_32x32@2x.png`, `icon_128x128.png`, `icon_128x128@2x.png`, `icon_256x256.png`, `icon_256x256@2x.png`, `icon_512x512.png`, `icon_512x512@2x.png` |
| `AppIcon.icns` | Built with `iconutil -c icns AppIcon.iconset -o AppIcon.icns` |

- **Design:** pale-stone rounded tile (824/1024, standard macOS grid, with a soft shadow below it) with a light-to-shade vertical gradient, and the V3 menu-glyph drawing in graphite (`#2B2623`): the solid pad, the lit strip and the heavy right edge, scaled 34× from the 16 × 11 glyph.
- **Contact dot rule:** the rust `#B4542B` contact dot sits on the heavy right side **only at rendered sizes ≥128 px**. `icon_16x16`, `icon_16x16@2x` (32 px), `icon_32x32` and `icon_32x32@2x` (64 px) have no dot; 128 px and up have it.
- **Two drawings:** the solid V3 shapes already hold up when small, so the <128 px drawing is the same geometry without the dot. Each PNG was rendered from the vector at its own pixel size, not downscaled from the master.
- Outside the tile is transparent.

## SVG sources (`svg/`)

- `glyph-<state>.svg`, one per state, same geometry as the PDFs.
- `app-icon.svg`: the ≥128 px drawing. The rust dot is the group `<g id="contact-dot">`; delete that group for a dot-free export.
- `app-icon-small.svg`: the <128 px drawing (no dot).

## How these were made

- Glyph PDFs: each `svg/glyph-<state>.svg` converted by a small script that writes the SVG paths as PDF vector operators (arcs become Bézier curves; `fill-rule="evenodd"` becomes the even-odd fill `f*`, so the Test Mode hole stays open), page set to the viewBox exactly. Each PDF was rasterized back to check that the strip, the hole and the page background are transparent. Headless Chrome's print-to-PDF was tried first and rejected: it gave a 16.08 × 11.04 pt page with a 0.9993 scale.
- Icon PNGs: headless Chrome screenshots of the SVG at each native pixel size (`--force-device-scale-factor=1`, transparent default background), then `iconutil`.
