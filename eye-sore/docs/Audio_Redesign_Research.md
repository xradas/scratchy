# Eyesore audio redesign: research and production brief

Research date: 2026-10-03. Status: design review, not accepted production audio. The user has rejected both the current game audio and the subsequent A/B/C shotgun audition. Those candidates have failed; a larger batch of the same treatment is not the proposed response.

## What was actually examined

Inspected `linux-game/tools/build_weapon_sounds.sh`, `build_shotgun_auditions.py`, `src/audio_mixer.{h,cpp}`, existing source/license READMEs, runtime WAVs, and the failed audition exports. Used FFmpeg/ffprobe and Python measurements. Read primary developer/source references below.

**Listening limitation:** this agent has no exposed audio listening/perception tool. It cannot truthfully claim to have heard these WAVs, compared a Doom recording by ear, or judged a mix on headphones. The user's playtest rejection is the subjective evidence. Measurements below diagnose concrete implementation and source-selection problems; they do not establish that a new sound is good. Reference character descriptions are design interpretations to confirm in a human listening session, not observations made during this run.

## Current failures with evidence

1. **The legacy build can omit the gunshot it claims to use.** `mossberg-shotgun.wav`, `-b.wav`, `-c.wav` are 96 kHz, 24-bit stereo recordings lasting 11.461, 8.571, and 6.819 seconds. First strong 10 ms windows begin at 0.78, 1.69, and 0.43 s (threshold 20 dB below the strongest window). The legacy recipe trims each input from time zero for 0.58 s. Therefore the first two clips omit the recorded blast; the third includes it late. The audition script knows approximate attacks at 0.785/1.695/0.426 s and fixes selection, but the user still rejects its artistic result. Correct trimming alone is insufficient.
2. **Encoding does not explain this by itself.** Runtime assets are uncompressed 44.1 kHz/16-bit mono PCM. That is adequate for this game's SFX. The weapon build deliberately resamples the main recording to 11.025 kHz and back, adds a low sine thump and noise to all three guns, then compresses/limits. This restricts recorded bandwidth without obtaining Doom's authored timing, source character, cue vocabulary, or balance. Returning to 44.1 kHz cannot recover removed detail.
3. **Attack is damaged again during playback.** A new mixer `Voice` starts `left/right` at zero. Every sample approaches its target with `/220`; at 44.1 kHz that is a ~5 ms time constant, reaching about 63% after 5 ms and 95% after 15 ms. A shot's early crack is attenuated. Smooth spatial/gain changes while a voice runs; start a new transient at its intended gain and only use a tiny click-prevention fade when required by the waveform. This needs a controlled runtime comparison.
4. **Source identity collapses.** Pistol/shotgun/arc each use firearm + one of two metal clips + low sine + noise. Four enemy hit sounds reuse three impact sources. `enemy-cast` is a pitch sweep and pink noise shared across threats. There are no full creature voices or material/contact vocabulary. An arc cannon built around a slowed AK recording has no convincing charge/discharge/cooling grammar.
5. **The mix has one background, converted to mono.** All clips load into mono S16/44.1 kHz buffers, including music. There are 24 voices split 6 weapon/14 combat/4 interface, fixed master 0.45, equal-power pan, simple distance attenuation, and a global ceiling. No acoustic zones, occlusion, source attachment update, music state layers, or dedicated ambience bed exists. Longer sounds remain at their original event coordinates, even though the listener moves.
6. **Recipe and artifacts need reproducibility.** The current script's intended end trims are 0.38/0.66 s for pistol/shotgun, whereas current take-0 files measure 0.34/0.58 s. `build_shotgun_auditions.py` derives ROOT from `parents[1]`, which resolves to `linux-game` although source/output directories are under the project root. A clean build needs to resolve this before assets can be trusted.

Measured exported samples (mono decoded at 44.1 kHz; RMS over entire clip, sample peak, no perceptual claims):

