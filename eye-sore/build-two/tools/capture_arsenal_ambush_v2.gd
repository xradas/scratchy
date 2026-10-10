extends SceneTree
## Native actual-Main presentation fixtures. Camera/actor teleport and AI freeze
## are recorded explicitly; no normal route or human style acceptance claim.
const NEW_GUNS := ["twin_shotgun", "rivet_cannon", "siege_launcher"]
const WARMUP := 12
var app: Control
var stage_id := "pale_ward"
var evidence_dir := "res://verification/arsenal-ambush-v2/captures"
var manifest_path := "res://assets/combat_art.json"
var weapon_phases := true
var force_offscreen := false
var events: Array[Dictionary] = []
var report := {"status": "running", "captures": [], "events": [], "failures": []}
var route: Dictionary

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--stage="): stage_id = arg.trim_prefix("--stage=")
		if arg.begins_with("--evidence-dir="): evidence_dir = arg.trim_prefix("--evidence-dir=")
		if arg.begins_with("--manifest="): manifest_path = arg.trim_prefix("--manifest=")
		if arg == "--skip-weapon-phases": weapon_phases = false
		if arg == "--force-offscreen-draw": force_offscreen = true
	call_deferred("capture")

func xyz(point: Vector3) -> Array: return [point.x, point.y, point.z]
func xy(point: Vector2) -> Array: return [point.x, point.y]
func vec(values: Array) -> Vector3: return Vector3(values[0], values[1], values[2])
func save_report() -> void:
	report.events = events
	var file := FileAccess.open(evidence_dir.path_join(stage_id + "-capture-state.json"), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(report, "  ") + "\n"); file.close()
func fail(message: String) -> bool:
	report.status = "failed"; report.failures.append(message); save_report()
	push_error("ARSENAL_AMBUSH_CAPTURE_FAILED: " + message); quit(1)
	return false
func require(condition: bool, message: String) -> bool:
	if not condition: return fail(message)
	return true
func on_event(event: Dictionary) -> void:
	var record := {"type": String(event.get("type", "")), "physics_tick": Engine.get_physics_frames(), "weapon_id": String(event.get("weapon_id", "")), "shot_id": int(event.get("shot_id", 0))}
	for key in ["ammo", "amount", "ammo_kind", "target_id"]:
		if event.has(key): record[key] = String(event[key]) if event[key] is StringName else event[key]
	events.append(record)
func freeze_actors() -> void:
	app.player.set_physics_process(false)
	for enemy in app.combat.enemies: enemy.set_physics_process(false)
func camera_pose(eye: Vector3, target: Vector3) -> void:
	app.player.rotation = Vector3.ZERO; app.player.camera.rotation = Vector3.ZERO
	app.player.global_position = eye - app.player.camera.position
	app.player.camera.look_at(target)
	for enemy in app.combat.enemies: enemy.update_presentation()
func room_pose(id: String, rear: float = 11.0) -> void:
	var center := vec(route.rooms[id].center)
	camera_pose(center + Vector3(0, 1.6, rear), center + Vector3(0, 1.6, -6))
func mechanism_records() -> Dictionary:
	var result := {}
	for arena in app.world.trap_entries:
		var entry: Node3D = app.world.trap_entries[arena]
		var shutters: Array = []
		for shutter in app.world.trap_shutters.get(arena, []): shutters.append({"node":String(shutter.name), "position":xyz(shutter.global_position), "opened":shutter.opened, "is_open":shutter.is_open()})
		result[arena] = {"entry_position":xyz(entry.global_position), "entry_opened":entry.opened, "entry_is_closed":entry.is_closed(), "shutters":shutters}
	return result
