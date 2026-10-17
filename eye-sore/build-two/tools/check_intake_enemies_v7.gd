extends SceneTree
## Controlled actual Main fixture. Player positioning is setup, not traversal.
var app: Control
var failures: Array[String] = []
var checks := 0
var trace: Array[Dictionary] = []
var results: Array[Dictionary] = []
var phase := "setup"
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(phase+": "+label); push_error(failures.back())
func record(event: Dictionary) -> void:
	var value := event.duplicate(true); value.phase = phase; value.tick = Engine.get_physics_frames(); trace.append(value)
func count(kind: String, id := "", attack := -1) -> int:
	var n := 0
	for event in trace:
		if String(event.get("phase", "")) == phase and String(event.get("type", "")) == kind and (id.is_empty() or String(event.get("target_id", "")) == id) and (attack < 0 or event.get("attack_id", -1) == attack): n += 1
	return n
func release_type(enemy: Node3D) -> String:
	if enemy.carried_weapon != &"": return "enemy_weapon_release"
	return "projectile_release" if enemy.definition.ranged else "enemy_melee_release"
func frames(n: int) -> void:
	for i in n: await physics_frame
func setup() -> Array:
	if is_instance_valid(app):
		app.combat_audio.stop_all(); app.menu_music.stop(); app.menu_music.stream=null
		await create_timer(.3,true).timeout
		app.free(); await frames(2)
	app = load("res://scenes/main.tscn").instantiate(); root.add_child(app)
	app.automated_input = true; app.campaign_mode = true; app.campaign.seek("pale_ward_01")
	app.stage_id = "pale_ward"; app.replace_world({}); app.campaign.entry_snapshot = app.campaign.capture(app.combat); app.enter_combat()
	app.player.set_physics_process(false); app.combat.set_physics_process(false)
	app.player.global_position = Vector3(0,-.13,-76)
	app.combat.combat_event.connect(record)
	var actors := []
	for enemy in app.combat.enemies:
		enemy.set_physics_process(false)
		if String(enemy.get_meta("arena_id", "")) == "arena_one": actors.append(enemy)
	await frames(3)
	for item in app.world.pickups:
		if item.name == "Bait_arena_one": app.world.collect(item); break
	for i in 150:
		await physics_frame
		if app.world.is_arena_active("arena_one"): break
	check(app.world.is_arena_active("arena_one"), "physical lure naturally opens shutters and enables arena")
	return actors
func wait_state(enemy: Node3D, state: StringName, limit := 600) -> bool:
	for i in limit:
		await physics_frame
		if enemy.state == state: return true
	var contacts := []
	for j in enemy.get_slide_collision_count(): contacts.append(str(enemy.get_slide_collision(j).get_collider().get_path()))
	results.append({"timed_out":enemy.target_id,"position":str(enemy.global_position),"state":enemy.state,"contacts":contacts,"can_see":enemy.can_see_player()})
	if enemy.target_id == "enemy_unsealed_8":
		app.player.global_position = Vector3(0,-.13,-70)
		await frames(300)
		results.append({"lane_change_after_stall":enemy.target_id,"position":str(enemy.global_position),"state":enemy.state,"on_floor":enemy.is_on_floor()})
	check(false,"timed out waiting " + String(state) + " for " + enemy.target_id)
	return false
func shoot(enemy: Node3D) -> bool:
	var exclusions := [app.player.get_rid()]
	for other in app.combat.enemies: exclusions.append(other.get_rid())
	for y in [.25,.05,-.15,.45,-.35]:
		for x in [0.0,.15,-.15,.3,-.3]:
			var point: Vector3 = enemy.global_position+Vector3(x,y,0)
			var origin: Vector3 = app.player.camera.global_position
			var hit: Dictionary = app.combat.ray(origin,origin+(point-origin).normalized()*60,exclusions,true)
			if not hit.is_empty() and hit.collider.get_meta("combat_target",null) == enemy:
				app.player.camera.look_at(point); app.combat.cooldown = 0; app.combat.currentweapon = &"pistol"
				return app.combat.try_fire()
	return false
