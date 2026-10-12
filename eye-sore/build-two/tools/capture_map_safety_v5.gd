extends SceneTree
## Actual Main/native controlled map presentation. No route or safety proof.
var app: Control
var output := "res://verification/map-safety-v5/art"
var captures: Array[Dictionary] = []
var failures: Array[String] = []
const SOURCES := ["res://scenes/campaign/pale_ward_01.tscn", "res://scripts/main.gd", "res://scripts/ward_lift.gd", "res://scripts/lift_landing_gate.gd", "res://scripts/stage_level.gd", "res://resources/campaign/pale_ward_01-route.json"]
func _initialize() -> void:
	call_deferred("run")
func xyz(v: Vector3) -> Array: return [v.x, v.y, v.z]
func save_report() -> void:
	var hashes: Dictionary = {}
	for path in SOURCES: hashes[path] = FileAccess.get_sha256(path)
	var file := FileAccess.open(output.path_join("captures.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"status":"passed" if failures.is_empty() else "failed", "scope":"Actual Main/native Compatibility, Ward01 controlled camera/map presentation. AI and player physics frozen. Declared exit_control/clear_final_arena flags bypass progression. Lift travels through its real activate API and native physics ticks. Images establish presentation only, not ordinary route, combat, passenger interlock safety or human approval.", "display_server":DisplayServer.get_name(), "video_adapter":RenderingServer.get_video_adapter_name(), "window_no_focus":root.get_flag(Window.FLAG_NO_FOCUS), "window_mode":root.mode, "script_sha256":FileAccess.get_sha256("res://tools/capture_map_safety_v5.gd"), "source_hashes":hashes, "captures":captures, "failures":failures}, "  ")+"\n")
		file.close()
func fail(message: String) -> void:
	failures.append(message); push_error("MAP_NATIVE_CAPTURE_FAILED: "+message); save_report(); quit(1)
func pose(eye: Vector3, target: Vector3) -> void:
	app.player.rotation = Vector3.ZERO; app.player.camera.rotation = Vector3.ZERO
	app.player.global_position = eye-app.player.camera.position; app.player.camera.look_at(target)
	for enemy in app.combat.enemies: enemy.update_presentation()
func gate_state(node: Node) -> Dictionary:
	return {"opened":node.opened, "visual_visible":node.get_node("Visual").visible, "collision_disabled":node.get_node("Collision").disabled, "position":xyz(node.global_position)}
func picture(label: String, fixture: String) -> bool:
	paused = true; app._process(0.0)
	for frame in 12: await process_frame; RenderingServer.force_draw(false)
	var full_image := root.get_texture().get_image()
	var world_image: Image = app.world_view.get_texture().get_image()
	if full_image == null or full_image.is_empty() or world_image == null or world_image.is_empty(): fail("Empty image "+label); return false
	var full := output.path_join("pale_ward_01-"+label+".png")
	var raw := output.path_join("pale_ward_01-"+label+"-world.png")
	if full_image.save_png(full) != OK or world_image.save_png(raw) != OK: fail("Cannot save "+label); return false
	var lift: Node3D = app.world.get_node("Lift_Observation")
	captures.append({"label":label,"fixture":fixture,"window_png":full,"world_png":raw,"window_sha256":FileAccess.get_sha256(full),"world_sha256":FileAccess.get_sha256(raw),"window_dimensions":[full_image.get_width(),full_image.get_height()],"world_dimensions":[world_image.get_width(),world_image.get_height()],"scene_sha256":FileAccess.get_sha256(app.world.scene_file_path),"camera_position":xyz(app.player.camera.global_position),"camera_rotation":xyz(app.player.camera.global_rotation),"actor_position":xyz(app.player.global_position),"ai_physics_frozen":true,"player_physics_frozen":true,"tree_paused_for_image":paused,"declared_progression_flags":{"exit_control":true,"clear_final_arena":true},"lift":{"origin":xyz(lift.origin),"position":xyz(lift.position),"upper":lift.upper,"moving":lift.moving,"obstructed":lift.obstructed,"departure_pending":lift.departure_pending},"lower_guard":gate_state(app.world.get_node("LiftLowerLandingGate")),"upper_guard":gate_state(app.world.get_node("LiftUpperLandingGate")),"hud_text":app.hud.text})
	save_report(); print("MAP_NATIVE_PHOTO_OK: ",label); return true
func travel_lift(expected_upper: bool) -> bool:
	paused = false
	var lift: Node = app.world.get_node("Lift_Observation")
	if not lift.activate(): fail("Lift activation refused with controlled actor clear of entrances"); return false
	for tick in 600:
		await physics_frame
		if not lift.moving:
			await physics_frame
			if lift.upper != expected_upper or lift.obstructed: fail("Unexpected lift destination"); return false
			return true
	fail("Lift travel timeout"); return false
func run() -> void:
	if DisplayServer.get_name() == "headless": fail("Native renderer required"); return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.set_flag(Window.FLAG_NO_FOCUS,true); root.size = Vector2i(1280,720); root.mode = Window.MODE_MINIMIZED
	app = load("res://scenes/main.tscn").instantiate(); root.add_child(app)
	paused = true; app.campaign.seek("pale_ward_01"); app.campaign_mode = true; app.stage_id = "pale_ward"; app.level_complete = false
	app.replace_world({}); app.enter_combat(); app.automated_input = true
	app.player.set_physics_process(false); app.player.velocity = Vector3.ZERO
	for enemy in app.combat.enemies: enemy.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE; root.set_flag(Window.FLAG_NO_FOCUS,true); root.mode = Window.MODE_MINIMIZED
	app.world.flags["exit_control"] = true; app.world.flags["clear_final_arena"] = true
	var exit_door: Node = app.world.get_node("Door_exit_gate")
	if not exit_door.activate(app.world.flags): fail("Controlled exit door fixture refused"); return
	paused = false
	for tick in 150: await physics_frame
	pose(Vector3(0,3.1,-222),Vector3(1.5,3.65,-230))
	if not await picture("c3-exit-stairs","Controlled lower stair approach showing authored exit wayfinding, downlight, native stair treads and upper landing; real door opened with declared exit_control flag."): return
	pose(Vector3(21.5,3.05,-210.1),Vector3(26.4,3.35,-209.8))
	if not await travel_lift(true): return
	var lower: Node = app.world.get_node("LiftLowerLandingGate")
	if lower.opened or lower.get_node("Collision").disabled: fail("Lower guard not closed while platform upper"); return
	if not await picture("lower-guard-platform-away","Controlled lower approach: actual lift travelled to upper dock; lower visible guard and physical collider closed. Physical outside call plate/sign and shaft floor are authored geometry."): return
	pose(Vector3(32.5,7.5,-210.5),Vector3(28,6.8,-209.7))
	if not await travel_lift(false): return
	var upper: Node = app.world.get_node("LiftUpperLandingGate")
	if upper.opened or upper.get_node("Collision").disabled: fail("Upper guard not closed while platform lower"); return
	if not await picture("upper-guard-platform-away","Controlled upper approach: actual lift travelled to lower dock; upper visible guard and physical collider closed, with outside call plate/sign."): return
	save_report(); print("MAP_NATIVE_CAPTURE_OK: ",captures.size()," views"); await app.quit_game()
