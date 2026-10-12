extends SceneTree
## Geometry isolation: authored Ward01, no combat/AI/audio, doors opened through real timelines.
var world:Node3D
var player:CharacterBody3D
var route:Dictionary
var scans:Array[Dictionary]=[]
var walks:Array[Dictionary]=[]
var mismatches:Array[Dictionary]=[]
var falling:=false
var step_samples:Array[Dictionary]=[]
func _initialize()->void:call_deferred("run")
func ray(at:Vector3,depth:float=5.0)->Dictionary:
	return world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*.45,at-Vector3.UP*depth,1,[player.get_rid()]))
func input_key(code:Key,pressed:bool)->void:
	var event:=InputEventKey.new();event.physical_keycode=code;event.pressed=pressed;Input.parse_input_event(event)
func release()->void:
	for code in [KEY_W,KEY_S,KEY_A,KEY_D]:input_key(code,false)
func walk_to(target:Vector3,label:String)->bool:
	var begin:Vector3=player.global_position;var frames:=0;var unsupported:=0;var lowest:=begin.y;var trace:Array[Dictionary]=[]
	while Vector2(player.position.x-target.x,player.position.z-target.z).length()>.24 and frames<240:
		var direction:Vector3=target-player.global_position;direction.y=0
		player.rotation.y=0
		input_key(KEY_W,direction.z<-.15);input_key(KEY_S,direction.z>.15);input_key(KEY_A,direction.x<-.15);input_key(KEY_D,direction.x>.15)
		await physics_frame;frames+=1
		lowest=minf(lowest,player.position.y)
		var hit:Dictionary=ray(player.global_position-Vector3.UP*.85,3)
		if hit.is_empty():unsupported+=1
		if frames%5==0 or hit.is_empty():trace.append({"tick":frames,"position":player.position,"grounded":player.is_on_floor(),"floor_body":str(hit.collider.name) if not hit.is_empty() else "NONE","floor_y":hit.get("position",Vector3(0,-999,0)).y})
		if player.position.y<-.7:
			falling=true;break
	release()
	for _tick in 10:
		await physics_frame
		if player.position.y<-.7:falling=true
	var end:Vector3=player.position
	var passed:bool=not falling and frames<240
	walks.append({"label":label,"initial_supported_fixture_position":begin,"end":end,"ticks":frames,"lowest_center_y":lowest,"unsupported_ticks":unsupported,"fell_out":falling,"reached":frames<240,"trace":trace})
	print("FLOOR_WALK ",label," end=",end," ticks=",frames," no_support=",unsupported," fell=",falling)
	return passed
func initial(at:Vector3)->bool:
	# Independent trial starting pose only. Never recover or reposition a falling trial.
	if falling:return false
	release();player.velocity=Vector3.ZERO;player.position=at
	for _tick in 12:await physics_frame
	return player.is_on_floor()
func dense_portal(portal:Dictionary,index:int)->void:
	if portal.lift:return
	var start:=Vector3(portal.start[0],portal.start[1],portal.start[2]);var finish:=Vector3(portal.end[0],portal.end[1],portal.end[2])
	var direction:Vector3=(finish-start);direction.y=0;var length:float=direction.length();direction=direction.normalized()
	var side:=Vector3(-direction.z,0,direction.x);var samples:=0;var missed:=0;var drops:=0;var gap:Array[Dictionary]=[];var bodies:Dictionary={}
	var along_count:=int(ceil((length+2)/.125));var across_count:=int(ceil((float(portal.width)-.1)/.1))
	for a in range(along_count+1):
		var advance:float=-1+float(a)*(length+2)/along_count
		var t:float=clampf(advance/length,0,1)
		for b in range(across_count+1):
			var offset:float=-(float(portal.width)*.5-.05)+float(b)*(float(portal.width)-.1)/across_count
			var point:Vector3=start+direction*advance+side*offset;point.y=lerpf(start.y,finish.y,t)
			var hit:Dictionary=ray(point,8)
			samples+=1
			if hit.is_empty():
				missed+=1
				if gap.size()<100:gap.append({"point":point,"issue":"no_world_support"})
			else:
				bodies[str(hit.collider.name)]=true
				if hit.normal.y>.7 and point.y-hit.position.y>.5:
					drops+=1
					if gap.size()<100:gap.append({"point":point,"hit_y":hit.position.y,"body":str(hit.collider.name),"issue":"floor_over_half_metre_below_authored_portal"})
	scans.append({"portal":index,"from":portal.from,"to":portal.to,"samples":samples,"misses":missed,"large_drop_samples":drops,"issues":gap,"support_bodies":bodies.keys()})
	print("FLOOR_PORTAL ",index," ",portal.from,"->",portal.to," samples=",samples," misses=",missed," large_drop=",drops)
func audit_boxes(node:Node)->void:
	if node is StaticBody3D and node.has_node("Visual") and node.has_node("Collision"):
		var visual:MeshInstance3D=node.get_node("Visual");var collision:CollisionShape3D=node.get_node("Collision")
		if visual.mesh is BoxMesh and collision.shape is BoxShape3D and not visual.mesh.size.is_equal_approx(collision.shape.size):mismatches.append({"body":str(node.name),"visual_size":visual.mesh.size,"physics_size":collision.shape.size})
		if node.has_meta("stage_step") and (String(node.name).begins_with("Step_13_") or String(node.name).begins_with("final_arena_GalleryStairs")):step_samples.append({"body":str(node.name),"position":node.global_position,"shape_size":collision.shape.size,"mesh_size":visual.mesh.size})
	for child in node.get_children():audit_boxes(child)
