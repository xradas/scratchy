# Eyesore — Stage 1 audio auditions

Three equally scoped audio directions for comparison. These are library auditions, not a finished soundtrack or a selected identity. Recorded firearm shots supply the gun sound; recorded weapon impacts supply the physical contact layer. No generated beep is used as a firearm substitute.

| Identity | Music candidate, 25 seconds | Physical sound scene, 10 seconds | Musical appeal to test |
|---|---|---|---|
| Corrupted biotech facility | [Abelian excerpt](cues/biotech_music_25s.ogg) | [Carbine and light impact](cues/biotech_sfx_10s.ogg) | Heavy guitars with synths: cold engineered threat against living corruption. |
| War-torn occult fortress | [Dragged Through Hellfire excerpt](cues/fortress_music_25s.ogg) | [Shotgun and blade clash](cues/fortress_sfx_10s.ogg) | Brutal riff-driven force: siege pressure and a hostile ritual mood. |
| Invaded civic megastructure | [The Recon Mission excerpt](cues/civic_music_25s.ogg) | [Automatic burst and heavy impact](cues/civic_sfx_10s.ogg) | Cold guitar-driven pressure: militant invasion in a vast public structure. |

All music excerpts preserve the originals' two-channel stereo. Each scene has gun events at 0.35, 2.65 and 6.1 seconds, an impact at 5 seconds, and the same sourced Kenney warning at 8.2 and 8.9 seconds. The gun recordings are exterior field recordings; the edited reflections are audition treatments, not measured room simulations. The metal/haft recordings are proposed material accents, not claims that the original recording depicts a game prop.

[Shared dry versus edited guns](cues/shared_guns_dry_vs_edited_12s.ogg): 0–6 seconds uses three dry 1911 excerpts; 6–12 seconds repeats the exact same excerpts with low body EQ, a softened upper midrange and short echoes. Both individual samples are peak matched to −9 dBFS. “Dry” retains the source recording's natural outdoor ambience and has trimming, a tail fade, resampling and gain matching, but no added EQ/echo.

Use the three masking checks after the isolated music/SFX:

- [Biotech masking check](cues/biotech_masking_check_25s.ogg)
- [Fortress masking check](cues/fortress_masking_check_25s.ogg)
- [Civic masking check](cues/civic_masking_check_25s.ogg)

The warning lands at 16.2 and 16.9 seconds in each masking check. Music is reduced by approximately 3.9 dB for these mixes and there is no ducking. Check whether both warnings remain recognizable, whether gun transients cut through without harshness, and whether each track sustains combat momentum without fatigue. Start at a low playback volume and compare at the same device setting. These listening questions remain open; technical checks do not establish subjective appeal or warning intelligibility.

Music reference WAVs target −19 LUFS with a −3 dBTP ceiling. Individual gun samples peak at −9 dBFS; impact samples peak at −14 dBFS; warning peaks at −12 dBFS. Sparse SFX have lower integrated loudness by design. Exact measured integrated LUFS, true peaks, durations, channel counts and SHA-256 hashes are in [manifest.json](manifest.json); the measurement logs are in `verification/`. All WAV cues are 48 kHz stereo PCM 16-bit. Matching OGG Vorbis files are convenient playback copies; WAVs are the measured references. Technical decoding/stereo/duration/level checks completed. No human or agent subjective listening validation is claimed.

## Credits and retained evidence

Music: **[Zander Noriega](https://opengameart.org/users/zander-noriega)** — [Abelian](https://opengameart.org/content/abelian), [Dragged Through Hellfire](https://opengameart.org/content/dragged-through-hellfire), and [The Recon Mission](https://opengameart.org/content/the-recon-mission). Licensed [Creative Commons Attribution 3.0](https://creativecommons.org/licenses/by/3.0/). Changes: excerpt selection, fades, loudness adjustment and format conversion; masking checks additionally mix the music with sound effects. Retain these credits and modification notices when distributing the auditions or derivative game assets.

Firearms: **Ben Jaszczak, Brian Nelson, Kevin Heras and Matthew Nanney**, [The Free Firearm Sound Library](https://opengameart.org/content/the-free-firearm-sound-library), [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/). Selected unmodified prepared-library WAVs and the original master sheet are retained. “Original” here means the downloaded library file, not an unprocessed microphone take. Changes in auditions: selection/trim, fade, gain, resampling, EQ and added echoes as recorded in the manifest.

Weapon impacts: **Ben Jaszczak and Brian Nelson**, [Medieval sound effects — Weapon impacts](https://opengameart.org/content/medieval-sound-effects-weapon-impacts), [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/). Changes: excerpt selection, high/low filtering, fade, gain, resampling and scene placement.

Warning: **[Kenney](https://kenney.nl/)**, [Interface Sounds](https://kenney.nl/assets/interface-sounds), [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/); `error_006.ogg`. Changes: gain adjustment, resampling and repetition/scene placement. The included `originals/kenney/License.txt` accompanies the source.

`originals/` holds the selected unmodified WAV/OGG source files. `provenance/` holds locally saved source-page HTML and plain-text copies showing creator, license, attribution instructions and attachment links; these portable records can travel with the project. The full downloaded archives remain in `archives/` and are also hashed in the manifest; they need not be published in the game repository. `stems/` holds intermediate audition edits. `render_auditions.py` documents/rebuilds the treatment from retained originals using FFmpeg. No existing Eyesore worktree or Git history was altered for this audio task.
