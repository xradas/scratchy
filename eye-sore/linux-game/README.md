# Eye Sore — Linux prototype

Native SDL2 first-person action prototype for Linux.

Build and run:

```bash
make run
```

To make a portable Linux folder archive, use `make package`. Extract it and run `./eye-sore` from inside the extracted `eye-sore` directory.

Controls: `W`/`S` move, `A`/`D` strafe, hold `Shift` to sprint at 2× speed, mouse to look, `1`/`2`/`3` switch weapons, left mouse or `Space` to fire, `Esc` to quit.

## 3D engine test room

Build and run the new perspective 3D milestone with:

```bash
make run-3d
```

To capture your playthrough directly from the game renderer, use `make run-3d-record`. When you quit, the MP4 is saved as `build/eye-sore-playtest.mp4`.

The test room uses repeating wall, floor, and ceiling materials, a perspective camera, mouse look, WASD movement, room and pillar collision, and a warm dynamic point light. `Esc` quits.

The weapon view models and firing animations share one original 4x3 source sheet, cut into transparent standalone frames so no black box or neighbouring weapon can bleed into the model. Frame one is the idle model and every model's art baseline is aligned with the bottom of the viewport. The pistol fires once every 0.5 seconds; the shotgun and arc cannon play all four frames with a 1.5-second interval and slower 1.2-second animation. Each weapon rotates through three distinct CC0 field-recording takes, reduced to a short, dry, low-sample-rate crunch with modest metal/steel foley reinforcement. Regenerate them with `./tools/build_weapon_sounds.sh`.

The 72 by 60-unit arena is a connected room complex: a central starting hall, north and south wings, side-room dividers, doorway gaps, pillars, and 14 enemies. Enemies roam until they notice the player. Ranged enemies notice the player from 18 units away and fire from up to 10.5 units; melee enemies notice the player from 12 units away. Ranged enemies trace a line to the player's torso before firing: if a fellow enemy, pillar, or room divider is in that line, they strafe to regain a clear shot rather than intentionally firing through it. Infighting starts only when a ranged enemy accidentally hits a different enemy while trying to hit the player; the victim then retaliates against that attacker. Pistol and shotgun shots use transparent camera-facing 2D sprites. The arc cannon instead presents one long ImageGen first-person bolt, followed by one continuous world-space lightning trail: it never uses an arc projectile sheet in the player view. Player projectiles physically travel until they strike an enemy, interior divider, outer wall, floor, or ceiling. Generate and validate these assets with `make projectile-assets verify-projectile-assets`.

A restrained 24-second room bed plays behind combat, using sparse recorded metal and low-passed firearm reverberation rather than a melody or MIDI. Weapon and hit sounds are based on CC0 field recordings; player projectile collisions add metal and fracture foley, and each enemy type has a distinct hit sound. Source notes are in `public/audio-sources/cc0` and `public/audio-sources/free-firearm-library`. Rebuild and validate them with `make weapon-sounds music verify-audio-assets`.

Enemy animation is defined as `state -> direction -> frames -> timing -> pivot -> fixed world size`:

- Moving: four real poses loop at 140 ms per frame. Eight viewing angles select front, diagonals, sides, and rear artwork.
- Attacking: wind-up, strike, and recovery frames play once. Melee damage or a ranged projectile is emitted only by the strike frame; the cultist and flame wraith fire distinct projectiles that collide with the player and room.
- Pain: a four-frame impact/recovery animation plays before movement resumes.
- Death and gib death: separate one-shot sequences are selected by lethal damage severity.
- Corpse: the final floor-aligned frame persists and can never move or attack again.

Each enemy has fixed render dimensions and a central foot pivot, so pose padding cannot change its scale or floor position. Collision is a body-sized cylinder with a per-frame profile: walk, pain, attack lunge, death fall, and corpse frames each set their own width, height, depth, and floor offset. Sprite textures use nearest-neighbour sampling and alpha testing. The 128 directional frames and 64 combat frames use wide 384x256 canvases so recoil, attacks, blood effects, falling bodies, and corpses cannot be clipped. Regenerate them with `make enemy-directional-assets enemy-combat-assets`, then validate every canvas and corpse baseline with `make verify-enemy-assets`.

All enemy types are taller and broader than the 1.42-unit player viewpoint. Player movement is 2.85 units per second and enemies move at 0.58 units per second. Enemy attacks also collide with other enemy types: a cross-type victim retaliates against its attacker until that attacker dies, while matching types do not infight.

The current combat milestone is an open 14-enemy arena test. Press `R` after death to restart the encounter.

All gameplay, art direction, and sound direction are original. This is not a Doom build or port.
