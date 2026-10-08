# Combat calibration room data contract

`linux-game/src/calibration_scene.h/.cpp` defines a renderer-independent scene
for a compact first-combat room. It uses the engine's current world convention:
X east/right, Y up, +Z south, floor at Y=0, and yaw 0 faces toward -Z.

- The shell spans 24 × 20 units and is 5 units high.
- The entry divider is at Z=4.0–4.4, with a centered opening from X=-1.5 to
  X=+1.5 (3 units wide).
- One low central cover block gives the player routes around either end.
- The scene data places the player, one caster, and a shotgun pickup candidate.
- Light regions provide explicit, static normalized brightness multipliers for
  the entry, combat floor, and north recess. They are data only; the renderer
  should apply the chosen material/light treatment consistently.

To integrate, include `calibration_scene.h`, compile `calibration_scene.cpp`,
and map each `SceneBox` into the same geometry consumed by draw, movement, ray,
and projectile collision. Keep shell extents, boxes, and placement constants
derived from `kCalibrationScene`; do not duplicate hand-authored coordinates in
those systems. `weapon_pickup` is a placement point and can remain inactive
until the chosen weapon unlock flow supports it.
