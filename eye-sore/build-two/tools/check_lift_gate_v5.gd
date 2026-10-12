extends SceneTree
class Probe:
	extends Node3D
	var actor:CharacterBody3D
	var dead:=false
	var enemies:Array=[]
	var explosions:Array[Dictionary]=[]
	func anatomical_exclusions()->Array[RID]:return [actor.get_rid()]
	func ray(start:Vector3,end:Vector3,excluded:Array[RID],_anatomical:bool=false)->Dictionary:
		return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start,end,15,excluded))
	func material_for(body:Object)->StringName:return StringName(body.get_meta("hit_material","hard")) if is_instance_valid(body) else &"hard"
	func resolve_ordnance_explosion(_definition:Resource,at:Vector3,body:Object,material:StringName,id:int)->void:
		explosions.append({"shot_id":id,"material":str(material),"at":at,"body":str(body.name) if is_instance_valid(body) else "NONE"})
class Departure:
	extends Node
	var lift:Node
	var attempted:=false
	var accepted:=false
	func _physics_process(_delta:float)->void:
		if not attempted:attempted=true;accepted=lift.activate();set_physics_process(false)
var world:Node3D
var player:CharacterBody3D
var lift:Node3D
var lower:Node3D
var upper:Node3D
var probe:Probe
var failures:Array[String]=[]
var records:Array[Dictionary]=[]
func _initialize()->void:call_deferred("run")
func check(value:bool,label:String)->void:
	if not value:failures.append(label);push_error(label)
func press(held:bool,direction:Vector3=Vector3.ZERO)->void:
	var event:=InputEventKey.new();event.physical_keycode=KEY_W;event.pressed=held;Input.parse_input_event(event)
	if held:player.rotation.y=atan2(-direction.x,-direction.z)
func pose(point:Vector3)->void:
	press(false);player.velocity=Vector3.ZERO;player.position=point
	for _tick in 10:await physics_frame
func normal(gate:Node3D)->Vector3:
	var outward:Vector3=gate.global_position-lift.global_position;outward.y=0
	return outward.normalized()
func point(gate:Node3D,distance:float)->Vector3:
	var result:Vector3=gate.global_position+normal(gate)*distance
	result.y=float(gate.get_meta("landing_height"))+.85
	return result
func gate_overlap(gate:Node3D)->bool:
	var shape:CollisionShape3D=gate.get_node("Collision")
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape.shape;query.transform=shape.global_transform;query.collision_mask=2;query.margin=.001
	for hit in world.get_world_3d().direct_space_state.intersect_shape(query):
		if hit.collider==player:return true
	return false
func gate_penetration(gate:Node3D)->float:
	var collider:CollisionShape3D=gate.get_node("Collision")
	var outward:Vector3=normal(gate)
	var half:float=absf(outward.dot(collider.global_basis.x))*collider.shape.size.x*.5+absf(outward.dot(collider.global_basis.z))*collider.shape.size.z*.5
	var radius:float=player.get_node("CollisionShape3D").shape.radius
	return half+radius-absf((player.global_position-collider.global_position).dot(outward))
func wait_lift()->void:
	var ticks:=0
	while lift.moving and ticks<500:await physics_frame;ticks+=1
	for _tick in 3:await physics_frame
	check(not lift.moving,"Actual lift reaches a dock")
func walk(target:Vector3,label:String)->void:
	var ticks:=0;var min_y:float=player.position.y
	while Vector2(player.position.x-target.x,player.position.z-target.z).length()>.2 and ticks<160:
		var toward:Vector3=target-player.position;toward.y=0;press(true,toward);await physics_frame;ticks+=1;min_y=minf(min_y,player.position.y)
		if player.position.y<-.6:break
	press(false)
	for _tick in 8:await physics_frame
	records.append({"test":label,"ticks":ticks,"end":player.position,"minimum_y":min_y,"grounded":player.is_on_floor()})
	check(ticks<160 and player.position.y>-.6,label)
func physics_value(value:Variant)->Variant:
	if typeof(value) in [TYPE_NIL,TYPE_BOOL,TYPE_INT,TYPE_STRING]:return value
	if typeof(value) in [TYPE_STRING_NAME,TYPE_NODE_PATH]:return str(value)
	return {"type":typeof(value),"native_bytes":var_to_bytes(value).hex_encode()}
func freeze(node:Node)->void:
	node.set_physics_process(false);node.set_process(false)
	for child in node.get_children():freeze(child)
