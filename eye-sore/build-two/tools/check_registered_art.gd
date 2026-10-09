extends SceneTree
## Registration audit of manifest-selected sprite resources and presentation ownership.
## Alpha-hit correctness belongs to check_sprite_alpha.gd; no art is rewritten here.
var checks := 0
var failures: Array[String] = []
var report := {"enemies": {}, "weapons": {}, "source_identity": {}, "known_limitations": []}
var app: Control
var git_prefix := ""
var evidence_path := "res://verification/grit/p08-registered-art.json"

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-path="): evidence_path = argument.trim_prefix("--evidence-path=")
	call_deferred("run_check")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("REGISTERED_ART_FAILED: " + message)

func git_output(arguments: PackedStringArray) -> String:
	var output: Array = []
	var code := OS.execute("git", arguments, output, true)
	check(code == 0, "git read-only command succeeded: " + " ".join(arguments))
	return "".join(output).strip_edges()

func source_identity(path: String, registered_sha: String = "") -> void:
	if report.source_identity.has(path): return
	var relative := path.trim_prefix("res://")
	var original_output: Array = []
	var tracked := OS.execute("git", ["rev-parse", "--verify", "HEAD:" + git_prefix + relative], original_output, false) == 0
	var original := "".join(original_output).strip_edges() if tracked else ""
	var current := git_output(["hash-object", ProjectSettings.globalize_path(path)])
	var sha := FileAccess.get_sha256(path)
	if tracked: check(current == original, relative + " original source bytes unchanged from HEAD")
	else: check(registered_sha.length() == 64, relative + " new source supplies registered SHA256 metadata")
	if not registered_sha.is_empty(): check(sha == registered_sha, relative + " source SHA256 matches manifest registration")
	report.source_identity[path] = {"head_blob": original, "current_blob": current, "tracked_original": tracked, "unchanged_from_head": current == original if tracked else null, "registered_sha256": registered_sha, "sha256": sha}

func registered_dimensions(data: Dictionary) -> Vector2:
	# Older approved entries precede explicit dimensions metadata. Keep their
	# 1536x1024 invariant; newly selected sources can declare their own dimensions.
	var dimensions: Array = data.get("source_dimensions", data.get("atlas_dimensions", [1536, 1024]))
	return Vector2(dimensions[0], dimensions[1])

func gameplay_state() -> Dictionary:
	var state := {}
	for key in ["health", "armor", "ammo_pistol", "ammo_shotgun", "currentweapon", "weapon_phase", "phase_time", "phase_duration", "cooldown", "empty_cooldown", "shot_counter", "kills", "dead", "recoil_remaining"]:
		state[key] = app.combat.get(key)
	state.player_transform = app.player.global_transform
	state.player_velocity = app.player.velocity
	state.camera_transform = app.player.camera.global_transform
	state.camera_fov = app.player.camera.fov
	state.center_ray = app.player.camera.project_ray_normal(Vector2(320, 180))
	return state

func audit_presentation_contract() -> void:
	check(app.world_view.size == Vector2i(640, 360) and app.weapon_layer.size == Vector2(640, 360), "camera and weapon canvas preserve fixed 640x360 coordinates")
	check(app.weapon_canvas.get_parent() == app.world_view and app.weapon_layer.get_parent() == app.weapon_canvas, "one viewport-owned weapon canvas")
	check(app.weapon_image.get_parent() == app.weapon_layer and app.muzzle_image.get_parent() == app.weapon_layer, "viewgun and muzzle share clipped presentation owner")
	var canvas_count := 0
	for child in app.world_view.get_children():
		if child is CanvasLayer: canvas_count += 1
	check(canvas_count == 1, "one persistent weapon presentation canvas")
	for control in [app.hud, app.status, app.menu, app.crosshair]:
		check(control.get_viewport() == root and control.material == null, "readable UI belongs to window and has no composite material")
	check(app.world_image.material is ShaderMaterial and app.world_image.material.shader == load("res://shaders/concept_pixels.gdshader"), "only combined world/weapon texture receives pixel-grid material")
	check(app.player.camera.keep_aspect == Camera3D.KEEP_WIDTH and app.player.camera.fov == app.field_of_view, "horizontal camera FOV remains applied")
	check(app.player.sensitivity == app.sensitivity and app.player.collision_layer == 2 and app.player.collision_mask == 3, "player sensitivity and collision contract preserved")
	check(app.crosshair.position + app.crosshair.size * 0.5 == app.world_image.position + app.world_image.size * 0.5, "window crosshair registers to camera center")
	report.presentation_contract = {"camera_resolution": [640, 360], "weapon_canvas_resolution": [640, 360], "window_ui_unfiltered": true, "shared_weapon_muzzle_owner": true, "single_canvas": canvas_count == 1, "horizontal_fov": app.player.camera.fov}

