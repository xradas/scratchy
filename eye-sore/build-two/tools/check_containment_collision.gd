extends SceneTree
# Focused shared-solid regression: actual authored geometry and combat code.
var world: Node3D
var player: CharacterBody3D
var combat: Node3D
var enemy: CharacterBody3D
var records: Array[Dictionary] = []
var failures: Array[String] = []
var impacts: Array[Dictionary] = []
var assertions := 0
var evidence_dir := "res://verification/grit/p13-containment-collision"

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-dir="):
			evidence_dir = argument.trim_prefix("--evidence-dir=")
	call_deferred("run_check")

func check(value: bool, label: String) -> void:
	assertions += 1
	if not value:
		failures.append(label)
		push_error(label)

func capture(event: Dictionary) -> void:
	if event.type == &"projectile_impact": impacts.append(event.duplicate())

func actor_probe(actor: CharacterBody3D, start: Vector3, finish: Vector3, solid: Node3D) -> Dictionary:
	var pose := actor.global_transform
	pose.origin = start
	var shape: CollisionShape3D = actor.get_node("CollisionShape3D")
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape.shape
	query.transform = pose * shape.transform
	query.collision_mask = 1
	check(world.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty(), "%s probe starts clear of solids: %s" % [actor.name, solid.name])
	var contact := KinematicCollision3D.new()
	var blocked := actor.test_move(pose, finish - start, contact)
	var collider: Object = contact.get_collider() if blocked else null
	check(blocked and collider == solid, "%s capsule blocked by %s (got %s)" % [actor.name, solid.name, collider])
	return {"actor": String(actor.name), "blocked": blocked, "collider": String(collider.name) if collider else "", "travel": contact.get_travel() if blocked else Vector3.ZERO}

func probe(name_value: String, axis: Vector3, height: float = -1.0) -> void:
	var solid: StaticBody3D = world.get_node(name_value)
	var visual: MeshInstance3D = solid.get_node("Visual")
	var collision: CollisionShape3D = solid.get_node("Collision")
	var center := solid.global_position
	if height >= 0.0: center.y = height
	var extent: float
	if collision.shape is BoxShape3D:
		var size: Vector3 = collision.shape.size
		check(visual.mesh is BoxMesh and visual.mesh.size.is_equal_approx(size), name_value + " visible/physical box dimensions agree")
		extent = size.dot(axis.abs()) * 0.5
	else:
		check(collision.shape is CylinderShape3D and visual.mesh is CylinderMesh, name_value + " uses matching cylinder primitives")
		check(is_equal_approx(collision.shape.radius, visual.mesh.top_radius) and is_equal_approx(collision.shape.height, visual.mesh.height), name_value + " visible/physical cylinder dimensions agree")
		extent = collision.shape.radius
	check(not collision.disabled and solid.collision_layer & 1 != 0, name_value + " is an enabled world solid")
	var clearance := 1.2 if axis == Vector3.DOWN else 0.85
	var start := center - axis * (extent + clearance)
	var finish := center + axis * (extent + 0.4)
	var actor_records := [actor_probe(player, start, finish, solid), actor_probe(enemy, start, finish, solid)]
	var exclusions := [player.get_rid(), enemy.get_rid()]
	var ray_records: Array[Dictionary] = []
	for anatomical in [false, true]:
		var hit: Dictionary = combat.ray(start, finish, exclusions, anatomical)
		check(not hit.is_empty() and hit.collider == solid, "%s actual Combat.ray blocked, anatomical=%s" % [name_value, anatomical])
		if not hit.is_empty(): check(String(combat.material_for(hit.collider)) == String(solid.get_meta("hit_material")), name_value + " combat contact material matches solid")
		ray_records.append({"anatomical_hits": anatomical, "collision_mask": 7 if anatomical else 3, "collider": String(hit.collider.name) if not hit.is_empty() else "", "position": hit.position if not hit.is_empty() else Vector3.ZERO})
	var before := impacts.size()
	var projectile: Node3D = combat.launch_projectile(enemy, start, axis)
	var weak: WeakRef = weakref(projectile)
	var ticks := 0
	var last_position := start
	while weak.get_ref() != null and ticks < 120:
		last_position = projectile.global_position
		await physics_frame
		ticks += 1
	check(weak.get_ref() == null and ticks > 0 and ticks < 120, name_value + " actual projectile retired by physics before lifetime expiry")
	check(impacts.size() == before + 1, name_value + " actual projectile emitted one obstacle impact")
	if impacts.size() > before:
		check(String(impacts[before].material) == String(solid.get_meta("hit_material")), name_value + " projectile reports shared solid material")
		check(impacts[before].position.distance_to(center) < extent + 0.3, name_value + " projectile impact remains at intended solid")
	records.append({"solid": name_value, "from": start, "to": finish, "actors": actor_records, "combat_rays": ray_records, "projectile_physics_ticks": ticks, "projectile_last_position": last_position, "impact_count": impacts.size() - before})
	print("CONTAINMENT_SOLID_CHECK ", name_value, " physics_ticks=", ticks)

