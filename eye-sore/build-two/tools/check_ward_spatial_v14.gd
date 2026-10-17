extends SceneTree
## Controlled actual Main physics fixture. Temporary endpoint receivers and
## emitter/player poses isolate construction; live full routes remain separate.
var expected: Dictionary
var spec: Dictionary
var physics_minima: Dictionary={}
var messages: Array[String]=[]
var level_id := "pale_ward_01"
var report_path := ""
var app: Control
var failures: Array[String]=[]
var checks: Array[Dictionary]=[]
var events: Array[Dictionary]=[]
var observations: Array[Dictionary]=[]
var route: Dictionary
var shot_id := 810000
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--expected="):expected=JSON.parse_string(FileAccess.get_file_as_string(arg.trim_prefix("--expected=")))
		if arg.begins_with("--level="):level_id=arg.trim_prefix("--level=")
		if arg.begins_with("--report="):report_path=arg.trim_prefix("--report=")
	call_deferred("run")
func v(a: Array) -> Vector3:return Vector3(a[0],a[1],a[2])
func check(ok: bool,label: String,detail: Dictionary={}) -> void:
	checks.append({"passed":ok,"check":label,"detail":detail})
	if not ok:failures.append(label);push_error("WARD_SPATIAL_V14 "+label+" "+JSON.stringify(detail))
func frames(n: int) -> void:
	for i in n:await physics_frame
func key(code: int,down: bool) -> void:
	var event:=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=down;Input.parse_input_event(event)
func stop() -> void:
	for code in [KEY_W,KEY_A,KEY_S,KEY_D,KEY_CTRL,KEY_SHIFT]:key(code,false)
func freeze_actors() -> void:
	for actor in app.combat.enemies:actor.set_physics_process(false)
func isolate_actors() -> void:
	for actor in app.combat.enemies:
		actor.collision_layer=0
		for body in actor.hurt_shapes:body.collision_layer=0
		for body in actor.corpse_shapes:body.collision_layer=0
func pose_player(floor_at: Vector3) -> void:
	stop();app.player.set_physics_process(false);app.player._set_crouching(false)
	app.player.global_position=floor_at+Vector3.UP*.87;app.player.velocity=Vector3.ZERO
	app.player.set_movement_active(true);app.player.set_physics_process(true)
	await frames(12)
func walk(at: Vector3,label: String,crouch:=false,limit:=360) -> bool:
	var start: Vector3=app.player.global_position
	for i in limit:
		var motion: Vector3=at-app.player.global_position;motion.y=0
		if motion.length()<.2:
			stop();await frames(6)
			check(absf(app.player.global_position.y-(at.y+(.55 if crouch else .85)))<.22,label+" arrives at supported elevation",{"actual":app.player.global_position,"floor":at,"crouch":crouch})
			return true
		app.player.rotation.y=atan2(-motion.x,-motion.z);key(KEY_CTRL,crouch);key(KEY_W,true)
		await physics_frame
	stop();check(false,label+" physical traversal stalled",{"start":start,"target":at,"actual":app.player.global_position,"velocity":app.player.velocity,"grounded":app.player.is_on_floor()});return false
func receiver(at: Vector3) -> StaticBody3D:
	var body:=StaticBody3D.new();body.name="TemporaryContactReceiver";body.collision_layer=1;body.collision_mask=0
	var node:=CollisionShape3D.new();var shape:=SphereShape3D.new();shape.radius=.25;node.shape=shape;body.add_child(node)
	app.world.add_child(body);body.global_position=at;return body
func prepare_emitter(at: Vector3,toward: Vector3) -> void:
	stop();app.player.set_physics_process(false);app.player.global_position=at-Vector3.UP*.68;app.player.camera.position=Vector3(0,.68,0);app.player.camera.look_at(toward)
	await frames(2)
