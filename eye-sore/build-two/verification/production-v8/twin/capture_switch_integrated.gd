extends SceneTree
var app: Control
const OUT := "res://verification/production-v8/twin/native-switch"
func _initialize() -> void:call_deferred("run")
func run() -> void:
	if DisplayServer.get_name()=="headless":push_error("Native renderer required");quit(1);return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.set_flag(Window.FLAG_NO_FOCUS,true);root.size=Vector2i(1280,720);root.mode=Window.MODE_MINIMIZED
	app=load("res://scenes/main.tscn").instantiate();root.add_child(app);app.enter_combat();app.automated_input=true
	app.player.set_physics_process(false);app.combat.set_physics_process(false)
	for enemy in app.combat.enemies:enemy.set_physics_process(false)
	app.combat.grant_weapon(&"twin_shotgun",20);app.combat.cooldown=0
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	if not app.combat.select_weapon(&"twin_shotgun"):push_error("Real switch rejected");quit(1);return
	var records=[]
	for step in 15:
		if step in [0,3,7,10,14]:
			paused=true;app._process(0.0)
			for frame in 8:await process_frame;RenderingServer.force_draw(false)
			var path:=OUT.path_join("switch-tick-%02d.png"%step)
			if FileAccess.file_exists(path):push_error("Refusing evidence overwrite");quit(1);return
			root.get_texture().get_image().save_png(path)
			records.append({"file":path,"sha256":FileAccess.get_sha256(path),"tick":step,"phase":String(app.combat.weapon_phase),"phase_progress":app.combat.get_hud_state().phase_progress,"position":[app.weapon_image.position.x,app.weapon_image.position.y],"size":[app.weapon_image.size.x,app.weapon_image.size.y]})
		paused=false;app.combat._physics_process(1.0/60.0);paused=true
	var f=FileAccess.open(OUT.path_join("switch.json"),FileAccess.WRITE);f.store_string(JSON.stringify({"scope":"Actual native Main; real Twin selection, manually stepped existing60Hzswitch timeline, enemy/player physicsfrozen. No source/production edits.","main_sha256":FileAccess.get_sha256("res://scripts/main.gd"),"manifest_sha256":FileAccess.get_sha256("res://assets/combat_art.json"),"captures":records},"  ")+"\n");f.close()
	print("TWIN_INTEGRATED_SWITCH_NATIVE_OK ",records.size());quit()
