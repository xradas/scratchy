extends "res://tools/capture_pickup_art_v6.gd"
## Actual Main, controlled camera; labels disclose the clinical inspection views.
func _initialize() -> void:
	output = "res://verification/production-v9/clinical/art"
	call_deferred("run")
func run() -> void:
	if DisplayServer.get_name()=="headless": fail("Native renderer required"); return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	manifest=JSON.parse_string(FileAccess.get_file_as_string("res://resources/pickups/presentation-v6.json"))
	root.set_flag(Window.FLAG_NO_FOCUS,true);root.size=Vector2i(1280,720);root.mode=Window.MODE_MINIMIZED
	app=load("res://scenes/main.tscn").instantiate();root.add_child(app)
	select_level("pale_ward_01")
	for enemy in app.combat.enemies: enemy.visible=false
	var label := Label.new(); label.position=Vector2(22,18); label.add_theme_font_size_override("font_size",20)
	label.add_theme_color_override("font_outline_color",Color.BLACK);label.add_theme_constant_override("outline_size",8);app.add_child(label)
	var views := [
		["west-bank",Vector3(-12.8,.65,-90.6),Vector3(-16.44,-.25,-90.6),"WEST TRIAGE BANK | 2 beds, shared monitor + screen | ground-level controlled view"],
		["east-bank",Vector3(12.8,.65,-90.6),Vector3(16.44,-.25,-90.6),"EAST TRIAGE BANK | 2 beds, shared monitor + screen | ground-level controlled view"],
		["triage-overview",Vector3(0,7.3,-61),Vector3(0,-.3,-90.6),"TRIAGE LAYOUT | 2 paired-bed banks + north cross-aisle | elevated inspection camera"]]
	for view in views:
		label.text=view[3]
		pose(view[1],view[2])
		room_fixture={"room_id":"arena_one","view":view[0],"label":view[3],"controlled_fixture":"Actual Main/native geometry; camera explicitly placed for clinical layout inspection. Player/enemy physics frozen; enemy visuals hidden. No traversal or combat claim.","enemy_visuals_hidden":true,"focus_inventory":"4 beds,2 monitors,2 privacy screens; full23-item six-room plan is separate measured diagram"}
		if not await picture("clinical-"+String(view[0])): return
	print("CLINICAL_V9_CAPTURE_OK: ",records.size()," views")
	await app.quit_game()
