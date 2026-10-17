extends "res://scripts/campaign_route_playtest.gd"
## Explicit --v13-route-test only. Shares the proven input/combat driver;
## Ward objectives and campaign acceptance never assume three arena clears.
var branch_order := "AB"
var requested_levels := 9
var ward_data: Dictionary = {}
var level_receipts: Array[Dictionary] = []
var lift_traversals_v13: Array[Dictionary] = []
var force_offscreen_v13 := false
var forced_draw_frames_v13 := 0
func _process(_delta: float) -> void:
	if force_offscreen_v13:
		RenderingServer.force_draw(false)
		forced_draw_frames_v13+=1
func configure_v13() -> void:
	if DisplayServer.get_name()!="headless":
		get_tree().root.set_flag(Window.FLAG_NO_FOCUS,true)
		get_tree().root.mode=Window.MODE_MINIMIZED
		force_offscreen_v13="--force-offscreen-draw" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--containment-order="):branch_order=arg.trim_prefix("--containment-order=")
		if arg.begins_with("--v13-level-count="):requested_levels=clampi(int(arg.trim_prefix("--v13-level-count=")),1,9)
		if arg.begins_with("--release-report-dir="):report_dir=arg.trim_prefix("--release-report-dir=").simplify_path()
	if report_dir.is_empty():report_dir=OS.get_user_data_dir().path_join("levels-v13-route")
	package_dir=(ProjectSettings.globalize_path("res://") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir()).simplify_path().trim_suffix("/")
	if not require(report_dir.is_absolute_path() and not report_dir.begins_with("res://") and report_dir.length()>1 and package_dir.is_absolute_path() and package_dir.length()>1 and report_dir!=package_dir and not report_dir.begins_with(package_dir+"/"),"Report directory must be absolute and outside the source/package directory"):
		report_dir=OS.get_user_data_dir().path_join("levels-v13-route")
	require(branch_order in ["AB","BA"],"Containment branch order must be AB or BA")
