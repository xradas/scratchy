# Eyesore — rebuilt visual directions

Three new concept boards emphasize textured room depth, sculptural enemy anatomy, directional shading, grounded weight and credible forward-pointing weapons. The music and SFX were left unchanged. No identity is selected.

These images are **built-in imagegen generated 3D-volume concept studies**. They are not hand-authored pixel sprites, original 3D models, production animation frames, seamless texture assets, or Godot screenshots. Hand-authored production art and animation remain pending identity selection.

| Direction | Close threat | Ranged threat | Visual and production implications |
|---|---|---|---|
| **The Pale Ward** — corrupted biotech | **Unsealed:** a muscular pursuing body, long gripping forearms, strong knee/hip articulation and a forward stride | **Vessel:** a heavy broad organism with bracing limbs, fractured containment ribs and a visible pressure sac/nozzle | Ceramic/steel architecture is modular; organic deformation and containment detail make character production expensive. This original board retains a more contemporary detailed rendered finish |
| **The Ash Citadel** — occult fortress | **Ironbound:** planted armor mass and an upright slab cleaver make the close attack legible | **Censer:** a low four-legged ossuary mass with a recessed ember mouth communicates ranged bursts | Masonry, iron and armor can share a disciplined material set. Weight transfer for the cleaver and four-legged gait require substantial animation work. Its finish is more visibly digitized and painted |
| **The Occupied Line** — civic invasion | **Reaver:** thick legs, a low armored skull and fused cutting arm convey pursuit and a lateral slash | **Surveyor:** a weighted tripod body and raised cyan sensor organs signal long-range aiming | Concrete/transit materials offer efficient reuse. Reaver articulation and tripod locomotion need dedicated poses. Its finish is visibly coarse and textured |

Every 1536 × 1024 board contains the same concept scope: a large first-person combat view, both monster roles, pistol and shotgun construction studies, four material studies, an eight-swatch reference palette and a compact HUD example. Layout details vary because the boards are generated illustrations. A few alternate static monster views were added by the generator in the fortress/civic boards; they are **not animation sheets** and do not prove consistent rotation geometry.

The original classic Doom structural reference was the [official publisher Steam page](https://store.steampowered.com/app/2280/DOOM__DOOM_II/), used to examine stair/riser faces, doorway depth, body shading and different threat masses. No screenshot, Doom creature, weapon, texture or other game asset was supplied as an image-generation input or copied into the project. The rejected coordinate-art packets were not references and remain preserved separately.

## Files and provenance

`manifest.json` preserves the original review field schema, relative asset paths, identity descriptions, sampled palette colors, production costs and limitations. Each concept directory contains:

- `board.png`: the untouched generated board, copied byte-for-byte from the tool’s default saved output.
- `prompt.txt`: the exact full prompt used for that board.
- `generation.json`: tool/mode, input-image count, original save path, copied save path, SHA-256 and crop metadata.
- `scene.png`: actual 640 × 360 undistorted central scene crop, exported with nearest resampling.
- `scene_pixel_preview.png`: the same crop sampled to 320 × 180 and scaled exactly 2× with nearest sampling, to inspect volume and threat readability at classic game scale.
- `scene_preview_native.png`: the native 320 × 180 scale-test pixels.
- `palette.json`: eight sampled board-palette reference colors. They are reference colors, **not an eight-ink constraint**; the image uses broad shading ramps.

`export_review.py` reproduces only the documented crop/resize exports, palette metadata and verification. It does not reproduce the stochastic generated art. It does not repaint, composite, extract alpha, change color, or fabricate production sprites. Requires Pillow (`requirements.txt`). Run it from any directory with:

```sh
python3 export_review.py
```

The original generation used the built-in `image_gen.imagegen` tool, with no CLI/API fallback, no image references and `transparent_background=false`. Exact prompts are the source of the concept-generation instructions. The unchanged board files are the retained source rasters. The prompts explicitly require original monsters and physically credible gun construction, volume, classic textured sector depth and mature horror. Fortress/civic prompts additionally require digitized painted tonal clusters and restrained reflections.

## Inspection and limitations

All original boards and all three pixel-scale exports were visually inspected. Stairs, riser faces, recesses, overlapping planes and directional shadows make the rooms read as deep spaces. Muscle/armor/carapace shadow ramps establish weight. Near and mid threats have distinct mass and posture, and the guns are viewed from behind aimed into the room.

The main generated panels are ultrawide, so a full-screen 16:9 export requires a crop rather than stretching bodies. Exact rectangles are recorded in the manifest. Biotech preserves both threats and the complete HUD, with its original crosshair slightly left of center. Fortress preserves its complete HUD strip. Civic’s central crop omits the left-positioned HUD and clips the near blade at the left frame; the complete original board preserves both. A consistent live/review HUD must be implemented separately rather than pretending these generated numbers are functional UI.

The pixel previews are export scale tests, not proof of authored pixel clusters. Downsampling reduces some anatomy detail; enemy identity still depends on coherent silhouettes and tonal mass. Generated scene/study anatomy and machining details vary and must be locked in later production. Material swatches have not been tested for seamless repeat. No alpha sprites, feet pivots, rotations, attack timing, frame alignment, collisions or gameplay behavior are asserted for these concepts.

After selection, production should establish an original model or deliberate hand-painted sprite construction, then create and verify the necessary directional and animation frames at the actual target resolution. These concept images should guide that work; they are not a substitute for it.
