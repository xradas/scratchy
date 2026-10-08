# Verification evidence

All commands used the pinned 4.7.2 editor/templates. `summary.json` records final binary size/hash and scope.

- `download_manifest.json`: exact original download URLs, bytes, local SHA-256 and full ZIP CRC validation. Template metadata is `4.7.2.stable`; editor reports `4.7.2.stable.official.ed1daf0bf`.
- `import.log`: final headless editor import, exit 0 and no engine/script errors.
- `smoke-headless.log`: final source project smoke, exit 0.
- `smoke-windowed.log`: native Compatibility renderer smoke, exit 0; PNGs captured and visually inspected at 1280×720.
- `export.log`: final Linux release export using exact matching templates, exit 0.
- `export-outside-headless.log` and `export-outside-windowed.log`: embedded-PCK release executable launched with working directory `/tmp`, no project path argument; both exit 0 with smoke assertions passing.

The smoke checks scene creation, fixed 640×360 world viewport, FOV applied, six expected buses, unchanged player position during paused frames and Master mute leaving the tree free to unpause. Native frame images confirm neutral geometry and legible native HUD/settings panel. It does not simulate human movement input or validate sound playback. The acceptance gates in `docs/contracts-and-gates.md` remain pending.
