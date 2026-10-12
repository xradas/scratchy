extends SceneTree
## Independent actual Main movement audit. Initial probe positions, frozen enemy
## AI and declared access flags isolate map collision. No falls are recovered.
const DIR := "res://verification/map-safety-v5/"
var app: Control
var errors: Array[String]=[]
var records: Array[Dictionary]=[]
var hazards: Array[Dictionary]=[]
var level_id:=""
var route: Dictionary
var lower_floor:=0.0
var report_name:="lift-edges-baseline"
var postfix:=false
var include_standalone:=false

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--receipt="):report_name=arg.trim_prefix("--receipt=")
		elif arg=="--postfix":postfix=true
		elif arg=="--include-standalone":include_standalone=true
	if postfix and report_name=="lift-edges-baseline":report_name="lift-edges-postfix"
	call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:errors.append(level_id+": "+message);push_error("LIFT_EDGE_FIXTURE: "+level_id+": "+message)
func xyz(v: Vector3) -> Array:return [v.x,v.y,v.z]
func vector(v: Array) -> Vector3:return Vector3(v[0],v[1],v[2])
func key(code: int,pressed: bool) -> void:
	var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed;Input.parse_input_event(event)
func stop() -> void:
	for code in [KEY_W,KEY_A,KEY_S,KEY_D,KEY_E]:key(code,false)
func ticks(count: int) -> void:
	for frame in count:await physics_frame
func setup_case(point: Vector3) -> void:
	# A fresh independent probe, never an in-game rescue from a recorded fall.
	stop();app.set_paused(true);app.level_complete=false;app.replace_world({})
	for enemy in app.combat.enemies:enemy.set_physics_process(false)
	app.world.flags["clear_final_arena"]=true
	app.world.flags["exit_control"]=true
	app.player.set_physics_process(false);app.player.global_position=point;app.player.velocity=Vector3.ZERO
	app.player.get_node("Camera3D").rotation=Vector3.ZERO
	app.enter_combat();await ticks(2);app.player.set_physics_process(true);await ticks(2)
func floor_sample(point: Vector3) -> Dictionary:
	var hit: Dictionary=app.world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point,point-Vector3(0,60,0),1))
	return {"supported":not hit.is_empty(),"height":float(hit.position.y) if not hit.is_empty() else null,"collider":String(hit.collider.name) if not hit.is_empty() else ""}
func checkpoint() -> Dictionary:
	return {"physics_tick":Engine.get_physics_frames(),"position":xyz(app.player.global_position),"velocity":xyz(app.player.velocity),"on_floor":app.player.is_on_floor(),"support_below_feet":floor_sample(app.player.global_position-Vector3(0,.82,0))}
func walk(goal: Vector3, code: int, label: String, limit:=240) -> Dictionary:
	var actor: CharacterBody3D=app.player
	var delta: Vector3=goal-actor.global_position;delta.y=0
	var yaw:=atan2(-delta.x,-delta.z)
	if code==KEY_S:yaw+=PI
	elif code==KEY_A:yaw-=PI/2
	elif code==KEY_D:yaw+=PI/2
	actor.rotation.y=yaw
	var initial: Dictionary=checkpoint();var trace: Array[Dictionary]=[];var elapsed:=0
	var first_unsupported: Dictionary={}
	key(code,true)
	# Release before the target and let the unchanged acceleration brake the
	# CharacterBody naturally; no velocity cancellation or position correction.
	while elapsed<limit and Vector2(actor.global_position.x-goal.x,actor.global_position.z-goal.z).length()>.75:
		await physics_frame;elapsed+=1
		var sample: Dictionary=checkpoint()
		if not sample.support_below_feet.supported and first_unsupported.is_empty():first_unsupported=sample
		if elapsed%12==0:trace.append(sample)
		if actor.global_position.y<lower_floor-12:break
	stop();await ticks(16)
	return {"label":label,"key":OS.get_keycode_string(code),"initial":initial,"goal":xyz(goal),"ticks":elapsed,"reached":Vector2(actor.global_position.x-goal.x,actor.global_position.z-goal.z).length()<=.5,"first_no_support_below":first_unsupported,"trace":trace,"terminal":checkpoint()}
