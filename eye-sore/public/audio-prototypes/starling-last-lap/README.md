# STARLING’S LAST LAP — audio audition 01

New rendered candidate WAVs for an orbital roller rink/night racecourse. **Produced, unapproved, awaiting human listening.** The agent did not hear or certify them. White Hunger is rejected and remains isolated; none of its produced WAVs is used here. No runtime bank, engine source or Makefile changed.

The weapon sources are newly selected dry CC0 firearm regions, compact damped wooden chassis/deck modes and short coarse impulses. The Counter/Hound/world cues are original procedural sound-design mockups, **not field recordings or performed voices**. The score is an original synth composition audition, **not** a copyrighted game tune or implemented adaptive soundtrack. No infernal drone, generic roar, beep warning, boiler hiss or long room reverb is present in the recipe.

## Numbered listening order

At a comfortable fixed device volume, review:

1. `01_carbine_cadence.wav`: twelve carbine shots, .20s provisional cadence, take order 1/2/3 repeated. Compact crack/body; no return buried in blast.
2. `02_deck_shotgun_cadence.wav`: eight spread releases, .60s provisional cadence. Unified broad transient plus deck/stock body, not two damaging shots.
3. `03_lap_counter_sequence.wav`: clack/aim tell .30s, release 1.20s, collapse 2.70s.
4. `04_bumper_hound_sequence.wav`: wheel/foam tell .30s, bounded-rush cue 1.20s, collapse 2.70s.
5. `world_distant_roller_loop.wav`: quiet localized crowdless roller hum.
6. `world_splitflap_light_loop.wav`: sparse irregular remote flap/relay rhythm, distinct from warning cadence.
7. `score_last_lap_140bpm_audition.wav`: separate original eight-bar/140 BPM pluck/bass/drum sketch with question/answer and rests. No ambience source inside it.

Then compare `carbine_release_1/2/3.wav` and `deck_shotgun_release_1/2/3.wav` one at a time; compare separate `*_return_1/2/3.wav`. Creature tell/release/collapse also have three variants. This is a take-variation packet within one source direction, not a false three-direction A/B/C.

All six shot variants now measure -23.000 dBFS first-250ms RMS after delivered PCM quantization (within ±0.001 dB), using gain only. The common target was lowered to preserve the highest-crest source transient beneath the -1.5 dBFS sample-peak bound. Actual RMS, sample/true peak and EBU R128 LUFS estimates are in manifest. **RMS matching does not guarantee matched perceived loudness**; a listener must adjust/record final matching before choosing. Reels use exported shot samples at unity; the recorded uniform mix trim is 0.000 dB for both. First-250ms file RMS is silence because of the 400ms lead-in. The manifest separately records the first-shot-aligned window; carbine includes the next shot at 200ms, so that overlap window is not the isolated-source matching metric. Creatures/world/score have intentionally different functional levels. No separate high-volume candidate is mislabeled as better.

Review crack immediacy, body on ordinary speakers, repetition at cadence, tell/release distinction and fatigue; then quieter playback and mono. Does Counter preparation sound clearly mechanical? Does Hound sound grounded/soft without becoming dull? Does score leave space for warnings? These questions await ears. Reject weak sources before runtime integration. Synthetic wheel/water/voice-style noise is a rough production route; professional foley/performance can replace it when audition exposes a weakness.

## Event and authored onset map

Each cue's manifest contains measured first sample above 2.5% peak, hash, duration, output format, level estimates and intended event. That threshold is technical, not human recognition time.

| Bank | Event | Authored landmarks |
|---|---|---|
| Carbine | `ShotEmitted` | Recorded attack file zero, wood response ~1ms; ~270ms dry total. |
| Deck shotgun | `ShotEmitted` | Broad impulse 0–.3ms, deck ~2ms, secondary stock body ~12ms; ~470ms. One release. |
| Return | `WeaponActionReturn` | Small stop from 0, spring/latch ~24ms; shotgun second load contact ~74ms. No reload/readiness promise. |
| Lap Counter tell | `EnemyTellBegin` | Split-flap clacks 0/82/165/235ms, latch/aim 380–400ms; 720ms. Must start before actual attack release. |
| Counter release | `EnemyReleaseCommitted` | Token ejection from 0; ~220ms. |
| Counter collapse | `DeathCommitted` | Contacts 0/170/390ms, decreasing weight; ~800ms. |
| Hound tell | `EnemyTellBegin` | Wheel brake 0–270ms; foam compress ~220ms, ground set ~430ms; 750ms. |
| Hound rush | `EnemyReleaseCommitted` | Ground push from 0, roller/soft accent ~55ms; 330ms. AI still owns bounded rush. |
| Hound collapse | `DeathCommitted` | Foam support loss from 0, axle ~140ms, quiet settle ~370ms; 680ms. |
| World loops | `WorldSourceLoop` | One localized source each; explicit [0, end-frame) region, 7.5s loop. |
| Score | `MusicCueAudition` | 8 bars, 140 quarter BPM, 4/4; ~13.714s dry original sketch. Separate bus/source, no gameplay state inference. |

No notice/pain/interrupt families in this bounded packet. Interrupt/death must cancel still-pending tell/release per actual simulation. Offline sequences do not prove AI timing, mixer transients, positional truth, loop seamlessness by ear or actual device latency. Current mixer/capture limitations remain.

