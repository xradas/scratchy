extends SceneTree
## Native-render contract for the shared pixel grid. Art style review is separate.
var app: Control
var failures: Array[String] = []
var checks := 0
var registrations: Array[Dictionary] = []
var renders: Array[Dictionary] = []
var evidence := "res://verification/style-v2/s01"
var native_grid := false
var force_offscreen := false

func _initialize() -> void:
	native_grid = "--style-native-grid" in OS.get_cmdline_user_args()
	force_offscreen = "--force-offscreen-draw" in OS.get_cmdline_user_args()
	call_deferred("run_check")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("STYLE_COMPOSITE_FAILED: " + message)

func draw_frame() -> void:
	for i in 3:
		await process_frame
		if force_offscreen: RenderingServer.force_draw(false)
		else: await RenderingServer.frame_post_draw

func vec(value: Vector2) -> Array:
	return [value.x, value.y]

func screen_rect(item: Control) -> Rect2:
	var factor: Vector2 = app.world_image.size / Vector2(app.world_view.size)
	return Rect2(app.world_image.position + item.position * factor, item.size * factor)

func audit_registration(window: Vector2i) -> void:
	var combat: Node3D = app.combat
	var original_ammo := Vector2i(combat.ammo_pistol, combat.ammo_shotgun)
	for weapon in ["pistol", "shotgun", "melee"]:
		var definition: Dictionary = app.art_data.weapon_atlases[weapon]
		for phase in ["idle", "fire", "recover", "switch"]:
			for recoil in [0.0, 7.0]:
				combat.currentweapon = StringName(weapon)
				combat.weapon_phase = StringName(phase)
				combat.recoil_remaining = recoil
				app.muzzle_time = 0.045 if weapon != "melee" else 0.0
				app._process(0.0)
				var pose: Dictionary = definition.placement[phase]
				var marker := Vector2(pose.marker[0], pose.marker[1])
				var target := Vector2(pose.target[0], pose.target[1])
				# Compare mapped global pixels to the original window-space formula.
				var scale: float = app.world_image.size.y / float(definition.source_canvas_height) * float(pose.scale)
				var expected_size: Vector2 = app.weapon_image.texture.get_size() * scale
				var expected_position: Vector2 = app.world_image.position + app.world_image.size * target - marker * scale
				expected_position.y += recoil * app.world_image.size.y / 180.0
				var actual := screen_rect(app.weapon_image)
				check(actual.position.is_equal_approx(expected_position) and actual.size.is_equal_approx(expected_size), "%s %s recoil %.0f global registration at %s" % [weapon, phase, recoil, window])
				if weapon != "melee":
					var flash: Dictionary = app.art_data.flash
					var anchor_data: Dictionary = flash.anchors.get(weapon, {})
					var anchor: Array = anchor_data.get(phase, anchor_data.get("fire", [160, 90]))
					var flash_size: Vector2 = Vector2.ONE * float(flash.get("world_size", 36)) * app.world_image.size.y / 360.0
					var flash_position: Vector2 = expected_position + Vector2(anchor[0], anchor[1]) * expected_size / Vector2(320, 180) - flash_size * 0.5
					var actual_flash := screen_rect(app.muzzle_image)
					check(app.muzzle_image.visible and actual_flash.position.is_equal_approx(flash_position) and actual_flash.size.is_equal_approx(flash_size), "%s %s recoil %.0f global muzzle registration at %s" % [weapon, phase, recoil, window])
				else:
					check(not app.muzzle_image.visible, "melee has no muzzle")
				var local_normalized: Vector2 = app.weapon_image.position / app.weapon_layer.size
				registrations.append({"window": vec(Vector2(window)), "weapon": weapon, "phase": phase, "recoil": recoil, "screen_position": vec(actual.position), "screen_size": vec(actual.size), "normalized_position": vec(local_normalized)})
	check(original_ammo == Vector2i(combat.ammo_pistol, combat.ammo_shotgun), "presentation does not spend ammunition")

func covered(point: Vector2) -> bool:
	for control in [app.hud, app.status, app.crosshair]:
		if control.visible and control.get_global_rect().has_point(point): return true
	return false

func near_color(a: Color, b: Color) -> bool:
	return maxf(maxf(absf(a.r - b.r), absf(a.g - b.g)), maxf(absf(a.b - b.b), absf(a.a - b.a))) <= 2.0 / 255.0

