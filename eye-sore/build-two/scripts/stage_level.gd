extends Node3D
signal checkpoint_reached(checkpoint_id: String)
@export var objective_profile: StageObjectiveProfile = null
const CheckpointState := preload("res://scripts/stage_checkpoint_v13.gd")
var checkpoint_markers: Array[Node3D] = []
var checkpoint_used: Dictionary = {}
var checkpoint_dwell := 0.0
var checkpoint_candidate := ""
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
	rooms.clear(); navigation.clear(); pickups.clear(); mechanisms.clear(); trap_entries.clear(); trap_shutters.clear(); checkpoint_markers.clear()
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
		if node.has_meta("checkpoint_id"): checkpoint_markers.append(node)
		if node.has_meta("stage_door") or node.has_meta("stage_button") or node.has_meta("ward_lift") or node.has_meta("stage_exit") or node.has_method("is_shootable_mechanism"):
			mechanisms.append(node)
			if node.has_method("is_shootable_mechanism"): node.setup(self)
	for child in node.get_children(): scan(child)
func reset() -> void:
	flags.clear(); collected.clear(); visited.clear(); dead_ids.clear(); arena_remaining.clear(); arena_active.clear(); enemy_groups.clear(); secrets.clear(); shortcuts.clear()
	traps.clear(); checkpoint_used.clear(); checkpoint_dwell=0.0; checkpoint_candidate=""
	if objective_profile!=null: flags=objective_profile.initial_flags.duplicate(true)
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
		if mechanism.has_method("reset_mechanism"): mechanism.reset_mechanism()
	if objective_profile!=null: refresh_objective()
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
	if get_tree().paused or not is_instance_valid(player) or not is_instance_valid(combat) or finished or combat.dead: return
	current_room = room_at(player.global_position)
	if not current_room.is_empty():
		visited[current_room] = true
		if objective_profile!=null and not flags.get("visited_"+current_room,false):
			flags["visited_"+current_room]=true;refresh_objective()
		for room in rooms:
			if String(room.get_meta("stage_room"))!=current_room or not room.has_meta("arena_id"):continue
			var arena:=String(room.get_meta("arena_id"))
			if is_pickup_arena(arena):continue
			var authored_room_entry:=false
			if objective_profile!=null:
				for encounter in objective_profile.encounters.values():
					if String(encounter.get("arena_id",""))==arena and String(encounter.get("activation",""))=="room_entry":authored_room_entry=true
			if authored_room_entry:
				if traps.has(arena):trigger_trap(arena)
				activate_arena(arena)
			elif not traps.has(arena):activate_arena(arena)
	for enemy in combat.enemies:
		if is_instance_valid(enemy) and not enemy.dead and String(enemy.get_meta("activate_room", "")) == current_room and is_arena_active(String(enemy.get_meta("arena_id", ""))): enemy.awake = true
	# Nearby ordinary bonuses may collect in this same tick. Finish with the
	# accepted reserve so its authored warning remains the visible message.
	var encounter_rewards:Array[Node3D]=[]
	for item in pickups:
		if not collected.has(pickup_identity(item)) and player.global_position.distance_to(item.global_position) < 1.2:
			if objective_profile!=null and not pickup_encounters_for_id(String(pickup_identity(item))).is_empty():encounter_rewards.append(item)
			else:collect(item)
	for item in encounter_rewards:collect(item)
	update_traps()
	var selected := nearest_mechanism()
	prompt = describe(selected) if selected != null else ""
func _physics_process(delta: float) -> void:
	if is_instance_valid(player) and is_instance_valid(combat):
		update_player(player, combat)
		if objective_profile!=null: update_checkpoints(delta)
