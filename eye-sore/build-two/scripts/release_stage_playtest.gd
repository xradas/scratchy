extends Node
## Opt-in exported-package acceptance fixture. Ordinary play never instantiates this.
## Uses the real Main input, CharacterBody physics, AI and authoritative weapon rays.
var app: Control
var world: Node3D
var player: CharacterBody3D
var combat: Node3D
var route: Dictionary = {}
var failures: Array[String] = []
var records: Array[Dictionary] = []
var interactions: Array[Dictionary] = []
var ticks := 0
var stage_id := ""
var global_start := 0
var avoid_side := 1
var lift_returned := false
var configured := false
var report_dir := ""
var package_dir := ""
var baseline: Dictionary = {}

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func setup(application: Control) -> void:
	if configured: return
	configured = true
	app = application
	app.automated_input = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	call_deferred("run")

func require(condition: bool, message: String) -> bool:
	# assert() is removed in release templates; acceptance must always execute.
	if not condition:
		failures.append(message)
		push_error("RELEASE_STAGE_ROUTE: " + message)
	return condition

func run() -> void:
	stage_id = String(app.stage_id)
	world = app.world; player = app.player; combat = app.combat
	report_dir = OS.get_user_data_dir().path_join("release-route-reports")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--release-report-dir="):
			report_dir = argument.trim_prefix("--release-report-dir=").simplify_path()
	if not require(report_dir.is_absolute_path() and not report_dir.begins_with("res://"), "Report directory must be an absolute filesystem path"):
		report_dir = OS.get_user_data_dir().path_join("release-route-reports")
		await finish(); return
	# res:// globalization is editor-only; embedded export paths need not map
	# to the directory containing the executable/PCK.
	package_dir = (ProjectSettings.globalize_path("res://") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir()).simplify_path().trim_suffix("/")
	if not require(package_dir.is_absolute_path() and not package_dir.begins_with("res://") and package_dir.length() > 1, "Could not resolve a meaningful absolute project/package directory"):
		report_dir = OS.get_user_data_dir().path_join("release-route-reports")
		await finish(); return
	if not require(report_dir != package_dir and not report_dir.begins_with(package_dir + "/"), "Receipt directory must be outside the project/package directory"):
		report_dir = OS.get_user_data_dir().path_join("release-route-reports")
		await finish(); return
	var route_path := "res://resources/stages/" + stage_id + "-route.json"
	if not require(not app.selected_stage().is_empty() and FileAccess.file_exists(route_path), "Selected runtime stage/route resource is unavailable"):
		await finish(); return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(route_path))
	if not require(parsed is Dictionary and String(parsed.get("id", "")) == stage_id and parsed.has("rooms") and parsed.has("portals"), "Runtime route JSON is invalid"):
		await finish(); return
	route = parsed
	baseline = {"health":combat.health,"armor":combat.armor,"pistol":combat.ammo_pistol,"shells":combat.ammo_shotgun,"kills":combat.kills,"total":combat.total_enemies,"shots":combat.shot_counter}
	require(combat.health == 100.0 and combat.armor == 50.0 and combat.ammo_pistol == 36 and combat.ammo_shotgun == 12 and combat.kills == 0 and combat.shot_counter == 0 and combat.total_enemies == 42, "Initial normal health/ammo/roster baseline changed")
	require(world.flags.is_empty() and world.shortcuts.is_empty() and not world.secret_found and not world.finished, "Initial stage progression was already modified")
	require(get_tree().paused and not app.started, "Main title/menu was not initially paused")
	var initial: Vector3 = combat.enemies[0].position
	for frame in 6: await get_tree().process_frame
	require(combat.enemies[0].position == initial, "Title menu failed to freeze combat")
	if failures.is_empty():
		app.enter_combat()
		require(not get_tree().paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Automated play failed to enter real combat with visible pointer")
		await get_tree().physics_frame
		global_start = Engine.get_physics_frames()
		await route_run()
		require(world.finished and app.level_complete and get_tree().paused, "Completed route did not reach Main's paused completion menu")
		require(not combat.dead and combat.health > 0.0, "Player did not survive the ordinary route")
		require(not world.secret_found and world.secrets.is_empty(), "Route used secret supplies")
		require(world.shortcuts.size() == 2 and world.shortcuts.has("shortcut_one") and world.shortcuts.has("shortcut_two"), "Both manual-route shortcuts were not opened")
		require(lift_returned, "Observation lift round trip did not complete")
		for flag in ["breaker","power","brass_key","red_key","release","clear_arena_one","clear_arena_two","clear_final_arena","exit_control","exit"]:
			require(bool(world.flags.get(flag,false)), "Required progression flag missing: " + flag)
		for arena in ["arena_one","arena_two","final_arena"]:
			require(int(world.arena_remaining.get(arena,-1)) == 0, "Arena remained uncleared: " + arena)
		require(combat.kills == 39 and combat.total_enemies == 42 and combat.shot_counter > 0, "Ordinary route kills/authoritative shots did not match the required 39 of 42 roster")
	await finish()

func finish() -> void:
	stop(); key(KEY_E,false)
	var report := {"stage":stage_id,"executable":OS.get_executable_path(),"project_package_dir":package_dir,"working_directory":OS.get_environment("PWD"),"editor_feature":OS.has_feature("editor"),"main_integration":true,"release_checks_enabled":true,"baseline":baseline,"failures":failures,"completed":world.finished,"completion_menu_paused":app.level_complete and get_tree().paused,"health":combat.health,"armor":combat.armor,"pistol":combat.ammo_pistol,"shells":combat.ammo_shotgun,"kills":combat.kills,"total":combat.total_enemies,"shots":combat.shot_counter,"physics_seconds":float(Engine.get_physics_frames()-global_start)/Engine.physics_ticks_per_second if global_start > 0 else 0.0,"bot_control_seconds":float(ticks)/Engine.physics_ticks_per_second,"secret_used":world.secret_found,"shortcuts":world.shortcuts.keys(),"flags":world.flags.duplicate(),"lift_round_trip":lift_returned,"interactions":interactions,"segments":records,"scope":"Export-safe Main route: real CharacterBody player/AI physics, ordinary baseline health/ammo, authoritative weapon rays; automated aim/strafe and real E input, no teleport, secret supplies or cheats. Bot time is not human duration."}
	var directory_error := DirAccess.make_dir_recursive_absolute(report_dir)
	require(directory_error == OK, "Could not create receipt directory: " + report_dir)
	var receipt_path := report_dir.path_join(stage_id + "-release-route.json")
	var output := FileAccess.open(receipt_path,FileAccess.WRITE)
	if require(output != null, "Could not write receipt: " + receipt_path):
		report["failures"] = failures.duplicate()
		output.store_string(JSON.stringify(report,"  "))
		output.close()
	print("RELEASE_STAGE_ROUTE_OK " if failures.is_empty() else "RELEASE_STAGE_ROUTE_FAILED ", JSON.stringify({"stage":stage_id,"receipt":receipt_path,"failures":failures,"completed":world.finished,"kills":combat.kills,"shots":combat.shot_counter}))
	# Fixed-fps timers can outrun the audio mix thread; retire playback in wall time.
	if is_instance_valid(app.menu_music):
		app.menu_music.stream_paused = false; app.menu_music.stop(); app.menu_music.stream = null
	if is_instance_valid(app.combat_audio): app.combat_audio.stop_all()
	var retire_until := Time.get_ticks_msec() + 300
	while Time.get_ticks_msec() < retire_until: await get_tree().process_frame
	await app.quit_game()
	if not failures.is_empty(): get_tree().quit(1)

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
	await get_tree().physics_frame
	ticks += 1
func walk(point: Vector3,label: String) -> bool:
	var start := ticks
	while horizontal(player.global_position,point) > .28:
		if combat.dead or ticks-start > 3600:
			failures.append(label + (": player died" if combat.dead else ": traversal stalled at "+str(player.global_position))); stop(); return false
		await tick(point)
	stop()
	for k in 5: await get_tree().physics_frame
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
	var selected: Node3D = world.nearest_mechanism()
	if not require(selected == world.get_node_or_null(name), name + ": expected mechanism was not selected by physical proximity/ray"): return false
	key(KEY_E,true); await get_tree().process_frame; key(KEY_E,false); await get_tree().process_frame
	if selected != null:
		if selected.has_meta("stage_exit"): accepted = world.finished
		elif selected.has_meta("stage_button"): accepted = bool(world.flags.get(String(selected.get_meta("stage_button")),false))
		elif selected.has_meta("ward_lift"): accepted = selected.moving
		else: accepted = selected.opened
	interactions.append({"mechanism":name,"accepted":accepted,"input":"E"})
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
	return true
func ride_lift() -> bool:
	var lift: AnimatableBody3D = world.get_node("Lift_Observation")
	var lower: Vector3 = lift.global_position+Vector3(0,1.02,0)
	# Optional observation lift is a physics shaft; it cannot bypass final combat.
	if not await walk(lower,"Lift boarding"): return false
	if not await use("Lift_Observation"): return false
	for k in 250:
		await get_tree().physics_frame
		if not lift.moving: break
	if lift.moving or player.global_position.y < room_center("observation").y-.2: failures.append("Lift did not physically carry passenger upward"); return false
	if not await walk(room_center("observation"),"Upper observation"): return false
	if not await walk(lift.global_position+Vector3(0,1.02,0),"Lift return boarding"): return false
	if not await use("Lift_Observation"): return false
	for k in 250:
		await get_tree().physics_frame
		if not lift.moving: break
	if not require(not lift.moving and horizontal(player.global_position,lift.global_position) < 1.0 and player.global_position.y < room_center("observation").y-1.0, "Lift did not physically carry passenger downward"): return false
	lift_returned = true
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
	require(world.finished, "Completion signal absent")
	require(app.level_complete and get_tree().paused, "Main completion/menu pause did not occur")
