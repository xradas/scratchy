# Representative live creature studies

These original Godot mesh studies replace the capsule visual with two dimensional, posed biotech creatures. This is a representative combat-art review, not a selected level identity or a completed production creature set. The approved corrupted-biotech image-generation concept was used as a visual design reference; none of its pixels, nor imported character models, are used by this runtime art.

Unsealed has a forward-set narrow split-maw head, curved ribcage, warm scarred flesh, long forearms and hooked digits. Vessel has a broad lower torso, irregular yellow-green culture sac, broken containment ribs, back plates, shoulder tubing and three forward throat nozzles. The contrast is meant to distinguish close pursuit from ranged containment pressure.

The real renders show meaningful volume and distinct silhouettes, but the sculpt remains simplified. The face, shoulder transitions, fingers and containment finish still look stylized and less natural than the approved concept. These are prototype studies awaiting the user's in-game art review, not assets declared visually accepted. Skin breakup is procedural shading rather than painted production texture work. Poses are representative joint animation, not polished motion capture or a complete directional sprite production.

## Runtime handoff

Copy `source/creature_rig.gd` and `source/creature_rig.tscn` into the destination art folder. Update the TSCN script path from `res://creature_rig.gd` to the destination path. The root is Node3D, faces local -Z, actor origin is capsule center, floor is local y=-0.85. No gameplay events, damage, AI, signals or audio are authored here.

- `configure(kind: StringName)` rebuilds the original rig. `unsealed`/`melee` select Unsealed. `vessel`/`ranged`/`containment`/`containment_choir` select Vessel.
- `present(state: StringName, time: float, windup_duration: float=0.45, recovery_duration: float=0.60, pain_duration: float=0.18)` takes elapsed time in the authoritative state. Supported states are chase/idle, windup, recovery, pain, dead/death. The controller owns facing and translation. Dead reaches its persistent floor-registered pose at 0.65 seconds.
- `get_projectile_origin() -> Vector3` returns world position of `Body/Head/ProjectileLip`. Vessel marker sits on the lip of the upper center forward vent, follows head posing, and introduces no firing logic.
- `bounds_now() -> AABB` is an exact posed vertex bound in rig-local coordinates, intended for diagnostics. Avoid calling it every physics frame; it traverses all vertices.
- Each merged MeshInstance3D has `hit_material` metadata. Unsealed surfaces are all `flesh`. Vessel bone/metal/rubber containment surfaces are `armor`; skin/muscle/scar/culture/eyes/tooth surfaces are `flesh`. The authority may use these tags for impact cues.

Rig meshes are batched per joint/material, preserving posed limb hierarchy. Query-only exact triangle hit bodies parented under each mesh preserve rib and mouth gaps. A convex hull around a batched rib or tooth group incorrectly fills those visible gaps. The existing movement capsule can remain a movement proxy; visual hit tests should use the actual posed mesh. Gameplay remains outside this package.

Standing Unsealed is approximately 1.2 units wide across arms and 1.65 units tall. Vessel is approximately 1.46 units wide and 1.54 units tall. The chase samples and exact per-state coordinates are in `bounds.json`; windup reaches farther forward and corpse bounds become broad and low. The existing radius .38 movement capsule is narrower than both visible arm spans. This package does not alter pathfinding, movement collision or damage balance.

## Verification and review

`source/verify_art.gd` tests both kinds over all five states at elapsed times 0, .1, .4, 2 and 20 seconds. It checks finite bounds, no vertex clipping below -.851, mesh impact tags, dead pose persistence, reset to chase and world-space translated firing origin. `verification.json` records results and geometry totals. Both pass on Godot 4.7.2. Unsealed: 28 mesh surfaces, 8,616 vertices, 16,824 triangles. Vessel: 29 surfaces, 11,876 vertices, 21,084 triangles. Runtime crowd performance and parent exact triangle hit-query cost still need profiling in the actual level.

`source/review.gd` renders each state, five angles, a 6m distance check and a closeup into native 640x360 SubViewport PNGs. These are real Godot captures with directional lighting and a floor; they are not image-generation output or painted standees. `make_review.py` only arranges the captured PNGs and resizes them for contact-sheet presentation. Original captures remain in `renders/`.

Reproduce from this folder:

```sh
GODOT=/home/rikki/.local/share/eyesore-tools/4.7.2/Godot_v4.7.2-stable_linux.x86_64
"$GODOT" --headless --path source --script verify_art.gd
"$GODOT" --path source --rendering-method gl_compatibility --display-driver x11 --audio-driver Dummy
python3 make_review.py
```

Pillow is required only by the presentation script, not by Godot runtime art. Do not copy `source/.godot` cache. Source is deterministic authored mesh coordinates, original hierarchy/poses and original procedural surface shader. No stock Doom monsters, generated runtime character imagery, third-party model or animation library is used.
