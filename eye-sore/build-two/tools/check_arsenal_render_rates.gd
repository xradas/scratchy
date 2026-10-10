extends SceneTree
## Opt-in native Main wall-shot fixture. Real fixed physics; render cap alone varies.
## AI is removed, ammo grants and stable camera placement are declared fixture setup.
class PhysicsDriver:
	extends Node
	signal finished
	var fixture: SceneTree
	var enabled := true
	func _physics_process(delta: float) -> void:
		if enabled: fixture.advance_physics(delta)
	func _process(_delta: float) -> void:
		if enabled and not DisplayServer.window_can_draw():
			fixture.forcing_draw = true
			fixture.forced_draw_calls += 1
			RenderingServer.force_draw(true)
			fixture.forcing_draw = false

var app: Control
var combat: Node3D
var actor: CharacterBody3D
var camera: Camera3D
var driver: PhysicsDriver
var wall: StaticBody3D
var fps := 60
var failures: Array[String] = []
var phase := "warmup"
var phase_ticks := 24
var total_ticks := 0
var gun_index := 0
var guns: Array[StringName] = [&"twin_shotgun",&"rivet_cannon",&"siege_launcher"]
var window_tick := 0
var windows: Array[Dictionary] = []
var current_window: Dictionary = {}
var shot_events: Array[Dictionary] = []
var timeline: Array[Dictionary] = []
var phase_transitions: Array[Dictionary] = []
var last_weapon_phase := ""
var pending_shots: Dictionary = {}
var rendered_shots: Dictionary = {}
var physics_deltas: Array[float] = []
var frame_times: Array[float] = []
var previous_draw_usec := 0
var draw_index := 0
var firing_draws := 0
var visible_muzzle_draws := 0
var forced_draw_calls := 0
var forced_draws := 0
var drawable_frames := 0
var forcing_draw := false
var measuring := false
var fixed_camera: Transform3D
var fixed_actor: Transform3D
var actors_removed := 0
var startup_ammo: Dictionary = {}
var granted_ammo: Dictionary = {}
var initial_physics_tick := 0

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--fps="): fps=int(argument.trim_prefix("--fps="))
	call_deferred("run")
func check(condition: bool,message: String) -> void:
	if not condition:
		failures.append(message);push_error("ARSENAL_RENDER_RATE_FAILED: "+message)
func ammo() -> Dictionary:
	return {"ammo_pistol":combat.ammo_pistol,"ammo_shotgun":combat.ammo_shotgun,"ammo_rivets":combat.ammo_rivets,"ammo_rockets":combat.ammo_rockets}
func observe(event: Dictionary) -> void:
	var type:=String(event.get("type",""))
	if type not in ["shot","weapon_switch","impact","ordnance_explosion","enemy_hurt","enemy_death","weapon_granted","ammo_added"]:return
	var entry:={"type":type,"weapon":String(event.get("weapon_id","")),"shot_id":int(event.get("shot_id",0)),"target_id":String(event.get("target_id","")),"physics_tick":Engine.get_physics_frames(),"fixture_tick":total_ticks,"window_tick":window_tick,"ammo_kind":String(event.get("ammo_kind","")),"amount":int(event.get("amount",0)),"ammo":int(event.get("ammo",0)),"material":String(event.get("material",""))}
	timeline.append(entry)
	if type=="shot":
		check(phase=="fire" and String(combat.currentweapon)==String(guns[gun_index]),"Shot was accepted outside the selected fixed-physics window")
		shot_events.append(entry)
		pending_shots[int(entry.shot_id)]={"event":entry,"draw_after":draw_index}
		current_window.accepted_ticks.append(window_tick)
		current_window.accepted_shot_ids.append(int(entry.shot_id))
	elif type in ["enemy_hurt","enemy_death"]:check(false,"Wall-only fixture unexpectedly damaged an actor")
func on_draw() -> void:
	if not measuring:return
	draw_index+=1
	var now:=Time.get_ticks_usec()
	if phase=="fire":
		firing_draws+=1
		if previous_draw_usec>0:frame_times.append(float(now-previous_draw_usec)/1000.0)
	previous_draw_usec=now
	if forcing_draw:forced_draws+=1
	if DisplayServer.window_can_draw():drawable_frames+=1
	check(camera.global_transform==fixed_camera and actor.global_transform==fixed_actor,"Render changed the controlled camera/player transform")
	if app.muzzle_image.visible and app.muzzle_image.texture!=null:
		visible_muzzle_draws+=1
		for id in pending_shots.keys():
			var pending: Dictionary=pending_shots[id]
			var latency:=Engine.get_physics_frames()-int(pending.event.physics_tick)
			check(latency<=maxi(3,int(ceil(60.0/fps))+1),"Accepted shot reached a muzzle render too late: "+str(id))
			rendered_shots[id]={"draw":draw_index,"physics_tick":Engine.get_physics_frames(),"physics_latency":latency,"forced":forcing_draw,"window_can_draw":DisplayServer.window_can_draw(),"muzzle_visible":true,"texture_present":true}
			pending_shots.erase(id)