func watch_fall(label: String) -> Dictionary:
	var trace: Array[Dictionary]=[];var initial: Dictionary=checkpoint();var min_y: float=app.player.global_position.y
	var elapsed:=0;var settled:=0;var fell_into_void:=false
	while elapsed<240:
		await physics_frame;elapsed+=1
		min_y=minf(min_y,app.player.global_position.y)
		if elapsed%12==0:trace.append(checkpoint())
		if app.player.is_on_floor() and absf(app.player.velocity.y)<.01:settled+=1
		else:settled=0
		if app.player.global_position.y<lower_floor-12:fell_into_void=true;break
		if settled>24:break
	var terminal: Dictionary=checkpoint()
	return {"label":label,"ticks":elapsed,"initial":initial,"minimum_actor_y":min_y,"fell_below_lowest_landing":fell_into_void,"settled_on_floor":settled>24,"terminal":terminal,"trace":trace,"health":app.combat.health,"armor":app.combat.armor,"recovery_used":false}
func lift_use(lift: Node3D, target_upper: bool) -> Dictionary:
	var before: Dictionary=checkpoint();var selected: Node3D=app.world.nearest_mechanism()
	check(selected==lift,"actual E did not select lift at fixed landing call position")
	key(KEY_E,true);await ticks(2);key(KEY_E,false)
	check(lift.upper==target_upper and lift.moving,"actual E call did not start expected lift direction")
	var elapsed:=0;var trace: Array[Dictionary]=[]
	while lift.moving and elapsed<400:
		await physics_frame;elapsed+=1
		if elapsed%24==0:trace.append({"lift":xyz(lift.global_position),"player":checkpoint()})
	check(not lift.moving,"lift failed to dock")
	await ticks(4)
	return {"target_upper":target_upper,"before":before,"ticks":elapsed,"trace":trace,"terminal":checkpoint(),"lift_terminal":xyz(lift.global_position)}
func geometry(lift: Node3D, portal: Dictionary) -> Dictionary:
	var deck: BoxShape3D=lift.get_node("Collision").shape
	var normal: Vector3=(vector(portal.end)-vector(portal.start));normal.y=0;normal=normal.normalized()
	var index: int=route.portals.find(portal)
	var approach: Node3D=app.world.get_node("Link_"+str(index)+"_Approach")
	var shape: BoxShape3D=approach.get_node("Collision").shape
	var room: Node3D=app.world.get_node("observation_Floor")
	var room_shape: BoxShape3D=room.get_node("Collision").shape
	var shaft_samples: Array[Dictionary]=[]
	for forward in [-1.5,0.0,1.5]:
		for sideways in [-1.5,0.0,1.5]:
			var point: Vector3=lift.get_parent().to_global(lift.origin)+normal*forward+Vector3(0,.5,sideways)
			shaft_samples.append({"position":xyz(point),"floor":floor_sample(point)})
	return {"portal":portal,"lift_origin":xyz(lift.origin),"deck_size":xyz(deck.size),"lift_offset":xyz(lift.lift_offset),"deck_lower_top":lift.origin.y+deck.size.y/2,"deck_upper_top":lift.origin.y+lift.lift_offset.y+deck.size.y/2,"approach_center":xyz(approach.global_position),"approach_size":xyz(shape.size),"approach_top":approach.global_position.y+shape.size.y/2,"upper_room_floor_center":xyz(room.global_position),"upper_room_floor_size":xyz(room_shape.size),"upper_room_floor_top":room.global_position.y+room_shape.size.y/2,"shaft_lower_samples":shaft_samples}
func classify(case: Dictionary, type: String) -> void:
	if bool(case.observation.fell_below_lowest_landing):
		hazards.append({"level":level_id,"type":type,"initial":case.observation.initial,"terminal":case.observation.terminal,"minimum_actor_y":case.observation.minimum_actor_y,"no_recovery":true})
	elif type=="upper_open_shaft_drop" and float(case.movement.initial.position[1])-float(case.observation.minimum_actor_y)>1:
		hazards.append({"level":level_id,"type":"unguarded_upper_drop_to_lower_deck","drop_metres":float(case.movement.initial.position[1])-float(case.observation.minimum_actor_y),"terminal":case.observation.terminal,"no_recovery":true})
