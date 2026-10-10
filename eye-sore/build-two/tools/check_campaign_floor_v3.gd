extends SceneTree
## Dense native downward-ray regression for the scaled Pale Ward triage floors.
## Samples both widened perimeter bands and the overlapping north/south sump
## rims. Cover and closet interiors are omitted because actors cannot stand
## there; the playable slab and the intentionally lowered sump are required.
var failures: Array[String] = []
var records: Array[Dictionary] = []
func _initialize() -> void: call_deferred("run")
func blocked_by_cover(x: float, z: float, center: Vector3, half_x: float) -> bool:
	var local_x := x - center.x; var local_z := z - center.z
	# Two angular cover masses occupy the arena floor near (+/-9,+6).
	if absf(absf(local_x) - 9.0) < 3.2 and absf(local_z - 6.0) < 3.8: return true
	# Opaque closet architecture occupies the outermost side strips.
	if absf(local_x) > half_x - 5.0 and local_z > -13.0 and local_z < 13.0: return true
	return false
func run() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/campaign/catalog.json"))
	for level in catalog.chapters[0].levels:
		var id := String(level.id)
		var route: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/campaign/" + id + "-route.json"))
		var arena: Dictionary = route.rooms.arena_one
		var center := Vector3(float(arena.center[0]), float(arena.center[1]), float(arena.center[2]))
		var half_x: float = float(arena.size[0]) / 2.0
		var half_z: float = float(arena.size[2]) / 2.0
		var world: Node3D = load(level.scene).instantiate(); root.add_child(world)
		var actor: CharacterBody3D = world.get_node("Player"); actor.set_physics_process(false)
		var combat: Node3D = load("res://scripts/combat.gd").new(); world.add_child(combat)
		combat.setup(world,actor); world.setup(combat,actor)
		for enemy in combat.enemies: enemy.set_physics_process(false)
		await physics_frame
		var samples := 0; var fixture_supported := 0; var unsupported: Array[Vector3] = []
		# Quarter-metre x spacing resolves the former four-centimetre rim seam;
		# one-metre z spacing covers the full actor-accessible arena length.
		var x := center.x - half_x + .5
		while x <= center.x + half_x - .5:
			var z := center.z - half_z + .5
			while z <= center.z + half_z - .5:
				if not blocked_by_cover(x,z,center,half_x):
					samples += 1
					var origin := Vector3(x,center.y + .25,z)
					var lower := Vector3(x,center.y - 1.25,z)
					var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin,lower,1))
					if hit.is_empty() or float(hit.normal.y) < .9:
						# A low ray can begin inside a bed or a physical stair tread.
						# Accept only those named reachable supports from an upper ray;
						# an overhead gallery deck cannot mask a missing floor.
						var upper: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,center.y + 4,z),lower,1))
						var name := String(upper.collider.name) if not upper.is_empty() else ""
						if not upper.is_empty() and float(upper.normal.y) > .9 and ("TriageBed" in name or "GalleryStairs" in name or "EastRimStairs" in name):
							fixture_supported += 1
						else: unsupported.append(Vector3(x,center.y,z))
				z += 1.0
			x += .25
		if not unsupported.is_empty(): failures.append(id + ": " + str(unsupported.size()) + " unsupported floor samples")
		records.append({"id":id,"samples":samples,"fixture_supported":fixture_supported,"unsupported":unsupported.size(),"examples":unsupported.slice(0,20)})
		world.queue_free(); await process_frame
	var receipt := {"failures":failures,"levels":records,"scope":"Native physics downward rays at 0.25m transverse/1m longitudinal spacing across all three Pale Ward arena_one floors, excluding solid cover and opaque closet interiors; lowered sump remains within support range."}
	var file := FileAccess.open("res://resources/campaign/floor-check.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(receipt,"  "))
	print("CAMPAIGN_FLOOR ",JSON.stringify(receipt))
	quit(0 if failures.is_empty() else 1)
