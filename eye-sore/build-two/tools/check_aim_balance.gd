extends SceneTree
var app: Control
var results: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run_check")

func prepare(kind: StringName, distance: float) -> CharacterBody3D:
	app.combat.reset()
	app.configure_combat_art()
	app.combat.set_physics_process(false)
	for enemy in app.combat.enemies:
		enemy.set_physics_process(false)
		enemy.position.x = 6.0
	var enemy: CharacterBody3D = app.combat.enemies[0 if kind == &"unsealed" else 1]
	enemy.position = Vector3(0, 0.87, 14 - distance)
	app.player.position = Vector3(0, 0.87, 14)
	app.player.rotation = Vector3.ZERO
	app.player.camera.look_at(enemy.global_position + Vector3(0, 0.3, 0))
	return enemy

func run_check() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	app = preload("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.enter_combat()
	app.player.set_physics_process(false)
	app.combat.set_physics_process(false)
	for enemy in app.combat.enemies: enemy.set_physics_process(false)
	app.player.rotation = Vector3.ZERO
	app.player.camera.rotation = Vector3.ZERO
	app.player.sensitivity = 0.002
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(100, 50)
	motion.screen_relative = Vector2(10, 5)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	app.player._unhandled_input(motion)
	assert(is_equal_approx(app.player.rotation.y, -0.02))
	assert(is_equal_approx(app.player.camera.rotation.x, -0.01))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for dimensions in [Vector2(1280,720), Vector2(1560,900), Vector2(800,600)]:
		root.size = Vector2i(dimensions)
		await process_frame
		await process_frame
		app.layout_view()
		var center: Vector2 = (app.crosshair.position + app.crosshair.size * 0.5 - app.world_image.position) / app.world_image.size * Vector2(640, 360)
		assert(center.is_equal_approx(Vector2(320,180)))
		var direction: Vector3 = app.player.camera.project_ray_normal(center)
		assert(direction.is_equal_approx(-app.player.camera.global_basis.z))
		var left_ray: Vector3 = app.player.camera.project_ray_normal(Vector2(0,180))
		var half_angle := rad_to_deg(atan2(absf(left_ray.dot(app.player.camera.global_basis.x)), left_ray.dot(-app.player.camera.global_basis.z)))
		assert(is_equal_approx(half_angle, app.field_of_view * 0.5), "FOV must describe horizontal view")
	for kind in [&"unsealed", &"vessel"]:
		for weapon in [&"pistol", &"shotgun", &"melee"]:
			var enemy := prepare(kind, 1.5 if weapon == &"melee" else 4.0)
			await physics_frame
			await physics_frame
			app.combat.currentweapon = weapon
			var before: Transform3D = app.player.camera.global_transform
			var shots := 0
			while not enemy.dead and shots < 20:
				app.combat.cooldown = 0
				app.combat.weapon_phase = &"idle"
				assert(app.combat.try_fire())
				shots += 1
				for tick in 3: app.combat._physics_process(1.0 / 60)
				assert(app.player.camera.global_transform.is_equal_approx(before), "Recoil altered aim")
			assert(enemy.dead)
			var expected := 4 if kind == &"unsealed" else 8
			if weapon == &"shotgun": expected = 1 if kind == &"unsealed" else 2
			elif weapon == &"melee": expected = 3 if kind == &"unsealed" else 6
			assert(shots == expected, "%s %s unexpected shots %d" % [kind, weapon, shots])
			results.append({"enemy":kind,"weapon":weapon,"hits_to_kill":shots,"camera_stable":true})
	var file := FileAccess.open("res://verification/combat/aim-balance.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"screen_relative_input":true,"crosshair_ray_center":true,"close_range_kills":results,"scope":"Actual physics contacts, torso aim. Does not claim subjective aim feel or long-range balance approval."}, "  ")+"\n")
	file.close()
	print("AIM_BALANCE_OK: screen-relative input; exact crosshair/ray alignment; camera stable through shots; close-range pistol4/8, shotgun1/2, melee3/6")
	await app.quit_game()
