extends SceneTree

const Director := preload("res://scripts/combat_audio.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var container := Node3D.new()
	container.process_mode = Node.PROCESS_MODE_PAUSABLE
	root.add_child(container)
	var profile := CombatAudioProfile.new()
	var sample := AudioStreamWAV.new()
	sample.format = AudioStreamWAV.FORMAT_16_BITS
	sample.mix_rate = 48000
	sample.data = PackedByteArray()
	sample.data.resize(48000 * 2)
	for weapon in ["pistol", "shotgun", "melee"]:
		for material in ["flesh", "armor", "hard"]:
			var cue := CombatCue.new()
			cue.identifier = StringName(weapon + "_" + material)
			cue.variations.append(sample)
			profile.cues.append(cue)
	for kind in ["unsealed", "vessel"]:
		for action in ["hurt", "death", "attack_warning"]:
			var cue := CombatCue.new()
			cue.identifier = StringName(kind + "_" + action)
			cue.bus = &"Creatures"
			cue.variations.append(sample)
			profile.cues.append(cue)
	var director := Director.new()
	container.add_child(director)
	director.setup(profile)
	var id := 1
	for weapon in ["pistol", "shotgun", "melee"]:
		for material in ["flesh", "armor", "hard"]:
			var event := {"type": "impact", "weapon_id": weapon, "material": material, "shot_id": id, "target_id": "test", "position": Vector3.ZERO}
			director.handle_event(event)
			director.handle_event(event)
			assert(director.last_cue == StringName(weapon + "_" + material))
			assert(director.cue_counts[director.last_cue] == 1, "Duplicate contact voice")
			id += 1
	for kind in ["unsealed", "vessel"]:
		director.handle_event({"type": "enemy_hurt", "enemy_kind": kind, "shot_id": id, "target_id": kind})
		assert(director.last_cue == StringName(kind + "_hurt"))
		id += 1
	assert(director.voices.size() == 11)
	for voice in director.voices:
		assert(voice is AudioStreamPlayer3D)
		assert(voice.bus in [&"World", &"Creatures"])
	director.handle_event({"type": "enemy_attack_warning", "enemy_kind": "unsealed", "attack_id": 1, "target_id": "alpha"})
	var warning: Node = director.voices.back()
	director.handle_event({"type": "enemy_hurt", "enemy_kind": "unsealed", "shot_id": id, "target_id": "alpha"})
	assert(not warning.playing and warning.is_queued_for_deletion())
	var hurt: Node = director.voices.back()
	director.handle_event({"type": "enemy_death", "enemy_kind": "unsealed", "shot_id": id + 1, "target_id": "alpha"})
	assert(not hurt.playing and hurt.is_queued_for_deletion())
	assert(director.voices.back().get_meta("role") == "enemy_death")
	paused = true
	assert(not director.can_process())
	AudioServer.set_bus_mute(0, true)
	paused = false
	assert(director.can_process())
	director.stop_all()
	assert(director.voices.is_empty())
	AudioServer.set_bus_mute(0, false)
	print("AUDIO_CONTRACT_OK: 9 weapon/material contacts; duplicate suppressed; 2 distinct hurts; pain/death stop actor warnings/hurt; positional buses; pause/mute processing; voice cleanup. Silent in-memory fixtures test routing only, not sound appeal or audible stream continuity.")
	quit()
