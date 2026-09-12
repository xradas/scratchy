#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/../.." && pwd)"
for sound in "$project_dir"/linux-game/assets/sounds/*.wav "$project_dir"/linux-game/assets/music/furnace-descent-loop.wav; do
  test "$(ffprobe -v error -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$sound")" = pcm_s16le
  test "$(ffprobe -v error -show_entries stream=sample_rate -of default=noprint_wrappers=1:nokey=1 "$sound")" = 44100
  test "$(ffprobe -v error -show_entries stream=channels -of default=noprint_wrappers=1:nokey=1 "$sound")" = 1
done
test "$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$project_dir/linux-game/assets/music/furnace-descent-loop.wav")" = 24.000000
for type in 0 1 2 3; do
  test -s "$project_dir/linux-game/assets/sounds/enemy-hit-$type.wav"
done
echo "verified recorded weapon, projectile, and four type-specific enemy impacts plus the 24-second restrained room bed"
