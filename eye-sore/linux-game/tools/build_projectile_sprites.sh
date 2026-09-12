#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/../.." && pwd)"
source_dir="$project_dir/public/projectiles/sources"
perspective_dir="$project_dir/public/projectiles/directional-sources"
first_person_dir="$project_dir/public/projectiles/first-person-sources"
png_dir="$project_dir/public/projectiles"
bmp_dir="$project_dir/linux-game/assets/projectiles"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$png_dir" "$bmp_dir"

canvas_sprite() {
  magick "$1" -trim +repage -filter point -resize '256x128>' \
    -gravity center -background none -extent 256x128 "$2"
}

names=(player-pistol player-shotgun player-arc cultist-fire wraith-plasma)
directions=(toward toward-right right away-right away away-left left toward-left)

for name in "${names[@]}"; do
  canvas_sprite "$source_dir/$name-source.png" "$png_dir/$name.png"
  canvas_sprite "$png_dir/$name.png" "$png_dir/$name-dir-right.png"
  magick "$png_dir/$name.png" -trim +repage -resize '42%x100%' -modulate 118,100,100 -gravity center -background none -extent 256x128 "$png_dir/$name-dir-toward.png"
  magick "$png_dir/$name.png" -trim +repage -resize '70%x100%' -modulate 108,100,100 -gravity center -background none -extent 256x128 "$png_dir/$name-dir-toward-right.png"
  magick "$png_dir/$name.png" -trim +repage -resize '70%x100%' -modulate 82,88,100 -gravity center -background none -extent 256x128 "$png_dir/$name-dir-away-right.png"
  magick "$png_dir/$name.png" -trim +repage -resize '42%x100%' -flop -modulate 72,88,100 -gravity center -background none -extent 256x128 "$png_dir/$name-dir-away.png"
  magick "$png_dir/$name.png" -trim +repage -resize '70%x100%' -flop -modulate 82,88,100 -gravity center -background none -extent 256x128 "$png_dir/$name-dir-away-left.png"
  magick "$png_dir/$name.png" -flop "$png_dir/$name-dir-left.png"
  magick "$png_dir/$name.png" -trim +repage -resize '70%x100%' -flop -modulate 108,100,100 -gravity center -background none -extent 256x128 "$png_dir/$name-dir-toward-left.png"
done

# Full-frame launch art is drawn over the first-person weapon for the brief
# moment a shot leaves its muzzle. Keep its transparent padding so nothing is
# clipped when the effect grows on screen.
for name in player-pistol player-shotgun; do
  magick "$first_person_dir/$name-launch.png" -trim +repage -filter point -resize '512x512>' \
    -gravity south -background none -extent 512x512 "$png_dir/first-person-$name.png"
  magick "$png_dir/first-person-$name.png" -define bmp:format=bmp4 "$bmp_dir/first-person-$name.bmp"
done

# The arc cannon is one continuous first-person bolt. Black is made transparent
# before trimming, so its original rectangular canvas cannot become a second bolt.
for asset in player-arc-perspective-bolt-v2 player-arc-muzzle-flash; do
  magick "$first_person_dir/$asset.png" -alpha off -fuzz 5% -transparent black -trim +repage -bordercolor none -border 36 -filter point -resize '440x440>' \
    -gravity center -background none -extent 512x512 "$png_dir/first-person-$asset.png"
  magick "$png_dir/first-person-$asset.png" -define bmp:format=bmp4 "$bmp_dir/first-person-$asset.bmp"
done

# Real ImageGen front/left/right cells replace the player projectiles' old
# scaled/flipped art. Diagonals bridge those purpose-built perspectives.
for name in player-pistol player-shotgun player-arc; do
  magick "$perspective_dir/$name-perspectives.png" -crop 3x1@ +repage "$tmp_dir/$name-cell.png"
  canvas_sprite "$tmp_dir/$name-cell-0.png" "$png_dir/$name-dir-toward.png"
  canvas_sprite "$tmp_dir/$name-cell-1.png" "$png_dir/$name-dir-right.png"
  canvas_sprite "$tmp_dir/$name-cell-2.png" "$png_dir/$name-dir-left.png"
  magick "$png_dir/$name-dir-right.png" -trim +repage -resize '78%x100%' -modulate 108,100,100 -gravity center -background none -extent 256x128 "$png_dir/$name-dir-toward-right.png"
  magick "$png_dir/$name-dir-right.png" -trim +repage -resize '72%x100%' -modulate 78,88,100 -gravity center -background none -extent 256x128 "$png_dir/$name-dir-away-right.png"
  magick "$png_dir/$name-dir-toward.png" -trim +repage -modulate 66,82,100 -gravity center -background none -extent 256x128 "$png_dir/$name-dir-away.png"
  magick "$png_dir/$name-dir-left.png" -trim +repage -resize '72%x100%' -modulate 78,88,100 -gravity center -background none -extent 256x128 "$png_dir/$name-dir-away-left.png"
  magick "$png_dir/$name-dir-left.png" -trim +repage -resize '78%x100%' -modulate 108,100,100 -gravity center -background none -extent 256x128 "$png_dir/$name-dir-toward-left.png"
done

for name in "${names[@]}"; do
  magick "$png_dir/$name.png" -define bmp:format=bmp4 "$bmp_dir/$name.bmp"
  for direction in "${directions[@]}"; do
    magick "$png_dir/$name-dir-$direction.png" -define bmp:format=bmp4 "$bmp_dir/$name-dir-$direction.bmp"
  done
done