func run() -> void:
	configure_v13()
	if not failures.is_empty():await finish_v13();return
	if not require(app.campaign_mode and not app.campaign.current_level().is_empty(),"Actual Main campaign required"):
		await finish_v13();return
	var expected_carry := {}
	for index in requested_levels:
		world=app.world;player=app.player;combat=app.combat;level_id=String(app.campaign.current_level().id);stage_id=level_id
		route_path="res://resources/campaign/"+level_id+"-route.json"
		if not require(FileAccess.file_exists(route_path),"Actual route resource missing "+level_id):break
		route=JSON.parse_string(FileAccess.get_file_as_string(route_path))
		var is_ward := level_id.begins_with("pale_ward_")
		var is_ash_approach := level_id=="ash_citadel_01" and bool(route.get("design_v15",false))
		if is_ward:
			ward_data=route.get("design_v13",route)
			if not require(int(world.get_meta("design_version",0))==13 and world.objective_profile!=null,"Redesigned Ward scene/profile required "+level_id):break
		elif is_ash_approach:
			ward_data=route
			if not require(int(world.get_meta("design_version",0))==15 and world.objective_profile!=null,"Authored Ash Approach scene/profile required"):break
		var entry: Dictionary=app.campaign.entry_snapshot.duplicate(true)
		if index==0 and app.campaign.current_index==0:
			require(entry.health==100 and entry.armor==50 and entry.ammo_pistol==36 and entry.ammo_shotgun==12 and entry.ammo_rivets==0 and entry.ammo_rockets==0 and entry.owned_weapons.size()==3,"Normal campaign entry loadout; no test seed")
		elif not expected_carry.is_empty():
			for field in app.campaign.COMBAT_FIELDS:require(entry[field]==expected_carry[field],"Exact Continue carry "+field+" into "+level_id)
		if not failures.is_empty():break
		current_route_room=String(ward_data.get("spawn_room","")) if is_ward or is_ash_approach else "entry"
		records.clear();interactions.clear();weapon_shots.clear();weapon_kills.clear();arsenal_events.clear();lift_traversals_v13.clear();ticks=0;reset_ammo_ledger()
		combat.combat_event.connect(observe_weapon_event)
		if not app.started:app.enter_combat()
		await get_tree().physics_frame;global_start=Engine.get_physics_frames()
		if is_ward or is_ash_approach:
			if await collect_room_supplies(current_route_room):
				if is_ash_approach:await ash_approach_route()
				else:await ward_route()
		else:await super.route_run()
		var complete: bool=world.finished and app.level_complete and get_tree().paused
		require(complete,"Actual exit/menu completion "+level_id);require(not combat.dead and combat.health>0,"Live route survival "+level_id)
		require(not world.secret_found and world.secrets.is_empty(),"No secret supply "+level_id)
		if is_ward or is_ash_approach:
			for flag in world.objective_profile.exit_requires:require(bool(world.flags.get(flag,false)),"Authored objective exit precondition "+String(flag))
			if level_id=="pale_ward_03":
				for id in route.rooms:
					if not route.rooms[id].get("optional",false) and not route.rooms[id].get("secret",false):require(world.visited.has(id),"Breach first pass physically visits required district room "+String(id))
		else:
			for flag in ["breaker","power","brass_key","release","red_key","exit_control","exit"]:require(bool(world.flags.get(flag,false)),"Legacy progression "+flag)
			for arena in ["arena_one","arena_two","final_arena"]:require(int(world.arena_remaining.get(arena,-1))==0,"Legacy arena clear "+arena)
		var exit_state: Dictionary=app.campaign.capture(combat)
		level_receipts.append({"level":level_id,"scene":world.scene_file_path,"redesigned_ward":is_ward,"containment_order":branch_order if level_id=="pale_ward_02" else "","completed":complete,"entry_loadout":entry,"exit_loadout":exit_state,"health":combat.health,"armor":combat.armor,"kills":combat.kills,"total_enemies":combat.total_enemies,"shots":combat.shot_counter,"flags":world.flags.duplicate(),"arena_remaining":world.arena_remaining.duplicate(),"secret_used":world.secret_found,"peak_ammo":peak_ammo.duplicate(),"ammo_caps":ammo_caps(),"weapon_shots":weapon_shots.duplicate(),"weapon_kills":weapon_kills.duplicate(),"segments":records.duplicate(true),"interactions":interactions.duplicate(true),"physics_seconds":float(Engine.get_physics_frames()-global_start)/Engine.physics_ticks_per_second,"checkpoint_at_exit":app.has_checkpoint()})
		level_receipts.back().siege_self_hits=siege_self_hits
		level_receipts.back().authored_ash_approach=is_ash_approach
		level_receipts.back().lift_traversals=lift_traversals_v13.duplicate(true)
		level_receipts.back().lift_route_requested="--check-lift-route" in OS.get_cmdline_user_args()
		level_receipts.back().visited_rooms=world.visited.keys()
		level_receipts.back().accepted_ammo=accepted_ammo.duplicate()
		if not complete:level_receipts.back().failure_state=failure_state()
		if not failures.is_empty():break
		expected_carry=exit_state
		if index+1<requested_levels:
			var old_world: Node=world;app.enter_combat();await get_tree().process_frame
			if not require(app.world!=old_world and not get_tree().paused,"Continue builds next real world"):break
			require(not app.has_checkpoint(),"Continue clears previous level checkpoint")
	await finish_v13()
func authored_route() -> bool:
	return level_id.begins_with("pale_ward_") or level_id=="ash_citadel_01" and bool(route.get("design_v15",false))
func gate_available(portal: Dictionary) -> bool:
	if not authored_route():return super.gate_available(portal)
	if bool(portal.get("secret",false)):return false
	for flag in portal.get("requires",[]):
		if not world.flags.get(String(flag),false):return false
	return true