func physics_tree(node:Node,path:String,data:Dictionary)->void:
	if node is PhysicsBody3D or node is CollisionShape3D:
		var entry:Dictionary={"class":node.get_class(),"transform":physics_value(node.global_transform)}
		if node is PhysicsBody3D:
			entry.properties={};entry.metadata={}
			for prop in node.get_property_list():
				if not (int(prop.usage)&PROPERTY_USAGE_STORAGE) or String(prop.name) in ["script","name","owner","scene_file_path","unique_name_in_owner"]:continue
				var value:Variant=node.get(prop.name)
				if not value is Object:entry.properties[String(prop.name)]=physics_value(value)
			for key in node.get_meta_list():
				var value:Variant=node.get_meta(key)
				if not value is Resource:entry.metadata[str(key)]=physics_value(value)
		else:
			entry.disabled=node.disabled;entry.shape_class=node.shape.get_class();entry.shape_properties={}
			for prop in node.shape.get_property_list():
				if not (int(prop.usage)&PROPERTY_USAGE_STORAGE) or String(prop.name) in ["resource_path","resource_name","resource_scene_unique_id","script"]:continue
				entry.shape_properties[String(prop.name)]=physics_value(node.shape.get(prop.name))
		data[path]=entry
	for index in node.get_child_count():
		var child:Node=node.get_child(index);var name:=String(child.name)
		if name.begins_with("@"):name="auto_%s_%d" % [child.get_class(),index]
		physics_tree(child,path+"/"+name,data)
func native_signature(path:String)->Dictionary:
	var scene:Node3D=load(path).instantiate();root.add_child(scene);scene.scan(scene);freeze(scene)
	for _tick in 3:await physics_frame
	var data:Dictionary={};physics_tree(scene,"world",data)
	scene.free();await process_frame
	return {"scene_sha256":FileAccess.get_sha256(path),"native_physics_nodes":data.size(),"physics_sha256":JSON.stringify(data).sha256_text(),"data":data}
