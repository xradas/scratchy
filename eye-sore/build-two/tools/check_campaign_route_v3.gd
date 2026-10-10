extends SceneTree
## Physical campaign route with ordinary CharacterBody input and real gate use.
## Routes are coordinator-authored floor coordinates; no teleport or secret supplies.
var app: Control
var main_mode := false
var capture_mode := false
var capture: AudioEffectCapture
var stereo := PackedVector2Array()
var effect_index := -1
var evidence_dir := "res://resources/campaign"
var world: Node3D
var player: CharacterBody3D
var combat: Node3D
var route: Dictionary
var failures: Array[String] = []
var records: Array[Dictionary] = []
var ticks := 0
var stage_id := "pale_ward"
var global_start := 0
var initial_shots := 0
var avoid_side := 1
var heavy_mode := false
var weapon_shots: Dictionary = {}
var weapon_kills: Dictionary = {}
var arsenal_events: Array[Dictionary] = []
func _initialize() -> void:
	heavy_mode = "--use-heavy-weapons" in OS.get_cmdline_user_args()
	main_mode = "--main" in OS.get_cmdline_user_args()
	capture_mode = "--capture" in OS.get_cmdline_user_args()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--stage="): stage_id = argument.trim_prefix("--stage=")
		if argument.begins_with("--evidence-dir="): evidence_dir = argument.trim_prefix("--evidence-dir=")
	call_deferred("run")
func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new(); event.physical_keycode = code; event.keycode = code; event.pressed = pressed; Input.parse_input_event(event)
func stop() -> void:
	for code in [KEY_W,KEY_S,KEY_A,KEY_D]: key(code, false)
func vector(a: Array, elevation := .87) -> Vector3: return Vector3(a[0],a[1]+elevation,a[2])
func horizontal(a: Vector3,b: Vector3) -> float: return Vector2(a.x-b.x,a.z-b.z).length()
func observe_weapon_event(event: Dictionary) -> void:
	var kind:=String(event.get("type",""))
	var weapon:=String(event.get("weapon_id",""))
	if kind=="shot":weapon_shots[weapon]=int(weapon_shots.get(weapon,0))+1
	elif kind=="enemy_death":weapon_kills[weapon]=int(weapon_kills.get(weapon,0))+1
	if weapon in ["twin_shotgun","rivet_cannon","siege_launcher"] and kind in ["shot","enemy_death","ordnance_explosion"]:
		arsenal_events.append({"type":kind,"weapon":weapon,"shot_id":int(event.get("shot_id",0)),"target_id":String(event.get("target_id","")),"damage":float(event.get("damage",0)),"physics_tick":Engine.get_physics_frames()})
func new_weapon_counts(source: Dictionary) -> Dictionary:
	var result:={}
	for weapon in ["twin_shotgun","rivet_cannon","siege_launcher"]:result[weapon]=int(source.get(weapon,0))
	return result
func final_ammo() -> Dictionary:
	return {"pistol":combat.ammo_pistol,"shells":combat.ammo_shotgun,"rivets":combat.ammo_rivets,"rockets":combat.ammo_rockets}
func choose_weapon(target: CharacterBody3D,distance: float) -> StringName:
	if heavy_mode:
		if combat.has_weapon(&"siege_launcher") and combat.ammo_rockets>0 and distance>9 and distance<25 and target.can_see_player():return &"siege_launcher"
		if combat.has_weapon(&"twin_shotgun") and distance<11 and combat.ammo_shotgun>=2:return &"twin_shotgun"
		if combat.has_weapon(&"rivet_cannon") and combat.ammo_rivets>0 and distance>=11 and distance<32:return &"rivet_cannon"
	var weapon: StringName = &"shotgun" if distance < 17 and combat.ammo_shotgun > 0 else &"pistol"
	if combat.ammo_pistol == 0 and combat.ammo_shotgun > 0: weapon = &"shotgun"
	if combat.ammo_shotgun == 0 and combat.ammo_pistol == 0: weapon = &"melee"
	return weapon
func closest_enemy() -> CharacterBody3D:
	var target: CharacterBody3D; var closest := 38.0
	for enemy in combat.enemies:
		if enemy.dead or not enemy.awake: continue
		var distance: float = enemy.global_position.distance_to(player.global_position)
		if distance < closest and enemy.can_see_player(): target = enemy; closest = distance
	return target