| Asset | Duration | Peak dBFS | RMS dBFS | Crest dB |
|---|---:|---:|---:|---:|
| rivet-shotgun-0.wav | .580 s | -7.89 | -21.16 | 13.28 |
| rivet-shotgun-1.wav | .580 s | -8.12 | -21.18 | 13.06 |
| rivet-shotgun-2.wav | .580 s | -1.73 | -20.49 | 18.76 |
| ember-pistol-0.wav | .340 s | -9.99 | -22.15 | 12.16 |
| arc-cannon-0.wav | .620 s | -8.99 | -21.17 | 12.18 |
| failed shotgun_a_take1.wav | .800 s | -0.86 | -26.10 | 25.24 |
| furnace-descent-loop.wav | 24.0 s | -7.63 | -36.06 | 28.43 |

The audition is 48 kHz natively; its measured peak here includes conversion to 44.1 kHz and is not its native sample peak or a certified true-peak result. Whole-file RMS exaggerates differences when silence/tail length differs. Use equal active windows and human level matching in the next comparison.

## Reference study and what to carry forward

**Doom / Ultimate Doom (1993/1995).** id's published sound table separates shot, cocking, door, pickup, enemy sight/pain/death/active events; the playback code prioritizes and spatializes those events. The original bandwidth is constrained, but the design lesson is recognizable event identity and timing. A shotgun needs an immediate blast and an intelligible recovery action; a monster's recognition cue has a different job from its attack release. The published Linux release includes Doom II content: do not silently treat super-shotgun/Arch-vile/Revenant references as 1993 features. See [sound definitions](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/sounds.c), [gameplay sound handling](https://raw.githubusercontent.com/id-Software/DOOM/master/linuxdoom-1.10/s_sound.c), and [low-level playback](https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/i_sound.c). The typical 8-bit, 11,025 Hz source format is documented in [Fabien Sanglard's audio chapter](https://fabiensanglard.net/b/gebbdoom.pdf); hardware limitations are not a production target.

**Quake (1996).** Its source explicitly handles entity channels, protects player sounds against monster channel replacement, attenuates/pans sources, and maintains ambient sound processing. Our inference: place machine loops, wind and water in space so a level has an audible identity; give footsteps and machinery material character; leave pockets of quiet so threats register. Do not imitate its exact samples. [id's sound code](https://raw.githubusercontent.com/id-Software/Quake/master/WinQuake/snd_dma.c).

**Doom (2016).** Mick Gordon describes deriving a corrupted audio palette from the fictional energy system, and breaking interactive music into pieces responding to exploration, enemy numbers and bosses. Carry forward a world-specific palette and arrangement changes; do not borrow its guitar riffs, recordings or constant loudness. Our proposed hierarchy still keeps danger cues readable above music. [Composer interview, Bethesda](https://bethesda.net/tr-TR/news/inside-the-doom-score-mick-gordon-interview), [composer's GDC session](https://www.gdcvault.com/play/1024068/).

**DUSK (2018).** The composer's official release provides the actual score for a listening session and credits all music performed/written/recorded by him. Its album contains a substantial authored vocabulary, rather than one short loop relabeled for every room. The specific contrast between atmospheric and aggressive passages must be auditioned rather than inferred from genre alone. Carry forward deliberate transitions between unease, discovery and combat. [Andrew Hulshult's official soundtrack](https://andrewhulshult.bandcamp.com/album/dusk-original-game-soundtrack), [publisher's game page](https://newblood.games/dusk).

Required human reference session: five minutes each of Doom E1M1/E1M2 with music low, Quake start/E1M1, and DUSK opening/exploration-to-fight. Log shot onset, dry/reverberant balance, recognition distance, warning audibility under fire, and quiet-to-loud contrast. Then repeat the same questions in Eyesore. No reference game recordings go into the asset library.

## Added references: Wolfenstein, Boltgun and Prodeus

Added following the user's explicit direction. A/B/C remains a failed audition. These references broaden the brief; none has been sampled into the project. This section separates documented implementation from proposed listening judgments. The agent still cannot hear a trailer or WAV through the available tool interface.

### Wolfenstein 3D: short cues carrying clear meaning

**Documented:** id's original [AUDIOWL6.H](https://raw.githubusercontent.com/id-Software/wolf3d/master/WOLFSRC/AUDIOWL6.H) enumerates 87 sound IDs and separate PC, AdLib and digitized banks. Its named vocabulary includes separate door opening/closing, key/ammunition/health pickups, pistol/machine-gun/Gatling attacks, guard recognition, dog bark/attack/death, boss activity, mechanical steps, and multiple death screams. The [sound manager](https://github.com/id-Software/wolf3d/blob/master/WOLFSRC/ID_SD.C) is a primary implementation reference. A listed sound ID does not prove that every build uses it in every circumstance.

**Design interpretation:** Wolfenstein's useful lesson is that an alert bark, door motor, pickup and shot can occupy clearly different perceptual categories. A memorable brief performance carries more information than a generic low noise burst. Preserve an enemy's short recognition signature separately from its pain and death; the player should learn it before a corridor turns. Avoid making all pickups metallic ticks or all creatures down-pitched growls.

**Direct audition brief:** use an original Wolfenstein 3D E1M1 session with digitized SFX enabled, then compare its optional synthesized sound mode at the same listening level. Log first guard recognition, first door, pistol-to-automatic cadence, dog notice and pickups. Available official access/reference page: [Wolfenstein 3D on Steam](https://store.steampowered.com/app/2270/Wolfenstein_3D/). This is a proposed listening session, not a session performed here. Do not mistake low sample rate or a particular sound-card mode for the cue-design principle.

### Later Wolfenstein: source processing shared across departments

**Documented production method:** composer Martin Stig Andersen describes collaboration with MachineGames audio director Nick Raynor on *Youngblood*: sounds were played through a guitar amp and recorded again, and an electroacoustic instrument recording was shared for sound-effects work. [Composer interview published by Air-Edel](https://airedelcouk.wordpress.com/2019/08/06/scoring-bethesda-softworks-latest-game-wolfenstein-youngblood-with-martin-stig-andersen/).

**Eyesore implication:** derive selected music textures, machinery and weapon body layers from one original recorded material palette. Keep dry transients separate. Real re-amping needs a speaker/amp, microphone, room and human capture session. A convolution or saturation plugin would be an explicitly labeled approximation; an FFmpeg distortion curve does not reproduce the documented physical recording process. This is a concrete production alternative to endlessly changing EQ on the rejected samples.

### Warhammer 40,000: Boltgun — armored mass and expressive hierarchy

**Documented:** the [publisher's original game page](https://www.focus-entmt.com/en/games/warhammer-40000-boltgun) presents powerful Space Marine weaponry and includes official trailer playback. Auroch's own [The Music of Warhammer 40,000: Boltgun, S9 E5](https://aurochdigital.podbean.com/e/the-music-of-warhammer-40000-boltgun-s9-e5/) explicitly describes its subject as the game's dynamic music system and how music/sound communicate power. The show notes establish that topic; without listening or a transcript they do not establish a particular stem count, middleware, compression chain or transition algorithm.

Useful adjacent **sequel** evidence: in a [2026 interview](https://www.gamereactor.eu/the-emperors-champions-warhammer-40000-boltgun-ii-interview-with-auroch-digital-1725113/), senior audio designer Matthew Walker describes an exaggerated space for weapons/enemies/gore and a refined mix hierarchy intended to communicate armored power. He also explains linking wet creature SFX to Nurgle anatomy. This supports an intentional expressive mix and anatomy-led source choices, but it is not a technical postmortem of the first game's exact signal chain.

**Listening hypotheses to assess in original Boltgun gameplay:**

| Aspect | What would create that identity | Concrete Eyesore adaptation to audition |
|---|---|---|
| Armored weapon attack | A decisive mechanical onset followed by a forceful blast and a distinct target consequence | Rivet latch/case movement, short pressure blast, then separate plate or flesh impact; no bass drone pretending to be weight |
| Industrial mass | Momentum implied by grip, moving components and return timing | Recovery with two believable moving parts at animation markers, plus a short casing/debris gesture after the shot |
| Player embodiment | Armor contact, sole impact and landing related to body mass | Add restrained harness/plate motion and a landing event; footsteps follow floor material and speed |
| Hit satisfaction | Attack and hit remain distinguishable, with armor/flesh/debris differences | Match the projectile/hitscan event; dry metal strike plus debris for armor, damp fracture/body for flesh |
| Space | Enclosed machinery and open combat spaces create different decay and background density | Small metal vestibule leading into a larger stone hall, with a short change of early reflections and ambience |
| Music | An authored power cue that follows combat state, leaving useful gaps | Sparse exploration bed → short attack/transition → combat pulse → aftermath decay, with danger cues still audible |

This table describes the reference attributes we want to interrogate and our proposed response. It does **not** claim measured Boltgun frequencies, timings, foley sources or listening results. Armored size should come from timing and material relationships before gain; making every layer louder reduces contrast.

**Direct audition reference:** use the official gameplay/trailer player on the [Focus page](https://www.focus-entmt.com/en/games/warhammer-40000-boltgun), then original Boltgun opening gameplay with music first on and then reduced. Compare one boltgun shot, a repeated burst, reload/handling, movement/landing, armored versus soft target, and transition out of combat. Trailer music may be a promotional edit: do not use it as proof of runtime balance. The [Auroch developer post with gameplay trailer](https://blog.playstation.com/2023/04/11/warhammer-40-000-boltgun-releases-may-23-new-gameplay-details-revealed/) is another official viewing entry point. Neither video was audibly reviewed by this agent.

### Prodeus: modern sound movement within a retro presentation

**Documented:** the developer's [Steam description](https://store.steampowered.com/app/964800/Prodeus/?l=english) explicitly describes Andrew Hulshult's score changing with player actions. The [official soundtrack listing](https://store.steampowered.com/app/1465760/Prodeus_Soundtrack/) credits Hulshult and names a wide roster, including *Spent Fuel*, *Cables and Chaos* and *Building Fear*.

**Eyesore implication:** tie music intensity to encounter state, including a release after combat; a retro visual vocabulary does not require a narrow, mono or static soundtrack. For audition, use the game's first full firefight and its quiet approach, then listen to the official music separately. Evaluate whether impact and enemy warning remain distinct under an intense cue. No particular distortion, foley or reverb technique is established by the store page, so none is asserted here.

### Revised first experiment and acquisition requirements

Retain one scene, now explicitly contrasting **Wolfenstein-like cue recognition** with **Boltgun-like bodily/mechanical weight**, and a music-state change motivated by Boltgun/Prodeus. Our sounds, world and performances remain original.

| Scene time | Event and listening question |
|---|---|
| 0–7 s | Approach through a metal vestibule. Two floor contacts, one restrained gear movement, machine landmark. Does the body feel present without obscuring distance? |
| 7–13 s | Door motor ends; one enemy recognition phrase beyond it. Can a listener identify notice versus impending attack before seeing the creature? |
| 13–22 s | First rivet blast, plate target strike, rack/latch recovery. Does the moving mass correspond to the animation? Is impact distinguishable from firing? |
| 22–31 s | Second enemy starts a different attack tell while the player fires and the combat pulse enters. Can the listener identify the imminent threat without turning the music off? |
| 31–38 s | Short landing on stone, second impact on a softer target, enemy collapse. Do material and body transitions read clearly? |
| 38–45 s | Music releases and the hall/pressure machinery returns. Does the listener understand that the fight ended? |

A no-music stem mix is required for diagnosis alongside the full scene. Do not present two loudness variants as different artistic designs. If a rhythm or creature voice is only a placeholder, label that stem individually; do not use its presence to call the scene finished.

Minimum new source library for this experiment: six different latch/bolt/rack gestures, four pressure/air releases, four medium/heavy plate contacts with natural decays, four stone contacts, four cloth/leather/armor gestures, two body/soft material families, one door mechanism, two room/machinery recordings, and three original performed creature phrases (recognition, windup, pain/death). Prefer several performed takes per gesture over random pitch shifting. The phrase and material inventory is the acquisition target, not proof that a named free pack contains every requirement.

Kenney CC0 impacts can seed plate/stone contact study; the original rejected three-clip foley set cannot fill this entire inventory. Search specific Sonniss bundle file lists for pressure/mechanism/room recordings and retain the pack license. Signature armor movement and creature performance may require a human recording session or a properly licensed specialist library. Later-Wolfenstein-style re-amping is optional until real capture equipment is available; avoid claiming a hardware process that was not used. No source acquisitions, production WAV replacements or runtime changes were made in this revision.

Lead critique questions: Is the player's body armored enough in the revised fiction/art to justify heavy contact sounds? Does the first level contain the proposed metal-to-stone transition? Which enemy has the short recognition phrase and which has the contrasting danger tell? Are the proposed new material/voice sources sufficient, or does this require a human sound designer for the first scene?

## New identity: a pressure-driven industrial nightmare

Weapons are dangerous machines with pressure, moving mass, venting and purposeful recovery. Creatures combine breath/strain, distinct resonant cavities and physical contact with surfaces. Magic sounds like stressed material and energy leaking through it. Reserve pure pitched tones for the few cues where pitch communicates charge or an interface state.

The production change is **source and performance direction first**: acquire or record bolts, latches, spring tension, pipe resonance, pressure exhaust, ceramic fractures, cloth/leather movement, stone scrape, wet tissue and performed creature breaths. Edit intentional phrases from these sources. Current free firearm takes may serve as a single transient layer only if a future audition supports them; they are not the default skeleton of every weapon. Synthetic oscillators support an existing physical gesture, not the bulk of the identity.

| Weapon role | Attack / body / tail | Recovery and register |
|---|---|---|
| Ember pistol: accurate repeatable puncture | 1–3 ms mechanical snap, short 120–350 Hz pressure knock, 60–140 ms restrained air | Separate bolt reset near animation return; narrow compact image, strong midrange |
| Rivet shotgun: heavy close-range rupture | 1–5 ms irregular fracture, 40–120 ms dense chest/body, 180–350 ms dissipating pressure | Distinct 2-part rack/latch synced to moving parts; avoid one booming tail over next cue |
| Arc cannon: energy discharge / area denial | Tension rise only if gameplay charges, bright split discharge, 80–220 ms sizzling material resonance | Crackling cool-down, no conventional shotgun thump; upper-mid signature balanced against caster warning |
| Melee fallback: contact and recovery | Swing air only before contact; impact depends on flesh/plate/stone; missed attack has no impact | Grip strain and short return; quieter than a shot |
| Future automatic role | Very short individual onset/body, aggregated mechanical loop only at speed | Burst stop/release cue; avoid stacking long tails per bullet |
| Future explosive role | Launch separate from explosion, explosion with crack/body/debris layers | Spatial distant tail and debris, priority below imminent attack telegraph |

These are production starting ranges, not magic frequency formulas. Change them after audition against animation and encounter density.

## Creature and world vocabulary: expansion in actual events

Use Doom's **combat roles**, with original creature names, silhouettes and voices. Base 1993 roster mapping: former-human ranged fodder; imp-like projectile harassment; demon-like rushing blocker; lost-soul-like flying charger; cacodemon-like floating heavy; baron-like durable artillery; spider/cyberdemon-like bosses. Doom II specialist additions (e.g. resurrection, homing pressure) remain explicitly later scope.

| Role | Identity | Events authored separately |
|---|---|---|
| Ranged fodder | Dry rasp through a damaged mask, weapon handling | notice, active breath, aim tell, fire, pain, death, collapse |
| Projectile caster | Hollow exhale, ceramic stress, short release hiss | notice, chant/windup, release, interrupt, pain, death |
| Melee rusher | Low chest breath, scrape and uneven foot rhythm | wake, approach steps, lunge tell, bite/contact, miss, pain, death |
| Flying charger | Narrow nasal friction, rising intake before launch | idle flight, acquire, charge, collision, pain, death |
| Floating heavy | Broad breath/cavity with intermittent valve rattle | notice, movement, attack inhale, release, stagger, death |
| Armored artillery | Heavy plate movement, stressed furnace resonance | footsteps, orient, charge, shot, armor hit, exposed hit, rupture |
| Boss | Authored identity changing by phase, signature warning rhythm | entrance, each attack tell/release, phase change, vulnerability, defeat |

Target a first production library of **~240–320 genuinely distinct source-derived exports**, counted by event/variation in a manifest: 50 weapon/mechanism; 90 creature; 48 surface/impact/footstep; 30 mechanisms/pickups/player/UI; 24 ambience/transition; plus music stems. Do not inflate the count with renamed or pitch-shifted duplicates. Deliver by coherent zone/encounter batches; 300 files without role contrast is still failure.

Surfaces: metal plate, grate, concrete, rough stone, ceramic, wet floor, flesh, armor, glass, wood. Each has impact intensity and footstep variants. Floor material IDs drive steps; wall IDs drive hit sparks/impacts; ceiling/room volume drives tail; sky/open-air suppresses enclosed reflections. Elevation affects position and occlusion and needs the same coordinates as level/lighting. A furnace light pulse and machine pressure cycle can share an event; random unrelated hum everywhere destroys landmarks.

## Space, music and mix

Dry player attacks stay immediate and centered; mechanisms sit close with subtle width only after stereo-capable loading exists. World SFX are mono point sources. Outdoor yards use sparse reflections; service corridors short early reflections; stone chambers darker longer tails. Prototype baked alternate tails before adding costly convolution. Doors/occlusion reduce direct high-frequency energy and gain smoothly, while crucial telegraphs retain a readable minimum. No blanket reverb over all weapon attacks.

Music gets exploration, pressure, combat, aftermath states with shared tempo/phrase boundaries, plus a boss set. Music should avoid filling every spectral band continuously. Ambience establishes room systems and threat distance. Start with 2–3 genuinely composed minutes per zone, not a 24-second loop multiplied. A composer/performance source is needed for final music; code-generated oscillators are not evidence that the score is finished.

Mix hierarchy: imminent danger / player action; enemy release and impact; movement and mechanism; ambience; music as context. Keep level automation tied to events rather than flattening the master. Start assets with useful headroom (typically peak -3 to -6 dBFS), preserve weapon crest factor, and compare active-window levels rather than normalizing all files to one RMS. For a 60-second reference encounter, start around -20 to -18 LUFS integrated and <= -1 dBTP at capture; these are adjustable house targets, not a broadcast mandate. Check a quiet exploration capture separately. Target no sustained master limiting. Expose music/effects controls and a reduced dynamic-range option later.

Monitor at one consistent comfortable level on headphones, speakers, and a small mono speaker. Audition 20 repeated shots, overlapping creatures, rear threat under fire, distance/door transitions, and low-volume play. Ask whether the player can identify the event without looking and whether repeated use becomes harsh. Spectra, peak, RMS, LUFS and voice counts support this review; none replaces hearing it.

## Production and runtime contract

Keep original source at native format; edit at 48 kHz float with 24-bit or float masters. Process only deliberate layers; trim from measured/performed onset; retain a little pre-onset safety that stays below perceptible trigger delay. Use DC cleanup, selective EQ, envelopes, modest compression if needed, and tiny terminal fades. Saturation is a chosen layer, not a blanket fix.

For the current mixer deliver **mono 44.1 kHz PCM S16 WAV** short SFX, one good resample with libsoxr and triangular dither on final reduction. Do not downsample to 11.025 kHz then restore. WAV avoids lossy onset/pre-echo and decoding ambiguity. Archive masters losslessly. A future stereo music/ambience decoder may use Ogg Vorbis; current `AudioClip` cannot preserve stereo, so adding a codec without changing buffer/channel semantics is pointless. Do not migrate device sample rate merely to make a quality claim.

Files: `audio/sfx/weapon/rivet/fire_close_01.wav`, `.../rack_01.wav`, `.../enemy/caster/telegraph_01.wav`, `.../surface/metal/impact_heavy_01.wav`. Manifest records stable event ID, variants, author/license/source URL/hash, source in/out, revision, sample format, active duration, gain, priority, concurrency, cooldown, spatial mode, room send and animation marker. Runtime calls event IDs with emitter ID, position (including height), velocity where relevant, and surface/room IDs. Repeating variants use no-immediate-repeat selection. Attack marker fires at the same simulation event as muzzle flash/projectile/hitscan. Mechanism markers come from weapon animation; do not bake inaccurate cadence into the shot file.

## Available tools and source strategy

FFmpeg and ffprobe work. Standalone SoX, Audacity and REAPER are not on PATH; Python lacks NumPy/SciPy. FFmpeg includes libsoxr. A deterministic noise/envelope/filter/resample/dither/export probe succeeded at `/tmp/eyesore-audio-toolchain-probe.wav` (mono PCM S16, 44.1 kHz). This only proves an available renderer. A DAW with waveform editing, layer automation, audition and A/B monitoring would improve human production; no DAW was installed or purchase initiated.

Immediately available alternative material source: [Kenney Impact Sounds](https://kenney.nl/assets/impact-sounds), whose creator labels it CC0. Broader recorded production source: [Sonniss GameAudioGDC](https://gdc.sonniss.com/gdc-game-audio-bundle/) with its [bundle license](https://sonniss.com/gdc-bundle-license/); inspect specific pack terms before committing material. These are different licenses, so do not label Sonniss recordings CC0. Existing [Free Firearm Sound Library](https://opengameart.org/content/the-free-firearm-sound-library) remains documented separately. Keep a verbatim license and source hash for every imported pack. Commission or record original breaths/mechanisms for signature sounds when a library cannot provide the performance. Do not rip Doom, Quake, DUSK or another commercial game's audio.

## First new experiment, after lead critique

Build **one 30–45 second authored encounter sound scene**, not another three-EQ shotgun selection. Use newly sourced material gestures to create a rivet weapon with separate rack, a caster with an original inhale/ceramic warning and release, and metal-vs-stone contact. Sequence: quiet machine landmark; caster behind a doorway; player enters; weapon fire/rack; threat side movement; warning over second shot; impact; pressure vent aftermath. Export isolated stems and full mix, plus an alternate dry/room mix with level matched events. Keep all files under `public/audio-prototypes/pressure-scene-v1`, outside production assets.

Feasible here: import verified CC0 impact/foley, produce explicit onset/body/tail layers with FFmpeg, synthesize supporting pressure textures with deterministic seeds, render event-position panning and room tails, write a listening HTML page with source notes and event markers. A creature human performance and musical composition cannot be certified or conjured by script: prototype those roles honestly and obtain human audition before expanding. Compare once through the existing mixer envelope and once with attack-preserving start to isolate runtime loss. The review is whether this scene tells the player what happened, sounds physically connected to the new art, and remains satisfying at game cadence.

Lead decisions needed: accept pressure/material identity or choose another world fiction; align revised enemy roster and animation markers; choose three first acoustic zones from new level plan; decide whether source acquisition is sufficient or a human sound designer/performer is needed for signature creature work. The lead must critique this proposal before production authoring. No game audio files have been replaced in this research pass.
