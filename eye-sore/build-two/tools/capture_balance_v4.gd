extends SceneTree
## Controlled actual-Main HUD/pickup/accepted-shot art evidence. No native combat,
## normal starting route, survival or human acceptance claim.
const LEVELS := ["pale_ward_03","ash_citadel_03","occupied_line_03"]
const GUNS := ["pistol","shotgun","melee","twin_shotgun","rivet_cannon","siege_launcher"]
const POOLS := {"pistol":"pistol","shotgun":"shells","melee":"","twin_shotgun":"shells","rivet_cannon":"rivets","siege_launcher":"rockets"}
const FIELDS := {"pistol":"ammo_pistol","shells":"ammo_shotgun","rivets":"ammo_rivets","rockets":"ammo_rockets"}
var app: Control
var output := "res://verification/combat-balance-v4/art"
var captures: Array[Dictionary]=[]
var events: Array[Dictionary]=[]
var failures: Array[String]=[]
var budget: Dictionary
var current_id := ""
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="):output=arg.trim_prefix("--evidence-dir=")
	call_deferred("run")
func xyz(v: Vector3) -> Array:return [v.x,v.y,v.z]
func xy(v: Vector2) -> Array:return [v.x,v.y]
func fail(message: String) -> bool:
	failures.append(message);push_error("BALANCE_CAPTURE_FAILED: "+message);save_report();quit(1);return false
func record_event(event: Dictionary) -> void:
	var value: Dictionary={"type":String(event.get("type","")),"weapon_id":String(event.get("weapon_id","")),"shot_id":int(event.get("shot_id",0)),"physics_tick":Engine.get_physics_frames()}
	for key in ["amount","ammo","ammo_kind","target_id"]:
		if event.has(key):value[key]=String(event[key]) if event[key] is StringName else event[key]
	events.append(value)
func freeze() -> void:
	app.automated_input=true;app.player.set_physics_process(false);app.player.velocity=Vector3.ZERO
	for enemy in app.combat.enemies:enemy.set_physics_process(false)
func pose(eye: Vector3,target: Vector3) -> void:
	app.player.rotation=Vector3.ZERO;app.player.camera.rotation=Vector3.ZERO
	app.player.global_position=eye-app.player.camera.position;app.player.camera.look_at(target)
	for enemy in app.combat.enemies:enemy.update_presentation()
func ready_weapon(id: StringName) -> bool:
	paused=false
	for tick in 180:
		await physics_frame
		if app.combat.currentweapon==id and app.combat.weapon_phase==&"idle" and app.combat.cooldown<=0:return true
	return fail("Weapon ready timeout "+String(id))
func save_report() -> void:
	var file:=FileAccess.open(output.path_join("captures.json"),FileAccess.WRITE)
	if file!=null:
		file.store_string(JSON.stringify({"status":"passed" if failures.is_empty() else "failed","scope":"Actual Main/native Compatibility, controlled cameras and declared overfilled owned carry snapshot clamped by real campaign policy. Player/AI physics disabled; tree paused only for images. Direct API switches/accepted shots and pickup collection are recorded; no continuous route, native combat, survival or human acceptance claim.","display_server":DisplayServer.get_name(),"video_adapter":RenderingServer.get_video_adapter_name(),"script_sha256":FileAccess.get_sha256("res://tools/capture_balance_v4.gd"),"budget_sha256":FileAccess.get_sha256("res://resources/campaign/balance-budget.json"),"captures":captures,"events":events,"failures":failures},"  ")+"\n");file.close()
func picture(label: String,fixture: String,extra: Dictionary={}) -> bool:
	paused=true;app._process(0.0)
	for frame in 12:await process_frame;RenderingServer.force_draw(false)
	var image:=root.get_texture().get_image();var native: Image=app.world_view.get_texture().get_image()
	if image==null or image.is_empty() or native==null or native.is_empty():return fail("Empty native image "+label)
	var prefix:=current_id+"-"+label;var full:=output.path_join(prefix+".png");var raw:=output.path_join(prefix+"-world.png")
	if image.save_png(full)!=OK or native.save_png(raw)!=OK:return fail("Cannot save "+label)
	var state: Dictionary=app.combat.get_hud_state();var pool: String=POOLS[String(state.weapon_id)]
	var font: Font=app.hud.get_theme_font("font");var font_size: int=app.hud.get_theme_font_size("font_size")
	var text_size:=font.get_multiline_string_size(app.hud.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)
	if text_size.x>app.hud.size.x-28 or text_size.y>app.hud.size.y-8:return fail("HUD overflow "+label)
	var record: Dictionary={"level":current_id,"label":label,"fixture":fixture,"window_png":full,"world_png":raw,"window_sha256":FileAccess.get_sha256(full),"world_sha256":FileAccess.get_sha256(raw),"scene":app.world.scene_file_path,"scene_sha256":FileAccess.get_sha256(app.world.scene_file_path),"camera_position":xyz(app.player.camera.global_position),"camera_rotation":xyz(app.player.camera.global_rotation),"actor_position":xyz(app.player.global_position),"ai_physics_frozen":true,"player_physics_frozen":true,"tree_paused_for_image":paused,"weapon":String(state.weapon_id),"phase":String(state.weapon_phase),"selected_ammo":app.combat.ammo_amount(StringName(pool)) if not pool.is_empty() else 0,"selected_capacity":app.combat.ammo_capacity(StringName(pool)) if not pool.is_empty() else -1,"hud_text":app.hud.text,"hud_text_size":xy(text_size),"hud_size":xy(app.hud.size),"window_dimensions":[image.get_width(),image.get_height()],"native_world_dimensions":[native.get_width(),native.get_height()],"weapon_path":state.weapon_visual_path,"weapon_sha256":FileAccess.get_sha256(state.weapon_visual_path),"muzzle_visible":app.muzzle_image.visible,"event_count":events.size()}
	if app.weapon_image.texture is AtlasTexture:
		var rect: Rect2=app.weapon_image.texture.region;record.native_source_rect=[rect.position.x,rect.position.y,rect.size.x,rect.size.y]
	record.merge(extra);captures.append(record);save_report();print("BALANCE_NATIVE_PHOTO_OK: ",prefix)
	return true