func photograph(label: String, fixture: String, extra: Dictionary = {}) -> bool:
	# Freeze achieved state, including stage mechanism simulation, while native
	# viewport/compositor receives warmup renders. The images are not composites.
	paused = true; app._process(0.0)
	var forced := false; var unavailable := false
	for frame in WARMUP:
		await process_frame
		var drawable := DisplayServer.window_can_draw()
		unavailable = unavailable or not drawable
		if force_offscreen or not drawable: RenderingServer.force_draw(false); forced = true
		else: await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var world_image: Image = app.world_view.get_texture().get_image()
	if not require(image != null and not image.is_empty() and world_image != null and not world_image.is_empty(), "Empty native image " + label): return false
	var name := stage_id + "-" + label
	var full_path := evidence_dir.path_join(name + ".png")
	var world_path := evidence_dir.path_join(name + "-world.png")
	if not require(image.save_png(full_path) == OK and world_image.save_png(world_path) == OK, "Save native images " + label): return false
	var state: Dictionary = app.combat.get_hud_state()
	var weapon := String(state.weapon_id); var phase := String(state.weapon_phase)
	if phase == "fire" and not require(app.muzzle_image.visible, "Accepted fire lacks native muzzle " + label): return false
	var definition: Dictionary = app.art_data.get("weapon_atlases", {}).get(weapon, {})
	var record := {"label":label, "fixture":fixture, "stage":stage_id, "full_window_png":full_path, "raw_main_subviewport_png":world_path,
		"full_window_sha256":FileAccess.get_sha256(full_path), "world_sha256":FileAccess.get_sha256(world_path),
		"window_dimensions":[image.get_width(),image.get_height()], "native_world_dimensions":[world_image.get_width(),world_image.get_height()],
		"camera_position":xyz(app.player.camera.global_position), "camera_rotation":xyz(app.player.camera.global_rotation), "camera_forward":xyz(-app.player.camera.global_basis.z),
		"actor_position":xyz(app.player.global_position), "player_physics_frozen":true, "enemy_ai_physics_frozen":true, "scene_tree_paused_for_image":paused,
		"forced_draw":forced, "window_unavailable":unavailable, "warmup_frames":WARMUP,
		"weapon":weapon, "phase":phase, "phase_progress":state.phase_progress, "owned_weapons":state.owned_weapons,
		"ammo_pistol":state.ammo_pistol, "ammo_shotgun":state.ammo_shotgun, "ammo_rivets":state.ammo_rivets, "ammo_rockets":state.ammo_rockets,
		"weapon_texture_path":state.weapon_visual_path, "weapon_rect_coordinate_space":"actual Main world SubViewport pixels", "weapon_rect_position":xy(app.weapon_image.global_position), "weapon_rect_size":xy(app.weapon_image.size),
		"muzzle_visible":app.muzzle_image.visible, "trap_state":app.world.get_level_state().get("traps", {}).duplicate(true), "mechanisms":mechanism_records()}
	if app.weapon_image.texture is AtlasTexture:
		var rect: Rect2 = (app.weapon_image.texture as AtlasTexture).region
		record.actual_native_source_rect = [rect.position.x,rect.position.y,rect.size.x,rect.size.y]
	if not definition.is_empty():
		var anchor: Variant = app.art_data.flash.anchors.get(weapon, {}).get(phase)
		if anchor is Array:
			var local: Vector2 = Vector2(anchor[0],anchor[1]) * app.weapon_image.size / Vector2(320,180)
			var native_point: Vector2 = app.weapon_image.global_position + local
			var point: Vector2 = app.world_image.global_position + native_point * app.world_image.size / Vector2(app.world_view.size)
			var cross: Vector2 = app.world_image.global_position + app.world_image.size * .5
			record.projected_muzzle_marker_native = xy(native_point)
			record.projected_muzzle_marker = xy(point); record.crosshair_center = xy(cross); record.marker_minus_crosshair = xy(point-cross)
			record.projected_muzzle_coordinate_space = "full window pixels"
			record.marker_scope = "Native marker projection is measurable; it does not prove illustrated bore direction or exact visual aim."
	record.merge(extra)
	report.captures.append(record); save_report()
	print("ARSENAL_AMBUSH_PHOTO_OK: ", name, " weapon=", weapon, " phase=", phase)
	return true
