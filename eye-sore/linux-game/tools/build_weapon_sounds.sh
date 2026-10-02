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
  # Original retro-FPS weapon design: recorded attack, a fast broadband crack,
  # and a decaying synthesized low thump. These added layers are generated
  # here and are not samples from another game's sound set.
  ffmpeg -y -v error -i "$firearm_dir/${pistol_takes[$take]}" -i "$folley_dir/metal1.wav" \
    -f lavfi -i "aevalsrc=0.9*sin(2*PI*82*t)*exp(-t*22):s=44100:d=0.25" \
    -f lavfi -i "anoisesrc=color=pink:amplitude=0.28:duration=0.12:sample_rate=44100" \
    -filter_complex "[0:a]atrim=duration=0.34,asetpts=PTS-STARTPTS,aresample=11025,aresample=44100,volume=1.48[shot];[1:a]atrim=duration=0.20,asetpts=PTS-STARTPTS,highpass=f=700,volume=.13,adelay=22[slide];[2:a]lowpass=f=150,volume=.88[bass];[3:a]highpass=f=950,lowpass=f=6500,afade=t=out:st=0:d=0.12,volume=.34[crack];[shot][slide][bass][crack]amix=inputs=4:normalize=0,acompressor=threshold=.12:ratio=2.8:attack=2:release=85:makeup=1.25,alimiter=limit=.96,atrim=duration=0.38" \
    -ac 1 -ar 44100 -c:a pcm_s16le "$out_dir/ember-pistol-$take.wav"
  ffmpeg -y -v error -i "$firearm_dir/${shotgun_takes[$take]}" -i "$folley_dir/steel1.wav" \
    -f lavfi -i "aevalsrc=1.0*sin(2*PI*66*t)*exp(-t*15):s=44100:d=0.34" \
    -f lavfi -i "anoisesrc=color=white:amplitude=0.34:duration=0.18:sample_rate=44100" \
    -filter_complex "[0:a]atrim=duration=0.58,asetpts=PTS-STARTPTS,aresample=11025,aresample=44100,volume=1.42[shot];[1:a]atrim=duration=0.34,asetpts=PTS-STARTPTS,lowpass=f=2100,volume=.20,adelay=42[mechanism];[2:a]lowpass=f=125,volume=.95[bass];[3:a]highpass=f=600,lowpass=f=5200,afade=t=out:st=0:d=0.18,volume=.42[crack];[shot][mechanism][bass][crack]amix=inputs=4:normalize=0,acompressor=threshold=.14:ratio=3.2:attack=2:release=110:makeup=1.35,alimiter=limit=.97,atrim=duration=0.66" \
    -ac 1 -ar 44100 -c:a pcm_s16le "$out_dir/rivet-shotgun-$take.wav"
  ffmpeg -y -v error -i "$firearm_dir/${arc_takes[$take]}" -i "$folley_dir/metal1.wav" \
    -f lavfi -i "aevalsrc=0.85*sin(2*PI*54*t)*exp(-t*13):s=44100:d=0.42" \
    -f lavfi -i "anoisesrc=color=pink:amplitude=0.19:duration=0.24:sample_rate=44100" \
    -filter_complex "[0:a]atrim=duration=0.42,asetpts=PTS-STARTPTS,asetrate=33075,aresample=11025,aresample=44100,lowpass=f=4200,volume=1.38[core];[1:a]atrim=duration=0.25,asetpts=PTS-STARTPTS,highpass=f=950,volume=.16,adelay=62[coil];[2:a]lowpass=f=115,volume=1.0[bass];[3:a]bandpass=f=1500:w=1900,afade=t=out:st=0:d=0.24,volume=.30[arc];[core][coil][bass][arc]amix=inputs=4:normalize=0,acompressor=threshold=.12:ratio=2.6:attack=3:release=120:makeup=1.32,alimiter=limit=.96,atrim=duration=0.62" \
    -ac 1 -ar 44100 -c:a pcm_s16le "$out_dir/arc-cannon-$take.wav"
done

