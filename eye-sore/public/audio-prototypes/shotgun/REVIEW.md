# Shotgun A/B/C audition candidates

These nine clips are a review pack, not approved game audio. Existing production sounds were left alone. Listen to `comparison_take1_A-B-C.wav` first: it plays A, B, and C from the same source take with 420 ms gaps and no music. Compare the matching `shotgun_[a|b|c]_takeN.wav` files to hear how the three recorded takes vary. A/B/C are neutral labels, not a ranking.

## Treatments

- **A — Dry immediate.** The recorded shot and its decay, with no added foley.
- **B — Blast plus mechanical recovery.** The same recorded shot, with quiet steel and metal accents after the attack. The accents are placeholders from a generic CC0 foley sampler, not a designed shotgun mechanism.
- **C — Compact abrasive industrial.** The shot is softened above 7.2 kHz and gently saturated; restrained filtered metal grit is layered near the transient. This is a processing study, not a finished mix.

All three treatments use the same first shot region from each source take. Stereo sources are explicitly averaged to mono, then resampled to 48 kHz. Each clip is 0.800 s, mono, 16-bit PCM. A/B/C have matched measured RMS per source take; the common loudness is limited by the clean candidate's available headroom, so it sits below the -20 dBFS RMS request. Peak ceiling is -1 dBFS. Exact file measurements, source and output SHA-256 hashes, and offsets are in `manifest.json`.

## Source and regions

The firearm recordings are from the bundled Free Firearm Sound Library, distributed as CC0/public domain according to `public/audio-sources/free-firearm-library/README.md`. They are listed in order as `mossberg-shotgun.wav`, `mossberg-shotgun-b.wav`, and `mossberg-shotgun-c.wav`. Attack starts were found from the actual recordings using 10 ms downmixed RMS windows, with the first active group above both -50 dBFS and 35 dB below the loudest analysis window. The script rounds the detected boundary to milliseconds. The used source regions are respectively 0.785–1.585 s, 1.695–2.495 s, and 0.426–1.226 s. The first region from each take is shared by A, B, and C.

B and C use `steel1.wav` and `metal1.wav` from the bundled CC0/Unlicense foley sampler; its license text is in `public/audio-sources/cc0/LICENSE`. Both upstream source references and hashes are recorded in `manifest.json`.

## Rebuild

From the repository checkout, run:

```sh
python3 eye-sore/tools/build_shotgun_auditions.py
```

The script needs `ffmpeg` and Python 3 standard library only. It contains the editable variant processing, source region offsets, level matching, and WAV export. Rebuilding replaces only this audition pack.

## Review notes

The source library clips are long field recordings with several separated shots. This pack deliberately uses only the first measured shot in each take so comparisons do not quietly switch to a different source recording. The equal-RMS matching does not guarantee equal perceived loudness or artistic quality. Please audition the candidates in context and judge the transient, body, recovery, repetition, and fit against the game mix before choosing or revising anything.

## Six-shot cadence and room-bed comparison

`sequence_01.wav` through `sequence_06.wav` are IEEE float32 mono WAVs arranged in the shuffled order recorded in `manifest.json`. Each sequence contains six shots exactly 1.5 seconds apart, rotating source takes 1, 2, 3, 1, 2, 3. The same rotation and timings apply to every treatment. The shotgun gain is the game's current 0.82; no shot is individually normalized during sequencing. `six_shot_listening_order.wav` plays those six sequences in the shuffled order with 800 ms gaps. The manifest keeps the candidate/ambience key separate from the neutral filenames so the user can listen first and decode later.

Each candidate has one **ambience off** and one **ambience on** sequence. “On” uses the exact checked-in `linux-game/assets/music/furnace-descent-loop.wav`, starting at its first sample and at the engine's unity music gain. The manifest records its SHA-256, format, and source build script. “Off” means silence beneath the shots, not a substitute bed. These renders contain no extra enemies, weapon impacts, or fabricated cues. Float WAV is used to preserve the additive game-level shot and room-bed signal without clipping; it may peak above 0 dBFS where the two tracks sum, as separate game audio devices also mix them downstream. The one-shot source WAVs and production sounds remain unchanged by sequence rendering.
