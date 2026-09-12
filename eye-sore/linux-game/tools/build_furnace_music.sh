#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/../.." && pwd)"
out_dir="$project_dir/linux-game/assets/music"
folley_dir="$project_dir/public/audio-sources/cc0"
firearm_dir="$project_dir/public/audio-sources/free-firearm-library"
mkdir -p "$out_dir"

# A restrained, non-musical room bed: distant recorded metal and low-passed
# firearm reverberation with long gaps. It has no MIDI, oscillator, or melody.
ffmpeg -y -v error \
  -f lavfi -i "anullsrc=r=44100:cl=mono:d=24" \
  -i "$folley_dir/metal1.wav" -i "$folley_dir/steel1.wav" -i "$firearm_dir/ak47-rifle.wav" \
  -filter_complex "[1:a]atrim=duration=0.48,asetpts=PTS-STARTPTS,lowpass=f=1700,volume=.18,asplit=4[m0][m1][m2][m3];[m0]adelay=1600[m0d];[m1]adelay=6980[m1d];[m2]adelay=13100[m2d];[m3]adelay=20240[m3d];[m0d][m1d][m2d][m3d]amix=inputs=4:normalize=0[metal];[2:a]atrim=duration=0.80,asetpts=PTS-STARTPTS,lowpass=f=950,volume=.11,asplit=3[s0][s1][s2];[s0]adelay=4020[s0d];[s1]adelay=11120[s1d];[s2]adelay=17860[s2d];[s0d][s1d][s2d]amix=inputs=3:normalize=0[steel];[3:a]atrim=duration=1.25,asetpts=PTS-STARTPTS,asetrate=26000,aresample=44100,lowpass=f=280,volume=.055,aecho=0.82:0.42:310:0.40,adelay=8400[rumble];[0:a][metal][steel][rumble]amix=inputs=4:normalize=0,alimiter=limit=.42,atrim=duration=24" \
  -ac 1 -ar 44100 -c:a pcm_s16le "$out_dir/furnace-descent-loop.wav"
