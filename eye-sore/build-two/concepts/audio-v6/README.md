# Arsenal audio candidates

Thirteen new cues are derived directly from nine preserved CC0 recordings in `concepts/audio-v3/originals/`. The firearm files are the downloaded prepared-library source originals; they are not described as raw microphone takes. No prior designed cues, rejected wet effects, synthesis, game audio, new downloads, or music are inputs.

`manifest.json` records the original hashes, authors, source/license URLs and evidence hashes; each selected excerpt, pitch, filter chain, gain, placement, fade and export hash is recorded per layer. `source-excerpts/` contains native-rate archival-source excerpts. `dry/` contains mono excerpt mixtures with gain and placement only, separate from `cues/` designed WAV/OGG outputs. Each `auditions/` WAV plays the dry mixture, 0.4 seconds of silence, then the designed candidate. These references are mixtures, not source originals.

The Twin Shotgun uses two recorded shotgun layers 22 ms apart. The Rivet Cannon uses a short pitched pistol crack and a small dry metal tick within its 0.16 second cadence. The Siege Launcher uses a low shotgun thump and metal clunk; its explosion layers the shotgun, dry wood cracking and metal. Flesh contacts use punching-bag recordings and dry wood, armor contacts use metal and hammer, and hard contacts use hammer and cracking. Cue durations and dynamics distinguish the three guns.

Decoded mono OGG peak targets are -8 dBFS for fire, -14 dBFS for contacts, and -10 dBFS for the explosion. The build verifies decoded peaks and zero clipped rail samples. Existing 35 cue metadata entries, sample bytes, music path and music bytes are preserved; the rebuilt runtime profile retains their exported values. The `preservation/` snapshots exist solely for verification and do not replace current runtime ownership.

From the project root:

```sh
python3 concepts/audio-v6/build_arsenal.py --verify-only
# Rebuild the candidate derivatives and append their runtime entries:
python3 concepts/audio-v6/build_arsenal.py
./tools/godot.sh --headless --editor --import --quit
./tools/godot.sh --headless --script tools/build_audio_profile.gd
./tools/godot.sh --headless --script tools/check_arsenal_audio_v2.gd
```

The runtime check fires the actual Combat weapons into flesh, armor and hard physics contacts, verifies one explosion/duplicate identity, four accepted rapid rivet shots, pause/resume and retry cleanup, and compares old cue/profile values. Its evidence is `verification/arsenal-architecture-v2/audio-runtime.json`.

Technical verification does not constitute subjective listening acceptance. Listening approval is pending.
