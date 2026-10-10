extends SceneTree
var failures: Array[String] = []
var records: Array[Dictionary] = []
class StubCombat:
	extends Node
	signal combat_event(event: Dictionary)
	var health := 70.0
	var armor := 20.0
	var ammo_pistol := 36
	var ammo_shotgun := 12
	var enemies: Array = []
	var dead := false
class StubEnemy:
	extends Node
	var target_id := ""
	var awake := false
	var dead := false
func _initialize() -> void: call_deferred("run")
func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
func geometry(node: Node, report: Dictionary) -> void:
	if node is StaticBody3D or node is AnimatableBody3D:
		var visual: MeshInstance3D = node.get_node_or_null("Visual")
		var collision: CollisionShape3D = node.get_node_or_null("Collision")
		if visual != null and collision != null and visual.mesh is BoxMesh and collision.shape is BoxShape3D:
			check(visual.mesh.size == collision.shape.size, str(node.get_path()) + " visible/collision sizes diverged")
			check(visual.transform == collision.transform, str(node.get_path()) + " visible/collision transforms diverged")
			report["shared_boxes"] += 1
		elif visual != null and collision != null and visual.mesh is CylinderMesh and collision.shape is CylinderShape3D:
			check(visual.mesh.height == collision.shape.height and visual.mesh.top_radius == collision.shape.radius and visual.mesh.bottom_radius == collision.shape.radius, str(node.get_path()) + " cylinder dimensions diverged")
			check(visual.transform == collision.transform, str(node.get_path()) + " cylinder transforms diverged")
			report["shared_cylinders"] += 1
	for child in node.get_children(): geometry(child, report)
