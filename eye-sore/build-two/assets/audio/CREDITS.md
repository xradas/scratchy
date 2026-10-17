# Eyesore combat prototype — audio credits

## Recording credits

All new physical and vocal source recordings use CC0 1.0. Original extracted FLAC/OGG/WAVs remain unchanged in `originals/`, with source page evidence, creator, URL, original SHA-256, exact excerpts/filters and export hashes in the ledger.

- **Iwan “qubodup” Gabovitch — [Punch](https://opengameart.org/content/punch)**, [actual punching-bag recording](https://freesound.org/people/qubodup/sounds/53985/), [CC0](https://creativecommons.org/publicdomain/zero/1.0/). Recorded with Zoom H2; no body/meat source.
- **rubberduck — [100 CC0 metal and wood SFX](https://opengameart.org/content/100-cc0-metal-and-wood-sfx)**, CC0. Dry wood hits, wood hammer/crack and metal strikes.
- **HaelDB — [Male Grunt/Yelling sounds](https://opengameart.org/content/male-gruntyelling-sounds)**, CC0 alternative selected from the offered licenses. Four male vocalists recorded with a Neumann microphone and Avalon 2022 preamp; individual performer names are not provided on the source page.
- **Ben Jaszczak, Brian Nelson, Kevin Heras and Matthew Nanney — [The Free Firearm Sound Library](https://opengameart.org/content/the-free-firearm-sound-library)**, CC0. Unchanged pistol and shotgun cues; selected original library WAVs retained.
- **Iwan “qubodup” Gabovitch — [Swish bamboo stick weapon swishes](https://opengameart.org/content/swish-bamboo-stick-weapon-swhoshes)** and **[Metal Interactions](https://opengameart.org/content/metal-interactions)**, CC0. Unchanged melee swing/empty; short bamboo air excerpt replaces the former projectile-release texture.
- **Zander Noriega — [Abelian](https://opengameart.org/content/abelian)** and **[Bestial Paragon Interface](https://opengameart.org/content/bestial-paragon-interface)**, [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/); **[Dragged Through Hellfire (Abomination)](https://opengameart.org/content/dragged-through-hellfire-abomination)**, [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Previously used full-song -19 LUFS playback derivatives and unchanged originals are preserved for historical provenance. None is selected by the current game.


Sources, original files, license evidence, exact edits and hashes are in the source project’s `concepts/audio-v3/manifest.json` and its referenced `concepts/audio-v2` music originals. Current active level and menu music is original project composition; the archived Noriega derivatives remain credited. No Doom/Quake audio is distributed.

The six creature attack, hurt and death cues in `assets/audio/demonic-v1` are new layered derivatives of the preserved HaelDB CC0 performances. Lowered pitch/formants, duration compensation, harmonic saturation and restrained fast amplitude modulation give each species a separate voice. No added reverb, echo, wet foley or unprocessed voice layer. `concepts/audio-v4/manifest.json` records the original SHA-256, excerpts, complete filter graphs, preceding versions and exported hashes; `build_demonic.py` reproduces the treatment. Previous runtime cues remain preserved. Human listening approval is pending.

The four expansion creatures use twelve additional dry derivatives at `assets/audio/demonic-v2`. Their original HaelDB CC0 source excerpts, species-specific pitch/formant layers, filter graphs and exported hashes are recorded in `concepts/audio-v5/manifest.json`. This paragraph records the v5 historical state; Citadel and Line now use distinct original cues.

The thirteen arsenal cues at `assets/audio/arsenal-v2` are new dry derivatives of the preserved CC0 firearm, qubodup metal/punch and rubberduck metal/wood recordings credited above. `concepts/audio-v6/manifest.json` records nine original hashes, native source excerpts, exact layer/filter/gain edits, dry/designed/A-B exports and runtime hashes; `build_arsenal.py` reproduces them. Twin shotgun, rivet cannon and siege launcher each have distinct fire/flesh/armor/hard cues; the rocket collision owns one spatial siege explosion. All previous thirty-five cue registrations and music remain unchanged. No wet foley, echo or reverb was added. Human listening acceptance is pending.

Pickup feedback (v6): nine short dry receipts use retained CC0 Metal Interactions recordings by Iwan “qubodup” Gabovitch and retained CC0 wood/metal recordings by rubberduck. Exact originals, creator/source/license evidence, excerpts, playback rates, filters, fades, layers and runtime hashes are recorded in concepts/pickups-rooms-v6/audio/manifest.json. Each accepted collection emits one item_collected receipt on the UI bus; existing weapon/creature/world cues and stereo music are preserved. Technical validation is separate from human listening approval.

## Selected firing recordings v10

User selection: pistol “New original take” (dry), shotgun Candidate A, Twin Shotgun Candidate B from the matched v9 review. Runtime files under assets/audio/selected-v10 are byte-identical to those selected OGG/WAV auditions, with a common +4dB playback gain; no additional EQ, pitch, layers or re-encoding. Other effects and all music are retained.

Original prepared firearm recordings: 1911/A_34P.wav (pistol), Nova/O_17P.wav (shotgun), Mossberg/N_26P.wav (Twin). Created and recorded by Ben Jaszczak, Brian Nelson, Kevin Heras and Matthew Nanney; CC0 1.0, [The Free Firearm Sound Library](https://opengameart.org/content/the-free-firearm-sound-library). Exact original/download hashes, source offsets, processing and audition provenance are retained in concepts/audio-v9/manifest.json; runtime selection mapping is in docs/production-v10/audio-selection.json. Private user MP3 references were not copied or shipped.

Staff pass v11: infected scientist warning/hurt/death use the existing demonic Unsealed voice family; infected security uses the existing demonic Vessel voice family. These are resource aliases to unchanged CC0-derived recordings, not new recordings or new processing. Original sources, creators and edit recipes remain in `concepts/audio-v4/manifest.json`. The accepted v10 firing cues and music are unchanged.

Pale Ward pass v19 replaces those staff aliases with distinct scientist and security detection, attack, hurt and death cues; Unsealed and Vessel also gain distinct detection cues. The voice edits derive from the existing CC0 HaelDB recordings above. Door and overdrive pickup cues are original project synthesis. Exact source hashes, edits, exported files and cue assignments are recorded in `assets/audio/ward-v19/provenance.json` and `assets/audio/runtime-cues.json`.

## Original campaign score v16

This historical pass added nine project cues while Abelian was still the menu theme. The cues used authored note, drum and arrangement patterns plus deterministic oscillator/noise synthesis. No external sample or previous recording entered their render. `tools/compose_campaign_v16.py` is the source; `assets/audio/music/original-v16/manifest.json` records stage mapping, tempo, pattern, duration and hashes. The prior review player is `concepts/audio-v16/index.html`. These files remain available for comparison but are not selected by the current game.

## Original menu and campaign score v17

The active menu and nine campaign levels use ten newly composed project cues. The three standalone stages select the opening cue of their respective chapters. The score alternates cold clinical ambience, industrial pressure, heavy breakbeat, ritual percussion, furnace drone, vault ambience, deserted transit pulse, mechanized electronics and an industrial climax. `tools/compose_campaign_v17.py` contains the score and synthesis source, `assets/audio/music/original-v17/manifest.json` records render provenance and exported hashes, [music direction](../../docs/music-v17/DIRECTION.md) explains each location’s role, and `concepts/audio-v17/index.html` provides the current review player. No earlier song or external sample is an input. Human listening, gameplay balance and transitions remain to be approved.