func run() -> void:
	phase = "native-spawns"
	var actors := await setup()
	check(actors.size()==5,"five existing triage actors")
	for enemy in actors:
		var origin: Vector3 = enemy.global_position
		var q := PhysicsRayQueryParameters3D.create(origin,origin+Vector3.DOWN*2,1)
		var floor_hit: Dictionary = enemy.get_world_3d().direct_space_state.intersect_ray(q)
		check(not floor_hit.is_empty(),enemy.target_id+" supported native spawn")
		var capsule: Shape3D = enemy.get_node("CollisionShape3D").shape
		var shape_query := PhysicsShapeQueryParameters3D.new(); shape_query.shape=capsule;shape_query.transform=enemy.global_transform;shape_query.collision_mask=1
		check(enemy.get_world_3d().direct_space_state.intersect_shape(shape_query).is_empty(),enemy.target_id+" native capsule clear of solids")
		check(enemy.awake,enemy.target_id+" awakened by real arena activation")
		check(is_instance_valid(enemy.sprite) or is_instance_valid(enemy.visual_rig),enemy.target_id+" production presentation loaded")
		var hurt_surfaces:=0
		for body in enemy.hurt_shapes:
			if body.collision_layer == 4 and body.get_node("HitSurface").shape != null: hurt_surfaces+=1
		check(hurt_surfaces>0,enemy.target_id+" active opaque-anatomy hurt geometry")
		if is_instance_valid(enemy.sprite_pivot): check(absf(enemy.sprite_pivot.position.y+.85)<.001,enemy.target_id+" feet pivot matches physical capsule")
		results.append({"id":enemy.target_id,"kind":enemy.definition.identifier,"spawn":str(origin),"visible_to_centre":enemy.can_see_player(),"health":enemy.health,"definition":enemy.definition.resource_path,"definition_sha256":FileAccess.get_sha256(enemy.definition.resource_path),"windup_seconds":enemy.definition.windup_seconds,"sprite_frame":enemy.sprite_frame})
	# Each pursuer moves through the actual furnished room independently from its native slot.
	for index in actors.size():
		actors = await setup()
		var enemy: Node3D = actors[index]
		phase = "natural-"+enemy.target_id
		var start: Vector3 = enemy.global_position
		var initial := start.distance_to(app.player.global_position)
		enemy.set_physics_process(true)
		if not await wait_state(enemy,&"windup",900): continue
		var warning_tick := Engine.get_physics_frames(); var attack: int=enemy.attack_id; var warning_frame: int=enemy.sprite_frame
		check(enemy.can_see_player(),"natural windup has line of sight")
		check(count("enemy_attack_warning",enemy.target_id,attack)==1,"one committed warning")
		check(initial-enemy.global_position.distance_to(app.player.global_position)>3.0 or enemy.definition.ranged,"melee physically advances more than 3m from alcove")
		var release := release_type(enemy)
		await frames(int(ceil(enemy.definition.windup_seconds*60))+3)
		check(count(release,enemy.target_id,attack)==1,"natural warning produces exactly one release")
		var release_tick := -1
		for event in trace:
			if String(event.get("phase", "")) == phase and String(event.get("type",""))==release and event.get("target_id","")==enemy.target_id and event.get("attack_id",-1)==attack: release_tick=event.tick
		check(absf(float(release_tick-warning_tick)/60-enemy.definition.windup_seconds)<=2.0/60,"natural release agrees with definition windup")
		results.append({"id":enemy.target_id,"natural_start":str(start),"attack_position":str(enemy.global_position),"warning_tick":warning_tick,"release_tick":release_tick,"distance_closed":initial-enemy.global_position.distance_to(app.player.global_position),"warning_frame":warning_frame,"released_frame":enemy.sprite_frame})
	# Nonlethal/terminal actual pistol contacts, using existing health rather than a health override.
	for ranged in [false,true]:
		actors=await setup()
		var enemy: Node3D
		for candidate in actors:
			if candidate.definition.ranged==ranged: enemy=candidate;break
		phase="interrupt-"+enemy.target_id
		enemy.set_physics_process(true)
		if not await wait_state(enemy,&"windup",900): continue
		var attack: int=enemy.attack_id
		var before: float=enemy.health
		check(shoot(enemy),"genuine opaque-surface pistol ray accepted")
		check(enemy.health<before and enemy.state==&"pain" and enemy.released,"nonlethal damage cancels pending windup")
		await frames(int(ceil(enemy.definition.pain_seconds*60))+3)
		check(count(release_type(enemy),enemy.target_id,attack)==0,"cancelled attack never releases")
		# Setup lowers health by genuine repeated pistol hits, preserving production max-health definition.
		for i in 30:
			if enemy.health <= 20: break
			enemy.set_physics_process(false)
			await frames(2)
			check(shoot(enemy),"subsequent genuine lethal contact accepted")
		enemy.set_physics_process(true)
		if await wait_state(enemy,&"windup",900):
			var terminal_attack: int=enemy.attack_id
			check(not enemy.released,"lethal contact starts in fresh unreleased natural windup")
			check(shoot(enemy),"terminal genuine opaque-surface pistol ray accepted")
			check(count(release_type(enemy),enemy.target_id,terminal_attack)==0,"lethal interrupted attack has no release")
		check(enemy.dead,"actual contacts reach death")
		enemy.set_physics_process(true)
		var dead_release:=count(release_type(enemy),enemy.target_id)
		await frames(150)
		check(count(release_type(enemy),enemy.target_id)==dead_release,"dead target never releases on later live physics")
		check(count("enemy_death",enemy.target_id)==1,"one terminal ownership event")
	phase="hard-geometry-projectile"
	actors=await setup()
	var ranged_enemy: Node3D=actors[0]
	var origin:=Vector3(0,.7,-76)
	var destination:=Vector3(30,.7,-76)
	var hard_query:=PhysicsRayQueryParameters3D.create(origin,destination,1)
	var wall: Dictionary=app.world.get_world_3d().direct_space_state.intersect_ray(hard_query)
	check(not wall.is_empty(),"existing hard geometry lies on declared projectile fixture path")
	app.player.global_position=destination
	await frames(2)
	var health_before: float=app.combat.health
	var impacts:=count("projectile_impact")
	var projectile: Node3D=app.combat.launch_projectile(ranged_enemy,origin,(destination-origin).normalized())
	await frames(200)
	check(not is_instance_valid(projectile) or projectile.resolved,"native swept projectile resolves against existing solid")
	check(app.combat.health==health_before,"hard geometry prevents projectile damage beyond obstruction")
	check(count("projectile_impact")==impacts+1,"one physical projectile impact event")
	finish()
