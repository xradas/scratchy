extends SceneTree
var evidence_dir := "res://verification/combat"
const LevelScript = preload("res://scripts/pale_ward_level.gd")
const DoorScript = preload("res://scripts/ward_door.gd")
const LiftScript = preload("res://scripts/ward_lift.gd")
var world:Node3D
var player:CharacterBody3D
var level:Node3D
var combat:Node3D
var records:Array[Dictionary]=[]
var failures:Array[String]=[]
func prepare_evidence_dir() -> bool:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-dir="):
			evidence_dir = argument.trim_prefix("--evidence-dir=")
	if evidence_dir.is_empty():
		push_error("Evidence directory cannot be empty")
		quit(1)
		return false
	var error := DirAccess.make_dir_recursive_absolute(evidence_dir)
	if error != OK:
		push_error("Cannot create evidence directory %s: %s" % [evidence_dir, error_string(error)])
		quit(1)
		return false
	return true

func write_evidence(filename: String, contents: String) -> bool:
	var path := evidence_dir.path_join(filename)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot open evidence file %s: %s" % [path, error_string(FileAccess.get_open_error())])
		quit(1)
		return false
	file.store_string(contents)
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		push_error("Cannot write evidence file %s: %s" % [path, error_string(error)])
		quit(1)
		return false
	return true

func _initialize()->void:
	if not prepare_evidence_dir(): return
	call_deferred("run_check")
func check(value:bool,label:String)->void:
	if not value: failures.append(label);push_error(label)
func key(pressed:bool)->void:
	var event:=InputEventKey.new();event.physical_keycode=KEY_W;event.pressed=pressed;Input.parse_input_event(event)
func walk(point:Vector3,label:String)->void:
	var ticks:=0;var airborne:=0;var lowest:=player.position.y
	while Vector2(player.position.x-point.x,player.position.z-point.z).length()>.32 and ticks<600:
		var direction:=point-player.global_position;direction.y=0
		player.rotation.y=atan2(-direction.x,-direction.z);key(true)
		await physics_frame
		if not player.is_on_floor():airborne+=1
		lowest=minf(lowest,player.position.y);ticks+=1
	key(false)
	for _tick in 15:await physics_frame
	print("ROUTE_SEGMENT ",label," end=",player.position," ticks=",ticks," airborne=",airborne)
	check(ticks<600,"Route stalled: "+label)
	if ticks>=600:
		var direction:Vector3=point-player.global_position;direction.y=0
		var motion:=direction.normalized()*(.7/60)
		var elevated:=player.global_transform
		var up_blocked:=player.test_move(elevated,Vector3.UP*.18)
		elevated.origin.y+=.18
		var horizontal_blocked:=player.test_move(elevated,motion)
		elevated.origin+=motion
		var landing:=KinematicCollision3D.new()
		var landing_hit:=player.test_move(elevated,Vector3.DOWN*.2,landing)
		print("STEP_DIAGNOSTIC floor=",player.is_on_floor()," motion=",motion," up_blocked=",up_blocked," raised_horizontal_blocked=",horizontal_blocked," landing_hit=",landing_hit," landing_normal=",landing.get_normal() if landing_hit else Vector3.ZERO," landing_travel=",landing.get_travel() if landing_hit else Vector3.ZERO)
		var far:=player.global_transform;far.origin.y+=.18;far.origin+=direction.normalized()*(8.0/60)
		var farther:=KinematicCollision3D.new();var far_hit:=player.test_move(far,Vector3.DOWN*.2,farther)
		print("STEP_FAST_PROBE hit=",far_hit," normal=",farther.get_normal() if far_hit else Vector3.ZERO," travel=",farther.get_travel() if far_hit else Vector3.ZERO)
		key(false);quit(1);return
	check(player.position.y>-.1,"Route fell through geometry: "+label)
	records.append({"segment":label,"physics_ticks":ticks,"airborne_ticks":airborne,"lowest_center_y":lowest,"end":player.position})