func collect_room_supplies(room_id: String) -> bool:
	var nodes: Array[Node3D]=[]
	for supply in route.get("supplies",[]):
		if String(supply.room)!=room_id:continue
		if not supply.has("node"):continue
		var pickup: Node3D=world.get_node_or_null(String(supply.node))
		if pickup!=null:nodes.append(pickup)
	if route.get("weapon") is Dictionary and String(route.weapon.get("room",""))==room_id:
		var weapon: Node3D=world.get_node_or_null(String(route.weapon.node))
		if weapon!=null:nodes.push_front(weapon)
	for pickup in nodes:
		if not pickup.visible:continue
		var kind: String=String(pickup.get_meta("stage_pickup",""))
		if kind=="health" and combat.health>=100:continue
		if kind=="armor" and combat.armor>=100:continue
		if kind in ["pistol","shells","rivets","rockets"] and combat.ammo_amount(StringName(kind))>=combat.ammo_capacity(StringName(kind)):continue
		if not await walk(pickup.global_position,"Physical main-route supply "+String(pickup.name)):return false
	return true
func path_to(destination: String) -> Array[String]:
	if not authored_route():return super.path_to(destination)
	var queue: Array[String]=[current_route_room];var previous := {current_route_room:""}
	while not queue.is_empty():
		var here: String=queue.pop_front()
		if here==destination:break
		for portal in route.portals:
			if not gate_available(portal):continue
			var next := String(portal.to) if String(portal.from)==here else String(portal.from) if String(portal.to)==here else ""
			if next.is_empty() or previous.has(next):continue
			if String(portal.get("first_open_from",""))!="" and here!=String(portal.first_open_from):
				var door: Node=world.get_node_or_null(String(portal.get("door","")))
				if door!=null and not door.opened:continue
			var room: Dictionary=route.rooms[next]
			if bool(room.get("secret",false)) or bool(room.get("optional",false)):continue
			previous[next]=here;queue.append(next)
	if not previous.has(destination):return []
	var result: Array[String]=[];var cursor := destination
	while cursor!=current_route_room:result.push_front(cursor);cursor=previous[cursor]
	return result
func connect_rooms(a: String,b: String) -> bool:
	if not authored_route():return await super.connect_rooms(a,b)
	var link := {}
	for portal in route.portals:
		if String(portal.from)==a and String(portal.to)==b or String(portal.from)==b and String(portal.to)==a:link=portal;break
	if not require(not link.is_empty(),"Authored v13 portal "+a+"→"+b):return false
	if bool(link.get("lift",false)):return await traverse_lift(link,a,b)
	# Runtime route contains physical floor samples in authored order. Never
	# synthesize a diagonal chord through rooms/walls or teleport over height.
	var points: Array=link.get("traverse_points",[]).duplicate(true)
	if not require(points.size()>=2,"Authored physical traverse_points missing "+a+"→"+b):return false
	if String(link.from)!=a:points.reverse()
	for point in points:
		var destination: Vector3=vector(point)
		var door_name: String=String(link.door) if link.get("door")!=null else ""
		var door: Node3D=world.get_node_or_null(door_name) if not door_name.is_empty() else null
		if door!=null and not door.is_open():
			var motion: Vector3=destination-player.global_position;motion.y=0
			var delta: Vector3=door.global_position-player.global_position;delta.y=0
			var ratio := clampf(delta.dot(motion)/maxf(motion.length_squared(),.001),0,1)
			if horizontal(player.global_position+motion*ratio,door.global_position)<2.0 and ratio>0 and ratio<1:
				var approach_point: Vector3=door.global_position-motion.normalized()*1.5;approach_point.y=destination.y
				if not await walk(approach_point,"Gate approach "+String(door.name)) or not await use(String(door.name)):return false
		if not await walk(destination,"Portal "+a+"→"+b):return false
	return await collect_room_supplies(b)
