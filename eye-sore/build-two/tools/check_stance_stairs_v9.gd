extends "res://tools/check_intake_physics_v7.gd"
## Bounded actual Ward stance stairs. Only fixture placements/open-door calls.
var stance_walks:=[]
var head_probe:=SphereShape3D.new()
var frozen:={}
func _initialize()->void:
	report_path="res://verification/production-v9/movement-stairs/geometry.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report_path=arg.trim_prefix("--report=")
	call_deferred("run")
func stop_all()->void:
	stop();key(KEY_CTRL,false);key(KEY_SHIFT,false);Input.flush_buffered_events()
func stance_walk(portal:Dictionary,index:int,reverse:bool,code:int,modifier:int)->void:
	var speed:=4.4 if modifier==KEY_CTRL else 10.8
	var label:="link%d %s %s+%s"%[index,"reverse" if reverse else "forward",OS.get_keycode_string(modifier),OS.get_keycode_string(code)]
	var a:=vec(portal.start);var b:=vec(portal.end)
	var along:=b-a;along.y=0;along=along.normalized()
	var start:=a-along;var goal:=b+along
	if reverse:var swap:=start;start=goal;goal=swap
	actor.set_physics_process(false);stop_all();actor.set_movement_active(false)
	actor.global_position=start+Vector3(0,.87,0)
	# Previous run can leave a crouched body. Restore only via real clearance
	# method at the independently declared clear landing, then set start center.
	actor._set_crouching(false);actor.global_position=start+Vector3(0,.87,0);actor.velocity=Vector3.ZERO
	var motion:=goal-start;motion.y=0
	actor.rotation.y=atan2(-motion.x,-motion.z)+(PI if code==KEY_S else 0.0)
	await ticks(3);actor.set_movement_active(true);actor.set_physics_process(true);await ticks(8)
	check(actor.is_on_floor(),label+" starts grounded")
	var initial_feet:float=actor.global_position.y-actor.body_collision.shape.height*.5
	key(modifier,true);Input.flush_buffered_events();await ticks(2)
	check(actor.is_crouching==(modifier==KEY_CTRL),label+" real modifier changes physical stance")
	check(absf((actor.global_position.y-actor.body_collision.shape.height*.5)-initial_feet)<.004,label+" modifier preserves feet")
	var initial:=actor.global_position;var last:=initial
	var distance:=Vector2(start.x-goal.x,start.z-goal.z).length()
	var limit:=int(ceil(distance/speed*60))+180
	var elapsed:=0;var missing_support:=[];var head_contacts:=[];var stance_errors:=[];var samples:=[]
	var airborne:=0;var airborne_run:=0;var longest_air:=0;var max_speed:=0.0;var max_tick_distance:=0.0;var max_floor_gap:=0.0;var sprint_ticks:=0
	key(code,true);Input.flush_buffered_events()
	while elapsed<limit and Vector2(actor.global_position.x-goal.x,actor.global_position.z-goal.z).length()>.55:
		await physics_frame;elapsed+=1
		var p:=actor.global_position
		var horizontal_speed:=Vector2(actor.velocity.x,actor.velocity.z).length();max_speed=maxf(max_speed,horizontal_speed)
		max_tick_distance=maxf(max_tick_distance,Vector2(p.x-last.x,p.z-last.z).length());last=p
		if not actor.is_on_floor():airborne+=1;airborne_run+=1;longest_air=maxi(longest_air,airborne_run)
		else:airborne_run=0
		if actor.is_sprinting:sprint_ticks+=1
		if actor.is_crouching!=(modifier==KEY_CTRL):stance_errors.append(elapsed)
		var foot:=p-Vector3(0,actor.body_collision.shape.height*.5,0)
		var support:=ray(foot+Vector3.UP*.06,foot-Vector3.UP*.32)
		if support.is_empty():missing_support.append({"tick":elapsed,"feet":xyz(foot)})
		else:max_floor_gap=maxf(max_floor_gap,foot.y-support.position.y)
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=head_probe;query.transform=Transform3D(Basis.IDENTITY,actor.camera.global_position);query.collision_mask=1;query.exclude=[actor.get_rid()];query.margin=0.0
		var contacts:=world.get_world_3d().direct_space_state.intersect_shape(query,1)
		if not contacts.is_empty():head_contacts.append({"tick":elapsed,"camera":xyz(actor.camera.global_position),"collider":relative(contacts[0].collider)})
		if elapsed%8==0:samples.append({"tick":elapsed,"position":xyz(p),"feet_y":foot.y,"grounded":actor.is_on_floor(),"speed":horizontal_speed,"crouching":actor.is_crouching,"sprinting":actor.is_sprinting,"camera":xyz(actor.camera.global_position)})
		if p.y<minf(start.y,goal.y)-3.0:break
	var arrival:=actor.global_position
	var arrival_error:=Vector2(arrival.x-goal.x,arrival.z-goal.z).length()
	stop_all()
	for coast_tick in 18:
		await physics_frame
		var foot:Vector3=actor.global_position-Vector3(0,actor.body_collision.shape.height*.5,0)
		var support:=ray(foot+Vector3.UP*.06,foot-Vector3.UP*.32)
		if support.is_empty():missing_support.append({"coast_tick":coast_tick,"feet":xyz(foot)})
		else:max_floor_gap=maxf(max_floor_gap,foot.y-support.position.y)
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=head_probe;query.transform=Transform3D(Basis.IDENTITY,actor.camera.global_position);query.collision_mask=1;query.exclude=[actor.get_rid()];query.margin=0.0
		var contacts:=world.get_world_3d().direct_space_state.intersect_shape(query,1)
		if not contacts.is_empty():head_contacts.append({"coast_tick":coast_tick,"camera":xyz(actor.camera.global_position),"collider":relative(contacts[0].collider)})
	var braking_distance_bound:=speed*speed/(2.0*42.0)+speed/60.0+.02
	var error:=Vector2(actor.global_position.x-goal.x,actor.global_position.z-goal.z).length()
	check(arrival_error<=.55,label+" actually reaches target landing before release")
	check(error<=arrival_error+braking_distance_bound,label+" release coast stays within unchanged physical braking bound")
	check(absf(actor.global_position.y-actor.body_collision.shape.height*.5-goal.y)<.01,label+" settles on declared far landing floor")
	check(actor.is_on_floor(),label+" terminal grounded")
	check(missing_support.is_empty(),label+" no floor gap under actual capsule feet")
	check(head_contacts.is_empty(),label+" real camera head/nearplane clearance")
	check(stance_errors.is_empty(),label+" modifier held throughout traverse")
	check(longest_air<=4,label+" no sustained airborne stair motion")
	check(max_floor_gap<=.27,label+" feet stay within floor-snap/step clearance")
	check(max_speed<=speed+.01 and max_speed>=speed-.02,label+" reaches declared speed without boost")
	check(max_tick_distance<=speed/60.0+.003,label+" horizontal per-tick displacement bounded")
	if modifier==KEY_SHIFT:check(sprint_ticks>0,label+" true grounded sprint observed")
	stance_walks.append({"label":label,"link":index,"from":portal.from,"to":portal.to,"reverse":reverse,"movement_key":OS.get_keycode_string(code),"modifier":OS.get_keycode_string(modifier),"target_speed":speed,"initial":xyz(initial),"goal_floor":xyz(goal),"terminal":xyz(actor.global_position),"goal_xz_error":error,"arrival_before_release":xyz(arrival),"arrival_xz_error":arrival_error,"braking_distance_bound":braking_distance_bound,"ticks":elapsed,"tick_budget":limit,"airborne_ticks":airborne,"maximum_contiguous_airborne_ticks":longest_air,"maximum_floor_gap":max_floor_gap,"maximum_speed":max_speed,"maximum_horizontal_tick_distance":max_tick_distance,"sprint_ticks":sprint_ticks,"missing_support":missing_support,"head_contacts":head_contacts,"stance_errors":stance_errors,"trace":samples})
	actor.set_physics_process(false)