func wait_ready(id: StringName) -> bool:
	paused = false
	for tick in 120:
		await physics_frame
		if app.combat.currentweapon == id and app.combat.weapon_phase == &"idle" and app.combat.cooldown <= 0: return true
	return fail("Weapon never ready: " + String(id))
func wait_phase(id: StringName, phase: StringName) -> bool:
	paused = false
	for tick in 120:
		await physics_frame
		if app.combat.currentweapon == id and app.combat.weapon_phase == phase: return true
	return fail("Weapon phase timeout: " + String(id) + " " + String(phase))
func captures_for_guns() -> bool:
	room_pose("entry", 7)
	for id in NEW_GUNS:
		var weapon := StringName(id)
		# Ownership and ammo came from the authored physical bait captures above.
		# Presentation uses that inventory; no synthetic grant or ammo refill.
		paused = false
		if not require(app.combat.has_weapon(weapon), "Physical bait ownership absent " + id): return false
		if not await wait_ready(app.combat.currentweapon): return false
		if not require(app.combat.select_weapon(weapon), "Presentation switch failed " + id): return false
		if not await photograph(id + "-switch", "Presentation fixture: actual authored bait grant followed by accepted switch; controlled entry camera"): return false
		if not await wait_ready(weapon): return false
		if not await photograph(id + "-idle", "Presentation fixture: actual authored bait ownership/ammo; controlled entry camera"): return false
		paused = false
		var resource: Resource = app.combat.weapons[weapon]
		var ammo_key := String(resource.get("ammo_key"))
		var before := int(app.combat.get(ammo_key))
		var events_before := events.size()
		if not require(app.combat.try_fire(), "Accepted shot missing " + id): return false
		if not require(int(app.combat.get(ammo_key)) == before-int(resource.get("ammo_cost")) and events.size() > events_before, "Shot ammo/event mismatch " + id): return false
		if not await photograph(id + "-fire", "Presentation fixture: actual authored bait inventory then accepted native shot; simulation frozen at fire", {"ammo_before":before,"ammo_cost":resource.get("ammo_cost")}): return false
		if not await wait_phase(weapon, &"recover"): return false
		if not await photograph(id + "-recover", "Presentation fixture: accepted shot advanced on native physics to recovery"): return false
		if not await wait_ready(weapon): return false
	return true
func capture_traps() -> bool:
	for arena in ["arena_one", "arena_two", "final_arena"]:
		var bait: Node3D
		for item in app.world.pickups:
			if String(item.get_meta("bait_arena", "")) == arena: bait = item
		if not require(bait != null and app.world.traps.has(arena), "Missing physical bait/trap " + arena): return false
		# Camera is set clear of the bait radius so a before-image cannot collect it.
		room_pose(arena, 12)
		if not await photograph(arena + "-trap-before", "Controlled room camera before physical bait collection", {"bait_position":xyz(bait.global_position),"bait_weapon":bait.get_meta("stage_pickup")}): return false
		paused = false
		app.player.global_position = bait.global_position
		app.world.update_player(app.player, app.combat)
		if not require(not bait.visible and app.world.traps[arena].triggered, "Physical bait collection did not trigger " + arena): return false
		var weapon := StringName(bait.get_meta("stage_pickup"))
		if not require(app.combat.has_weapon(weapon), "Bait did not grant weapon " + String(weapon)): return false
		if not await wait_ready(app.combat.currentweapon): return false
		if app.combat.currentweapon != weapon:
			if not require(app.combat.select_weapon(weapon), "Bait weapon switch rejected"): return false
			if not await wait_ready(weapon): return false
		room_pose(arena, 12)
		if not await photograph(arena + "-bait-acquired", "Actor teleported onto authored physical bait; normal update_player collection granted weapon and triggered trap", {"bait_weapon":String(weapon),"bait_hidden":not bait.visible}): return false
		paused = false
		for tick in 125: await physics_frame
		if not require(app.world.traps[arena].shutters_open and app.world.is_arena_active(arena), "Trap shutters/roster failed to activate " + arena): return false
		if not await photograph(arena + "-trap-after", "Native mechanisms advanced for 125 physics ticks after bait; enemy AI frozen; controlled room camera"): return false
	return true
