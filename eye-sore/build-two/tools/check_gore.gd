extends SceneTree
## Meaningful ownership/geometry checks on actual integrated damage and art.
var app: Control
var records: Dictionary = {}
var cap := 60

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--gore-fps="): cap = int(argument.trim_prefix("--gore-fps="))
	Engine.max_fps = cap
	call_deferred("run")

func shot(enemy: CharacterBody3D, weapon: StringName, health: float) -> void:
	enemy.health = health; enemy.dead = false; enemy.gibbed = false
	enemy.collision_layer = 2; enemy.position = Vector3(0,.87,7)
	enemy.change_state(&"chase"); enemy.set_physics_process(false)
	app.combat.currentweapon = weapon; app.combat.weapon_phase = &"idle"; app.combat.cooldown = 0
	app.player.camera.look_at(enemy.global_position + Vector3(0,.28,0))
	await physics_frame; await physics_frame
	assert(app.combat.try_fire())

func run() -> void:
	if DisplayServer.get_name() != "headless": root.set_flag(Window.FLAG_NO_FOCUS,true)
	app = preload("res://scenes/main.tscn").instantiate(); root.add_child(app)
	app.enter_combat(); Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	app.player.set_physics_process(false); app.combat.set_physics_process(false)
	app.player.position = Vector3(0,.87,11)
	for enemy in app.combat.enemies: enemy.set_physics_process(false); enemy.position.x = 80
	var first: CharacterBody3D = app.combat.enemies[0]
	var second: CharacterBody3D = app.combat.enemies[2]
	var gore: Node3D = app.combat.gore
	await shot(first,&"pistol",20)
	assert(first.dead and not first.gibbed and gore.death_count == 1)
	assert(first.sprite.visible)
	var record: Dictionary = gore.death_records[first.target_id]
	assert(record.part_count == 2 and is_instance_valid(record.pool))
	assert(not record.gibbed and record.pool.get_meta("death_pool"))
	var pool: MeshInstance3D = record.pool
	var vertices: PackedVector3Array = pool.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var maximum_gap := 0.0
	for vertex in vertices:
		var point := pool.to_global(vertex)
		var hit: Dictionary = gore.world_ray(point+Vector3.UP*.08,point-Vector3.UP*.08)
		assert(not hit.is_empty())
		maximum_gap = maxf(maximum_gap,point.y-hit.position.y)
	assert(maximum_gap < .011)
	records.pistol = {"corpse_visible":true,"parts":record.part_count,"max_pool_surface_gap":maximum_gap}
	# Repeated death/damage and corpse shots must not create a second death effect.
	first.apply_damage(999,91,&"shotgun",first.position)
	gore.handle_event({"type":"enemy_death","target_id":first.target_id,"weapon_id":"pistol","shot_id":app.combat.shot_counter,"position":first.position})
	assert(gore.death_count == 1)
	first.position.x = -4
	await shot(second,&"shotgun",80)
	assert(second.dead and second.gibbed and not second.sprite.visible)
	assert(gore.death_count == 2 and gore.death_records[second.target_id].part_count == 9)
	records.shotgun = {"gibbed":true,"parts":9,"deaths_once":gore.death_count}
	var start_draw := Engine.get_frames_drawn()
	var start_usec := Time.get_ticks_usec()
	for i in 160: await physics_frame
	assert(gore.particles.is_empty() and gore.remains.size() == 11)
	records.cadence = {"render_cap":cap,"physics_ticks":160,"rendered_frames":Engine.get_frames_drawn()-start_draw,"elapsed_seconds":(Time.get_ticks_usec()-start_usec)/1000000.0,"settled_remains":gore.remains.size(),"live_particles":gore.particles.size()}
	var count: int = gore.stains.size()
	app.player.camera.rotation = Vector3.ZERO
	app.combat.cooldown = 0; app.combat.weapon_phase = &"idle"
	assert(app.combat.try_fire())
	assert(gore.stains.size() == count and gore.death_count == 2)
	# Actual armor hurt produces sparks without blood; hard impacts are ignored.
	gore.handle_event({"type":"enemy_hurt","target_id":"armor_fixture","shot_id":700,"weapon_id":"pistol","material":"armor","position":Vector3(0,1,5)})
	assert(gore.particles.size() == 2)
	for particle in gore.particles: assert(not particle.blood)
	# Surface decals cannot span an unsupported edge or an invisible stair ramp.
	var patch: MeshInstance3D = gore.surface_patch(Vector3(0,.5,-7.75),Vector3.UP,Vector2(2,2),gore.profile.pools,2,2,1,9,0,false)
	assert(is_instance_valid(patch))
	var stair_vertices: PackedVector3Array = patch.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for i in range(0,stair_vertices.size(),3):
		assert(absf(stair_vertices[i].y-stair_vertices[i+1].y)<.025 and absf(stair_vertices[i].y-stair_vertices[i+2].y)<.025)
	assert(gore.surface_patch(Vector3(60,0,0),Vector3.UP,Vector2(2,2),gore.profile.pools,2,2,0,4,0,false)==null)
	records.surfaces = {"stair_triangles_split_at_risers":stair_vertices.size()/3,"unsupported_patch_rejected":true}
	app.set_paused(true)
	var positions: Array[Vector3] = []
	for particle in gore.particles: positions.append(particle.node.position)
	await create_timer(.2,true).timeout
	for i in positions.size(): assert(gore.particles[i].node.position==positions[i])
	app.restart_combat(); Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	assert(not is_instance_valid(gore))
	assert(app.combat.gore.stains.is_empty() and app.combat.gore.remains.is_empty() and app.combat.gore.death_count==0)
	records.lifecycle = "Pause freezes gore; retry replaces owner and clears all stains/remains/particles."
	var file := FileAccess.open("res://verification/gore/contract-%d.json" % cap,FileAccess.WRITE)
	file.store_string(JSON.stringify(records,"  "));file.close()
	print("GORE_CHECK_OK ",JSON.stringify(records))
	await app.quit_game()
