extends SceneTree
## Real production CharacterBody, real input and physics in isolated declared geometry.
const PLAYER_SCENES := ["res://scenes/campaign/pale_ward_01.tscn","res://scenes/campaign/ash_citadel_01.tscn","res://scenes/campaign/occupied_line_01.tscn"]
const P = preload("res://scripts/weapon_presentation.gd")
var output := "res://verification/production-v9/movement/headless.json"
var rate_only := false
var cap := 60
var fixture: Node3D
var actor: CharacterBody3D
var checks := 0
var failures: Array[String] = []
var records := []
var combat: Node3D
var shots: Array[Dictionary] = []
func on_combat_event(event: Dictionary) -> void:
	if event.get("type")==&"shot":shots.append(event.duplicate())
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
		if arg.begins_with("--render-fps="):cap=int(arg.trim_prefix("--render-fps="))
		if arg=="--rate-only":rate_only=true
	call_deferred("run")
func check(value: bool, label: String) -> void:
	checks+=1
	if not value:failures.append(label);push_error("MOVEMENT_V9: "+label)
func xyz(v: Vector3) -> Array:return [v.x,v.y,v.z]
func key(code: int, down: bool) -> void:
	var event:=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=down;Input.parse_input_event(event);Input.flush_buffered_events()
func release() -> void:
	for code in [KEY_W,KEY_A,KEY_S,KEY_D,KEY_CTRL,KEY_SHIFT]:key(code,false)
func ticks(count: int) -> void:
	for i in count:await physics_frame
func box(label: String, size: Vector3, at: Vector3) -> void:
	var body:=StaticBody3D.new();body.name=label;body.position=at;body.collision_layer=1
	var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=size;collision.shape=shape;body.add_child(collision);fixture.add_child(body)
func new_actor(scene: String, position: Vector3=Vector3(0,.87,0)) -> CharacterBody3D:
	var source:Node3D=load(scene).instantiate()
	var player:CharacterBody3D=source.get_node("Player");source.remove_child(player);source.free()
	player.position=position;player.rotation=Vector3.ZERO;fixture.add_child(player)
	return player
func feet() -> float:return actor.global_position.y+actor.body_collision.position.y-actor.body_collision.shape.height*.5
func reset_actor(at: Vector3=Vector3(0,.87,0)) -> void:
	release();actor.set_movement_active(false);actor.global_position=at;actor.velocity=Vector3.ZERO;actor.set_movement_active(true);await ticks(8)
func camera_contract() -> void:
	var center:=Vector2(320,180)
	check(actor.camera.project_ray_normal(center).distance_to(-actor.camera.global_basis.z)<.0001,"Camera owns centered aim during movement")
	var art:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/combat_art.json"))
	for phase in ["idle","fire","recover"]:
		var atlas:Dictionary=art.weapon_atlases.twin_shotgun
		var pose:Dictionary=P.pose(atlas.placement[phase],Vector2(780,520),512,Vector2(640,360),11.0 if phase=="fire" else 0.0)
		for bore in pose.bores:check(absf(bore.aim_x-320)<.01,"Twin painted bore remains camera-centered while "+phase)