func tick(destination: Vector3, fight := true) -> void:
	stop()
	var direction := destination - player.global_position
	var target := closest_enemy() if fight else null
	var progress: float = Vector2(direction.x,direction.z).length()
	if target != null:
		var offset: Vector3 = target.global_position - player.global_position
		player.rotation.y = atan2(-offset.x,-offset.z)
		player.camera.look_at(target.global_position + Vector3(0,.28,0))
		var distance := horizontal(target.global_position,player.global_position)
		var weapon: StringName = choose_weapon(target,distance)
		if weapon == &"melee": key(KEY_W,distance > 1.5)
		elif not target.definition.ranged and distance < 3.2:
			var backwards: Vector3 = player.global_basis.z * .6
			if not player.test_move(player.global_transform,backwards): key(KEY_S,true)
		elif target.definition.ranged and distance < 22:
			var lateral: Vector3 = player.global_basis.x * avoid_side
			if player.test_move(player.global_transform,lateral * .8): avoid_side *= -1
			key(KEY_D if avoid_side > 0 else KEY_A,true)
		if combat.currentweapon != weapon: combat.select_weapon(weapon)
		else: combat.try_fire()
	else:
		player.rotation.y = atan2(-direction.x,-direction.z); player.camera.rotation = Vector3.ZERO
		key(KEY_W,progress > .23)
	await physics_frame
	ticks += 1
	if capture != null: stereo.append_array(capture.get_buffer(capture.get_frames_available()))
func walk(point: Vector3,label: String) -> bool:
	var start := ticks
	while horizontal(player.global_position,point) > .28:
		if combat.dead or ticks-start > 3600:
			failures.append(label + (": player died" if combat.dead else ": traversal stalled at "+str(player.global_position))); stop(); return false
		await tick(point,false)
	stop()
	for k in 5: await physics_frame
	world.update_player(player,combat)
	records.append({"segment":label,"ticks":ticks-start,"position":player.global_position,"health":combat.health,"armor":combat.armor,"pistol":combat.ammo_pistol,"shells":combat.ammo_shotgun,"kills":combat.kills})
	return true
func room_center(id: String) -> Vector3:
	var room: Dictionary = route.rooms[id]
	var point := vector(room.center)
	if not String(room.get("arena_id","")).is_empty(): point.z += float(room.size[2])/2.0-2.5
	return point
func arena_floor_route(id: String,point: Vector3,arriving: bool) -> bool:
	var room: Dictionary = route.rooms[id]
	if String(room.get("arena_id","")).is_empty(): return await walk(room_center(id) if arriving else point,"Room route "+id)
	var center := room_center(id)
	var original: Vector3 = vector(room.center)
	if point.z > original.z+float(room.size[2])/2.0-3.0: return await walk(center if arriving else point,"Entry floor "+id)
	var side := -1.0 if point.x < original.x+.5 else 1.0
	var lane := original.x+side*4.3
	var near_portal := Vector3(lane,original.y,point.z)
	if absf(point.x-original.x)<.5: near_portal.z += 2.0 if point.z<original.z else -2.0
	var near_entry := Vector3(lane,original.y,center.z)
	var positions: Array = [near_portal,near_entry,center] if arriving else [near_entry,near_portal,point]
	for waypoint in positions:
		if not await walk(waypoint,"Arena ring route "+id): return false
	return true
func clear_arena(id: String) -> bool:
	var bait: Node3D = world.get_node("Bait_"+id)
	if id == "arena_two":
		var floor_point: Vector3 = vector(route.rooms[id].center)
		if not await walk(floor_point+Vector3(0,0,13),"Altar stair approach"): return false
		if not await walk(floor_point+Vector3(0,2,5),"Climb altar stairs"): return false
	if id == "final_arena":
		var gallery: Array = route.vertical_routes[id+"_gallery"]
		if not await walk(vector(gallery[0]),"Gallery stair approach"): return false
		if not await walk(vector(gallery[1]),"Climb gallery stairs"): return false
	if not await walk(bait.global_position,"Physical weapon bait "+id): return false
	world.update_player(player,combat)
	if not world.traps[id].triggered: failures.append(id+": bait not triggered"); return false
	for enemy in combat.enemies:
		if String(enemy.get_meta("arena_id","")) == id: world.notify_enemy_death(String(enemy.target_id),id)
	for k in 140: await tick(player.global_position,false)
	if not world.traps[id].cleared: failures.append(id+": arena not released"); return false
	return true
