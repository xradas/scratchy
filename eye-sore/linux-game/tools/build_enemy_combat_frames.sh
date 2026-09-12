#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/../.." && pwd)"
source_dir="$project_dir/public/enemies/sources"
png_dir="$project_dir/public/enemies/combat"
bmp_dir="$project_dir/linux-game/assets/enemies/combat"
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

mkdir -p "$png_dir" "$bmp_dir"
states=(pain attack death gib)

for enemy_type in {0..3}; do
  source_image="$source_dir/enemy-$enemy_type-combat-source.png"
  frame_dir="$work_dir/enemy-$enemy_type"
  mkdir -p "$frame_dir"

  if [[ "$enemy_type" == 0 ]]; then
    magick "$source_image" -crop 4x4@ +repage "$frame_dir/raw-%02d.png"
  else
    # Some generated sources contain a baked neutral checkerboard. Remove it
    # before splitting while retaining the saturated sprite and dark outline.
    magick "$source_image" -alpha set -channel A \
      -fx '((max(r,max(g,b))-min(r,min(g,b))<0.06)&&((r+g+b)/3>0.22))?0:1' \
      -morphology Open Diamond "$frame_dir/keyed.png"
    magick "$frame_dir/keyed.png" -crop 4x4@ +repage "$frame_dir/raw-%02d.png"
  fi

  for state_index in {0..3}; do
    for frame in {0..3}; do
      source_index=$((state_index * 4 + frame))
      output_name="enemy-$enemy_type-${states[$state_index]}-$frame"
      # Scale the whole source cell once, then trim only for anchoring. This
      # preserves relative pose scale while allowing wide corpses and effects.
      magick "$frame_dir/raw-$(printf '%02d' "$source_index").png" \
        -resize x256 -channel A -threshold 5% +channel -trim +repage \
        -gravity south -background none -extent 384x256 \
        "$png_dir/$output_name.png"
      if [[ "$enemy_type" == 1 && "$state_index" == 1 && "$frame" == 3 ]]; then
        # Remove a detached projectile sliver that spilled into the recovery
        # cell in the generated source; the cultist itself begins well right.
        magick "$png_dir/$output_name.png" -channel A -fill black \
          -draw 'rectangle 0,0 80,255' "$png_dir/$output_name.png"
      fi
      magick "$png_dir/$output_name.png" -background black -alpha remove \
        "$bmp_dir/$output_name.bmp"
    done
  done
done
