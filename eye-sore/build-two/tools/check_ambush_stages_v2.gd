extends SceneTree
## State/collider contract fixture. Full traversal is the ordinary input route bot.
var failures: Array[String] = []
var records: Array[Dictionary] = []
func _initialize() -> void: call_deferred("run")
func check(condition: bool,message: String) -> void:
	if not condition: failures.append(message);push_error(message)
func floor_vector(point: Array) -> Vector3: return Vector3(point[0],point[1],point[2])
func walk_height_route(actor: CharacterBody3D,points: Array,label: String) -> Dictionary:
	# Only the fixture's initial placement is direct; every route edge uses W input.
	actor.global_position=floor_vector(points[0])+Vector3(0,.87,0)
	actor.velocity=Vector3.ZERO;actor.set_physics_process(true)
	var minimum:=actor.global_position.y;var maximum:=minimum;var ticks:=0
	for index in range(1,points.size()):
		var goal:=floor_vector(points[index])+Vector3(0,.87,0)
		while Vector2(actor.global_position.x-goal.x,actor.global_position.z-goal.z).length()>.3:
			var direction:=goal-actor.global_position
			actor.rotation.y=atan2(-direction.x,-direction.z)
			var event:=InputEventKey.new();event.physical_keycode=KEY_W;event.keycode=KEY_W;event.pressed=true;Input.parse_input_event(event)
			await physics_frame;ticks+=1
			minimum=minf(minimum,actor.global_position.y);maximum=maxf(maximum,actor.global_position.y)
			if ticks>1800:check(false,label+": physical staircase route stalled "+str(actor.global_position));break
		var stop:=InputEventKey.new();stop.physical_keycode=KEY_W;stop.keycode=KEY_W;stop.pressed=false;Input.parse_input_event(stop)
		if ticks>1800:break
	actor.set_physics_process(false)
	return {"route":label,"ticks":ticks,"minimum_y":minimum,"maximum_y":maximum,"measured_rise":maximum-minimum}
