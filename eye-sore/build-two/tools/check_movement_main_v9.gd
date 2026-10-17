extends SceneTree
## Controlled actual Main integration, temporary XDG settings and real movement/shot APIs.
const P=preload("res://scripts/weapon_presentation.gd")
var app: Control
var output:="res://verification/production-v9/movement-main"
var failures:Array[String]=[]
var checks:=0
var records:=[]
var shots:Array[Dictionary]=[]
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="):output=arg.trim_prefix("--evidence-dir=")
	call_deferred("run")
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label);push_error("MOVEMENT_MAIN_V9: "+label)
func xy(v:Vector2)->Array:return [v.x,v.y]
func xyz(v:Vector3)->Array:return [v.x,v.y,v.z]
func key(code:int,down:bool)->void:
	var e:=InputEventKey.new();e.physical_keycode=code;e.keycode=code;e.pressed=down;Input.parse_input_event(e);Input.flush_buffered_events()
func release()->void:
	for code in [KEY_W,KEY_A,KEY_S,KEY_D,KEY_CTRL,KEY_SHIFT]:key(code,false)
func ticks(n:int)->void:
	for i in n:await physics_frame
func on_event(event:Dictionary)->void:
	if event.get("type")==&"shot":shots.append(event.duplicate())
func freeze_others()->void:
	app.automated_input=true;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	for enemy in app.combat.enemies:enemy.set_physics_process(false)
	app.combat.set_physics_process(false)
	if not app.combat.combat_event.is_connected(on_event):app.combat.combat_event.connect(on_event)
func bob_slider()->HSlider:
	var sliders:Array=app.menu.find_children("*","HSlider",true,false)
	check(sliders.size()==3,"Actual menu exposes sensitivity/FOV/bob sliders")
	return sliders[2]
func new_main()->void:
	if is_instance_valid(app):
		if is_instance_valid(app.combat_audio):app.combat_audio.stop_all()
		if is_instance_valid(app.menu_music):app.menu_music.stop();app.menu_music.stream=null
		app.free();await process_frame
	app=load("res://scenes/main.tscn").instantiate();root.add_child(app);app.automated_input=true
	freeze_others()
	for frame in 4:await process_frame;RenderingServer.force_draw(false)
func picture(label:String)->void:
	var was_processing:=app.is_processing();app.set_process(false)
	app._process(0.0)
	for frame in 4:await process_frame;RenderingServer.force_draw(false)
	var path:=output.path_join(label+".png")
	check(not FileAccess.file_exists(path),"Refuse retained screenshot overwrite "+label)
	root.get_texture().get_image().save_png(path)
	records.append({"screenshot":path,"sha256":FileAccess.get_sha256(path),"window":[root.size.x,root.size.y],"phase":String(app.combat.weapon_phase),"camera_global":xyz(app.player.camera.global_position),"camera_local":xyz(app.player.camera.position),"player_global":xyz(app.player.global_position),"crouching":app.player.is_crouching,"sprinting":app.player.is_sprinting})
	app.set_process(was_processing)
func menu_access()->void:
	app.set_paused(true);root.size=Vector2i(640,360)
	await process_frame;app.layout_view()
	for frame in 6:await process_frame;RenderingServer.force_draw(false)
	var scroll:ScrollContainer=app.menu.find_children("*","ScrollContainer",true,false)[0]
	var slider:=bob_slider();slider.grab_focus()
	scroll.ensure_control_visible(slider)
	for frame in 5:await process_frame;RenderingServer.force_draw(false)
	check(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(app.menu.get_global_rect()),"Minimum640 menu fits physical window")
	check(scroll.get_global_rect().encloses(slider.get_global_rect()),"Bob slider reachable inside clipped scrolling viewport at640")
	check(scroll.get_v_scroll_bar().max_value>scroll.size.y,"Actual minimum menu has vertical scroll range")
	await picture("minimum-640-bob-slider-zero")
	var quit_button:Button=null
	for button in app.menu.find_children("*","Button",true,false):
		if button.text=="Quit":quit_button=button
	check(quit_button!=null,"Quit control exists")
	scroll.ensure_control_visible(quit_button);quit_button.grab_focus()
	for frame in 5:await process_frame;RenderingServer.force_draw(false)
	check(scroll.get_global_rect().encloses(quit_button.get_global_rect()),"Bottom settings/Quit reachable at640")
	await picture("minimum-640-bottom-controls")
	records.append({"minimum_settings_scroll":true,"menu_rect":xy(app.menu.global_position)+xy(app.menu.size),"scroll_rect":xy(scroll.global_position)+xy(scroll.size),"scroll_max":scroll.get_v_scroll_bar().max_value,"scroll_value":scroll.scroll_vertical})
