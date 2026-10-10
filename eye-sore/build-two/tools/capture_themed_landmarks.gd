extends SceneTree
## Controlled actual-main art review. Teleported camera/AI freeze is explicitly
## recorded; these stills do not establish ordinary input, combat or route play.
var app: Control
var stage_id := "pale_ward"
var evidence_dir := "res://verification/expansion-v1/art"
var force_offscreen := false
var warmup_frames := 12
var report := {"status": "running", "captures": [], "failures": []}
const KINDS := ["unsealed", "vessel", "ironbound", "censer", "reaver", "surveyor"]

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--stage="): stage_id = argument.trim_prefix("--stage=")
		if argument.begins_with("--evidence-dir="): evidence_dir = argument.trim_prefix("--evidence-dir=")
	force_offscreen = "--force-offscreen-draw" in OS.get_cmdline_user_args()
	call_deferred("capture")

func xyz(point: Vector3) -> Array: return [point.x, point.y, point.z]

func save_report() -> void:
	var file := FileAccess.open(evidence_dir + "/" + stage_id + "-landmarks.json", FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(report, "  ") + "\n"); file.close()

func fail(message: String) -> bool:
	report.status = "failed"; report.failures.append(message); save_report()
	push_error("THEMED_LANDMARK_CAPTURE_FAILED: " + message); quit(1)
	return false

func native_images(label: String) -> bool:
	var forced := false; var unavailable := false
	for frame in warmup_frames:
		await process_frame
		var drawable := DisplayServer.window_can_draw()
		unavailable = unavailable or not drawable
		if force_offscreen or not drawable:
			# force_draw emits frame_post_draw synchronously; do not wait afterward.
			RenderingServer.force_draw(false); forced = true
		else: await RenderingServer.frame_post_draw
	var window_image := root.get_texture().get_image()
	var world_image: Image = app.world_view.get_texture().get_image()
	if window_image == null or window_image.is_empty() or world_image == null or world_image.is_empty(): return fail("Empty rendered image: " + label)
	var window_path := evidence_dir + "/" + stage_id + "-" + label + ".png"
	var world_path := evidence_dir + "/" + stage_id + "-" + label + "-world.png"
	for pair in [[window_image, window_path], [world_image, world_path]]:
		var error: Error = pair[0].save_png(pair[1])
		if error != OK: return fail("PNG save: " + pair[1] + " · " + error_string(error))
	var camera: Camera3D = app.player.camera
	var record := {"label": label, "room": report.current_room, "camera_position": xyz(camera.global_position),
		"camera_rotation_radians": xyz(camera.global_rotation), "camera_forward": xyz(-camera.global_basis.z),
		"camera_horizontal_fov": camera.fov, "camera_keep_aspect": camera.keep_aspect,
		"actor_position": xyz(app.player.global_position), "weapon": String(app.combat.currentweapon),
		"weapon_phase": String(app.combat.weapon_phase), "warmup_render_frames": warmup_frames,
		"forced_offscreen_requested": force_offscreen, "force_draw_used": forced, "window_unavailable_during_warmup": unavailable,
		"portrait_enemy_adjustments": report.current_portrait_adjustments,
		"window_png": window_path, "window_dimensions": [window_image.get_width(), window_image.get_height()],
		"window_sha256": FileAccess.get_sha256(window_path), "raw_main_world_subviewport_png": world_path,
		"world_dimensions": [world_image.get_width(), world_image.get_height()], "world_sha256": FileAccess.get_sha256(world_path)}
	report.captures.append(record); save_report()
	print("THEMED_LANDMARK_IMAGE_OK: ", stage_id, " ", label, " native_world=", world_image.get_size(), " force_draw=", forced)
	return true

func set_room_camera(route: Dictionary, room_id: String, rear_offset: float) -> void:
	var center: Array = route.rooms[room_id].center
	var camera: Camera3D = app.player.camera
	var desired := Vector3(float(center[0]), float(center[1]) + 1.27, float(center[2]) + rear_offset)
	app.player.rotation = Vector3.ZERO; camera.rotation = Vector3.ZERO
	app.player.global_position = desired - camera.position
	camera.look_at(desired + Vector3(0, 0, -20))
	var adjustments: Array = []
	for enemy in app.combat.enemies:
		if enemy.dead: continue
		var to_camera: Vector3 = app.player.global_position - enemy.global_position
		if to_camera.length() < 45 and camera.is_position_in_frustum(enemy.global_position + Vector3(0, .3, 0)):
			var before: float = enemy.rotation.y
			enemy.rotation.y = atan2(-to_camera.x, -to_camera.z)
			adjustments.append({"target_id": String(enemy.target_id), "kind": String(enemy.definition.identifier),
				"position": xyz(enemy.global_position), "original_yaw": before, "controlled_portrait_yaw": enemy.rotation.y})
		# Actor/camera is positioned before selecting the corresponding native pose.
		enemy.update_presentation()
	report.current_room = room_id; report.current_portrait_adjustments = adjustments