func contacts(a: Vector3,b: Vector3,clear: bool,label: String) -> void:
	# Natural attack probes can leave accepted rounds in flight. Retire those
	# only at the controlled case boundary, before observing a fresh projectile.
	for child in app.combat.get_children():
		if child.has_method("is_combat_projectile"):child.queue_free()
	await frames(2)
	# Existing actors are query-disabled only during this wall/aperture probe.
	# The temporary receiver supplies a real physical endpoint beyond the cut.
	isolate_actors()
	var endpoint:=receiver(b);await frames(2)
	await prepare_emitter(a,b)
	var ray: Dictionary=app.combat.ray(a,b+(b-a).normalized()*.3,[app.player.get_rid()],true)
	check(not ray.is_empty() and (ray.collider==endpoint)==clear,label+" actual geometry ray",{"clear_expected":clear,"collider":str(ray.get("collider")),"position":ray.get("position")})
	for i in 120:
		if app.combat.cooldown<=0 and app.combat.weapon_phase==&"idle":break
		await physics_frame
	app.combat.select_weapon(&"pistol");await frames(2)
	events.clear();var ammo: int=app.combat.ammo_pistol
	var fired: bool=app.combat.try_fire();var accepted: int=app.combat.shot_counter
	check(fired and app.combat.ammo_pistol==ammo-1,label+" accepted actual pistol consumes exactly one round")
	var impacts: Array[Dictionary]=[]
	for event in events:
		if String(event.type)=="impact" and int(event.shot_id)==accepted:impacts.append(event)
	check(impacts.size()==1 and (String(impacts[0].target_id)==str(endpoint.get_instance_id()))==clear,label+" authoritative pistol contact",{"impacts":impacts})
	# Actual production swept enemy projectile, including its .12m shape.
	var owner: CharacterBody3D
	for actor in app.combat.enemies:
		if actor.definition.ranged:owner=actor;break
	check(owner!=null,label+" actual ranged emitter exists")
	if owner!=null:
		app.player.global_position=Vector3(200,200,200);await frames(2);events.clear()
		var projectile: Node3D=app.combat.launch_projectile(owner,a,(b-a).normalized())
		for i in 300:
			if not is_instance_valid(projectile) or projectile.resolved:break
			await physics_frame
		var hits: Array[Dictionary]=[]
		for event in events:
			if String(event.type)=="projectile_impact":hits.append(event)
		check(hits.size()==1 and ((hits[0].position as Vector3).distance_to(b)<.55)==clear,label+" actual swept enemy projectile contact",{"hits":hits})
	# Actual production swept player ordnance, launched as an explicitly
	# controlled geometric probe; this is not an accepted-ammo/cadence claim.
	events.clear();shot_id+=1
	var ordnance: Node3D=app.combat.launch_player_ordnance(app.combat.weapons[&"siege_launcher"],a,(b-a).normalized(),shot_id)
	for i in 300:
		if not is_instance_valid(ordnance) or ordnance.resolved:break
		await physics_frame
	var explosions: Array[Dictionary]=[]
	for event in events:
		if String(event.type)=="ordnance_explosion" and int(event.shot_id)==shot_id:explosions.append(event)
	check(explosions.size()==1 and ((explosions[0].position as Vector3).distance_to(b)<.6)==clear,label+" actual swept player ordnance contact",{"explosions":explosions})
	endpoint.queue_free();await frames(2)
func paths(connection: Dictionary) -> void:
	for path in connection.get("walk_paths",[]):
		for reverse in [false,true] if path.get("reverse",false) else [false]:
			var points: Array=path.points.duplicate(true)
			if reverse:points.reverse()
			await pose_player(v(points[0]))
			for point in points.slice(1):
				if not await walk(v(point),String(path.id)+(" reverse" if reverse else " forward")):break
func shutter_states(connection: Dictionary,original: Dictionary) -> void:
	var liquid: Node3D=app.world.get_node("ReservoirLiquid")
	var pair: Dictionary=connection.shot_pairs[0]
	for flags in [[],["isolation_a"],["isolation_b"],["isolation_a","isolation_b"]]:
		app.world.restore_checkpoint_state(original);freeze_actors()
		for flag in flags:app.world.flags[flag]=true
		app.world.refresh_objective()
		var both: bool=flags.size()==2
		check(liquid.is_drained()==both and is_equal_approx(liquid.position.y,liquid.low_y if both else liquid.high_y),"Actual derived basin surface "+str(flags),{"height":liquid.position.y})
		for spec in connection.shutters:
			var shutter: Node3D=app.world.get_node(String(spec.id))
			check(shutter.opened==both,"Actual automatic shutter requires both feeds "+String(spec.id)+str(flags))
			await pose_player(Vector3(float(spec.position[0]),4,-25.4))
			check(app.world.nearest_mechanism()!=shutter,"No E candidate bypass for automatic shutter "+String(spec.id)+str(flags))
		if not both:
			await pose_player(v(pair.b)-Vector3.UP*1.17)
			var basin_actor: CharacterBody3D
			for candidate in app.combat.enemies:
				if String(candidate.target_id)==String(connection.actor_overrides[0].stable_id):basin_actor=candidate;break
			check(basin_actor!=null and not basin_actor.can_see_player(),"Closed real shutter blocks basin enemy LOS "+str(flags))
			if basin_actor!=null:
				events.clear();basin_actor.set_physics_process(true);await frames(90);basin_actor.set_physics_process(false)
				var releases:=0
				for event in events:
					if String(event.type) in ["projectile_release","enemy_weapon_release"] and String(event.target_id)==String(basin_actor.target_id):releases+=1
				check(releases==0,"No early basin attacks through closed shutter "+str(flags),{"releases":releases})
		if both:
			paused=true;var before: Vector3=app.world.get_node(String(connection.shutters[0].id)).position
			await frames(12)
			check(app.world.get_node(String(connection.shutters[0].id)).position==before,"Actual automatic shutter motion freezes while paused")
			paused=false;await frames(100)
			for spec in connection.shutters:check(app.world.get_node(String(spec.id)).is_open(),"Actual full shutter travel completes "+String(spec.id))
		await contacts(v(pair.a),v(pair.b),both,"Shutter state "+str(flags)+" basin→balcony")
		if both:await contacts(v(pair.b),v(pair.a),true,"Open shutter balcony→basin")
	# A physically captured open pose and a closed pose must each restore with
	# their corresponding derived liquid BEFORE any unpaused physics frame.
	var opened: Dictionary=app.world.capture_checkpoint_state()
	check(app.world.restore_checkpoint_state(original),"Actual closed shutter checkpoint restore accepted")
	check(not liquid.is_drained() and is_equal_approx(liquid.position.y,liquid.high_y),"Closed restore synchronously refills basin")
	for spec in connection.shutters:check(app.world.get_node(String(spec.id)).is_closed(),"Closed restore real shutter collision pose "+String(spec.id))
	check(app.world.restore_checkpoint_state(opened),"Actual open shutter checkpoint restore accepted")
	check(liquid.is_drained(),"Open restore synchronously drains basin")
	for spec in connection.shutters:check(app.world.get_node(String(spec.id)).is_open(),"Open restore real shutter collision pose "+String(spec.id))
	await parapet_attempts(connection)