func shot(profile:String,weapon:StringName)->void:
	app.combat.currentweapon=weapon;app.combat.weapon_phase=&"idle";app.combat.phase_time=0;app.combat.cooldown=0
	var ammo_field:="ammo_shotgun" if weapon==&"twin_shotgun" else "ammo_pistol"
	var before:int=app.combat.get(ammo_field);var count:=shots.size()
	var cue:=StringName(String(weapon)+"_fire");var cues_before:int=app.combat_audio.cue_counts.get(cue,0)
	check(app.combat.try_fire(),profile+" actual Main accepts "+String(weapon)+" shot")
	check(shots.size()==count+1,profile+" authoritative one shot event")
	var definition=app.combat.weapons[weapon]
	check(app.combat.get(ammo_field)==before-definition.ammo_cost,profile+" exact ammo cost")
	check(app.combat_audio.cue_counts.get(cue,0)==cues_before+1,profile+" one Main fire audio cue")
	if shots.size()>count:
		check(shots[-1].position.distance_to(app.player.camera.global_position)<.0001,profile+" shot starts at translated actual camera")
		check(shots[-1].direction.distance_to(-app.player.camera.global_basis.z)<.0001,profile+" shot follows actual centered camera ray")
	app.player.set_physics_process(false);app._process(0.0)
	var atlas:Dictionary=app.art_data.weapon_atlases[String(weapon)]
	var region:Array=atlas.regions.fire
	var expected:Dictionary=P.pose(atlas.placement.fire,Vector2(region[2],region[3]),float(atlas.source_canvas_height),Vector2(640,360),app.combat.recoil_remaining,0)
	check(app.weapon_image.position.distance_to(expected.position)<.01,profile+" source-registered weapon geometry unaffected by bob/stance")
	check(app.player.camera.project_ray_normal(Vector2(320,180)).distance_to(-app.player.camera.global_basis.z)<.0001,profile+" centered camera projection unchanged")
	check((app.crosshair.position+app.crosshair.size*.5).distance_to(Vector2(root.size)*.5)<.01,profile+" physical crosshair still centered")
	if weapon==&"twin_shotgun":
		check(app.muzzle_image.visible and app.muzzle_image_secondary.visible,profile+" both physical Twin flash sprites visible")
		check((app.muzzle_image.position+app.muzzle_image.size*.5).distance_to(expected.muzzles[0])<.01,profile+" left flash at painted bore")
		check((app.muzzle_image_secondary.position+app.muzzle_image_secondary.size*.5).distance_to(expected.muzzles[1])<.01,profile+" right flash at painted bore")
		for bore in expected.bores:check(absf(bore.aim_x-320)<.01,profile+" painted barrel convergence fixed to actual camera center")
	check(not app.combat.try_fire(),profile+" duplicate request rejected")
	check(app.combat_audio.cue_counts.get(cue,0)==cues_before+1,profile+" duplicate request emits no extra audio")
	await picture(profile+"-"+String(weapon)+"-actual-shot")
	records.append({"profile":profile,"weapon":String(weapon),"shot_id":shots[-1].shot_id,"shot_origin":xyz(shots[-1].position),"shot_direction":xyz(shots[-1].direction),"ammo_before":before,"ammo_after":app.combat.get(ammo_field),"fire_cues_added":app.combat_audio.cue_counts.get(cue,0)-cues_before,"source_pose_position":xy(app.weapon_image.position)})
	app.player.set_physics_process(true)
func profile(name:String,code:int=0)->void:
	release();app.restart_combat();freeze_others();await ticks(8)
	app.combat.grant_weapon(&"twin_shotgun",0)
	if code:key(code,true)
	key(KEY_W,true);await ticks(20)
	check(app.player._movement_active,name+" Main activity binding permits movement")
	check(app.player.is_crouching==(code==KEY_CTRL),name+" actual capsule stance")
	check(app.player.is_sprinting==(code==KEY_SHIFT),name+" actual grounded sprint")
	check(app.player._bob_offset.length()>.001,name+" actual Main grounded bob present")
	await shot(name,&"pistol");await shot(name,&"twin_shotgun")
	release();await ticks(2)
