# Combat audio contacts and voices

Open [index.html](index.html) for every dry/designed comparison, the six weapon/material cases, separate enemy voice sets and level music candidates. These are new candidates for listening. Earlier rejected impact cues are not marked approved. All source and edit records are in [manifest.json](manifest.json).

## Runtime mapping

`cues` maps exact AudioDirector keys to relative `file`, existing `bus`, and suggested `gain_db`. SFX are mono 48 kHz PCM 24-bit WAVs for spatial playback; OGG copies are supplied. Music stays stereo. Use these existing buses only:

| Keys | Bus | Playback |
|---|---|---|
| `pistol_fire`, `shotgun_fire`, `melee_swing`, `empty` | Weapons | Near listener / weapon view |
| `pistol_flesh`, `shotgun_flesh`, `melee_flesh` | World | At struck target |
| `pistol_armor`, `shotgun_armor`, `melee_armor` | World | At struck target |
| `pistol_hard`, `shotgun_hard`, `melee_hard` | World | Quiet fallback only |
| `projectile_impact`, `projectile_hard` | World | Organic body contact / quiet hard-material fallback |
| `unsealed_hurt`, `unsealed_death`, `unsealed_attack_warning` | Creatures | At Unsealed actor |
| `vessel_hurt`, `vessel_death`, `vessel_attack_warning` | Creatures | At Vessel actor |
| `projectile_release`, `player_hurt` | Creatures | Release at actor; player hurt near listener |
| `menu_music` | Music | Separate menu player, always process |
| `level_music_biotech_candidate`, `level_music_fortress_candidate` | Music | Selected level player, pauses with world |

Choose contact by **weapon and hit material**. Flesh cues use different wet-towel recordings with selected organic impact layers. Armor cues use different metal interactions and distinct envelopes. The armor material can belong to any enemy; contact sound is not the enemy's hurt voice.

For the shotgun, collect seven pellet results by unique target, apply aggregated damage, and play **one shotgun contact per target per shot**. Trigger at most one identity-specific hurt voice per target, subject to voice cooldown. A lethal hit uses death instead of hurt. For melee misses, play swing only. Empty triggers play the short click without fire or contact. Play attack warning during the wind-up, and projectile release only when a projectile actually spawns. `projectile_impact` is organic contact for the player/flesh; hard targets use `projectile_hard`. Player hurt remains a separate voice event after damage.

The hard-material keys are a small shared-source fallback with different pitch/envelopes and quieter levels. This pack adds no wall, floor or ceiling redesign.

## Music routing

**Abelian is the main menu track.** `music/menu_music.wav` is the full original copied byte-for-byte from the approved source. Its SHA-256, original sample rate and stereo channels are preserved. `music/menu_abelian.ogg` is the separate full-song playback derivative normalized to approximately −19 LUFS, with a measured reference at `music/menu_abelian.wav`. Its normalization, resampling and OGG encoding are documented; the source remains unchanged. Start its runtime gain around −3 dB from the normalized copy. Stop or crossfade the menu player when entering a level. Do not use Abelian as the combat loop.

Two independent level candidates are provided while the final setting is being resolved:

- **Bestial Paragon Interface**: the creator describes a slower, monstrous, cold heavy direction. This is the provisional biotech fit, subject to listening.
- **Dragged Through Hellfire (Abomination)**: a newer mix with recorded real bass and a brutal death-metal direction. This is the provisional fortress fit, subject to listening; it is a separately sourced newer version rather than a reused Stage 1 excerpt.

Each has a full stereo playback copy normalized to approximately −19 LUFS and a separate 25-second audition. Original full WAVs remain in `originals/music/`. Full-track repetition has not been established as musically seamless. Use runtime fades/crossfades at the boundary, or confirm the musical transition before treating a track as a seamless loop. A level selects one matching track; the menu and world players must not overlap unintentionally.

## Mixing guidance

