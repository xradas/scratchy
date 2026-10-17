extends SceneTree
## Isolated actual Main verification; production manifest remains untouched.
const P = preload("res://scripts/weapon_presentation.gd")
const WINDOWS = [Vector2i(1280,720),Vector2i(800,600),Vector2i(1560,900)]
var failures: Array[String] = []
var checks := 0
var records := []
var shots: Array[Dictionary] = []
func on_event(event: Dictionary) -> void:
	if event.get("type") == &"shot": shots.append(event.duplicate())
func require(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message);push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/production-v8/twin-presentation.json"))
	var candidate: Dictionary = spec.patch.weapon_atlases.twin_shotgun
	var before_hash := FileAccess.get_sha256("res://assets/combat_art.json")
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app);app.enter_combat();app.automated_input=true
	app.player.set_physics_process(false);app.combat.set_physics_process(false)
	for enemy in app.combat.enemies:enemy.set_physics_process(false)
	require(app.art_data.weapon_atlases.twin_shotgun==candidate,"Live manifest differs from candidate")
	app.combat.grant_weapon(&"twin_shotgun",100)
	app.combat.currentweapon=&"twin_shotgun"
	app.combat.combat_event.connect(on_event)
	paused=true
	for window in WINDOWS:
		root.size=window;app.size=window;app.layout_view()
		app.combat.weapon_phase=&"idle";app.combat.recoil_remaining=0.0
		app._process(0.0)
		var factor: float=app.weapon_image.size.x/float(candidate.regions.idle[2])
		var origin: Vector2=app.weapon_image.position
		var aim:=Vector2(320,180)
		var bores=[]
		for bore in candidate.placement.idle.bores:
			var breech: Vector2=origin+P.point(bore.breech)*factor
			var muzzle: Vector2=origin+P.point(bore.muzzle)*factor
			var residual: float=absf(P.line_x_at_y(breech,muzzle,180.0)-320.0)
			require(residual<0.01,"Painted barrel misses actual native aim "+str(window))
			bores.append({"muzzle":[muzzle.x,muzzle.y],"breech":[breech.x,breech.y],"residual":residual})
		var grip:=origin+Vector2(450,350)*factor
		require(grip.y<320,"Trigger grip still hidden by bottom HUD "+str(window))
		require(app.player.camera.project_ray_normal(aim).distance_to(-app.player.camera.global_basis.z)<0.0001,"Camera ray moved")
		require((app.crosshair.position+app.crosshair.size*.5).distance_to(Vector2(window)*.5)<0.01,"Window crosshair off center")
		var screen_center:=P.to_window(aim,Vector2(window))
		require(screen_center.distance_to(Vector2(window)*.5)<0.01,"Letterbox aim moved")
		records.append({"window":[window.x,window.y],"bores":bores,"trigger_grip_native":[grip.x,grip.y],"recoil":app.combat.recoil_remaining})
	var idle_receiver: Vector2=P.pose(candidate.placement.idle,Vector2(780,520),512).position+Vector2(386,300)*.38671875
	for phase in ["idle","fire","recover","switch"]:
		require(candidate.placement[phase].scale==.55,phase+" changed authored size")
		require(candidate.regions[phase]==candidate.regions.idle,phase+" changed physical source anatomy")
	for phase in ["idle","fire","recover"]:
		for kick in [0.0,1.0,3.0,5.5,8.0,11.0]:
			var projected: Dictionary=P.pose(candidate.placement[phase],Vector2(780,520),512,Vector2(640,360),kick)
			require(projected.muzzles.size()==2,phase+" missing physical dual muzzle origins")
			for bore in projected.bores:require(absf(bore.aim_x-320)<.01,phase+" real barrel moved away from centered aim during recoil")
			var receiver: Vector2=projected.position+Vector2(386,300)*projected.scale
			require(receiver.distance_to(idle_receiver)<3.0,phase+" receiver jumps during recoil")
	var idle_pose: Dictionary=P.pose(candidate.placement.idle,Vector2(780,520),512)
	var last_switch_y := INF
	for step in 31:
		var switched: Dictionary=P.pose(candidate.placement.switch,Vector2(780,520),512,Vector2(640,360),0.0,float(step)/30.0)
		require(switched.position.y<=last_switch_y,"Switch lowers again while being raised")
		last_switch_y=switched.position.y
		if step==30:require(switched.position.distance_to(idle_pose.position)<.001,"Switch endpoint jumps into idle")
	# Real accepted-shot cycles at three simulated physics rates; production uses fixed 60 Hz.
	paused=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	for rate in [30,60,120]:
		shots.clear();app.combat.ammo_shotgun=40;app.combat.cooldown=0.0;app.combat.weapon_phase=&"idle"
		var accepted_times: Array[float]=[]
		for step in rate*3:
			var cue_before: int=app.combat_audio.cue_counts.get(&"twin_shotgun_fire",0)
			var ammo_before: int=app.combat.ammo_shotgun
			if app.combat.try_fire():
				accepted_times.append(float(step)/rate)
				app._process(0.0)
				require(app.combat.ammo_shotgun==ammo_before-2,"Two flash sprites consumed extra ammo")
				require(app.combat_audio.cue_counts.get(&"twin_shotgun_fire",0)==cue_before+1,"Two flash sprites emitted duplicate fire audio")
				require(app.muzzle_image.visible and app.muzzle_image_secondary.visible,"Actual shot lacks two flash sprites")
				var actual: Dictionary=P.pose(candidate.placement.fire,Vector2(780,520),512,Vector2(640,360),app.combat.recoil_remaining,0.0)
				require((app.muzzle_image.position+app.muzzle_image.size*.5).distance_to(actual.muzzles[0])<.01,"Left actual flash misses painted muzzle")
				require((app.muzzle_image_secondary.position+app.muzzle_image_secondary.size*.5).distance_to(actual.muzzles[1])<.01,"Right actual flash misses painted muzzle")
				require(not app.combat.try_fire(),"Second flash caused a second accepted shot")
				require(app.combat_audio.cue_counts.get(&"twin_shotgun_fire",0)==cue_before+1 and app.combat.ammo_shotgun==ammo_before-2,"Rejected shot changes audio/ammo")
			app.combat._physics_process(1.0/rate)
		require(shots.size()==3 and app.combat.ammo_shotgun==34,"Duplicate or missing accepted event/ammo at "+str(rate))
		for event in shots:
			require(event.pellets==16,"Pellet count changed")
			require(event.position.distance_to(app.player.camera.global_position)<.0001,"Shot origin moved")
			require(event.direction.distance_to(-app.player.camera.global_basis.z)<.0001,"Shot ray moved")
		for index in range(1,accepted_times.size()):require(absf(accepted_times[index]-accepted_times[index-1]-1.2)<=1.0/rate+.0001,"Cadence depends on presentation rate "+str(rate))
		records.append({"rate":rate,"accepted_times":accepted_times,"shot_events":shots.size(),"shells_used":40-app.combat.ammo_shotgun})
	# Exercise the actual Main phase_progress binding from a real selection.
	app.combat.cooldown=0.0;app.combat.select_weapon(&"pistol")
	app.combat.cooldown=0.0;require(app.combat.select_weapon(&"twin_shotgun"),"Actual Twin selection rejected")
	var switch_samples=[]
	var last_y := INF
	for step in 16:
		app._process(0.0)
		require(app.weapon_image.position.y<=last_y+.001,"Live switch does not raise monotonically")
		last_y=app.weapon_image.position.y
		switch_samples.append({"phase":String(app.combat.weapon_phase),"progress":app.combat.get_hud_state().phase_progress,"sprite_y":last_y})
		app.combat._physics_process(1.0/60.0)
	require(app.combat.weapon_phase==&"idle","Actual switch failed to reach idle")
	require(app.weapon_image.position.distance_to(idle_pose.position)<.01,"Live switch endpoint jumps")
	records.append({"actual_main_switch":switch_samples,"fire_audio_cue_count":app.combat_audio.cue_counts.get(&"twin_shotgun_fire",0)})
	paused=true
	var definition=app.combat.weapons[&"twin_shotgun"]
	require(definition.pellets==16 and definition.ammo_cost==2 and is_equal_approx(definition.cooldown_seconds,1.2),"Twin gameplay constants changed")
	require(FileAccess.get_sha256("res://assets/combat_art.json")==before_hash,"Production manifest mutated")
	require(FileAccess.get_sha256("res://"+String(spec.source_path))==spec.source_sha256,"Source atlas mutated")
	var out=FileAccess.open("res://verification/production-v8/twin/integrated-geometry.json",FileAccess.WRITE)
	out.store_string(JSON.stringify({"checks":checks,"failures":failures,"scope":"Actual Main in-memory idle candidate; both source barrel axes, camera and crosshair tested. Three simulated physics rates accepted-shot cadence/ammo checked (production fixed 60 Hz); real bores stay centered during continuous recoil. Actual integrated dual flash origins, single shot/audio/ammo ownership and Main switch phase binding verified. Does not claim human visual acceptance.","records":records},"  ")+"\n");out.close()
	print("TWIN_V8_CHECK ",checks," checks failures=",failures)
	app.free();quit(0 if failures.is_empty() else 1)