func capture_routes() -> bool:
	for name in route.get("vertical_routes", {}):
		var points: Array = route.vertical_routes[name]
		if points.size() < 3: continue
		var fixture := "Controlled authored elevation-route viewpoint; no movement completion claim"
		var extra := {"authored_route":String(name),"route_vantage_index":1}
		if String(name).ends_with("_gallery") or String(name) == "service_balcony":
			var room_id := String(name).trim_suffix("_gallery") if String(name).ends_with("_gallery") else "service"
			var center := vec(route.rooms[room_id].center)
			var target := center + Vector3(0,1.0,0)
			camera_pose(vec(points[1]) + Vector3(0,1.3,0), target)
			fixture = "Controlled authored gallery viewpoint looking down toward room floor; camera at physical routepoint[1]+1.3m eyeheight. Separate physical climb proof is required; no movement completion claim."
			extra["look_down_target"] = xyz(target); extra["room"] = room_id
		else:
			camera_pose(vec(points[1]) + Vector3(0,1.3,0), vec(points[2]) + Vector3(0,1.3,0))
		if not await photograph("elevation-" + String(name), fixture, extra): return false
	for arena in route.get("combat_paths", {}):
		var paths: Array = route.combat_paths[arena]
		for index in paths.size():
			var points: Array = paths[index]
			if points.size() < 2: continue
			camera_pose(vec(points[0]) + Vector3(0,1.3,0), vec(points[-1]) + Vector3(0,1.3,0))
			if not await photograph(String(arena) + "-split-path-" + str(index+1), "Controlled authored split combat-path viewpoint; no movement completion claim"): return false
	return true
func capture() -> void:
	if DisplayServer.get_name() == "headless": fail("Native renderer required; headless captures are rejected"); return
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence_dir)) != OK: fail("Cannot create evidence directory"); return
	var route_path := "res://resources/stages/%s-route.json" % stage_id
	route = JSON.parse_string(FileAccess.get_file_as_string(route_path))
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	report.scope = "Full native window and raw actual Main world SubViewport. Controlled teleported cameras/actors, enemy AI/player physics disabled, simulation paused only for photographs. Accepted weapon shots and authored physical bait collection/mechanisms are recorded. No normal input-driven route, human style or exact illustrated bore aim acceptance claim."
	report.stage = stage_id; report.manifest = manifest_path; report.manifest_sha256 = FileAccess.get_sha256(manifest_path)
	report.route_sha256 = FileAccess.get_sha256(route_path); report.script_sha256 = FileAccess.get_sha256("res://tools/capture_arsenal_ambush_v2.gd")
	report.engine = Engine.get_version_info(); report.display_server = DisplayServer.get_name(); report.video_adapter = RenderingServer.get_video_adapter_name()
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	app = preload("res://scenes/main.tscn").instantiate(); root.add_child(app)
	if not require(app.stage_id == stage_id, "Actual Main stage argument mismatch"): return
	app.automated_input = true; app.enter_combat(); Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	app.art_data = manifest; app.combat.configure_weapon_visuals(manifest.weapons); app.texture_cache.clear(); app.weapon_image.texture = null
	freeze_actors(); app.combat.combat_event.connect(on_event)
	report.native_weapon_sources = {}
	for weapon in manifest.weapons:
		var path: String = manifest.weapons[weapon].idle
		report.native_weapon_sources[weapon] = {"path":path,"sha256":FileAccess.get_sha256(path)}
	report.actual_main_scene = app.selected_stage().scene; report.stage_scene_sha256 = FileAccess.get_sha256(app.selected_stage().scene)
	room_pose("entry", 7)
	if not await photograph("entry", "Controlled actual stage entry viewpoint; starting inventory"): return
	if not await capture_traps(): return
	if not await capture_routes(): return
	if weapon_phases and not await captures_for_guns(): return
	report.status = "passed"; save_report()
	print("ARSENAL_AMBUSH_CAPTURE_OK: ", stage_id, " photographs=", report.captures.size())
	await app.quit_game()