func audit_lift(portal: Dictionary) -> Dictionary:
	var normal: Vector3=vector(portal.end)-vector(portal.start);normal.y=0;normal=normal.normalized()
	var lower: Vector3=vector(portal.end)-normal*2;lower.y=float(portal.start[1])+.87
	var call_lower: Vector3=lower-normal*2.4
	var call_upper: Vector3=lower+normal*2.4;call_upper.y=float(portal.end[1])+.87
	lower_floor=float(portal.start[1])
	await setup_case(call_lower)
	var lift: Node3D=app.world.get_node("Lift_Observation")
	var native_geometry: Dictionary=geometry(lift,portal)
	var board: Dictionary=await walk(lower,KEY_W,"ordinary W boarding")
	check(board.reached,"could not board native lower lift")
	var up: Dictionary=await lift_use(lift,true)
	check(absf(app.player.global_position.y-call_upper.y)<.15,"native CharacterBody moving-platform carry failed")
	var leave: Dictionary=await walk(call_upper,KEY_W,"ordinary W upper disembark")
	check(leave.reached and app.player.is_on_floor(),"normal docked upper landing unsupported")
	var down_empty: Dictionary=await lift_use(lift,false)
	var return_from_upper: Dictionary=await lift_use(lift,true)
	var down_again: Dictionary=await lift_use(lift,false)
	var upper_strafe: Dictionary=await walk(lower,KEY_A if normal.x>0 else KEY_D,"strafe upper landing into shaft with deck below")
	var upper_drop: Dictionary=await watch_fall("upper landing absent deck drop")
	var upper_case: Dictionary={"movement":upper_strafe,"observation":upper_drop}
	classify(upper_case,"upper_open_shaft_drop")
	# Rebuild after fully recording the preceding outcome. No gameplay rescue.
	await setup_case(call_lower);lift=app.world.get_node("Lift_Observation")
	var empty_up: Dictionary=await lift_use(lift,true)
	var lower_call: Dictionary=await lift_use(lift,false)
	var empty_up_again: Dictionary=await lift_use(lift,true)
	var away_geometry: Dictionary=geometry(lift,portal)
	var lower_walk: Dictionary=await walk(lower,KEY_W,"W lower landing with platform away")
	var lower_fall: Dictionary=await watch_fall("lower empty shaft")
	var lower_case: Dictionary={"movement":lower_walk,"observation":lower_fall}
	classify(lower_case,"lower_lift_away_void")
	await setup_case(lower);lift=app.world.get_node("Lift_Observation")
	check(app.player.is_on_floor(),"early ascent setup did not stand on actual deck")
	check(app.world.nearest_mechanism()==lift,"early ascent E did not select lift")
	key(KEY_E,true);await ticks(2);key(KEY_E,false)
	var departure_height: float=lift.global_position.y+.15
	var early_walk: Dictionary=await walk(call_upper,KEY_W,"W leaves lift before upper docking")
	var early_fall: Dictionary=await watch_fall("under upper room during ascent")
	var early_case: Dictionary={"departure_deck_top":departure_height,"upper_landing_height":float(portal.end[1]),"movement":early_walk,"observation":early_fall,"lift_moving_at_terminal":lift.moving,"lift_position_at_terminal":xyz(lift.global_position)}
	classify(early_case,"early_ascent_upper_underfloor_void")
	return {"geometry":native_geometry,"geometry_with_deck_away":away_geometry,"normal_boarding":board,"ride_up":up,"normal_upper_disembark":leave,"upper_empty_down_call":down_empty,"manual_return_from_upper_away":return_from_upper,"lower_again":down_again,"upper_strafe_case":upper_case,"prepare_upper_empty":empty_up,"manual_return_from_lower_away":lower_call,"prepare_lower_empty":empty_up_again,"lower_walk_case":lower_case,"early_ascent_case":early_case}
func nudge(direction: Vector3, code: int) -> Dictionary:
	var yaw:=atan2(-direction.x,-direction.z)
	if code==KEY_S:yaw+=PI
	elif code==KEY_A:yaw-=PI/2
	elif code==KEY_D:yaw+=PI/2
	app.player.rotation.y=yaw
	var before: Dictionary=checkpoint()
	key(code,true);await ticks(6);stop();await ticks(16)
	return {"key":OS.get_keycode_string(code),"pressed_ticks":6,"natural_braking_ticks":16,"initial":before,"terminal":checkpoint()}
