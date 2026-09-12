#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/../.." && pwd)"
source_dir="$project_dir/public/enemies/sources"
png_dir="$project_dir/public/enemies/directional"
bmp_dir="$project_dir/linux-game/assets/enemies/directional"
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

mkdir -p "$png_dir" "$bmp_dir"

for enemy_type in 0 1 2 3; do
  source_image="$source_dir/enemy-$enemy_type-directional-source.png"
  frame_dir="$work_dir/enemy-$enemy_type"
  mkdir -p "$frame_dir"

  if [[ "$enemy_type" == 1 ]]; then
    # The original cultist source contains three authored rows. Its fourth
    # stride is stored separately so all four steps are genuinely distinct.
    magick "$source_image" -alpha set -channel A \
      -fx '((max(r,max(g,b))-min(r,min(g,b))<0.06)&&((r+g+b)/3>0.22))?0:1' \
      -morphology Open Diamond \
      -crop 1774x750+0+0 +repage "$frame_dir/keyed.png"
    magick "$frame_dir/keyed.png" -crop 8x3@ +repage "$frame_dir/raw-%02d.png"
    magick "$source_dir/enemy-1-directional-walk-row-3.png" -alpha set -channel A \
      -fx '((max(r,max(g,b))-min(r,min(g,b))<0.06)&&((r+g+b)/3>0.22))?0:1' \
      -morphology Open Diamond -crop 8x1@ +repage "$frame_dir/fourth-%02d.png"
    poses=(0 1 2 3)
    edge_shave="3x10"
  else
    magick "$source_image" -crop 8x4@ +repage "$frame_dir/raw-%02d.png"
    poses=(0 1 2 3)
    edge_shave="3x5"
  fi

  for direction in {0..7}; do
    for pose in {0..3}; do
      source_pose="${poses[$pose]}"
      source_index=$((source_pose * 8 + direction))
      output_name="enemy-$enemy_type-dir-$direction-walk-$pose"
      if [[ "$enemy_type" == 1 && "$pose" == 3 ]]; then
        magick "$frame_dir/fourth-$(printf '%02d' "$direction").png" \
          -shave "$edge_shave" -trim +repage -resize x230 \
          -gravity south -background none -extent 384x256 "$png_dir/$output_name.png"
      else
        magick "$frame_dir/raw-$(printf '%02d' "$source_index").png" \
          -shave "$edge_shave" -trim +repage -gravity south -background none -extent 384x256 \
          "$png_dir/$output_name.png"
      fi
      magick "$png_dir/$output_name.png" -background black -alpha remove \
        "$bmp_dir/$output_name.bmp"
    done
  done
done
