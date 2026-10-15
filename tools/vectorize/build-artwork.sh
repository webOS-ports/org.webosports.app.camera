#!/bin/sh
# Builds the tools, redraws every button from its spec, checks each SVG
# against the bitmap it was drawn after, and renders each at 4x and 8x for
# a look.
#
#   tools/vectorize/build-artwork.sh [build dir]
#
# Needs Qt 6 with Qt SVG (development files) on the build host.
set -e
cd "$(dirname "$0")"
B=${1:-../../build/vectorize}
cmake -S . -B "$B" -G Ninja -DCMAKE_BUILD_TYPE=Release > /dev/null
ninja -C "$B" > /dev/null
mkdir -p "$B/scaled"
for spec in specs/*.json; do
    name=$(basename "$spec" .json)
    "$B/vectorfit" "$spec" | tail -n 1 | sed "s|^|$name: |"
    for k in 4 8; do
        "$B/svgcheck" render "../../qml/images/$name.svg" $k "$B/scaled/$name@${k}x.png"
    done
done
echo "4x and 8x renders in $B/scaled"