func run()->void:
	check(DisplayServer.get_name()!="headless","Actual native Main required")
	check(not OS.get_environment("XDG_DATA_HOME").is_empty(),"Temporary XDG isolation set")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.set_flag(Window.FLAG_NO_FOCUS,true);root.size=Vector2i(1280,720);root.position=Vector2i(20000,20000)
	check(not FileAccess.file_exists("user://calibration_settings.cfg"),"First boot has no saved settings")
	await new_main()
	check(app.campaign_mode and app.campaign.current_index==0,"Actual Main opens Ward Intake campaign")
	check(app.bob_intensity==.35 and app.player.bob_intensity==.35,"Default bob.35 applied to actual player")
	var slider:=bob_slider();check(slider.min_value==0 and slider.max_value==1 and slider.step==.05,"Actual bob slider includes zero and full range")
	slider.value=0
	check(app.bob_intensity==0 and app.player.bob_intensity==0,"Actual slider zero applies immediately")
	var cfg:=ConfigFile.new();check(cfg.load("user://calibration_settings.cfg")==OK and cfg.get_value("display","bob_intensity",-1)==0,"Actual slider persists zero to tempXDG")
	await menu_access()
	app.restart_combat();freeze_others();check(app.player.bob_intensity==0,"Restart newworld applies saved zero setting")
	key(KEY_W,true);await ticks(20);check(app.player.camera.position==app.player._neutral_camera_position(),"Saved zero remains neutral during actual Main movement")
	release();await ticks(2)
	await new_main();check(app.bob_intensity==0 and bob_slider().value==0 and app.player.bob_intensity==0,"Fresh Main process-equivalent instance reloads persisted zero")
	bob_slider().value=.35;check(app.bob_intensity==.35 and app.player.bob_intensity==.35,"Default intensity reapplied through real settings slider")
	root.size=Vector2i(1280,720);await process_frame;app.layout_view()
	await profile("bob-walk")
	await profile("sprint",KEY_SHIFT)
	await profile("crouch",KEY_CTRL)
	# Real pause/Resume and actual damage-owned death/Retry; held keys remain down.
	release();app.restart_combat();freeze_others();await ticks(8);key(KEY_W,true);key(KEY_SHIFT,true);await ticks(20)
	app.set_paused(true);var paused_at:Vector3=app.player.global_position
	check(app.player.camera.position==app.player._neutral_camera_position() and app.player.velocity==Vector3.ZERO,"Main pause neutralizes camera and movement")
	app.enter_combat();await ticks(6)
	check(app.player.global_position==paused_at,"Resume while movement held suppresses stale keys")
	release();await ticks(2);key(KEY_W,true);key(KEY_CTRL,true);await ticks(12)
	check(app.player.is_crouching,"Death fixture starts from real held crouch")
	var old_shape:int=app.player.body_collision.shape.get_instance_id()
	app.combat.receive_player_damage(1000,"movement_fixture",app.player.global_position)
	check(app.combat.dead and not app.player._movement_active,"Real damage-owned death immediately disables movement")
	await process_frame
	check(paused and app.player.camera.position==app.player._neutral_camera_position(),"Main death pause camera neutral")
	app.enter_combat();freeze_others();await ticks(8)
	check(not app.combat.dead and not app.player.is_crouching and is_equal_approx(app.player.body_collision.shape.height,1.7),"Actual Retry creates standing alive actor")
	check(app.player.body_collision.shape.get_instance_id()!=old_shape,"Retry capsule is unique new resource")
	var retry_at:Vector3=app.player.global_position;await ticks(8)
	check(app.player.global_position==retry_at,"Retry held crouch/movement cannot restart")
	check(app.player.bob_intensity==.35,"Retry applies configured bob")
	release();await ticks(2);key(KEY_W,true);await ticks(12);check(app.player.global_position.distance_to(retry_at)>.2,"Retry fresh movement key accepted")
	# This controlled completion-state call tests the real Continue binding only,
	# explicitly not physical route/progression acceptance.
	release();await ticks(2);key(KEY_W,true)
	app.on_level_completed();await process_frame
	var carry:Dictionary=app.campaign.capture(app.combat)
	app.continue_campaign();freeze_others();await ticks(8)
	check(app.campaign.current_index==1 and not paused,"Actual Continue replaces world and resumes next level")
	check(not app.player.is_crouching and is_equal_approx(app.player.body_collision.shape.height,1.7) and app.player.bob_intensity==.35,"Continue newplayer standing and configured")
	check(app.campaign.entry_snapshot==carry,"Continue exact entryloadout carry unchanged")
	var next_at:Vector3=app.player.global_position;await ticks(8);check(app.player.global_position==next_at,"Continue suppresses stale held movement")
	release();await ticks(2);key(KEY_W,true);await ticks(12);check(app.player.global_position.distance_to(next_at)>.2,"Continue accepts fresh movement key")
	release();app.set_paused(true)
	var result:={"passed":failures.is_empty(),"checks":checks,"failures":failures,"display_server":DisplayServer.get_name(),"temp_user_data_dir":OS.get_user_data_dir(),"settings_saved_path":ProjectSettings.globalize_path("user://calibration_settings.cfg"),"actual_shot_events":shots.size(),"records":records,"scope":"Actual unmodified Main/settings/player/Combat on current authored campaign. AI/Combat automaticphysics frozen, real actor movement and accepted ray APIs retained. Explicit Twin fixture grant. Continue tested through controlled completionstate handler only; not a campaign route or progression claim. TempXDG settings only. Native screenshots unchanged.","main_sha256":FileAccess.get_sha256("res://scripts/main.gd"),"player_sha256":FileAccess.get_sha256("res://scripts/player.gd"),"weapon_geometry_sha256":FileAccess.get_sha256("res://scripts/weapon_presentation.gd"),"scene_sha256":FileAccess.get_sha256("res://scenes/campaign/pale_ward_01.tscn")}
	var f:=FileAccess.open(output.path_join("integration.json"),FileAccess.WRITE);f.store_string(JSON.stringify(result,"  ")+"\n");f.close()
	print("MOVEMENT_MAIN_V9 ",JSON.stringify({"checks":checks,"failures":failures,"shot_events":shots.size()}))
	if is_instance_valid(app.combat_audio):app.combat_audio.stop_all()
	quit(0 if failures.is_empty() else 1)