func audit_enemy(enemy: CharacterBody3D, data: Dictionary) -> void:
	var kind := String(enemy.definition.identifier)
	var sprite: Sprite3D = enemy.sprite
	check(is_instance_valid(sprite), kind + " registered runtime Sprite3D")
	if not is_instance_valid(sprite): return
	var texture: Texture2D = load(data.file)
	var options: Dictionary = data.sprite_options
	var columns := int(data.columns)
	var rows := int(options.rows)
	check(sprite.texture == texture and texture.resource_path == String(data.file), kind + " actual loaded atlas matches manifest")
	check(texture.get_size() == registered_dimensions(data), kind + " atlas dimensions match registered metadata")
	check(sprite.hframes == columns and sprite.vframes == rows and columns * rows == 8, kind + " eight registered frames")
	var frame_size := texture.get_size() / Vector2(columns, rows)
	var expected_frame_size := registered_dimensions(data) / Vector2(columns, rows)
	if data.has("source_cell_dimensions"): expected_frame_size = Vector2(data.source_cell_dimensions[0], data.source_cell_dimensions[1])
	check(frame_size == expected_frame_size, kind + " frame dimensions match registered layout")
	check(is_equal_approx(sprite.pixel_size, float(data.pixel_size)), kind + " pixel scale matches manifest")
	check(sprite.layers == 2, kind + " moving sprite excluded from static reflection layer")
	check((app.player.camera.cull_mask & sprite.layers) != 0, kind + " main camera includes moving sprite layer")
	check(enemy.sprite_base_foot == Vector2(data.foot_pivot[0], data.foot_pivot[1]), kind + " base foot pivot matches manifest")
	var movement: CollisionShape3D = enemy.get_node("CollisionShape3D")
	var movement_transform := movement.global_transform
	var movement_shape := movement.shape
	var actor_layer := enemy.collision_layer
	var actor_mask := enemy.collision_mask
	var ground_y: float = enemy.global_position.y - movement.shape.height * 0.5
	check(is_equal_approx(enemy.sprite_pivot.global_position.y, ground_y), kind + " sprite foot origin equals movement capsule ground")
	var frames: Array = []
	var original_poses: Dictionary = enemy.sprite_data.poses.duplicate(true)
	for frame in range(columns * rows):
		# Use the normal presentation path to select every authored pose, including corpses,
		# without invoking death/gore or changing production gameplay behavior.
		enemy.sprite_data.poses.pain = [frame]
		enemy.state = &"pain"
		enemy.state_time = 0.0
		enemy.update_presentation()
		var pivot: Array = options.frame_pivots[str(frame)]
		var foot := Vector2(pivot[0], pivot[1])
		check(foot.x >= 0 and foot.x < frame_size.x and foot.y >= 0 and foot.y < frame_size.y, "%s frame %d pivot inside original cell" % [kind, frame])
		check(enemy.sprite_foot == foot and sprite.frame == frame, "%s frame %d selected with authored pivot" % [kind, frame])
		# The authored pivot is the pixel mapped to local ground (0,0), by the
		# same Sprite3D placement formula used by the native hurt geometry.
		var rendered_foot := sprite.position + Vector3((foot.x - frame_size.x * 0.5 + sprite.offset.x) * sprite.pixel_size, (frame_size.y * 0.5 - foot.y) * sprite.pixel_size, 0)
		check(rendered_foot.is_equal_approx(Vector3.ZERO), "%s frame %d rendered foot anchored at ground" % [kind, frame])
		var expected: Dictionary = load("res://scripts/sprite_hurt_geometry.gd").build(texture, columns, rows, frame, sprite.pixel_size, foot, enemy.sprite_data)
		var before: Dictionary = {}
		for material in enemy.sprite_bodies:
			var body: StaticBody3D = enemy.sprite_bodies[material]
			var shape: CollisionShape3D = body.get_node("HitSurface")
			if not expected.shapes.has(material): continue
			# Pose selection is part of the cache signature; the initially selected
			# frame can retain an equivalent shape from before the fixture's pose map.
			check(shape.shape != null and shape.shape.get_faces() == expected.shapes[material].get_faces(), "%s frame %d %s uses native registered hurt geometry" % [kind, frame, material])
			check(body.global_transform.is_equal_approx(enemy.sprite_pivot.global_transform) and shape.transform.is_equal_approx(Transform3D.IDENTITY), "%s frame %d hurt surface shares foot/facing transform" % [kind, frame])
			before[material] = {"transform": body.global_transform, "shape": shape.shape, "layer": body.collision_layer, "mask": body.collision_mask}
		var render_transform := sprite.global_transform
		var pivot_transform: Transform3D = enemy.sprite_pivot.global_transform
		sprite.layers = 1
		enemy.update_presentation()
		sprite.layers = 2
		enemy.update_presentation()
		check(sprite.global_transform.is_equal_approx(render_transform) and enemy.sprite_pivot.global_transform.is_equal_approx(pivot_transform), "%s frame %d render-layer change does not shift sprite or feet" % [kind, frame])
		for material in before:
			var body: StaticBody3D = enemy.sprite_bodies[material]
			check(body.global_transform.is_equal_approx(before[material].transform) and body.get_node("HitSurface").shape == before[material].shape and body.collision_layer == before[material].layer and body.collision_mask == before[material].mask, "%s frame %d layer change leaves hurt collision unchanged" % [kind, frame])
		check(movement.global_transform.is_equal_approx(movement_transform) and movement.shape == movement_shape and enemy.collision_layer == actor_layer and enemy.collision_mask == actor_mask, kind + " actor movement collision unchanged")
		frames.append({"frame": frame, "foot_pivot": pivot, "ground_y": ground_y, "native_hurt_materials": expected.shapes.keys(), "render_layer_does_not_shift_registration": true})
	for pose in options.pose_frames:
		for frame in options.pose_frames[pose]:
			check(int(frame) >= 0 and int(frame) < columns * rows, kind + " " + pose + " frame in atlas")
	enemy.sprite_data.poses = original_poses
	enemy.state = &"chase"
	enemy.update_presentation()
	report.enemies[kind] = {"path": data.file, "atlas_dimensions": [texture.get_width(), texture.get_height()], "frame_dimensions": [int(frame_size.x), int(frame_size.y)], "frame_count": columns * rows, "direction_count": int(data.directions), "frames": frames}
	if int(data.directions) < 8:
		report.known_limitations.append(kind + ": eight representative frontal poses; full eight-direction production animation remains pending. This does not fail current registration.")
	source_identity(data.file, String(data.get("sha256", data.get("source_sha256", ""))))

