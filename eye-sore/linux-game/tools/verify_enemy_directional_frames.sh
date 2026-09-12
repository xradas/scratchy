#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/../.." && pwd)"
png_dir="$project_dir/public/enemies/directional"
bmp_dir="$project_dir/linux-game/assets/enemies/directional"
expected_count=128

png_count="$(find "$png_dir" -maxdepth 1 -name '*.png' | wc -l)"
bmp_count="$(find "$bmp_dir" -maxdepth 1 -name '*.bmp' | wc -l)"
[[ "$png_count" == "$expected_count" ]] || { echo "expected $expected_count PNG frames, found $png_count" >&2; exit 1; }
[[ "$bmp_count" == "$expected_count" ]] || { echo "expected $expected_count BMP frames, found $bmp_count" >&2; exit 1; }

for enemy_type in {0..3}; do
  for direction in {0..7}; do
    signatures=()
    for pose in {0..3}; do
      name="enemy-$enemy_type-dir-$direction-walk-$pose"
      png="$png_dir/$name.png"
      bmp="$bmp_dir/$name.bmp"
      [[ "$(identify -format '%wx%h' "$png")" == 384x256 ]] || { echo "$png has the wrong canvas" >&2; exit 1; }
      [[ "$(identify -format '%wx%h' "$bmp")" == 384x256 ]] || { echo "$bmp has the wrong canvas" >&2; exit 1; }
      identify -format '%[channels]' "$png" | grep -q a || { echo "$png has no alpha channel" >&2; exit 1; }
      [[ "$(magick "$png" -alpha extract -crop 384x1+0+255 +repage -format '%[fx:maxima]' info:)" != 0 ]] || { echo "$png is not anchored to its foot baseline" >&2; exit 1; }
      signatures+=("$(magick "$png" -format '%#' info:)")
    done
    unique_count="$(printf '%s\n' "${signatures[@]}" | sort -u | wc -l)"
    [[ "$unique_count" == 4 ]] || { echo "enemy $enemy_type direction $direction repeats a walking pose" >&2; exit 1; }
  done
done

echo "verified 4 enemies x 8 directions x 4 poses on fixed 384x256 canvases"
