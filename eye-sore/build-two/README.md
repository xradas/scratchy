# Eyesore build two — revised identity review

This is a new isolated Godot project for a standalone Linux Doom-inspired game. The rejected flat art is preserved. Three revised directions now show textured spatial depth, shaded weapon forms and stronger creature anatomy. **Identity selection remains pending.** Abelian is assigned to the main menu following your feedback. Separate level music candidates match the biotech and fortress settings.

## Review the revised packets

Open [concepts/index.html](concepts/index.html) in a browser, or run `python3 concepts/serve_review.py` and visit `http://127.0.0.1:8764/`. The page works from disk; the optional local server supports audio seeking. Each equally scoped packet includes a combat composition, palette/material studies, two enemy roles, pistol/shotgun studies, HUD thumbnail and sourced audio/music auditions. The primary image is a 320×180 scale test enlarged to 640×360; expand the original board for design detail. Separate captures show the actual Godot room.

- **The Pale Ward** — corrupted biotech facility.
- **The Ash Citadel** — war-torn occult fortress.
- **The Occupied Line** — invaded civic megastructure.

[Visual source and exact prompts](concepts/visual-v2/README.md) identify these as built-in imagegen concept studies. They are not hand-authored production sprites, models or animation sets. The [classic Doom visual audit](docs/DOOM_VISUAL_AUDIT.md) records spatial, silhouette, shading and weapon framing criteria. Original Doom assets are not used. The rejected coordinate packet remains under `concepts/rejected/coordinate-v1/`.

The review plays lossless WAV references. OGG alternatives, selected unmodified originals, licenses and [audio credits](concepts/audio/README.md) are retained. You praised the music; sound effect and final gameplay mix approval remain pending. Browsing does not record an identity choice: reply with a chosen direction or revisions.

## Run the real 3D room preview

The authored room has connected spaces, thick door reveals, raised walkable service access, machinery, original pixel materials and cast shadows. WASD moves; the mouse looks; Escape pauses and opens settings. Sensitivity, FOV and mute persist. The world renders at 640×360 with nearest scaling, while HUD/menu text uses window resolution. The source now also contains combat logic, representative mesh-rendered weapon poses and provisional encounter fixtures. Enemy visuals are still neutral collision proxies. This is not the accepted complete combat calibration. The previously exported room preview remains the movement-only build.

Use **Godot 4.7.2 stable**, GDScript and the Compatibility renderer, with matching Linux export templates. [Setup and foundation details](docs/FOUNDATION.md) and [download evidence](verification/download_manifest.json) pin the toolchain.

```sh
tools/godot.sh --editor
tools/godot.sh --headless -- --smoke-test
tools/godot.sh --headless --script res://tools/check_geometry.gd
tools/godot.sh --headless --export-release "Linux Portable" build/eyesore-room-preview.x86_64
```

The Linux executable embeds its PCK and launches without the source project/editor. This is a movement/display preview, not the complete combat calibration or finished game.

## Production and preservation

The [production plan](docs/PRODUCTION_PLAN.md), [selection record](docs/SELECTION.md), [event contracts](docs/contracts-and-gates.md) and thirteen [specialist briefs](docs/specialists/README.md) carry the remaining work. Selection precedes complete animation and combat production; combat review precedes the 5–8 minute level. The [verification report](verification/INTEGRATION.json) separates completed preview checks from pending gameplay acceptance.

All six prior worktrees, including uncommitted source/assets/research and local build outputs, were preserved separately. Dated archive branches were pushed to `xradas/scratchy` and exact remote commit IDs verified. See the [preservation manifest](docs/PRESERVATION.json). This project is on `codex/eyesore-build-two` in its own worktree.

## Current audio correction

The wet-impact audition was rejected. The replacement uses dry Doom/Quake-inspired contact and short pain grunts, still routed by weapon × actual hit material. See the [current listening page](concepts/audio-v3/index.html), with the longer death screams first and an actual isolated stereo game-output recording. The old wet pack remains labeled rejected research. New sounds require listening review; technical checks alone do not establish quality.

Combat definitions and authoritative events now handle one-shell seven-pellet aggregation, finite ammo, attack interruption, deaths and reset. Native render-cap checks at30/60/120FPS produced identical fixed60Hz firing and movement. UI/audio integration separates menu, paused world and restart ownership. The full directional creature and weapon animation sets, selected level, route design and release playtest remain later gates.

The current Linux combat prototype includes pistol, shotgun, melee, weapon poses and the dry cue bank. Enemy visuals are neutral proxies. It is separate from the preserved room-only preview; a complete authored level is still pending.