func parapet_attempts(_connection: Dictionary) -> void:
	isolate_actors()
	# Representative slot-centre and diagonal attempts on BOTH real balconies.
	# The only blocks here are visible actual base/posts, with shutters open.
	for x in [-5.25,5.25]:
		for crouch in [false,true]:
			for diagonal in [-1.0,0.0,1.0]:
				await pose_player(Vector3(x,4,-24.7))
				var destination:=Vector3(x+diagonal*1.5,4,-29)
				for i in 90:
					var motion: Vector3=destination-app.player.global_position;motion.y=0
					app.player.rotation.y=atan2(-motion.x,-motion.z);key(KEY_CTRL,crouch);key(KEY_W,true);await physics_frame
				check(app.player.global_position.z>-26 and app.player.global_position.y>4.45,"Actual parapet resists "+str(x)+" crouch="+str(crouch)+" diagonal="+str(diagonal),{"position":app.player.global_position,"crouch":app.player.is_crouching,"grounded":app.player.is_on_floor()})
				stop()
func actor_angle(connection: Dictionary) -> void:
	for override in connection.get("actor_overrides",[]):
		var actor: CharacterBody3D
		for candidate in app.combat.enemies:
			if String(candidate.target_id)==String(override.stable_id):actor=candidate;break
		check(actor!=null,"Exact existing moved actor stable ID "+String(override.stable_id))
		if actor==null:continue
		check(actor.global_position.distance_to(v(override.position))<.15,"Authored moved actor position "+String(actor.target_id),{"actual":actor.global_position,"expected":override.position})
		var pair: Dictionary=connection.shot_pairs[0]
		var to: Vector3=v(pair.b)
		await pose_player(to-Vector3.UP*1.17)
		check(actor.can_see_player(),"Actual elevated actor sees cross-area player "+String(actor.target_id),{"actor":actor.global_position,"player":app.player.global_position})
		var distance: float=Vector2(actor.global_position.x-app.player.global_position.x,actor.global_position.z-app.player.global_position.z).length()
		check(distance<=actor.definition.attack_range,"Cross-area stance is inside actual attack range "+String(actor.target_id),{"distance":distance,"range":actor.definition.attack_range})
		events.clear();actor.set_physics_process(true)
		await frames(180);actor.set_physics_process(false)
		var releases:=0
		var contacts_received:=0
		for event in events:
			if String(event.type) in ["projectile_release","enemy_weapon_release"] and String(event.target_id)==String(actor.target_id):releases+=1
			if String(event.type)=="player_hurt" and String(event.get("source_id",""))==String(actor.target_id):contacts_received+=1
		check(releases>0,"Natural actual actor emits attack across new opening "+String(actor.target_id),{"releases":releases,"state":actor.state,"awake":actor.awake})
		check(contacts_received>0,"Actual natural cross-area attack reaches player "+String(actor.target_id),{"player_contacts":contacts_received})
func descendants(node: Node) -> Array[Node]:
	var result: Array[Node]=[]
	for child in node.get_children():result.append(child);result.append_array(descendants(child))
	return result
func stable(id: String) -> Node3D:
	for node in descendants(app.world):
		if String(node.get_meta("stable_id",""))==id:return node as Node3D
	return null
func polygon(points: Array) -> PackedVector2Array:
	var result:=PackedVector2Array()
	for p in points:result.append(Vector2(p[0],p[1]))
	return result
func edge_distance(point: Vector2,poly: PackedVector2Array) -> float:
	var distance:=INF
	for i in poly.size():distance=minf(distance,point.distance_to(Geometry2D.get_closest_point_to_segment(point,poly[i],poly[(i+1)%poly.size()])))
	return distance
func physical_ray(a: Vector3,b: Vector3) -> Dictionary:
	var query:=PhysicsRayQueryParameters3D.create(a,b,1)
	return app.world.get_world_3d().direct_space_state.intersect_ray(query)
func mesh_closed(mesh: Mesh) -> bool:
	var vertices:=mesh.get_faces();var edges: Dictionary={};var volume:=0.0
	for i in range(0,vertices.size(),3):
		volume+=vertices[i].dot(vertices[i+1].cross(vertices[i+2]))/6.0
		for j in 3:
			var a: String=str(vertices[i+j].snapped(Vector3.ONE*.00001));var b: String=str(vertices[i+(j+1)%3].snapped(Vector3.ONE*.00001))
			var edge: String=a+"|"+b if a<b else b+"|"+a;edges[edge]=int(edges.get(edge,0))+1
	if vertices.is_empty() or absf(volume)<.00001:return false
	for count in edges.values():
		if count!=2:return false
	return true
