extends SceneTree
## Import the exported cue ledger into the Resource used by gameplay.
func _initialize() -> void:
	var ledger: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/runtime-cues.json"))
	var profile := CombatAudioProfile.new()
	for key in ledger.cues:
		var data: Dictionary = ledger.cues[key]
		var cue := CombatCue.new()
		cue.identifier = StringName(key)
		cue.bus = StringName(data.bus)
		cue.gain_db = float(data.get("gain_db", 0.0))
		cue.spatial = cue.bus != &"Weapons"
		assert(ResourceLoader.exists(data.file), "Missing cue: " + data.file)
		cue.variations.append(load(data.file))
		profile.cues.append(cue)
	if ledger.has("level_music"):
		profile.music = load(ledger.level_music)
	profile.music_gain_db = -5.0
	var error := ResourceSaver.save(profile, "res://resources/combat_audio.tres")
	assert(error == OK)
	print("AUDIO_PROFILE_BUILT: ", profile.cues.size(), " licensed cue definitions; separate menu and provisional calibration music.")
	quit()
