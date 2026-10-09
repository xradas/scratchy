extends SceneTree
var evidence_dir := "res://verification/level"
## Main-menu ownership, world pause, visited-map drawing and complete scene replacement.
func prepare_evidence_dir() -> bool:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-dir="):
			evidence_dir = argument.trim_prefix("--evidence-dir=")
	if evidence_dir.is_empty():
		push_error("Evidence directory cannot be empty")
		quit(1)
		return false
	var error := DirAccess.make_dir_recursive_absolute(evidence_dir)
	if error != OK:
		push_error("Cannot create evidence directory %s: %s" % [evidence_dir, error_string(error)])
		quit(1)
		return false
	return true

func _initialize() -> void:
	if not prepare_evidence_dir(): return
	call_deferred("run")

func run() -> void:
	if DisplayServer.get_name() != "headless": root.set_flag(Window.FLAG_NO_FOCUS,true)
	var app: Control = preload("res://scenes/main.tscn").instantiate(); root.add_child(app)
	var initial: Vector3 = app.combat.enemies[0].position
	await create_timer(.2,true).timeout
	assert(app.combat.enemies[0].position == initial and paused)
	app.enter_combat(); Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await create_timer(.2,true).timeout
	assert(app.combat.enemies[0].position != initial)
	app.set_paused(true)
	var positions: Array[Vector3] = []
	for enemy in app.combat.enemies: positions.append(enemy.position)
	var health: float = app.combat.health
	await create_timer(.25,true).timeout
	for i in positions.size(): assert(app.combat.enemies[i].position == positions[i])
	assert(app.combat.health == health)
	app.set_paused(false); Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var tab := InputEventKey.new(); tab.keycode = KEY_TAB; tab.pressed = true
	app._input(tab); assert(app.automap.visible)
	await process_frame; await process_frame
	assert(app.world.get_level_state().map_rooms.size() == 1)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var path := evidence_dir.path_join("visited-map.png")
		var error := root.get_texture().get_image().save_png(path)
		if error != OK:
			push_error("Cannot write evidence file %s: %s" % [path, error_string(error)])
			quit(1)
			return
	var old_world: Node3D = app.world; var old_audio: Node3D = app.combat_audio
	app.world.has_key = true; app.world.get_node("Door_Rear").activate(true)
	app.combat.ammo_shotgun = 0; app.combat.health = 1
	app.restart_combat(); Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	assert(not is_instance_valid(old_world) and not is_instance_valid(old_audio))
	assert(not app.world.has_key and not app.world.get_node("Door_Rear").opened)
	assert(app.combat.health == 100 and app.combat.ammo_shotgun == 12)
	assert(app.combat.kills == 0 and app.combat.enemies.size() == 11)
	assert(app.combat_audio.voices.is_empty() and not app.automap.visible)
	app.return_to_title()
	assert(paused and not app.started and app.menu_music.playing)
	print("WARD_SESSION_OK: title/world ownership; actual enemies freeze under pause; visited-only map; retry replaces whole scene/audio and restores gates/pickups/ammo; title restarts Abelian")
	await app.quit_game()
