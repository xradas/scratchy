extends "res://tools/capture_pickup_art_v6.gd"
## Controlled native scene inspection. No claim of ordinary camera traversal.
func _initialize() -> void:
	output = "res://verification/production-v8/art"
	call_deferred("run")
func save_report() -> void:
	for record in records:
		record["capture_template_sha256"] = FileAccess.get_sha256("res://tools/capture_pickup_art_v6.gd")
		record["capture_script_sha256"] = FileAccess.get_sha256("res://tools/capture_presentation_v8.gd")
	var file := FileAccess.open(output.path_join("captures.json"), FileAccess.WRITE)
	if file == null: return
	file.store_string(JSON.stringify({"status":"passed" if failures.is_empty() else "failed", "scope":"Controlled actual Main native Compatibility room views. Camera placed by fixture, physics/AI frozen and enemy visuals hidden for room inspection. Not physical traversal, live combat or human acceptance. Original PNG outputs unchanged.", "display_server":DisplayServer.get_name(), "video_adapter":RenderingServer.get_video_adapter_name(), "script_sha256":FileAccess.get_sha256("res://tools/capture_presentation_v8.gd"), "scene_sha256":FileAccess.get_sha256("res://scenes/campaign/pale_ward_01.tscn"), "captures":records, "failures":failures}, "  ")+"\n")
	file.close()
func room_picture(view: Array, overview: bool = false) -> bool:
	if not overview: return await super.room_picture(view,false)
	select_level(String(view[0]))
	for enemy in app.combat.enemies: enemy.visible=false
	paused=false
	for frame in 2: await physics_frame
	paused=true
	var route: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://resources/campaign/pale_ward_01-route.json"))
	var room: Dictionary=route.rooms[view[1]]
	var center:=Vector3(room.center[0],room.center[1],room.center[2])
	var fitting: Node3D=null
	var count:=0
	var prefix: String="pale_ward_01."+String(view[1])+"."
	for node in app.world.get_children():
		if node is Node3D and String(node.get_meta("room_program_object","")).begins_with(prefix):
			count+=1
			if fitting==null: fitting=node
	if fitting==null: fail("No working-room fitting "+String(view[1]));return false
	var entry:=center+Vector3(0,0,float(room.size[2])*.5)
	for portal in route.portals:
		if String(portal.to)==String(view[1]):
			entry=Vector3(portal.end[0],portal.end[1],portal.end[2]);break
	var inward:=Vector3(center.x-entry.x,0,center.z-entry.z).normalized()
	var eye:=entry+inward*2.0+Vector3(0,1.65,0)
	var target:=fitting.global_position+Vector3(0,1.5,0)
	pose(eye,target)
	room_fixture={"room_id":view[1],"room_function":String(fitting.get_meta("room_function","")),"controlled_fixture":"Room doorway camera two metres inside, directed at the actual first working fitting. Not a physical route to vantage.","enemy_visuals_hidden":true,"vantage":"doorway-to-functional-work-cell","camera_target":xyz(target),"focus_fitting":String(fitting.get_meta("room_program_object")),"room_fitting_count":count}
	return await picture("pale_ward_01-room-"+String(view[2])+"-overview")
func run() -> void:
	if DisplayServer.get_name()=="headless": fail("Native renderer required"); return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	manifest = JSON.parse_string(FileAccess.get_file_as_string("res://resources/pickups/presentation-v6.json"))
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	root.size=Vector2i(1280,720)
	root.mode=Window.MODE_MINIMIZED
	app=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	root.mode=Window.MODE_MINIMIZED
	for room in [["entry","reception"],["service","decontamination"],["arena_one","triage"],["key_wing","diagnostics"],["key_console","operating-theatre"],["return_store","sterile-return"]]:
		var view: Array=["pale_ward_01",room[0],room[1]]
		if not await room_picture(view,true):return
		if String(room[0]) in ["arena_one","key_console"]:
			if not await room_picture(view,false):return
	save_report()
	print("PRESENTATION_V8_CAPTURE_OK: ",records.size()," views")
	await app.quit_game()
