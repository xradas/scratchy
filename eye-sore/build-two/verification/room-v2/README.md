# Actual-engine concept-room verification

These PNGs were captured from Godot 4.7.2 Compatibility rendering the authored `scenes/calibration.tscn`. They are not image-generated concept boards and do not imply completed combat or level design.

- `actual-engine-gameplay.png`: main-hall actual 3D camera; near warm surfaces, mid-distance steps/walkway/vessel and deep cool-lit doorway.
- `actual-engine-annex-gameplay.png`: actual second camera position in the connected annex; wall corners, machinery depth and cast shadow.
- Corresponding `*-menu.png` files: native-resolution pause/settings over the same frozen world.
- `import.log`: final headless editor import/parse check, exit 0.
- `smoke-headless.log`, `smoke-native.log`, `smoke-native-annex.log`: fixed viewport/pause/bus smoke checks; exit 0.
- `export.log`: matching-template Linux release export, exit 0.
- `export-outside.log`, `export-outside-native.log`: portable embedded-PCK binary launches from `/tmp`, headless and native, exit 0.

No engine/script errors found in these final logs. Main screenshot was visually inspected after reducing material grain contrast. Parent foundation source/contracts and music were preserved. Geometry and material provenance, binary digest and remaining scope are recorded in `summary.json`.

`geometry-check.log` additionally records a real CharacterBody3D collision traversal along the stair slope: no jump, final grounded player center `(-5.8, 1.750868, 6.435756)` above the 0.9-unit walkway. The check validates 52 matching architectural box/cylinder mesh-and-shape dimensions and the portal/two-room floor dimensions. `tools/check_geometry.gd` applies forward velocity directly to isolate geometry traversal; WASD input mapping remains part of manual playtesting.