func traverse_lift(link: Dictionary,a: String,b: String) -> bool:
	var data: Dictionary=link.get("lift_data",{});var lift: Node3D=world.get_node_or_null(String(data.get("node","")))
	if not require(lift!=null,"Authored lift component "+a+"→"+b):return false
	var source_floor: float=route.rooms[a].center[1]
	var source_upper: bool=absf(source_floor-float(data.upper_floor))<absf(source_floor-float(data.lower_floor))
	var call: Vector3=Vector3(data.upper_call[0],source_floor+.87,data.upper_call[2]) if source_upper else Vector3(data.lower_call[0],source_floor+.87,data.lower_call[2])
	var points: Array=link.traverse_points.duplicate(true)
	if String(link.from)!=a:points.reverse()
	if not await walk(vector(points[0]),"Lift source room "+a) or not await walk(vector(points[1]),"Lift source landing "+a):return false
	if not await walk(call,"Lift external call "+a):return false
	if lift.upper!=source_upper:
		if not await use(String(lift.name)):return false
		for i in 600:
			if not lift.moving:break
			stop();await get_tree().physics_frame;ticks+=1
		if not require(not lift.moving and lift.upper==source_upper,"Lift arrives at source landing"):return false
	if not await walk(lift.global_position+Vector3.UP*1.02,"Board actual lift "+a):return false
	if not await use(String(lift.name)):return false
	for i in 600:
		if not lift.moving:break
		stop();await get_tree().physics_frame;ticks+=1
	if not require(not lift.moving and lift.upper!=source_upper,"Lift physically carries passenger to destination"):return false
	if not require(absf(player.global_position.y-(float(route.rooms[b].center[1])+.87))<.4,"Lift passenger reaches actual destination elevation"):return false
	lift_traversals_v13.append({"node":String(lift.name),"from":a,"to":b,"source_floor":source_floor,"destination_floor":float(route.rooms[b].center[1]),"actual_passenger_position":player.global_position,"actual_deck_position":lift.global_position,"input":"E","physics_tick":Engine.get_physics_frames()})
	if not await walk(vector(points[points.size()-2]),"Leave lift landing "+b):return false
	return await walk(vector(points.back()),"Lift destination room "+b)
func device(id: String,meta := "stage_button") -> Node3D:
	for node in world.mechanisms:
		if String(node.get_meta(meta,""))==id:return node
	return null
func approach(node: Node3D,room_id: String) -> bool:
	var center: Vector3=vector(route.rooms[room_id].center)
	if not await walk(center,"Control centre approach "+String(node.name)):return false
	var toward: Vector3=center-node.global_position;toward.y=0
	var point: Vector3=node.global_position+toward.normalized()*1.25;point.y=center.y
	return await walk(point,"Approach "+String(node.name))
func use_control(id: String,room_id: String) -> bool:
	if not await travel_to(room_id):return false
	var node := device(id)
	if not require(node!=null,"Authored objective control "+id):return false
	if not await approach(node,room_id):return false
	return await use(String(node.name))
func secure_checkpoint(id: String,room_id: String) -> bool:
	if not await travel_to(room_id):return false
	var marker: Node3D
	for node in world.checkpoint_markers:
		if String(node.get_meta("checkpoint_id"))==id:marker=node;break
	if not require(marker!=null,"Authored checkpoint "+id):return false
	if not await walk(marker.global_position,"Checkpoint approach "+id):return false
	stop()
	for i in 1200:
		if app.has_checkpoint() and String(app.campaign.checkpoint_snapshot.get("checkpoint_id",""))==id:
			interactions.append({"checkpoint":id,"accepted":true,"input":"stationary physical dwell","position":player.global_position,"world_safe":world.checkpoint_is_safe(),"ticks":i});return true
		# Combat movement is ordinary input, but a ranged target in the next
		# room must not cause perpetual strafing during an otherwise safe dwell.
		var nearby_threat:=false
		var threat_radius: float=world.objective_profile.checkpoint_options.get("threat_radius",10.0)
		for enemy in combat.enemies:
			if enemy.dead:continue
			var distance: float=enemy.global_position.distance_to(player.global_position)
			if distance<threat_radius or (enemy.awake and distance<maxf(threat_radius,enemy.definition.attack_range+2.0) and enemy.can_see_player()):nearby_threat=true;break
		if not nearby_threat and horizontal(player.global_position,marker.global_position)<.28:
			stop();await get_tree().physics_frame;ticks+=1
		else:await tick(marker.global_position,nearby_threat)
	interactions.append({"checkpoint":id,"accepted":false,"diagnostic":checkpoint_diagnostic(marker)})
	return require(false,"Safe actual checkpoint dwell did not complete "+id)