func run() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/expansion-v1/contract.json"))
	for stage in catalog.stages:
		var world: Node3D = load(stage.scene).instantiate();root.add_child(world)
		var actor: CharacterBody3D = world.get_node("Player");actor.set_physics_process(false)
		var controller: Node3D = load("res://scripts/combat.gd").new();world.add_child(controller);controller.setup(world,actor);world.setup(controller,actor)
		for enemy in controller.enemies: enemy.set_physics_process(false)
		var route: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/stages/"+stage.id+"-route.json"))
		check(world.rooms.size()==19 and controller.enemies.size()==42,stage.id+": core rooms/roster changed")
		check(world.traps.size()==3,stage.id+": missing pickup ambush state")
		check(route.vertical_routes.size()>=4 and route.combat_paths.size()==3,stage.id+": usable elevation routes missing")
		await physics_frame
		for arena in ["arena_one","arena_two","final_arena"]:
			var entry: Node3D = world.trap_entries[arena]
			var threshold: Vector3 = entry.get_meta("entry_threshold")
			var normal: Vector3 = entry.get_meta("entry_normal")
			actor.global_position=threshold+normal*2.5+Vector3(0,.87,0);world.update_player(actor,controller)
			check(not world.traps[arena].triggered and not world.is_arena_active(arena),stage.id+": arena activated on entrance "+arena)
			check(entry.is_open(),stage.id+": lure approach bulkhead starts closed "+arena)
			for enemy in controller.enemies:
				if String(enemy.get_meta("arena_id",""))!=arena:continue
				check(not enemy.awake,stage.id+": dormant arena actor woke early")
				var front: Vector3=enemy.global_position;front.x += -signf(enemy.global_position.x)*5.0
				var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(front,enemy.global_position,1))
				check(not hit.is_empty(),stage.id+": unsealed enemy closet exposes pretrigger actor")
			var bait: Node3D=world.get_node("Bait_"+arena)
			world.collect(bait);world.update_player(actor,controller)
			check(world.traps[arena].triggered and not entry.sealing,stage.id+": closure ignored threshold safety")
			var weapon:=StringName(bait.get_meta("stage_pickup"))
			check(controller.has_weapon(weapon),stage.id+": physical cache failed weapon ownership")
			actor.global_position=threshold+normal*4.5+Vector3(0,.87,0)
			for frame in 125:await physics_frame
			world.update_player(actor,controller)
			check(entry.is_closed() and world.traps[arena].latched,stage.id+": safe retreat bulkhead failed to seal")
			check(world.traps[arena].shutters_open and world.is_arena_active(arena),stage.id+": opened closets did not activate roster")
			for enemy in controller.enemies:
				if String(enemy.get_meta("arena_id",""))==arena:world.notify_enemy_death(String(enemy.target_id),arena)
			check(world.traps[arena].cleared and not world.traps[arena].latched,stage.id+": arena clear failed retreat release")
			check(world.flags.get("clear_"+arena,false) and not world.flags.get("breaker",false),stage.id+": combat clear bypassed manual control")
			for frame in 125:await physics_frame
			check(entry.is_open(),stage.id+": cleared retreat remains blocked")
		# The same collider triangles support all authored staircase/upper route samples.
		for key in route.vertical_routes:
			for point in route.vertical_routes[key]:
				var location:=floor_vector(point)
				var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(location+Vector3(0,.5,0),location-Vector3(0,.5,0),1))
				check(not hit.is_empty() and hit.normal.y>.95,stage.id+": upper route has unsupported floor "+key+" "+str(location))
		var height_evidence: Array[Dictionary] = []
		for key in route.vertical_routes:
			var evidence: Dictionary = await walk_height_route(actor,route.vertical_routes[key],stage.id+":"+key)
			height_evidence.append(evidence)
			var lowest:=INF;var highest:=-INF
			for point in route.vertical_routes[key]:lowest=minf(lowest,float(point[1]));highest=maxf(highest,float(point[1]))
			check(float(evidence.measured_rise)>highest-lowest-.15,stage.id+": upper combat route did not physically change elevation "+key)
		controller.reset();world.reset()
		for enemy in controller.enemies:enemy.set_physics_process(false)
		check(not controller.has_weapon(&"twin_shotgun") and controller.ammo_rivets==0 and controller.ammo_rockets==0,stage.id+": retry retained arsenal")
		for arena in world.traps:
			check(not world.traps[arena].triggered and not world.traps[arena].cleared and world.trap_entries[arena].is_open(),stage.id+": retry retained trap state")
			for shutter in world.trap_shutters[arena]:check(shutter.is_closed(),stage.id+": retry left closet open")
		# All pre-killed is a legal edge state: collecting bait cannot reseal retreat.
		for enemy in controller.enemies:
			if String(enemy.get_meta("arena_id",""))=="arena_one":world.notify_enemy_death(String(enemy.target_id),"arena_one")
		world.collect(world.get_node("Bait_arena_one"))
		check(world.traps.arena_one.cleared and world.trap_entries.arena_one.opened,stage.id+": pre-killed arena can softlock retreat")
		records.append({"id":stage.id,"rooms":world.rooms.size(),"enemies":controller.total_enemies,"traps":3,"vertical_routes":route.vertical_routes.size(),"combat_paths":route.combat_paths.size(),"physical_height_routes":height_evidence})
		world.queue_free();await process_frame
	var report:={"failures":failures,"stages":records,"scope":"Pickup trap state, opaque physical closets, safe threshold closure, remaining-zero retreat/manual control, retry and pre-killed safety, shared polygon geometry and supported upper routes; separate full route proves ordinary input movement."}
	var output:=FileAccess.open("res://resources/stages/ambush-v2-check.json",FileAccess.WRITE);output.store_string(JSON.stringify(report,"  "))
	print("AMBUSH_V2_CHECK ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
