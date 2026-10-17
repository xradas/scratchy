extends SceneTree
## Focused actual-physics hearing check in Ward 02. Actor and player poses are
## controlled above the map, with one temporary layer-1 solid as a closed door.

var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		push_error(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var app: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.enter_combat()
	for i in 60: await physics_frame
	app.combat.set_physics_process(false)
	check(app.world.scene_file_path.ends_with("pale_ward_02.tscn"), "Ward 02 loaded")
	var opening_awake: Array[String] = []
	for enemy in app.combat.enemies:
		if enemy.awake: opening_awake.append(enemy.target_id)
	print("WARD_02_OPENING_AWAKE ", opening_awake)
	check(opening_awake.size() <= 8, "Ward 02 opening holds distant squads dormant")
	for enemy in app.combat.enemies: enemy.set_physics_process(false)
	app.player.set_physics_process(false)
	var actor: CharacterBody3D = app.combat.enemies[0]
	var origin := Vector3(0, 40, 0)
	app.player.global_position = origin
	actor.global_position = origin + Vector3(0, 0, -7)
	app.combat.currentweapon = &"pistol"
	app.combat.cooldown = 0.0
	app.combat.weapon_phase = &"idle"
	app.player.camera.rotation.y = PI
	for i in 2: await physics_frame
	check(app.combat.try_fire(), "actual pistol shot accepted")
	check(actor.can_hear_player_shot(7.0), "accepted pistol shot audible within ten metres on a clear path")
	app.combat.weapon_phase = &"idle"
	check(not actor.can_hear_player_shot(7.0), "idle phase does not create hearing")
	app.combat.weapon_phase = &"fire"
	actor.global_position = origin + Vector3(0, 0, -11)
	await physics_frame
	check(not actor.can_hear_player_shot(11.0), "pistol shot outside local radius is inaudible")
	actor.global_position = origin + Vector3(0, 0, -7)
	var door := StaticBody3D.new()
	door.collision_layer = 1
	door.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3, 3, 0.35)
	collision.shape = shape
	door.add_child(collision)
	app.world.add_child(door)
	door.global_position = origin + Vector3(0, 0, -3.5)
	for i in 2: await physics_frame
	check(not actor.can_hear_player_shot(7.0), "closed physical door blocks hearing")
	door.queue_free()
	for i in 2: await physics_frame
	check(actor.can_hear_player_shot(7.0), "opening the path restores hearing")
	app.combat.weapon_phase = &"idle"
	actor.global_position = origin + Vector3(0, 0, -13)
	actor.awake = false
	actor._physics_process(1.0 / 60.0)
	check(not actor.awake, "distant clear sight alone does not wake the actor")
	app.combat.currentweapon = &"shotgun"
	app.combat.cooldown = 0.0
	check(app.combat.try_fire(), "actual shotgun shot accepted")
	check(actor.can_hear_player_shot(13.0), "shotgun heard farther than pistol")
	actor._physics_process(1.0 / 60.0)
	check(actor.awake, "loud gunshot wakes an actor beyond sight acquisition range")
	app.combat.weapon_phase = &"idle"
	app.combat_audio.stop_all()
	app.menu_music.stop()
	print("ENEMY_HEARING_V16 failures=", failures.size(), " labels=", failures)
	quit(1 if not failures.is_empty() else 0)
