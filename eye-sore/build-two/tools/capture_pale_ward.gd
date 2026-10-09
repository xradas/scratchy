extends SceneTree
## Actual rendered world; controlled camera tour makes composition review reproducible.
var app: Control
var evidence_dir := "res://verification/level"
var force_offscreen := false

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-dir="): evidence_dir = argument.trim_prefix("--evidence-dir=")
	force_offscreen = "--force-offscreen-draw" in OS.get_cmdline_user_args()
	call_deferred("capture")

func capture_failed(message: String) -> bool:
	push_error("PALE_WARD_CAPTURE_FAILED: " + message)
	quit(1)
	return false

func photograph(label: String) -> bool:
	var offscreen_required := false
	for i in 12:
		await process_frame
		# Explicit photograph mode only; force_draw completes its draw before returning.
		if force_offscreen:
			offscreen_required = offscreen_required or not DisplayServer.window_can_draw()
			RenderingServer.force_draw(false)
	if not force_offscreen: await RenderingServer.frame_post_draw
	var captured := root.get_texture().get_image()
	if captured == null or captured.is_empty(): return capture_failed("Empty native viewport for " + label)
	var error := captured.save_png(evidence_dir + "/" + label + ".png")
	if error != OK: return capture_failed("PNG save failed for " + label + ": " + error_string(error))
	print("PALE_WARD_PHOTOGRAPH_OK: label=", label, " forced_offscreen=", force_offscreen, " offscreen_required=", offscreen_required)
	return true

func capture() -> void:
	if DisplayServer.get_name() == "headless":
		capture_failed("Photographs require a native renderer")
		return
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	app = preload("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.enter_combat()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	app.player.set_physics_process(false)
	app.combat.set_physics_process(false)
	for enemy in app.combat.enemies: enemy.set_physics_process(false)
	app.combat.currentweapon = &"shotgun"
	app.player.rotation = Vector3.ZERO
	app.player.camera.rotation = Vector3.ZERO
	if not await photograph("containment-entry"): return
	var poses := {
		"containment-stairs": [Vector3(0, .87, -3), Vector3(0, 3, -18)],
		"bio-wing": [Vector3(11, .87, 5), Vector3(19, 1.8, -2)],
		"operating-room": [Vector3(22, .87, -1), Vector3(17, 1.4, -6)],
		"rear-lab": [Vector3(0, 2.37, -18.5), Vector3(-4.5, 3, -26.5)],
		"exit-gallery": [Vector3(4, 5.37, -24.5), Vector3(-4, 5.8, -28)]
	}
	for label in poses:
		app.player.position = poses[label][0]
		app.player.camera.look_at(poses[label][1])
		if not await photograph(label): return
	print("PALE_WARD_CAPTURE_OK: actual geometry/lighting/materials and gameplay sprites; render_scope=", "forced offscreen native rendering" if force_offscreen else "ordinary native rendering")
	await app.quit_game()
