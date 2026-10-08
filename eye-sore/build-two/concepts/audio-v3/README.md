# Dry damage revision

Open `index.html` for the new 9-second death/hurt comparison and the 10-second direction check, the 12-second six-contact matrix and individual source-excerpt/design comparisons. These are listening candidates. The prior `../combat-audio` wet damage pack remains rejected research; no file in it was changed.

The new body contacts use recorded punching-bag strikes. `flesh` is the runtime target material name, not an instruction to make a wet sound. Pistol has a compact tick/thunk, shotgun a heavier bag strike with a quiet wooden crack, and melee a solid punch. Armor uses three different recorded metal takes with brief decays. Hurt/warnings use short real human grunts and efforts, mild pitch/EQ and small edge fades. Following the request for more blood-curdling deaths, Unsealed and Vessel deaths use longer real human screams (1.55/1.89 seconds), distinct takes with mild pitch/EQ and gentle soft clipping. No animal layers or reverb are added. Earlier brief deaths are retained under `history/brief-deaths-before-scream-revision/`. Contact contains no pain voice, no reverb or synthetic oscillator.

`manifest.json` maps all 26 existing cue keys to files and the existing Weapons, World, Creatures and Music buses. Each new SFX has 48 kHz mono PCM WAV and Vorbis OGG. Four prior attack/empty outputs and the three prior stereo music OGGs are byte-identical copies. Full unchanged music originals remain at the explicitly recorded sibling paths; no large duplicate music WAVs were created. Include both packs' referenced originals when archiving the project.

## Recording credits

All new physical and vocal source recordings use CC0 1.0. Original extracted FLAC/OGG/WAVs remain unchanged in `originals/`, with source page evidence, creator, URL, original SHA-256, exact excerpts/filters and export hashes in the ledger.

- **Iwan “qubodup” Gabovitch — [Punch](https://opengameart.org/content/punch)**, [actual punching-bag recording](https://freesound.org/people/qubodup/sounds/53985/), [CC0](https://creativecommons.org/publicdomain/zero/1.0/). Recorded with Zoom H2; no body/meat source.
- **rubberduck — [100 CC0 metal and wood SFX](https://opengameart.org/content/100-cc0-metal-and-wood-sfx)**, CC0. Dry wood hits, wood hammer/crack and metal strikes.
- **HaelDB — [Male Grunt/Yelling sounds](https://opengameart.org/content/male-gruntyelling-sounds)**, CC0 alternative selected from the offered licenses. Four male vocalists recorded with a Neumann microphone and Avalon 2022 preamp; individual performer names are not provided on the source page.
- **Ben Jaszczak, Brian Nelson, Kevin Heras and Matthew Nanney — [The Free Firearm Sound Library](https://opengameart.org/content/the-free-firearm-sound-library)**, CC0. Unchanged pistol and shotgun cues; selected original library WAVs retained.
- **Iwan “qubodup” Gabovitch — [Swish bamboo stick weapon swishes](https://opengameart.org/content/swish-bamboo-stick-weapon-swhoshes)** and **[Metal Interactions](https://opengameart.org/content/metal-interactions)**, CC0. Unchanged melee swing/empty; short bamboo air excerpt replaces the former projectile-release texture.
- **Zander Noriega — [Abelian](https://opengameart.org/content/abelian)** and **[Bestial Paragon Interface](https://opengameart.org/content/bestial-paragon-interface)**, [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/); **[Dragged Through Hellfire (Abomination)](https://opengameart.org/content/dragged-through-hellfire-abomination)**, [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Prior full-song -19 LUFS playback derivatives reused unchanged; original songs preserved at ledger paths. Abelian is menu only. Level candidates remain separate and pausable with the world.

## Classic references and first mix

[id Software's Doom `A_Pain`](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_enemy.c) selects the actor's pain sound. [Quake `PainSound`](https://github.com/id-Software/Quake/blob/master/qw-qc/player.qc) uses the voice channel and a 0.5-second pain cooldown. These primary code references inform separate events and compact cadence. They do not establish waveform tone or duration. No Doom/Quake sound asset is included or copied.

- Emit one weapon/material contact per damaged target. Aggregate seven shotgun pellets into one contact and one hurt/death voice per target per shot.
- Lethal damage replaces hurt with death and cancels any prior hurt/warning voice. The longer death scream owns one event. Keep contact on World and identity voices on Creatures, spatialized; weapon fire/swing stays near the listener on Weapons.
- New contact peaks are approximately -7 to -10 dBFS; low-priority solid-surface fallback is -12 to -14 dBFS. Hurt/warnings are -11/-12 dBFS; revised death screams target -10 dBFS. Preserved gunfire targets remain -6 dBFS. Start cue gain at 0 dB and retain the coordinator's spatial attenuation/mixer settings; assess actual combined playback before raising gain.
- Keep warning intelligible before attack commitment. Consider a 0.4–0.5-second hurt cooldown per actor when rapid damage occurs. Do not stack all pellet voices or hurt+death.
- Existing music routing remains menu at -3 dB and level at -5 dB relative to its -19 LUFS derivative. Check warning and grunt audibility in the actual mix. No ducking or mix approval is asserted here.

`verification/checks.json` records decode, mono/stereo, duration, sample/true peak and hashes. New contacts/hurt/warnings remain under 0.51 seconds; only the two revised death screams have 1–2 second tails. The death revision preserved all other runtime cue hashes. Short-event LUFS can be unavailable or misleading; `null` is deliberate. Technical verification is not subjective listening. The coordinator/user must assess tone, identity distinction and masking.