func footprints() -> void:
	isolate_actors();app.player.set_physics_process(false);app.player.global_position=Vector3(200,200,200);await frames(2)
	for outline in spec.outlines:
		var room_id: String=String(outline.room);var data: Dictionary=route.rooms[room_id];var center: Vector3=v(data.center);var poly:=polygon(outline.outline_xz)
		var marker: Node3D=app.world.get_node("Room_"+room_id)
		check(marker.get_meta("footprint_xz",PackedVector2Array())==poly,"Actual room exposes exact local footprint "+room_id)
		var inside_count:=0;var outside_count:=0;var floors: Dictionary={};var mismatches: Array[Dictionary]=[]
		var sx: float=float(data.size[0])*.5;var sz: float=float(data.size[2])*.5
		for grid_x in range(int(-sx*2)+1,int(sx*2)):
			for grid_z in range(int(-sz*2)+1,int(sz*2)):
				var x: float=float(grid_x)*.5;var z: float=float(grid_z)*.5
				var point:=Vector2(x,z)
				if edge_distance(point,poly)<.65:continue
				var inside: bool=Geometry2D.is_point_in_polygon(point,poly);var at:=center+Vector3(x,.87,z)
				var detected: String=app.world.room_at(at)
				var hit:=physical_ray(center+Vector3(x,.08,z),center+Vector3(x,-.8,z))
				var supported: bool=not hit.is_empty() and hit.normal.y>.99 and absf(float(hit.position.y)-center.y)<.06
				if inside:
					inside_count+=1
					if detected!=room_id or not supported:mismatches.append({"point":point,"inside":true,"room":detected,"hit":str(hit.get("collider"))})
					if supported:floors[hit.collider.get_instance_id()]=hit.collider
				else:
					outside_count+=1
					if detected==room_id or supported:mismatches.append({"point":point,"inside":false,"room":detected,"hit":str(hit.get("collider"))})
		check(inside_count>20 and outside_count>0,"Footprint has independently sampled usable inside and excluded corner "+room_id,{"inside":inside_count,"excluded":outside_count})
		check(mismatches.is_empty(),"Actual room detection AND floor collision follow concave/angled boundary "+room_id,{"mismatches":mismatches.slice(0,12),"total":mismatches.size()})
		for floor_node in floors.values():
			var meshes:=0
			for child in descendants(floor_node):
				if child is MeshInstance3D and child.mesh!=null:meshes+=1;check(mesh_closed(child.mesh),"Actual sampled floor cell mesh is closed "+String(floor_node.name))
			check(meshes>0,"Floor collider has native visible mesh "+String(floor_node.name))
		var fitting_failures: Array[String]=[];var fitting_meshes:=0
		for node in descendants(app.world):
			var prop_id: String=String(node.get_meta("room_program_object",""))
			if not prop_id.begins_with(level_id+"."+room_id+"."):continue
			for child in descendants(node):
				if not child is MeshInstance3D or child.mesh==null:continue
				fitting_meshes+=1;var bounds: AABB=child.get_aabb()
				for i in 8:
					var p: Vector3=child.global_transform*bounds.get_endpoint(i)-center;var p2:=Vector2(p.x,p.z)
					if not Geometry2D.is_point_in_polygon(p2,poly) and edge_distance(p2,poly)>.08:fitting_failures.append(prop_id+":"+str(p2))
		check(fitting_meshes>0 and fitting_failures.is_empty(),"Complete actual fitting mesh bounds inside authored footprint "+room_id,{"meshes":fitting_meshes,"failures":fitting_failures.slice(0,12)})
		var bad_points: Array[String]=[]
		for kind in ["enemy_spawns","supplies","checkpoints","keys","anchors","controls"]:
			for item in route.get(kind,[]):
				if String(item.get("room",""))!=room_id or not item.has("position"):continue
				var local: Vector3=v(item.position)-center;var point2:=Vector2(local.x,local.z)
				if not Geometry2D.is_point_in_polygon(point2,poly) and edge_distance(point2,poly)>.05:bad_points.append(kind+":"+str(item.get("id",item.get("stable_id",item.get("node","")))))
		check(bad_points.is_empty(),"All authored actor/supply/control/anchor/checkpoint positions fit actual footprint "+room_id,{"outside":bad_points})
		observations.append({"level":level_id,"room":room_id,"inside_samples":inside_count,"excluded_samples":outside_count,"floor_cells":floors.size(),"fitting_meshes":fitting_meshes})
		# Physical movement on actual floor cells: all four cardinal mouths and
		# the authored centre remain linked; full campaign traversal is separate.
		for direction in [Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK]:
			await pose_player(center)
			var radius: float=minf(sx,sz)-3.0
			var destination: Vector3=center+direction*radius
			if Geometry2D.is_point_in_polygon(Vector2(destination.x-center.x,destination.z-center.z),poly):await walk(destination,"Actual shaped room centre lane "+room_id+str(direction),false,240)
func reward_events(id: String) -> int:
	var count:=0
	for event in events:
		if String(event.type)=="item_collected" and String(event.get("pickup_id",""))==id:count+=1
	return count
func controlled_restore(snapshot: Dictionary,label: String) -> void:
	var staging: Vector3=v(route.rooms[String(route.spawn_room)].center)
	for portal in route.portals:
		if String(portal.to)==String(spec.optional_reserve.room) and String(portal.from)==String(route.spawn_room):staging=v(portal.middle);break
	await pose_player(staging)
	events.clear();var was_paused: bool=paused;paused=true
	check(app.world.restore_checkpoint_state(snapshot),label+" actual world snapshot accepted");freeze_actors()
	var door:=stable(String(spec.optional_reserve.release_door_stable_id))
	var immediate: Vector3=door.position;var sync: bool=door.sync_to_physics
	paused=was_paused;await frames(2)
	observations.append({"restore_probe":label,"door_immediate":immediate,"door_after_two_physics":door.position,"sync":sync,"saved":snapshot.mechanisms[String(spec.optional_reserve.release_door_stable_id)]})
	check(reward_events(String(spec.optional_reserve.reward_stable_id))==0,label+" restore emits no reward event")