func audit_render(label: String) -> void:
	await draw_frame()
	var image := root.get_texture().get_image()
	var source: Image = app.world_view.get_texture().get_image()
	check(image != null and not image.is_empty() and source != null and not source.is_empty(), label + " native rendered textures available")
	if image == null or image.is_empty() or source == null or source.is_empty(): return
	check(image.save_png(evidence.path_join(label + ("-native" if native_grid else "") + ".png")) == OK, label + " screenshot saved")
	if label == "1280x720-pistol-idle":
		check(source.save_png(evidence.path_join("world-weapon-native640.png")) == OK, "native world/weapon composite saved")
	var resolution := Vector2i(640, 360) if native_grid else Vector2i(320, 180)
	var cell_size: Vector2 = app.world_image.size / Vector2(resolution)
	var tested := 0
	var mismatch := 0
	var examples: Array[Dictionary] = []
	for y in range(resolution.y):
		for x in range(resolution.x):
			var origin: Vector2 = app.world_image.position + Vector2(x, y) * cell_size
			var center: Vector2 = origin + cell_size * 0.5
			if covered(origin) or covered(origin + cell_size - Vector2.ONE) or covered(center): continue
			var source_point := Vector2i((Vector2(x, y) + Vector2.ONE * 0.5) * Vector2(640, 360) / Vector2(resolution))
			var expected := source.get_pixelv(source_point)
			for offset in [Vector2.ZERO, Vector2(cell_size.x - 1, 0), Vector2(0, cell_size.y - 1), cell_size - Vector2.ONE]:
				var point := Vector2i(origin + offset)
				tested += 1
				if not near_color(image.get_pixelv(point), expected):
					mismatch += 1
					if examples.size() < 4: examples.append({"screen": vec(Vector2(point)), "source": vec(Vector2(source_point)), "actual": image.get_pixelv(point).to_html(true), "expected": expected.to_html(true)})
	check(tested > 100000 and mismatch == 0, "%s all sampled visible cell corners match combined native source (%d/%d mismatches)" % [label, mismatch, tested])
	renders.append({"label": label, "window": vec(Vector2(root.size)), "world_rect_position": vec(app.world_image.position), "world_rect_size": vec(app.world_image.size), "virtual_resolution": vec(Vector2(resolution)), "sampled_pixels": tested, "mismatches": mismatch, "examples": examples})

func audit_shader_tint() -> void:
	# A translucent white texel over opaque black reveals repeated texture-alpha
	# or vertex-color multiplication, which can make sprite boundaries darken.
	var viewport := SubViewport.new()
	viewport.size = Vector2i(16, 16)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.color = Color.BLACK
	background.size = Vector2(16, 16)
	viewport.add_child(background)
	var pixels := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	pixels.fill(Color(1, 1, 1, 0.5))
	var sample := TextureRect.new()
	sample.texture = ImageTexture.create_from_image(pixels)
	sample.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sample.size = Vector2(16, 16)
	sample.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sample.modulate = Color(0.5, 0.25, 0.75, 0.8)
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/concept_pixels.gdshader")
	material.set_shader_parameter("virtual_resolution", Vector2(8, 8))
	sample.material = material
	viewport.add_child(sample)
	await draw_frame()
	var rendered := viewport.get_texture().get_image().get_pixel(8, 8)
	var alpha: float = pixels.get_pixel(0, 0).a * 0.8
	check(near_color(rendered, Color(0.5 * alpha, 0.25 * alpha, 0.75 * alpha, 1.0)), "shader preserves vertex tint and texture alpha exactly once")
	viewport.free()

func freeze_world() -> void:
	app.set_process(false)
	app.player.set_physics_process(false)
	app.combat.set_physics_process(false)
	for enemy in app.combat.enemies: enemy.set_physics_process(false)