func advance_physics(delta: float) -> void:
	total_ticks+=1;physics_deltas.append(delta)
	check(camera.global_transform==fixed_camera and actor.global_transform==fixed_actor,"Physics/recoil changed the controlled camera/player transform")
	if total_ticks>600:
		check(false,"Fixture exceeded ten simulated seconds")
		driver.enabled=false;driver.finished.emit();return
	if phase=="warmup":
		phase_ticks-=1
		if phase_ticks<=0 and combat.cooldown<=0:
			check(combat.select_weapon(guns[gun_index]),"Ordinary weapon selection rejected")
			phase="switch"
	elif phase=="switch":
		if combat.weapon_phase==&"idle" and combat.cooldown<=0:
			var definition: Resource=combat.weapons[guns[gun_index]]
			current_window={"weapon":String(guns[gun_index]),"physics_start":Engine.get_physics_frames(),"fixture_start":total_ticks,"physics_ticks":120,"ammo_key":String(definition.ammo_key),"ammo_cost":int(definition.ammo_cost),"ammo_before":int(combat.get(String(definition.ammo_key))),"accepted_ticks":[],"accepted_shot_ids":[]}
			phase="fire";window_tick=0
	if phase=="fire":
		combat.try_fire()
		window_tick+=1
		if window_tick==120:
			current_window.ammo_after=int(combat.get(String(current_window.ammo_key)))
			current_window.ammo_spent=int(current_window.ammo_before)-int(current_window.ammo_after)
			current_window.accepted_count=current_window.accepted_ticks.size()
			check(int(current_window.ammo_spent)==int(current_window.accepted_count)*int(current_window.ammo_cost),"Ammo expenditure diverged from accepted shots")
			windows.append(current_window)
			gun_index+=1
			if gun_index<guns.size():phase="warmup";phase_ticks=24
			else:phase="tail";phase_ticks=45
	elif phase=="tail":
		phase_ticks-=1
		if phase_ticks<=0:driver.enabled=false;driver.finished.emit()
	var observed_phase:=String(combat.weapon_phase)
	if observed_phase!=last_weapon_phase:
		phase_transitions.append({"weapon":String(combat.currentweapon),"phase":observed_phase,"fixture_tick":total_ticks,"physics_tick":Engine.get_physics_frames(),"phase_seconds":combat.phase_time,"cooldown_seconds":combat.cooldown})
		last_weapon_phase=observed_phase
func statistics(values: Array[float]) -> Dictionary:
	if values.is_empty():return {"samples":0}
	var sorted:=values.duplicate();sorted.sort()
	var sum:=0.0
	for value in sorted:sum+=value
	return {"samples":sorted.size(),"minimum":sorted[0],"maximum":sorted[-1],"mean":sum/sorted.size(),"median":sorted[sorted.size()/2],"p95":sorted[mini(sorted.size()-1,int(ceil(sorted.size()*.95))-1)]}
