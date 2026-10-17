extends SceneTree
## Verify every playable music route resolves to the new, distinct original cues.

const MUSIC_DIR := "res://assets/audio/music/original-v17/"

func _initialize() -> void:
	var failures: Array[String] = []
	var main: Control = load("res://scripts/main.gd").new()
	main.stage_catalog = JSON.parse_string(FileAccess.get_file_as_string("res://resources/stages/catalog.json")).stages
	main.campaign.load_catalog("res://resources/campaign/catalog.json")
	main.campaign_mode = true
	var seen: Dictionary = {}
	for level in main.campaign.levels:
		var id: String = String(level.id)
		if not main.campaign.seek(id):
			failures.append("Missing campaign level " + id)
			continue
		var path: String = main.selected_level_music_path()
		if path != MUSIC_DIR + id + ".ogg" or seen.has(path):
			failures.append("Wrong/duplicate campaign cue " + id + ": " + path)
		else:
			_check_stream(path, failures)
		seen[path] = true
	main.campaign_mode = false
	for stage in main.stage_catalog:
		var id := String(stage.id)
		main.stage_id = id
		var path: String = main.selected_level_music_path()
		if path != MUSIC_DIR + id + "_01.ogg":
			failures.append("Wrong standalone stage cue " + id + ": " + path)
		else:
			_check_stream(path, failures)
	var profile: CombatAudioProfile = load("res://resources/combat_audio.tres")
	if not profile.music or profile.music.resource_path != MUSIC_DIR + "pale_ward_01.ogg":
		failures.append("Wrong combat audio fallback")
	var menu_path := MUSIC_DIR + "menu.ogg"
	_check_stream(menu_path, failures)
	var packed := "--packed" in OS.get_cmdline_user_args()
	if not packed:
		var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
		if not main_source.contains('var path := "' + menu_path + '"'):
			failures.append("Menu does not use original cue")
		for source_path in ["res://scripts/main.gd", "res://resources/combat_audio.tres", "res://resources/stages/catalog.json", "res://resources/campaign/catalog.json"]:
			var source := FileAccess.get_file_as_string(source_path)
			if source.contains("menu_abelian.ogg") or source.contains("level_music_biotech_candidate.ogg") or source.contains("level_music_fortress_candidate.ogg") or source.contains("original-v16/"):
				failures.append("Legacy music remains in active config: " + source_path)
	else:
		for legacy_name in ["menu_abelian.ogg", "level_music_biotech_candidate.ogg", "level_music_fortress_candidate.ogg"]:
			var legacy_path: String = "res://assets/audio/music/" + legacy_name
			if ResourceLoader.exists(legacy_path):
				failures.append("Archived licensed cue included in game export: " + legacy_path)
	main.free()
	print("CAMPAIGN_MUSIC_V17 status=", "passed" if failures.is_empty() and seen.size() == 9 else "failed", " cues=", seen.size(), " failures=", failures)
	quit(0 if failures.is_empty() and seen.size() == 9 else 1)

func _check_stream(path: String, failures: Array[String]) -> void:
	if not ResourceLoader.exists(path):
		failures.append("Missing cue " + path)
		return
	var stream: AudioStream = load(path)
	if not stream is AudioStreamOggVorbis or stream.get_length() < 30.0:
		failures.append("Invalid/short cue " + path)
