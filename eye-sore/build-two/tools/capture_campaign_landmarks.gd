extends SceneTree
## Controlled native Main pictures, not gameplay-route or human pacing evidence.
var app: Control
var captures: Array[Dictionary] = []
var output := "res://verification/campaign-v3/captures"

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Campaign pictures require native renderer")
		quit(1)
		return
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	root.size = Vector2i(1280,720)
	AudioServer.set_bus_mute(0,true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	app = preload("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	for level in app.campaign.levels:
		paused = false
		app.campaign.seek(String(level.id))
		app.campaign_mode = true
		app.stage_id = String(level.theme)
		app.level_complete = false
		app.replace_world({})
		app.enter_combat()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		app.player.set_physics_process(false)
		for enemy in app.combat.enemies: enemy.set_physics_process(false)
		paused = true
		app.layout_view()
		await picture(String(level.id), "arrival")
		for room_name in ["arena_one", "arena_two"]:
			for room in app.world.rooms:
				if String(room.get_meta("stage_room")) != room_name: continue
				var bounds: Vector3 = room.get_meta("room_bounds")
				var floor_center: Vector3 = room.position - Vector3(0,bounds.y-1.0,0)
				var route: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/campaign/"+String(level.id)+"-route.json"))
				var point: Array = route.vertical_routes[room_name+"_gallery"][1]
				app.player.position = Vector3(point[0], point[1]+0.87, point[2])
				app.player.camera.look_at(floor_center + Vector3(5,1.7,-bounds.z * 0.14))
				await picture(String(level.id), room_name)
				break
	var file := FileAccess.open(output.path_join("captures.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"Actual Main/native Compatibility; controlled cameras with player/AI physics frozen and tree paused. No route completion or human acceptance claim.", "captures":captures},"  ")+"\n")
	file.close()
	print("CAMPAIGN_NATIVE_PICTURES_OK ",captures.size())
	app.queue_free()
	paused = false
	await process_frame
	await process_frame
	quit()

func picture(level_id: String, view: String) -> void:
	app._process(0.0)
	for warmup in 8:
		await process_frame
		RenderingServer.force_draw(false)
	var rendered := root.get_texture().get_image()
	var path := output.path_join(level_id+"-"+view+".png")
	if rendered == null or rendered.is_empty() or rendered.save_png(path) != OK:
		push_error("Cannot capture "+path)
		quit(1)
		return
	captures.append({"level":level_id,"view":view,"file":path,"sha256":FileAccess.get_sha256(path),"camera_position":app.player.camera.global_position,"camera_rotation":app.player.camera.global_rotation,"world_size":app.world_view.size,"window_size":root.size})