func weapon_view(id: StringName) -> void:
	if app.combat.currentweapon != id: app.combat.select_weapon(id)
	# Let the existing controller finish its normal switch; no replacement view art.
	await create_timer(.45).timeout

func capture() -> void:
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence_dir))
	if error != OK: fail("Evidence directory unavailable"); return
	report.stage_id = stage_id
	report.scope = "Controlled art review of actual main scene/native world SubViewport and unchanged HUD/view weapons. Camera teleported to authored runtime room coordinates; player and enemy AI physics frozen; selected in-frustum threats face camera as controlled portraits. Direct enter_combat/select_weapon API calls bypass physical input. No normal route, ordinary combat or human playthrough claim."
	report.player_physics_frozen = true; report.enemy_ai_physics_frozen = true
	report.combat_weapon_tick_frozen = false; report.stage_geometry_modified = false
	report.engine_version = Engine.get_version_info(); report.display_server = DisplayServer.get_name()
	report.video_adapter = RenderingServer.get_video_adapter_name()
	report.rendering_method_setting = ProjectSettings.get_setting("rendering/renderer/rendering_method", "")
	report.capture_script_sha256 = FileAccess.get_sha256("res://tools/capture_themed_landmarks.gd")
	if DisplayServer.get_name() == "headless": fail("Native renderer required for photographs"); return
	var route_path := "res://resources/stages/" + stage_id + "-route.json"
	if not FileAccess.file_exists(route_path): fail("Unknown runtime stage route: " + stage_id); return
	var route: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(route_path))
	var art: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/combat_art.json"))
	report.runtime_route_path = route_path; report.runtime_route_sha256 = FileAccess.get_sha256(route_path)
	report.runtime_art_sha256 = FileAccess.get_sha256("res://assets/combat_art.json")
	report.runtime_catalog_sha256 = FileAccess.get_sha256("res://resources/stages/catalog.json")
	var source_art := {}
	for kind in KINDS:
		if not art.enemies.has(kind): fail("Final native art missing: " + kind); return
		var entry: Dictionary = art.enemies[kind]
		source_art[kind] = {"path": entry.file, "sha256": FileAccess.get_sha256(entry.file)}
	report.final_native_art = source_art
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	app = preload("res://scenes/main.tscn").instantiate(); root.add_child(app)
	if app.stage_id != stage_id: fail("Actual main ignored requested --stage"); return
	app.automated_input = true; app.enter_combat(); Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	app.player.set_physics_process(false)
	var configured := {}
	for enemy in app.combat.enemies:
		enemy.set_physics_process(false)
		if enemy.sprite == null: fail("Actual main has an unconfigured enemy sprite"); return
		configured[String(enemy.definition.identifier)] = true
	report.configured_stage_species = configured.keys(); report.authored_enemy_count = app.combat.enemies.size()
	report.gore_profile_path = app.combat.gore.profile.resource_path
	report.gore_profile_sha256 = FileAccess.get_sha256(report.gore_profile_path)
	report.actual_main_stage_scene = app.selected_stage().scene
	report.stage_scene_sha256 = FileAccess.get_sha256(report.actual_main_stage_scene)
	report.main_world_subviewport_size = [app.world_view.size.x, app.world_view.size.y]
	report.landmark_pose_count = 3; report.entry_weapon_comparisons = 2
	set_room_camera(route, "entry", 7)
	await weapon_view(&"pistol")
	if not await native_images("entry-pistol"): return
	await weapon_view(&"shotgun")
	if not await native_images("entry-shotgun"): return
	for room in ["arena_one", "final_arena"]:
		set_room_camera(route, room, 12)
		if not await native_images(room + "-shotgun"): return
	report.erase("current_room"); report.erase("current_portrait_adjustments")
	report.status = "passed"; save_report()
	print("THEMED_LANDMARK_CAPTURE_OK: ", stage_id, " actual main; 3 controlled camera poses/4 weapon-composite photographs; not normal route gameplay")
	await app.quit_game()