func trigger_trap(arena: String) -> void:
	if not traps.has(arena) or traps[arena].triggered: return
	traps[arena].triggered = true
	var warning := "AMBUSH · survive the weapon cache"
	if objective_profile!=null:
		warning="DECONTAMINATION LOCKDOWN · clear the chamber"
		for encounter in objective_profile.encounters.values():
			if String(encounter.get("arena_id",""))==arena:warning=String(encounter.get("message",warning))
	message_changed.emit(warning)
	if objective_profile==null: objective = "Clear the ambush to reopen retreat and enable its control."
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
	if objective_profile==null and int(arena_remaining.get(arena, 0)) > 0: objective = "Clear this arena to enable its marked control."
	for enemy in combat.enemies:
		if is_instance_valid(enemy) and String(enemy.get_meta("arena_id", "")) == arena: enemy.awake = true
func is_pickup_arena(arena: String) -> bool:
	if objective_profile==null or arena.is_empty():return false
	for encounter in objective_profile.encounters.values():
		if String(encounter.get("activation",""))=="pickup" and String(encounter.get("arena_id",""))==arena:return true
	return false
func is_pickup_release_door(node: Node) -> bool:
	if objective_profile==null:return false
	var id:=String(node.get_meta("stable_id",""))
	if id.is_empty():return false
	for encounter in objective_profile.encounters.values():
		if String(encounter.get("activation",""))=="pickup" and encounter.get("release_doors",[]).has(id):return true
	return false
func pickup_encounters_for_id(pickup_id: String) -> Array[Dictionary]:
	var result:Array[Dictionary]=[]
	if objective_profile!=null:
		for encounter in objective_profile.encounters.values():
			if String(encounter.get("activation",""))=="pickup" and String(encounter.get("pickup_id",""))==pickup_id:result.append(encounter)
	return result
func activate_pickup_encounters(pickup_id: String) -> String:
	if objective_profile==null:return ""
	var warning:=""
	for encounter in pickup_encounters_for_id(pickup_id):
		var arena:=String(encounter.get("arena_id",""))
		if arena.is_empty() or arena_active.get(arena,false) or not objective_profile.unmet(encounter.get("requires",[]),flags).is_empty():continue
		var release_doors:Array[Node3D]=[]
		var valid:=true
		for id in encounter.get("release_doors",[]):
			var selected:Node3D
			for mechanism in mechanisms:
				if String(mechanism.get_meta("stable_id",""))==String(id) and mechanism.has_method("reset_door"):
					selected=mechanism;break
			if selected==null or not missing_requirements(selected).is_empty():valid=false;break
			release_doors.append(selected)
		if not valid:continue
		for door in release_doors:door.activate(flags)
		activate_arena(arena)
		warning=String(encounter.get("message","Reserve opened · retreat remains clear"))
	return warning
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
		if objective_profile==null and arena_active.get(arena, false): objective = "Use this arena’s enabled control."
		if objective_profile!=null:
			for encounter in objective_profile.encounters.values():
				if String(encounter.get("arena_id",""))==arena:
					var flag := String(encounter.get("completion_flag",""))
					if not flag.is_empty(): flags[flag]=true
			refresh_objective()
		var message := "Arena clear · its control is enabled"
		if objective_profile!=null:
			message="Decontamination clear · transfer exit released"
			for encounter in objective_profile.encounters.values():
				if String(encounter.get("arena_id",""))==arena:message=String(encounter.get("completion_message",message))
		message_changed.emit(message)
func missing_requirements(node: Node) -> Array[String]:
	var result: Array[String] = []
	var requirements: Array = node.get_meta("requires", []).duplicate()
	if objective_profile!=null:
		if node.has_meta("stage_button"): requirements.append_array(objective_profile.controls.get(String(node.get_meta("stage_button")),{}).get("requires",[]))
		if node.has_meta("stage_exit"): requirements.append_array(objective_profile.exit_requires)
	for requirement in requirements:
		if not flags.get(String(requirement), false): result.append(String(requirement))
	# Authored one-way release applies only until its first accepted opening.
	# Use a world-space door-plane normal: corridor controls can lie outside rooms.
	if node.has_meta("first_open_normal") and not bool(node.get("opened")):
		var normal: Vector3 = node.get_meta("first_open_normal")
		if not is_instance_valid(player) or normal.length_squared() < .0001 or (player.global_position - node.global_position).dot(normal.normalized()) < .05:
			result.append("first_open_side")
	return result
