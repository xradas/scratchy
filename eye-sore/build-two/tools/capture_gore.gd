extends SceneTree
var app: Control

func _initialize() -> void: call_deferred("run")

func photo(label: String) -> void:
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://verification/gore/"+label+".png")

func run() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	app = preload("res://scenes/main.tscn").instantiate();root.add_child(app)
	app.enter_combat();Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	app.player.set_physics_process(false);app.combat.set_physics_process(false)
	for enemy in app.combat.enemies: enemy.set_physics_process(false);enemy.position.x = 80
	app.player.position = Vector3(0,.87,11)
	var first: CharacterBody3D = app.combat.enemies[0]
	var second: CharacterBody3D = app.combat.enemies[2]
	first.position = Vector3(-1.2,.87,7.5);second.position = Vector3(1.2,.87,7.5)
	app.combat.currentweapon = &"shotgun"
	app.player.camera.look_at(second.global_position+Vector3(0,.25,0))
	await physics_frame;await physics_frame
	assert(app.combat.try_fire())
	print("CAPTURE_DEATH ", app.combat.gore.death_records.get(second.target_id,{}))
	assert(second.dead and second.gibbed)
	await photo("shotgun-burst")
	first.health = 20
	app.player.camera.look_at(first.global_position+Vector3(0,.25,0))
	await physics_frame;await physics_frame
	app.combat.currentweapon = &"pistol";app.combat.cooldown = 0;app.combat.weapon_phase = &"idle"
	assert(app.combat.try_fire());assert(first.dead and not first.gibbed)
	first.set_physics_process(true);second.set_physics_process(true)
	for i in 160:await physics_frame
	app.combat.currentweapon = &"shotgun";app.combat.weapon_phase = &"idle";app.combat.recoil_remaining = 0
	app.player.camera.look_at(Vector3(0,.25,7.5))
	await photo("bloody-remains")
	app.player.position = Vector3(0,.87,9.6)
	app.player.camera.look_at(Vector3(0,.15,7.4))
	await photo("corpse-close")
	print("GORE_CAPTURE_OK: actual authoritative pistol/shotgun kills; full native level; persistent remains after physics settling.")
	await app.quit_game()