## Reproduce and provenance

`linux-game/tools/starling_audio/build_candidates.py` generates this folder with seed 41791. Pinned requirements are alongside it; Python wheel compatibility and FFmpeg required. Manifest records dependency/meter versions, script hash, original source hashes, selected source-start offsets and delivered asset hashes. Floating-point libraries/platform differences may change binary output; exact versions are recorded, not cross-platform bit identity asserted.

Local `public/audio-sources/free-firearm-library/README.md` identifies PPQ/Mossberg/AK recordings as CC0 via [Free Firearm Sound Library](https://opengameart.org/content/the-free-firearm-sound-library) and [FPS Asset Kit](https://github.com/petroulacl/fps-asset-kit). It was inspected before rendering. This is retained local provenance, not a newly completed upstream contributor audit. The older metal/steel/cracker Unlicense file was also inspected; **those recordings are not used**. Source selection: carbine PPQ first/AK B/PPQ C; shotgun Mossberg first/B/C. Detailed hashes and offsets in manifest. All remaining excitation, filtering, envelopes, cavity modes, contacts and musical contour newly authored for Eyesore, performer none.

Metrics generated during rendering: PCM quantized sample peak, full and first-250ms RMS, FFmpeg EBU R128 integrated LUFS and oversampled true-peak estimate. Short sparse cues make integrated LUFS unstable/descriptive; no mastering target or ear approval is inferred. Meter output and onset calculation do not count as a game build/test. No runtime tests run.

## Measurement correction — gain matched revision

The initial render requested -17.5 dBFS RMS, then peak-ceiling gain reduced the six files unequally. Its matching claim was incorrect. This revision chooses -23 dBFS as the common crest-safe target; no limiter/compressor/clipping was added to force a higher RMS. Shape/decay/transient are preserved by uniform gain. Updated script, PCM/reel hashes and measurements supersede initial output.

| File | First250ms RMS dBFS | Sample peak dBFS | FFmpeg true peak estimate dBFS | Integrated LUFS |
|---|---:|---:|---:|---:|
| carbine_release_1 | -23.000 | -1.669 | -1.7 | Undefined: <400ms |
| carbine_release_2 | -23.000 | -2.871 | -2.9 | Undefined: <400ms |
| carbine_release_3 | -23.000 | -1.622 | -1.6 | Undefined: <400ms |
| deck_shotgun_release_1 | -23.000 | -4.063 | -4.0 | -25.7 |
| deck_shotgun_release_2 | -23.000 | -4.096 | -4.1 | -25.4 |
| deck_shotgun_release_3 | -23.000 | -4.051 | -4.0 | -25.5 |

Cadence reels: carbine full-file RMS -26.014 dBFS, sample peak -1.620 dBFS, true peak estimate -1.6 dBFS, integrated -22.7 LUFS; shotgun full-file RMS -27.771 dBFS, sample peak -4.052 dBFS, true peak estimate -4.0 dBFS, integrated -25.6 LUFS. Different cadence changes full-reel energy; it does not mean their isolated releases are mismatched. Each reel has a 0 dB uniform mix trim, no clip/limiter. All values descriptive signal measurements, not evidence of perceived quality.

## Bounded integration addition — revision 2

Six new procedural `lap_counter_contact_1..3.wav` / `bumper_hound_contact_1..3.wav` files distinguish sharp wood/enamel chassis contact from broader foam/rubber/wheel contact. Both families measure -29.000 dBFS first250ms RMS; sample peaks span -7.881 to -9.448 dBFS (Counter) and -9.334 to -10.067 dBFS (Hound). They represent contact only, never confirmed interruption or death. No additional weapon identities or broad reel family added.

`carbine_complete_fire_1..3.wav` combines one matched dry release at unity with its return delayed 95ms. `deck_shotgun_complete_fire_1..3.wav` does the same at 220ms. These are direct-play compound fixtures, not separate gameplay shots. **Do not dispatch the separate return again when playing a compound.** Delays are provisional cosmetic timings and do not create ammo, reload or ready events. Once animation timelines are authoritative, use separate cues instead or approve these exact delays.

The added return changes the compound's first250ms energy; it is not claimed identical to the isolated release matching metric. Carbine compound RMS -22.371 to -22.113 dBFS; shotgun -22.717 to -22.623 dBFS. Small uniform ceiling trims on carbine compound 1/3 are -0.164209/-0.257748 dB, respectively; all others 0dB. No compressor/clipping. Exact measurements/hashes in manifest. Original isolated releases/reels stay unchanged.

`gameplay_music_world_bus_proof.wav` is one honest offline mix proof: original score at 0dB, score-only static blend of 65% dry and 35% 1.5–3.4kHz bandstop (maximum approximate center carve 3.7dB), roller ambience -6dB, flap/light ambience -8dB. No dynamic ducking, shot/tell layer, source loudness re-normalization or limiter. Room/noise/music buses remain separable; world loop wrap is the declared source wrap. Peak -7.309 dBFS, FFmpeg integrated loudness -26.3 LUFS, 0dB ceiling trim. Its musical dominance, tell-band space and loop joins are **awaiting human listening**, not certified by math. This proof is not a ready adaptive game score or a perceptual masking pass.