func describe(node: Node3D) -> String:
	if not missing_requirements(node).is_empty(): return String(node.get_meta("locked_message", "Access locked"))
	if node.has_meta("stage_exit"): return "E · leave " + String(get_meta("stage_title", "the stage"))
	if node.has_meta("ward_lift"):
		if node.obstructed: return "Lift blocked · clear the lower landing"
		return "Lift travelling" if node.moving else "E · call / operate lift"
	if node.has_meta("stage_button"):
		return "Control active" if flags.get(String(node.get_meta("stage_button")), false) else "E · " + String(node.get_meta("label", "press control"))
	return "Passage open" if node.opened else "E · " + String(node.get_meta("label", "open gate"))
func nearest_mechanism() -> Node3D:
	if not is_instance_valid(player): return null
	var best: Node3D
	var distance := 2.65
	for candidate in mechanisms:
		if candidate.has_method("is_shootable_mechanism") or bool(candidate.get_meta("auto_open",false)) or is_pickup_release_door(candidate): continue
		var anchor: Vector3 = candidate.get_meta("use_anchor", Vector3.ZERO)
		var point: Vector3 = candidate.to_global(anchor)
		if candidate.has_method("reset_door"): point = candidate.get_parent().to_global(candidate.origin + anchor)
		var points: Array[Vector3] = [point]
		if candidate.has_meta("ward_lift"):
			# Keep passenger and shaft-base calls, and add fixed buttons outside
			# each guard. A closed landing must never hide the only call point.
			var lower: Vector3 = candidate.get_parent().to_global(candidate.origin + anchor)
			points.append(lower)
			points.append(lower + candidate.lift_offset)
			for landing in ["lower", "upper"]:
				var call_anchor: Vector3 = candidate.get_meta(landing + "_use_anchor", anchor)
				var offset: Vector3 = candidate.lift_offset if landing == "upper" else Vector3.ZERO
				points.append(candidate.get_parent().to_global(candidate.origin + offset + call_anchor))
		for use_point in points:
			var separation: float = player.global_position.distance_to(use_point)
			if separation >= distance: continue
			var camera: Camera3D = player.get_node_or_null("Camera3D")
			if camera != null:
				var ray := PhysicsRayQueryParameters3D.create(camera.global_position, use_point, 1, [player.get_rid()])
				var hit := player.get_world_3d().direct_space_state.intersect_ray(ray)
				if not hit.is_empty() and hit.collider != candidate and hit.position.distance_to(use_point) > .16: continue
			best = candidate; distance = separation
	return best
func try_use(actor: CharacterBody3D = null) -> bool:
	if actor != null: player = actor
	if finished or not is_instance_valid(player) or combat.dead or (objective_profile!=null and get_tree().paused): return false
	var selected := nearest_mechanism()
	if selected == null: return false
	if not missing_requirements(selected).is_empty(): message_changed.emit(describe(selected)); return false
	if selected.has_meta("stage_exit"):
		finished = true
		if objective_profile!=null: flags["finished"]=true
		objective = String(get_meta("stage_title", "Stage")) + " cleared."; prompt = ""; completed.emit(); return true
	if selected.has_meta("stage_button"):
		var flag := String(selected.get_meta("stage_button"))
		if flags.get(flag, false): return false
		flags[flag] = true
		if objective_profile!=null:
			for granted in objective_profile.controls.get(flag,{}).get("sets",[flag]): flags[String(granted)]=true
		else:
			if flag == "breaker": flags["power"] = true
			if flag == "exit_control": flags["exit"] = true
		refresh_objective()
		var activation_message:=String(selected.get_meta("activated_message", "Control engaged"))
		var complete_requires:Array=selected.get_meta("activated_complete_requires",[])
		if objective_profile!=null and not complete_requires.is_empty() and objective_profile.unmet(complete_requires,flags).is_empty():
			activation_message=String(selected.get_meta("activated_complete_message",activation_message))
		message_changed.emit(activation_message); return true
	if selected.has_meta("ward_lift"):
		var accepted: bool = selected.activate()
		if not accepted and not selected.moving: message_changed.emit("Stand clear of the lift entrance before operating it")
		return accepted
	if not selected.activate(flags): return false
	var id := String(selected.get_meta("stage_door"))
	if selected.has_meta("secret") and not secrets.has(id): secrets[id] = true; secret_found = true; message_changed.emit("Secret found")
	if selected.has_meta("shortcut"): shortcuts[id] = true; shortcut_open = true
	return true
