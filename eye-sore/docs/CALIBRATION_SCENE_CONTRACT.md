# Combat calibration room data contract

`linux-game/src/calibration_scene.h/.cpp` defines a renderer-independent scene
for a compact first-combat room. It uses the engine's current world convention:
X east/right, Y up, +Z south, floor at Y=0, and yaw 0 faces toward -Z.

- The shell spans 24 × 20 units and is 5 units high.
- The entry divider is at Z=5–6, with a 3-unit opening from X=3 to X=6.
- A full-height central cover block leaves routes around both ends.
- The scene data places the player, one caster, and a shotgun pickup candidate.
- Fixed floor brightness is .75 in the entry, .68 in the main lane, .88 in the
  east lane, and .42 in the west lane. These regions are scene data and are
  drawn with separate floor patches; they do not use the camera-relative point
  light in the legacy renderer.

To integrate, include `calibration_scene.h`, compile `calibration_scene.cpp`,
and map each `SceneBox` into the same geometry consumed by draw, movement, ray,
and projectile collision. Keep shell extents, boxes, and placement constants
derived from `kCalibrationScene`; do not duplicate hand-authored coordinates in
those systems. `weapon_pickup` is a placement point and can remain inactive
until the chosen weapon unlock flow supports it.
