extends SceneTree
## New containment hardware must not bury authored actors inside solids.
func _initialize() -> void: call_deferred("run")

func run() -> void:
	var app: Control = preload("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.enter_combat()
	app.player.set_physics_process(false)
	for enemy in app.combat.enemies: enemy.set_physics_process(false)
	await physics_frame; await physics_frame
	var actors: Array[Dictionary] = []
	for enemy in app.combat.enemies:
		var collision: CollisionShape3D = enemy.get_node("CollisionShape3D")
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = collision.shape; query.transform = collision.global_transform
		query.collision_mask = 1; query.exclude = [enemy.get_rid()]
		var overlap: Array[Dictionary] = enemy.get_world_3d().direct_space_state.intersect_shape(query)
		assert(overlap.is_empty(),"New hardware overlaps spawn " + enemy.target_id)
		assert(enemy.sprite.layers == 2,"A moving creature is captured by static reflections")
		actors.append({"target":enemy.target_id,"position":enemy.position,"overlapping_world_solids":overlap.size()})
	var file := FileAccess.open("res://verification/grit/spawn-clearance.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(actors,"  ")+"\n");file.close()
	print("WARD_ART_GEOMETRY_OK: eleven authored spawns clear real world solids; moving creatures excluded from static reflection captures")
	await app.quit_game()