func straddle_refusal(lift: Node3D, gate: Node3D) -> Dictionary:
	check(gate.opened and not gate.entrance_clear(),"actual passenger does not straddle the open landing guard")
	var before_position: Vector3=lift.position;var upper: bool=lift.upper
	check(app.world.nearest_mechanism()==lift,"straddling passenger cannot select actual E lift call")
	key(KEY_E,true);await ticks(3);key(KEY_E,false)
	check(not lift.moving and lift.upper==upper and lift.position==before_position and gate.opened,"lift departed/closed a guard through straddling passenger")
	return {"player":checkpoint(),"entrance_clear":gate.entrance_clear(),"guard_open":gate.opened,"guard_collision_disabled":gate.get_node("Collision").disabled,"lift_remained_stationary":not lift.moving and lift.position==before_position}
func guard_rays(lift: Node3D, normal: Vector3) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for gate in lift.landing_gates:
		var point: Vector3=gate.global_position
		var hit: Dictionary=app.world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point-normal*.6,point+normal*.6,1))
		check(hit.is_empty() if gate.opened else not hit.is_empty() and hit.collider==gate,"landing guard ray/visible-collision state diverged")
		check(gate.get_node("Collision").disabled==gate.opened,"guard collider differs from docking state")
		result.append({"guard":String(gate.name),"landing_height":float(gate.get_meta("landing_height")),"open":gate.opened,"collision_disabled":gate.get_node("Collision").disabled,"ray_hit":String(hit.collider.name) if not hit.is_empty() else "","position":xyz(point)})
	return result