func audit_weapons(art: Dictionary) -> void:
	for weapon in ["pistol", "shotgun", "melee"]:
		var definition: Dictionary = art.weapon_atlases[weapon]
		var phases: Dictionary = {}
		for phase in ["idle", "fire", "recover", "switch"]:
			app.combat.currentweapon = StringName(weapon)
			app.combat.weapon_phase = StringName(phase)
			app.combat.recoil_remaining = 0
			var before := gameplay_state()
			app._process(0.0)
			check(gameplay_state() == before, weapon + " " + phase + " presentation preserves ammo, combat timeline, player and camera")
			var state: Dictionary = app.combat.get_hud_state()
			var path: String = art.weapons[weapon][phase]
			check(String(state.weapon_visual_path) == path, weapon + " " + phase + " HUD visual path matches manifest")
			var texture: Texture2D = load(path)
			check(texture != null and texture.get_size() == registered_dimensions(definition), weapon + " selected atlas dimensions match registration")
			var coordinates: Array = definition.regions[phase]
			var region := Rect2(coordinates[0], coordinates[1], coordinates[2], coordinates[3])
			check(Rect2(Vector2.ZERO, texture.get_size()).encloses(region) and region.has_area(), weapon + " " + phase + " image region valid")
			var rendered: AtlasTexture = app.weapon_image.texture
			check(rendered != null and rendered.atlas == texture and rendered.region == region and rendered.filter_clip, weapon + " " + phase + " actual HUD uses registered AtlasTexture")
			check(app.weapon_image.visible and app.hud.visible and app.hud.text.contains(weapon.to_upper()), weapon + " " + phase + " weapon and HUD visible")
			var placement: Dictionary = definition.placement[phase]
			var marker := Vector2(placement.marker[0], placement.marker[1])
			check(Rect2(Vector2.ZERO, region.size).has_point(marker), weapon + " " + phase + " authored marker inside frame")
			var scale: float = app.weapon_layer.size.y / float(definition.source_canvas_height) * float(placement.scale)
			var target := Vector2(placement.target[0], placement.target[1])
			check(app.weapon_image.size.is_equal_approx(region.size * scale) and app.weapon_image.position.is_equal_approx(app.weapon_layer.size * target - marker * scale), weapon + " " + phase + " viewport-owned weapon placement matches manifest")
			var screen_scale: Vector2 = app.world_image.size / app.weapon_layer.size
			var screen_position: Vector2 = app.world_image.position + app.weapon_image.position * screen_scale
			var original_window_scale: float = app.world_image.size.y / float(definition.source_canvas_height) * float(placement.scale)
			check(screen_position.is_equal_approx(app.world_image.position + app.world_image.size * target - marker * original_window_scale) and (app.weapon_image.size * screen_scale).is_equal_approx(region.size * original_window_scale), weapon + " " + phase + " mapped global placement equals original window-space formula")
			var visible_rect := Rect2(app.weapon_image.position, app.weapon_image.size).intersection(Rect2(Vector2.ZERO, app.weapon_layer.size))
			check(visible_rect.has_area(), weapon + " " + phase + " frame intersects visible weapon canvas")
			check(FileAccess.get_sha256(path) == String(definition.sha256), weapon + " original atlas SHA256 matches registration")
			phases[phase] = {"path": path, "region": coordinates, "marker": placement.marker, "target": placement.target, "visible": app.weapon_image.visible, "placement_matches_manifest": true}
			source_identity(path, String(definition.sha256))
		report.weapons[weapon] = phases