func checkpoint_diagnostic(marker: Node3D) -> Dictionary:
	var threats: Array[Dictionary]=[]
	for enemy in combat.enemies:
		if not is_instance_valid(enemy) or enemy.dead:continue
		var distance: float=enemy.global_position.distance_to(player.global_position)
		if distance<maxf(20,enemy.definition.attack_range+2):threats.append({"id":String(enemy.get_meta("stable_id","")),"position":enemy.global_position,"distance":distance,"awake":enemy.awake,"visible":enemy.can_see_player(),"state":String(enemy.state)})
	return {"position":player.global_position,"velocity":player.velocity,"grounded":player.is_on_floor(),"marker":marker.global_position,"marker_distance":player.global_position.distance_to(marker.global_position),"radius":marker.get_meta("radius"),"candidate":world.checkpoint_candidate,"dwell":world.checkpoint_dwell,"used":world.checkpoint_used.duplicate(),"safe":world.checkpoint_is_safe(),"threats":threats,"prompt":world.prompt}
func destroy_anchor(id: String,room_id: String) -> bool:
	if not await travel_to(room_id):return false
	var anchor := device(id,"completion_flag")
	if not require(anchor!=null and anchor.has_method("is_shootable_mechanism"),"Real shootable anchor "+id):return false
	if not await approach(anchor,room_id):return false
	stop()
	for i in 600:
		if bool(world.flags.get(id,false)):return true
		player.camera.look_at(anchor.global_position)
		if combat.currentweapon!=&"pistol":combat.select_weapon(&"pistol")
		else:combat.try_fire()
		await get_tree().physics_frame;ticks+=1
	return require(false,"Actual weapon rays did not destroy anchor "+id)
func ash_approach_route() -> void:
	# The credential and winch are physical interactions; the route never sets
	# progression flags or advances across the bridge by teleporting.
	if not await travel_to("lower_crypt"):return
	var credential: Node3D
	for pickup in world.pickups:
		if String(pickup.get_meta("stage_pickup","")) in ["brass","brass_key"]:
			credential=pickup;break
	if not require(credential!=null,"Actual gatehouse credential pickup"):return
	if not await walk(credential.global_position,"Acquire gatehouse credential"):return
	if not require(bool(world.flags.get("brass",false)),"Gatehouse credential flag from accepted pickup"):return
	if not await secure_checkpoint("crypt_credential","lower_crypt"):return
	if not await use_control("gate_winch","winch"):return
	if not require(bool(world.flags.get("gate_winch",false)),"Winch operated by real E input"):return
	var bridge: Node3D
	for node in world.get_children():
		if node is Node3D and bool(node.get_meta("ash_bridge",false)):
			bridge=node;break
	if not require(bridge!=null and bridge.has_method("is_open"),"Physical Ash bridge component"):return
	for i in 600:
		if bridge.is_open():break
		stop();await get_tree().physics_frame;ticks+=1
	if not require(bridge.is_open(),"Winch lowered physical bridge before crossing"):return
	if not await secure_checkpoint("bridge_winch","winch"):return
	if not await travel_to("furnace_gate"):return
	var exit_node: Node3D
	for node in world.mechanisms:
		if node.has_meta("stage_exit"):exit_node=node;break
	if not require(exit_node!=null,"Actual Ash furnace exit mechanism"):return
	if not await approach(exit_node,"furnace_gate"):return
	await use(String(exit_node.name))