func optional_states() -> void:
	var reserve: Dictionary=spec.optional_reserve;var group: String=String(reserve.arena_id);var id: String=String(reserve.reward_stable_id)
	var original: Dictionary=app.world.capture_checkpoint_state();var reward:=stable(id);var door:=stable(String(reserve.release_door_stable_id))
	check(reward!=null and door!=null,"Actual reserve stable reward and physical release door "+level_id)
	if reward==null or door==null:return
	check(reward.get_meta("stage_pickup")=="shells" and int(reward.get_meta("amount",0))==12,"Exact unchanged twelve-shell reward")
	check(not app.world.arena_active.has(group) and door.is_closed(),"Declined reserve stays inactive/closed")
	check(app.world.is_pickup_release_door(door),"Reserve release door excluded from ordinary E path")
	var released:=0
	for actor in app.combat.enemies:
		if String(actor.get_meta("arena_id",""))==group:released+=1;check(not actor.awake,"Unaccepted reserve actor asleep "+String(actor.target_id))
	check(released==2,"Exactly two existing reserve actors")
	# A similarly named physical pickup does not own this encounter. This is
	# controlled identity probing, using the actual collect mutation/API.
	var dummy:=Node3D.new();dummy.set_meta("stable_id",id+"_unmatched");dummy.set_meta("stage_pickup","shells");dummy.set_meta("amount",1);app.world.add_child(dummy)
	app.combat.ammo_shotgun=20;app.world.collect(dummy)
	check(not app.world.arena_active.has(group) and door.is_closed(),"Similar unmatched stable pickup ID cannot release reserve")
	app.world.collected.erase(String(dummy.get_meta("stable_id")))
	var encounter: Dictionary={}
	for entry in app.world.objective_profile.encounters.values():
		if String(entry.get("arena_id",""))==group:encounter=entry;break
	var saved_requires: Array=encounter.get("requires",[]).duplicate()
	encounter.requires=["fixture_unmet_requirement"];events.clear();app.combat.ammo_shotgun=20;app.world.collect(reward)
	check(app.combat.ammo_shotgun==20 and reward.visible and not app.world.arena_active.has(group) and reward_events(id)==0,"Controlled unmet encounter requirement blocks only matching reward before mutation")
	app.world.collect(dummy)
	check(app.combat.ammo_shotgun==21 and not app.world.arena_active.has(group),"Controlled unmatched ordinary supply unaffected by encounter requirement")
	app.world.collected.erase(String(dummy.get_meta("stable_id")));encounter.requires=saved_requires
	dummy.queue_free();await frames(2)
	app.player.set_physics_process(false);app.player.global_position=reward.global_position+Vector3(0,0,2);app.combat.ammo_shotgun=40;events.clear()
	await frames(30)
	check(not app.world.arena_active.has(group) and reward.visible and not app.world.collected.has(id),"Declining nearby optional reward never activates")
	app.world.collect(reward);await frames(2)
	check(app.combat.ammo_shotgun==40 and reward.visible and not app.world.collected.has(id) and not app.world.arena_active.has(group) and reward_events(id)==0 and door.is_closed(),"Full unaccepted shells never collect/release/emit")
	app.combat.ammo_shotgun=39;events.clear();app.world.collect(reward);await frames(2)
	check(app.combat.ammo_shotgun==40 and app.world.collected.has(id) and not reward.visible and app.world.arena_active.get(group,false) and reward_events(id)==1 and door.opened,"Partially accepted reserve releases exactly once with actual accepted amount")
	for event in events:
		if String(event.type)=="item_collected" and String(event.get("pickup_id",""))==id:check(int(event.amount)==1,"Saturated partial reward receipt reports one accepted shell")
	var accepted: Dictionary=app.world.capture_checkpoint_state();events.clear();app.world.collect(reward);await frames(2)
	check(reward_events(id)==0 and app.combat.ammo_shotgun==40,"Repeated collected reward emits no duplicate")
	await controlled_restore(original,"Pre-acceptance")
	check(reward.visible and not app.world.arena_active.has(group) and door.is_closed(),"Pre-acceptance restore retains available reward/closed group",{"visible":reward.visible,"active":app.world.arena_active.get(group,false),"opened":door.opened,"position":door.position,"origin":door.origin})
	await controlled_restore(accepted,"Post-acceptance")
	check(not reward.visible and app.world.arena_active.get(group,false) and door.opened,"Post-acceptance restore retains consumed reward/open group")
	await controlled_restore(original,"Same-frame health plus shells setup")
	reward=stable(id);app.combat.health=75;app.combat.ammo_shotgun=20;messages.clear();events.clear()
	# Both authored nearby items are processed by the real update_player batch.
	app.player.global_position=reward.global_position;app.world.update_player(app.player,app.combat)
	check(reward_events(id)==1 and app.combat.health>75 and not messages.is_empty() and messages.back()==String(reserve.message),"Nearby health and reserve accepted in same update retain authored warning",{"messages":messages,"health":app.combat.health})
	# Snapshot capture here is deliberately controlled, not a claim of safe
	# physical marker acquisition. Continue below is the actual Main API.
	var checkpoint: Node3D=app.world.checkpoint_markers[0]
	for snapshot in [original,accepted]:
		await controlled_restore(snapshot,"Before controlled campaign capture")
		await frames(100)
		var safe: bool=app.world.checkpoint_is_safe()
		var captured: bool=app.campaign.capture_checkpoint(app.world,app.combat,app.player,String(checkpoint.get_meta("checkpoint_id")))
		check(safe and captured,"Controlled supported entry pose passes actual unchanged checkpoint safety/capture",{"safe":safe,"captured":captured,"position":app.player.global_position})
		events.clear();app.continue_from_checkpoint();freeze_actors();await frames(3)
		reward=stable(id);door=stable(String(reserve.release_door_stable_id))
		var was_accepted: bool=snapshot.collected.has(id)
		check(app.has_checkpoint() and reward.visible!=was_accepted and bool(app.world.arena_active.get(group,false))==was_accepted and door.opened==was_accepted,"Actual Main Continue preserves optional consumed/group/door state "+str(was_accepted))
		check(reward_events(id)==0,"Actual Main Continue never replays reward")
		checkpoint=app.world.checkpoint_markers[0]
	app.restart_level();freeze_actors();await frames(3);events.clear()
	reward=stable(id);door=stable(String(reserve.release_door_stable_id))
	check(not app.has_checkpoint() and reward.visible and not app.world.arena_active.has(group) and door.is_closed(),"Actual Main Restart restores optional reward/closed group and clears checkpoint")
