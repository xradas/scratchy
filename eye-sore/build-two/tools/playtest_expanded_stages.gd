extends SceneTree
## Real player physics, ordinary AI, normal ammunition and authoritative weapon rays.
## Routes are coordinator-authored floor coordinates; no teleport or secret supplies.
var app: Control
var main_mode := false
var capture_mode := false
var capture: AudioEffectCapture
var stereo := PackedVector2Array()
var effect_index := -1
var evidence_dir := "res://resources/stages"
var world: Node3D
var player: CharacterBody3D
var combat: Node3D
var route: Dictionary
var failures: Array[String] = []
var records: Array[Dictionary] = []
var ticks := 0
var stage_id := "pale_ward"
var global_start := 0
var initial_shots := 0
var avoid_side := 1
func _initialize() -> void:
	main_mode = "--main" in OS.get_cmdline_user_args()
	capture_mode = "--capture" in OS.get_cmdline_user_args()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--stage="): stage_id = argument.trim_prefix("--stage=")
		if argument.begins_with("--evidence-dir="): evidence_dir = argument.trim_prefix("--evidence-dir=")
	call_deferred("run")
func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new(); event.physical_keycode = code; event.keycode = code; event.pressed = pressed; Input.parse_input_event(event)
func stop() -> void:
	for code in [KEY_W,KEY_S,KEY_A,KEY_D]: key(code, false)
func vector(a: Array, elevation := .87) -> Vector3: return Vector3(a[0],a[1]+elevation,a[2])
func horizontal(a: Vector3,b: Vector3) -> float: return Vector2(a.x-b.x,a.z-b.z).length()
func closest_enemy() -> CharacterBody3D:
	var target: CharacterBody3D; var closest := 38.0
	for enemy in combat.enemies:
		if enemy.dead: continue
		var distance: float = enemy.global_position.distance_to(player.global_position)
		if distance < closest and enemy.can_see_player(): target = enemy; closest = distance
	return target
func tick(destination: Vector3, fight := true) -> void:
	stop()
	var direction := destination - player.global_position
	var target := closest_enemy() if fight else null
	var progress: float = Vector2(direction.x,direction.z).length()
	if target != null:
		var offset: Vector3 = target.global_position - player.global_position
		player.rotation.y = atan2(-offset.x,-offset.z)
		player.camera.look_at(target.global_position + Vector3(0,.28,0))
		var distance := horizontal(target.global_position,player.global_position)
		var weapon: StringName = &"shotgun" if distance < 17 and combat.ammo_shotgun > 0 else &"pistol"
		if combat.ammo_pistol == 0 and combat.ammo_shotgun > 0: weapon = &"shotgun"
		if combat.ammo_shotgun == 0 and combat.ammo_pistol == 0: weapon = &"melee"
		if weapon == &"melee": key(KEY_W,distance > 1.5)
		elif not target.definition.ranged and distance < 3.2:
			var backwards: Vector3 = player.global_basis.z * .6
			if not player.test_move(player.global_transform,backwards): key(KEY_S,true)
		elif target.definition.ranged and distance < 22:
			var lateral: Vector3 = player.global_basis.x * avoid_side
			if player.test_move(player.global_transform,lateral * .8): avoid_side *= -1
			key(KEY_D if avoid_side > 0 else KEY_A,true)
		if combat.currentweapon != weapon: combat.select_weapon(weapon)
		else: combat.try_fire()
	else:
		player.rotation.y = atan2(-direction.x,-direction.z); player.camera.rotation = Vector3.ZERO
		key(KEY_W,progress > .23)
	await physics_frame
	ticks += 1
	if capture != null: stereo.append_array(capture.get_buffer(capture.get_frames_available()))
func walk(point: Vector3,label: String) -> bool:
	var start := ticks
	while horizontal(player.global_position,point) > .28:
		if combat.dead or ticks-start > 3600:
			failures.append(label + (": player died" if combat.dead else ": traversal stalled at "+str(player.global_position))); stop(); return false
		await tick(point)
	stop()
	for k in 5: await physics_frame
	world.update_player(player,combat)
	records.append({"segment":label,"ticks":ticks-start,"position":player.global_position,"health":combat.health,"armor":combat.armor,"pistol":combat.ammo_pistol,"shells":combat.ammo_shotgun,"kills":combat.kills})
	return true
func room_center(id: String) -> Vector3: return vector(route.rooms[id].center)
func clear_arena(id: String) -> bool:
	var start := ticks
	while int(world.arena_remaining.get(id,0)) > 0:
		if combat.dead or ticks-start > 3600: failures.append(id+": arena clear failed"); return false
		var target := closest_enemy()
		var destination := room_center(id)
		if target == null:
			for enemy in combat.enemies:
				if not enemy.dead and String(enemy.get_meta("arena_id","")) == id: destination = enemy.global_position; break
		await tick(destination)
	stop(); return true
