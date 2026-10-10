extends SceneTree
## tools/godot.sh --headless --script tools/check_weapon_alignment_v3.gd --
## Fails until every gun pose carries authored breech/muzzle points and the
## runtime uses weapon_presentation.gd for placement and flash origin.

const PRESENTATION = preload("res://scripts/weapon_presentation.gd")
const GUNS := ["pistol", "shotgun", "twin_shotgun", "rivet_cannon", "siege_launcher"]
const PHASES := ["idle", "fire", "recover", "switch"]
const WINDOWS := [Vector2(1280, 720), Vector2(800, 600), Vector2(1560, 900)]
const CENTER := Vector2(320, 180)
var failures: Array[String] = []
var checks := 0
var shot_events: Array[Dictionary] = []
var rivet_receiver_by_window: Dictionary = {}

func _initialize() -> void:
	call_deferred("run")

func require(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error("WEAPON_ALIGNMENT_FAILED: " + message)

func on_combat_event(event: Dictionary) -> void:
	if event.get("type") == &"shot": shot_events.append(event.duplicate())

func inspect_main_pose(app: Control, art: Dictionary, weapon: String, phase: String, window: Vector2) -> void:
	app._process(0.0)
	var atlas: Dictionary = art.weapon_atlases[weapon]
	var region: Array = atlas.regions[phase]
	var expected: Dictionary = PRESENTATION.pose(atlas.placement[phase], Vector2(region[2], region[3]), float(atlas.source_canvas_height), Vector2(640, 360), app.combat.recoil_remaining)
	var label := "%s/%s/%dx%d" % [weapon, phase, int(window.x), int(window.y)]
	require(app.weapon_image.visible and app.weapon_image.texture != null, label + ": Main sprite absent")
	require(app.weapon_image.position.distance_to(expected.position) <= 0.2, label + ": Main sprite position differs from bore pose")
	require(app.weapon_image.size.distance_to(expected.size) <= 0.2, label + ": Main sprite scale differs from registered pose")
	if weapon == "rivet_cannon":
		var receiver: Vector2 = app.weapon_image.position + PRESENTATION.point(atlas.placement[phase].receiver) * float(expected.scale)
		var window_key := "%dx%d" % [int(window.x), int(window.y)]
		if not rivet_receiver_by_window.has(window_key): rivet_receiver_by_window[window_key] = {}
		rivet_receiver_by_window[window_key][phase] = receiver
		if phase in ["fire", "recover"] and rivet_receiver_by_window[window_key].has("idle"):
			require(receiver.distance_to(rivet_receiver_by_window[window_key].idle) <= 6.0, label + ": Rivet receiver jumps between active poses")
	var camera: Camera3D = app.player.camera
	var ray_normal := camera.project_ray_normal(CENTER)
	require(ray_normal.distance_to(-camera.global_basis.z) <= 0.0001, label + ": camera center ray moved")
	if weapon != "melee":
		var aim_x := PRESENTATION.line_x_at_y(expected.breech, expected.muzzle, CENTER.y)
		if phase != "switch": require(absf(aim_x - CENTER.x) <= 4.0, label + ": active bore misses camera after recoil")
		if phase == "fire":
			require(app.muzzle_image.visible, label + ": accepted shot has no flash")
			if app.muzzle_image.visible:
				var actual_muzzle: Vector2 = app.muzzle_image.position + app.muzzle_image.size * 0.5
				require(actual_muzzle.distance_to(expected.muzzle) <= 1.5, label + ": actual flash misses authored muzzle")
	var world_rect: Rect2 = PRESENTATION.window_world_rect(window)
	require(app.world_image.position.distance_to(world_rect.position) <= 0.2 and app.world_image.size.distance_to(world_rect.size) <= 0.2, label + ": world letterbox differs")
	var crosshair_center: Vector2 = app.crosshair.position + app.crosshair.size * 0.5
	require(crosshair_center.distance_to(window * 0.5) <= 0.2, label + ": crosshair left physical camera center")

func inspect_actual_main(art: Dictionary) -> void:
	var app: Control = preload("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.enter_combat()
	app.player.set_physics_process(false)
	app.combat.set_physics_process(false)
	for enemy in app.combat.enemies: enemy.set_physics_process(false)
	for weapon in GUNS:
		if weapon not in ["pistol", "shotgun"]: app.combat.grant_weapon(StringName(weapon), 100)
	app.combat.ammo_pistol = 100
	app.combat.ammo_shotgun = 100
	app.combat.ammo_rivets = 100
	app.combat.ammo_rockets = 100
	app.combat.combat_event.connect(on_combat_event)
	for entry in WINDOWS:
		var window: Vector2 = entry
		root.size = Vector2i(window)
		app.size = window
		app.layout_view()
		for weapon in GUNS:
			app.combat.currentweapon = StringName(weapon)
			app.combat.weapon_phase = &"idle"
			app.combat.recoil_remaining = 0.0
			app.combat.cooldown = 0.0
			inspect_main_pose(app, art, weapon, "idle", window)
			var before := shot_events.size()
			require(app.combat.try_fire() and shot_events.size() == before + 1, weapon + ": actual firing rejected")
			if shot_events.size() == before: continue
			var event: Dictionary = shot_events[-1]
			require((event.position as Vector3).distance_to(app.player.camera.global_position) <= 0.0001, weapon + ": actual shot origin changed")
			require((event.direction as Vector3).distance_to(-app.player.camera.global_basis.z) <= 0.0001, weapon + ": actual shot direction changed")
			inspect_main_pose(app, art, weapon, "fire", window)
			app.combat.weapon_phase = &"recover"
			app.combat.recoil_remaining *= 0.5
			app.muzzle_time = 0.0
			inspect_main_pose(app, art, weapon, "recover", window)
			app.combat.weapon_phase = &"switch"
			app.combat.recoil_remaining = 0.0
			inspect_main_pose(app, art, weapon, "switch", window)
	app.free()

func run() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://assets/combat_art.json"))
	if not parsed is Dictionary:
		require(false, "combat_art.json could not be parsed")
		quit(1)
		return
	var art: Dictionary = parsed
	var summary: Dictionary = {}
	for weapon in GUNS:
		var atlas: Dictionary = art.get("weapon_atlases", {}).get(weapon, {})
		require(not atlas.is_empty(), weapon + ": atlas metadata missing")
		if atlas.is_empty(): continue
		if weapon in ["twin_shotgun", "rivet_cannon", "siege_launcher"]:
			var idle_scale := float(atlas.placement.idle.scale)
			for active_phase in ["fire", "recover"]:
				require(is_equal_approx(float(atlas.placement[active_phase].scale), idle_scale), weapon + ": receiver scale changes during active phase " + active_phase)
		summary[weapon] = {}
		for phase in PHASES:
			var placement: Dictionary = atlas.get("placement", {}).get(phase, {})
			var region: Array = atlas.get("regions", {}).get(phase, [])
			require(placement.has("bore"), weapon + "/" + phase + ": authored bore missing")
			if not placement.has("bore") or region.size() != 4: continue
			var bore: Dictionary = placement.bore
			require(bore.has("breech") and bore.has("muzzle"), weapon + "/" + phase + ": breech/muzzle missing")
			if not bore.has("breech") or not bore.has("muzzle"): continue
			var frame_size := Vector2(float(region[2]), float(region[3]))
			var local_breech := PRESENTATION.point(bore.breech)
			var local_muzzle := PRESENTATION.point(bore.muzzle)
			var anchor: Array = art.flash.anchors.get(weapon, {}).get(phase, [])
			require(anchor.size() == 2, weapon + "/" + phase + ": flash anchor missing")
			if anchor.size() == 2:
				var flash_local := PRESENTATION.point(anchor) * frame_size / Vector2(320, 180)
				require(flash_local.distance_to(local_muzzle) <= 0.1, weapon + "/" + phase + ": flash does not originate at authored muzzle")
			require(local_muzzle.y + 20.0 < local_breech.y, weapon + "/" + phase + ": bore does not point forward")
			for local in [local_breech, local_muzzle]:
				require(local.x >= 0.0 and local.x < frame_size.x and local.y >= 0.0 and local.y < frame_size.y, weapon + "/" + phase + ": bore marker outside native frame")
			var projected: Dictionary = PRESENTATION.pose(placement, frame_size, float(atlas.source_canvas_height))
			var residual: float = absf(float(projected.aim_x) - CENTER.x)
			if phase != "switch":
				require(residual <= 1.0, weapon + "/" + phase + ": projected bore misses center by " + str(residual) + " native pixels")
				require(absf(float(projected.alignment_shift_x)) <= 95.0, weapon + "/" + phase + ": alignment requires implausible horizontal pose shift")
			else:
				require(not bool(placement.get("align_bore", true)) and projected.muzzle.y > CENTER.y + 45.0, weapon + "/switch: lowered nonfiring pose expected")
			var screen: Array = []
			for entry in WINDOWS:
				var window: Vector2 = entry
				var aim_screen := PRESENTATION.to_window(Vector2(float(projected.aim_x), CENTER.y), window)
				var center_screen: Vector2 = window * 0.5
				if phase != "switch": require(aim_screen.distance_to(center_screen) <= 2.0, weapon + "/" + phase + ": resized view bore misses camera center")
				screen.append({"window": window, "breech": PRESENTATION.to_window(projected.breech, window), "muzzle": PRESENTATION.to_window(projected.muzzle, window), "aim": aim_screen})
			summary[weapon][phase] = {"native_breech": projected.breech, "native_muzzle": projected.muzzle, "native_aim_x": projected.aim_x, "horizontal_shift": projected.alignment_shift_x, "screens": screen}
	# Combat ray source must remain the camera. This source-level contract catches
	# accidental attempts to hide a bad drawing by moving the shot origin.
	var combat_source := FileAccess.get_file_as_string("res://scripts/combat.gd")
	require(combat_source.contains("var origin := camera.global_position") and combat_source.contains("var forward := -camera.global_basis.z"), "combat shots no longer originate from camera center")
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	require(main_source.contains("res://scripts/weapon_presentation.gd"), "Main does not use bore-aligned weapon presentation")
	inspect_actual_main(art)
	var report_dir := "res://verification/weapon-alignment-v3"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(report_dir))
	var report_file := FileAccess.open(report_dir.path_join("geometry.json"), FileAccess.WRITE)
	if report_file != null:
		report_file.store_string(JSON.stringify({"checks": checks, "failures": failures, "poses": summary, "rivet_receiver_native_by_window": rivet_receiver_by_window}, "  ") + "\n")
		report_file.close()
	print(JSON.stringify({"checks": checks, "failures": failures, "accepted_shots": shot_events.size()}))
	quit(0 if failures.is_empty() else 1)
