# Eyesore — three visual concept packets

These are three equally scoped identity studies for a fresh classic Doom-style Godot game. None is selected. They use the same scene layout, threat distances, asset sizes, palette budget, HUD statistics, and board layout so that identity and readability can be compared directly. They are concept evidence, not a production art pack or a playable combat implementation.

| Packet | Identity | Threat language | Production cost |
|---|---|---|---|
| **The Pale Ward** (`corrupted-biotech`) | A clinical shell breached by living tissue; bone ceramic, surgical steel, clotted pink, culture green | A pale stretched patient with a split stitched skull; a broad rooted containment bell with a living core | Medium-high. The room can use modular panels, but skin deformation and asymmetrical organic limbs need deliberate animation |
| **The Ash Citadel** (`occult-fortress`) | Scored masonry, ritual inlay, broken ramparts, tarnished iron | A cage-crowned armored penitent with a slab cleaver; a walking four-foot reliquary with an exposed ember | Medium. Modular armor and stone are efficient; weapon timing and the shrine’s gait carry the cost |
| **The Occupied Line** (`civic-invasion`) | Brutalist transit hall, public lanes, service entrances, alien cables | A low-headed orange-backed reaver; a three-legged surveyor with an elevated multiple-lens crown | Medium-low architecture, medium creatures. Repeatable signage/concrete is economical; asymmetric and tripod poses need dedicated work |

Every directory contains:

- `board.png`: 1280 × 900 presentation, with an equally sized scene, labeled palette, both threat silhouettes, both held weapons, HUD, and four repeated material samples.
- `scene.png`: 640 × 360 finished combat composition, rendered from `scene_native.png` at 320 × 180 with exact nearest-neighbor 2× scaling. Each has a central small crosshair, a near melee enemy, a mid-distance ranged enemy, a central route, a secondary passage, a held shotgun, and a compact HUD.
- `enemy_melee.png`, `enemy_ranged.png`: transparent 96 × 128 **single design poses**. Both use feet reference `(48, 124)`; asymmetric feet occupy different contact spans around it. This is an import anchor, not an assertion that the center pixel touches the floor.
- `pistol.png`, `shotgun.png`: transparent 160 × 112 **single held-view design frames**, with bottom-center anchor `(80, 112)`. The hand intentionally meets the lower crop. These are weapon construction studies; recoil/reload/fire states are absent.
- `material_1.png` through `material_4.png`: native 32 × 32 periodic material tiles. Boards show each as a 2 × 2 repeat. Tiles are deliberately pixel-patterned and have no filtered edges; normal maps and mipmap behavior are not provided.
- `hud.png`: 320 × 32 native HUD thumbnail. Numbers are fixed comparison examples, not live game values.
- `palette.json`: eight named color inks with hex values. All opaque enemy, weapon, tile, HUD, and scene pixels are restricted to the packet’s eight inks. Board labels and UI framing use a separate neutral presentation palette.

`manifest.json` is the authoritative relative-path map for the local interactive review. `verification.json` records dimensions, alpha bounds, feet reference, opaque ink counts and re-render provenance. Integration should copy only these PNG/JSON/Markdown/Python/TXT deliverables; **exclude `_vendor/` and `__pycache__/`**.

## Authorship and reproduction

All silhouettes, anatomy, prop construction, cracks, tissue curves, surface features, and pixel clusters are newly authored in `draw_concepts.py` as explicit coordinates. Procedural placement is limited to small deterministic material wear. Floor texture uses integer nearest samples of a perspective plane. No image-generation model, stock sprite, external image, old repository asset, or previous worktree is an input. Pillow renders those coordinate instructions; it does not generate an image from a text prompt.

Use Python 3 with Pillow (`requirements.txt`), then run:

```sh
python3 draw_concepts.py
```

The host’s local dependency fallback can run the same script with:

```sh
PYTHONPATH="$PWD/_vendor" python3 draw_concepts.py
```

The render regenerates all packet assets, manifest, and verification report without fetching art or writing outside this directory. Board typography uses system DejaVu Sans; install it if the declared font path is absent.

## Readability and limits

Visual inspection covered all three boards and final 640 × 360 scenes. Melee/ranged anatomy differs in silhouette, height, stance, and focal color; the camera position and size budgets are held constant. Dark floor and wall joints give pale/armored/orange silhouettes a readable separation. The near threat occupies roughly half the usable scene height; the ranged threat remains above the gun in mid-space. The smaller optics and anatomy details are secondary to the silhouette.

The scenes are authored flat compositions with drawn perspective. They establish a game-facing look, but do not demonstrate Godot lighting, collision, enemy motion, aiming behavior, performance, or depth sorting. The eight-ink palette intentionally simplifies material and lighting. No full animation sheets, rotations, hit poses, death poses, pickups, or map textures beyond the four probes are included. Animation and runtime readability must be validated after the user chooses an identity. Identical room geometry is a comparison control, not a proposal to reuse one level for all three themes.

The gun views are illustrative held-camera crops; a later in-engine pass must confirm camera placement, recoil, and muzzle alignment. Tiny palette labels on boards are presentation text, not intended game UI. Some repeated wear remains visible by design at concept scope. These limitations apply equally to all three packets.
