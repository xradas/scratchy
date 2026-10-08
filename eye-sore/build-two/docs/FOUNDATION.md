# Calibration foundation — identity selection pending

This is a new, isolated Godot foundation. It contains a neutral calibration room, grounded movement and the display/settings shell. It contains no production levels, weapons, enemies, combat, soundtrack or identity-specific assets. The room is authored in `scenes/calibration.tscn`; every visible solid box has a matching physical BoxShape3D with the same dimensions. It is a calibration fixture, not an accepted level.

## Pinned toolchain

Use **Godot 4.7.2 stable**, GDScript and the **Compatibility** renderer. The downloaded Linux editor reports `4.7.2.stable.official.ed1daf0bf`. Matching export template archive `templates/version.txt` reports `4.7.2.stable`.

Editor, downloaded archives and extracted Linux templates live outside this project at `/home/rikki/.local/share/eyesore-tools/4.7.2`. Original URLs, downloaded file sizes, local SHA-256 digests and ZIP CRC verification are recorded in `verification/download_manifest.json`. These local hashes identify the actual downloaded files; they are not presented as independently verified publisher signatures.

```bash
/home/rikki/.local/share/eyesore-tools/4.7.2/Godot_v4.7.2-stable_linux.x86_64 --editor --path /home/rikki/Projects/eyesore-build-two/eye-sore/build-two
```

`Linux Portable` uses the standard versioned export template directory. Install `linux_debug.x86_64`, `linux_release.x86_64` and `version.txt` from the matching archive under `${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/4.7.2.stable/`. The local installation contains these exact downloaded Linux templates. `tools/godot.sh` rejects editors outside 4.7.2 stable; on another machine set `GODOT_BIN` to that editor or install it under the documented tool root. Do not silently select newer templates.

## Running and exporting

```bash
/home/rikki/.local/share/eyesore-tools/4.7.2/Godot_v4.7.2-stable_linux.x86_64 --headless --path /home/rikki/Projects/eyesore-build-two/eye-sore/build-two --editor --import
/home/rikki/.local/share/eyesore-tools/4.7.2/Godot_v4.7.2-stable_linux.x86_64 --headless --path /home/rikki/Projects/eyesore-build-two/eye-sore/build-two -- --smoke-test
mkdir -p /home/rikki/Projects/eyesore-build-two/eye-sore/build-two/build
/home/rikki/.local/share/eyesore-tools/4.7.2/Godot_v4.7.2-stable_linux.x86_64 --headless --path /home/rikki/Projects/eyesore-build-two/eye-sore/build-two --export-release "Linux Portable" /home/rikki/Projects/eyesore-build-two/eye-sore/build-two/build/eyesore-calibration.x86_64
cd /tmp
/home/rikki/Projects/eyesore-build-two/eye-sore/build-two/build/eyesore-calibration.x86_64
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
