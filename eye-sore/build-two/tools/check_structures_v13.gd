extends SceneTree
## Controlled actual Main physics fixture. Temporary endpoint receivers and
## emitter/player poses isolate construction; live full routes remain separate.
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
		if arg.begins_with("--level="):level_id=arg.trim_prefix("--level=")
		if arg.begins_with("--report="):report_path=arg.trim_prefix("--report=")
	call_deferred("run")
func v(a: Array) -> Vector3:return Vector3(a[0],a[1],a[2])
func check(ok: bool,label: String,detail: Dictionary={}) -> void:
	checks.append({"passed":ok,"check":label,"detail":detail})
	if not ok:failures.append(label);push_error("STRUCTURE_V13 "+label+" "+JSON.stringify(detail))
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
func run() -> void:
	app=load("res://scenes/main.tscn").instantiate();root.add_child(app);app.automated_input=true
	app.campaign_mode=true;app.campaign.seek(level_id);app.stage_id="pale_ward";app.replace_world({})
	freeze_actors();app.enter_combat();await frames(3)
	app.combat.combat_event.connect(func(event: Dictionary):events.append(event.duplicate(true)))
	route=JSON.parse_string(FileAccess.get_file_as_string("res://resources/campaign/"+level_id+"-route.json"))
	var connections: Array=route.get("structural_connections",[])
	check(not connections.is_empty(),"Explicit structural connection contract available "+level_id)
	var original: Dictionary=app.world.capture_checkpoint_state()
	for connection in connections:
		isolate_actors()
		await paths(connection)
		app.world.restore_checkpoint_state(original);freeze_actors();await frames(2)
		if connection.has("shutters"):await shutter_states(connection,original)
		var firing_state: Dictionary=app.world.capture_checkpoint_state()
		await actor_angle(connection)
		app.world.restore_checkpoint_state(firing_state);freeze_actors();await frames(2)
		for pair in connection.get("shot_pairs",[]):
			if pair.get("state","always")!="always" and not connection.has("shutters"):continue
			await contacts(v(pair.a),v(pair.b),true,String(pair.id)+" a→b")
			if pair.get("bidirectional",false):await contacts(v(pair.b),v(pair.a),true,String(pair.id)+" b→a")
		for pair in connection.get("solid_pairs",[]):
			await contacts(v(pair.a),v(pair.b),false,String(pair.id))
		observations.append({"connection":connection.id,"contract":connection})
	await finish()
func finish() -> void:
	stop();var report: Dictionary={"status":"passed" if failures.is_empty() else "failed","level":level_id,"checks":checks,"failures":failures,"observations":observations,"scope":"Controlled actual Main construction fixture: physical player inputs on authored paths; actual moved actor natural LoS/range/release; actual pistol and both production swept projectile classes against temporary endpoint receivers and real authored walls. Actor/query isolation and initial poses are fixture setup, not live-route proof. Player ordnance direct launch is geometry-only, no ammo/cadence claim. Full natural campaign routes are separate."}
	app.combat_audio.stop_all();app.menu_music.stop();app.menu_music.stream=null
	var until: int=Time.get_ticks_msec()+300
	while Time.get_ticks_msec()<until:await process_frame
	app.combat.gore.reset();app.queue_free();app=null;paused=false;await frames(4)
	preload("res://scripts/sprite_hurt_geometry.gd").frame_cache.clear();preload("res://scripts/sprite_hurt_geometry.gd").image_cache.clear()
	until=Time.get_ticks_msec()+250
	while Time.get_ticks_msec()<until:await process_frame
	FileAccess.open(report_path,FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("STRUCTURE_V13 ",level_id," ",report.status," ",checks.size()," ",failures)
	quit(0 if failures.is_empty() else 1)
