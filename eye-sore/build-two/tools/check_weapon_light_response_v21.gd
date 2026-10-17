extends SceneTree
## The first-person painted gun must respond to live mounted lights at the
## player's position, while muzzle flash brightens only its accepted lifetime.

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var app: Control = preload("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	var fixture: Node3D
	for node in get_nodes_in_group("intake_lighting_v11"):
		if node.fixture_kind == "tube" and is_instance_valid(node.light) and node.light.light_energy > 0.0:
			fixture = node
			break
	assert(is_instance_valid(fixture), "Pale Ward mounted light missing")
	var prior: Vector3 = app.player.global_position
	app.player.global_position = Vector3(1000, 2, 1000)
	var dark: Color = app.weapon_light_tint()
	app.player.global_position = fixture.light.global_position + Vector3(0, -1, 0)
	var lit: Color = app.weapon_light_tint()
	assert(lit.r > dark.r and lit.g > dark.g, "painted gun did not respond to player position")
	app.muzzle_time = 0.05
	var flash: Color = app.weapon_light_tint()
	assert(flash.r >= lit.r and flash.g >= lit.g, "muzzle light did not affect painted gun")
	app.muzzle_time = 0.0
	app.player.global_position = prior
	print("WEAPON_LIGHT_RESPONSE_V21_OK dark=", dark, " lit=", lit, " flash=", flash)
	app.menu_flythrough.stop()
	await app.quit_game()