func run()->void:
	Engine.physics_ticks_per_second=60
	if "--physics-signature-only" in OS.get_cmdline_user_args():
		var scene_path:="res://scenes/campaign/pale_ward_01.tscn";var baseline_path:="";var receipt:="gate-physics-parity"
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--scene="):scene_path=argument.trim_prefix("--scene=")
			if argument.begins_with("--baseline="):baseline_path=argument.trim_prefix("--baseline=")
			if argument.begins_with("--receipt="):receipt=argument.trim_prefix("--receipt=")
		var current:Dictionary=await native_signature(scene_path)
		var baseline:Dictionary=await native_signature(baseline_path) if not baseline_path.is_empty() else {}
		var differences:Array[String]=[]
		if not baseline.is_empty():
			var keys:Array=baseline.data.keys()
			for key in current.data:if not keys.has(key):keys.append(key)
			for key in keys:
				if baseline.data.get(key)!=current.data.get(key):differences.append(key)
		current.erase("data");baseline.erase("data")
		var report:={"scene":scene_path,"baseline_path":baseline_path,"current":current,"baseline":baseline,"differences":differences,"physics_equal":null if baseline.is_empty() else differences.is_empty(),"comparison_performed":not baseline.is_empty(),"scope":"Native loaded physics bodies and shapes including generated polygons, exact binary math/packed-array values, initial docking collider state, body metadata and serialized parameters; source resource IDs excluded. Cosmetic noncollision nodes excluded."}
		var out:=FileAccess.open("res://verification/map-safety-v5/"+receipt+".json",FileAccess.WRITE);out.store_string(JSON.stringify(report,"  "));out.close()
		print("LIFT_NATIVE_PHYSICS_PARITY ",scene_path," differences=",differences.size());quit(0 if differences.is_empty() else 1);return
	var scene_path:="res://scenes/campaign/pale_ward_01.tscn"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--scene="):scene_path=argument.trim_prefix("--scene=")
	world=load(scene_path).instantiate();root.add_child(world);world.scan(world);world.set_physics_process(false)
	player=world.get_node("Player");lift=world.get_node("Lift_Observation")
	var fresh_player_position:Vector3=player.position
	if lift.landing_gates.size()!=2:printerr("LIFT_GATE_V5_WAITING_AUTHORED_SCENE");world.free();quit(2);return
	probe=Probe.new();probe.actor=player;world.add_child(probe);world.player=player;world.combat=probe;world.flags["clear_final_arena"]=true
	for gate in lift.landing_gates:
		if float(gate.get_meta("landing_height"))<float(lift.origin.y+lift.lift_offset.y):lower=gate
		else:upper=gate
	# Classification is based on lower deck height, not scene resource identifiers.
	var ordered:Array=lift.landing_gates.duplicate();ordered.sort_custom(func(a,b):return float(a.get_meta("landing_height"))<float(b.get_meta("landing_height")))
	lower=ordered[0];upper=ordered[1]
	for _tick in 3:await physics_frame
	check(lower.opened and lower.get_node("Collision").disabled,"Lower dock gate opens physically")
	check(not upper.opened and not upper.get_node("Collision").disabled,"Absent upper deck remains physically guarded")
	await pose(point(upper,1.0))
	var shot_at:Vector3=point(upper,0);shot_at.y=float(upper.get_meta("landing_height"))+1
	var hit:Dictionary=probe.ray(shot_at+normal(upper),shot_at-normal(upper),[player.get_rid()])
	check(not hit.is_empty() and hit.collider==upper,"Closed visible landing gate blocks actual world hitscan")
	var projectile:Node3D=load("res://scenes/player_ordnance.tscn").instantiate();world.add_child(projectile);projectile.global_position=shot_at+normal(upper)
	projectile.setup(probe,load("res://resources/weapons/siege_launcher.tres"),-normal(upper),901)
	for _tick in 12:await physics_frame
	check(probe.explosions.size()==1 and probe.explosions[0].body==str(upper.name),"Real swept ordnance stops once on the same closed gate")
	press(true,-normal(upper))
	for _tick in 30:await physics_frame
	press(false)
	for _tick in 8:await physics_frame
	var closed_contact:bool=gate_overlap(upper)
	var closed_penetration:float=gate_penetration(upper)
	var outside:float=(player.global_position-upper.global_position).dot(normal(upper))
	check(closed_penetration<=.003 and outside>0 and player.is_on_floor(),"Closed landing gate physically blocks actual capsule without losing support")
	records.append({"test":"closed upper gate actor/hitscan/projectile","raw_contact":closed_contact,"geometric_penetration":closed_penetration,"grounded":player.is_on_floor(),"outside_side":outside,"actor":player.position,"hit_body":str(hit.get("collider").name) if not hit.is_empty() else "NONE","projectile":probe.explosions.duplicate()})
	await pose(point(upper,1.0))
	check(world.nearest_mechanism()==lift,"Outside closed upper guard can reach the fixed call anchor")
	check(world.try_use(player),"Actual stage use calls lift from outside closed upper guard")
	await physics_frame;await physics_frame
	check(not lower.opened and not upper.opened and not lower.get_node("Collision").disabled and not upper.get_node("Collision").disabled,"Both physical gates close while actual lift travels")
	await wait_lift()
	check(upper.opened and upper.get_node("Collision").disabled and not lower.opened,"Arrival opens only the actual docked landing")
	var deck:Vector3=lift.global_position;deck.y=float(upper.get_meta("landing_height"))+.85
	await walk(deck,"Actual W passage through docked upper guard onto deck")
	await walk(point(upper,-.35),"Actual W approach to upper opening straddle")
	check(not upper.entrance_clear(),"Straddling actor is detected by actual guard query volume")
	var refused:bool=not world.try_use(player)
	check(refused and not lift.moving and upper.opened and upper.get_node("Collision").disabled,"Straddle refuses departure without enabling a collider through the actor")
	records.append({"test":"straddle refusal","position":player.position,"refused":refused,"moving":lift.moving,"gate_open":upper.opened})
	await walk(deck,"Clear the entrance onto the actual upper deck")
	check(world.try_use(player),"Clear deck passenger can depart through actual stage use")
	await wait_lift()
	# Upper landing remains closed when deck is absent. Call from shaft base is queried separately.
	var base:Vector3=lift.get_parent().to_global(lift.origin);base.y=float(lower.get_meta("landing_height"))+.85
	await pose(point(lower,1.0))
	check(lift.activate(),"Fixture sends lift to upper dock for shaft-base call")
	await wait_lift()
	await pose(base)
	check(world.nearest_mechanism()==lift,"Inside below-deck shaft-base call anchor remains reachable")
	records.append({"test":"inside below-deck call visibility","position":player.position,"selected_lift":world.nearest_mechanism()==lift,"grounded":player.is_on_floor()})
	check(world.try_use(player),"Inside shaft-base stage call starts controlled descent")
	var obstruction_ticks:=0
	while not lift.obstructed and lift.moving and obstruction_ticks<300:await physics_frame;obstruction_ticks+=1
	for _tick in 3:await physics_frame
	check(lift.obstructed and lower.opened and lower.get_node("Collision").disabled,"Descending deck stops above the body and opens emergency lower egress")
	var stopped_height:float=lift.position.y
	for _tick in 10:await physics_frame
	check(absf(lift.position.y-stopped_height)<.002 and player.is_on_floor(),"Obstructed deck stays stationary over supported lower body")
	records.append({"test":"under-deck obstruction/emergency egress","stopped_height":stopped_height,"body_position":player.position,"lower_guard_open":lower.opened,"obstructed":lift.obstructed})
	await walk(point(lower,1.0),"Actual W emergency egress up authored low tread")
	await wait_lift()
	check(lower.opened and lower.get_node("Collision").disabled and not lift.obstructed,"After egress descent completes and reopens only the docked lower guard")
	await pose(point(upper,1.0));world.try_use(player);await wait_lift()
	# A supported independent timing trial tests a real E-like activation before the player physics tick.
	await pose(point(upper,1.0))
	var collision:CollisionShape3D=upper.get_node("Collision");var direction:Vector3=normal(upper)
	var half_thickness:float=absf(direction.dot(upper.global_basis.x))*collision.shape.size.x*.5+absf(direction.dot(upper.global_basis.z))*collision.shape.size.z*.5
	await pose(point(upper,half_thickness+.3+(.10+8.0/Engine.physics_ticks_per_second)+.015))
	player.velocity=-direction*8;press(true,-direction)
	var departure:=Departure.new();departure.lift=lift;departure.process_physics_priority=-100;root.add_child(departure)
	var unsafe:=false
	var close_timeline:Array[Dictionary]=[]
	for _tick in 3:
		await physics_frame
		var enabled:bool=not upper.get_node("Collision").disabled
		var overlap:bool=gate_overlap(upper)
		var penetration:float=gate_penetration(upper)
		close_timeline.append({"tick":_tick,"enabled":enabled,"query_overlap":overlap,"geometric_penetration":penetration,"actor":player.position})
		if enabled and overlap and penetration>.003:unsafe=true
	var departed:bool=departure.accepted
	press(false);departure.free()
	records.append({"test":"before-player departure race","accepted":departed,"unsafe_enabled_overlap":unsafe,"timeline":close_timeline,"actor":player.position})
	check(not unsafe,"Departure never enables its gate through a same-tick moving actor")
	await wait_lift()
	# Main supports fresh-world restart, not arbitrary live straddle reset.
	await pose(fresh_player_position)
	lift.reset_lift();await physics_frame;await physics_frame
	check(lower.opened and lower.get_node("Collision").disabled and not upper.opened and not upper.get_node("Collision").disabled,"Fresh-start reset restores only lower docking with no actor/gate overlap")
	check(not gate_overlap(lower) and not gate_overlap(upper),"Fresh-start reset does not enclose an actor")
	records.append({"test":"supported fresh-start reset","lower_open":lower.opened,"upper_open":upper.opened,"arbitrary_live_straddle_reset":"Not an ordinary Main contract; not exercised."})
	var filename:="gate-before-fix"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--receipt="):filename=arg.trim_prefix("--receipt=")
	var output:=FileAccess.open("res://verification/map-safety-v5/"+filename+".json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"scene":scene_path,"scene_sha256":FileAccess.get_sha256(scene_path),"gate_script_sha256":FileAccess.get_sha256("res://scripts/lift_landing_gate.gd"),"lift_script_sha256":FileAccess.get_sha256("res://scripts/ward_lift.gd"),"failures":failures,"records":records,"scope":"Isolated authored gate physics; actual CharacterBody input, stage use call anchors, native hitscan and original swept ordnance. AI absent and clear_final_arena flag explicitly granted. Supported trial starting poses are fixture setup, not campaign progression or recovery proof."},"  "));output.close()
	press(false);world.free();world=null;player=null;probe=null;lift=null;lower=null;upper=null;await process_frame
	print("LIFT_GATE_V5_DONE failures=",failures.size());quit(0 if failures.is_empty() else 1)