func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("ARSENAL_RENDER_RATE_FAILED: native rendering is required; headless cannot verify muzzle visibility")
		quit(1);return
	if fps not in [30,60,120] or "--calibration" not in OS.get_cmdline_user_args() or "--automated-input" not in OS.get_cmdline_user_args():
		push_error("ARSENAL_RENDER_RATE_FAILED: requires --calibration --automated-input --fps=30|60|120")
		quit(1);return
	Engine.physics_ticks_per_second=60;Engine.max_fps=fps
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	app=load("res://scenes/main.tscn").instantiate();root.add_child(app)
	combat=app.combat;actor=app.player;camera=actor.get_node("Camera3D")
	actor.set_physics_process(false)
	actor.position=Vector3(0,.87,10);actor.rotation=Vector3.ZERO;camera.rotation=Vector3.ZERO
	fixed_camera=camera.global_transform;fixed_actor=actor.global_transform
	actors_removed=combat.enemies.size()
	for enemy in combat.enemies:
		enemy.set_physics_process(false);enemy.collision_layer=0;enemy.collision_mask=0
		for hurt in enemy.hurt_shapes:hurt.collision_layer=0
		enemy.queue_free()
	combat.enemies.clear()
	wall=StaticBody3D.new();wall.name="RenderRateFixtureWall";wall.position=Vector3(0,1.52,-2);wall.collision_layer=1;wall.collision_mask=3;wall.set_meta("hit_material",&"hard");app.world.add_child(wall)
	var box:=BoxShape3D.new();box.size=Vector3(14,8,.15)
	var shape:=CollisionShape3D.new();shape.shape=box;wall.add_child(shape)
	var mesh:=BoxMesh.new();mesh.size=box.size
	var visual:=MeshInstance3D.new();visual.mesh=mesh;wall.add_child(visual)
	startup_ammo=ammo();combat.combat_event.connect(observe)
	for item in [[&"twin_shotgun",12],[&"rivet_cannon",72],[&"siege_launcher",6]]:check(combat.grant_weapon(item[0],item[1]),"Declared fixture grant rejected")
	granted_ammo=ammo()
	app.enter_combat();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	await process_frame
	driver=PhysicsDriver.new();driver.fixture=self;root.add_child(driver)
	initial_physics_tick=Engine.get_physics_frames();measuring=true
	RenderingServer.frame_post_draw.connect(on_draw)
	await driver.finished
	await process_frame
	measuring=false
	RenderingServer.frame_post_draw.disconnect(on_draw)
	check(windows.size()==3,"Three complete weapon windows were not recorded")
	check(pending_shots.is_empty() and rendered_shots.size()==shot_events.size(),"Accepted shots were hidden from actual renders")
	check(draw_index>0 and visible_muzzle_draws>0,"No native muzzle draw was observed")
	check(Engine.physics_ticks_per_second==60,"Fixed physics tick rate changed")
	var physics_stats:=statistics(physics_deltas)
	check(absf(float(physics_stats.get("minimum",0))-1.0/60.0)<.000001 and absf(float(physics_stats.get("maximum",0))-1.0/60.0)<.000001,"Physics delta changed with render cap")
	var frame_stats:=statistics(frame_times)
	var measured_fps:=1000.0/float(frame_stats.get("mean",1000.0))
	var matched:=absf(measured_fps-fps)/fps<.15
	check(matched,"Native firing render rate did not match the requested cap")
	check(float(frame_stats.get("p95",1000.0))<2500.0/fps,"Native firing frame times exceeded the bounded p95")
	var grants:=0;var explosions:={};var siege_shots:={}
	for event in timeline:
		if event.type=="ammo_added":grants+=1
		if event.type=="ordnance_explosion":explosions[int(event.shot_id)]=int(explosions.get(int(event.shot_id),0))+1
		if event.type=="shot" and event.weapon=="siege_launcher":siege_shots[int(event.shot_id)]=true
	check(grants==3,"Fixture received undeclared additional ammunition")
	check(explosions.size()==siege_shots.size(),"Siege wall contacts did not resolve each accepted ordnance")
	for id in explosions:check(siege_shots.has(id) and explosions[id]==1,"Explosion lacks a unique accepted-shot owner")
	var report:={"failures":failures,"render_cap":fps,"matched_cap":matched,"measured_render_fps":measured_fps,"frame_times_ms":frame_stats,"physics_ticks_per_second":60,"physics_delta_seconds":physics_stats,"physics_ticks":total_ticks,"simulated_seconds":total_ticks/60.0,"display_server":DisplayServer.get_name(),"rendering_method":RenderingServer.get_current_rendering_method(),"window_dimensions":[root.size.x,root.size.y],"world_viewport_dimensions":[app.world_view.size.x,app.world_view.size.y],"actors_removed":actors_removed,"fixture_grants":{"twin_shotgun_shells":12,"rivet_cannon_rivets":72,"siege_launcher_rockets":6},"startup_ammo":startup_ammo,"granted_ammo":granted_ammo,"final_ammo":ammo(),"camera_unchanged":camera.global_transform==fixed_camera and actor.global_transform==fixed_actor,"window_can_draw_frames":drawable_frames,"native_draws":draw_index-forced_draws,"forced_draw_calls":forced_draw_calls,"forced_draws":forced_draws,"firing_draws":firing_draws,"visible_muzzle_draws":visible_muzzle_draws,"accepted_shots":shot_events.size(),"rendered_shots":rendered_shots,"hidden_shot_ids":pending_shots.keys(),"weapon_windows":windows,"phase_transitions":phase_transitions,"timeline":timeline,"damage_owner":{"accepted":"scripts/combat.gd:try_fire/resolve_shot","projectile":"scripts/player_ordnance.gd swept physical contacts","explosion":"scripts/combat.gd:resolve_ordnance_explosion","fixture_wall_id":str(wall.get_instance_id()),"siege_shots":siege_shots.keys(),"explosion_counts":explosions},"scope":"Native Main calibration wall-shot cadence and muzzle visibility. Two original AI actors removed, stable camera/player fixture placement, declared ammo grants; 60 Hz real engine physics with 30/60/120 render cap. No live-AI, physical mouse feel, or human acceptance claim."}
	var directory:="res://verification/arsenal-architecture-v2/rates";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var output:=FileAccess.open(directory+"/"+str(fps)+".json",FileAccess.WRITE)
	if output!=null:output.store_string(JSON.stringify(report,"  "));output.close()
	else:check(false,"Could not write render-rate receipt")
	print("ARSENAL_RENDER_RATE_OK " if failures.is_empty() else "ARSENAL_RENDER_RATE_FAILED ",JSON.stringify({"cap":fps,"measured_fps":measured_fps,"accepted_shots":shot_events.size(),"rendered_shots":rendered_shots.size(),"failures":failures,"simulated_seconds":total_ticks/60.0,"windows":windows}))
	await app.quit_game()
	quit(0 if failures.is_empty() else 1)
