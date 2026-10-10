# Themed stage expansion, 10 October 2026

User direction: the six creatures in the three approved original art boards belong in their own theme stages. Chapter placement and story ordering are deferred. The menu provides independent stage selection.

Coordinator selected the original boards, geometry grammar, room graphs, enemy identities, armor masks, native sprite regions, audio designs and gore identities. Programming workers implement bounded contracts and verification; they do not research or choose replacement themes. Existing approved HUD, aligned guns, physical dry contacts and two Ward voices remain.

The creator page https://www.moddb.com/mods/brutal-doom describes distinctive death/gib presentations and dismemberment. Our design inference is directional blood fans, severed anatomical/hardware pieces with momentum, surface spatter and finite shootable corpses. No Doom, Quake or Brutal Doom artwork/audio/code is copied.

All new raster generation used the built-in imagegen tool with the original approved theme board as reference and transparent_background=true. Original PNG bytes remain intact. Coordinator-reviewed native AtlasTexture rectangles isolate complete irregularly spaced poses and keep visual/live/corpse hit regions identical. Raised blades and fallen bodies cross nominal grid boundaries; the initial uniform-grid candidates were rejected. This is generated pose adaptation, not hand-authored full animation.

Four new creatures have eight directional stance images plus frontal combat, pain and death sequences. The existing Ward pair retain their approved frontal sequences. Full directional animated movement/attack production, human listening approval, visual acceptance and human pacing remain open.

Abelian remains menu-only. Bestial Paragon Interface scores Ward and temporarily Line; Dragged Through Hellfire (Abomination) scores Citadel. Existing licensed music bytes are preserved. New twelve dry creature voice cues derive from preserved HaelDB CC0 originals with distinct formants, rasp and duration compensation; exact edits/hashes in concepts/audio-v5/manifest.json. Its first build rejected the short decimal afade duration spelling (FFmpeg exit234); the corrected0.035 spelling passed all twelve duration/rail checks.

## Export verification path contract

Godot documents that `ProjectSettings.globalize_path("res://…")` does not work in exported projects; exported filesystem neighbors use `OS.get_executable_path().get_base_dir()`. Primary reference: https://docs.godotengine.org/en/stable/classes/class_projectsettings.html#class-projectsettings-method-globalize-path . The optional release test receipt-directory guard must use that executable directory outside the editor. This changes the verification driver only, not ordinary gameplay. Initial rejected external-path evidence is preserved separately; accepted release routes must be rerun on the corrected export.