ffmpeg -y -v error -i "$folley_dir/metal1.wav" -i "$folley_dir/cracker2.wav" \
  -filter_complex "[0:a]atrim=duration=0.45,asetpts=PTS-STARTPTS,volume=.92[plate];[1:a]atrim=duration=0.38,asetpts=PTS-STARTPTS,volume=.58,adelay=18[fracture];[plate][fracture]amix=inputs=2:normalize=0,alimiter=limit=.94" \
  -ac 1 -ar 44100 -c:a pcm_s16le "$out_dir/projectile-impact.wav"

ffmpeg -y -v error -i "$folley_dir/metal1.wav" -filter_complex "[0:a]atrim=duration=0.42,asetpts=PTS-STARTPTS,highpass=f=260,volume=1.10,alimiter=limit=.94" -ac 1 -ar 44100 -c:a pcm_s16le "$out_dir/enemy-hit-0.wav"
ffmpeg -y -v error -i "$folley_dir/cracker2.wav" -filter_complex "[0:a]atrim=duration=0.52,asetpts=PTS-STARTPTS,lowpass=f=3800,volume=1.05,alimiter=limit=.94" -ac 1 -ar 44100 -c:a pcm_s16le "$out_dir/enemy-hit-1.wav"
ffmpeg -y -v error -i "$folley_dir/steel1.wav" -filter_complex "[0:a]atrim=duration=0.72,asetpts=PTS-STARTPTS,highpass=f=680,volume=.85,aecho=0.8:0.35:82:0.20,alimiter=limit=.94" -ac 1 -ar 44100 -c:a pcm_s16le "$out_dir/enemy-hit-2.wav"
ffmpeg -y -v error -i "$folley_dir/metal1.wav" -i "$folley_dir/steel1.wav" -filter_complex "[0:a]atrim=duration=0.45,asetpts=PTS-STARTPTS,lowpass=f=900,volume=1.08[body];[1:a]atrim=duration=0.50,asetpts=PTS-STARTPTS,lowpass=f=1400,volume=.48,adelay=34[ring];[body][ring]amix=inputs=2:normalize=0,alimiter=limit=.95" -ac 1 -ar 44100 -c:a pcm_s16le "$out_dir/enemy-hit-3.wav"

# Fresh, original combat cues generated from synthesis and the project's CC0 foley.
ffmpeg -y -v error -f lavfi -i "aevalsrc=0.72*sin(2*PI*(220-420*t)*t)*exp(-t*5):s=44100:d=0.34" -f lavfi -i "anoisesrc=color=pink:amplitude=.12:duration=0.26:sample_rate=44100" -filter_complex "[0:a]lowpass=f=1800,volume=.8[tone];[1:a]lowpass=f=2600,afade=t=out:st=0:d=0.24,volume=.65[air];[tone][air]amix=inputs=2:normalize=0,aecho=.8:.25:48:.18,alimiter=limit=.94" -ac 1 -ar 44100 -c:a pcm_s16le "$out_dir/enemy-cast.wav"
ffmpeg -y -v error -f lavfi -i "aevalsrc=sin(2*PI*68*t)*exp(-t*21):s=44100:d=0.20" -f lavfi -i "anoisesrc=color=white:amplitude=.32:duration=0.11:sample_rate=44100" -filter_complex "[0:a]lowpass=f=130,volume=1.4[body];[1:a]bandpass=f=1200:w=1800,afade=t=out:st=0:d=0.10,volume=.55[crunch];[body][crunch]amix=inputs=2:normalize=0,acompressor=threshold=.10:ratio=3:attack=1:release=70:makeup=1.25,alimiter=limit=.94" -ac 1 -ar 44100 -c:a pcm_s16le "$out_dir/player-damage.wav"
ffmpeg -y -v error -i "$folley_dir/steel1.wav" -f lavfi -i "sine=frequency=760:duration=0.12:sample_rate=44100" -filter_complex "[0:a]atrim=duration=0.28,asetpts=PTS-STARTPTS,highpass=f=900,volume=.28,afade=t=out:st=0.04:d=0.24[metal];[1:a]afade=t=out:st=0.02:d=0.10,volume=.16[tone];[metal][tone]amix=inputs=2:normalize=0,aecho=.7:.18:52:.16,alimiter=limit=.90" -ac 1 -ar 44100 -c:a pcm_s16le "$out_dir/weapon-pickup.wav"