func aim_at_actor(actor: CharacterBody3D) -> Vector3:
	var center: Vector3=actor.global_position+Vector3.UP*.28
	var nearest:=INF;var answer:=center
	for body in actor.sprite_bodies.values():
		if body.collision_layer&4==0:continue
		var node: CollisionShape3D=body.get_node_or_null("HitSurface")
		if node==null or not node.shape is ConcavePolygonShape3D:continue
		var faces: PackedVector3Array=node.shape.get_faces()
		for i in range(0,faces.size(),3):
			var point: Vector3=body.to_global((faces[i]+faces[i+1]+faces[i+2])/3.0)
			var hit: Dictionary=app.combat.ray(app.player.camera.global_position,point+(point-app.player.camera.global_position).normalized()*.2,app.combat.anatomical_exclusions(),true)
			if hit.is_empty():continue
			var collider: Object=hit.collider
			if collider!=actor and (not collider.has_meta("combat_target") or collider.get_meta("combat_target")!=actor):continue
			var distance: float=center.distance_squared_to(point)
			if distance<nearest:nearest=distance;answer=point
	return answer
func can_hit(actor: CharacterBody3D,point: Vector3) -> bool:
	var origin: Vector3=app.player.camera.global_position
	var hit: Dictionary=app.combat.ray(origin,point+(point-origin).normalized()*.3,app.combat.anatomical_exclusions(),true)
	return not hit.is_empty() and (hit.collider==actor or (hit.collider.has_meta("combat_target") and hit.collider.get_meta("combat_target")==actor))