func ward_route() -> void:
	match level_id:
		"pale_ward_01":
			if not await use_control("local_power","generator"):return
			if not await secure_checkpoint("power_return","reception"):return
			if not await travel_to("theatre"):return
			var credential: Node3D
			for pickup in world.pickups:
				if String(pickup.get_meta("stage_pickup","")) in ["brass","brass_key"]:credential=pickup;break
			if not require(credential!=null,"Actual surgical credential pickup"):return
			if not await walk(credential.global_position,"Acquire surgical credential"):return
			require(bool(world.flags.get("surgical_credential",false)),"Credential granted only after power")
			if not await secure_checkpoint("credential_return","sterile"):return
			if not await travel_to("decon"):return
			for i in 3600:
				if world.flags.get("decon_clear",false):break
				await tick(player.global_position,true)
			if not require(bool(world.flags.get("decon_clear",false)),"Real decon lockdown survived"):return
		"pale_ward_02":
			var sequence := ["isolation_a","isolation_b"] if branch_order=="AB" else ["isolation_b","isolation_a"]
			for id in sequence:
				if not await use_control(id,id):return
				if not await secure_checkpoint("culture_safe" if id=="isolation_a" else "waste_safe",id):return
			if not await travel_to("reservoir"):return
		"pale_ward_03":
			for id in ["anchor_a","anchor_b","anchor_c"]:
				if not await destroy_anchor(id,id):return
				if id!="anchor_c" and not await secure_checkpoint("upper_anchor_safe" if id=="anchor_a" else "middle_anchor_safe",id):return
	if not await travel_to("exit"):return
	var exit_node: Node3D
	for node in world.mechanisms:
		if node.has_meta("stage_exit"):exit_node=node;break
	if not require(exit_node!=null,"Real v13 exit mechanism"):return
	if not await approach(exit_node,"exit"):return
	await use(String(exit_node.name))
func finish_v13() -> void:
	stop();key(KEY_E,false)
	var completed := 0
	for receipt in level_receipts:
		if receipt.completed:completed+=1
	var report := {"status":"passed" if failures.is_empty() and completed==requested_levels else "failed","levels_completed":completed,"expected_levels":requested_levels,"containment_order":branch_order,"use_heavy_weapons":heavy_mode,"levels":level_receipts,"failures":failures,"executable":OS.get_executable_path(),"editor_feature":OS.has_feature("editor"),"engine_arguments":OS.get_cmdline_args(),"physics_ticks_per_second":Engine.physics_ticks_per_second,"source_package_dir":package_dir,"scope":"Opt-in actual Main physical CharacterBody movement, live enemies/damage/finite ammo, real weapon rays and E-use. Three Ward objective contracts, authored Ash Approach bridge objective, and five unchanged legacy maps. Exact Continue carry, no seed/teleport/death/flag injection or secret supplies. Bot simulation timings do not establish human pacing."}
	report.user_arguments=OS.get_cmdline_user_args()
	report.capture_policy={"native":DisplayServer.get_name()!="headless","no_focus":get_tree().root.get_flag(Window.FLAG_NO_FOCUS),"minimized":get_tree().root.mode==Window.MODE_MINIMIZED,"force_offscreen_requested":force_offscreen_v13,"forced_draw_frames":forced_draw_frames_v13}
	DirAccess.make_dir_recursive_absolute(report_dir)
	FileAccess.open(report_dir.path_join("v13-route.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("LEVELS_V13_ROUTE ",report.status," ",completed,"/",requested_levels," ",failures)
	app.combat_audio.stop_all();app.menu_music.stop();app.menu_music.stream=null
	# Fixed simulation time can outrun the audio mixer. Give stopped OGG
	# playbacks actual wall time to retire, as the legacy route harness does.
	var stop_at: int=Time.get_ticks_msec()
	while Time.get_ticks_msec()-stop_at<300:await get_tree().process_frame
	var stopped_wall_ms: int=Time.get_ticks_msec()-stop_at
	# This opt-in driver is a Main child. Retain only the driver while freeing
	# actual Main so its audio/resources and paused queued nodes drain normally.
	var tree: SceneTree=get_tree()
	reparent(tree.root)
	app.combat.gore.reset()
	world=null;player=null;combat=null
	app.queue_free();app=null;tree.paused=false
	for i in 4:await tree.physics_frame
	preload("res://scripts/sprite_hurt_geometry.gd").frame_cache.clear()
	preload("res://scripts/sprite_hurt_geometry.gd").image_cache.clear()
	var free_at: int=Time.get_ticks_msec()
	while Time.get_ticks_msec()-free_at<250:await tree.process_frame
	report.teardown={"complete":true,"stopped_audio_wall_ms":stopped_wall_ms,"freed_main_drain_wall_ms":Time.get_ticks_msec()-free_at,"gameplay_changed":false}
	FileAccess.open(report_dir.path_join("v13-route.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("LEVELS_V13_TEARDOWN ",JSON.stringify(report.teardown))
	get_tree().quit(0 if report.status=="passed" else 1)
