# Native sprite production brief

## Scope

Create a coherent, original sprite set for Eye Sore’s native SDL/OpenGL FPS. This brief is for a later sprite-production pass. Keep all characters, weapon designs, poses, and effects original; do not copy Doom artwork or trace its sprites. Treat generated images as concept references until their frames have been visually inspected and cleaned.

## What the native renderer expects today

### Enemies

- The renderer currently loads **4 enemy types** (`0..3`) using fixed-size arrays in `linux-game/src/engine3d.cpp`.
- Walking art is **8 views × 4 poses** per type. The view order used by `EnemyDirection` is: front, front-right, right, back-right, back, back-left, left, front-left.
- Each exported frame is **384×256 px**. Enemy sprites use transparency and share a fixed floor/foot baseline at the bottom of the canvas. Frames should keep the same apparent scale and ground-contact point across views and poses.
- Combat states are separate **4-frame** sequences for pain, attack, death, and gib, on the same 384×256 canvas. The engine uses per-state clip timings and an attack event frame. Corpse frames should remain aligned to the floor.
- Enemy render dimensions, baseline, and collision dimensions are configured separately in `ENEMY_DEFS`. New art needs a matching gameplay-scale review and corresponding metadata tuning; frame dimensions alone do not set world scale.

### Weapons

- Three first-person weapons currently load **4 frames each** from `linux-game/assets/weapons/weapon-{weapon}-frame-{frame}.bmp`.
- Weapon images retain alpha. The view model is drawn near the bottom of the screen; its apparent screen width/height are currently selected in code by weapon index.
- Weapon-specific source frame order, frame count, cooldown, and animation duration are hard-coded in `WEAPON_SOURCE_FRAMES`, `WEAPON_FRAME_COUNTS`, `WEAPON_COOLDOWNS`, and `WEAPON_ANIM_DURATIONS`.
- Existing 512×512 first-person launch overlays are a separate projectile/muzzle effect path. They are not additional weapon animation frames.

### Projectiles

- Projectile sprites are directional billboard assets with **8 orientations**. Validators expect **256×128 px** transparent BMPs for each projectile name/direction.
- Separate 512×512 transparent assets are used for first-person launch effects.

## Naming and asset pipeline

- Enemy directional source art is under `eye-sore/public/enemies/sources/`; split PNGs go to `public/enemies/directional/`, then native BMPs go to `linux-game/assets/enemies/directional/`.
- Enemy combat sources and outputs use the parallel `sources/`, `combat/`, and `linux-game/assets/enemies/combat/` folders.
- Weapon source art is `public/infernal-firing-sheet.png`; generated PNG and BMP frames are named `weapon-{0..2}-frame-{0..3}`.
- `linux-game/tools/build_enemy_directional_frames.sh` splits 8×4 sheets. It contains special extraction/color-key handling for enemy type 1.
- `linux-game/tools/build_enemy_combat_frames.sh` splits 4×4 sheets and includes special color-key and cleanup handling for particular sources.
- `linux-game/tools/build_weapon_frames.sh` splits the 4×3 weapon sheet. Weapon BMP export is intended to preserve alpha.
- Validators: `verify_enemy_directional_frames.sh`, `verify_enemy_combat_frames.sh`, `verify_weapon_assets.sh`, and `verify_projectile_assets.sh`.
- Current enemy validators expect exactly 128 directional frames (4×8×4) and 64 combat frames (4×4 states×4). Code, builders, validators, definitions, and load loops all assume four enemy types. Adding a type requires coordinated changes across these locations.

## Risks observed in the current art pipeline

- Source sheets are not consistently exact multiples of their intended grids. Existing directional sources are 1774×887, while combat sources vary around 1263×1246. Equal-grid crops can land on fractional cell boundaries or include inconsistent margins.
- Some sources have baked backgrounds and depend on per-type color-key heuristics. This can leave halos or erase dark silhouette pixels; alpha should be authored/cleaned deliberately, not inferred from a similar background color.
- Generated frames can shift in scale, foot placement, silhouette, or facing between cells. A sheet that has the right number of apparent cells is not necessarily a usable animation.
- Four poses may be repeated or differ only in incidental detail. Compare frames at actual game scale and check a loop before treating the source as complete.
- Weapon art can change grip, muzzle location, or overall screen position across frames. Review the assembled firing sequence, not just isolated frame images.
- Existing script exceptions are evidence that generated source sheets have needed manual repair. Avoid adding another one-off crop exception without first improving the source master and documenting the reason.

## New low-tier caster: original concept brief

**Working role:** a small, readable ranged enemy that teaches the player to recognize and avoid slow fire projectiles. It should be physically weaker and less imposing than the existing heavy enemies, with an obvious cast wind-up and a distinct attack silhouette.

**Visual direction:** design an original “Kiln Wretch”: squat ash-black body; a cracked ceramic or furnace-mask head with narrow ember eye slits; one asymmetrical cinder mantle/shoulder; one forearm brazier or ember vent; short, widely readable limbs. Use charcoal and soot browns with muted bone ceramic and a restrained orange ember focal point. Prioritize a strong outline and readable casting pose over surface detail. Do not use iconic Doom monster anatomy, horns, face, color blocking, or pose as a template.

**Animation deliverables:**

1. Walk: 8 views × 4 genuinely distinct poses, with consistent apparent scale and foot baseline.
2. Cast attack: 4 frames with a clear anticipation, release, and recovery. Specify the projectile event frame so the engine launches at the visible release.
3. Pain: 4 readable recoil frames.
4. Death: 4 frames ending in a floor-aligned corpse.
5. Gib: 4 frames, visually distinct from the ordinary death.

**Technical handoff:** provide a layered/editable master plus a flattened transparent PNG atlas on an exact integer grid. Export each final frame to a 384×256 transparent canvas with a fixed foot baseline. Include a labeled contact sheet, frame/direction key, palette swatches, and a small metadata note for intended world height, baseline, hitbox, and animation timing. Keep source and exports separate. Do not overwrite the existing four enemy sources or run the existing builders against this prototype until it has been reviewed.

## Review and integration gate

1. Review the full contact sheets at native display scale for silhouette, palette, direction continuity, foot alignment, and genuinely distinct motion.
2. Inspect alpha edges against both dark and bright backgrounds; remove stray pixels and color fringes.
3. Confirm integer cell boundaries and verify all 32 walk frames map to the documented row/column order.
4. Only then export frames and run the matching validator scripts.
5. Integrate art with the engine definition, collision profile, clip timing, and attack event frame as one coordinated change. Expand the hard-coded enemy counts and validation expectations together if this is a fifth type.
