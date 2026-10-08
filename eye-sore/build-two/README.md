# Eyesore build two — visual revision in progress

This is a new isolated Godot project for a standalone Linux Doom-inspired game. **Visual packet v1 was rejected; a substantial 3D and creature-design revision is in progress. Identity selection remains pending.** The complete combat exchange and 5–8 minute level follow the user's chosen direction.

## Review the three packets

Open [concepts/index.html](concepts/index.html) in a browser. It works directly from disk, without a server or network. Each packet has a static first-person combat composition, eight-color palette, four material samples, two representative enemy frames, pistol/shotgun designs, HUD thumbnail, music and physical gun/SFX auditions. Browse the detailed art board and compare dry/designed gun sounds. Browsing does not record an identity selection; reply with the chosen identity or revisions.

- **The Pale Ward** — corrupted biotech facility.
- **The Ash Citadel** — war-torn occult fortress.
- **The Occupied Line** — invaded civic megastructure.

The review page plays the lossless WAV references, preserving complete clip durations in Chromium. OGG alternatives are also retained. Audio provenance and original source files are in `concepts/audio/`; editable coordinate-authored pixel sources and pivot metadata are in `concepts/visual/`. Music listening appeal remains awaiting the user's review. The compositions are artwork, not captured gameplay.

## Run the foundation

The identity-neutral movement/display preview has an authored 3D calibration room, fast grounded WASD movement, mouse free look, a small crosshair, persisted sensitivity/FOV/mute settings, native-resolution HUD/menu text and a 640×360 nearest-scaled world. Escape pauses and opens settings. There are no production enemies, guns or level encounters yet.

Use **Godot 4.7.2 stable**, GDScript and the Compatibility renderer. The matching editor and Linux templates have been verified locally. [Toolchain instructions](docs/FOUNDATION.md) and [download evidence](verification/download_manifest.json) retain the exact versions, original URLs and hashes.

```sh
tools/godot.sh --editor
tools/godot.sh --headless -- --smoke-test
tools/godot.sh --headless --export-release "Linux Portable" build/eyesore-calibration.x86_64
```

The exported executable embeds its PCK and runs without the project or editor. The current package is a **foundation preview**, not the complete combat calibration or finished game.

## Production and preservation

The [production plan](docs/PRODUCTION_PLAN.md), [selection record](docs/SELECTION.md), [single-event contracts](docs/contracts-and-gates.md) and thirteen [specialist briefs](docs/specialists/README.md) carry the remaining work. Rendering FPS consistency, combat release/collision/animation agreement, audible audio lifecycle, complete route/reset, and sustained release playtesting remain pending after selection.

All six previous worktrees were preserved separately, including uncommitted source/assets/research. Exact local snapshots retain compiled outputs; dated archive branches were pushed to `xradas/scratchy` and their exact remote commit IDs verified. See [preservation manifest](docs/PRESERVATION.json). This project is on `codex/eyesore-build-two` in its own worktree.

[Audio credits and modification notices](concepts/audio/README.md) must accompany distributed audio. [Current verification](verification/INTEGRATION.json) separates completed foundation/packet checks from later production acceptance.
