extends SceneTree
## Controlled actual Main/native world pickup imagery, not a gameplay route.
var app: Control
var output := "res://verification/pickup-art-v6/art"
var records: Array[Dictionary] = []
var failures: Array[String] = []
var manifest: Dictionary
const ROOM_VIEWS := [["pale_ward_01","arena_one","triage"],["pale_ward_01","key_console","operating-theatre"],["pale_ward_02","arena_one","reservoir"],["pale_ward_02","arena_two","surgery"],["pale_ward_03","arena_one","specimen-silo"],["ash_citadel_01","arena_one","cloister"],["ash_citadel_02","arena_one","choir"],["ash_citadel_03","arena_one","reliquary"],["occupied_line_01","arena_one","platform"],["occupied_line_02","arena_one","administration"],["occupied_line_03","arena_two","reactor"]]
var room_fixture: Dictionary = {}
var room_filter := ""
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--room-filter="):room_filter=arg.trim_prefix("--room-filter=")
	call_deferred("run")
func xyz(v: Vector3) -> Array: return [v.x,v.y,v.z]
func fail(message: String) -> void:
	failures.append(message); push_error("PICKUP_NATIVE_CAPTURE_FAILED: "+message); save_report(); quit(1)
func freeze() -> void:
	app.automated_input = true; app.player.set_physics_process(false); app.player.velocity = Vector3.ZERO
	for enemy in app.combat.enemies:enemy.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE; paused = true
func pose(eye: Vector3, target: Vector3) -> void:
	app.player.rotation = Vector3.ZERO; app.player.camera.rotation = Vector3.ZERO
	app.player.global_position = eye-app.player.camera.position; app.player.camera.look_at(target)
	for enemy in app.combat.enemies:enemy.update_presentation()
func save_report() -> void:
	var file := FileAccess.open(output.path_join("captures.json"),FileAccess.WRITE)
	if file != null:
		var materials: Dictionary = {}
		for path in ["res://assets/materials/room-props-v6/pale_ward-atlas.png","res://assets/materials/room-props-v6/ash_citadel-atlas.png","res://assets/materials/room-props-v6/occupied_line-atlas.png"]:materials[path]=FileAccess.get_sha256(path)
		file.store_string(JSON.stringify({"status":"passed" if failures.is_empty() else "failed","scope":"Actual Main/native Compatibility. Controlled campaign seek/cameras; AI and player physics disabled, tree paused for pickup/room presentation. Existing authored world pickups remain at their real coordinates. No progression flags, grants or collection APIs used. No route, combat, safety or human acceptance claim. No image edits.","display_server":DisplayServer.get_name(),"video_adapter":RenderingServer.get_video_adapter_name(),"window_no_focus":root.get_flag(Window.FLAG_NO_FOCUS),"window_mode":root.mode,"script_sha256":FileAccess.get_sha256("res://tools/capture_pickup_art_v6.gd"),"main_sha256":FileAccess.get_sha256("res://scripts/main.gd"),"manifest_sha256":FileAccess.get_sha256("res://resources/pickups/presentation-v6.json"),"atlas_sha256":manifest.get("source_sha256",""),"room_material_sha256":materials,"room_author_sha256":FileAccess.get_sha256("res://tools/room_program_v6.py"),"captures":records,"failures":failures},"  ")+"\n"); file.close()