func finish() -> void:
	var report:={"passed":failures.is_empty(),"checks":checks,"failures":failures,"results":results,"events":trace,"engine":Engine.get_version_info(),"scene_sha256":FileAccess.get_sha256("res://scenes/campaign/pale_ward_01.tscn"),"fixture_sha256":FileAccess.get_sha256("res://tools/check_intake_enemies_v7.gd"),"enemy_runtime_sha256":FileAccess.get_sha256("res://scripts/combat_enemy.gd"),"projectile_sha256":FileAccess.get_sha256("res://scripts/combat_projectile.gd"),"scope":"Controlled actual Main Intake. Real bait activation, original five actor spawns and production definitions/timings. Other actors frozen for independent approach/contact cases, player movement frozen and repositioned as declared. Natural attacks use live physics. Projectile obstruction case explicitly uses launch_projectile into existing hard geometry, not a natural enemy attack. No route, human visual/audio approval or balance claim."}
	var path:="res://verification/intake-v7/enemies/report.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):path=arg.trim_prefix("--report=")
	var file:=FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  ")+"\n");file.close()
	app.combat_audio.stop_all();app.menu_music.stop();app.menu_music.stream=null
	await create_timer(.3,true).timeout
	app.free()
	preload("res://scripts/sprite_hurt_geometry.gd").frame_cache.clear()
	preload("res://scripts/sprite_hurt_geometry.gd").image_cache.clear()
	print("INTAKE_ENEMIES_V7_", "PASS" if failures.is_empty() else "FAIL", " ",checks)
	await create_timer(.3,true).timeout
	quit(0 if failures.is_empty() else 1)
