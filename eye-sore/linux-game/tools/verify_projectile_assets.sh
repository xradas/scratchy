#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/../.." && pwd)"
for name in player-pistol player-shotgun player-arc; do
  source="$project_dir/public/projectiles/directional-sources/$name-perspectives.png"
  test -f "$source"
  [[ "$(magick identify -format '%[channels]' "$source")" == srgba* ]]
done
for name in player-pistol player-shotgun; do
  source="$project_dir/public/projectiles/first-person-sources/$name-launch.png"
  png="$project_dir/public/projectiles/first-person-$name.png"
  bmp="$project_dir/linux-game/assets/projectiles/first-person-$name.bmp"
  test -f "$source" && test -f "$png" && test -f "$bmp"
  test "$(magick identify -format '%wx%h' "$png")" = "512x512"
  [[ "$(magick identify -format '%[channels]' "$png")" == srgba* ]]
  [[ "$(magick identify -format '%[channels]' "$bmp")" == srgba* ]]
  read -r png_alpha_min png_alpha_max <<< "$(magick "$png" -channel A -format '%[minima] %[maxima]' info:)"
  read -r bmp_alpha_min bmp_alpha_max <<< "$(magick "$bmp" -channel A -format '%[minima] %[maxima]' info:)"
  test "$png_alpha_min" = 0 && test "$png_alpha_max" -gt 0
  test "$bmp_alpha_min" = 0 && test "$bmp_alpha_max" -gt 0
  magick compare -metric AE "$png" "$bmp" null: 2>&1 | grep -qx '0 (0)'
done
for asset in player-arc-perspective-bolt-v2 player-arc-muzzle-flash; do
  source="$project_dir/public/projectiles/first-person-sources/$asset.png"
  png="$project_dir/public/projectiles/first-person-$asset.png"
  bmp="$project_dir/linux-game/assets/projectiles/first-person-$asset.bmp"
  test -f "$source" && test -f "$png" && test -f "$bmp"
  test "$(magick identify -format '%wx%h' "$png")" = "512x512"
  [[ "$(magick identify -format '%[channels]' "$png")" == srgba* ]]
  [[ "$(magick identify -format '%[channels]' "$bmp")" == srgba* ]]
  read -r png_alpha_min png_alpha_max <<< "$(magick "$png" -channel A -format '%[minima] %[maxima]' info:)"
  read -r bmp_alpha_min bmp_alpha_max <<< "$(magick "$bmp" -channel A -format '%[minima] %[maxima]' info:)"
  test "$png_alpha_min" = 0 && test "$png_alpha_max" -gt 0
  test "$bmp_alpha_min" = 0 && test "$bmp_alpha_max" -gt 0
  magick compare -metric AE "$png" "$bmp" null: 2>&1 | grep -qx '0 (0)'
done
for name in player-pistol player-shotgun player-arc cultist-fire wraith-plasma; do
  for direction in toward toward-right right away-right away away-left left toward-left; do
  png="$project_dir/public/projectiles/$name-dir-$direction.png"
  bmp="$project_dir/linux-game/assets/projectiles/$name-dir-$direction.bmp"
  test -f "$png" && test -f "$bmp"
  test "$(magick identify -format '%wx%h' "$png")" = "256x128"
  [[ "$(magick identify -format '%[channels]' "$png")" == srgba* ]]
  [[ "$(magick identify -format '%[channels]' "$bmp")" == srgba* ]]
  read -r png_alpha_min png_alpha_max <<< "$(magick "$png" -channel A -format '%[minima] %[maxima]' info:)"
  read -r bmp_alpha_min bmp_alpha_max <<< "$(magick "$bmp" -channel A -format '%[minima] %[maxima]' info:)"
  test "$png_alpha_min" = 0 && test "$png_alpha_max" -gt 0
  test "$bmp_alpha_min" = 0 && test "$bmp_alpha_max" -gt 0
  magick compare -metric AE "$png" "$bmp" null: 2>&1 | grep -qx '0 (0)'
  done
done
echo "verified ImageGen perspective sheets, forty directional projectile sprites, and four first-person launch/muzzle effects"
