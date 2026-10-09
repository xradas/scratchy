extends SceneTree
## Native rendered-frame evidence for the real Combat light, at fixed 60 Hz physics.
var app: Control
var active := false
var ticks := 0
var accepted: Array[Dictionary] = []
var rejected := 0
var dark_rejected := 0
var draws: Array[int] = []
var failures: Array[String] = []
var light_id := 0
var sample_draws := false
var results: Array[Dictionary] = []
var force_offscreen := false
var output_stem := "p14-shot-lighting-native"
var evidence_path := ""
var total_completed_draws := 0

func request_forced_draw() -> void:
	if force_offscreen and not DisplayServer.window_can_draw():
		call_deferred("force_native_draw")

func force_native_draw() -> void:
	if force_offscreen and not DisplayServer.window_can_draw():
		RenderingServer.force_draw(false)

func _initialize() -> void:
	call_deferred("run_profile")

func require(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func pulse() -> void:
	if not active: return
	ticks += 1
	var lighting: Node3D = app.combat.weapon_lighting
	var before: float = lighting.remaining
	var previous_id: int = lighting.active_shot_id
	var was_visible: bool = lighting.flash.visible
	if app.combat.try_fire():
		accepted.append({"shot_id":app.combat.shot_counter, "physics_tick":ticks, "accepted_usec":Time.get_ticks_usec(), "rendered_flash_frames":0, "visible_draw_usec":[], "first_dark_draw_usec":0})
		require(lighting.flash.visible, "Accepted shot did not enable light")
		before = lighting.remaining
		previous_id = lighting.active_shot_id
		was_visible = lighting.flash.visible
		# A second actual call on the same tick must reject without refreshing.
		require(not app.combat.try_fire(), "Immediate repeated shot accepted")
	else:
		rejected += 1
		if not was_visible: dark_rejected += 1
	require(lighting.remaining == before and lighting.active_shot_id == previous_id and lighting.flash.visible == was_visible, "Rejected shot changed light state")
	require(lighting.flash.get_instance_id() == light_id and lighting.get_child_count() == 1, "Shot replaced or allocated another light")

func rendered() -> void:
	total_completed_draws += 1
	if not sample_draws or not is_instance_valid(app): return
	var now := Time.get_ticks_usec()
	draws.append(now)
	if accepted.is_empty(): return
	var shot: Dictionary = accepted.back()
	var lighting: Node3D = app.combat.weapon_lighting
	if lighting.flash.visible:
		require(lighting.active_shot_id == shot.shot_id, "Rendered light belongs to wrong shot")
		shot.rendered_flash_frames += 1
		shot.visible_draw_usec.append(now)
	elif shot.first_dark_draw_usec == 0:
		shot.first_dark_draw_usec = now

func run_profile() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-path="):
			evidence_path = argument.trim_prefix("--evidence-path=")
			if evidence_path.is_empty():
				require(false, "--evidence-path requires a nonempty path")
				quit(1)
				return
	force_offscreen = "--force-offscreen-draw" in OS.get_cmdline_user_args()
	if force_offscreen:
		output_stem = "p14-shot-lighting-forced-offscreen"
		process_frame.connect(request_forced_draw)
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	root.size = Vector2i(1280, 720)
	root.mode = Window.MODE_WINDOWED
	root.position = Vector2i(40, 40)
	root.show()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.physics_ticks_per_second = 60
	physics_frame.connect(pulse)
	RenderingServer.frame_post_draw.connect(rendered)
	for cap in [30, 60, 120]:
		for weapon in [&"pistol", &"shotgun"]:
			Engine.max_fps = cap
			app = preload("res://scenes/main.tscn").instantiate()
			root.add_child(app)
			app.enter_combat()
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			app.player.set_physics_process(false)
			app.player.position = Vector3(0, 0.87, 14)
			app.player.rotation = Vector3(0, PI, 0)
			app.player.camera.rotation = Vector3.ZERO
			# Aim behind the encounter; disable enemy AI, retain room/art rendering.
			for enemy in app.combat.enemies: enemy.set_physics_process(false)
			app.combat.currentweapon = weapon
			light_id = app.combat.weapon_lighting.flash.get_instance_id()
			require(app.world_view.size == Vector2i(640, 360), "World viewport differs from current 640x360")
			await create_timer(0.4).timeout
			print("NATIVE_DRAW_STATE: ", DisplayServer.window_can_draw(), " root_visible=", root.visible, " mode=", root.mode, " position=", root.position, " render_loop=", RenderingServer.is_render_loop_enabled(), " frames=", Engine.get_frames_drawn())
			if (not DisplayServer.window_can_draw() and not force_offscreen) or total_completed_draws == 0:
				require(false, "Native renderer unavailable: window minimized/not drawable and no completed renders after warm-up. Flash visibility and cap performance are unverified.")
				write_report()
				app.combat_audio.stop_all()
				app.free()
				quit(1)
				return
			ticks = 0
			accepted.clear()
			draws.clear()
			rejected = 0
			dark_rejected = 0
			var started := Time.get_ticks_usec()
			var start_draw := Engine.get_frames_drawn()
			sample_draws = true
			active = true
			while ticks < 120: await physics_frame
			active = false
			var finished := Time.get_ticks_usec()
			var engine_draws := Engine.get_frames_drawn() - start_draw
			var completed_draws := draws.size()
			# Finish observing the last accepted flash, without extending performance interval.
			await create_timer(0.15).timeout
			sample_draws = false
			var seconds := float(finished - started) / 1000000.0
			var max_draw_interval := 0.0
			for index in range(1, draws.size()):
				max_draw_interval = maxf(max_draw_interval, float(draws[index] - draws[index - 1]) / 1000000.0)
			var duration := 0.055 if weapon == &"pistol" else 0.08
			for shot in accepted:
				shot.expiry_seconds = float(shot.first_dark_draw_usec - shot.accepted_usec) / 1000000.0
				shot.expiry_limit_seconds = duration + 1.0 / cap + 0.003
				shot.last_visible_seconds = float(shot.visible_draw_usec.back() - shot.accepted_usec) / 1000000.0 if not shot.visible_draw_usec.is_empty() else -1.0
				require(shot.rendered_flash_frames > 0, "Accepted %s at cap%d had no rendered flash frame" % [weapon, cap])
				require(shot.first_dark_draw_usec > 0 and shot.expiry_seconds <= shot.expiry_limit_seconds, "Flash expiry exceeded duration plus one requested-cap render interval: %s cap%d shot%d (%.6fs > %.6fs)" % [weapon, cap, shot.shot_id, shot.expiry_seconds, shot.expiry_limit_seconds])
			var expected_shots := 6 if weapon == &"pistol" else 3
			var expected_ammo := 36 - expected_shots if weapon == &"pistol" else 12 - expected_shots
			var ammo: int = app.combat.ammo_pistol if weapon == &"pistol" else app.combat.ammo_shotgun
			require(app.combat.shot_counter == expected_shots and ammo == expected_ammo, "Fixed-tick shot/ammo cadence changed: %s cap%d" % [weapon, cap])
			require(app.combat.kills == 0, "Controlled aim killed an enemy")
			require(completed_draws / seconds >= cap * 0.90, "Native room did not achieve 90%% of requested cap%d" % cap)
			# An actual dry-fire rejection after the light has expired stays dark.
			app.combat.set(String(app.combat.weapons[weapon].ammo_key), 0)
			app.combat.cooldown = 0.0
			require(not app.combat.try_fire() and not app.combat.weapon_lighting.flash.visible and app.combat.weapon_lighting.remaining == 0.0, "Dry fire generated flash")
			results.append({"cap":cap, "weapon":weapon, "physics_ticks":ticks, "elapsed_seconds":seconds, "engine_rendered_frames":engine_draws, "completed_render_frames":completed_draws, "achieved_fps":completed_draws / seconds, "max_render_interval_seconds":max_draw_interval, "shots":app.combat.shot_counter, "ammo_after_cadence":ammo, "rejected_attempts":rejected, "dark_rejected_attempts":dark_rejected, "duration_seconds":duration, "light_instance_id":light_id, "owned_light_count":app.combat.weapon_lighting.get_child_count(), "accepted_shots":accepted.duplicate(true)})
			app.menu_music.stop()
			app.menu_music.stream = null
			app.combat_audio.stop_all()
			app.free()
			app = null
			await create_timer(0.1).timeout
	write_report()
	print("SHOT_LIGHTING_NATIVE_", "OK" if failures.is_empty() else "FAILED", ": ", results.size(), " cap/weapon cases; ", failures)
	quit(0 if failures.is_empty() else 1)

func write_report() -> void:
	var destination := evidence_path if not evidence_path.is_empty() else "res://verification/grit/" + output_stem + ".json"
	var absolute := ProjectSettings.globalize_path(destination)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if directory_error != OK:
		require(false, "Could not create evidence directory %s: error %d" % [absolute.get_base_dir(), directory_error])
		return
	var file := FileAccess.open(destination, FileAccess.WRITE)
	if file == null:
		require(false, "Could not open evidence report %s: error %d" % [destination, FileAccess.get_open_error()])
		return
	file.store_string(JSON.stringify({"scope":"Native current main scene, 640x360 world and current screen shader; vsync disabled, no-focus window; 60Hz physics, actual Combat.try_fire every tick, aim behind encounter, enemy AI disabled. frame_post_draw records the actual light state submitted for each completed render; does not measure pixel brightness or sustained AI gameplay. Expiry bound is duration plus one requested-cap render interval plus 3ms scheduling tolerance; actual longest draw interval is reported independently so a render hitch cannot relax the expiry check.", "render_mode":"forced offscreen native OpenGL; force_draw(false) after process nodes on each process-frame cadence while minimized; FPS measures offscreen rendering, not visible-window presentation" if force_offscreen else "ordinary native visible-window rendering", "adapter":RenderingServer.get_video_adapter_name(), "renderer_drawable":DisplayServer.window_can_draw(), "window_mode":root.mode, "total_engine_frames":Engine.get_frames_drawn(), "total_completed_draws":total_completed_draws, "results":results, "failures":failures}, "  ") + "\n")
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		require(false, "Could not write evidence report %s: error %d" % [destination, write_error])
