extends Node3D
signal completed
signal message_changed(text: String)
var combat: Node
var player: CharacterBody3D
var rooms: Array[Node3D] = []
var navigation: Array[Node3D] = []
var pickups: Array[Node3D] = []
var mechanisms: Array[Node3D] = []
var flags: Dictionary = {}
var collected: Dictionary = {}
var visited: Dictionary = {}
var dead_ids: Dictionary = {}
var arena_remaining: Dictionary = {}
var arena_active: Dictionary = {}
var enemy_groups: Dictionary = {}
var traps: Dictionary = {}
var trap_entries: Dictionary = {}
var trap_shutters: Dictionary = {}
var current_room := ""
var finished := false
var prompt := ""
var objective := "Restore power at the first arena breaker."
var secret_found := false
var shortcut_open := false
var secrets: Dictionary = {}
var shortcuts: Dictionary = {}
func setup(controller: Node, actor: CharacterBody3D) -> void:
	combat = controller; player = actor
	rooms.clear(); navigation.clear(); pickups.clear(); mechanisms.clear(); trap_entries.clear(); trap_shutters.clear()
	scan(self)
	if combat.has_signal("combat_event") and not combat.combat_event.is_connected(handle_event): combat.combat_event.connect(handle_event)
	reset()
func scan(node: Node) -> void:
	if node is Node3D:
		if node.has_meta("stage_polygon") and node.get_child_count() == 0: build_polygon(node)
		if node.has_meta("trap_entry"): trap_entries[String(node.get_meta("trap_entry"))] = node
		if node.has_meta("trap_shutter"):
			var arena := String(node.get_meta("trap_shutter"))
			if not trap_shutters.has(arena): trap_shutters[arena] = []
			trap_shutters[arena].append(node)
		if node.has_meta("stage_room"): rooms.append(node)
		if node.has_meta("stage_nav"): navigation.append(node)
		if node.has_meta("stage_pickup"): pickups.append(node)
		if node.has_meta("stage_door") or node.has_meta("stage_button") or node.has_meta("ward_lift") or node.has_meta("stage_exit"): mechanisms.append(node)
	for child in node.get_children(): scan(child)
func reset() -> void:
	flags.clear(); collected.clear(); visited.clear(); dead_ids.clear(); arena_remaining.clear(); arena_active.clear(); enemy_groups.clear(); secrets.clear(); shortcuts.clear()
	traps.clear()
	for arena in trap_entries:
		traps[arena] = {"triggered":false,"cleared":false,"latched":false,"shutters_open":false}
		trap_entries[arena].reset_door()
		for shutter in trap_shutters.get(arena,[]): shutter.reset_door()
	finished = false; secret_found = false; shortcut_open = false; current_room = ""; prompt = ""
	objective = "Restore power at the first arena breaker."
	for item in pickups: item.visible = true
	for mechanism in mechanisms:
		if mechanism.has_method("reset_door"): mechanism.reset_door()
		if mechanism.has_method("reset_lift"): mechanism.reset_lift()
	var spawns: Node = get_node_or_null("EnemySpawns")
	if spawns == null: return
	for index in spawns.get_child_count():
		var marker: Node = spawns.get_child(index)
		var arena := String(marker.get_meta("arena_id", ""))
		if not arena.is_empty(): arena_remaining[arena] = int(arena_remaining.get(arena, 0)) + 1
		if index < combat.enemies.size():
			var enemy: Node = combat.enemies[index]
			enemy.set_meta("arena_id", arena)
			enemy.set_meta("activate_room", marker.get_meta("activate_room", ""))
			enemy_groups[String(enemy.target_id)] = arena
func update_player(actor: CharacterBody3D, controller: Node) -> void:
	player = actor; combat = controller
	if not is_instance_valid(player) or not is_instance_valid(combat) or finished or combat.dead: return
	current_room = room_at(player.global_position)
	if not current_room.is_empty():
		visited[current_room] = true
		for room in rooms:
			if String(room.get_meta("stage_room")) == current_room and room.has_meta("arena_id") and not traps.has(String(room.get_meta("arena_id"))): activate_arena(String(room.get_meta("arena_id")))
	for enemy in combat.enemies:
		if is_instance_valid(enemy) and not enemy.dead and String(enemy.get_meta("activate_room", "")) == current_room and is_arena_active(String(enemy.get_meta("arena_id", ""))): enemy.awake = true
	for item in pickups:
		if not collected.has(item.get_instance_id()) and player.global_position.distance_to(item.global_position) < 1.2: collect(item)
	update_traps()
	var selected := nearest_mechanism()
	prompt = describe(selected) if selected != null else ""