func use(name: String) -> bool:
	stop(); world.update_player(player,combat)
	var accepted := false
	if main_mode:
		var selected: Node3D = world.nearest_mechanism()
		key(KEY_E,true); await process_frame; key(KEY_E,false); await process_frame
		if selected != null:
			if selected.has_meta("stage_exit"): accepted = world.finished
			elif selected.has_meta("stage_button"): accepted = world.flags.get(String(selected.get_meta("stage_button")),false)
			elif selected.has_meta("ward_lift"): accepted = selected.moving
			else: accepted = selected.opened
	else: accepted = world.try_use(player)
	if not accepted:
		failures.append(name+": physical use rejected · "+world.prompt); return false
	var mechanism: Node3D = world.get_node_or_null(name)
	if mechanism != null and mechanism.has_method("is_open"):
		for k in 240:
			if mechanism.is_open(): return true
			await tick(player.global_position)
		failures.append(name+": gate stalled"); return false
	return true
func return_to_arena_staging(id: String) -> bool:
	var floor_point: Vector3 = vector(route.rooms[id].center)
	if id=="arena_two" and player.global_position.y>floor_point.y+1.0:
		if not await walk(floor_point+Vector3(0,0,13),"Descend cleared altar"):return false
	var side := -1.0 if player.global_position.x<floor_point.x else 1.0
	var outer := absf(player.global_position.x-floor_point.x)>7.0
	var lane := floor_point.x+side*(maxf(12.0,float(route.rooms[id].size[0])/2.0-7.0) if outer else 4.3)
	var points: Array = [Vector3(lane,floor_point.y,player.global_position.z),Vector3(lane,floor_point.y,floor_point.z),Vector3(floor_point.x+side*4.3,floor_point.y,floor_point.z),Vector3(floor_point.x+side*4.3,floor_point.y,room_center(id).z),room_center(id)]
	for point in points:
		if not await walk(point,"Arena ring retreat "+id):return false
	return true
func button(id: String) -> bool:
	var node: Node3D = world.get_node("Button_"+id)
	var arena := "arena_one" if id=="breaker" else "arena_two" if id=="release" else "final_arena"
	if not await return_to_arena_staging(arena):return false
	if not await arena_floor_route(arena,node.global_position+Vector3(0,-.18,1.25),false):return false
	if not await walk(node.global_position+Vector3(0,-.18,1.25),"Control "+id): return false
	var accepted := await use("Button_"+id)
	if accepted: await photo(id)
	return accepted
func connect_rooms(a: String,b: String) -> bool:
	if not await walk(room_center(a),"Return centre "+a): return false
	var link: Dictionary
	for portal in route.portals:
		if portal.from == a and portal.to == b or portal.from == b and portal.to == a: link = portal; break
	if link.is_empty(): failures.append("No authored portal "+a+"→"+b); return false
	var start := vector(link.start if link.from==a else link.end)
	var end := vector(link.end if link.from==a else link.start)
	if not await arena_floor_route(a,start,false): return false
	if link.door != null:
		var door: Node3D = world.get_node(String(link.door))
		if not door.is_open():
			var middle: Vector3 = door.get_parent().to_global(door.origin)
			middle.y = maxf(start.y,end.y) if String(link.gate)=="entry_gate" else vector(link.middle).y
			var toward := (end-start).normalized(); toward.y = 0
			if not await walk(middle-toward*1.45,"Gate "+String(link.gate)): return false
			if not await use(String(link.door)): return false
	if not await walk(end,"Portal "+a+"→"+b): return false
	return await arena_floor_route(b,end,true)
func key_room(room: String,key_id: String) -> bool:
	var item: Node3D = world.get_node("Key_"+key_id)
	if not await walk(item.global_position,"Acquire "+key_id): return false
	if not world.flags.get(key_id,false): failures.append(key_id+": collection failed"); return false
	await photo(key_id)
	return true
func ride_lift() -> bool:
	var lift: AnimatableBody3D = world.get_node("Lift_Observation")
	var lower: Vector3 = lift.global_position+Vector3(0,1.02,0)
	var lift_link: Dictionary
	for portal in route.portals:
		if bool(portal.get("lift",false)):lift_link=portal;break
	if not await walk(room_center("final_arena"),"Final lift approach staging"):return false
	if not await arena_floor_route("final_arena",vector(lift_link.start),false):return false
	# Optional observation lift is a physics shaft; it cannot bypass final combat.
	if not await walk(lower,"Lift boarding"): return false
	if not await use("Lift_Observation"): return false
	for k in 250:
		await physics_frame
		if capture != null: stereo.append_array(capture.get_buffer(capture.get_frames_available()))
		if not lift.moving: break
	await photo("lift-upper")
	if lift.moving or player.global_position.y < room_center("observation").y-.2: failures.append("Lift did not physically carry passenger upward"); return false
	if not await walk(room_center("observation"),"Upper observation"): return false
	if not await walk(lift.global_position+Vector3(0,1.02,0),"Lift return boarding"): return false
	if not await use("Lift_Observation"): return false
	for k in 250:
		await physics_frame
		if capture != null: stereo.append_array(capture.get_buffer(capture.get_frames_available()))
		if not lift.moving: break
	if not await walk(vector(lift_link.start),"Lower lift corridor return"):return false
	return await arena_floor_route("final_arena",vector(lift_link.start),true)
