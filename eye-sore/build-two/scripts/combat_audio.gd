extends Node3D
## Only resolved combat events create voices. No raycasts or damage live here.
const MAX_VOICES := 24
var profile: CombatAudioProfile
var cue_map: Dictionary = {}
var voices: Array[Node] = []
var music_player: AudioStreamPlayer
var seen_events: Array[String] = []
var cue_counts: Dictionary = {}
var last_cue: StringName
var variation_counts: Dictionary = {}

func setup(value: CombatAudioProfile, play_music: bool = true) -> void:
	profile = value
	process_mode = Node.PROCESS_MODE_PAUSABLE
	for cue in profile.cues:
		assert(AudioServer.get_bus_index(cue.bus) >= 0, "Unknown audio bus: " + str(cue.bus))
		assert(not cue.variations.is_empty(), "Missing samples for " + str(cue.identifier))
		cue_map[cue.identifier] = cue
	if profile.music:
		music_player = AudioStreamPlayer.new()
		music_player.name = "StereoMusic"
		music_player.bus = &"Music"
		music_player.volume_db = profile.music_gain_db
		var stream := profile.music.duplicate() as AudioStream
		if stream is AudioStreamOggVorbis:
			stream.loop = true
		elif stream is AudioStreamWAV:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_begin = 0
			stream.loop_end = int(round(stream.get_length() * stream.mix_rate))
		music_player.stream = stream
		add_child(music_player)
		if play_music: music_player.play()

func start_music() -> void:
	if is_instance_valid(music_player) and not music_player.playing:
		music_player.play()

func handle_event(event: Dictionary) -> void:
	var type := String(event.get("type", ""))
	var weapon := String(event.get("weapon_id", ""))
	var kind := String(event.get("enemy_kind", ""))
	var key := ""
	match type:
		"shot": key = "melee_swing" if weapon == "melee" else weapon + "_fire"
		"impact":
			var material := String(event.get("material", "hard"))
			if material not in ["flesh", "armor", "hard"]: material = "hard"
			key = weapon + "_" + material
		"enemy_hurt": key = kind + "_hurt"
		"enemy_death": key = kind + "_death"
		"enemy_attack_warning": key = kind + "_attack_warning"
		"projectile_impact": key = "projectile_impact" if event.get("material") == &"flesh" else "projectile_hard"
		"projectile_release", "player_hurt", "empty": key = type
	if key.is_empty(): return
	# A shotgun's valid pellet damage is aggregated by combat before reaching here.
	# Suppress duplicate presentation only; this code never suppresses gameplay damage.
	var identity := ""
	if event.has("shot_id") and int(event.shot_id) > 0:
		identity = "%s:%s:%s" % [type, event.shot_id, event.get("target_id", "player")]
	elif event.has("attack_id"):
		identity = "%s:%s:%s" % [type, event.attack_id, event.get("target_id", kind)]
	if not identity.is_empty():
		if identity in seen_events: return
		seen_events.append(identity)
		if seen_events.size() > 256: seen_events.pop_front()
	var target_id := String(event.get("target_id", ""))
	if type in ["enemy_hurt", "enemy_death"]:
		stop_actor_voices(target_id, ["enemy_attack_warning", "enemy_hurt"])
	elif type == "player_hurt":
		stop_actor_voices("player", ["player_hurt"])
	play_cue(StringName(key), event.get("position", Vector3.ZERO), target_id, type)

func stop_actor_voices(target_id: String, roles: Array) -> void:
	for voice in voices:
		if is_instance_valid(voice) and voice.get_meta("target_id", "") == target_id and voice.get_meta("role", "") in roles:
			voice.process_mode = Node.PROCESS_MODE_ALWAYS
			voice.stream_paused = false
			voice.stop()
			voice.stream = null
			voice.queue_free()

func play_cue(identifier: StringName, position: Vector3, target_id: String = "", role: String = "") -> void:
	if not cue_map.has(identifier):
		push_warning("Unmapped combat cue: " + str(identifier))
		return
	var cue: CombatCue = cue_map[identifier]
	var count: int = variation_counts.get(identifier, 0)
	variation_counts[identifier] = count + 1
	var stream: AudioStream = cue.variations[count % cue.variations.size()]
	# Finished players are freed; inspect validity before any typed conversion.
	for i in range(voices.size() - 1, -1, -1):
		if not is_instance_valid(voices[i]) or voices[i].is_queued_for_deletion():
			voices.remove_at(i)
	if voices.size() >= MAX_VOICES:
		var oldest: Node = voices.pop_front()
		oldest.stop()
		oldest.queue_free()
	var voice: Node
	if cue.spatial:
		var spatial := AudioStreamPlayer3D.new()
		spatial.stream = stream
		spatial.bus = cue.bus
		spatial.volume_db = cue.gain_db
		spatial.max_db = cue.gain_db
		spatial.unit_size = 7.0
		spatial.max_distance = 32.0
		spatial.panning_strength = 0.75
		spatial.attenuation_filter_cutoff_hz = 14000.0
		voice = spatial
		add_child(voice)
		spatial.global_position = position
	else:
		var local := AudioStreamPlayer.new()
		local.stream = stream
		local.bus = cue.bus
		local.volume_db = cue.gain_db
		voice = local
		add_child(voice)
	voice.set_meta("target_id", target_id)
	voice.set_meta("role", role)
	voice.finished.connect(voice.queue_free)
	voices.append(voice)
	voice.play()
	last_cue = identifier
	cue_counts[identifier] = int(cue_counts.get(identifier, 0)) + 1

func stop_all() -> void:
	for voice in voices:
		if is_instance_valid(voice):
			voice.process_mode = Node.PROCESS_MODE_ALWAYS
			voice.stream_paused = false
			voice.stop()
			voice.stream = null
			voice.queue_free()
	voices.clear()
	if is_instance_valid(music_player):
		music_player.process_mode = Node.PROCESS_MODE_ALWAYS
		music_player.stream_paused = false
		music_player.stop()
		music_player.stream = null
	seen_events.clear()

func _exit_tree() -> void:
	stop_all()

