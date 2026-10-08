# Eye Sore — Linux prototype

Native SDL2 first-person action prototype for Linux.

Build and run:

```bash
make run
```

To make a portable Linux folder archive, use `make package`. Extract it and run `./eye-sore` from inside the extracted `eye-sore` directory.

Controls: `W`/`S` move, `A`/`D` strafe, hold `Shift` to sprint at 2× speed, mouse to look, `1`/`2`/`3` switch weapons, left mouse or `Space` to fire, `Esc` to quit.

## First descent playtest

Build and run the new perspective 3D milestone with:

```bash
make run-3d
```

The default 3D run stays in Eye Sore's infernal descent setting. The separate night-rink experiment is isolated behind `./build/eye-sore-3d --starling` and is not part of the intended game direction.

To capture your playthrough directly from the game renderer, use `make run-3d-record`. When you quit, the MP4 is saved as `build/eye-sore-playtest.mp4`.

Launch the compact first-combat room with `make run-calibration`. Move through the entry opening, collect the shotgun near the start, then use the central block to break the caster's line of sight. The caster waits until it can see you. Pistol and shotgun fire use immediate hitscan in this mode; the shotgun fires seven pellets. `R` restarts the encounter at any time. The original staged descent remains the default mode.

In calibration mode, press `F1` to pause and release the mouse; `Space` resumes. `M` mutes audio. Health, selected weapon, pickup status, and restart/help hints are shown in the HUD. Ammo remains infinite until an ammo system is added.

The test room uses repeating wall, floor, and ceiling materials, a perspective camera, mouse look, WASD movement, room and pillar collision, and a warm dynamic point light. `Esc` quits.

The weapon view models and firing animations share one original 4x3 source sheet, cut into transparent standalone frames so no black box or neighbouring weapon can bleed into the model. Frame one is the idle model and every model's art baseline is aligned with the bottom of the viewport. The pistol fires once every 0.5 seconds; the shotgun and arc cannon use a 1.5-second interval and 1.2-second animation. Current runtime weapon sounds remain provisional and are not approved for production. Do not regenerate them with `make weapon-sounds` for this review.

The 72 by 60-unit connected room complex has a staged south-hall, two weapon caches, low forge cover, and a deeper-room descent. Basalt wall, ash floor, iron service lane and exhaust ceiling materials divide the space by role; the molten floor candidate remains unused until hazards are taught.

The layout retains its central hall, wings, side-room dividers, doorway gaps and pillars, with low asymmetric cover breaking long firing lanes. Enemies notice and pursue the player, and ranged enemies trace a clear line before firing. The introductory descent adds a Hookrunner melee demon and Soot Bellower ranged demon after the pistol, cultist, brute and wraith encounters. Pistol and shotgun shots use transparent camera-facing sprites. The arc cannon uses one long first-person bolt and a continuous world-space lightning trail. Player projectiles travel until they strike an enemy or room geometry.

New infernal weapon, enemy, room and music candidates are wired for playtest from `public/audio-prototypes/furnace-descent-redesign/`. They are procedural candidate renders and still need human listening before any production-quality claim. The earlier sound set remains available as source material. Source notes are in `public/audio-sources/cc0` and `public/audio-sources/free-firearm-library`.

Enemy animation is defined as `state -> direction -> frames -> timing -> pivot -> fixed world size`. The original four families use the fuller animation set below; the two Furnace Descent additions use a deliberately smaller, honest key set while those first combat concepts are playtested:

- Moving: four real poses loop at 140 ms per frame. Eight viewing angles select front, diagonals, sides, and rear artwork.
- Attacking: wind-up, strike, and recovery frames play once. Melee damage or a ranged projectile is emitted only by the strike frame; the cultist and flame wraith fire distinct projectiles that collide with the player and room.
- Pain: a four-frame impact/recovery animation plays before movement resumes.
- Death and gib death: separate one-shot sequences are selected by lethal damage severity.
- Corpse: the final floor-aligned frame persists and can never move or attack again.

Each enemy has fixed render dimensions and a central foot pivot, so pose padding cannot change its scale or floor position. Collision is a body-sized cylinder with pose-specific profiles. Sprite textures use nearest-neighbour sampling and alpha testing. The original 192 directional/combat frames and new 96 Furnace Descent frames use 384x256 canvases. The Hookrunner and Soot Bellower preserve separate tell, release, recovery, and corpse keys; they do not yet have dedicated pain, falling, or gib sequences. Their approach cycle has two coarse weight/contact poses, not a full walking gait. Inspect the previews in `public/enemies/furnace-descent-redesign/` before extending their animation set.

All enemy types are taller and broader than the 1.42-unit player viewpoint. Player movement is 2.85 units per second and enemies move at 0.58 units per second. Enemy attacks also collide with other enemy types: a cross-type victim retaliates against its attacker until that attacker dies, while matching types do not infight.

The current shotgun sound decision pack is under `public/audio-prototypes/shotgun`. It contains three treatment families across three measured firearm takes and six shuffled 1.5-second firing sequences with the current ambience either off or on. Start with `six_shot_listening_order.wav`; `manifest.json` holds the separate candidate key, source hashes, measured regions, and level data. These are audition candidates only; none has been selected for the game.

This is a first concept-level pass. Review the calibration room's entry, cover, caster tell, retreat route, and the complete fire-to-hit timing before expanding the campaign.

All gameplay, art direction, and sound direction are original. This is not a Doom build or port.

## 3D audio playback

Press `M` to mute or unmute all sound. Effects and the looping background now share one stereo 44.1 kHz device. Each WAV is independently validated and converted at load time to mono signed 16-bit 44.1 kHz; unsupported or missing clips print an error and remain silent. The mixer never loads files or allocates memory in its callback.

`src/audio_mixer.h` exposes separate effect/background gains, listener updates, mute, background selection, and a device-locked reset. Clips must remain alive and unmodified until mixer shutdown. Positioned effects retain their emission location; their panning and attenuation follow the listener as you move and turn. Moving emitters are not followed after emission.

Defaults reserve headroom (0.45 master, 0.8 effects, 0.22 background). Short attack/release ramps and 5 ms stolen-voice tails reduce clicks. Voice limits are 6 weapon, 14 combat, and 4 interface effects; replacement chooses the lowest priority, then the oldest voice, and rejects lower-priority arrivals. A safety ceiling controls exceptional overlap. On exit, stderr reports the peak before this ceiling, limited frames/total output frames, and stolen/dropped voices. Frequent limiting means clip or bus levels need reducing; the ceiling is not an asset loudness treatment. Reset clears effects and restarts the room bed under the audio device lock.

This repairs playback; it does not change the existing provisional sound recordings or establish their artistic quality.