func run() -> void:
	if DisplayServer.get_name()=="headless":fail("Native renderer required");return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output));root.set_flag(Window.FLAG_NO_FOCUS,true);root.size=Vector2i(1280,720)
	budget=JSON.parse_string(FileAccess.get_file_as_string("res://resources/campaign/balance-budget.json"))
	app=load("res://scenes/main.tscn").instantiate();root.add_child(app)
	for level in LEVELS:
		current_id=level;paused=true;app.campaign.seek(level);app.campaign_mode=true;app.stage_id=String(app.campaign.current_level().theme);app.level_complete=false
		app.replace_world({});freeze();app.enter_combat();freeze();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		if not await picture("entry-normal","Controlled actual campaign-level entry with normal initial inventory; direct campaign seek bypasses prior levels."):return
		var snapshot: Dictionary=app.campaign.capture(app.combat)
		snapshot.owned_weapons={&"pistol":true,&"shotgun":true,&"melee":true,&"twin_shotgun":true,&"rivet_cannon":true,&"siege_launcher":true}
		for pool in FIELDS:snapshot[FIELDS[pool]]=int(budget.ammo_caps[pool])+13
		paused=true;app.replace_world(snapshot);app.campaign.entry_snapshot=app.campaign.capture(app.combat);freeze();app.enter_combat();freeze()
		app.combat.combat_event.connect(record_event)
		var spawn: Vector3=app.player.camera.global_position
		for gun in GUNS:
			pose(spawn,spawn+Vector3(0,0,-20))
			if not await ready_weapon(app.combat.currentweapon):return
			if app.combat.currentweapon!=StringName(gun):
				if not app.combat.select_weapon(StringName(gun)):fail("Accepted switch rejected "+gun);return
				if not await ready_weapon(StringName(gun)):return
			if not await picture(gun+"-capacity","Controlled presentation: declared overfilled owned carry clamped by actual campaign Main; accepted native weapon switch."):return
			paused=false
			var resource: Resource=app.combat.weapons[StringName(gun)];var pool: String=POOLS[gun];var before: int=app.combat.ammo_amount(StringName(pool))
			if not app.combat.try_fire():fail("Accepted trigger rejected "+gun);return
			if not pool.is_empty() and app.combat.ammo_amount(StringName(pool))!=before-int(resource.ammo_cost):fail("Accepted shot ammo mismatch "+gun);return
			if not await picture(gun+"-accepted-fire","Controlled direct try_fire accepted shot/ammo event; camera and AI/player physics frozen. This is not native combat.",{"ammo_before":before,"ammo_cost":resource.ammo_cost if not pool.is_empty() else 0}):return
			if not await ready_weapon(StringName(gun)):return
		for pool in FIELDS:
			var item: Node3D=app.world.get_node_or_null("Supply_"+pool+"_entry")
			if item==null:continue
			var chosen: StringName=StringName({"pistol":"pistol","shells":"shotgun","rivets":"rivet_cannon","rockets":"siege_launcher"}[pool])
			if not await ready_weapon(app.combat.currentweapon):return
			if app.combat.currentweapon!=chosen:
				if not app.combat.select_weapon(chosen):fail("Pickup presentation switch rejected");return
				if not await ready_weapon(chosen):return
			var target: Vector3=item.global_position+Vector3(0,.3,0);pose(item.global_position+Vector3(3,2,3),target)
			app.combat.set(FIELDS[pool],int(budget.ammo_caps[pool]));paused=false;app.world.collect(item)
			if not item.visible:fail("Full ordinary supply consumed "+String(item.name));return
			if not await picture("entry-"+pool+"-full-case","Controlled camera showing actual forward-entry ordinary supply retained at full capacity; direct collect API fixture.",{"pickup":String(item.name),"pickup_position":xyz(item.global_position),"offered":int(item.get_meta("amount")),"visible_at_full":item.visible}):return
			paused=false;app.combat.set(FIELDS[pool],int(budget.ammo_caps[pool])-1);app.world.collect(item)
			if item.visible or app.combat.ammo_amount(StringName(pool))!=int(budget.ammo_caps[pool]):fail("Partial ordinary supply not accepted "+String(item.name));return
			if not await picture("entry-"+pool+"-partial-accepted","Declared one-round deficit then actual collect accepted exactly remaining capacity; no gameplay ammo economy claim.",{"pickup":String(item.name),"accepted_deficit":1,"hidden_after_acceptance":not item.visible}):return
	save_report();print("BALANCE_NATIVE_CAPTURE_OK: ",captures.size()," pictures; events=",events.size());await app.quit_game()
