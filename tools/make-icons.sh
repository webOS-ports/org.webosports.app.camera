#!/bin/sh
# Renders the app's launcher icons from camera-icon.svg (the legacy webOS
# camera's icon, redrawn as vectors) with Qt's own SVG renderer, at the size
# each needs: icon.png (64x64) and icon-256x256.png.
#
#   tools/make-icons.sh <svgcheck>
#
# svgcheck is built by tools/vectorize/build-artwork.sh.
set -e
cd "$(dirname "$0")/.."
S=${1:?usage: make-icons.sh <svgcheck>}
"$S" render camera-icon.svg 1 icon-256x256.png
"$S" render camera-icon.svg 0.25 icon.png
