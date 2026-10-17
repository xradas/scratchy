extends SceneTree

const Director := preload("res://scripts/combat_audio.gd")
const StageDoor := preload("res://scripts/stage_door.gd")
const WardDoor := preload("res://scripts/ward_door.gd")
const KINDS := ["unsealed", "vessel", "infected_scientist", "infected_security"]

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var profile: CombatAudioProfile = load("res://resources/combat_audio.tres")
	assert(profile != null)
	var registrations: Dictionary = {}
	for cue in profile.cues:
		registrations[String(cue.identifier)] = cue
	var unique_paths: Dictionary = {}
	for kind in KINDS:
		for action in ["detect", "attack_warning", "hurt", "death"]:
			var name: String = kind + "_" + action
			assert(registrations.has(name), "Missing " + name)
			var cue: CombatCue = registrations[name]
			assert(cue.bus == &"Creatures" and cue.spatial)
			assert(cue.variations.size() == 1)
			var path: String = cue.variations[0].resource_path
			assert(not unique_paths.has(path), "Shared voice: " + name)
			unique_paths[path] = true
	for kind in ["health", "armor"]:
		var cue: CombatCue = registrations["pickup_overdrive_" + kind]
		assert(cue.bus == &"UI" and not cue.spatial)
	var director: Node3D = Director.new()
	root.add_child(director)
	director.setup(profile, false)
	for kind in KINDS:
		var actor_id: String = kind + "_test"
		var at := Vector3(2, 1, -4)
		var detect := {"type":"enemy_detect", "enemy_kind":kind, "target_id":actor_id, "position":at}
		director.handle_event(detect)
		var voice: Node = director.voices.back()
		assert(voice is AudioStreamPlayer3D and voice.bus == &"Creatures" and voice.global_position.is_equal_approx(at))
		director.handle_event(detect)
		assert(int(director.cue_counts.get(StringName(kind + "_detect"), 0)) == 1)
		director.handle_event({"type":"enemy_attack_warning", "enemy_kind":kind, "target_id":actor_id, "attack_id":1, "position":at})
		director.handle_event({"type":"enemy_hurt", "enemy_kind":kind, "target_id":actor_id, "shot_id":20, "position":at})
		assert(voice.is_queued_for_deletion() and not voice.playing)
		var hurt: Node = director.voices.back()
		director.handle_event({"type":"enemy_death", "enemy_kind":kind, "target_id":actor_id, "shot_id":21, "position":at})
		assert(hurt.is_queued_for_deletion() and not hurt.playing)
		director.handle_event(detect)
		assert(int(director.cue_counts.get(StringName(kind + "_detect"), 0)) == 1)
	for kind in ["health", "armor"]:
		director.handle_event({"type":"item_collected", "item_kind":"overdrive_" + kind, "pickup_id":"overdrive_test_" + kind})
		assert(director.last_cue == StringName("pickup_overdrive_" + kind))
	var doors_parent := Node3D.new()
	root.add_child(doors_parent)
	for script in [StageDoor, WardDoor]:
		var door: Variant = script.new()
		var collision := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1, 2, 0.4)
		collision.shape = box
		collision.name = "Collision"
		door.add_child(collision)
		doors_parent.add_child(door)
		assert(door.motor is AudioStreamPlayer3D and door.motor.bus == &"World")
		assert(door.activate({}) if script == StageDoor else door.activate(true))
		assert(door.motor.playing and door.motor.stream.resource_path.ends_with("door_open.ogg"))
		var first_stream: AudioStream = door.motor.stream
		assert(door.activate({}) if script == StageDoor else door.activate(true))
		assert(door.motor.stream == first_stream)
		if script == StageDoor:
			assert(door.seal())
			assert(door.motor.playing and door.motor.stream.resource_path.ends_with("door_close.ogg"))
		door.reset_door()
		assert(not door.motor.playing)
		door.free()
	doors_parent.free()
	director.stop_all()
	assert(director.voices.is_empty())
	await create_timer(0.1).timeout
	director.free()
	print("WARD_AUDIO_V19_OK: 16 unique spatial creature states, one detection/actor, pain/death interruption, overdrive cues, positional door state cues/reset")
	quit()
