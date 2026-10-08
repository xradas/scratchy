extends SceneTree

func _initialize() -> void:
	call_deferred("run_check")

func run_check() -> void:
	var world: Node3D = load("res://scenes/calibration.tscn").instantiate()
	root.add_child(world)
	var player: CharacterBody3D = world.get_node("Player")
	player.set_physics_process(false)
	var matched := 0
	for body in world.get_children():
		if body is StaticBody3D and body.has_node("Visual") and body.has_node("Collision"):
			var mesh: Mesh = body.get_node("Visual").mesh
			var shape: Shape3D = body.get_node("Collision").shape
			if mesh is BoxMesh:
				assert(shape is BoxShape3D)
				assert(mesh.size == shape.size)
			elif mesh is CylinderMesh:
				assert(shape is CylinderShape3D)
				assert(mesh.top_radius == shape.radius and mesh.height == shape.height)
			matched += 1
	assert(matched == 52)
	assert(world.get_node("PortalLeft/Collision").shape.size.z == 1.5)
	assert(world.get_node("MainFloor/Collision").shape.size.x == 16.0)
	assert(world.get_node("AnnexFloor/Collision").shape.size.z == 16.0)
	player.position = Vector3(-5.8, 0.86, 11.5)
	player.velocity = Vector3.ZERO
	for frame in range(135):
		await physics_frame
		player.velocity.z = -2.4
		player.velocity.x = 0.0
		if not player.is_on_floor(): player.velocity.y -= 24.0 / 60.0
		else: player.velocity.y = 0.0
		player.move_and_slide()
	assert(player.position.z < 8.0, "Player must cross ramp to walkway")
	assert(player.position.y > 1.7, "Player must reach raised walkway without jumping")
	assert(player.is_on_floor(), "Player must remain grounded on walkway")
	print("GEOMETRY_CHECK_OK: 52 shared mesh/collision dimensions; thick portal; two floor bounds; no-jump ramp traversal; final player=", player.position)
	quit()