func audit_guarded_lift(portal: Dictionary) -> Dictionary:
	var normal: Vector3=vector(portal.end)-vector(portal.start);normal.y=0;normal=normal.normalized()
	var lower: Vector3=vector(portal.end)-normal*2;lower.y=float(portal.start[1])+.87
	# Fixed call buttons are outside the guards; this placement gives the
	# conservative entrance sweep full clearance before requesting departure.
	var call_lower: Vector3=lower-normal*2.8
	var call_upper: Vector3=lower+normal*2.8;call_upper.y=float(portal.end[1])+.87
	lower_floor=float(portal.start[1])
	await setup_case(call_lower)
	var lift: Node3D=app.world.get_node("Lift_Observation")
	check(lift.landing_gates.size()==2,"guarded lift lacks two native landing guards")
	if lift.landing_gates.size()!=2:return {}
	var lower_gate: Node3D=lift.landing_gates[0];var upper_gate: Node3D=lift.landing_gates[1]
	if float(lower_gate.get_meta("landing_height"))>float(upper_gate.get_meta("landing_height")):
		var saved: Node3D=lower_gate;lower_gate=upper_gate;upper_gate=saved
	var initial_rays: Array[Dictionary]=guard_rays(lift,normal)
	var lower_straddle_movement: Dictionary=await nudge(normal,KEY_W)
	var lower_refusal: Dictionary=await straddle_refusal(lift,lower_gate)
	var board: Dictionary=await walk(lower,KEY_W,"W clear lower guard and board")
	check(board.reached,"guarded lower boarding failed")
	var up: Dictionary=await lift_use(lift,true)
	check(absf(app.player.global_position.y-call_upper.y)<.15,"guarded lift lost actual upward carry")
	var upper_rays: Array[Dictionary]=guard_rays(lift,normal)
	var leave: Dictionary=await walk(call_upper,KEY_W,"W docked upper guard disembark")
	check(leave.reached and app.player.is_on_floor(),"guarded upper disembark unsupported")
	var down_empty: Dictionary=await lift_use(lift,false)
	var closed_upper_rays: Array[Dictionary]=guard_rays(lift,normal)
	var upper_probe: Dictionary=await walk(lower,KEY_A if normal.x>0 else KEY_D,"same upper-to-shaft strafe with platform below",90)
	var upper_observation: Dictionary=await watch_fall("upper guard containment")
	check(not upper_probe.reached and upper_observation.settled_on_floor and absf(app.player.global_position.y-call_upper.y)<.15,"closed upper guard allowed old empty-shaft drop")
	var return_up: Dictionary=await lift_use(lift,true)
	# Move back to the stable fixed call stance using actual motion, then
	# straddle the upper opening while it is docked and open.
	await walk(call_upper,KEY_W,"W away from upper doorway before straddle")
	var upper_straddle_movement: Dictionary=await nudge(-normal,KEY_A if normal.x>0 else KEY_D)
	var upper_refusal: Dictionary=await straddle_refusal(lift,upper_gate)
	var board_upper: Vector3=lower;board_upper.y=call_upper.y
	var upper_board: Dictionary=await walk(board_upper,KEY_S,"S through docked upper guard onto deck")
	check(upper_board.reached,"upper deck boarding failed")
	var ride_down: Dictionary=await lift_use(lift,false)
	check(absf(app.player.global_position.y-lower.y)<.15,"guarded lift lost actual downward carry")
	var lower_leave: Dictionary=await walk(call_lower,KEY_S,"S through docked lower guard onto approach")
	check(lower_leave.reached and app.player.is_on_floor(),"lower deck disembark unsupported")
	var empty_up: Dictionary=await lift_use(lift,true)
	var away_geometry: Dictionary=geometry(lift,portal)
	for sample in away_geometry.shaft_lower_samples:
		check(sample.floor.supported and float(sample.floor.height)>=lower_floor-.31,"fixed shaft base fails to support deck footprint when lift away")
	var closed_lower_rays: Array[Dictionary]=guard_rays(lift,normal)
	var lower_probe: Dictionary=await walk(lower,KEY_W,"same lower-to-shaft W with platform away",90)
	var lower_observation: Dictionary=await watch_fall("lower guard containment")
	check(not lower_probe.reached and lower_observation.settled_on_floor and absf(app.player.global_position.y-lower.y)<.15,"closed lower guard allowed old unsupported entry")
	var return_down: Dictionary=await lift_use(lift,false)
	await setup_case(lower);lift=app.world.get_node("Lift_Observation")
	key(KEY_E,true);await ticks(2);key(KEY_E,false)
	var early_walk: Dictionary=await walk(call_upper,KEY_W,"same immediate ascent W toward upper underfloor",260)
	var early_observation: Dictionary=await watch_fall("early upper departure now physically contained")
	check(not early_observation.fell_below_lowest_landing and early_observation.settled_on_floor,"upper underfloor escape remains unbounded")
	classify({"movement":early_walk,"observation":early_observation},"early_ascent_upper_underfloor_void")
	await setup_case(lower);lift=app.world.get_node("Lift_Observation")
	key(KEY_E,true);await ticks(2);key(KEY_E,false)
	var early_back: Dictionary=await walk(call_lower,KEY_S,"early S back toward fixed approach",260)
	var early_back_observation: Dictionary=await watch_fall("early backward departure bounded")
	check(not early_back_observation.fell_below_lowest_landing and early_back_observation.settled_on_floor,"early backward departure lacks physical support")
	classify({"movement":early_back,"observation":early_back_observation},"early_backward_departure_void")
	# Declared independent under-deck initial placement exercises emergency
	# support/egress. The deck is first raised through an actual fixed E call.
	await setup_case(call_lower);lift=app.world.get_node("Lift_Observation")
	await lift_use(lift,true)
	app.player.set_physics_process(false)
	app.player.global_position=Vector3(lower.x,lower_floor-.3+.87,lower.z)
	app.player.velocity=Vector3.ZERO
	await ticks(2);app.player.set_physics_process(true);await ticks(4)
	check(app.player.is_on_floor(),"declared midshaft fixture lacks actual base support")
	var base_initial: Dictionary=checkpoint()
	check(app.world.nearest_mechanism()==lift,"shaft-base passenger cannot select real E return call")
	key(KEY_E,true);await ticks(2);key(KEY_E,false)
	var obstruction_ticks:=0
	while not lift.obstructed and lift.moving and obstruction_ticks<400:
		await physics_frame;obstruction_ticks+=1
	check(lift.obstructed and lift.moving,"descending deck did not pause above actual under-deck passenger")
	var obstruction_position: Vector3=lift.position
	var head_clearance: float=lift.global_position.y-.15-(app.player.global_position.y+.85)
	await ticks(24)
	check(lift.position==obstruction_position and app.combat.health==100 and head_clearance>.30,"paused descending platform crushes or displaces base passenger")
	var emergency_rays: Array[Dictionary]=guard_rays(lift,normal)
	var emergency_walk: Dictionary=await walk(call_lower,KEY_S,"S emergency tread egress from shaft base",240)
	check(emergency_walk.reached and app.player.is_on_floor() and absf(app.player.global_position.y-lower.y)<.15,"real S egress failed emergency tread/approach")
	var resume_ticks:=0
	while lift.moving and resume_ticks<400:await physics_frame;resume_ticks+=1
	await ticks(4)
	check(not lift.moving and not lift.obstructed and not lift.upper,"descent did not resume/dock after passenger physically cleared guard")
	var emergency: Dictionary={"declared_initial_placement_after_actual_E_raise":base_initial,"obstruction_ticks":obstruction_ticks,"paused_deck_position":xyz(obstruction_position),"head_clearance":head_clearance,"emergency_guard_rays":emergency_rays,"ordinary_S_egress":emergency_walk,"resumed_ticks":resume_ticks,"terminal":checkpoint(),"lift_lower_docked":not lift.moving and not lift.upper}
	var old_id: int=app.world.get_instance_id()
	app.restart_combat()
	for enemy in app.combat.enemies:enemy.set_physics_process(false)
	await ticks(3)
	lift=app.world.get_node("Lift_Observation")
	check(app.world.get_instance_id()!=old_id and not lift.upper and not lift.moving and lift.position==lift.origin,"Main Retry did not restore lower dock")
	var retry_rays: Array[Dictionary]=guard_rays(lift,normal)
	check(not app.world.flags.get("clear_final_arena",false) and not app.world.flags.get("exit_control",false),"Retry retained injected control permissions")
	return {"geometry_with_deck_away":away_geometry,"initial_guard_rays":initial_rays,"lower_straddle_movement":lower_straddle_movement,"lower_departure_refusal":lower_refusal,"board":board,"ride_up":up,"upper_guard_rays":upper_rays,"upper_leave":leave,"empty_down_call":down_empty,"closed_upper_rays":closed_upper_rays,"upper_old_path":upper_probe,"upper_containment":upper_observation,"upper_return_call":return_up,"upper_straddle_movement":upper_straddle_movement,"upper_departure_refusal":upper_refusal,"upper_board":upper_board,"ride_down":ride_down,"lower_leave":lower_leave,"empty_up_call":empty_up,"closed_lower_rays":closed_lower_rays,"lower_old_path":lower_probe,"lower_containment":lower_observation,"lower_return_call":return_down,"early_upper_old_path":early_walk,"early_upper_containment":early_observation,"early_backward_path":early_back,"early_backward_containment":early_back_observation,"midshaft_emergency_case":emergency,"retry_guard_rays":retry_rays,"retry_lower_docked":not lift.upper and not lift.moving}
