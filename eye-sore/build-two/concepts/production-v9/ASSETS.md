# Clinical movement v9: assets and method

This pass introduces no new bitmap artwork. Equipment, platforms, controls and the exit use the unchanged native triage, surgery and utility texture atlases from [presentation v8](../production-v8/ASSETS.md). Shader projection selects original atlas cells on complete mesh faces. Control state stripes and glyphs, and the segmented pedestal operating table, are authored geometry. Source PNGs remain unchanged.

Clinical object lists were authored before scene creation in [clinical-layout.json](../../docs/production-v9/clinical-layout.json). All23 first-six-room furnishing instances have explicit positions, preserving type/ID/count; the other eight campaign maps retain their scene bytes. Further density and room dressing remain later work.

Movement uses actual player collision and camera position, with no new textures. Ctrl holds a real shorter capsule; blocked standing waits for clearance. Shift gives grounded1.35×sprint, crouch wins, firing remains allowed. View bob intensity defaults to0.35 and includes zero.

[Audio source brief](../../docs/production-v9/audio-brief.json) and [source survey](../../docs/production-v9/firearm-source-survey.json) record coordinator-selected library candidates. The separate listening packet is a comparison only; runtime gunshot/impact/music assets remain unchanged in this game build. Private user MP3 references stay outside the project. The [Free Firearm Sound Library](https://opengameart.org/content/the-free-firearm-sound-library) records its prepared recordings as CC0, by Ben Jaszczak, Brian Nelson, Kevin Heras and Matthew Nanney. Technical measurements do not establish listening approval.