func walking(profile: String, control: int=0) -> Dictionary:
	await reset_actor(Vector3(-15,.87,12))
	actor.set_motion_settings(.35)
	var before:=actor.global_position;var start_frames:=Engine.get_frames_drawn()
	var low:=Vector3.INF;var high:=-Vector3.INF
	if control:key(control,true)
	key(KEY_W,true)
	for i in 120:
		await physics_frame
		var offset:Vector3=actor.camera.position-actor._neutral_camera_position()
		low=low.min(offset);high=high.max(offset)
		check(actor.is_on_floor(),profile+" stays grounded")
		check(offset.y<=.00001,profile+" bob never moves head above neutral")
	camera_contract()
	combat.cooldown=0.0
	var ammo_before:int=combat.ammo_pistol
	var shot_before:=shots.size()
	check(combat.try_fire(),profile+" permits real authoritative firing")
	check(shots.size()==shot_before+1 and combat.ammo_pistol==ammo_before-1,profile+" actual shot owns one event/ammo")
	if shots.size()>shot_before:
		check(shots[-1].position.distance_to(actor.camera.global_position)<.0001,profile+" ray starts at bob/crouch camera")
		check(shots[-1].direction.distance_to(-actor.camera.global_basis.z)<.0001,profile+" ray follows actual camera center")
	var result:={"profile":profile,"render_cap":cap,"rendered_frames":Engine.get_frames_drawn()-start_frames,"physics_ticks":120,"travel":xyz(actor.global_position-before),"final_speed":Vector2(actor.velocity.x,actor.velocity.z).length(),"bob_min":xyz(low),"bob_max":xyz(high),"crouching":actor.is_crouching,"sprinting":actor.is_sprinting}
	var target:=4.4 if control==KEY_CTRL else (10.8 if control==KEY_SHIFT else 8.0)
	check(absf(result.final_speed-target)<.01,profile+" unchanged declared speed")
	check(high.x-low.x>.002,profile+" distance-driven camera bob visible in trace")
	release();await ticks(60)
	check((actor.camera.position-actor._neutral_camera_position()).length()<.0001,profile+" idle returns neutral")
	records.append(result);return result
