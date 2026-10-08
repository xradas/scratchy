# Eye Sore — Furnace Descent audio redesign audition

73 actual new WAV candidates, 4 October 2026. **Produced but unapproved; human ear validation pending.** Prototype masters remain separate from earlier candidate sets; the16 extension files are also exported to the coordinator’s new runtime folder as documented below. No engine source/Makefile changes, game build or playback test. No rink/roller/motor/arcade identity.

## What changed

Pistol and shotgun retain a correctly onset-selected CC0 firearm crack as one layer, then new damped cage/stock modes and short coarse physical body; arc cannon instead has an original nonperiodic discharge/cage impulse, not a slowed rifle. No old metal/steel/cracker renders, missing-blast trim, blanket 11kHz degradation, sine sub-bass overlay, long reverb or slam compressor. All nine release variants measure -25dBFS first250ms RMS with gain only; the shared lower target leaves transient headroom. Dynamic contrast remains purposeful, not louder render equals heavier.

Four creature type IDs match the current infernal runtime: 0 dry coarse throat/contact; 1 caster scrape/held breath; 2 disrupted wraith flutter; 3 broad grounded loading/support. Each gets two new tell/attack/hit/death variants, with different time/excitation grammar. **These are procedural approximations, not performed creature voices/field recordings.** No universal roar or falling electronic warning note. Future skilled foley/vocal performance may outperform them; we must listen before adopting.

Room layers are sparse heat-stressed masonry/ember contacts and distant loaded chain/shaft gestures with substantial gaps. They are localized world loops, not a constant infernal drone. The score is an actual original eight-bar 112 BPM pitched bass/percussion sketch with rests, separate from ambience. No tune/sample from a reference game.

## Listen in this order

1. `ember_pistol_release_1..3.wav`, then `ember_pistol_six_shots.wav` (0.50s cadence).
2. `rivet_shotgun_release_1..3.wav`, then `rivet_shotgun_six_shots.wav` (0.60s audition cadence).
3. `arc_cannon_release_1..3.wav`, then `arc_cannon_six_shots.wav` (0.85s audition cadence).
4. Separate `*_return_1..3.wav`; no recovery hidden inside the release. Actual return markers remain mechanics/art-owned.
5. For enemy0..3, compare `enemy_N_tell_1.wav` → `enemy_N_attack_1.wav` → `enemy_N_hit_1.wav` → `enemy_N_death_1.wav`; then second variants.
6. `room_hot_masonry_loop.wav` and `room_chain_shaft_loop.wav` individually.
7. `score_furnace_descent_112bpm.wav`, then `score_room_bus_proof.wav`.

Keep one comfortable volume, then repeat quieter and mono. Judge onset immediacy, midrange body on ordinary speakers, repetitive fatigue, preparing versus releasing, hit versus death and score space. RMS is measured signal matching, not certified perceived-loudness equality or quality. Do not turn the quiet ambience up to gunfire level. All preferences await the user/listener.

## Event timing and integration notes

All output mono S16 PCM 44100Hz. Manifest has hashes, onset threshold, duration, sample/true peak estimate, full/first250ms RMS, short-cue LUFS where meaningful, normalization/ceiling gain, source hashes and offsets.

Release maps to actual accepted `ShotEmitted`; return maps to future approved `WeaponActionReturn`. Hit maps to contact/effective response, not guaranteed interruption. Death maps to `DeathCommitted` and suppresses same-tick pain. Tells are 240ms source gestures to fit the current roughly260ms attack-release marker **if** dispatched at attack-state entry. Type1 held component starts55ms; type2 flutter pulses0/70/140ms; type3 grounded set120ms. Current original runtime has no dedicated notice/tell/death dispatch: starting a tell at projectile spawn is wrong. No runtime wiring attempted here. Interrupt/death must cancel active/pending preparing events. Fairness of a260ms warning remains unvalidated.

No notice/footstep/player/interaction families in this bounded packet. Room loops use explicit [0,end frame) regions, 8.5 seconds from procedural seam crossfade; joins still await ears. Score ~17.143s,8 bars112 BPM. `score_room_bus_proof` uses score0dB, masonry-4dB, chain-6dB static gains; no pumping, hidden warning ducks or master compression. It is an offline bus proof, not an adaptive score or runtime mix pass. Existing mixer gain-ramp/voice/event/capture issues are separate dependencies.

## Provenance and reproduce

`render.py` renders this prototype folder, seed60427; extension IDs4/5 also export their16 new runtime PCM files as documented below. Pinned dependencies in `requirements.txt`; FFmpeg required. Script/source/output hashes and actual library/meter versions in manifest. Platform/math-library changes can alter binary output, so no cross-platform bit-identical claim.

The local firearm README was inspected: [Free Firearm Sound Library](https://opengameart.org/content/the-free-firearm-sound-library), via [FPS Asset Kit](https://github.com/petroulacl/fps-asset-kit), identifies retained PPQ/Mossberg takes as CC0. That retained statement is provenance, not an independent contributor-rights audit. Old metal/steel/cracker Unlicense was inspected but those sources are unused. All other signals and the score contour are newly authored mathematical designs; performer none. No proprietary-game audio/music.

```bash
python -m venv /tmp/furnace-audio
/tmp/furnace-audio/bin/pip install -r public/audio-prototypes/furnace-descent-redesign/requirements.txt
/tmp/furnace-audio/bin/python public/audio-prototypes/furnace-descent-redesign/render.py
```

Measurements are taken after PCM export. Short cues under400ms have undefined integrated LUFS and manifest null, not misleading -70 meter floor. Onset is first sample exceeding2.5% peak, not human recognition time. No audio quality validation follows from those numbers. Initial57 candidates were not runtime-copied by this agent. The coordinator now has runtime integration; the16 new ID4/5 assets are exported to its requested path. Approval and playback remain pending.

## Hookrunner and Soot Bellower extension — revision2

Type4 **Hookrunner**: overhead strap/hook loading with contact landmarks104/151ms; short gritty rake release; damp leather/harness hit; support collapse with a single dropped-hook scrape. Type5 **Soot Bellower**: uneven fan/hide loading plus brace contacts25/87/154ms; hollow compact throat release; broad soft soot-hide contact; emptied air then heavy soft support loss. Hookrunner uses hard localized resonances, Bellower uses broader cavity/soft-body movement. Neither shares a generic flat-noise attack/roar. Both remain procedural sound-design approximations, not recorded real creatures/performers.

New files: `enemy_4_{tell,attack,hit,death}_1..2.wav` and `enemy_5_{tell,attack,hit,death}_1..2.wav`.16 WAVs, matching mono S16/44100Hz current convention. Tell240ms matches the current attack entry→roughly260ms release timing; no later cinematic vocal warning. Attack is release only, hit never promises interrupt, death suppresses same-tick hurt. Event/onset/level/hash metadata added to manifest. All are **candidate assets awaiting human ears**, including fatigue/danger recognition.

The coordinator's current source explicitly loads six enemy IDs from `linux-game/assets/sounds/furnace-descent-redesign/`. Therefore these16 new files are also exported there under matching names, with the prototype PCM unchanged. This agent edited no engine code or Makefile, ran no game build/test and claims no runtime hearing. Earlier renders/assets remain preserved. Reproduction now re-exports these16 extension files only; existing original runtime banks are untouched.