func picture(label: String, item: Node3D = null) -> bool:
	paused = true; app._process(0.0)
	for frame in 12:await process_frame; RenderingServer.force_draw(false)
	var full_image := root.get_texture().get_image()
	var world_image: Image = app.world_view.get_texture().get_image()
	if full_image == null or full_image.is_empty() or world_image == null or world_image.is_empty():fail("Empty image "+label);return false
	var full := output.path_join(label+".png");var raw := output.path_join(label+"-world.png")
	if full_image.save_png(full)!=OK or world_image.save_png(raw)!=OK:fail("Cannot save "+label);return false
	var record := {"label":label,"window_png":full,"world_png":raw,"window_sha256":FileAccess.get_sha256(full),"world_sha256":FileAccess.get_sha256(raw),"scene":app.world.scene_file_path,"scene_sha256":FileAccess.get_sha256(app.world.scene_file_path),"camera_position":xyz(app.player.camera.global_position),"camera_rotation":xyz(app.player.camera.global_rotation),"actor_position":xyz(app.player.global_position),"player_physics_frozen":true,"ai_physics_frozen":true,"window_dimensions":[full_image.get_width(),full_image.get_height()],"native_world_dimensions":[world_image.get_width(),world_image.get_height()]}
	record.capture_script_sha256=FileAccess.get_sha256("res://tools/capture_pickup_art_v6.gd")
	record.merge(room_fixture);room_fixture={}
	if item != null:record.merge({"pickup_name":String(item.name),"pickup_kind":String(item.get_meta("stage_pickup")),"pickup_amount":int(item.get_meta("amount",0)),"pickup_position":xyz(item.global_position),"visible":item.visible})
	records.append(record);save_report();print("PICKUP_NATIVE_PHOTO_OK: ",label);return true
func select_level(id: String) -> void:
	paused = true; app.campaign.seek(id); app.campaign_mode = true; app.stage_id = String(app.campaign.current_level().theme); app.level_complete = false
	app.replace_world({}); app.enter_combat(); freeze()
func room_picture(view: Array, overview: bool = false) -> bool:
	select_level(view[0])
	# Environment-only fixture: actor bodies remain, their presentation is
	# hidden so authored furniture can be inspected. Pickup shots retain actors.
	for enemy in app.combat.enemies:enemy.visible=false
	paused=false
	for tick in 2:await physics_frame
	paused=true
	var route: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/campaign/"+String(view[0])+"-route.json"))
	var room: Dictionary = route.rooms[view[1]]
	var center := Vector3(room.center[0],room.center[1],room.center[2])
	var prefix: String = view[0]+"."+view[1]+"."
	var fitting: Node3D = null
	var fitting_nodes: Array[Node3D] = []
	var fitting_count := 0
	for node in app.world.get_children():
		if node is Node3D and String(node.get_meta("room_program_object","")).begins_with(prefix):
			fitting_count+=1
			fitting_nodes.append(node)
			if fitting==null:fitting=node
	if fitting==null:fail("No authored fitting for "+prefix);return false
	var target := fitting.global_position+Vector3(.3,.7,0)
	var eye := fitting.global_position+Vector3(2.5,1.8,3.2)
	var vantage := "near-functional-bay"
	if not overview:
		var selected := false
		var focus_type: String = String(fitting.get_meta("prop_type"))
		for candidate in fitting_nodes:
			if String(candidate.get_meta("prop_type"))!=focus_type:continue
			var inward := Vector3(center.x-candidate.global_position.x,0,center.z-candidate.global_position.z).normalized()
			for distance in [4.0,3.0,5.5]:
				for angle in [0,30,-30,60,-60,90,-90,180]:
					var candidate_eye: Vector3 = candidate.global_position+inward.rotated(Vector3.UP,deg_to_rad(float(angle)))*float(distance)+Vector3(0,1.8,0)
					var candidate_target := candidate.global_position+Vector3(0,.75,0)
					var shape := SphereShape3D.new();shape.radius=.12
					var space: PhysicsDirectSpaceState3D = app.world.get_world_3d().direct_space_state
					var point := PhysicsShapeQueryParameters3D.new();point.shape=shape;point.transform=Transform3D(Basis.IDENTITY,candidate_eye);point.collision_mask=1|4
					if not space.intersect_shape(point,1).is_empty():continue
					var ray := PhysicsRayQueryParameters3D.create(candidate_eye,candidate_target,1|4)
					var hit: Dictionary = space.intersect_ray(ray)
					if not hit.is_empty() and not candidate.is_ancestor_of(hit.collider):continue
					fitting=candidate;eye=candidate_eye;target=candidate_target;selected=true;break
				if selected:break
			if selected:break
		if not selected:fail("No unobstructed native functional-bay camera for "+prefix);return false
		vantage="native-ray-checked-unobstructed-functional-bay"
	if overview:
		var entry := center+Vector3(0,0,float(room.size[2])*.5)
		for portal in route.portals:
			if String(portal.to)==String(view[1]):entry=Vector3(portal.end[0],portal.end[1],portal.end[2]);break
		var inward := Vector3(center.x-entry.x,0,center.z-entry.z).normalized()
		eye=entry+inward*6+Vector3(0,1.65,0)
		target=center+Vector3(0,1.1,0)
		vantage="doorway-aligned-overview-six-metres-inside"
	pose(eye,target)
	room_fixture={"room_id":view[1],"room_function":String(fitting.get_meta("room_function","")),"controlled_fixture":"Camera placed at declared authored doorway alignment or relative to an actual room fitting; enemy visuals hidden for environment presentation, bodies remain; no physical route to vantage claimed.","enemy_visuals_hidden":true,"vantage":vantage,"focus_fitting":String(fitting.get_meta("room_program_object")),"focus_prop_type":String(fitting.get_meta("prop_type")),"room_fitting_count":fitting_count,"camera_target":xyz(target)}
	return await picture(view[0]+"-room-"+view[2]+("-overview" if overview else "-detail"))
