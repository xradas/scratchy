extends SceneTree
## Integrated combat/navigation smoke: normal health, ammo, enemy AI and authoritative shots.
var app: Control
var failures: Array[String] = []
var records: Array[Dictionary] = []
var ticks := 0
var capture: AudioEffectCapture
var stereo := PackedVector2Array()
var effect_index: int
var evidence_dir := "res://verification/level"

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-dir="): evidence_dir = argument.trim_prefix("--evidence-dir=")
	call_deferred("run")

func key(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_W
	event.keycode = KEY_W
	event.pressed = pressed
	Input.parse_input_event(event)

func tick(destination: Vector3) -> void:
	if app.combat.dead: return
	var direction: Vector3 = destination - app.player.global_position
	app.player.rotation.y = atan2(-direction.x, -direction.z)
	var target: CharacterBody3D
	var closest := 19.0
	for enemy in app.combat.enemies:
		if enemy.dead: continue
		var distance: float = enemy.global_position.distance_to(app.player.global_position)
		if distance < closest and enemy.can_see_player():
			target = enemy; closest = distance
	key(target == null and Vector2(direction.x, direction.z).length() > 0.3)
	if target != null:
		app.player.camera.look_at(target.global_position + Vector3(0, .28, 0))
		var weapon: StringName = &"shotgun" if closest < 10.0 and app.combat.ammo_shotgun > 0 else &"pistol"
		if app.combat.ammo_pistol == 0 and app.combat.ammo_shotgun > 0: weapon = &"shotgun"
		if app.combat.ammo_pistol == 0 and app.combat.ammo_shotgun == 0:
			weapon = &"melee"; key(closest > 1.8)
		if app.combat.currentweapon != weapon: app.combat.select_weapon(weapon)
		else: app.combat.try_fire()
	else: app.player.camera.rotation = Vector3.ZERO
	await physics_frame
	ticks += 1
	if capture: stereo.append_array(capture.get_buffer(capture.get_frames_available()))

func walk(point: Vector3, label: String) -> bool:
	var started_tick := ticks
	while Vector2(app.player.position.x - point.x, app.player.position.z - point.z).length() > .3:
		if app.combat.dead or ticks - started_tick > 1200:
			failures.append(label + (": player died" if app.combat.dead else ": traversal stalled"))
			key(false)
			return false
		await tick(point)
	key(false)
	for i in 10:
		await physics_frame
		stereo.append_array(capture.get_buffer(capture.get_frames_available()))
	records.append({"segment":label,"ticks":ticks-started_tick,"position":app.player.position,"health":app.combat.health,"armor":app.combat.armor,"shells":app.combat.ammo_shotgun,"pistol":app.combat.ammo_pistol,"kills":app.combat.kills})
	return true

func photo(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(evidence_dir + "/playtest-" + label + ".png")

func use_door(name: String) -> bool:
	if not app.world.interact(): failures.append(name + ": use rejected"); return false
	var door: Node3D = app.world.get_node(name)
	for i in 240:
		if door.is_open(): return true
		await tick(app.player.position)
	failures.append(name + ": opening stalled")
	return false

func route() -> void:
	for point in [Vector3(0,0,5.5), Vector3(10,0,5.5), Vector3(19,0,5.5), Vector3(18,0,2), Vector3(18,0,-2), Vector3(20,0,-6.1)]:
		if not await walk(point, "Bio route " + str(point)): return
	if not app.world.has_key: failures.append("Key missing after physical approach"); return
	await photo("key")
	if not await walk(Vector3(19,0,-3), "Shortcut approach"): return
	if not await walk(Vector3(12,0,-2.5), "Shortcut control"): return
	if not await use_door("Door_Shortcut"): return
	if not await walk(Vector3(0,0,-3), "Shortcut return"): return
	if not await walk(Vector3(0,1.5,-14), "Containment stairs"): return
	if not await use_door("Door_Rear"): return
	if not await walk(Vector3(0,1.5,-20), "Rear lab"): return
	if not await walk(Vector3(-4.5,1.5,-26.5), "Lift boarding"): return
	key(false)
	if not app.world.interact(): failures.append("Lift use rejected"); return
	for i in 240:
		if not app.world.get_node("Lift_Exit").moving: break
		await physics_frame
		stereo.append_array(capture.get_buffer(capture.get_frames_available()))
	await photo("gallery")
	if not await walk(app.world.exit_marker.global_position, "Discharge exit"): return
	if not app.world.interact(): failures.append("Exit use rejected")
	await process_frame
	if not app.level_complete or not paused: failures.append("Completion did not pause/show end state")
	await photo("completed")

func run() -> void:
	if DisplayServer.get_name() != "headless": root.set_flag(Window.FLAG_NO_FOCUS, true)
	effect_index = AudioServer.get_bus_effect_count(0)
	capture = AudioEffectCapture.new(); capture.buffer_length = 3
	AudioServer.add_bus_effect(0, capture)
	app = preload("res://scenes/main.tscn").instantiate(); root.add_child(app)
	var initial: Vector3 = app.combat.enemies[0].position
	await create_timer(.25, true).timeout
	assert(app.combat.enemies[0].position == initial, "Title must freeze world")
	app.enter_combat(); Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await route()
	key(false)
	var report := {"failures":failures,"segments":records,"shots":app.combat.shot_counter,"elapsed_physics_seconds":ticks/60.0,"completed":app.level_complete,"health":app.combat.health,"kills":app.combat.kills,"secret_used":app.world.secret_found,"scope":"Actual main scene, authored spawns, normal AI/health/ammo, authoritative hitscan; automated aiming, no secret supplies or cheats. Timing is bot traversal, not human level-duration acceptance."}
	var file := FileAccess.open(evidence_dir + "/integrated-playtest.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  ")); file.close()
	var data := PackedByteArray(); data.resize(stereo.size() * 4)
	for i in stereo.size():
		data.encode_s16(i*4, int(clampf(stereo[i].x,-1,1)*32767))
		data.encode_s16(i*4+2, int(clampf(stereo[i].y,-1,1)*32767))
	var wav := AudioStreamWAV.new(); wav.format = AudioStreamWAV.FORMAT_16_BITS; wav.stereo = true
	wav.mix_rate = int(AudioServer.get_mix_rate()); wav.data = data
	wav.save_to_wav(evidence_dir + "/integrated-game-mix.wav")
	AudioServer.remove_bus_effect(0,effect_index)
	print("INTEGRATED_WARD_PLAYTEST ", JSON.stringify(report))
	await app.quit_game()