func run() -> void:
	var contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/expansion-v1/contract.json"))
	for stage in contract.stages:
		if not ResourceLoader.exists(stage.scene): failures.append(stage.id + ": missing scene"); continue
		var world = load(stage.scene).instantiate(); root.add_child(world)
		var actor: CharacterBody3D = world.get_node("Player"); actor.set_physics_process(false)
		var controller := StubCombat.new(); world.add_child(controller)
		var spawns: Node = world.get_node("EnemySpawns")
		var kinds: Dictionary = {}
		for index in spawns.get_child_count():
			var marker: Node = spawns.get_child(index)
			var kind := String(marker.get_meta("kind")); kinds[kind] = true
			check(stage.enemy_kinds.has(kind), stage.id + ": foreign enemy " + kind)
			var enemy := StubEnemy.new(); enemy.target_id = "fixture_" + str(index); controller.add_child(enemy); controller.enemies.append(enemy)
		world.setup(controller, actor)
		var record := {"id":stage.id,"rooms":world.rooms.size(),"enemies":spawns.get_child_count(),"shared_boxes":0,"shared_cylinders":0,"kinds":kinds.keys()}
		geometry(world, record)
		check(world.rooms.size() >= 16, stage.id + ": too few distinct regions")
		check(spawns.get_child_count() >= 32 and spawns.get_child_count() <= 44, stage.id + ": enemy count outside target")
		var side_count := 0; var secret_count := 0; var shortcut_count := 0; var lifts := 0; var steps := 0
		for room in world.rooms:
			if room.get_meta("optional", false): side_count += 1
		for mechanism in world.mechanisms:
			if mechanism.has_meta("secret"): secret_count += 1
			if mechanism.has_meta("shortcut"): shortcut_count += 1
			if mechanism.has_meta("ward_lift"): lifts += 1
		for node in world.get_children():
			if node.has_meta("stage_step"): steps += 1
		check(side_count >= 4, stage.id + ": fewer than four optional rooms")
		check(secret_count >= 2 and shortcut_count >= 2, stage.id + ": missing optional secrets/shortcuts")
		check(lifts >= 1 and steps >= 8, stage.id + ": physical height progression missing")
		check(world.get_level_state().map_rooms.is_empty(), stage.id + ": map leaks unvisited rooms")
		# Closed, moving and opened slabs all share the actual world ray layer.
		var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/stages/"+stage.id+"-route.json"))
		await physics_frame
		for portal in layout.portals:
			if portal.door == null: continue
			var door: AnimatableBody3D = world.get_node(String(portal.door))
			var center: Vector3 = door.get_parent().to_global(door.origin) + Vector3(0,-1.1,0)
			var offset := Vector3(1.0,0,0) if int(portal.axis)==0 else Vector3(0,0,1.0)
			var ray := PhysicsRayQueryParameters3D.create(center-offset,center+offset,1)
			var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(ray)
			check(not hit.is_empty() and hit.collider == door, stage.id + ": closed slab failed visibility/ray block " + String(portal.door))
			var permission := {}
			for requirement in door.get_meta("requires",[]): permission[String(requirement)] = true
			check(door.activate(permission),stage.id + ": valid door flags rejected")
			await physics_frame
			hit = world.get_world_3d().direct_space_state.intersect_ray(ray)
			check(not hit.is_empty() and hit.collider == door, stage.id + ": moving slab prematurely stopped blocking")
		for frame in 100: await physics_frame
		for portal in layout.portals:
			if portal.door != null:
				var door: AnimatableBody3D = world.get_node(String(portal.door))
				check(door.is_open(),stage.id + ": door never reached fully open")
				var center: Vector3 = door.get_parent().to_global(door.origin) + Vector3(0,-1.1,0)
				var offset := Vector3(1.0,0,0) if int(portal.axis)==0 else Vector3(0,0,1.0)
				var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(center-offset,center+offset,1))
				check(hit.is_empty(),stage.id + ": opened slab still blocks rays " + String(portal.door))
			# Every portal has a collision floor under each sampled point.
			# Lift travel has a shaft intentionally; test its approach and initial deck.
			for index in 9:
				var t := float(index)/8.0
				var point := Vector3(portal.start[0],portal.start[1],portal.start[2]).lerp(Vector3(portal.end[0],portal.end[1],portal.end[2]),t)
				var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3(0,3,0),point-Vector3(0,4,0),1))
				check(not hit.is_empty() and hit.normal.y > .99,stage.id + ": floor gap in " + String(portal.from) + "→" + String(portal.to))
		for mechanism in world.mechanisms:
			if mechanism.has_method("reset_door"): mechanism.reset_door()
		# A real button rejects use until its group clears.
		var locked_button: Node3D = world.get_node("Button_breaker")
		actor.global_position = locked_button.global_position + Vector3(0,0,1.3)
		await physics_frame
		check(not world.try_use(actor),stage.id + ": uncleared arena control allowed use")
		var brass: Node3D
		for item in world.pickups:
			if String(item.get_meta("stage_pickup")) == "brass_key": brass = item
		check(brass != null, stage.id + ": brass key absent")
		if brass != null: world.collect(brass); check(not world.flags.get("brass", false), stage.id + ": key bypasses power")
		for arena in world.arena_remaining.keys():
			var ids: Array[String] = []
			for id in world.enemy_groups:
				if world.enemy_groups[id] == arena: ids.append(id)
			world.activate_arena(arena)
			var initial: int = world.arena_remaining[arena]
			world.notify_enemy_death(ids[0], arena); world.notify_enemy_death(ids[0], arena)
			check(world.arena_remaining[arena] == initial - 1, stage.id + ": duplicate death advances arena")
			for id in ids: world.notify_enemy_death(id, arena)
			check(world.flags.get("clear_" + arena, false), stage.id + ": arena did not enable control")
		check(not world.flags.get("power", false) and not world.flags.get("exit", false), stage.id + ": clear grants button flags automatically")
		for flag in ["breaker","release","exit_control"]:
			var button: Node3D
			for mechanism in world.mechanisms:
				if String(mechanism.get_meta("stage_button", "")) == flag: button = mechanism
			check(button != null, stage.id + ": missing physical " + flag + " control")
			if button == null: continue
			actor.global_position = button.global_position + Vector3(0,0,1.3)
			await physics_frame
			check(world.try_use(actor), stage.id + ": enabled " + flag + " button rejected")
			check(world.flags.get(flag, false), stage.id + ": button did not set " + flag)
		if brass != null: world.collect(brass); check(world.flags.get("brass", false), stage.id + ": brass collection failed after power")
		for item in world.pickups:
			if String(item.get_meta("stage_pickup")) == "red_key": world.collect(item)
		check(world.flags.get("red", false), stage.id + ": red key collection failed")
		check(world.secrets.is_empty(), stage.id + ": critical state requires secret")
		record["side_rooms"] = side_count; record["secrets"] = secret_count; record["shortcuts"] = shortcut_count; record["steps"] = steps
		records.append(record)
		world.queue_free(); await process_frame
	var report := {"failures":failures,"stages":records,"scope":"Scene structure, exact mesh/collision dimensions, all portal collision-floor continuity, closed/moving/open door ray blocking, theme exclusivity, visited-only map, deduplicated arena state and physical locked/enabled control interaction."}
	print("EXPANDED_STAGE_CHECK ", JSON.stringify(report))
	var output := FileAccess.open("res://resources/stages/state-check.json", FileAccess.WRITE); output.store_string(JSON.stringify(report,"  "))
	quit(0 if failures.is_empty() else 1)
