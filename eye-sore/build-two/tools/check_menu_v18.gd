extends SceneTree
## Focused title preview, playlist and gameplay hand-off contract.

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var requested_level := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--campaign-level="):
			requested_level = argument.trim_prefix("--campaign-level=")
	var app: Control = preload("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	if not requested_level.is_empty(): assert(String(app.campaign.current_level().id) == requested_level)
	assert(paused and app.menu_flythrough.active and app.menu_flythrough.camera.current)
	assert(app.menu_flythrough.shots.size() >= 1)
	var preview_start: Vector3 = app.menu_flythrough.camera.position
	await create_timer(1.2, true).timeout
	assert(paused and app.menu_flythrough.camera.position.distance_to(preview_start) > 0.05)
	assert(not app.title_art.visible and not app.weapon_image.visible)
	assert(app.menu_music.playing and app.menu_music_entries.size() == 10)
	var hidden := 0
	for enemy in app.combat.enemies:
		if not enemy.visible: hidden += 1
	assert(hidden == app.combat.enemies.size() and hidden > 0)
	var original_index: int = app.menu_music_index
	(app.menu_music_controls.get_child(2) as Button).pressed.emit()
	assert(app.menu_music_index == (original_index + 1) % 10)
	assert(app.menu_music.playing)
	assert(app.menu_music.stream is AudioStreamOggVorbis)
	(app.menu_music_controls.get_child(0) as Button).pressed.emit()
	assert(app.menu_music_index == original_index)
	app.enter_combat()
	await process_frame
	assert(not paused and not app.menu_flythrough.active and app.player.camera.current)
	assert(not app.menu_music.playing and app.combat_audio.music_player.playing)
	for enemy in app.combat.enemies: assert(enemy.visible)
	app.return_to_title()
	await process_frame
	assert(paused and app.menu_flythrough.active and app.menu_flythrough.camera.current)
	assert(app.menu_music.playing and not app.combat_audio.music_player.playing)
	for enemy in app.combat.enemies: assert(not enemy.visible)
	print("MENU_V18_OK initial_level=", requested_level, " title_level=", app.current_level_label(), " shots=", app.menu_flythrough.shots.size(),
		" enemies_hidden=", app.combat.enemies.size(), " cues=", app.menu_music_entries.size())
	app.menu_flythrough.stop()
	await app.quit_game()
