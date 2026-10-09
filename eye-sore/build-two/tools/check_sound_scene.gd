extends SceneTree
## Exercise real combat contacts and the menu/level audio lifecycle.
var app: Control
var capture: AudioEffectCapture
var stereo := PackedVector2Array()
var capture_path := "res://verification/combat/actual-game-mix.wav"

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-prefix="):
			capture_path = "res://verification/combat/" + argument.trim_prefix("--capture-prefix=") + "-bus-mix.wav"
	if "--isolated-audio" in OS.get_cmdline_user_args():
		assert("eyesore_review" in AudioServer.get_output_device_list())
		AudioServer.output_device = "eyesore_review"
	call_deferred("run")

func wait_audio(seconds: float) -> void:
	var remaining := seconds
	while remaining > 0:
		await create_timer(minf(remaining, 0.05), true).timeout
		remaining -= 0.05
		stereo.append_array(capture.get_buffer(capture.get_frames_available()))

func run() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	capture = AudioEffectCapture.new()
	capture.buffer_length = 2.0
	var effect_index := AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0, capture)
	app = preload("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	assert(is_instance_valid(app.menu_music) and app.menu_music.playing)
	assert(is_instance_valid(app.combat_audio.music_player) and not app.combat_audio.music_player.playing)
	await wait_audio(0.5)
	app.enter_combat()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	assert(not app.menu_music.playing and app.combat_audio.music_player.playing)
	app.combat.set_physics_process(false)
	for enemy in app.combat.enemies: enemy.set_physics_process(false)
	await wait_audio(0.4)
	app.set_paused(true)
	var paused_position: float = app.combat_audio.music_player.get_playback_position()
	await wait_audio(0.25)
	var pause_drift: float = absf(app.combat_audio.music_player.get_playback_position() - paused_position)
	assert(pause_drift < 0.04, "Pause advanced the level soundtrack")
	assert(not app.menu_music.playing)
	app.set_paused(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	AudioServer.set_bus_mute(0, true)
	var muted_position: float = app.combat_audio.music_player.get_playback_position()
	await wait_audio(0.25)
	assert(app.combat_audio.music_player.get_playback_position() > muted_position + 0.15, "Mute must retain advancing playback")
	AudioServer.set_bus_mute(0, false)
	app.player.position = Vector3(0, 0.87, 14)
	app.player.rotation = Vector3.ZERO
	app.player.get_node("Camera3D").rotation = Vector3.ZERO
	var target: CharacterBody3D
	for enemy in app.combat.enemies: enemy.health = 2000
	var expected := []
	for weapon in [&"pistol", &"shotgun", &"melee"]:
		for material in [&"flesh", &"armor"]:
			var index := 0 if material == &"flesh" else 1
			target = app.combat.enemies[index]
			app.combat.enemies[1 - index].position = Vector3(9, 0.87, 3)
			target.position = Vector3(0, 0.87, 12.5 if weapon == &"melee" else 10)
			target.definition.hit_material = material
			# Controlled material fixture on real posed mesh geometry.
			for surface in target.hurt_shapes: surface.set_meta("hit_material", material)
			await physics_frame
			await physics_frame
			app.player.get_node("Camera3D").look_at(target.global_position + Vector3(0, 0.3, 0))
			app.combat.recoil_remaining = 0
			app.combat.currentweapon = weapon
			app.combat.weapon_phase = &"idle"
			app.combat.cooldown = 0
			assert(app.combat.try_fire())
			var key := StringName(str(weapon) + "_" + str(material))
			expected.append(key)
			assert(app.combat_audio.cue_counts.get(key, 0) == 1, "Actual contact did not dispatch " + str(key))
			await wait_audio(0.8)
	assert(app.combat_audio.cue_counts.get(&"unsealed_hurt", 0) == 3)
	assert(app.combat_audio.cue_counts.get(&"vessel_hurt", 0) == 3)
	for index in 2:
		target = app.combat.enemies[index]
		app.combat.enemies[1 - index].position = Vector3(9, 0.87, 3)
		target.position = Vector3(0, 0.87, 10)
		target.health = 1
		await physics_frame
		await physics_frame
		app.player.get_node("Camera3D").look_at(target.global_position + Vector3(0, 0.3, 0))
		app.combat.recoil_remaining = 0
		app.combat.currentweapon = &"pistol"
		app.combat.weapon_phase = &"idle"
		app.combat.cooldown = 0
		assert(app.combat.try_fire())
		assert(target.dead)
		var death_key := StringName(str(target.definition.identifier) + "_death")
		assert(app.combat_audio.cue_counts.get(death_key, 0) == 1)
		await wait_audio(2.2)
	app.combat.receive_player_damage(1000, "fixture", app.player.global_position)
	await process_frame
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	app._input(escape)
	assert(paused, "Escape resumed a dead player")
	var old_audio: Node3D = app.combat_audio
	app.restart_combat()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	assert(not is_instance_valid(old_audio), "Restart retained previous audio owner")
	assert(app.combat_audio.voices.is_empty())
	assert(not app.menu_music.playing and app.combat_audio.music_player.playing)
	app.combat.set_physics_process(false)
	for enemy in app.combat.enemies: enemy.set_physics_process(false)
	await wait_audio(0.25)
	app.return_to_title()
	assert(app.menu_music.playing and not app.combat_audio.music_player.playing)
	assert(app.combat_audio.voices.is_empty())
	await wait_audio(0.5)
	var nonzero := false
	var different_channels := false
	var data := PackedByteArray()
	data.resize(stereo.size() * 4)
	for i in stereo.size():
		var frame := stereo[i]
		if frame.length_squared() > 0.00000001: nonzero = true
		if absf(frame.x - frame.y) > 0.0001: different_channels = true
		data.encode_s16(i * 4, int(clampf(frame.x, -1, 1) * 32767))
		data.encode_s16(i * 4 + 2, int(clampf(frame.y, -1, 1) * 32767))
	assert(nonzero and different_channels, "Capture must contain actual non-silent stereo game mix")
	var recording := AudioStreamWAV.new()
	recording.format = AudioStreamWAV.FORMAT_16_BITS
	recording.stereo = true
	recording.mix_rate = int(AudioServer.get_mix_rate())
	recording.data = data
	assert(recording.save_to_wav(capture_path) == OK)
	AudioServer.remove_bus_effect(0, effect_index)
	print("SOUND_SCENE_OK: actual physics contacts dispatch six weapon/material cues; hurt separate; Abelian title only; level pause drift=", pause_drift, "; mute advances; retry replaces audio owner; title restarts menu; captured ", stereo.size(), " actual stereo bus frames. No subjective listening approval claimed.")
	app.menu_music.stop()
	app.menu_music.stream = null
	app.combat_audio.stop_all()
	app.free()
	app = null
	capture = null
	recording = null
	# Let the audio mix thread retire stopped playback before process exit.
	paused = false
	await create_timer(0.25, true).timeout
	quit()