func _physics_process(_delta: float) -> void:
	if is_instance_valid(player) and is_instance_valid(combat): update_player(player, combat)
func trigger_trap(arena: String) -> void:
	if not traps.has(arena) or traps[arena].triggered: return
	traps[arena].triggered = true
	message_changed.emit("AMBUSH · survive the weapon cache")
	objective = "Clear the ambush to reopen retreat and enable its control."
	for shutter in trap_shutters.get(arena,[]): shutter.activate()
	# The normal weapon pickup is a lure, never a permanent prerequisite.
	if int(arena_remaining.get(arena,0)) == 0: clear_trap(arena)
func clear_trap(arena: String) -> void:
	if not traps.has(arena): return
	traps[arena].cleared = true; traps[arena].latched = false
	trap_entries[arena].activate()
	flags["clear_"+arena] = true
func update_traps() -> void:
	for arena in traps:
		var state: Dictionary = traps[arena]
		if not state.triggered: continue
		var entry: Node3D = trap_entries[arena]
		if state.cleared: continue
		var normal: Vector3 = entry.get_meta("entry_normal")
		var threshold: Vector3 = entry.get_meta("entry_threshold")
		if (player.global_position-threshold).dot(normal) > 3.0 and entry.opened: entry.seal()
		state.latched = entry.is_closed()
		var exposed := true
		for shutter in trap_shutters.get(arena,[]):
			if not shutter.is_open(): exposed = false
		state.shutters_open = exposed
		if exposed and not arena_active.get(arena,false): activate_arena(arena)
func activate_arena(arena: String) -> void:
	if arena_active.has(arena): return
	arena_active[arena] = true
	if int(arena_remaining.get(arena, 0)) > 0: objective = "Clear this arena to enable its marked control."
	for enemy in combat.enemies:
		if is_instance_valid(enemy) and String(enemy.get_meta("arena_id", "")) == arena: enemy.awake = true
func handle_event(event: Dictionary) -> void:
	if String(event.get("type", "")) == "enemy_death": notify_enemy_death(String(event.get("target_id", "")), String(event.get("arena_id", "")))
func notify_enemy_death(id: String, arena: String = "") -> void:
	if id.is_empty() or dead_ids.has(id): return
	dead_ids[id] = true
	if arena.is_empty(): arena = String(enemy_groups.get(id, ""))
	if arena.is_empty() or not arena_remaining.has(arena): return
	arena_remaining[arena] = maxi(0, int(arena_remaining[arena]) - 1)
	if int(arena_remaining[arena]) == 0:
		flags["clear_" + arena] = true
		clear_trap(arena)
		if arena_active.get(arena, false): objective = "Use this arena’s enabled control."
		message_changed.emit("Arena clear · its control is enabled")
func missing_requirements(node: Node) -> Array[String]:
	var result: Array[String] = []
	for requirement in node.get_meta("requires", []):
		if not flags.get(String(requirement), false): result.append(String(requirement))
	return result
func describe(node: Node3D) -> String:
	if not missing_requirements(node).is_empty(): return String(node.get_meta("locked_message", "Access locked"))
	if node.has_meta("stage_exit"): return "E · leave " + String(get_meta("stage_title", "the stage"))
	if node.has_meta("ward_lift"): return "Lift travelling" if node.moving else "E · operate lift"
	if node.has_meta("stage_button"):
		return "Control active" if flags.get(String(node.get_meta("stage_button")), false) else "E · " + String(node.get_meta("label", "press control"))
	return "Passage open" if node.opened else "E · " + String(node.get_meta("label", "open gate"))
