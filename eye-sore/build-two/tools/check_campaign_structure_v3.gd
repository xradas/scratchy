extends SceneTree
## Native scene/collider contract for every independently authored campaign map.
var failures: Array[String] = []
var records: Array[Dictionary] = []
var graph_signatures: Dictionary = {}
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	if not value: failures.append(label); push_error(label)
func run() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/campaign/catalog.json"))
	check(catalog.chapters.size() == 3, "chapter count")
	var expected := ["pale_ward", "ash_citadel", "occupied_line"]
	for chapter_index in 3:
		var chapter: Dictionary = catalog.chapters[chapter_index]
		check(chapter.id == expected[chapter_index], "chapter order " + str(chapter_index))
		check(chapter.levels.size() == 3, chapter.id + ": level count")
		for level in chapter.levels:
			var id := String(level.id)
			var route: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/campaign/" + id + "-route.json"))
			var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/campaign/" + id + "-layout.json"))
			check(route.id == id and layout.id == id, id + ": resource ids")
			check(route.portals.size() >= 9 and route.rooms.size() >= 10, id + ": connected map size")
			var edges: Array[String] = []
			for edge in route.portals:
				var pair: Array[String] = [String(edge.from), String(edge.to)]; pair.sort()
				edges.append(pair[0] + "/" + pair[1] + ":" + String(edge.get("gate", "")))
			edges.sort()
			var signature := "|".join(edges)
			check(not graph_signatures.has(signature), id + ": duplicate route graph")
			graph_signatures[signature] = id
			var rects: Array = route.rooms.values()
			for first in range(rects.size()):
				for second in range(first + 1, rects.size()):
					var a: Dictionary = rects[first]; var b: Dictionary = rects[second]
					var overlap_x: float = (float(a.size[0]) + float(b.size[0])) / 2.0 - absf(float(a.center[0]) - float(b.center[0]))
					var overlap_z: float = (float(a.size[2]) + float(b.size[2])) / 2.0 - absf(float(a.center[2]) - float(b.center[2]))
					check(overlap_x < .05 or overlap_z < .05, id + ": overlapping rooms " + String(a.id) + "/" + String(b.id))
			var world: Node3D = load(level.scene).instantiate(); root.add_child(world)
			check(String(world.get_meta("stage_id", "")) == chapter.id, id + ": theme metadata")
			check(String(world.get_meta("campaign_level_id", "")) == id, id + ": level metadata")
			var actor: CharacterBody3D = world.get_node("Player")
			actor.set_physics_process(false)
			var combat: Node3D = load("res://scripts/combat.gd").new(); world.add_child(combat)
			combat.setup(world, actor); world.setup(combat, actor)
			for enemy in combat.enemies: enemy.set_physics_process(false)
			await physics_frame
			check(world.rooms.size() == route.rooms.size() and world.traps.size() == 3, id + ": rooms/traps")
			check(world.get_node_or_null("Key_brass_key") != null and world.get_node_or_null("Key_red_key") != null, id + ": key loop")
			check(world.get_node_or_null("ExitControl") != null, id + ": exit")
			check(not world.get_node_or_null("Door_brass_gate") == null and not world.get_node_or_null("Door_red_gate") == null, id + ": keyed doors")
			if chapter.id == "pale_ward":
				var first: Node3D = world.get_node_or_null("FirstGunCache")
				check(first != null, id + ": early weapon")
				if first != null:
					check(String(first.get_meta("stage_pickup")) == String(route.entry_weapon), id + ": weapon order")
					check(first.global_position.distance_to(actor.global_position) < 11, id + ": first route pickup distance")
			for path in route.vertical_routes:
				for point in route.vertical_routes[path]:
					var location := Vector3(point[0], point[1], point[2])
					var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(location + Vector3(0,.8,0), location - Vector3(0,.8,0), 1))
					check(not hit.is_empty() and hit.normal.y > .95, id + ": supported upper route " + String(path) + " " + str(location))
			records.append({"id": id, "rooms": world.rooms.size(), "portals": route.portals.size(), "enemies": combat.enemies.size(), "vertical_routes": route.vertical_routes.size(), "early_weapon": route.entry_weapon})
			world.queue_free(); await process_frame
	var file := FileAccess.open("res://resources/campaign/structure-check.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"failures": failures, "levels": records}, "  "))
	print("CAMPAIGN_STRUCTURE ", JSON.stringify({"failures": failures, "levels": records}))
	quit(0 if failures.is_empty() else 1)