func dense_stairs()->void:
	var count:=0;var misses:Array[Dictionary]=[]
	for node in world.get_children():
		var name:=String(node.name)
		if not (name.begins_with("Step_13_") or name.begins_with("final_arena_GalleryStairs") or name=="final_arena_GalleryDeck"):continue
		var shape:CollisionShape3D=node.get_node("Collision")
		var size:Vector3=shape.shape.size
		var across:=int(ceil(size.x/.1));var along:=int(ceil(size.z/.125))
		for ix in range(across+1):
			for iz in range(along+1):
				var point:Vector3=shape.to_global(Vector3(-size.x*.5+.02+(size.x-.04)*ix/across,size.y*.5,-size.z*.5+.02+(size.z-.04)*iz/along))
				var hit:Dictionary=ray(point,3);count+=1
				if hit.is_empty() or hit.position.y<point.y-.2:misses.append({"body":name,"point":point,"hit":hit.get("position",Vector3(0,-999,0))})
	scans.append({"area":"full C3/exit stair and gallery-deck footprints including corners","samples":count,"misses":misses.size(),"issues":misses})
	print("STAIR_FULL_FOOTPRINT samples=",count," gaps=",misses.size())
func run()->void:
	Engine.physics_ticks_per_second=60
	route=JSON.parse_string(FileAccess.get_file_as_string("res://resources/campaign/pale_ward_01-route.json"))
	world=load("res://scenes/campaign/pale_ward_01.tscn").instantiate();root.add_child(world);world.scan(world);world.set_physics_process(false)
	player=world.get_node("Player");player.set_physics_process(false)
	for node in world.get_children():
		if node.has_method("activate") and node.has_meta("stage_door") or node.has_meta("trap_entry") or node.has_meta("trap_shutter"):
			var flags:Dictionary={}
			for flag in node.get_meta("requires",[]):flags[String(flag)]=true
			node.activate(flags)
	for _tick in 110:await physics_frame
	audit_boxes(world)
	for index in route.portals.size():dense_portal(route.portals[index],index)
	dense_stairs()
	var output_name:="foundation-before-fix"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--receipt="):output_name=argument.trim_prefix("--receipt=")
	if "--probe-only" not in OS.get_cmdline_user_args():
		player.set_physics_process(true)
		for lane in ([] if "--gallery-edge-only" in OS.get_cmdline_user_args() else [-1.65,-1.1,-.55,0.0,.55,1.1,1.65]):
			if not await initial(Vector3(lane,2.37,-228.5)):break
			if not await walk_to(Vector3(lane,3,-240),"C3_exit_ascending_lane_"+str(lane)):break
			if not await walk_to(Vector3(lane,1.5,-228.5),"C3_exit_descending_lane_"+str(lane)):break
		if not falling:
			for sign in ([] if "--gallery-edge-only" in OS.get_cmdline_user_args() else [-1.0,1.0]):
				if not await initial(Vector3(sign*4,2.37,-228.5)):break
				if not await walk_to(Vector3(sign*1.55,2.5,-235),"C3_corner_approach_"+str(sign)):break
				if not await walk_to(Vector3(-sign*1.55,3,-240),"C3_diagonal_upper_landing_"+str(sign)):break
		if not falling:
			for offset in ([-1.45,1.45] if "--gallery-edge-only" in OS.get_cmdline_user_args() else [-1.45,-1.15,0.0,1.15,1.45]):
				if not await initial(Vector3(-7+offset,2.37,-192)):break
				if not await walk_to(Vector3(-7+offset,4,-205),"C3_gallery_stairs_lane_"+str(offset)):break
				if not await walk_to(Vector3(-7+offset,4,-215),"C3_gallery_deck_lane_"+str(offset)):break
				if not await walk_to(Vector3(-7+offset,1.5,-228),"C3_gallery_far_stairs_lane_"+str(offset)):break
	var file:=FileAccess.open("res://verification/map-safety-v5/"+output_name+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"scene":"pale_ward_01","scene_sha256":FileAccess.get_sha256("res://scenes/campaign/pale_ward_01.tscn"),"movement_sha256":FileAccess.get_sha256("res://scripts/grounded_step.gd"),"portals":scans,"walks":walks,"rendered_physical_box_mismatches":mismatches,"relevant_stair_geometry":step_samples,"fell_out":falling,"fixture":"Actual authored scene and current CharacterBody physics; AI never instantiated. Gates explicitly granted all flags and opened through real timelines. Independent supported initial lane placements; no mid-trial teleport recovery. Lift route19 belongs to separate worker. Grid125mm longitudinal/100mm lateral inside authored portal width,1m overlap each landing."},"  "));file.close()
	release();world.free();world=null;player=null;await process_frame
	print("EXIT_FLOOR_V5_DONE fallen=",falling," walks=",walks.size()," box_mismatches=",mismatches.size());quit(1 if falling else 0)