func run() -> void:
	if DisplayServer.get_name()!="headless":root.set_flag(Window.FLAG_NO_FOCUS,true);root.position=Vector2i(20000,20000)
	Engine.max_fps=cap
	root.size=Vector2i(640,360)
	fixture=Node3D.new();root.add_child(fixture)
	box("Floor",Vector3(80,.2,80),Vector3(0,-.1,0))
	box("Wall",Vector3(4,3,.2),Vector3(0,1.5,-7))
	box("LowRoof",Vector3(3,.2,4),Vector3(5,1.35,-6))
	var viewport:=SubViewport.new();viewport.size=Vector2i(640,360);viewport.own_world_3d=false;root.add_child(viewport)
	actor=new_actor(PLAYER_SCENES[0]);await ticks(10)
	var empty_spawns:=Node3D.new();empty_spawns.name="EnemySpawns";fixture.add_child(empty_spawns)
	combat=preload("res://scripts/combat.gd").new();fixture.add_child(combat);combat.setup(fixture,actor);combat.set_physics_process(false);combat.combat_event.connect(on_combat_event)
	check(actor.is_on_floor(),"Real capsule settles on floor")
	check(is_equal_approx(actor.bob_intensity,.35),"Default bob intensity.35")
	await walking("walk")
	await walking("sprint",KEY_SHIFT)
	await walking("crouch",KEY_CTRL)
	if not rate_only:
		await reset_actor()
		actor.set_motion_settings(0);key(KEY_W,true);await ticks(30)
		check(actor.camera.position==actor._neutral_camera_position(),"Zero bob fully neutral while moving")
		actor.set_motion_settings(9);check(actor.bob_intensity==1,"Bob upper clamp")
		actor.set_motion_settings(-1);check(actor.bob_intensity==0,"Bob lower clamp")
		release();actor.set_motion_settings(.35)
		await reset_actor();key(KEY_CTRL,true);await ticks(2)
		var crouch_feet:=feet();check(actor.is_crouching and is_equal_approx(actor.body_collision.shape.height,1.1),"Ctrl resizes actual capsule")
		check(absf(crouch_feet)<.005,"Crouch preserves floor feet")
		check(absf(actor.camera.position.y-.38)<.002,"Camera follows current capsule center")
		key(KEY_SHIFT,true);key(KEY_W,true);await ticks(30)
		check(actor.is_crouching and not actor.is_sprinting and absf(actor.velocity.z+4.4)<.01,"Crouch wins simultaneous Ctrl+Shift")
		var second:=new_actor(PLAYER_SCENES[0],Vector3(10,.87,0));await ticks(2)
		check(not second.is_crouching and is_equal_approx(second.body_collision.shape.height,1.7),"Retry freshworld starts standing despite held Ctrl")
		check(second.body_collision.shape!=actor.body_collision.shape,"Mutable capsule unique per actor")
		var second_start:=second.global_position;await ticks(8)
		check(Vector2(second.global_position.x-second_start.x,second.global_position.z-second_start.z).length()<.001,"Newworld held movement waits for release")
		second.free();release();await ticks(3)
		check(not actor.is_crouching and absf(feet()-crouch_feet)<.003,"Stand restores height without lifting feet")
		await reset_actor(Vector3(5,.87,-2));key(KEY_W,true);await ticks(45)
		check(actor.global_position.z> -3.75,"Standing capsule physically blocked by low tunnel")
		key(KEY_CTRL,true);await ticks(40)
		check(actor.is_crouching and actor.global_position.z< -4.5,"Crouched capsule actually enters low tunnel")
		release();await ticks(15)
		check(actor.is_crouching and not actor._can_stand(),"Releasing Ctrl cannot expand through ceiling")
		check(actor.camera.global_position.y<1.21,"Crouched head/nearplane clears ceiling")
		camera_contract();key(KEY_W,true);await ticks(80);release();await ticks(10)
		check(actor.global_position.z< -8.5 and not actor.is_crouching,"Auto stand only after leaving low ceiling")
		check(absf(feet())<.005,"Tunnel transition preserves floor support")
		await reset_actor();key(KEY_W,true);await ticks(100)
		check(actor.global_position.z> -6.7,"Ordinary wall physically blocks movement")
		await ticks(60)
		check((actor.camera.position-actor._neutral_camera_position()).length()<.0001,"Pushing blocked wall produces no bob")
		key(KEY_CTRL,true);await ticks(3);key(KEY_CTRL,false);await ticks(3)
		check(not actor.is_crouching,"Standing beside wall is not falsely blocked")
		await reset_actor();key(KEY_W,true);key(KEY_SHIFT,true);await ticks(20)
		paused=true
		check(actor.camera.position==actor._neutral_camera_position() and not actor.is_sprinting,"Pause immediately neutralizes camera and sprint")
		var pause_at:=actor.global_position;await ticks(4);check(actor.global_position==pause_at,"Pause stops actual body")
		paused=false;await ticks(8);check(actor.global_position==pause_at,"Pause held keys cannot restart movement")
		release();await ticks(2);key(KEY_W,true);await ticks(12)
		actor.set_movement_active(false);var dead_at:=actor.global_position;await ticks(6)
		check(actor.global_position==dead_at and actor.velocity==Vector3.ZERO,"Inactive/dead stops body")
		check(actor.camera.position==actor._neutral_camera_position(),"Inactive/dead bob exactly neutral")
		actor.set_movement_active(true);await ticks(6);check(actor.global_position==dead_at,"Inactive/dead held keys suppressed after activation")
		release();await ticks(2);key(KEY_W,true);await ticks(12);check(actor.global_position.distance_to(dead_at)>.2,"Fresh keypress restores movement")
		release();actor.free()
		for scene in PLAYER_SCENES.slice(1):
			actor=new_actor(scene);await ticks(8);key(KEY_CTRL,true);await ticks(2)
			check(actor.is_crouching and absf(actor.camera.position.y-.38)<.002,"Scene family crouch derived from actual authored offset "+scene)
			release();await ticks(2);check(not actor.is_crouching,"Scene family safe stand "+scene);actor.free()
	else:release();actor.free()
	var report:={"passed":failures.is_empty(),"checks":checks,"failures":failures,"physics_rate":Engine.physics_ticks_per_second,"display_server":DisplayServer.get_name(),"render_cap":cap,"records":records,"scope":"Actual current production CharacterBody from campaign scenes; isolated physical floor/wall/1.25m tunnel, genuine physical-key input. No scene,combat,weapon or shared grounded-step edits. Render-cap evidence needs native runs; headless does not prove visualfeel.","player_sha256":FileAccess.get_sha256("res://scripts/player.gd"),"weapon_geometry_sha256":FileAccess.get_sha256("res://scripts/weapon_presentation.gd"),"grounded_step_sha256":FileAccess.get_sha256("res://scripts/grounded_step.gd"),"actual_shot_events":shots.size()}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output).get_base_dir());var f:=FileAccess.open(output,FileAccess.WRITE);f.store_string(JSON.stringify(report,"  ")+"\n");f.close()
	print("MOVEMENT_V9_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"records":records}));quit(0 if failures.is_empty() else 1)
