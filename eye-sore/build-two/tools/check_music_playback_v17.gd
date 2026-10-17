extends SceneTree
## Capture the actual stereo Master bus on the menu and in one selected level.

var capture: AudioEffectCapture
var frames := PackedVector2Array()
var level_id := "pale_ward_01"

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--campaign-level="):
			level_id = argument.trim_prefix("--campaign-level=")
	call_deferred("run")

func collect(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		await create_timer(0.05, true).timeout
		elapsed += 0.05
		frames.append_array(capture.get_buffer(capture.get_frames_available()))

func run() -> void:
	var effect_index := AudioServer.get_bus_effect_count(0)
	capture = AudioEffectCapture.new()
	capture.buffer_length = 3.0
	AudioServer.add_bus_effect(0, capture)
	var app: Control = preload("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	var expected := "res://assets/audio/music/original-v17/%s.ogg" % level_id
	assert(app.selected_level_music_path() == expected)
	assert(app.menu_music.playing)
	await collect(1.0)
	app.enter_combat()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	assert(not app.menu_music.playing and app.combat_audio.music_player.playing)
	await collect(2.5)
	var output := "res://verification/music-v17/game-mix-%s.wav" % level_id
	var bytes := PackedByteArray()
	bytes.resize(frames.size() * 4)
	var left_energy := 0.0
	var right_energy := 0.0
	var difference_energy := 0.0
	for i in frames.size():
		var frame := frames[i]
		bytes.encode_s16(i * 4, int(clampf(frame.x, -1.0, 1.0) * 32767.0))
		bytes.encode_s16(i * 4 + 2, int(clampf(frame.y, -1.0, 1.0) * 32767.0))
		left_energy += frame.x * frame.x
		right_energy += frame.y * frame.y
		difference_energy += (frame.x - frame.y) * (frame.x - frame.y)
	assert(frames.size() > 48000)
	assert(left_energy > 0.001 and right_energy > 0.001 and difference_energy > 0.0001)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = true
	wav.mix_rate = int(AudioServer.get_mix_rate())
	wav.data = bytes
	wav.save_to_wav(output)
	AudioServer.remove_bus_effect(0, effect_index)
	print("MUSIC_PLAYBACK_V17_OK level=", level_id, " path=", expected,
		" stereo_frames=", frames.size(), " wav=", output)
	app.queue_free()
	quit()
