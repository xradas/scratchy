extends SceneTree
## Actual rendered world; controlled camera tour makes composition review reproducible.
var app: Control

func _initialize() -> void:
	call_deferred("capture")

func photograph(label: String) -> void:
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://verification/level/" + label + ".png") == OK)

func capture() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	app = preload("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.enter_combat()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	app.player.set_physics_process(false)
	app.combat.set_physics_process(false)
	for enemy in app.combat.enemies: enemy.set_physics_process(false)
	app.combat.currentweapon = &"shotgun"
	app.player.position = Vector3(0, 0.87, 15)
	app.player.rotation = Vector3.ZERO
	app.player.camera.rotation = Vector3.ZERO
	await photograph("containment-entry")
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
		await photograph(label)
	print("PALE_WARD_CAPTURE_OK: actual geometry/lighting/materials and gameplay sprites")
	await app.quit_game()
