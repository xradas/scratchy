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

To capture your playthrough directly from the game renderer, use `make run-3d-record`. When you quit, the MP4 is saved as `build/eye-sore-playtest.mp4`.

The test room uses repeating wall, floor, and ceiling materials, a perspective camera, mouse look, WASD movement, room and pillar collision, and a warm dynamic point light. `Esc` quits.

The weapon view models and firing animations share one original 4x3 source sheet, cut into transparent standalone frames so no black box or neighbouring weapon can bleed into the model. Frame one is the idle model and every model's art baseline is aligned with the bottom of the viewport. The pistol fires once every 0.5 seconds; the shotgun and arc cannon play all four frames with a 1.5-second interval and slower 1.2-second animation. Each weapon rotates through three CC0 field-recording takes, layered with generated sub-bass punches, sharp noise transients and metal mechanism foley. Original synthesized cues cover caster attacks, player damage and weapon pickups. Regenerate these with `make weapon-sounds`.

The 72 by 60-unit connected room complex now hosts a paced first-level descent. You begin in the south hall with the ember pistol. Three low-health enemies introduce movement and the flame-caster's projectile attack. Clear the room to reveal the shotgun cache at the next doorway; collecting it starts a four-enemy encounter in the deeper rooms. Clear that wave to reveal an arc-cannon cache and a final group of seven tougher enemies. The caches unlock their weapons and auto-equip them. `R` restarts the level after death. Weapon keys only switch to weapons you have collected.

The layout retains its central hall, wings, side-room dividers, doorway gaps and pillars. Enemies notice and pursue the player, and ranged enemies trace a clear line before firing. Pistol and shotgun shots use transparent camera-facing sprites. The arc cannon uses one long first-person bolt and a continuous world-space lightning trail. Player projectiles travel until they strike an enemy or room geometry.

A restrained 24-second room bed plays behind combat, using sparse recorded metal and low-passed firearm reverberation rather than a melody or MIDI. Weapon and hit sounds use CC0 field recordings plus generated layers; player projectile collisions add metal and fracture foley, and each enemy type has a distinct hit sound. Source notes are in `public/audio-sources/cc0` and `public/audio-sources/free-firearm-library`. Rebuild the sounds and music with `make weapon-sounds music`; validate their format with `make verify-audio-assets`.

Enemy animation is defined as `state -> direction -> frames -> timing -> pivot -> fixed world size`:

- Moving: four real poses loop at 140 ms per frame. Eight viewing angles select front, diagonals, sides, and rear artwork.
- Attacking: wind-up, strike, and recovery frames play once. Melee damage or a ranged projectile is emitted only by the strike frame; the cultist and flame wraith fire distinct projectiles that collide with the player and room.
- Pain: a four-frame impact/recovery animation plays before movement resumes.
- Death and gib death: separate one-shot sequences are selected by lethal damage severity.
- Corpse: the final floor-aligned frame persists and can never move or attack again.

Each enemy has fixed render dimensions and a central foot pivot, so pose padding cannot change its scale or floor position. Collision is a body-sized cylinder with a per-frame profile: walk, pain, attack lunge, death fall, and corpse frames each set their own width, height, depth, and floor offset. Sprite textures use nearest-neighbour sampling and alpha testing. The 128 directional frames and 64 combat frames use wide 384x256 canvases so recoil, attacks, blood effects, falling bodies, and corpses cannot be clipped. Regenerate them with `make enemy-directional-assets enemy-combat-assets`, then validate every canvas and corpse baseline with `make verify-enemy-assets`.

All enemy types are taller and broader than the 1.42-unit player viewpoint. Player movement is 2.85 units per second and enemies move at 0.58 units per second. Enemy attacks also collide with other enemy types: a cross-type victim retaliates against its attacker until that attacker dies, while matching types do not infight.

This is the first concept-level pass. The next playtest should focus on whether the route between rooms reads clearly, whether the two caches feel rewarding, and whether enemy pressure rises at a fair pace.

All gameplay, art direction, and sound direction are original. This is not a Doom build or port.

## 3D audio playback

Press `M` to mute or unmute all sound. Effects and the looping background now share one stereo 44.1 kHz device. Each WAV is independently validated and converted at load time to mono signed 16-bit 44.1 kHz; unsupported or missing clips print an error and remain silent. The mixer never loads files or allocates memory in its callback.

`src/audio_mixer.h` exposes separate effect/background gains, listener updates, mute, background selection, and a device-locked reset. Clips must remain alive and unmodified until mixer shutdown. Positioned effects retain their emission location; their panning and attenuation follow the listener as you move and turn. Moving emitters are not followed after emission.

Defaults reserve headroom (0.45 master, 0.8 effects, 0.22 background). Short attack/release ramps and 5 ms stolen-voice tails reduce clicks. Voice limits are 6 weapon, 14 combat, and 4 interface effects; replacement chooses the lowest priority, then the oldest voice, and rejects lower-priority arrivals. A safety ceiling controls exceptional overlap. On exit, stderr reports the peak before this ceiling, limited frames/total output frames, and stolen/dropped voices. Frequent limiting means clip or bus levels need reducing; the ceiling is not an asset loudness treatment. Reset clears effects and restarts the room bed under the audio device lock.

This repairs playback; it does not change the existing provisional sound recordings or establish their artistic quality.