func ride(lift:Node3D,label:String)->void:
	var ticks:=0;var airborne:=0;var max_gap:=0.0
	while lift.moving and ticks<400:
		await physics_frame;ticks+=1
		if not player.is_on_floor():airborne+=1
		var visual:MeshInstance3D=lift.get_node("Visual")
		var top:Vector3=visual.to_global(Vector3(0,visual.mesh.get_aabb().end.y,0))
		max_gap=maxf(max_gap,absf(player.global_position.y-.85-top.y))
	check(not lift.moving and max_gap<.09,"Grounded physical lift ride: "+label)
	records.append({"segment":"lift "+label+" continuous ride","physics_ticks":ticks,"airborne_flags":airborne,"maximum_foot_platform_gap":max_gap})
func world_ray(start:Vector3,end:Vector3)->Dictionary:
	return player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start,end,1,[player.get_rid()]))
func run_check()->void:
	var packed:PackedScene=load("res://scenes/pale_ward.tscn")
	if packed==null:quit(1);return
	world=packed.instantiate();root.add_child(world)
	player=world.get_node_or_null("Player")
	if player==null:
		check(false,"Scene needs Player for test")
		quit(1);return
	combat=load("res://scripts/combat.gd").new();world.add_child(combat);combat.setup(world,player);combat.set_physics_process(false)
	var starting_pistol:int=combat.ammo_pistol;var starting_shells:int=combat.ammo_shotgun
	for actor in combat.enemies:actor.set_physics_process(false);actor.collision_layer=0;actor.position.x=100
	level=world if world.get_script()==LevelScript else LevelScript.new()
	if level!=world:world.add_child(level)
	level.setup(combat,player)
	for _tick in 10:await physics_frame
	var stairs:Node3D=world.get_node("MainRamp")
	check(stairs.get_child_count()==12,"Exactly twelve authored physical stair treads")
	var step_tops:Array[float]=[]
	for step in stairs.get_children():
		check(step.has_meta("ward_step"),"Every stair tread carries audit metadata")
		var mesh:BoxMesh=step.get_node("Visual").mesh
		var shape:BoxShape3D=step.get_node("Collision").shape
		check(mesh.size.is_equal_approx(shape.size),"Step visible mesh and physics size agree")
		check(is_equal_approx(mesh.size.x,6) and is_equal_approx(mesh.size.z,.5),"Broad six-metre stairs with half-metre treads")
		var top:Vector3=step.to_global(Vector3(0,mesh.size.y*.5,0))
		var hit:Dictionary=world_ray(top+Vector3.UP*.5,top-Vector3.UP*.5)
		check(not hit.is_empty() and absf(hit.position.y-top.y)<.002,"Each rendered stair top has matching physical contact")
		step_tops.append(top.y)
	for index in 12:check(absf(step_tops[index]-(index+1)*.125)<.002,"Stair rise is twelve physical eighth-metre risers")
	records.append({"geometry":"stairs","count":12,"tops":step_tops,"visual_collision_match":true})
	var rear:Node3D=world.get_node("Door_Rear")
	check(not rear.activate(false),"Rear door must reject missing key")
	check(not rear.opened,"Rejected lock must stay colliding closed")
	combat.health=40;combat.armor=20;combat.ammo_pistol=1;combat.ammo_shotgun=1
	for kind in ["health","armor","pistol","shells"]:
		for item in level.pickups:
			if String(item.get_meta("ward_pickup"))==kind:level.collect(item);break
	check(combat.health>40 and combat.armor>20 and combat.ammo_pistol>1 and combat.ammo_shotgun>1,"All pickup effects apply")
	await walk(Vector3(0,1.5,-14),"inspect locked raised gate")
	var door_ray:Dictionary=world_ray(Vector3(0,2.35,-14),Vector3(0,2.35,-18))
	check(not door_ray.is_empty() and door_ray.collider==rear,"Closed shared rear door blocks world rays")
	player.rotation.y=0;key(true)
	for _tick in 30:await physics_frame
	key(false)
	check(player.position.z>=-15.55 and player.is_on_floor(),"Actual capsule cannot traverse closed rear door")
	check(not level.interact(),"E rejects keyless rear gate")
	check(not rear.opened,"E rejection preserves shared collision")
	await walk(Vector3(0,0,5.5),"descend raised entrance to hall")
	await walk(Vector3(-4.4,0,8),"optional service alcove control")
	check(level.interact(),"E opens optional secret")
	var secret:Node3D=world.get_node("Door_Secret")
	var secret_ticks:=0
	while not secret.is_open() and secret_ticks<300:await physics_frame;secret_ticks+=1
	check(secret.is_open(),"Optional secret door finished opening")
	if not secret.is_open():quit(1);return
	await walk(Vector3(-8.3,0,8),"optional service alcove supplies")
	check(level.secret_found and level.visited.has("Secret"),"Secret flag and automap discovered")
	await walk(Vector3(0,0,5.5),"return from optional service alcove")
	await walk(Vector3(10,0,5.5),"east doorway")
	await walk(Vector3(19,0,5.5),"bio wing")
	await walk(Vector3(18,0,2),"operating doorway approach")
	await walk(Vector3(18,0,-2),"operating doorway centre")
	await walk(Vector3(20,0,-6.1),"operating room key")
	check(level.has_key,"Key collected by physical approach")
	var closed_graph:Vector3=level.get_chase_target(player.global_position,Vector3(0,.85,10))
	check(closed_graph.x>16 and closed_graph.x<19 and closed_graph.z>0 and closed_graph.z<2,"Closed shortcut chase graph routes through Operating/Bio portal")
	records.append({"navigation":"closed shortcut","target":closed_graph})
	await walk(Vector3(19,0,-3),"return to shortcut")
	await walk(Vector3(12,0,-2.5),"shortcut control approach")
	var shortcut:Node3D=world.get_node("Door_Shortcut");check(level.interact(),"E opens shortcut")
	check(level.shortcut_open,"Shortcut discovery flag")
	var shortcut_ticks:=0
	while not shortcut.is_open() and shortcut_ticks<300:await physics_frame;shortcut_ticks+=1
	check(shortcut.is_open(),"Shortcut door finished opening")
	if not shortcut.is_open():quit(1);return
	await walk(Vector3(0,0,-3),"shortcut return")
	await walk(Vector3(0,1.5,-14),"central raised stairs")
	check(level.interact(),"E opens keyed rear door")
	await physics_frame;await physics_frame
	var moving_hit:Dictionary=world_ray(Vector3(0,2.35,-14),Vector3(0,2.35,-18))
	check(not moving_hit.is_empty() and moving_hit.collider==rear,"Opening shared door still blocks before clearance")
	var door_ticks:=0
	while not rear.is_open() and door_ticks<300:await physics_frame;door_ticks+=1
	check(rear.is_open(),"Keyed rear door finished opening")
	if not rear.is_open():quit(1);return
	check(world_ray(Vector3(0,2.35,-14),Vector3(0,2.35,-18)).is_empty(),"Opened doorway ray has physical clearance")
	await walk(Vector3(0,1.5,-20),"unlocked rear doorway")
	await walk(Vector3(-4.5,1.5,-26.5),"lift boarding")
	var lift:Node3D=world.get_node("Lift_Exit");var before:=player.global_position.y
	check(lift.activate(),"Lift starts")
	await ride(lift,"ascent")
	for _tick in 15:await physics_frame
	check(absf(player.global_position.y-before-3)<.12,"Actual grounded passenger rides lift3m")
	var platform_hit:Dictionary=world_ray(lift.global_position+Vector3(0,1,0),lift.global_position-Vector3(0,1,0))
	var visual:MeshInstance3D=lift.get_node("Visual")
	var rendered_top:Vector3=visual.to_global(Vector3(0,visual.mesh.get_aabb().end.y,0))
	check(not platform_hit.is_empty() and platform_hit.collider==lift and absf(platform_hit.position.y-rendered_top.y)<.002,"Lift visible and physical platform top agree")
	check(level.visited.has("BioWing") and level.visited.has("OperatingRoom") and level.get_level_state().map_rooms.size()>=4,"Visited-room automap reveals traversed route")
	records.append({"segment":"lift ascent","rise":player.global_position.y-before,"grounded":player.is_on_floor()})
	check(lift.activate(),"Lift descent starts")
	await ride(lift,"descent")
	for _tick in 15:await physics_frame
	check(absf(player.global_position.y-before)<.12 and player.is_on_floor(),"Actual passenger stays grounded during lift descent")
	records.append({"segment":"lift descent","end_y":player.global_position.y,"grounded":player.is_on_floor()})
	check(lift.activate(),"Lift returns to gallery")
	await ride(lift,"return ascent")
	for _tick in 15:await physics_frame
	var destination:Vector3=level.exit_marker.global_position
	await walk(destination,"upper gallery exit")
	check(level.interact(),"Exit interaction completes")
	check(level.finished,"Exit completion state")
	records.append({"completed":level.finished,"visited_rooms":level.visited.keys(),"map_room_count":level.get_level_state().map_rooms.size(),"secret_found":level.secret_found,"shortcut_open":level.shortcut_open})
	level.reset()
	check(not level.has_key and not level.finished and level.collected.is_empty(),"Reset clears key/completion/pickups")
	for item in level.pickups:check(item.visible,"Reset restores pickup visual")
	check(not rear.opened and not shortcut.opened and not lift.upper,"Reset restores mechanisms")
	var supplies:Dictionary={"enemy_total_hp":0.0,"pistol_rounds":starting_pistol,"shells":starting_shells}
	for marker in world.get_node("EnemySpawns").get_children():
		var definition:Resource=load("res://resources/enemies/%s.tres" % marker.get_meta("kind"))
		supplies.enemy_total_hp+=definition.health
	for item in level.pickups:
		if String(item.name).contains("Secret"):continue
		var kind:String=item.get_meta("ward_pickup")
		if kind=="pistol":supplies.pistol_rounds+=int(item.get_meta("amount"))
		if kind=="shells":supplies.shells+=int(item.get_meta("amount"))
	var pistol:Resource=load("res://resources/weapons/pistol.tres")
	var shotgun:Resource=load("res://resources/weapons/shotgun.tres")
	supplies.pistol_damage_capacity=supplies.pistol_rounds*pistol.damage
	supplies.shotgun_damage_capacity=supplies.shells*shotgun.damage*shotgun.pellets
	supplies.accuracy_assumption="Upper bound assumes all shots/pellets hit; not a combat completion bot or survival proof. Melee and optional secret supplies excluded."
	check(supplies.pistol_damage_capacity+supplies.shotgun_damage_capacity>supplies.enemy_total_hp,"Mandatory supplied damage capacity exceeds authored enemy HP")
	if not write_evidence("pale-ward-route.json", JSON.stringify({"records":records,"failures":failures,"fixed_physics":60,"scene_sha256":FileAccess.get_sha256("res://scenes/pale_ward.tscn"),"movement_sha256":FileAccess.get_sha256("res://scripts/grounded_step.gd"),"supplies":supplies,"scope":"Authored route/no-jump real CharacterBody traversal; enemies disabled for fixture; pickup effects, key gate, lift, exit, reset."},"  ")): return
	print("PALE_WARD_ROUTE_OK" if failures.is_empty() else "PALE_WARD_ROUTE_FAILED")
	key(false);world.free();world=null;player=null;level=null;combat=null
	await process_frame;quit(0 if failures.is_empty() else 1)
