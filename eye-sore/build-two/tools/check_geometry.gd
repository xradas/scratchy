extends SceneTree

func _initialize() -> void:
	call_deferred("run_check")

func run_check() -> void:
	var world: Node3D = load("res://scenes/calibration.tscn").instantiate()
	root.add_child(world)
	var player: CharacterBody3D = world.get_node("Player")
	if "--ramp-only" not in OS.get_cmdline_user_args():
		var portal_results := await check_portal(world, player)
		var baseline := "--portal-baseline" in OS.get_cmdline_user_args()
		var evidence_path := "res://verification/combat/portal-before.json" if baseline else "res://verification/combat/portal-after.json"
		var evidence := FileAccess.open(evidence_path, FileAccess.WRITE)
		evidence.store_string(JSON.stringify(portal_results, "  ") + "\n")
		evidence.close()
		if baseline:
			print("PORTAL_BASELINE: ", portal_results)
			quit()
			return
		assert(portal_results.ray_misses == 0, "Every portal floor shot must resolve a real floor collider")
		for hit in portal_results.floor_ray_hits:
			assert(hit.collider in ["MainFloor", "AnnexFloor"] and absf(hit.height) < 0.001, "Shot collision must match the rendered floor plane")
		var annex_front: float = world.get_node("AnnexFloor").position.z + world.get_node("AnnexFloor/Collision").shape.size.z * 0.5
		var main_rear: float = world.get_node("MainFloor").position.z - world.get_node("MainFloor/Collision").shape.size.z * 0.5
		assert(is_equal_approx(annex_front, main_rear), "Floor edges must meet at the portal")
		for path in portal_results.paths:
			assert(path.minimum_y > 0.84, "Player dropped into portal gap")
			assert(path.grounded and path.crossed, "Player must traverse the portal both ways")
		print("PORTAL_TRAVERSAL_OK: 6 real-player W paths at 8u/s/60Hz; both directions, x -1.9/0/1.9; no drop; 15 actual floor rays at rendered y0")
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
			if mesh is ArrayMesh:
				assert(shape is ConvexPolygonShape3D)
				var vertices:PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
				var unique:Array[Vector3] = []
				for vertex in vertices:
					assert(shape.points.has(vertex), "Rendered ramp vertex must be an exact collision vertex")
					if not unique.has(vertex): unique.append(vertex)
				assert(unique.size() == shape.points.size() and unique.size() == 6)
			matched += 1
	assert(matched == 53)
	assert(world.get_node("PortalLeft/Collision").shape.size.z == 1.5)
	assert(world.get_node("MainFloor/Collision").shape.size.x == 16.0)
	assert(world.get_node("AnnexFloor/Collision").shape.size.z == 17.0)
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
	print("GEOMETRY_CHECK_OK: 52 matched boxes/cylinders plus exact six-vertex visible/collision ramp; thick portal; two floor bounds; no-jump ramp traversal; final player=", player.position)
	quit()

func check_portal(world: Node3D, player: CharacterBody3D) -> Dictionary:
	# Use the unchanged production player script and buffered physical-W input.
	# These are actual physics frames, not a copied movement implementation.
	Engine.physics_ticks_per_second = 60
	var results: Dictionary = {"physics_hz": 60, "gameplay_speed": player.SPEED, "paths": [], "ray_misses": 0, "floor_ray_hits": []}
	await physics_frame
	await physics_frame
	var space := world.get_world_3d().direct_space_state
	for x in [-1.9, 0.0, 1.9]:
		for z in [-2.0, -1.9, -1.5, -1.1, -1.0]:
			var query := PhysicsRayQueryParameters3D.create(Vector3(x, 1.5, z), Vector3(x, -1, z), 1, [player.get_rid()])
			var hit := space.intersect_ray(query)
			if hit.is_empty(): results.ray_misses += 1
			results.floor_ray_hits.append({"x": x, "z": z, "collider": str(hit.collider.name) if not hit.is_empty() else "MISS", "height": hit.position.y if not hit.is_empty() else null})
	for x in [-1.9, 0.0, 1.9]:
		for direction in [-1, 1]:
			player.position = Vector3(x, 0.87, 1.5 if direction == -1 else -4.0)
			player.rotation = Vector3(0, 0 if direction == -1 else PI, 0)
			player.velocity = Vector3.ZERO
			player.set_physics_process(true)
			var event := InputEventKey.new()
			event.physical_keycode = KEY_W; event.keycode = KEY_W; event.pressed = true
			Input.parse_input_event(event); Input.flush_buffered_events()
			await process_frame
			assert(Input.is_physical_key_pressed(KEY_W))
			var minimum_y := player.position.y
			for frame in range(60):
				await physics_frame
				minimum_y = minf(minimum_y, player.position.y)
			event.pressed = false; Input.parse_input_event(event); Input.flush_buffered_events()
			results.paths.append({"x": x, "direction": direction, "minimum_y": minimum_y, "end_position": {"x":player.position.x,"y":player.position.y,"z":player.position.z}, "grounded": player.is_on_floor(), "crossed": player.position.z < -3 if direction == -1 else player.position.z > 0})
			player.set_physics_process(false)
	return results
