#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/../.." && pwd)"
source_image="$project_dir/public/infernal-firing-sheet.png"
png_dir="$project_dir/public/weapons"
bmp_dir="$project_dir/linux-game/assets/weapons"
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

mkdir -p "$png_dir" "$bmp_dir"
magick "$source_image" -crop 4x3@ +repage "$work_dir/frame-%02d.png"

for weapon in {0..2}; do
  for frame in {0..3}; do
    index=$((weapon * 4 + frame))
    name="weapon-$weapon-frame-$frame"
    magick "$work_dir/frame-$(printf '%02d' "$index").png" "$png_dir/$name.png"
    # Keep the source alpha in a 32-bit BMP. Flattening here creates the black
    # rectangle that surrounds the view model in-game.
    magick "$png_dir/$name.png" -define bmp:format=bmp4 "$bmp_dir/$name.bmp"
  done
done