func run_check() -> void:
	git_prefix = git_output(["rev-parse", "--show-prefix"])
	var art: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/combat_art.json"))
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.enter_combat()
	app.set_process(false)
	app.player.set_physics_process(false)
	app.combat.set_physics_process(false)
	for enemy in app.combat.enemies: enemy.set_physics_process(false)
	await process_frame
	# Main's initial menu pause is deferred; settle it before deterministic HUD reads.
	app.set_paused(false)
	app.player.position = Vector3(0, 0.87, 14)
	var audited: Dictionary = {}
	for enemy in app.combat.enemies:
		var kind := String(enemy.definition.identifier)
		if not audited.has(kind) and art.enemies.has(kind):
			audit_enemy(enemy, art.enemies[kind])
			audited[kind] = true
	check(audited.size() == 2, "both registered enemy types audited")
	audit_presentation_contract()
	audit_weapons(art)
	report.manifest_sha256 = FileAccess.get_sha256("res://assets/combat_art.json")
	source_identity("res://scripts/combat.gd")
	source_identity("res://scripts/player.gd")
	source_identity("res://scripts/sprite_hurt_geometry.gd")
	source_identity("res://scenes/combat_enemy.tscn")
	report["checks"] = checks
	report["failures"] = failures
	report["passed"] = failures.is_empty()
	report["alpha_contract"] = "Existing check_sprite_alpha.gd owns alpha contact acceptance; this audit checks registration only."
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence_path.get_base_dir()))
	var file := FileAccess.open(evidence_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	for limitation in report.known_limitations: print("KNOWN_LIMITATION: " + limitation)
	print("REGISTERED_ART_%s: %d checks; manifest-selected enemy atlases/eight poses, feet and collision retained across render-layer changes; three weapon atlases/four phases, viewport/global registration; presentation/gameplay ownership and original or registered source identities" % ["OK" if failures.is_empty() else "FAILED", checks])
	var exit_code := 0 if failures.is_empty() else 1
	if is_instance_valid(app.combat_audio): app.combat_audio.stop_all()
	if is_instance_valid(app.menu_music): app.menu_music.stop()
	app.free()
	load("res://scripts/sprite_hurt_geometry.gd").frame_cache.clear()
	load("res://scripts/sprite_hurt_geometry.gd").image_cache.clear()
	await create_timer(0.3, true).timeout
	quit(exit_code)
