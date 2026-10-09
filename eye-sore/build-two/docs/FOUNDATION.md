# Pinned Godot foundation

Use Godot **4.7.2 stable** (`4.7.2.stable.official.ed1daf0bf`), GDScript, Compatibility rendering and matching standard Linux export templates. Editor and downloaded original tool archives live outside the project under `/home/rikki/.local/share/eyesore-tools/4.7.2`. Download provenance and hashes are in `verification/download_manifest.json`. `tools/godot.sh` rejects a different engine version; set GODOT_BIN/EYESORE_TOOL_ROOT for another installation of the same version.

From the project directory:

```bash
tools/godot.sh --headless --editor --import
tools/godot.sh
tools/godot.sh --headless -- --smoke-test
tools/godot.sh --headless --export-release "Linux Portable" /absolute/output/eyesore.x86_64
```

Matching Linux templates are installed in the usual Godot `export_templates/4.7.2.stable` directory. The export embeds its PCK and excludes concept/research/docs/tools/verification; all runtime scene/script/material/sprite/audio resources and the JSON art manifest are included. Export launch is verified from `/tmp`. The portable archive includes separate full visual/audio credits, Godot MIT and component license notices. Ordinary Linux graphics/audio/system libraries are required.

The runtime loads `scenes/pale_ward.tscn`. Pass `-- --calibration` to retain the original isolated combat room for regression tools. This is separate from the preserved six prior worktrees/builds. New authored environment geometry is reproducible with `tools/author_pale_ward.py`; it only authors native scene/mesh resources and never rewrites raster PNGs. Install the pinned editor first if reproducing the generator on another machine.

Physics runs at fixed 60Hz. Player/enemies share a bounded grounded step helper that queries real shape clearance and a tread landing; horizontal movement remains owned by move_and_slide. Twelve visible stair boxes have matching physical boxes, rather than an invisible slope. Capsule corners can briefly change floor flags while settling; traversal records those transitions. Moving gates and the passenger lift use their actual visible collision bodies. The whole world is pausable, while menu input remains active.