func run()->void:
	head_probe.radius=.05
	for path in ["scripts/player.gd","scripts/grounded_step.gd","scenes/campaign/pale_ward_01.tscn"]:frozen[path]=FileAccess.get_sha256("res://"+path)
	route=JSON.parse_string(FileAccess.get_file_as_string("res://resources/campaign/pale_ward_01-route.json"))
	world=load("res://scenes/campaign/pale_ward_01.tscn").instantiate();root.add_child(world)
	world.set_physics_process(false);world.scan(world);actor=world.get_node("Player");actor.set_physics_process(false)
	var flags:Dictionary={}
	for portal in route.portals:
		for need in portal.requires:flags[String(need)]=true
	for node in world.get_children():
		if node.has_method("activate") and (node.has_meta("stage_door") or node.has_meta("trap_entry") or node.has_meta("trap_shutter")):
			node.activate(flags);opened.append(String(node.name))
	await ticks(120)
	for index in [2,13]:
		for modifier in [KEY_CTRL,KEY_SHIFT]:
			for reverse in [false,true]:
				for code in [KEY_W,KEY_S]:await stance_walk(route.portals[index],index,reverse,code,modifier)
	for path in frozen:check(FileAccess.get_sha256("res://"+path)==frozen[path],"Production source unchanged "+path)
	var report:={"passed":failures.is_empty(),"checks":checks,"failures":failures,"physics_rate":Engine.physics_ticks_per_second,"source_sha256":frozen,"fixture_sha256":FileAccess.get_sha256("res://tools/check_stance_stairs_v9.gd"),"opened_actual_doors":opened,"walks":stance_walks,"scope":"Isolated actual production Ward Intake scene/player/shared grounded_step. All-access doors opened using real activate; independent declared landing placements. Real Ctrl/Shift plusW/S, bothdirections across steep link2 and C3exit link13. Camerahead probe radius.05m excludesactor. Bounded geometry/movement proof, not campaign progression or human gamefeel.","criteria":"Arrival within.55m before release; terminal position within speed-squared/2acceleration braking bound and actual target landing floorheight. Terminal actual is_on_floor; centered-foot support within.32m throughout, no >4 consecutive airborne ticks, no head-probe collision, real stance held, maxspeed equals4.4/10.8 and no horizontal accelerationboost."}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(report_path).get_base_dir())
	var file:=FileAccess.open(report_path,FileAccess.WRITE);file.store_string(JSON.stringify(report,"  ")+"\n");file.close()
	print("STANCE_STAIRS_V9 ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,"walks":stance_walks.size(),"failures":failures}))
	world.free();quit(0 if failures.is_empty() else 1)
