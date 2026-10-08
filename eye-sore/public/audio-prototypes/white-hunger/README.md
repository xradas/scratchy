# White Hunger — new audio audition 01

These are real new WAV candidates, produced 3 October 2026. They are **unapproved**, have not been judged by listening by the agent, and are not installed in the game. They replace the old source recipe for this audition: correctly selected recorded firearm attacks, damped wooden-shell modes and short coarse texture; distinct procedural throat/joint efforts; sparse localized world sounds. No game soundtrack/samples, old metal/steel/cracker library, low sine bass overlay, echo/reverb or furnace loop is used.

## Listening order

Keep one comfortable device volume throughout. Start low. The weapons are matched to a first-250ms RMS target of -17.5 dBFS with a -1.5 dBFS sample-peak ceiling; exact achieved values and measured true peaks are in `manifest.json`. This is signal-level matching, **not certified perceived-loudness matching**. World beds and efforts intentionally have different functional levels. Do not normalize every file to the same peak.

1. `01_pistol_eight_shots.wav` — eight shots, takes 1/2/3/1/2/3/1/2, .28s cadence.
2. `02_spread_eight_shots.wav` — same take order, .60s cadence. These cadence values are audition hypotheses, not an implemented mechanic.
3. `03_spoutback_tell_release_death.wav` — scrape/held cavity warning at .3s, release at 1.18s, terminal collapse at 2.6s.
4. `04_knuckle_grazer_tell_release_death.wav` — broad effort/joint-set warning, grounded release and terminal loss of support at the same times.
5. `world_shade_cloth_loop.wav` — localized flutter, not a global desert wind bed.
6. `world_harness_shift.wav` — strap friction/fastening, not a threat warning.
7. `world_dry_basin_loop.wav` — sparse grit/cavity contacts and almost quiet air, no water promise.
8. `world_spring_trickle_loop.wav` — localized droplets and thin stream, not continuous loud water hiss.

Then compare isolated `pistol_dry_1/2/3.wav` and `spread_dry_1/2/3.wav`, and the individual creature takes. `dry` means no environmental reverb, not untouched source. Counterweight files are separate action-return gestures; playing them at any particular game marker is a future mechanics/art decision, and they imply no reload or ready timing.

Review attack immediacy, broad body on small speakers, hollow/grounded warning distinction, release versus warning, terminal response, repetition and fatigue. Repeat at lower volume and mono, then choose or reject source direction. A candidate that is only better because it is louder fails. Human review can reject the entire packet. No claim that the generated efforts equal a skilled creature performer or that the synthetic trickle equals a convincing field recording.

## Event/onset map

`manifest.json` provides each file's measured first sample exceeding 2.5% of its own peak, duration, sample/true peak, full/250ms RMS, gated integrated LUFS, hash, event and notes. This onset detector is a technical threshold, not the time a person recognizes a warning.

| Bank | Semantic marker | Authored gesture landmarks |
|---|---|---|
| Pistol/spread dry | `ShotEmitted` | New selected firearm region starts at file zero, wood response ~2ms; one unified release, no recovery embedded. |
| Counterweight | `WeaponActionReturn` | First stop at 0, second physical return ~43ms; marker must be approved before integration. |
| Spoutback tell | `EnemyTellBegin` | Scrape from 0; held exhale from 120ms. Entire ~740ms warning must begin before release, not at projectile spawn. |
| Spoutback release | `EnemyReleaseCommitted` | Brief expulsion from 0, no preparation replay. |
| Spoutback death | `DeathCommitted` | Terminal cavity effort from 0; support contacts ~280/470ms. No pain or interrupt alias. |
| Grazer tell | `EnemyTellBegin` | Broad effort from 0, joint/ground set ~320–350ms; ~710ms whole gesture. |
| Grazer release | `EnemyReleaseCommitted` | Effort from 0, ground push ~16ms. |
| Grazer death | `DeathCommitted` | Terminal effort from 0; broad support loss ~230–280ms, small settle ~630ms. |
| World loops | `WorldSourceLoop` | One source handle; loop region [0, frame count), stop/reset/cancel follows emitter state. |
| Harness | `WorldSourceOneShot` | Localized prop/movement gesture only when actual movement warrants it. |

The creature clips are procedural timbre/rhythm candidates. They are not recorded animal/human vocal performances. No notice/pain/interrupt families were produced in this bounded packet; those remain separate future requirements. Cancellation stops active preparing cue without replaying release. Existing mixer softens attacks, has no moving emitter/room acoustics, and current video capture has no audio; these offline files do not establish in-game quality or timing.

## Reproduction and provenance

Production script: `linux-game/tools/white_hunger_audio/build_candidates.py`; pinned dependencies alongside it. From repository root, create an isolated Python environment supporting the pinned wheels, install requirements, and run that script with its interpreter. FFmpeg must be available. The script creates only this new audition folder, uses a fixed NumPy random seed, and captures actual Python library/FFmpeg versions and script/source/output hashes in the manifest. Binary hashes may differ across math-library/platform/FFmpeg versions; exact environment is recorded rather than claiming cross-platform bit identity.

All procedural excitation, envelopes, cavity/membrane modes, contacts, cloth and water gestures are newly authored signals for Eyesore. Weapon crack uses the six local CC0 PPQ/Mossberg takes only. Inspect `SOURCE_PROVENANCE.md`; source hashes and selected start regions are in the manifest. No audio from Doom, Wolfenstein, DUSK, Prodeus, Boltgun or Dead Space was copied.

Measured LUFS is FFmpeg EBU R128 gated integrated loudness of the delivered PCM. Very short/sparse files can have undefined/unstable values; this is not a mastering prescription. True peak is FFmpeg meter estimate, distinct from sample peak. Onset/RMS/peak measurements performed during asset production are not listening validation, playback testing, game builds or tests. No current game asset, source file or Makefile changed.
