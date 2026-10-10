extends SceneTree
## Native, integrated candidate-weapon captures. No production manifest is changed.

const PHYSICS_STEP := 1.0 / 60.0
const WARMUP_FRAMES := 12

var app: Control
var manifest_path := "res://concepts/weapon-style-v3/candidate-combat-art.json"
var evidence_dir := "res://verification/weapon-style-v3/captures"
var force_offscreen := false
var offscreen_required := false
var events: Array[Dictionary] = []
var captures: Array[Dictionary] = []
var manifest: Dictionary = {}

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--manifest="): manifest_path = argument.trim_prefix("--manifest=")
		if argument.begins_with("--evidence-dir="): evidence_dir = argument.trim_prefix("--evidence-dir=")
	force_offscreen = "--force-offscreen-draw" in OS.get_cmdline_user_args()
	call_deferred("capture")

func fail(message: String) -> bool:
	push_error("WEAPON_STYLE_CAPTURE_FAILED: " + message)
	quit(1)
	return false

func require(condition: bool, message: String) -> bool:
	if not condition: return fail(message)
	return true

func read_manifest() -> bool:
	if not FileAccess.file_exists(manifest_path): return fail("Missing manifest: " + manifest_path)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not parsed is Dictionary: return fail("Manifest is not a JSON object: " + manifest_path)
	manifest = parsed
	for weapon in ["pistol", "shotgun"]:
		if not manifest.get("weapons", {}).has(weapon): return fail("Missing weapon: " + weapon)
		if not manifest.get("weapon_atlases", {}).has(weapon): return fail("Missing atlas definition: " + weapon)
		for phase in ["idle", "fire", "recover", "switch"]:
			var path: String = manifest.weapons[weapon].get(phase, "")
			if path.is_empty() or not ResourceLoader.exists(path): return fail("Missing %s %s texture: %s" % [weapon, phase, path])
	return true

func on_event(event: Dictionary) -> void:
	if event.get("type") in [&"shot", &"weapon_switch"]:
		var record := {
			"type": String(event.type),
			"weapon_id": String(event.weapon_id),
			"shot_id": int(event.get("shot_id", 0)),
			"physics_tick": int(event.get("physics_tick", Engine.get_physics_frames()))
		}
		events.append(record)

func wait_for_phase(phase: StringName, weapon: StringName, maximum_ticks: int = 120) -> bool:
	for tick in maximum_ticks:
		await physics_frame
		if app.combat.currentweapon == weapon and app.combat.weapon_phase == phase:
			return true
	return fail("Timed out awaiting %s %s phase" % [weapon, phase])

func wait_ready(weapon: StringName, maximum_ticks: int = 120) -> bool:
	for tick in maximum_ticks:
		await physics_frame
		if app.combat.currentweapon == weapon and app.combat.weapon_phase == &"idle" and app.combat.cooldown <= 0.0:
			return true
	return fail("Timed out awaiting %s idle/cooldown" % weapon)

func photograph(label: String, weapon: StringName, phase: StringName, event_index: int = -1) -> bool:
	if not require(app.combat.currentweapon == weapon and app.combat.weapon_phase == phase, "Wrong state at %s: %s %s" % [label, app.combat.currentweapon, app.combat.weapon_phase]): return false
	# Freeze the simulation at the achieved gameplay phase. This keeps the native
	# presentation stable through the window compositor's twelve-frame warmup.
	paused = true
	app._process(0.0)
	for frame in WARMUP_FRAMES:
		await process_frame
		if force_offscreen:
			offscreen_required = offscreen_required or not DisplayServer.window_can_draw()
			RenderingServer.force_draw(false)
	if not force_offscreen: await RenderingServer.frame_post_draw
	var state: Dictionary = app.combat.get_hud_state()
	if not require(state.weapon_id == weapon and state.weapon_phase == phase, "State drifted while photographing " + label): return false
	if not require(app.weapon_image.visible and app.weapon_image.texture != null, "Weapon texture absent at " + label): return false
	if phase == &"fire" and not require(app.muzzle_image.visible and app.muzzle_time > 0, "Accepted fire lacks visible muzzle at " + label): return false
	var image := root.get_texture().get_image()
	if not require(image != null and not image.is_empty(), "Empty native viewport at " + label): return false
	if not require(image.get_width() == root.size.x and image.get_height() == root.size.y, "Unexpected screenshot dimensions at " + label): return false
	var file_name := label + ".png"
	if not require(image.save_png(evidence_dir.path_join(file_name)) == OK, "PNG save failed at " + label): return false
	var last_event: Dictionary = events[event_index] if event_index >= 0 else {}
	captures.append({
		"file": file_name,
		"weapon": String(weapon),
		"phase": String(phase),
		"phase_progress": float(state.phase_progress),
		"shot_id": int(last_event.get("shot_id", 0)),
		"trigger_event": last_event,
		"ammo_pistol": int(state.ammo_pistol),
		"ammo_shotgun": int(state.ammo_shotgun),
		"weapon_visual_path": String(state.weapon_visual_path),
		"muzzle_visible": app.muzzle_image.visible,
		"simulation_frozen": paused,
		"scene_tree_paused": paused,
		"window_size": [image.get_width(), image.get_height()],
		"world_view_size": [app.world_view.size.x, app.world_view.size.y],
		"world_image_size": [app.world_image.size.x, app.world_image.size.y],
		"world_image_position": [app.world_image.position.x, app.world_image.position.y],
		"weapon_image_position": [app.weapon_image.position.x, app.weapon_image.position.y],
		"weapon_image_size": [app.weapon_image.size.x, app.weapon_image.size.y]
	})
	print("WEAPON_STYLE_PHOTOGRAPH_OK: ", label, " phase=", phase, " ammo=", state.ammo_pistol, "/", state.ammo_shotgun, " window=", image.get_size())
	return true