func audit_exit() -> Dictionary:
	var portal: Dictionary={}
	for item in route.portals:
		if String(item.to)=="exit_gallery":portal=item;break
	check(not portal.is_empty(),"exit gallery connector missing")
	if portal.is_empty():return {}
	var from: Vector3=vector(portal.start);var to: Vector3=vector(portal.end)
	var normal: Vector3=to-from;normal.y=0;normal=normal.normalized()
	lower_floor=minf(from.y,to.y)
	var initial: Vector3=from-normal*2+Vector3(0,.87,0)
	await setup_case(initial)
	var door: Node3D=app.world.get_node(String(portal.door))
	# Declared final-arena exit-control fixture flag grants the same native door
	# permission. No enemy health/ammo or invulnerability alterations occur.
	check(door.activate(app.world.flags),"exit gate fixture permission rejected")
	await ticks(110)
	var forward: Dictionary=await walk(to+normal*2+Vector3(0,.87,0),KEY_W,"W through enabled exit doorway",300)
	check(forward.reached and app.player.is_on_floor(),"ordinary exit doorway W traversal failed")
	var room: Dictionary=route.rooms.exit_gallery
	var center: Vector3=vector(room.center)
	var cross: Vector3=Vector3.RIGHT if int(portal.axis)==2 else Vector3.BACK
	var left: Vector3=app.player.global_position-cross*(float(room.size[0 if int(portal.axis)==2 else 2])/2+2)
	var wall_left: Dictionary=await walk(left,KEY_A,"A strafe against exit gallery wall",160)
	check(app.player.is_on_floor() and app.player.global_position.y>center.y+.6,"A exit wall probe fell below gallery")
	var right: Vector3=app.player.global_position+cross*(float(room.size[0 if int(portal.axis)==2 else 2])+4)
	var wall_right: Dictionary=await walk(right,KEY_D,"D strafe against opposite exit gallery wall",260)
	check(app.player.is_on_floor() and app.player.global_position.y>center.y+.6,"D exit wall probe fell below gallery")
	var align: Vector3=app.player.global_position;align.x=to.x if int(portal.axis)==2 else align.x;align.z=to.z if int(portal.axis)==0 else align.z
	var return_center: Dictionary=await walk(align,KEY_A,"A return to doorway center",200)
	check(return_center.reached,"gallery return to doorway center failed")
	var backward: Dictionary=await walk(initial,KEY_S,"S back through exit doorway",300)
	check(backward.reached and app.player.is_on_floor(),"ordinary exit doorway S traversal failed")
	return {"portal":portal,"forward":forward,"left_wall":wall_left,"right_wall":wall_right,"return_to_center":return_center,"backward":backward,"lower_floor":lower_floor}