func interact() -> bool: return try_use()
func collect(item: Node3D) -> void:
	if get_tree().paused or combat.dead or collected.has(pickup_identity(item)): return
	if objective_profile!=null and not missing_requirements(item).is_empty(): return
	if objective_profile!=null:
		for encounter in pickup_encounters_for_id(String(pickup_identity(item))):
			if not objective_profile.unmet(encounter.get("requires",[]),flags).is_empty():return
	var kind := String(item.get_meta("stage_pickup"))
	var amount := int(item.get_meta("amount", 25))
	var receipt_kind := kind
	var accepted_amount: Variant = amount
	var receipt_accepted := true
	var new_weapon := false
	if kind == "health":
		if combat.health >= 100: return
		var before: float = combat.health
		combat.health = minf(100, combat.health + amount)
		accepted_amount = combat.health - before
		receipt_accepted = accepted_amount > 0
	elif kind == "armor":
		if combat.armor >= 100: return
		var before: float = combat.armor
		combat.armor = minf(100, combat.armor + amount)
		accepted_amount = combat.armor - before
		receipt_accepted = accepted_amount > 0
	elif kind in ["pistol","shells","rivets","rockets"]:
		var before: int = combat.ammo_amount(StringName(kind))
		if not combat.add_ammo(StringName(kind),amount): return
		amount = combat.ammo_amount(StringName(kind)) - before
		accepted_amount = amount
	elif kind in ["twin_shotgun","rivet_cannon","siege_launcher"]:
		var bait_arena := String(item.get_meta("bait_arena",""))
		receipt_kind = "weapon"
		new_weapon = not combat.has_weapon(StringName(kind))
		var ammo_key: StringName = combat.weapons[StringName(kind)].ammo_key
		var before: int = combat.ammo_amount(ammo_key)
		var accepted: bool = combat.grant_weapon(StringName(kind),amount)
		accepted_amount = combat.ammo_amount(ammo_key) - before
		receipt_accepted = accepted
		# A full carried weapon can still spring a physical lure on the next level.
		if not bait_arena.is_empty(): trigger_trap(bait_arena)
		elif not accepted: return
	elif objective_profile!=null and objective_profile.keys.has(kind.trim_suffix("_key")):
		var key_id := kind.trim_suffix("_key")
		var rules: Dictionary = objective_profile.keys[key_id]
		if not objective_profile.unmet(rules.get("requires",[]),flags).is_empty(): return
		receipt_kind=key_id+"_key";receipt_accepted=not flags.get(key_id,false);accepted_amount=1
		for granted in rules.get("sets",[key_id,key_id+"_key"]): flags[String(granted)]=true
		refresh_objective()
	elif kind in ["brass", "red", "brass_key", "red_key"]:
		if objective_profile!=null or not flags.get("power", false): return
		receipt_kind = kind.trim_suffix("_key") + "_key"
		receipt_accepted = not flags.get(kind.trim_suffix("_key"), false)
		accepted_amount = 1
		flags[kind] = true
		flags[kind.trim_suffix("_key")] = true
		refresh_objective()
	else: return
	collected[pickup_identity(item)] = true; item.visible = false
	# One authoritative receipt follows actual accepted mutation. Inventory events
	# remain separate; saturated owned bait may still trigger its trap silently.
	if receipt_accepted:
		combat.emit_event({"type": &"item_collected", "item_kind": StringName(receipt_kind), "pickup_id": pickup_identity(item), "amount": accepted_amount, "new_weapon": new_weapon, "position": item.global_position})
		var encounter_message:=activate_pickup_encounters(String(pickup_identity(item))) if objective_profile!=null else ""
		if not encounter_message.is_empty():message_changed.emit(encounter_message);return
	if kind in ["twin_shotgun","rivet_cannon","siege_launcher"]:
		var equip_key: int = {"twin_shotgun":4,"rivet_cannon":5,"siege_launcher":6}[kind]
		message_changed.emit("%s cache · [%d] equip · AMBUSH" % [kind.replace("_"," ").capitalize(),equip_key])
	else:
		message_changed.emit(kind.trim_suffix("_key").capitalize() + " access key acquired" if kind in ["brass", "red", "brass_key", "red_key"] else "%s +%d" % [kind.capitalize(), amount])