func use(name: String) -> bool:
	stop(); world.update_player(player,combat)
	var accepted := false
	if main_mode:
		var selected: Node3D = world.nearest_mechanism()
		key(KEY_E,true); await process_frame; key(KEY_E,false); await process_frame
		if selected != null:
			if selected.has_meta("stage_exit"): accepted = world.finished
			elif selected.has_meta("stage_button"): accepted = world.flags.get(String(selected.get_meta("stage_button")),false)
			elif selected.has_meta("ward_lift"): accepted = selected.moving
			else: accepted = selected.opened
	else: accepted = world.try_use(player)
	if not accepted: failures.append(name+": physical use rejected · "+world.prompt); return false
	var mechanism: Node3D = world.get_node_or_null(name)
	if mechanism != null and mechanism.has_method("is_open"):
		for k in 240:
			if mechanism.is_open(): return true
			await tick(player.global_position)
		failures.append(name+": gate stalled"); return false
	return true
func button(id: String) -> bool:
	var node: Node3D = world.get_node("Button_"+id)
	if not await walk(node.global_position+Vector3(0,-.18,1.25),"Control "+id): return false
	var accepted := await use("Button_"+id)
	if accepted: await photo(id)
	return accepted
func connect_rooms(a: String,b: String) -> bool:
	if not await walk(room_center(a),"Return centre "+a): return false
	var link: Dictionary
	for portal in route.portals:
		if portal.from == a and portal.to == b or portal.from == b and portal.to == a: link = portal; break
	if link.is_empty(): failures.append("No authored portal "+a+"→"+b); return false
	var start := vector(link.start if link.from==a else link.end)
	var end := vector(link.end if link.from==a else link.start)
	if not await walk(start,"Threshold "+a+"→"+b): return false
	if link.door != null:
		var door: Node3D = world.get_node(String(link.door))
		if not door.is_open():
			var middle: Vector3 = door.get_parent().to_global(door.origin)
			middle.y = maxf(start.y,end.y) if String(link.gate)=="entry_gate" else vector(link.middle).y
			var toward := (end-start).normalized(); toward.y = 0
			if not await walk(middle-toward*1.45,"Gate "+String(link.gate)): return false
			if not await use(String(link.door)): return false
	if not await walk(end,"Portal "+a+"→"+b): return false
	return await walk(room_center(b),"Room "+b)
func key_room(room: String,key_id: String) -> bool:
	var item: Node3D = world.get_node("Key_"+key_id)
	if not await walk(item.global_position,"Acquire "+key_id): return false
	if not world.flags.get(key_id,false): failures.append(key_id+": collection failed"); return false
	await photo(key_id)
	return true
func ride_lift() -> bool:
	var lift: AnimatableBody3D = world.get_node("Lift_Observation")
	var lower: Vector3 = lift.global_position+Vector3(0,1.02,0)
	# Optional observation lift is a physics shaft; it cannot bypass final combat.
	if not await walk(lower,"Lift boarding"): return false
	if not await use("Lift_Observation"): return false
	for k in 250:
		await physics_frame
		if capture != null: stereo.append_array(capture.get_buffer(capture.get_frames_available()))
		if not lift.moving: break
	await photo("lift-upper")
	if lift.moving or player.global_position.y < room_center("observation").y-.2: failures.append("Lift did not physically carry passenger upward"); return false
	if not await walk(room_center("observation"),"Upper observation"): return false
	if not await walk(lift.global_position+Vector3(0,1.02,0),"Lift return boarding"): return false
	if not await use("Lift_Observation"): return false
	for k in 250:
		await physics_frame
		if capture != null: stereo.append_array(capture.get_buffer(capture.get_frames_available()))
		if not lift.moving: break
	return await walk(room_center("final_arena"),"Return from lift")
func route_run() -> void:
	# Main route collects only authored required-room supply clusters.
	for pair in [["entry","service"],["service","arena_one"]]:
		if not await connect_rooms(pair[0],pair[1]): return
	if not await clear_arena("arena_one") or not await button("breaker"): return
	for pair in [["arena_one","key_wing"],["key_wing","key_console"]]:
		if not await connect_rooms(pair[0],pair[1]): return
	if not await key_room("key_console","brass_key"): return
	for pair in [["key_console","key_wing"],["key_wing","return_store"],["return_store","service"],["service","arena_one"],["arena_one","spine"],["spine","arena_two"]]:
		if not await connect_rooms(pair[0],pair[1]): return
	if not await clear_arena("arena_two") or not await button("release"): return
	for pair in [["arena_two","red_wing"],["red_wing","red_console"]]:
		if not await connect_rooms(pair[0],pair[1]): return
	if not await key_room("red_console","red_key"): return
	for pair in [["red_console","red_wing"],["red_wing","armory"],["armory","spine"],["spine","arena_two"],["arena_two","final_arena"]]:
		if not await connect_rooms(pair[0],pair[1]): return
	if not await clear_arena("final_arena") or not await button("exit_control"): return
	if not await ride_lift(): return
	if not await connect_rooms("final_arena","exit_gallery"): return
	var exit: Node3D = world.get_node("ExitControl")
	if not await walk(exit.global_position+Vector3(0,-.18,1.3),"Enabled exit"): return
	if not await use("ExitControl"): return
	if not world.finished: failures.append("Completion signal absent")
	if main_mode and (not app.level_complete or not paused): failures.append("Main completion/menu pause did not occur")
	await photo("completed")