func optional_live() -> void:
	# Fresh world, normal campaign entry inventory. Only unrelated actors are
	# frozen; reserve actors keep authored transforms/health/collision and AI.
	var reserve: Dictionary=spec.optional_reserve;var id: String=String(reserve.reward_stable_id);var group: String=String(reserve.arena_id)
	var actors: Array[CharacterBody3D]=[]
	for actor in app.combat.enemies:
		if String(actor.get_meta("arena_id",""))==group:actors.append(actor);actor.set_physics_process(true)
	check(actors.size()==2,"Live optional encounter contains two authored actors")
	var link: Dictionary={}
	for portal in route.portals:
		if String(portal.to)==String(reserve.room) and String(portal.from)==String(route.spawn_room):link=portal;break
	check(not link.is_empty(),"Optional reserve physically accessible from unchanged entry graph")
	if link.is_empty():return
	var points: Array=link.traverse_points
	# Frozen unrelated actors retain their real bodies. In Breach one occupies
	# the exact abstract room centre; use a supported offset before the mouth
	# instead of demanding the live player occupy that actor's capsule.
	var staging: Vector3=v(points[0])+Vector3(0,0,2.5)
	if not await walk(staging,"Live entry approach beside occupied room centre",false,240):return
	for p in points.slice(1):
		if not await walk(v(p),"Live unaccepted optional approach",false,480):return
	var reward:=stable(id);var door:=stable(String(reserve.release_door_stable_id));events.clear()
	check(reward.visible and not app.world.arena_active.has(group) and door.is_closed(),"Physical optional entry/decline does not activate reward group")
	var before: int=app.combat.ammo_shotgun;var reward_floor: Vector3=reward.global_position;reward_floor.y=float(reserve.floor)
	if not await walk(reward_floor,"Live actual reserve proximity pickup",false,240):return
	check(app.combat.ammo_shotgun==mini(40,before+12) and app.world.collected.has(id) and reward_events(id)==1 and app.world.arena_active.get(group,false),"Live movement accepts exactly one twelve-shell supply/release")
	var start_shots: int=app.combat.shot_counter;var start_kills: int=app.combat.kills;physics_minima={"health":app.combat.health,"armor":app.combat.armor,"pistol":app.combat.ammo_pistol,"shells":app.combat.ammo_shotgun}
	# Retreat along the actual entry while the released group can chase and
	# shoot. No deaths, prerequisites, door states or player poses are injected.
	if not await walk(v(points.back()),"Live retreat to optional room centre",false,240):return
	for i in range(points.size()-2,-1,-1):
		if not await walk(staging if i==0 else v(points[i]),"Live retreat through unchanged entry",false,480):return
	check(not app.combat.dead and app.world.room_at(app.player.global_position)==String(route.spawn_room),"Live accepted optional reserve leaves retreat to main route open")
	var departures: Dictionary={}
	await frames(120)
	var retreat_probe: Array[Dictionary]=[]
	for actor in actors:
		var target: Vector3=app.world.get_chase_target(actor.global_position,app.player.global_position)
		var direction: Vector3=target-actor.global_position;direction.y=0
		var collision:=KinematicCollision3D.new();var blocked: bool=actor.test_move(actor.global_transform,direction.normalized()*2,collision)
		retreat_probe.append({"id":actor.target_id,"position":actor.global_position,"target":target,"can_see":actor.can_see_player(),"blocked_next_two_metres":blocked,"collider":str(collision.get_collider()) if blocked else "","normal":collision.get_normal() if blocked else Vector3.ZERO})
		if outside_closet(actor.global_position,reserve):departures[String(actor.target_id)]=true
	observations.append({"level":level_id,"live_retreat_body_probe":retreat_probe,"player":app.player.global_position})
	# Re-enter physically after proving retreat. A distant main-room position
	# is not assumed to see every guard through two room mouths.
	for i in range(1,points.size()):
		if not await walk(v(points[i]),"Live optional return to exposed fight stance",false,480):return
	await frames(90)
	var before_flags: Dictionary={}
	for flag in app.world.objective_profile.exit_requires:before_flags[String(flag)]=app.world.flags.get(String(flag),false)
	# Fight from the existing mouth/room centre using only accepted finite
	# pistol shots and actual current opaque anatomical target surfaces.
	app.combat.select_weapon(&"pistol");var accepted_shots:=0
	for tick in 1200:
		var living: CharacterBody3D
		for actor in actors:
			if not actor.dead:living=actor;break
		if living==null or app.combat.dead:break
		var aim: Vector3=aim_at_actor(living);app.player.camera.look_at(aim)
		if can_hit(living,aim) and app.combat.try_fire():accepted_shots+=1
		physics_minima.health=minf(float(physics_minima.health),app.combat.health);physics_minima.armor=minf(float(physics_minima.armor),app.combat.armor);physics_minima.pistol=mini(int(physics_minima.pistol),app.combat.ammo_pistol);physics_minima.shells=mini(int(physics_minima.shells),app.combat.ammo_shotgun)
		for actor in actors:
			if outside_closet(actor.global_position,reserve):departures[String(actor.target_id)]=true
		await physics_frame
	var remaining:=0;var moved:=0
	for actor in actors:
		if not actor.dead:remaining+=1
		for a in spec.reserve_actor_overrides:
			if String(a.stable_id)==String(actor.target_id) and actor.global_position.distance_to(v(a.position))>1:moved+=1
	var actor_state: Array[Dictionary]=[]
	var naturally_engaged:=0
	var actual_ranged_player_contacts:=0
	for actor in actors:
		var release_count:=0
		var player_contacts:=0
		for event in events:
			if String(event.type) in ["projectile_release","enemy_weapon_release"] and String(event.get("target_id",""))==String(actor.target_id):release_count+=1
			if String(event.type)=="player_hurt" and String(event.get("source_id",""))==String(actor.target_id):player_contacts+=1
		if actor.definition.ranged:actual_ranged_player_contacts+=player_contacts
		if departures.has(String(actor.target_id)) or (actor.definition.ranged and player_contacts>0):naturally_engaged+=1
		actor_state.append({"id":actor.target_id,"position":actor.global_position,"health":actor.health,"awake":actor.awake,"state":actor.state,"can_see":actor.can_see_player(),"actual_projectile_releases":release_count,"actual_player_contacts":player_contacts})
	check(naturally_engaged==2,"Both reserve actors physically depart or land an actual natural ranged attack",{"departed":departures,"actors":actor_state})
	check(actual_ranged_player_contacts>0,"Natural optional ranged attack reaches actual player, beyond release event",{"actual_player_contacts":actual_ranged_player_contacts,"actors":actor_state})
	check(remaining==0 and not app.combat.dead and app.combat.kills-start_kills==2 and accepted_shots>0,"Live optional group cleared by finite accepted shots after open retreat",{"remaining":remaining,"health":app.combat.health,"accepted_pistol_shots":accepted_shots,"moved_actors":moved,"actors":actor_state,"minima":physics_minima})
	check(app.world.arena_remaining.get(group,-1)==0,"Actual optional group reports clear")
	for flag in before_flags:check(app.world.flags.get(flag,false)==before_flags[flag],"Optional clear leaves main prerequisite unchanged "+String(flag))
	check(reward_events(id)==1,"Live fight never duplicates accepted reward")
	observations.append({"level":level_id,"live_optional":group,"actual_shots":app.combat.shot_counter-start_shots,"actual_kills":app.combat.kills-start_kills,"minima":physics_minima,"scope":"Physical route from actual entry, proximity reward, natural two authored actors, open retreat and finite accepted pistol combat. Unrelated actors frozen; no full-campaign AI acceptance claim."})
func outside_closet(at: Vector3,reserve: Dictionary) -> bool:
	return at.z>float(reserve.partition_z)+.5 if float(reserve.actor_positions[0][2])<float(reserve.partition_z) else at.z<float(reserve.partition_z)-.5
