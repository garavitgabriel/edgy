# Edgy production assets

Exported 2026-11-07 from the final design source (look 26F-1TVB, render F for the icon and glyph, supplement sheet S5 for the glyph states). Spec: `docs/BRIEF.md` § "Menu glyph and app icon" and § "System states".

## Menu glyph

| File | State | Shape |
|---|---|---|
| `glyph-normal.pdf` | Normal | Pad outline, open on the right, plus the heavy right bar |
| `glyph-testMode.pdf` | Test Mode | Normal plus a solid dot inside the outline |
| `glyph-paused.pdf` | Paused | The heavy bar becomes two short stacked dashes |
| `glyph-disabled.pdf` | Disabled | Same artwork as normal. **Dim to 40% in code.** |
| `glyph-noTrackpad.pdf` | No trackpad | Same artwork as normal. **Dim to 40% in code.** |
| `glyph-needsAccessibility.pdf` | No Accessibility | The heavy bar becomes an exclamation: a short bar plus a dot |
| `glyph-brokenConfig.pdf` | Broken config | Same exclamation artwork as needsAccessibility |

- **Size:** 16 × 11 pt page, viewBox `0 2.5 16 11` (the source glyph is drawn on a 16 × 16 grid; the page is that grid cropped vertically to the ink, y 2.5 to 13.5).
- **Format:** single-page vector PDF, pure black (`#000000`) on a transparent page, no raster content.
- **Template image:** add to the asset catalog with "Render As: Template Image" (or set `image.isTemplate = true`) so macOS tints it for light, dark and highlighted menu bars. The PDFs carry no opacity. Disabled and No trackpad look like Normal at 40% opacity; apply that in code (for example `button.appearsDisabled = true` or `alphaValue = 0.4`).
- **Test Mode dot:** 3.2 pt diameter at 1× (r 1.6). That clears the ≥2 pt rule in the brief, so it is the source size, unchanged.
- **Precedence** when several states apply: No Accessibility > No trackpad > Paused > Disabled > Test Mode. Show the top one only.

## App icon

| File | What |
|---|---|
| `icon-1024.png` | Master, 1024 × 1024 |
| `AppIcon.iconset/` | `icon_16x16.png`, `icon_16x16@2x.png`, `icon_32x32.png`, `icon_32x32@2x.png`, `icon_128x128.png`, `icon_128x128@2x.png`, `icon_256x256.png`, `icon_256x256@2x.png`, `icon_512x512.png`, `icon_512x512@2x.png` |
| `AppIcon.icns` | Built with `iconutil -c icns AppIcon.iconset -o AppIcon.icns` |

- **Design ("Exact"):** pale-stone rounded tile (824/1024, standard macOS grid, with a soft shadow below it) with a light-to-shade vertical gradient, and a graphite line drawing of the pad at 160:100 with its heavy right side set apart.
- **Contact dot rule:** the rust `#B4542B` contact dot sits on the heavy right side **only at rendered sizes ≥128 px**. `icon_16x16`, `icon_16x16@2x` (32 px), `icon_32x32` and `icon_32x32@2x` (64 px) have no dot; 128 px and up have it.
- **Two drawings:** below 128 px the line drawing uses heavier strokes and a wider gap so it holds up when small. Each PNG was rendered from the vector at its own pixel size, not downscaled from the master.
- Outside the tile is transparent.

## SVG sources (`svg/`)

- `glyph-<state>.svg`, one per state, same geometry as the PDFs.
- `app-icon.svg`: the ≥128 px drawing. The rust dot is the group `<g id="contact-dot">`; delete that group for a dot-free export.
- `app-icon-small.svg`: the <128 px drawing (heavier strokes, no dot).

## How these were made

- Glyph PDFs: each `svg/glyph-<state>.svg` converted by a small script that writes the SVG paths as PDF vector operators (arcs become Bézier curves), page set to the viewBox exactly. Headless Chrome's print-to-PDF was tried first and rejected: it gave a 16.08 × 11.04 pt page with a 0.9993 scale.
- Icon PNGs: headless Chrome screenshots of the SVG at each native pixel size (`--force-device-scale-factor=1`, transparent default background), then `iconutil`.
