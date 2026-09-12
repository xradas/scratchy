#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/../.." && pwd)"
out_dir="$project_dir/linux-game/assets/sounds"
folley_dir="$project_dir/public/audio-sources/cc0"
firearm_dir="$project_dir/public/audio-sources/free-firearm-library"
mkdir -p "$out_dir"

# Three separate CC0 field-recording takes per weapon. The game rotates them
# on every trigger pull, so repeated shots do not read as one copied WAV.
pistol_takes=(ppq-pistol.wav ppq-pistol-b.wav ppq-pistol-c.wav)
shotgun_takes=(mossberg-shotgun.wav mossberg-shotgun-b.wav mossberg-shotgun-c.wav)
arc_takes=(ak47-rifle.wav ak47-rifle-b.wav ak47-rifle-c.wav)

for take in 0 1 2; do
  ffmpeg -y -v error -i "$firearm_dir/${pistol_takes[$take]}" -i "$folley_dir/metal1.wav" \
    -filter_complex "[0:a]atrim=duration=0.34,asetpts=PTS-STARTPTS,aresample=11025,aresample=44100,volume=1.36[shot];[1:a]atrim=duration=0.20,asetpts=PTS-STARTPTS,highpass=f=700,volume=.16,adelay=28[slide];[shot][slide]amix=inputs=2:normalize=0,alimiter=limit=.97,atrim=duration=0.38" \
    -ac 1 -ar 44100 -c:a pcm_s16le "$out_dir/ember-pistol-$take.wav"
  ffmpeg -y -v error -i "$firearm_dir/${shotgun_takes[$take]}" -i "$folley_dir/steel1.wav" \
    -filter_complex "[0:a]atrim=duration=0.58,asetpts=PTS-STARTPTS,aresample=11025,aresample=44100,volume=1.30[shot];[1:a]atrim=duration=0.34,asetpts=PTS-STARTPTS,lowpass=f=2100,volume=.18,adelay=54[mechanism];[shot][mechanism]amix=inputs=2:normalize=0,alimiter=limit=.98,atrim=duration=0.66" \
    -ac 1 -ar 44100 -c:a pcm_s16le "$out_dir/rivet-shotgun-$take.wav"
  # The arc cannon keeps the same short, dry impact character using a
  # down-pitched rifle take and brief electrical-metal tail, not a long synth.
  ffmpeg -y -v error -i "$firearm_dir/${arc_takes[$take]}" -i "$folley_dir/metal1.wav" \
    -filter_complex "[0:a]atrim=duration=0.42,asetpts=PTS-STARTPTS,asetrate=33075,aresample=11025,aresample=44100,lowpass=f=4200,volume=1.30[core];[1:a]atrim=duration=0.25,asetpts=PTS-STARTPTS,highpass=f=950,volume=.18,adelay=62[coil];[core][coil]amix=inputs=2:normalize=0,alimiter=limit=.97,atrim=duration=0.62" \
    -ac 1 -ar 44100 -c:a pcm_s16le "$out_dir/arc-cannon-$take.wav"
done

ffmpeg -y -v error -i "$folley_dir/metal1.wav" -i "$folley_dir/cracker2.wav" \
  -filter_complex "[0:a]atrim=duration=0.45,asetpts=PTS-STARTPTS,volume=.92[plate];[1:a]atrim=duration=0.38,asetpts=PTS-STARTPTS,volume=.58,adelay=18[fracture];[plate][fracture]amix=inputs=2:normalize=0,alimiter=limit=.94" \
  -ac 1 -ar 44100 -c:a pcm_s16le "$out_dir/projectile-impact.wav"

ffmpeg -y -v error -i "$folley_dir/metal1.wav" -filter_complex "[0:a]atrim=duration=0.42,asetpts=PTS-STARTPTS,highpass=f=260,volume=1.10,alimiter=limit=.94" -ac 1 -ar 44100 -c:a pcm_s16le "$out_dir/enemy-hit-0.wav"
ffmpeg -y -v error -i "$folley_dir/cracker2.wav" -filter_complex "[0:a]atrim=duration=0.52,asetpts=PTS-STARTPTS,lowpass=f=3800,volume=1.05,alimiter=limit=.94" -ac 1 -ar 44100 -c:a pcm_s16le "$out_dir/enemy-hit-1.wav"
ffmpeg -y -v error -i "$folley_dir/steel1.wav" -filter_complex "[0:a]atrim=duration=0.72,asetpts=PTS-STARTPTS,highpass=f=680,volume=.85,aecho=0.8:0.35:82:0.20,alimiter=limit=.94" -ac 1 -ar 44100 -c:a pcm_s16le "$out_dir/enemy-hit-2.wav"
ffmpeg -y -v error -i "$folley_dir/metal1.wav" -i "$folley_dir/steel1.wav" -filter_complex "[0:a]atrim=duration=0.45,asetpts=PTS-STARTPTS,lowpass=f=900,volume=1.08[body];[1:a]atrim=duration=0.50,asetpts=PTS-STARTPTS,lowpass=f=1400,volume=.48,adelay=34[ring];[body][ring]amix=inputs=2:normalize=0,alimiter=limit=.95" -ac 1 -ar 44100 -c:a pcm_s16le "$out_dir/enemy-hit-3.wav"