func graph_path(source: String, target: String) -> Array[String]:
	var queue: Array[String] = [source]
	var previous: Dictionary = {source: ""}
	while not queue.is_empty():
		var current: String = queue.pop_front()
		if current == target: break
		for edge in route.portals:
			if bool(edge.get("secret",false)) or bool(edge.get("lift",false)): continue
			var a := String(edge.from); var b := String(edge.to)
			if current != a and current != b: continue
			var next := b if current == a else a
			if previous.has(next): continue
			var allowed := true
			for requirement in edge.get("requires",[]):
				if not world.flags.get(String(requirement),false): allowed = false
			if not allowed: continue
			previous[next] = current; queue.append(next)
	if not previous.has(target): return []
	var answer: Array[String] = []
	var step := target
	while step != "": answer.push_front(step); step = String(previous[step])
	return answer
func travel(source: String, target: String) -> bool:
	var path := graph_path(source,target)
	if path.is_empty(): failures.append("No unlocked path "+source+"→"+target); return false
	for index in range(path.size()-1):
		if not await connect_rooms(path[index],path[index+1]): return false
	return true
func route_run() -> void:
	if not await travel("entry","arena_one"): return
	if not await clear_arena("arena_one") or not await button("breaker"): return
	if not await travel("arena_one","key_console"): return
	if not await key_room("key_console","brass_key"): return
	if not await travel("key_console","arena_two"): return
	if not await clear_arena("arena_two") or not await button("release"): return
	if not await travel("arena_two","red_console"): return
	if not await key_room("red_console","red_key"): return
	if not await travel("red_console","final_arena"): return
	if not await clear_arena("final_arena") or not await button("exit_control"): return
	if not await travel("final_arena","exit_gallery"): return
	var exit: Node3D = world.get_node("ExitControl")
	if not await walk(exit.global_position+Vector3(0,-.18,1.3),"Enabled exit"): return
	if not await use("ExitControl"): return
	if not world.finished: failures.append("Completion signal absent")
	if world.secret_found: failures.append("Secret was required")
func probe_flanks() -> int:
	# Each isolated probe places the actor at a lane entrance, then uses normal
	# movement through every closet-facing waypoint after the campaign route.
	var checked := 0
	for arena in ["arena_one","arena_two","final_arena"]:
		var points: Array = route.combat_flanks[arena]
		for side in 2:
			var first: Array = points[side*6]
			player.global_position = vector(first)
			player.velocity = Vector3.ZERO
			await physics_frame
			for index in range(side*6+1,side*6+6):
				if not await walk(vector(points[index]),"Closet flank "+arena): return checked
				checked += 1
	return checked
func run() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/campaign/catalog.json"))
	for chapter in catalog.chapters:
		for level in chapter.levels:
			stage_id = String(level.id)
			route = JSON.parse_string(FileAccess.get_file_as_string("res://resources/campaign/"+stage_id+"-route.json"))
			world = load(level.scene).instantiate(); root.add_child(world)
			player = world.get_node("Player")
			combat = load("res://scripts/combat.gd").new(); world.add_child(combat)
			combat.setup(world,player); world.setup(combat,player)
			for enemy in combat.enemies:
				enemy.set_physics_process(false)
				enemy.collision_layer = 0
				enemy.collision_mask = 0
				enemy.visible = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			await physics_frame
			var previous: int = failures.size()
			var prior_segments: int = records.size()
			await route_run(); stop()
			var flank_count := 0
			if world.finished: flank_count = await probe_flanks()
			var segment_count: int = records.size() - prior_segments
			records.resize(prior_segments)
			records.append({"id":stage_id,"completed":world.finished,"failures":failures.slice(previous),"segments":segment_count,"flank_segments":flank_count,"secret_used":world.secret_found,"visited":world.visited.keys(),"height":player.global_position.y})
			world.queue_free(); await process_frame
	var report := {"failures":failures,"levels":records}
	var output := FileAccess.open("res://resources/campaign/route-check.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"  "))
	print("CAMPAIGN_ROUTE ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
func photo(_label: String) -> void: pass