func refresh_objective() -> void:
	if objective_profile!=null:
		objective=objective_profile.objective_text(flags)
		refresh_automatic_doors()
		return
	if flags.get("exit", false): objective = "Reach the enabled exit."
	elif flags.get("red", false): objective = "Return to the red gate and clear the raised final arena."
	elif flags.get("release", false): objective = "Find the red access key beyond the release gate."
	elif flags.get("brass", false): objective = "Return through the shortcut to the brass gate."
	elif flags.get("power", false): objective = "Find the brass access key in the side wing."
func refresh_automatic_doors() -> void:
	# Opt-in solid shutters retain ordinary door motion/snapshots. Derive the
	# cosmetic surface synchronously, before authorizing any physical opening.
	for mechanism in mechanisms:
		if not bool(mechanism.get_meta("auto_open",false)) or not mechanism.has_method("reset_door"): continue
		var drain_path:=NodePath(String(mechanism.get_meta("drain_controller","")))
		if drain_path.is_empty(): continue
		var drain:=get_node_or_null(drain_path)
		if drain==null or not drain.has_method("refresh_visual") or not drain.has_method("is_drained"): continue
		drain.refresh_visual()
		if missing_requirements(mechanism).is_empty() and drain.is_drained(): mechanism.activate(flags)
func room_at(point: Vector3) -> String:
	var result := ""; var best := INF
	for room in rooms:
		var bounds: Vector3 = room.get_meta("room_bounds", Vector3(5, 4, 5))
		var local := room.to_local(point)
		if room.has_meta("footprint_xz"):
			var footprint:PackedVector2Array=room.get_meta("footprint_xz")
			if footprint.size()<3 or not Geometry2D.is_point_in_polygon(Vector2(local.x,local.z),footprint):continue
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
		if room.has_meta("footprint_xz"):
			var footprint:=PackedVector2Array()
			for vertex in room.get_meta("footprint_xz"):
				var world_vertex:Vector3=room.to_global(Vector3(vertex.x,0,vertex.y))
				footprint.append(Vector2(world_vertex.x,world_vertex.z))
			map.back().footprint=footprint
			map.back().rect_is_envelope=true
	return {"objective": objective, "prompt": prompt, "current_room": current_room, "visited_rooms": visited.keys(), "map_rooms": map, "key": flags.get("brass", false), "brass_key": flags.get("brass", false), "red_key": flags.get("red", false), "power": flags.get("power", false), "arena_remaining": arena_remaining.duplicate(), "traps": traps.duplicate(true), "shortcut_open": shortcut_open, "shortcuts_open": shortcuts.size(), "secret_found": secret_found, "secrets_found": secrets.size(), "exit_ready": flags.get("exit", false) if objective_profile==null else objective_profile.unmet(objective_profile.exit_requires,flags).is_empty(), "completed": finished, "pickups_remaining": pickups.size() - collected.size(), "flags": flags.duplicate()}
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