Start the level Music bus about 4–6 dB below the normalized music copies. Keep the gun transient present, the material strike audible behind it, and the hurt voice independent. Guns peak around −6 dBTP, major contacts around −7 to −10 dBTP, warnings around −10 dBTP, and hurt/death around −12 dBTP before runtime bus changes. Short transient clips can have no valid integrated LUFS measurement; the ledger reports `null` in those cases and retains measured true peaks.

Use a modest 2–4 dB Music reduction during a committed attack warning or important hurt/death voice, with a quick attack and a release of roughly 150–300 ms. Avoid heavy compression on the entire Master bus: it can flatten contact contrast or make music pump. Test several simultaneous targets before setting polyphony limits. Prefer one active hurt per actor with a short 120–200 ms retrigger gate; death should interrupt that actor's hurt voice. Pitch variation of a few percent can reduce repetition after the base sounds pass review.

The matrix audition intentionally plays fire, contact and hurt as separate events so each can be judged. The warning/music audition has no ducking and exposes masking. Check physical force, harshness, repeated-hit fatigue and whether both warnings remain identifiable at gameplay distance. Recorded field guns retain natural exterior ambience; no room simulation is claimed. Empty is adapted recorded metal-object foley, not a claimed authentic gun dry-fire recording.

## Source credits

- **Ben Jaszczak, Brian Nelson, Kevin Heras and Matthew Nanney** — [The Free Firearm Sound Library](https://opengameart.org/content/the-free-firearm-sound-library), [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/). Selected downloaded prepared-library originals and master sheet retained.
- **Iwan “qubodup” Gabovitch** — [wet towel on body](https://opengameart.org/content/40-wet-towel-clubpoundhitattack-sounds), [Impact](https://opengameart.org/content/impact), [Metal Interactions](https://opengameart.org/content/metal-interactions), and [bamboo stick swishes](https://opengameart.org/content/swish-bamboo-stick-weapon-swhoshes), CC0 1.0. The wet-towel source page explicitly supersedes the older archive information file's license wording with CC0.
- **AuraVoice / Nocturnal_Vanguard** — [Female Hurt Grunts and Groans](https://opengameart.org/content/female-hurt-grunts-groans), CC0 1.0; actual recorded human vocal performance.
- **AntumDeluge** (extraction), **craigsmith** (source digitization) — [Camel Groan](https://opengameart.org/content/camel-groan), CC0 1.0; upstream [recorded animal vocalization](https://freesound.org/people/craigsmith/sounds/437937/) also lists CC0. This supplies a different source voice for Vessel.
- **[Zander Noriega](https://soundcloud.com/zander-noriega)** — [Abelian](https://opengameart.org/content/abelian) and [Bestial Paragon Interface](https://opengameart.org/content/bestial-paragon-interface), [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/); [Dragged Through Hellfire (Abomination)](https://opengameart.org/content/dragged-through-hellfire-abomination), [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Menu original unchanged; the menu OGG playback derivative adds normalization/resampling/encoding. Level playback copies have gain normalization/resampling; short auditions add excerpt selection and fades. Retain these credits and modification notices in distribution.

SFX edits comprise excerpt selection, playback pitch changes, filtering/EQ, selected dynamics, layer mixing, fades, gain matching and format conversion, exactly recorded per cue. No generated oscillator substitutes for a gun, body strike or vocal recording. `originals/` contains unmodified downloaded library files; these may already be treatments by their original creators. `provenance/` retains portable HTML/text license evidence. `archives/` may remain local; do not require the archives for the game's runtime.

## Verification and reproduction

Run `build_cues.py` first, then `build_music.py`. FFmpeg performs the rendering. `verification/` retains measurement logs and the final checks. Checks cover decoded audio, non-empty duration, channel counts, expected keys/buses, source/export hashes and unchanged menu music. No agent or human subjective listening approval is claimed. Review before accepting the new combat sounds.
