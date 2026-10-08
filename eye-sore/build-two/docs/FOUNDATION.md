# 3D concept room — identity selection pending

This is a new, isolated Godot foundation. It contains an original industrial/biotech-adjacent concept room, grounded movement and the display/settings shell. This is an actual Godot 3D scene, not an image-generated board or a finished game. It contains no production levels, weapons, enemies, combat, soundtrack or identity-specific assets. The room is authored in `scenes/calibration.tscn`; architectural boxes use matching BoxShape3D sizes and processing vessels use CylinderShape3D collision. Visual stair risers share an underlying sloped ConvexPolygonShape3D so grounded movement can reach the raised walkway without jumping. Overhead cosmetic conduits and light faces have no gameplay collision. It is a concept/calibration fixture, not an accepted level.

## Pinned toolchain

Use **Godot 4.7.2 stable**, GDScript and the **Compatibility** renderer. The downloaded Linux editor reports `4.7.2.stable.official.ed1daf0bf`. Matching export template archive `templates/version.txt` reports `4.7.2.stable`.

Editor, downloaded archives and extracted Linux templates live outside this project at `/home/rikki/.local/share/eyesore-tools/4.7.2`. Original URLs, downloaded file sizes, local SHA-256 digests and ZIP CRC verification are recorded in `verification/download_manifest.json`. These local hashes identify the actual downloaded files; they are not presented as independently verified publisher signatures.

```bash
/home/rikki/.local/share/eyesore-tools/4.7.2/Godot_v4.7.2-stable_linux.x86_64 --editor --path /home/rikki/Projects/eyesore-build-two/eye-sore/build-two
```

`Linux Portable` uses the matching standard versioned template directory `${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/4.7.2.stable/`. The local Linux debug/release templates and version.txt come from the verified archive. `tools/godot.sh` rejects editors outside 4.7.2 stable. On another machine install the exact same editor/templates; set `GODOT_BIN` as needed.

## Running and exporting

```bash
/home/rikki/.local/share/eyesore-tools/4.7.2/Godot_v4.7.2-stable_linux.x86_64 --headless --path /home/rikki/Projects/eyesore-build-two/eye-sore/build-two --editor --import
/home/rikki/.local/share/eyesore-tools/4.7.2/Godot_v4.7.2-stable_linux.x86_64 --headless --path /home/rikki/Projects/eyesore-build-two/eye-sore/build-two -- --smoke-test
mkdir -p /home/rikki/Projects/eyesore-build-two/eye-sore/build-two/build
/home/rikki/.local/share/eyesore-tools/4.7.2/Godot_v4.7.2-stable_linux.x86_64 --headless --path /home/rikki/Projects/eyesore-build-two/eye-sore/build-two --export-release "Linux Portable" /home/rikki/Projects/eyesore-build-two/eye-sore/build-two/build/eyesore-concept-room.x86_64
cd /tmp
/home/rikki/Projects/eyesore-build-two/eye-sore/build-two/build/eyesore-concept-room.x86_64
```

The executable embeds its PCK. Portable here means no dependence on the source project/editor; ordinary Linux graphics/system library compatibility still applies.

## Controls and display

Enter/resume calibration, then use WASD and captured mouse look. Escape pauses and opens settings. There is no jump or dash. Movement is 8 units/second with grounded acceleration, gravity and collision. Sensitivity and FOV sliders plus mute persist in Godot's `user://calibration_settings.cfg`.

World rendering is fixed at 640×360, displayed through a nearest-filtered texture. Enlargements use integer scaling and centered black margins; windows smaller than 640×360 use nearest downscaling. Menu, text and small crosshair render in the native window viewport rather than the world SubViewport.

## Pause and audio ownership

Buses: Master, Weapons, Creatures, World, Music, UI. Mute only changes Master bus audibility and never pauses the tree. The calibration world has `PROCESS_MODE_PAUSABLE`; Escape sets `SceneTree.paused`, freezing its physics. Native menu and input shell continue processing.

Future gameplay AudioStreamPlayer nodes must be descendants of the pausable world and inherit its processing mode. Godot pauses those players with their node process state. UI audio may process while paused on the UI bus. Do not implement pause by muting buses: that loses stream continuity. No sound asset or gameplay stream exists in this foundation, so audible stream-resume acceptance is still pending.

## Identity gate

The user must select the game's identity before producing full level, combat or asset content. The resource definitions are empty schemas only. See `docs/contracts-and-gates.md` for future event contracts and pending acceptance work.

## Original 3D architecture and material provenance

`scenes/calibration.tscn` contains two physically connected spaces, 0.7-unit thick exterior walls, a 1.5-unit deep door reveal, structural ribs, overhead beams/conduits, a six-riser service access, raised walkway/railings, utility cabinet and cylindrical processing vessels. Local lights and cast shadows separate near, middle and far surfaces. Main and annex camera poses show the same connected scene from two positions.

The four 128×128 PNG material tiles are original deterministic procedural pixels authored by `tools/author_environment.py`, using Python standard-library raster/PNG code and random seed 472. They depict concrete courses, bolted steel, tread plate and grille slats. No photographs, Doom textures, downloaded art, licensed game meshes or generated image boards are used. The authoring tool writes the scene offline; gameplay does not construct the room dynamically.

This borrows the readable spatial architecture, textured surfaces and first-person view of classic Doom-era environments. It uses Godot's actual 3D renderer and is not the Doom engine. No weapon, enemy or approved identity is implied.

| View | What this actual engine view demonstrates | What remains conceptual |
| --- | --- | --- |
| Main hall | Near warm wall/floor, repeated structural depth, overhead pipes, visible step/riser faces, raised walkway, thick cool-lit doorway | Final art direction, gameplay layout and encounter placement |
| Connected annex | Different camera position in the same authored space, concrete corner/recess hierarchy, three-dimensional machinery with cast shadow | Production machinery design and interactive behavior |

Actual source-engine frames are `verification/room-v2/actual-engine-gameplay.png` and `verification/room-v2/actual-engine-annex-gameplay.png`; the corresponding menu frames preserve the native HUD/settings. A generated concept board is separate creative reference and cannot be substituted for these engine captures.

Capture the annex view using the same source smoke command with `--view=annex`. Optional `--capture-prefix=/absolute/path/prefix` saves actual native window frames in smoke mode.

Headless geometry check: `godot --headless --path <project> --script res://tools/check_geometry.gd`. It validates matching solid mesh/shape dimensions and moves a CharacterBody3D up the stair slope onto the walkway without jumping. Visual riser faces and the smooth traversal slope are deliberately separate; later precise weapon traces against steps require design acceptance before combat production.