func pickup_identity(item: Node) -> Variant:
	return String(item.get_meta("stable_id",get_path_to(item))) if objective_profile!=null else item.get_instance_id()

func set_progress_flag(flag: String) -> void:
	if flag.is_empty():return
	flags[flag]=true;refresh_objective()

func checkpoint_mechanisms() -> Array[Node3D]:
	var result:Array[Node3D]=mechanisms.duplicate()
	for entry in trap_entries.values():
		if entry not in result:result.append(entry)
	for shutters in trap_shutters.values():
		for shutter in shutters:
			if shutter not in result:result.append(shutter)
	return result

func checkpoint_is_safe() -> bool:
	if objective_profile==null or get_tree().paused or finished or not is_instance_valid(player) or combat.dead:return false
	if not player.is_on_floor() or player.velocity.length_squared()>.01:return false
	for child in combat.get_children():
		if child.has_method("is_combat_projectile") and not child.resolved:return false
	for node in checkpoint_mechanisms():
		if node.has_method("reset_lift") and (node.moving or node.departure_pending or node.obstructed):return false
		if node.has_method("reset_door"):
			if node.opened and not node.is_open():return false
			if CheckpointState.has_property(node,"sealing") and node.sealing and not node.is_closed():return false
	var radius := float(objective_profile.checkpoint_options.get("threat_radius",10.0))
	for enemy in combat.enemies:
		if not is_instance_valid(enemy) or enemy.dead:continue
		var distance:float=enemy.global_position.distance_to(player.global_position)
		if distance<radius:return false
		if enemy.awake and distance<maxf(radius,enemy.definition.attack_range+2.0) and enemy.can_see_player():return false
	return true

func update_checkpoints(delta: float) -> void:
	if objective_profile==null or get_tree().paused or finished or combat.dead:return
	var selected:Node3D
	for marker in checkpoint_markers:
		var id:=String(marker.get_meta("checkpoint_id"))
		if checkpoint_used.has(id) or not missing_requirements(marker).is_empty():continue
		if player.global_position.distance_to(marker.global_position)<=float(marker.get_meta("radius",1.5)):
			selected=marker;break
	if selected==null:checkpoint_dwell=0.0;checkpoint_candidate="";return
	# Keep the E-use prompt when a real nearby control/gate is selected.
	var show_checkpoint_prompt:=nearest_mechanism()==null
	if not player.is_on_floor() or player.velocity.length_squared()>.01:
		checkpoint_dwell=0.0;checkpoint_candidate=""
		if show_checkpoint_prompt:prompt="Checkpoint · stop here to secure progress"
		return
	if not checkpoint_is_safe():
		checkpoint_dwell=0.0;checkpoint_candidate=""
		if show_checkpoint_prompt:prompt="Checkpoint waiting · clear nearby threats"
		return
	var id:=String(selected.get_meta("checkpoint_id"))
	if id!=checkpoint_candidate:checkpoint_candidate=id;checkpoint_dwell=0.0
	checkpoint_dwell+=delta
	if show_checkpoint_prompt:prompt="Checkpoint · securing progress…"
	if checkpoint_dwell<float(objective_profile.checkpoint_options.get("stationary_seconds",.5)):return
	checkpoint_used[id]=true;checkpoint_dwell=0.0
	if show_checkpoint_prompt:prompt="Checkpoint secured"
	checkpoint_reached.emit(id)

func capture_checkpoint_state() -> Dictionary:
	return CheckpointState.capture(self) if objective_profile!=null else {}

func restore_checkpoint_state(data: Dictionary) -> bool:
	if not CheckpointState.restore(self,data):return false
	for item in pickups:item.visible=not collected.has(pickup_identity(item))
	return true