func run() -> void:
	if DisplayServer.get_name()=="headless":fail("Native renderer required");return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	manifest = JSON.parse_string(FileAccess.get_file_as_string("res://resources/pickups/presentation-v6.json"))
	root.set_flag(Window.FLAG_NO_FOCUS,true);root.size = Vector2i(1280,720);root.mode = Window.MODE_MINIMIZED
	app = load("res://scenes/main.tscn").instantiate();root.add_child(app)
	root.set_flag(Window.FLAG_NO_FOCUS,true);root.mode = Window.MODE_MINIMIZED
	if not room_filter.is_empty():
		var previous: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(output.path_join("captures.json")))
		for entry in previous.captures:
			if not String(entry.label).begins_with(room_filter+"-room-"):
				if not entry.has("capture_script_sha256"):entry.capture_script_sha256=previous.script_sha256
				records.append(entry)
		for view in ROOM_VIEWS:
			if String(view[0])!=room_filter:continue
			if not await room_picture(view):return
			if not await room_picture(view,true):return
		save_report();print("PICKUP_NATIVE_CAPTURE_UPDATED: ",room_filter," totalviews=",records.size());await app.quit_game();return
	for index in 2:
		if not await room_picture(ROOM_VIEWS[index]):return
		if not await room_picture(ROOM_VIEWS[index],true):return
	select_level("pale_ward_01")
	if not await picture("ward01-authored-entry"):return
	for kind in manifest.items:
		var pickup_level := "pale_ward_03"
		select_level(pickup_level)
		var item: Node3D = null
		for candidate in app.world.pickups:
			var actual := String(candidate.get_meta("stage_pickup"))
			if String(manifest.aliases.get(actual,actual))==kind:item=candidate;break
		if item==null:
			# Ward budgets deliberately contain no ordinary rockets. Use a real
			# existing Citadel supply rather than grant or relocate a fake case.
			pickup_level="ash_citadel_03";select_level(pickup_level)
			for candidate in app.world.pickups:
				var actual := String(candidate.get_meta("stage_pickup"))
				if String(manifest.aliases.get(actual,actual))==kind:item=candidate;break
		if item==null:fail("Actual Ward03/Citadel03 missing supported kind "+kind);return
		if item.get_node_or_null("PresentationV6")==null:fail("No authored art on "+String(item.name));return
		pose(item.global_position+Vector3(.8,.65,1.0),item.global_position+Vector3(0,-.08,0))
		if not await picture(pickup_level+"-"+kind+"-native",item):return
	for index in range(2,ROOM_VIEWS.size()):
		if not await room_picture(ROOM_VIEWS[index]):return
		if not await room_picture(ROOM_VIEWS[index],true):return
	save_report();print("PICKUP_NATIVE_CAPTURE_OK: ",records.size()," views");await app.quit_game()
