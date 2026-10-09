# The Pale Ward — approved artwork adapted into runtime sprites

The user said the earlier 2D concept art should be used, and that the procedural 3D studies wasted the approved direction. The current game now uses faithful transparent creature and weapon sprite adaptations of that exact approved board, and the unchanged approved scene as actual title artwork. The Pale Ward remains the selected first-level setting.

## Source and edits

Built-in **imagegen**, edit mode, supplied the approved `../visual-v2/corrupted-biotech/board.png` as the locked appearance reference. No CLI/API fallback. Original output PNGs are copied byte-for-byte; exact prompts and generation metadata are retained under `enemies/` and `weapons/`. These are generated adaptations, not hand-authored animation or newly authored 3D models. No Doom game assets were supplied or copied.

- Unsealed and Vessel: two 1536×1024RGBA atlases, eight 384×512 cells, frontal idle/two walk/windup/recovery/pain/death-fall/corpse poses. Built-in layout corrections provide clear cell borders. Measured per-frame foot pivots register every pose on the same ground plane.
- Pistol, shotgun and melee: three 1536×1024RGBA atlases with four representative view poses. Generated registration/perspective varies; authored runtime region/marker/scale metadata consumes original pixels without raster editing. The firing event owns pose, muzzle effect and audio.
- Title: byte-identical640×360 `scene.png` copied to runtime. Godot displays the region above its static concept HUD. The scene remains static title artwork; it is not presented as live exploration.

`runtime-registration.json` records the exact runtime regions, feet, scales, muzzle/nozzle anchors and authored Vessel hardware material polygons. PNG resize/crop/repaint was not performed by Python; Python only reads alpha and copies/hashes files. Godot atlas regions and sprite transforms provide registration and nearest rendering.

## Gameplay correspondence and evidence

Billboard visuals and bounded 128×192 alpha-query triangles share a camera-facing pivot. Transparent pixels miss even where a movement capsule exists. Organic pixels route flesh contacts; manually traced visible collar/rib strips route armor. Multiple pellets aggregate once per target; corpses disable query surfaces. Source sub-cell details are approximated by the bounded gameplay raster. Source-file keyed caches stay at16 pose entries/two images across retries.

Actual integrated game captures are in `../../verification/combat/board-sprite-*.png`: title, pistol, shotgun, a real accepted firing event/muzzle frame, melee, windup and corpses. Fixed creature placement and frozen AI make those comparisons readable; this is not a completed-level playtest. Native actual-atlas ray checks cover all16 poses and24 armor points. Integrated aim/balance checks retain pistol4/8, shotgun1/2 and melee3/6 close-range kills;30/60/120 timing stays at 6 shots/30 ammo over 120 physics frames. The isolated actual stereo game output is `board-sprite-driver-mix.wav`.

## Limits

One frontal creature direction only; full eight-direction animation remains pending. Some generated anatomy, claws, vent counts and gun pose/perspective details drift. Weapons have four poses; creatures have representative pose sequences. The original mesh studies and previous builds are preserved. The authored5–8 minute level, complete assets and sustained release playtest remain later gates. User visual acceptance is not claimed.