func run_check() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence))
	check(DisplayServer.get_name() != "headless", "requires native renderer, not headless dummy")
	if not failures.is_empty(): quit(1); return
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	root.mode = Window.MODE_WINDOWED
	root.show()
	await audit_shader_tint()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.enter_combat()
	await process_frame
	app.set_paused(false)
	freeze_world()
	app.player.position = Vector3(0, 0.87, 14)
	app.player.rotation = Vector3.ZERO
	app.player.camera.rotation = Vector3.ZERO
	for i in range(app.combat.enemies.size()):
		var enemy: CharacterBody3D = app.combat.enemies[i]
		enemy.position = Vector3(-1.5 if i == 0 else 1.8, 0.87, 9.5 if i == 0 else 7.0)
		enemy.state_time = 0.0
		enemy.update_presentation()
	check(app.weapon_canvas.get_parent() == app.world_view and app.weapon_layer.get_parent() == app.weapon_canvas and app.weapon_image.get_parent() == app.weapon_layer and app.muzzle_image.get_parent() == app.weapon_layer, "world, viewgun and muzzle share viewport and persistent overlay owner")
	for control in [app.hud, app.status, app.menu, app.crosshair]:
		check(control.get_viewport() == root and control.material == null, "window UI retains its own resolution and unmodified material")
	var camera: Camera3D = app.player.camera
	var base_direction := camera.project_ray_normal(Vector2(320, 180))
	var base_origin := camera.project_ray_origin(Vector2(320, 180))
	var base_fov := camera.fov
	for window in [Vector2i(1280, 720), Vector2i(1560, 900), Vector2i(800, 600)]:
		root.size = window
		await process_frame
		app.layout_view()
		check(app.world_view.size == Vector2i(640, 360) and app.weapon_layer.size == Vector2(640, 360), "fixed camera/presentation viewport at " + str(window))
		check(app.crosshair.position + app.crosshair.size * 0.5 == app.world_image.position + app.world_image.size * 0.5, "crosshair stays centered at " + str(window))
		check(camera.project_ray_origin(Vector2(320, 180)).is_equal_approx(base_origin) and camera.project_ray_normal(Vector2(320, 180)).is_equal_approx(base_direction) and camera.fov == base_fov, "window resize preserves camera center ray/FOV at " + str(window))
		audit_registration(window)
		app.combat.currentweapon = &"pistol"
		app.combat.weapon_phase = &"idle"
		app.combat.recoil_remaining = 0.0
		app.muzzle_time = 0.0
		app._process(0.0)
		await audit_render("%dx%d-pistol-idle" % [window.x, window.y])
	# Real accepted shots still own their flash, ammo and timing.
	root.size = Vector2i(1280, 720)
	await process_frame
	app.layout_view()
	app.combat.currentweapon = &"shotgun"
	app.combat.weapon_phase = &"idle"
	app.combat.cooldown = 0.0
	var ammo: int = app.combat.ammo_shotgun
	check(app.combat.try_fire(), "actual Combat accepts shotgun")
	app._process(0.0)
	check(app.muzzle_image.visible and not app.muzzle_pending and app.combat.ammo_shotgun == ammo - 1 and app.combat.weapon_phase == &"fire", "accepted shot keeps visible-first-frame muzzle, ammo and fire phase")
	var cooldown: float = app.combat.cooldown
	var lifetime: float = app.muzzle_time
	app.combat.weapon_lighting.set_process(false)
	await audit_render("1280x720-shotgun-fire")
	var visible_source: Image = app.world_view.get_texture().get_image()
	var flash_rect := screen_rect(app.muzzle_image)
	app.muzzle_image.visible = false
	await draw_frame()
	var dark_source: Image = app.world_view.get_texture().get_image()
	var flash_changed := 0
	for y in range(360):
		for x in range(640):
			if not near_color(visible_source.get_pixel(x, y), dark_source.get_pixel(x, y)): flash_changed += 1
	check(flash_changed > 10, "muzzle actually changes the combined world render texture")
	app._process(0.0)
	app.set_paused(true)
	await create_timer(0.08, true).timeout
	app._process(0.08)
	check(app.muzzle_time == lifetime and app.combat.cooldown == cooldown, "pause freezes flash and combat timing")
	app.set_paused(false)
	app._process(0.005)
	check(is_equal_approx(app.muzzle_time, lifetime - 0.005), "resume preserves existing muzzle countdown")
	check(not app.combat.try_fire() and app.combat.ammo_shotgun == ammo - 1, "cooldown rejection keeps ammo ownership")
	var owners: Dictionary = {}
	for key in ["weapon_canvas", "weapon_layer", "weapon_image", "muzzle_image", "hud", "status", "menu", "crosshair"]: owners[key] = app.get(key).get_instance_id()
	for action in ["restart_combat", "return_to_title"]:
		app.call(action)
		freeze_world()
		for key in owners: check(app.get(key).get_instance_id() == owners[key], action + " retains " + key)
		var canvases := 0
		for child in app.world_view.get_children():
			if child is CanvasLayer: canvases += 1
		check(canvases == 1, action + " keeps one weapon canvas")
	var report := {"passed": failures.is_empty(), "checks": checks, "failures": failures, "scope": "Spatial composition contract only; does not establish equivalence to approved art style.", "force_offscreen": force_offscreen, "native_grid": native_grid, "camera_resolution": [640, 360], "registrations": registrations, "renders": renders, "muzzle_changed_native_pixels": flash_changed, "muzzle_screen_rect": {"position": vec(flash_rect.position), "size": vec(flash_rect.size)}, "pause_retry_ownership": true}
	var file := FileAccess.open(evidence.path_join("composite-native.json" if native_grid else "composite.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	print("STYLE_COMPOSITE_%s: %d checks; shared world/weapon/muzzle pixels, global registration across three windows, readable window UI, center ray, accepted fire and pause/retry ownership" % ["OK" if failures.is_empty() else "FAILED", checks])
	if is_instance_valid(app.combat_audio): app.combat_audio.stop_all()
	if is_instance_valid(app.menu_music): app.menu_music.stop()
	app.free()
	await create_timer(0.3, true).timeout
	quit(0 if failures.is_empty() else 1)
