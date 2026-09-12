#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/../.." && pwd)"
source_image="$project_dir/public/infernal-firing-sheet.png"
png_dir="$project_dir/public/weapons"
bmp_dir="$project_dir/linux-game/assets/weapons"
sound_dir="$project_dir/linux-game/assets/sounds"
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

[[ "$(identify -format '%wx%h' "$source_image")" == 1536x1024 ]] || { echo "weapon source has the wrong dimensions" >&2; exit 1; }
[[ "$(find "$png_dir" -maxdepth 1 -name '*.png' | wc -l)" == 12 ]] || { echo "expected 12 weapon PNG frames" >&2; exit 1; }
[[ "$(find "$bmp_dir" -maxdepth 1 -name '*.bmp' | wc -l)" == 12 ]] || { echo "expected 12 weapon BMP frames" >&2; exit 1; }

for weapon in {0..2}; do
  row=()
  for frame in {0..3}; do
    png="$png_dir/weapon-$weapon-frame-$frame.png"
    bmp="$bmp_dir/weapon-$weapon-frame-$frame.bmp"
    row+=("$png")
    identify -format '%[channels]' "$bmp" | grep -q a || { echo "$bmp lost its transparent background" >&2; exit 1; }
    [[ "$(compare -metric AE "$png" "$bmp" null: 2>&1)" == "0 (0)" ]] || { echo "$bmp does not match its source frame" >&2; exit 1; }
  done
  magick "${row[@]}" +append "$work_dir/row-$weapon.png"
done
magick "$work_dir/row-0.png" "$work_dir/row-1.png" "$work_dir/row-2.png" -append "$work_dir/rebuilt.png"
[[ "$(compare -metric AE "$source_image" "$work_dir/rebuilt.png" null: 2>&1)" == "0 (0)" ]] || { echo "standalone weapon frames do not reconstruct the original sheet" >&2; exit 1; }

for spec in "ember-pistol.wav:0.420000" "rivet-shotgun.wav:0.720000" "arc-cannon.wav:0.860000"; do
  file="${spec%%:*}";duration="${spec##*:}";path="$sound_dir/$file"
  [[ "$(ffprobe -v error -show_entries stream=codec_name -of default=nk=1:nw=1 "$path")" == pcm_s16le ]] || { echo "$file is not PCM" >&2; exit 1; }
  [[ "$(ffprobe -v error -show_entries stream=sample_rate -of default=nk=1:nw=1 "$path")" == 44100 ]] || { echo "$file has the wrong sample rate" >&2; exit 1; }
  [[ "$(ffprobe -v error -show_entries stream=channels -of default=nk=1:nw=1 "$path")" == 1 ]] || { echo "$file is not mono" >&2; exit 1; }
  [[ "$(ffprobe -v error -show_entries stream=duration -of default=nk=1:nw=1 "$path")" == "$duration" ]] || { echo "$file has the wrong duration" >&2; exit 1; }
done

echo "verified original sheet -> 12 isolated frames, plus 3 mono PCM weapon sounds"