func new_connections() -> void:
	var found:=false
	for connection in route.get("structural_connections",[]):
		if String(connection.id)!=String(spec.new_shared_connection.id):continue
		found=true;var original: Dictionary=app.world.capture_checkpoint_state();isolate_actors();await paths(connection)
		app.world.restore_checkpoint_state(original);freeze_actors();await frames(2);await actor_angle(connection)
		for pair in connection.get("shot_pairs",[]):
			await contacts(v(pair.a),v(pair.b),true,"v14 "+String(pair.id)+" a→b")
			if pair.get("bidirectional",false):await contacts(v(pair.b),v(pair.a),true,"v14 "+String(pair.id)+" b→a")
		for pair in connection.get("solid_pairs",[]):await contacts(v(pair.a),v(pair.b),false,"v14 "+String(pair.id))
		check(not connection.get("walk_paths",[]).is_empty() and not connection.get("shot_pairs",[]).is_empty() and not connection.get("solid_pairs",[]).is_empty(),"New shared connection has actual tested walk/contact/boundary paths")
	check(found,"Exact new shared connection authored contract available")
func feed_feedback() -> void:
	if level_id!="pale_ward_02":return
	var initial: Dictionary=app.world.capture_checkpoint_state()
	for order in [["isolation_a","isolation_b"],["isolation_b","isolation_a"]]:
		await controlled_restore(initial,"Feed feedback order reset")
		for i in 2:
			var node: Node3D=app.world.get_node("Control_"+String(order[i]));var floor_at: Vector3=node.global_position+Vector3(0,-.95,1.8)
			await pose_player(floor_at);messages.clear()
			check(app.world.nearest_mechanism()==node,"Actual nearby selected feed control "+String(order[i]))
			var accepted: bool=app.world.try_use();var expected_message: String=String(node.get_meta("activated_message","")) if i==0 else String(node.get_meta("activated_complete_message",""))
			check(accepted and not expected_message.is_empty() and not messages.is_empty() and messages.back()==expected_message,"Actual first/second feed feedback matches remaining vs complete state "+str(order)+str(i),{"messages":messages,"expected":expected_message})
func run() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	if DisplayServer.get_name()!="headless":root.mode=Window.MODE_MINIMIZED
	node_added.connect(observe_added)
	for selected in expected.selected:
		level_id=String(selected)
		for entry in expected.plan.levels:
			if String(entry.id)==level_id:spec=entry
		app=load("res://scenes/main.tscn").instantiate();root.add_child(app);app.automated_input=true
		app.campaign_mode=true;app.campaign.seek(level_id);app.stage_id="pale_ward";app.replace_world({});freeze_actors();app.enter_combat();await frames(3)
		route=JSON.parse_string(FileAccess.get_file_as_string("res://resources/campaign/"+level_id+"-route.json"))
		check(app.world.get_meta("layout_revision",0)==14,"Actual v14 world root revision "+level_id)
		if expected.mode in ["all","controlled"]:
			await footprints();app.restart_level();freeze_actors();await frames(3);events.clear();await optional_states();await feed_feedback()
		if expected.mode in ["all","connections"]:
			app.restart_level();freeze_actors();await frames(3);events.clear();await new_connections()
		if expected.mode in ["all","live"]:
			app.restart_level();freeze_actors();await frames(3);events.clear();await optional_live()
		await retire_main()
	await finish()
func observe_added(node: Node) -> void:
	if node.has_signal("combat_event") and not node.is_connected("combat_event",record_event):node.connect("combat_event",record_event)
	if node.has_signal("message_changed") and not node.is_connected("message_changed",record_message):node.connect("message_changed",record_message)
func record_message(message: String) -> void:messages.append(message)
func record_event(event: Dictionary) -> void:events.append(event.duplicate(true))
func retire_main() -> void:
	stop();app.combat_audio.stop_all();app.menu_music.stop();app.menu_music.stream=null
	var until: int=Time.get_ticks_msec()+300
	while Time.get_ticks_msec()<until:await process_frame
	app.combat.gore.reset();app.queue_free();app=null;paused=false;await frames(4)
	preload("res://scripts/sprite_hurt_geometry.gd").frame_cache.clear();preload("res://scripts/sprite_hurt_geometry.gd").image_cache.clear()
	until=Time.get_ticks_msec()+250
	while Time.get_ticks_msec()<until:await process_frame
func finish() -> void:
	var report: Dictionary={"status":"passed" if failures.is_empty() else "failed","checks":checks,"failures":failures,"observations":observations,"mode":expected.mode,"scope":"Actual Main independent spatial fixture. Controlled mode: polygon grid vs actual floor collisions/room ownership, closed floor meshes, prop bounds, physical cardinal-lane input, accepted/full/declined pickups plus snapshot/Main Continue/Restart and Containment feedback. Controlled supported capture uses unchanged checkpoint safety but does not prove actual marker acquisition. Connections mode: physical authored paths, natural moved actor attack and actual pistol plus both swept projectile classes/solid boundaries. Live mode: actual entry/proximity optional pickup/open retreat and finite-ammo two-actor natural encounter; unrelated actors frozen. Initial poses/direct collection only isolate controlled semantics. Full campaign routes remain separate. No human pacing claim."}
	FileAccess.open(report_path,FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n");print("WARD_SPATIAL_V14 ",report.status," ",checks.size()," ",failures);quit(0 if failures.is_empty() else 1)