func spawn_overlap(actor: CharacterBody3D, label: String) -> void:
	var shape: CollisionShape3D = actor.get_node("CollisionShape3D")
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape.shape
	query.transform = shape.global_transform
	query.collision_mask = 1
	var hits := world.get_world_3d().direct_space_state.intersect_shape(query, 64)
	var names: Array[String] = []
	for hit in hits: names.append(String(hit.collider.name))
	check(hits.is_empty(), label + " authored spawn capsule does not overlap world solids: " + str(names))
	records.append({"spawn": label, "position": actor.global_position, "solid_overlaps": names})

func key(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_W
	event.pressed = pressed
	Input.parse_input_event(event)

func central_walk() -> void:
	player.position = Vector3(0, 0.87, 7.4)
	player.velocity = Vector3.ZERO
	player.rotation.y = 0
	player.set_physics_process(true)
	for _tick in 12: await physics_frame
	var ticks := 0
	var lowest := player.position.y
	key(true)
	while player.position.z > -8.0 and ticks < 300:
		await physics_frame
		lowest = minf(lowest, player.position.y)
		ticks += 1
	key(false)
	for _tick in 15: await physics_frame
	check(ticks > 0 and ticks < 300 and player.position.z <= -8.0, "Actual player capsule traverses central corridor through maintenance plates without a hidden wall")
	check(lowest > 0.8 and player.is_on_floor(), "Central traversal retains floor contact without falling through plates")
	records.append({"route": "central hall only: z7.4 to z-8 at x0", "physics_ticks": ticks, "lowest_center_y": lowest, "finish": player.position, "grounded": player.is_on_floor()})
	player.set_physics_process(false)

func run_check() -> void:
	world = load("res://scenes/pale_ward.tscn").instantiate()
	root.add_child(world)
	player = world.get_node("Player")
	player.set_physics_process(false)
	combat = load("res://scripts/combat.gd").new()
	world.add_child(combat)
	combat.setup(world, player)
	combat.set_physics_process(false)
	combat.combat_event.connect(capture)
	for actor in combat.enemies: actor.set_physics_process(false)
	for _tick in 3: await physics_frame
	spawn_overlap(player, "Player")
	check(combat.enemies.size() == world.get_node("EnemySpawns").get_child_count() and combat.enemies.size() > 0, "Nonzero authored enemies instantiated for spawn audit")
	for index in combat.enemies.size(): spawn_overlap(combat.enemies[index], "Spawn%d" % index)
	enemy = combat.enemies[0]
	# Keep fixture actors away from rays/projectiles after auditing their real spawns.
	for actor in combat.enemies: actor.position = Vector3(100 + actor.get_index() * 3, 10, 100)
	player.position = Vector3(100, 10, 120)
	for _tick in 3: await physics_frame
	await probe("ContainmentPier-1", Vector3.RIGHT, 2.0)
	await probe("ContainmentPier1", Vector3.RIGHT, 2.0)
	await probe("BioJunctionHousing", Vector3.RIGHT)
	await probe("BioJunctionFeed", Vector3.RIGHT)
	await probe("RearDoorJamb-1", Vector3.FORWARD)
	await probe("RearDoorJamb1", Vector3.FORWARD)
	for index in 3: await probe("MaintenancePlate%d" % index, Vector3.DOWN)
	await central_walk()
	check(assertions >= 90 and records.size() >= 20 and impacts.size() == 9, "Explicit nonzero fixture coverage: nine solids, real impacts, spawn audit and central traversal")
	check(DirAccess.make_dir_recursive_absolute(evidence_dir) == OK, "Evidence directory writable")
	var result := {"scope": "Authored solids; actual player/enemy test_move; Combat.ray visibility and hitscan masks; real Combat.launch_projectile physics and retirement; authored spawn capsule overlaps; focused central corridor traversal. Fixture AI disabled; no geometry mutation.", "assertions": assertions, "failures": failures, "records": records, "projectile_impacts": impacts, "scene_sha256": FileAccess.get_sha256("res://scenes/pale_ward.tscn"), "combat_sha256": FileAccess.get_sha256("res://scripts/combat.gd"), "projectile_sha256": FileAccess.get_sha256("res://scripts/combat_projectile.gd"), "check_sha256": FileAccess.get_sha256("res://tools/check_containment_collision.gd")}
	var file := FileAccess.open(evidence_dir.path_join("collision.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(result, "  "))
		file.close()
	else: check(false, "Evidence file writable")
	print("CONTAINMENT_COLLISION_OK assertions=%d records=%d impacts=%d" % [assertions, records.size(), impacts.size()] if failures.is_empty() else "CONTAINMENT_COLLISION_FAILED " + str(failures))
	key(false)
	world.free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
