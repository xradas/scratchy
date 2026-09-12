#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/../.." && pwd)"
png_dir="$project_dir/public/enemies/combat"
bmp_dir="$project_dir/linux-game/assets/enemies/combat"
states=(pain attack death gib)
expected_count=64

png_count="$(find "$png_dir" -maxdepth 1 -name '*.png' | wc -l)"
bmp_count="$(find "$bmp_dir" -maxdepth 1 -name '*.bmp' | wc -l)"
[[ "$png_count" == "$expected_count" ]] || { echo "expected $expected_count PNG frames, found $png_count" >&2; exit 1; }
[[ "$bmp_count" == "$expected_count" ]] || { echo "expected $expected_count BMP frames, found $bmp_count" >&2; exit 1; }

for enemy_type in {0..3}; do
  for state in "${states[@]}"; do
    for frame in {0..3}; do
      name="enemy-$enemy_type-$state-$frame"
      png="$png_dir/$name.png"
      bmp="$bmp_dir/$name.bmp"
      [[ "$(identify -format '%wx%h' "$png")" == 384x256 ]] || { echo "$png has the wrong canvas" >&2; exit 1; }
      [[ "$(identify -format '%wx%h' "$bmp")" == 384x256 ]] || { echo "$bmp has the wrong canvas" >&2; exit 1; }
      identify -format '%[channels]' "$png" | grep -q a || { echo "$png has no alpha channel" >&2; exit 1; }
      if [[ "$frame" == 3 && ("$state" == death || "$state" == gib) ]]; then
        [[ "$(magick "$png" -alpha extract -crop 384x8+0+248 +repage -format '%[fx:maxima]' info:)" != 0 ]] || { echo "$png corpse is not anchored within the floor baseline tolerance" >&2; exit 1; }
      fi
    done
  done
done

echo "verified 4 enemies x 4 combat states x 4 frames on uncropped 384x256 canvases"
