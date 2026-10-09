extends SceneTree
## Real integrated scene captures; controlled enemy placement for readable comparison.
var app: Control
var prefix := "art"

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-prefix="): prefix = argument.trim_prefix("--capture-prefix=")
	call_deferred("run_capture")

func photograph(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(image.save_png("res://verification/combat/" + prefix + "-" + label + ".png") == OK)

func run_capture() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	app = preload("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await photograph("title")
	app.enter_combat()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	app.player.set_physics_process(false)
	app.combat.set_physics_process(false)
	app.player.position = Vector3(0, 0.87, 14)
	app.player.rotation = Vector3.ZERO
	app.player.camera.rotation = Vector3.ZERO
	var left: CharacterBody3D = app.combat.enemies[0]
	var right: CharacterBody3D = app.combat.enemies[1]
	left.set_physics_process(false)
	right.set_physics_process(false)
	left.position = Vector3(-1.5,0.87,9.5)
	right.position = Vector3(1.8,0.87,7.0)
	left.rotation.y = PI
	right.rotation.y = PI
	left.state_time = 0.0
	right.state_time = 0.0
	left.update_presentation()
	right.update_presentation()
	await physics_frame
	await physics_frame
	await photograph("pistol")
	app.combat.currentweapon = &"shotgun"
	await photograph("shotgun")
	app.combat.cooldown = 0
	app.combat.weapon_phase = &"idle"
	assert(app.combat.try_fire())
	await photograph("shotgun-fire")
	assert(app.muzzle_image.visible, "Accepted firing event did not reach a visible muzzle frame")
	app.combat.weapon_phase = &"idle"
	app.combat.recoil_remaining = 0
	app.combat.currentweapon = &"melee"
	await photograph("melee")
	app.combat.currentweapon = &"shotgun"
	left.change_state(&"windup")
	left.state_time = left.definition.windup_seconds * 0.75
	left.update_presentation()
	right.change_state(&"windup")
	right.state_time = right.definition.windup_seconds * 0.75
	right.update_presentation()
	await photograph("windup")
	left.change_state(&"dead")
	left.state_time = 1.0
	left.update_presentation()
	right.change_state(&"dead")
	right.state_time = 1.0
	right.update_presentation()
	await photograph("corpses")
	print("ART_CAPTURE_OK: actual integrated viewport; controlled idle/weapon/windup/corpse captures, not concept overlays or a complete playtest")
	await app.quit_game()