func nearest_mechanism() -> Node3D:
	if not is_instance_valid(player): return null
	var best: Node3D
	var distance := 2.65
	for candidate in mechanisms:
		var anchor: Vector3 = candidate.get_meta("use_anchor", Vector3.ZERO)
		var point: Vector3 = candidate.to_global(anchor)
		if candidate.has_method("reset_door"): point = candidate.get_parent().to_global(candidate.origin + anchor)
		elif candidate.has_meta("ward_lift"):
			# Fixed landing call positions remain usable while the deck is away.
			var lower: Vector3 = candidate.get_parent().to_global(candidate.origin + anchor)
			var upper: Vector3 = lower + candidate.lift_offset
			point = lower if player.global_position.distance_to(lower) <= player.global_position.distance_to(upper) else upper
		var separation: float = player.global_position.distance_to(point)
		if separation >= distance: continue
		var camera: Camera3D = player.get_node_or_null("Camera3D")
		if camera != null:
			var ray := PhysicsRayQueryParameters3D.create(camera.global_position, point, 1, [player.get_rid()])
			var hit := player.get_world_3d().direct_space_state.intersect_ray(ray)
			if not hit.is_empty() and hit.collider != candidate and hit.position.distance_to(point) > .16: continue
		best = candidate; distance = separation
	return best
func try_use(actor: CharacterBody3D = null) -> bool:
	if actor != null: player = actor
	if finished or not is_instance_valid(player) or combat.dead: return false
	var selected := nearest_mechanism()
	if selected == null: return false
	if not missing_requirements(selected).is_empty(): message_changed.emit(describe(selected)); return false
	if selected.has_meta("stage_exit"):
		finished = true; objective = String(get_meta("stage_title", "Stage")) + " cleared."; prompt = ""; completed.emit(); return true
	if selected.has_meta("stage_button"):
		var flag := String(selected.get_meta("stage_button"))
		if flags.get(flag, false): return false
		flags[flag] = true
		if flag == "breaker": flags["power"] = true
		if flag == "exit_control": flags["exit"] = true
		refresh_objective(); message_changed.emit(String(selected.get_meta("activated_message", "Control engaged"))); return true
	if selected.has_meta("ward_lift"): return selected.activate()
	if not selected.activate(flags): return false
	var id := String(selected.get_meta("stage_door"))
	if selected.has_meta("secret") and not secrets.has(id): secrets[id] = true; secret_found = true; message_changed.emit("Secret found")
	if selected.has_meta("shortcut"): shortcuts[id] = true; shortcut_open = true
	return true
func interact() -> bool: return try_use()
func collect(item: Node3D) -> void:
	var kind := String(item.get_meta("stage_pickup"))
	var amount := int(item.get_meta("amount", 25))
	if kind == "health":
		if combat.health >= 100: return
		combat.health = minf(100, combat.health + amount)
	elif kind == "armor":
		if combat.armor >= 100: return
		combat.armor = minf(100, combat.armor + amount)
	elif kind in ["pistol","shells","rivets","rockets"]: combat.add_ammo(StringName(kind),amount)
	elif kind in ["twin_shotgun","rivet_cannon","siege_launcher"]:
		combat.grant_weapon(StringName(kind),amount)
		trigger_trap(String(item.get_meta("bait_arena","")))
	elif kind in ["brass", "red", "brass_key", "red_key"]:
		if not flags.get("power", false): return
		flags[kind] = true
		flags[kind.trim_suffix("_key")] = true
		refresh_objective()
	else: return
	collected[item.get_instance_id()] = true; item.visible = false
	if kind in ["twin_shotgun","rivet_cannon","siege_launcher"]:
		var equip_key: int = {"twin_shotgun":4,"rivet_cannon":5,"siege_launcher":6}[kind]
		message_changed.emit("%s acquired · [%d] equip · AMBUSH" % [kind.replace("_"," ").capitalize(),equip_key])
	else:
		message_changed.emit(kind.trim_suffix("_key").capitalize() + " access key acquired" if kind in ["brass", "red", "brass_key", "red_key"] else "%s +%d" % [kind.capitalize(), amount])
func refresh_objective() -> void:
	if flags.get("exit", false): objective = "Reach the enabled exit."
	elif flags.get("red", false): objective = "Return to the red gate and clear the raised final arena."
	elif flags.get("release", false): objective = "Find the red access key beyond the release gate."
	elif flags.get("brass", false): objective = "Return through the shortcut to the brass gate."
	elif flags.get("power", false): objective = "Find the brass access key in the side wing."
func room_at(point: Vector3) -> String:
	var result := ""; var best := INF
	for room in rooms:
		var bounds: Vector3 = room.get_meta("room_bounds", Vector3(5, 4, 5))
		var local := room.to_local(point)
		if absf(local.x) <= bounds.x + .3 and absf(local.z) <= bounds.z + .3 and absf(local.y) <= bounds.y:
			var score := local.length_squared()
			if score < best: best = score; result = String(room.get_meta("stage_room"))
	return result