func capture() -> void:
	if DisplayServer.get_name() == "headless":
		fail("Captures require a native renderer")
		return
	if not read_manifest(): return
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence_dir)) != OK:
		fail("Cannot create evidence directory: " + evidence_dir)
		return
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	app = preload("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.enter_combat()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Candidate weapons only. Enemy visual setup stays as loaded by the game.
	app.art_data = manifest
	app.combat.configure_weapon_visuals(manifest.get("weapons", {}))
	app.texture_cache.clear()
	app.weapon_image.texture = null
	app.muzzle_image.texture = null
	app.player.set_physics_process(false)
	for enemy in app.combat.enemies: enemy.set_physics_process(false)
	app.player.rotation = Vector3.ZERO
	app.player.camera.rotation = Vector3.ZERO
	app.combat.combat_event.connect(on_event)
	if not await photograph("pistol-idle", &"pistol", &"idle"): return
	paused = false
	var pistol_before: int = app.combat.ammo_pistol
	if not require(app.combat.try_fire(), "Pistol trigger was rejected"): return
	if not require(app.combat.ammo_pistol == pistol_before - 1 and events.size() == 1 and events[-1].type == "shot", "Pistol accepted event/ammo mismatch"): return
	if not await photograph("pistol-fire", &"pistol", &"fire", events.size() - 1): return
	paused = false
	if not await wait_for_phase(&"recover", &"pistol"): return
	if not await photograph("pistol-recover", &"pistol", &"recover", 0): return
	paused = false
	if not await wait_ready(&"pistol"): return
	if not require(app.combat.select_weapon(&"shotgun"), "Shotgun switch was rejected"): return
	if not require(events.size() == 2 and events[-1].type == "weapon_switch", "Shotgun switch event missing"): return
	if not await photograph("shotgun-switch", &"shotgun", &"switch", events.size() - 1): return
	paused = false
	if not await wait_ready(&"shotgun"): return
	if not await photograph("containment-entry", &"shotgun", &"idle"): return
	if not await photograph("shotgun-idle", &"shotgun", &"idle"): return
	paused = false
	var shotgun_before: int = app.combat.ammo_shotgun
	if not require(app.combat.try_fire(), "Shotgun trigger was rejected"): return
	if not require(app.combat.ammo_shotgun == shotgun_before - 1 and events.size() == 3 and events[-1].type == "shot", "Shotgun accepted event/ammo mismatch"): return
	if not await photograph("shotgun-fire", &"shotgun", &"fire", events.size() - 1): return
	paused = false
	if not await wait_for_phase(&"recover", &"shotgun"): return
	if not await photograph("shotgun-recover", &"shotgun", &"recover", events.size() - 1): return
	paused = false
	if not await wait_ready(&"shotgun"): return
	if not require(app.combat.select_weapon(&"pistol"), "Pistol switch was rejected"): return
	if not require(events.size() == 4 and events[-1].type == "weapon_switch", "Pistol switch event missing"): return
	if not await photograph("pistol-switch", &"pistol", &"switch", events.size() - 1): return
	var report := {
		"scope": "Native full-window screenshots of the real main scene and accepted gameplay events. Candidate weapon art only; runtime manifest unchanged.",
		"manifest": manifest_path,
		"render": {"display_server": DisplayServer.get_name(), "force_offscreen_draw": force_offscreen, "offscreen_required": offscreen_required, "window_can_draw": DisplayServer.window_can_draw(), "warmup_frames": WARMUP_FRAMES, "native_world_size": [640, 360]},
		"events": events,
		"captures": captures
	}
	var report_file := FileAccess.open(evidence_dir.path_join("capture-state.json"), FileAccess.WRITE)
	if not require(report_file != null, "Cannot save capture-state.json"): return
	report_file.store_string(JSON.stringify(report, "  ") + "\n")
	report_file.close()
	print("WEAPON_STYLE_CAPTURE_OK: ", captures.size(), " actual full-window screenshots; events=", events.size(), " forced_offscreen=", force_offscreen, " offscreen_required=", offscreen_required)
	await app.quit_game()