func configure_art() -> void:
	var art: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/combat_art.json"))
	for enemy in combat.enemies:
		var kind := String(enemy.definition.identifier)
		if not art.get("enemies",{}).has(kind): continue
		var data: Dictionary = art.enemies[kind]
		if data.has("rig_scene"): enemy.configure_live_visual(data.rig_scene); continue
		var clips := {}
		for clip in data.clips: clips[clip] = Vector2i(data.clips[clip][0],data.clips[clip][1])
		var pivot: Array = data.get("foot_pivot",[-1,-1])
		enemy.configure_sprite_sheet(data.file,data.columns,data.directions,clips,data.get("pixel_size",.015),Vector2(pivot[0],pivot[1]),data.get("sprite_options",{}))
func run() -> void:
	if DisplayServer.get_name() != "headless": root.set_flag(Window.FLAG_NO_FOCUS, true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence_dir))
	route = JSON.parse_string(FileAccess.get_file_as_string("res://resources/stages/"+stage_id+"-route.json"))
	var contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/expansion-v1/contract.json"))
	for stage in contract.stages:
		if stage.id == stage_id: world = load(stage.scene).instantiate(); break
	if main_mode:
		# Main reads the same --stage argument and wires menu, HUD, music and reset.
		world.free()
		app = load("res://scenes/main.tscn").instantiate(); root.add_child(app)
		world = app.world; player = app.player; combat = app.combat
		var initial: Vector3 = combat.enemies[0].position
		for frame in 6: await process_frame
		if combat.enemies[0].position != initial: failures.append("Title menu failed to freeze combat")
		app.enter_combat()
	else:
		root.add_child(world); player = world.get_node("Player")
		combat = load("res://scripts/combat.gd").new(); world.add_child(combat); combat.setup(world,player)
		configure_art(); world.setup(combat,player)
	if capture_mode and main_mode:
		# Capture full Master output without persisting any user settings change.
		AudioServer.set_bus_mute(0, false)
		effect_index = AudioServer.get_bus_effect_count(0)
		capture = AudioEffectCapture.new(); capture.buffer_length = 3; AudioServer.add_bus_effect(0,capture)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await physics_frame
	await photo("entry")
	global_start = Engine.get_physics_frames()
	await route_run(); stop()
	var report := {"stage":stage_id,"main_integration":main_mode,"failures":failures,"completed":world.finished,"health":combat.health,"armor":combat.armor,"pistol":combat.ammo_pistol,"shells":combat.ammo_shotgun,"kills":combat.kills,"total":combat.total_enemies,"shots":combat.shot_counter,"physics_seconds":float(Engine.get_physics_frames()-global_start)/Engine.physics_ticks_per_second,"bot_control_seconds":ticks/60.0,"secret_used":world.secret_found,"shortcuts":world.shortcuts.size(),"segments":records,"scope":"Authored expanded stage, real CharacterBody player/AI physics, original normal health/ammo, authoritative weapon rays; automated aim/strafe, no teleport, secret supplies or cheats. Bot time is not human duration."}
	var output := FileAccess.open(evidence_dir+"/"+stage_id+"-playtest.json",FileAccess.WRITE);output.store_string(JSON.stringify(report,"  "))
	if capture_mode and main_mode: save_mix()
	print("EXPANDED_STAGE_PLAYTEST ",JSON.stringify(report))
	if main_mode:
		# --fixed-fps advances physics timers faster than the audio mix thread.
		# Retire playback for bounded real wall time, then use main's lifecycle.
		if is_instance_valid(app.menu_music):
			app.menu_music.stream_paused = false; app.menu_music.stop(); app.menu_music.stream = null
		if is_instance_valid(app.combat_audio): app.combat_audio.stop_all()
		var retire_until := Time.get_ticks_msec() + 300
		while Time.get_ticks_msec() < retire_until: await process_frame
		await app.quit_game()
		if not failures.is_empty(): quit(1)
	else: quit(0 if failures.is_empty() and world.finished else 1)

func photo(label: String) -> void:
	if not capture_mode or DisplayServer.get_name() == "headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(evidence_dir+"/"+stage_id+"-"+label+".png")
func save_mix() -> void:
	stereo.append_array(capture.get_buffer(capture.get_frames_available()))
	var data := PackedByteArray(); data.resize(stereo.size()*4)
	for index in stereo.size():
		data.encode_s16(index*4,int(clampf(stereo[index].x,-1,1)*32767))
		data.encode_s16(index*4+2,int(clampf(stereo[index].y,-1,1)*32767))
	var wav := AudioStreamWAV.new(); wav.format = AudioStreamWAV.FORMAT_16_BITS; wav.stereo = true; wav.mix_rate = int(AudioServer.get_mix_rate()); wav.data = data
	wav.save_to_wav(evidence_dir+"/"+stage_id+"-game-mix.wav")
	AudioServer.remove_bus_effect(0,effect_index)
