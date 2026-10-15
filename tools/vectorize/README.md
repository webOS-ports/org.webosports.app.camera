# The camera's artwork as vectors

The camera's controls are the legacy webOS camera's (the Pre3's 1.5x
artwork; the front/back arrows are the Pre3 email app's sync icon). The
bitmaps are kept in `reference/`; the app uses them redrawn as SVG
(`qml/images/*.svg`), rendered at the size they are shown, so they stay
sharp and smooth at any size.

    tools/vectorize/build-artwork.sh [build dir]

builds the two tools, redraws every SVG that has a spec in `specs/`, prints
how close each comes to its bitmap and puts 4x and 8x renders in
`<build dir>/scaled`. It needs Qt 6 with Qt SVG (development files). The
specs are frozen, so a second run gives the same files byte for byte.

The tools and the record, stop, round-button and bezel specs come from
org.webosports.app.soundrecorder, which drew those buttons first.

## How they are drawn

`vectorfit` builds each picture the way it was drawn: a stack of discs,
rings, half discs and rings cut at the gloss line, rectangles, the
shutter's blades ("aperture") and free outlines ("path"), each with a
gradient (vertical, horizontal or radial). The specs say which shapes and
where; the colours are not written down anywhere but solved for.

- **Inner shapes go underneath** the ring around them. Shapes that only
  meet are both anti-aliased along the seam and the seam comes out light.
  For the same reason the shutter's blades are drawn whole, and the part
  above the gloss line drawn again on top, rather than as two halves.
- **Smooth stays smooth.** A soft shadow is one gradient, never a stack of
  steps. Broad fills get few stops and a strong "smooth" of their own, so
  they stay one even ramp when enlarged instead of following every row of
  the bitmap; that is what keeps the shutter free of bands at 8x.
- **Colours are solved, not picked.** With the shapes fixed, what Qt draws
  is linear in one layer's stop colours (opacities held) and in its stop
  opacities (colours held), so each layer is solved by least squares
  against the bitmap, in turn, round after round. Qt interpolates gradients
  in straight colour, not premultiplied.
- **The geometry is searched** around the measured values - centres,
  radii, the gloss line, rectangles, the blades (radius, hexagon, turn,
  gap), a shadow's offset and blur - solving the colours again each time.
  `vectorfit <spec> --freeze` writes the result back into the spec.

The shutter's blades: blade k is the part of the disc beyond side k+1 of a
hexagon, moved out by the gap, and short of the line of side k. Each is the
disc cut by straight lines, so the outline is exact straight edges and
circle arcs at any size.

A "path" layer's "blur" is a Gaussian blur filter, used for the shadow and
glow of the toggle icons and the sync arrows. Filters and masks are not SVG
Tiny; Qt SVG renders them from Qt 6.7 (LuneOS has 6.12).

Everything is rendered with QSvgRenderer, the renderer QML uses for SVG on
the device.

## Drawn outside vectorfit

These were fitted with scratch scripts (numerical fits against the bitmaps,
rendered with QSvgRenderer) that are not kept here; the SVGs are the
result:

- `menu-bezel-camera`: two circles joined by tangent curves, a vertical
  gradient of black.
- `timer-background`, `blank-thumbnail`: a rounded rectangle and a frame,
  vertical gradients.
- `view-finder*`: rings, arcs and the cross; the focusing ring's glow and
  the locked ring are radial gradients, the glow drawn whole under the
  gapped ring.
- `image-overlay(-pressed)`: the frame's stroke, inner highlights and drop
  shadow or glow, from gradient strips and corners around the rounded
  rectangle (one SVG with both frames, each file showing its half).
- `flash-off/on/auto(-pressed)`: the round button's SVG with the icon on
  top: the bolt and the AUTO letters as polygons and fitted curves, the
  barred ring through a mask.

## The app icon

`camera-icon.svg` is the legacy camera's app icon (`reference/app-icon-256x256.png`),
rebuilt by `camera-icon.py` as plain shapes - body, brushed panel, grip,
shutter button, viewfinder, light, lens rings and glass, the engraving in
LuneOS's Prelude as glyph outlines - with colours read from the original:

    python3 -I tools/vectorize/camera-icon.py <PreludeWGL-Medium.ttf>
    tools/make-icons.sh <svgcheck>

The second renders `icon.png` (64x64) and `icon-256x256.png` from it.

## How close they are

`svgcheck compare <svg> <png> [x y w h]` compares premultiplied RGBA (what
is seen once drawn). At 1x, 2026-10-15:

| SVG | PSNR | largest difference |
|---|---|---|
| bezel | 60.9 dB | 10 |
| blank-thumbnail | 60.2 dB | 1 |
| timer-background | 57.5 dB | 12 |
| view-finder | 56.4 dB | 20 |
| view-finder-autofocus-lock | 54.0 dB | 16 |
| menu-bezel-camera | 52.9 dB | 29 |
| image-overlay | 44.9 dB | 48 |
| round-button-pressed | 44.6 dB | 16 |
| view-finder-autofocus | 43.1 dB | 32 |
| stop | 42.5 dB | 22 |
| record | 42.1 dB | 29 |
| record-pressed | 41.8 dB | 30 |
| stop-pressed | 41.3 dB | 31 |
| round-button | 40.8 dB | 24 |
| flash-on | 40.8 dB | 24 |
| flash-off | 39.5 dB | 31 |
| image-overlay-pressed | 39.1 dB | 29 |
| flash-on-pressed | 38.4 dB | 62 |
| flash-auto | 37.8 dB | 47 |
| flash-auto-pressed | 37.4 dB | 58 |
| mode-photo-pressed | 36.6 dB | 54 |
| flash-off-pressed | 35.1 dB | 79 |
| mode-video-pressed | 33.6 dB | 88 |
| shutter-pressed | 33.3 dB | 68 |
| mode-photo | 33.2 dB | 45 |
| shutter | 31.7 dB | 153 |
| mode-video | 30.6 dB | 134 |
| icon-sync | 27.4 dB | 122 |

The shutter's blades and the sync arrows' tails were drawn to the design
rather than to the bitmap's pixels (wider gaps and brighter blades; square,
rounded tails in line with the arrowheads), which costs a little at 1x.

The fills, the shading and the shadows match to a level or two. What is
left is on anti-aliased edges - the blades', the icons', the rims': the
bitmaps' edges were anti-aliased by the program they were drawn in, and a
vector edge drawn by Qt cannot repeat that bit for bit. Matching those
pixels exactly would take squares for pixels, which would no longer be
smooth when scaled up. The view-finder rings also carry a fine speckle in
the bitmaps that a smooth gradient leaves out.