func run() -> void:
	app=load("res://scenes/main.tscn").instantiate();root.add_child(app);await process_frame
	var levels: Array=app.campaign.levels.duplicate(true)
	if include_standalone:
		for stage in app.stage_catalog:levels.append({"id":String(stage.id),"scene":String(stage.scene),"theme":String(stage.id),"standalone":true})
	levels.sort_custom(func(a,b):return String(a.id)=="pale_ward_01" if String(a.id)!=String(b.id) and (String(a.id)=="pale_ward_01" or String(b.id)=="pale_ward_01") else String(a.id)<String(b.id))
	for level_value in levels:
		var level: Dictionary=level_value;level_id=String(level.id)
		app.campaign_mode=not bool(level.get("standalone",false))
		if app.campaign_mode:app.campaign.seek(level_id)
		app.stage_id=String(level.theme)
		var route_folder:="campaign/" if app.campaign_mode else "stages/"
		route=JSON.parse_string(FileAccess.get_file_as_string("res://resources/"+route_folder+level_id+"-route.json"))
		var lifts: Array[Dictionary]=[]
		for portal in route.portals:
			if bool(portal.get("lift",false)):
				lifts.append(await audit_guarded_lift(portal) if postfix else await audit_lift(portal))
		var exit_evidence: Dictionary=await audit_exit()
		records.append({"level":level_id,"standalone":bool(level.get("standalone",false)),"scene":String(level.scene),"scene_sha256":FileAccess.get_sha256(String(level.scene)),"lifts":lifts,"exit_gallery_wasd":exit_evidence})
		save_report();print("LIFT_EDGE_AUDIT_LEVEL ",level_id," lifts=",lifts.size()," cumulative_hazards=",hazards.size()," fixture_errors=",errors.size())
	if postfix:check(hazards.is_empty(),"guarded source still reproduces unsafe void movement")
	save_report();print("LIFT_EDGE_AUDIT_COMPLETE levels=",records.size()," hazards=",hazards.size()," fixture_errors=",errors.size()," receipt=",DIR+report_name+".json")
	await app.quit_game();quit(0 if errors.is_empty() else 1)
func save_report() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var report:={"status":"fixture_error" if not errors.is_empty() else "hazards_reproduced" if not hazards.is_empty() else "contained","errors":errors,"hazards":hazards,"levels":records,"display_server":DisplayServer.get_name(),"physics_ticks_per_second":Engine.physics_ticks_per_second,"scope":"Actual native Main CharacterBody W/A/S/D movement, moving-platform carry, fixed-landing E calls and collision-floor/edge audit. Initial placements and cleared-final/exit-control flags are declared independent probe setup; enemy AI frozen. No recovery, collision disabling, invulnerability, ammo/health tuning, scene/pickup movement or old user-process manipulation.","limitations":["AI/control fixtures isolate map support; not combat survival or human input feel.","Separate independent probes rebuild the map after recording a terminal fall; this is not runtime recovery.","Exit-gallery center traversal and wall strafes supplement the independent Foundation full-width stair audit.","Headless runs verify actual Godot physics, not native visual acceptance."],"recommended_geometry_fixes":["Provide fixed shaft containment/floor below both landings to stop any actor falling out when the platform is absent.","Use platform-synchronized physical landing gates, closed during travel and while the platform is away, to prevent lower-entry and upper-disembark access to an empty shaft.","Keep the deck-to-landing floor overlap and add clear lift/call signage rather than implying an always-present staircase."]}
	var file:=FileAccess.open(DIR+report_name+".json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
