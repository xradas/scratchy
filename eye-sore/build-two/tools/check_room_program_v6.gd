extends SceneTree
## Native authored-room inventory: every planned furnishing must be present,
## collidable, and visually congruent with its physics shape.
var failures: Array[String] = []
var records: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	if not ok:
		failures.append(description)
		push_error(description)

func check_body(body: Node, label: String) -> void:
	var mesh: MeshInstance3D = body.get_node_or_null("Visual")
	var collision: CollisionShape3D = body.get_node_or_null("Collision")
	check(body is StaticBody3D and mesh != null and collision != null, label + ": physical body")
	check(String(body.get_meta("hit_material", "")) in ["armor", "hard"], label + ": impact material")
	if mesh == null or collision == null:
		return
	check(mesh.transform == collision.transform, label + ": visual/physics transform")
	var material: Material = mesh.mesh.material
	check(material is ShaderMaterial, label + ": face-local prop material")
	if material is ShaderMaterial:
		var atlas: ShaderMaterial = material
		var texture: Texture2D = atlas.get_shader_parameter("painted_surface")
		var region: Vector4 = atlas.get_shader_parameter("source_region_pixels")
		check(texture != null and region.z > 1 and region.w > 1, label + ": imported atlas region")
		if texture != null:
			check(region.x >= 0 and region.y >= 0 and region.x + region.z <= texture.get_width() and region.y + region.w <= texture.get_height(), label + ": bounded atlas pixels")
		if mesh.mesh is BoxMesh:
			check(bool(atlas.get_shader_parameter("box_mesh_uv")), label + ": box face normalization")
			var arrays: Array = mesh.mesh.surface_get_arrays(0)
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			check(indices.size() == 36, label + ": six box faces")
			for face_index in 6:
				var lo := Vector2(1, 1)
				var hi := Vector2.ZERO
				for vertex_index in range(face_index * 6, face_index * 6 + 6):
					var uv: Vector2 = uvs[indices[vertex_index]]
					lo = lo.min(uv)
					hi = hi.max(uv)
				check(absf((hi.x-lo.x)-1.0/3.0) < .001 and absf((hi.y-lo.y)-.5) < .001, label + ": complete 3x2 unwrapped face " + str(face_index))
		elif mesh.mesh is CylinderMesh:
			check(not bool(atlas.get_shader_parameter("box_mesh_uv")), label + ": cylinder native UV")
	if mesh.mesh is BoxMesh and collision.shape is BoxShape3D:
		check(mesh.mesh.size == collision.shape.size, label + ": box size")
	elif mesh.mesh is CylinderMesh and collision.shape is CylinderShape3D:
		check(is_equal_approx(mesh.mesh.height, collision.shape.height), label + ": cylinder height")
		check(is_equal_approx(mesh.mesh.top_radius, collision.shape.radius), label + ": cylinder radius")
	else:
		check(false, label + ": unsupported shape pair")

func run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/room-program-v6/levels.json"))
	var fitted: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/campaign/room-fittings-v6.json"))
	var planned_total := 0
	var placed_total := 0
	for programme in manifest.levels:
		var id := String(programme.id)
		var route: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/campaign/" + id + "-route.json"))
		var expected: Dictionary = {}
		for room in programme.rooms:
			for recipe in room.objects:
				for ordinal in range(1, int(recipe.count) + 1):
					expected[String(recipe.id) + "." + str(ordinal)] = {"room": room.id, "type": recipe.type, "function": room.function, "mode": room.layout_mode}
		var report: Dictionary = {}
		for item in fitted.levels:
			if String(item.id) == id:
				report = item
				break
		check(not report.is_empty(), id + ": missing placement receipt")
		var world: Node3D = load("res://scenes/campaign/" + id + ".tscn").instantiate()
		root.add_child(world)
		world.set_physics_process(false)
		world.get_node("Player").set_physics_process(false)
		var seen: Dictionary = {}
		var physical_bodies := 0
		for node in world.get_children():
			if not String(node.name).begins_with("RoomProp_"):
				continue
			var object_id := String(node.get_meta("room_program_object", ""))
			check(expected.has(object_id), id + ": unplanned fitting " + object_id)
			check(not seen.has(object_id), id + ": duplicate fitting " + object_id)
			seen[object_id] = true
			if expected.has(object_id):
				var design: Dictionary = expected[object_id]
				check(String(node.get_meta("prop_type", "")) == String(design.type), id + ": wrong fitting type " + object_id)
				check(String(node.get_meta("room_function", "")) == String(design.function), id + ": wrong room function " + object_id)
				check(String(node.get_meta("layout_mode", "")) == String(design.mode), id + ": wrong layout mode " + object_id)
		var bodies := 0
		for node in world.get_children():
			if not String(node.name).begins_with("RoomProp_"):
				continue
			var prop_bodies := 0
			for child in node.get_children():
				if child is StaticBody3D:
					check_body(child, id + "/" + String(node.name) + "/" + String(child.name))
					prop_bodies += 1
					bodies += 1
			check(prop_bodies > 0, id + ": nonphysical fitting " + String(node.name))
		check(seen.size() == expected.size(), id + ": fitting count")
		check(int(report.get("placed_count", -1)) == expected.size() and int(report.get("rejected_count", -1)) == 0, id + ": placement receipt")
		var rooms_report: Array = report.get("rooms", [])
		check(rooms_report.size() == programme.rooms.size(), id + ": per-room receipt")
		for room_report in rooms_report:
			check(int(room_report.planned) == int(room_report.placed) and int(room_report.rejected) == 0, id + ": unfilled room " + String(room_report.room))
		var compact_rooms: Dictionary = {}
		for planned_room in programme.rooms:
			if not planned_room.has("authored_size_xz"):
				continue
			var rid := String(planned_room.id)
			compact_rooms[rid] = true
			var dimensions: Array = planned_room.authored_size_xz
			var actual_room: Dictionary = route.rooms[rid]
			check(is_equal_approx(float(dimensions[0]), float(actual_room.size[0])) and is_equal_approx(float(dimensions[1]), float(actual_room.size[2])), id + ": authored footprint " + rid)
			var marker: Node3D = world.get_node("Room_" + rid)
			var bounds: Vector3 = marker.get_meta("room_bounds")
			check(is_equal_approx(bounds.x * 2, float(dimensions[0])) and is_equal_approx(bounds.z * 2, float(dimensions[1])), id + ": native room footprint " + rid)
		await physics_frame
		for portal in route.portals:
			if not compact_rooms.has(String(portal.from)) and not compact_rooms.has(String(portal.to)):
				continue
			for role in ["start", "middle", "end"]:
				var coords: Array = portal[role]
				var floor_point := Vector3(coords[0], coords[1], coords[2])
				var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(floor_point + Vector3(0,.6,0), floor_point - Vector3(0,1.4,0), 1))
				check(not hit.is_empty() and hit.normal.y > .9, id + ": unsupported compact-room portal " + String(portal.from) + "/" + String(portal.to) + "/" + role)
		planned_total += expected.size()
		placed_total += seen.size()
		physical_bodies += bodies
		records.append({"id": id, "rooms": programme.rooms.size(), "fittings": seen.size(), "solid_parts": bodies})
		world.queue_free()
		await process_frame
	check(planned_total == 508 and placed_total == 508, "total furnishing inventory")
	var result := {"failures": failures, "planned": planned_total, "placed": placed_total, "levels": records}
	var file := FileAccess.open("res://resources/campaign/room-program-check-v6.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "  "))
	print("ROOM_PROGRAM_V6 ", JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
