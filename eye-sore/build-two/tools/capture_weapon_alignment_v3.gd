extends SceneTree
## Native Main captures. Fire/recover follow an accepted Combat shot; idle and
## optional switch are controlled poses. No campaign-route evidence is claimed.
## tools/godot.sh --script tools/capture_weapon_alignment_v3.gd -- --force-offscreen-draw

const WEAPONS := ["pistol", "shotgun", "melee", "twin_shotgun", "rivet_cannon", "siege_launcher"]
const PHASES := ["idle", "fire", "recover", "switch"]
const WINDOWS := [Vector2i(1280, 720)]
const WARMUP := 8
var evidence_dir := "res://verification/weapon-alignment-v3/captures"
var force_offscreen := false
var requested_weapons := ["twin_shotgun", "rivet_cannon", "siege_launcher"]
var requested_phases := ["idle", "fire", "recover"]
var app: Control
var report := {"scope":"Native Main scene, forced visual phases; no accepted-shot or gameplay-route claim.","captures":[],"failures":[]}

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-dir="): evidence_dir = argument.trim_prefix("--evidence-dir=")
		if argument == "--force-offscreen-draw": force_offscreen = true
		if argument.begins_with("--weapons="): requested_weapons = argument.trim_prefix("--weapons=").split(",")
		if argument.begins_with("--phases="): requested_phases = argument.trim_prefix("--phases=").split(",")
	call_deferred("capture")

func fail(message: String) -> void:
	report.failures.append(message)
	push_error("WEAPON_ALIGNMENT_CAPTURE_FAILED: " + message)
	quit(1)

func xy(value: Vector2) -> Array:
	return [value.x, value.y]

func capture() -> void:
	if DisplayServer.get_name() == "headless":
		fail("Native renderer required")
		return
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence_dir)) != OK:
		fail("Cannot create evidence directory")
		return
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	root.size = WINDOWS[0]
	app = preload("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.enter_combat()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	app.player.set_physics_process(false)
	for enemy in app.combat.enemies: enemy.set_physics_process(false)
	for weapon in WEAPONS:
		if not app.combat.has_weapon(StringName(weapon)): app.combat.grant_weapon(StringName(weapon), 100)
	app.combat.ammo_pistol = 100
	app.combat.ammo_shotgun = 100
	app.combat.ammo_rivets = 100
	app.combat.ammo_rockets = 100
	for window in WINDOWS:
		root.size = window
		app.size = window
		app.layout_view()
		for weapon in requested_weapons:
			if weapon not in WEAPONS:
				fail("Unknown weapon " + weapon)
				return
			for phase in requested_phases:
				if phase not in PHASES:
					fail("Unknown phase " + phase)
					return
				app.combat.currentweapon = StringName(weapon)
				app.combat.cooldown = 0.0
				if phase == "fire":
					paused = false
					app.combat.weapon_phase = &"idle"
					if not app.combat.try_fire():
						fail("Accepted shot missing for " + weapon)
						return
				elif phase == "recover":
					if app.combat.weapon_phase != &"fire":
						paused = false
						app.combat.weapon_phase = &"idle"
						if not app.combat.try_fire():
							fail("Accepted shot missing before recovery for " + weapon)
							return
					paused = false
					app.combat._physics_process(float(app.combat.weapons[StringName(weapon)].fire_seconds) + 0.001)
					app.muzzle_time = 0.0
				else:
					app.combat.weapon_phase = StringName(phase)
					app.combat.recoil_remaining = 0.0
					app.muzzle_time = 0.0
				app.texture_cache.clear()
				app.weapon_image.texture = null
				paused = true
				app._process(0.0)
				for frame in WARMUP:
					await process_frame
					if force_offscreen or not DisplayServer.window_can_draw(): RenderingServer.force_draw(false)
				if not force_offscreen and DisplayServer.window_can_draw(): await RenderingServer.frame_post_draw
				var screenshot := root.get_texture().get_image()
				if screenshot == null or screenshot.is_empty() or screenshot.get_size() != window:
					fail("Empty or incorrectly sized frame: %s/%s %s" % [weapon,phase,window])
					return
				var file := "%s-%s-%dx%d.png" % [weapon, phase, window.x, window.y]
				var path := evidence_dir.path_join(file)
				if screenshot.save_png(path) != OK:
					fail("Could not save " + path)
					return
				var record := {"weapon":weapon,"phase":phase,"window":[window.x,window.y],"file":path,"sha256":FileAccess.get_sha256(path),"world_rect":xy(app.world_image.position)+xy(app.world_image.size),"crosshair_center":xy(app.crosshair.position+app.crosshair.size*0.5),"sprite_position_native":xy(app.weapon_image.position),"sprite_size_native":xy(app.weapon_image.size),"muzzle_visible":app.muzzle_image.visible,"recoil_remaining":app.combat.recoil_remaining,"last_accepted_shot_id":app.combat.shot_counter}
				if app.muzzle_image.visible: record.muzzle_center_native = xy(app.muzzle_image.position+app.muzzle_image.size*0.5)
				var atlas: Dictionary = app.art_data.weapon_atlases.get(weapon, {})
				if not atlas.is_empty() and atlas.placement[phase].has("receiver"):
					var source_width: float = float(atlas.regions[phase][2])
					var receiver: Vector2 = app.weapon_image.position + Vector2(atlas.placement[phase].receiver[0], atlas.placement[phase].receiver[1]) * app.weapon_image.size.x / source_width
					record.receiver_native = xy(receiver)
					record.receiver_fraction_of_native = xy(receiver / Vector2(640, 360))
				report.captures.append(record)
				print("WEAPON_ALIGNMENT_CAPTURE: ", file)
	var output := FileAccess.open(evidence_dir.path_join("capture-state.json"), FileAccess.WRITE)
	if output == null:
		fail("Could not save capture report")
		return
	output.store_string(JSON.stringify(report, "  ") + "\n")
	output.close()
	print("WEAPON_ALIGNMENT_CAPTURE_OK: ", report.captures.size(), " native Main frames")
	quit(0)
