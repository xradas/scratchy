# Representative weapon frames v2 — darker combat study

This packet contains original dimensional weapon frames for a compact service pistol, pump shotgun and industrial-glove melee view. They are prototype assets for gameplay review, **not accepted final art**. Setting-specific enemies have not been produced while the final setting choice is pending. Rooms and integrated project files were left alone.

The frames are actual transparent renders of newly authored 3D mesh construction, followed by a small controlled native pixel finish. They are not cropped generated concept montages, imported models, or imagegen sprites. Mesh anatomy/material source, camera, lighting, recoil poses and projected wear points are retained in `source/render.gd`.

## Asset schema

Each weapon has four 320 × 180 RGBA representative poses at:

```text
assets/weapons/{pistol,shotgun,melee}/{idle,fire,recover,switch}.png
```

The stable whole-canvas held-view anchor is `(160, 180)`. Overlay these frames at the same origin and scale them exactly 2× for the 640 × 360 world. Use nearest texture filtering and disable mipmaps. Do not trim each alpha rectangle independently: that would destroy pose registration. Transparent RGB is zero and alpha is strictly binary.

`assets/weapons/flash.png` is a separate original 64 × 64 pixel effect, pivot `(32, 32)`. Attach it to the frame’s projected `muzzle_anchor` from `manifest.json`; it is not baked into the fire frame. Pistol/shotgun fire should select the recoil frame, flash and sound from the same accepted authoritative shot event. Audio callbacks must not create shots. Melee has no muzzle flash.

The pistol slide is a separately authored mesh and moves backward in fire/recover poses. The shotgun recover pose moves the modeled ribbed fore-end and supporting hand together through a partial pump stroke. Melee fire extends the right fist. Switch is a lowered representative pose. **These four poses are not complete reload, pump, switch or melee animations**, and timing still needs gameplay review.

## Source and reproduction

- `source/render.gd`, `render.tscn`, `project.godot`: original procedural mesh/pose authoring and a transparent local Godot viewport.
- `source/render_metadata.json`: camera-projected muzzle and material cleanup marker positions for each pose.
- `source/finish_sprites.py`: snaps native alpha, applies one shared 128-tone render-derived palette without dithering, and adds a few manually specified highlight/shadow pixels at projected authored wear locations. No silhouette repainting or image generation occurs.
- `assets/weapons/*/raw_*.png`: retained direct renderer outputs before pixel finish.
- `manifest.json`: authoritative relative paths, size, anchor, muzzle anchor, frame roles, provenance and hashes.
- `verification.json`: every frame’s actual dimensions, alpha rectangle, binary alpha, tone count and small cleanup count.

Render with the pinned local Godot 4.7.2 executable on an available display:

```sh
/path/to/Godot_v4.7.2-stable_linux.x86_64 --path source --rendering-method gl_compatibility --display-driver x11 --audio-driver Dummy
python3 source/finish_sprites.py
```

The Python finish requires Pillow (`requirements.txt`). Godot renders a temporary small viewport and exits after the 12 images. The renderer does not need Blender, an API key or an image-generation service. Do not copy `.godot/` caches as production assets.

## Visual inspection and limits

`probes/weapon_contact_sheet.png` shows all 12 poses at their exact native sizes over a checker. Six `probes/*_scale.png` images show idle assets at exact 2× scale over the approved biotech/fortress concept rooms. These are **diagnostic screenshot overlays**, not gameplay captures: those original concept backgrounds contain a baked illustrative gun that may remain visible behind parts of the new mesh sprite. They are not edited room textures or a claim of integrated combat.

Inspection revised the initial low framing and excessive surface grain. The shotgun now has a centered muzzle near `(160, 86)`, a long selective light barrel strip, a dark groove, a darker receiver body, separated top mechanical detail, a ribbed fore-end and a connected support grip. The pistol uses dark recesses, a shaded slide, slide serrations, sight notch and separate grip. Gloves use modeled palms, opposed thumbs, segmented curled fingers and padded cuffs.

The meshes remain deliberately economical and somewhat faceted. Hand anatomy, metal finish, pose timing and screen occupancy need real gameplay review before final acceptance. There is no complete reload animation, no mechanical simulation, no game event implementation and no enemy production in this packet. Source geometry and raw renders are retained so these can be improved directly instead of regenerating unrelated artwork.

## Revision after playtest

Original meshes retained; new renders use darker matte steel, dark green-black gloves and polymer, lower ambient/key intensity and50° render FOV to reduce screen occupation. The prior packet remains in `../weapon-prototypes/`. This is still a four-pose representative set, not completed weapon animation. All12 native RGBA assets retain binary alpha and the stable320×180 canvas; muzzle anchors are freshly projected from the same model.

Pinned pixel-finish dependency: `Pillow==12.3.0`. In this workspace the isolated art environment is `/home/rikki/.local/share/eyesore-tools/art-venv/bin/python`; install requirements in a virtual environment when reproducing elsewhere.