func get_chase_target(enemy_position: Vector3, player_position: Vector3) -> Vector3:
	var start := room_at(enemy_position); var goal := room_at(player_position)
	if start.is_empty() or goal.is_empty() or start == goal: return player_position
	var queue: Array[String] = [start]; var seen: Dictionary = {start: true}; var first: Dictionary = {}
	while not queue.is_empty():
		var current: String = queue.pop_front()
		for portal in navigation:
			var pair: Array = portal.get_meta("stage_nav", [])
			if pair.size() != 2 or not pair.has(current): continue
			if portal.has_meta("stage_nav_door"):
				var door: Node = portal.get_node_or_null(portal.get_meta("stage_nav_door"))
				if door != null and not door.is_open(): continue
			var next := String(pair[1] if pair[0] == current else pair[0])
			if seen.has(next): continue
			seen[next] = true; first[next] = portal if current == start else first[current]
			if next == goal:
				var selected: Node3D = first[next]
				var direction: Vector3 = player_position - selected.global_position; direction.y = 0
				return selected.global_position + direction.normalized() * 1.2
			queue.append(next)
	return enemy_position
func get_level_state() -> Dictionary:
	var map: Array[Dictionary] = []
	for room in rooms:
		var id := String(room.get_meta("stage_room"))
		if not visited.has(id): continue
		var bounds: Vector3 = room.get_meta("room_bounds")
		map.append({"id": id, "label": room.get_meta("stage_label", id), "rect": Rect2(Vector2(room.global_position.x - bounds.x, room.global_position.z - bounds.z), Vector2(bounds.x * 2, bounds.z * 2)), "visited": true, "position": room.global_position, "bounds": bounds})
	return {"objective": objective, "prompt": prompt, "current_room": current_room, "visited_rooms": visited.keys(), "map_rooms": map, "key": flags.get("brass", false), "brass_key": flags.get("brass", false), "red_key": flags.get("red", false), "power": flags.get("power", false), "arena_remaining": arena_remaining.duplicate(), "traps": traps.duplicate(true), "shortcut_open": shortcut_open, "shortcuts_open": shortcuts.size(), "secret_found": secret_found, "secrets_found": secrets.size(), "exit_ready": flags.get("exit", false), "completed": finished, "pickups_remaining": pickups.size() - collected.size(), "flags": flags.duplicate()}
func is_arena_active(arena: String) -> bool:
	return arena.is_empty() or bool(arena_active.get(arena, false))

func build_polygon(node: Node3D) -> void:
	var outline: PackedVector2Array = node.get_meta("stage_polygon")
	var height: float = node.get_meta("polygon_height",1.0)
	var vertices := PackedVector3Array()
	for elevation in [0.0,height]:
		for point in outline: vertices.append(Vector3(point.x,elevation,point.y))
	var faces: Array[Vector3i] = []
	var count := outline.size()
	for index in range(1,count-1):
		faces.append(Vector3i(0,index,index+1))
		faces.append(Vector3i(count,count+index+1,count+index))
	for index in count:
		var following := (index+1)%count
		faces.append(Vector3i(index,following,index+count))
		faces.append(Vector3i(following,following+count,index+count))
	var center := Vector3.ZERO
	for vertex in vertices: center += vertex
	center /= vertices.size()
	var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in faces:
		var a := vertices[face.x]; var b := vertices[face.y]; var c := vertices[face.z]
		var normal := (b-a).cross(c-a).normalized()
		if normal.dot((a+b+c)/3.0-center) < 0:
			var temporary := b; b=c; c=temporary; normal=-normal
		for vertex in [a,b,c]: surface.set_normal(normal); surface.add_vertex(vertex)
	var mesh := surface.commit()
	mesh.surface_set_material(0,node.get_meta("polygon_material"))
	var body := StaticBody3D.new();body.collision_layer=1;body.collision_mask=3;body.set_meta("hit_material","hard");node.add_child(body)
	var visual := MeshInstance3D.new();visual.mesh=mesh;body.add_child(visual)
	var shape := ConvexPolygonShape3D.new();shape.points=vertices
	var collider := CollisionShape3D.new();collider.shape=shape;body.add_child(collider)
