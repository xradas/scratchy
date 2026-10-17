extends SceneTree
## Load every authored campaign cue and exercise Main's actual selection function.

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
		var expected := "res://assets/audio/music/original-v16/%s.ogg" % id
		if path != expected or seen.has(path) or not ResourceLoader.exists(path):
			failures.append("Cue selection/missing/duplicate " + id + ": " + path)
			continue
		var stream: AudioStream = load(path)
		if not stream is AudioStreamOggVorbis or stream.get_length() < 30.0:
			failures.append("Invalid/short stereo cue " + id)
		seen[path] = true
	main.free()
	print("CAMPAIGN_MUSIC_V16 status=", "passed" if failures.is_empty() and seen.size() == 9 else "failed", " cues=", seen.size(), " failures=", failures)
	quit(0 if failures.is_empty() and seen.size() == 9 else 1)
