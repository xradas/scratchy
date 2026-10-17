extends SceneTree
## Controlled native Compatibility views of the changed room shells.
var output := "/tmp/eyesore-v21-room-views"

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(960, 540)
	DirAccess.make_dir_recursive_absolute(output)
	var views := {
		"pale_ward_01": [
			["processing", Vector3(-51, 2.95, 91), Vector3(-31, 3.5, 68)],
			["sterile", Vector3(24, 2.95, 0), Vector3(56, 3.5, 0)],
		],
		"pale_ward_02": [
			["purge", Vector3(51, 0.95, -68), Vector3(30, 1.5, -92)],
			["waste-access", Vector3(24, 4.95, 0), Vector3(56, 5.5, 0)],
		],
	}
	for level_id in views:
		var world: Node3D = load("res://scenes/campaign/"+level_id+".tscn").instantiate()
		root.add_child(world)
		world.scan(world)
		world.set_physics_process(false)
		var actor: CharacterBody3D = world.get_node("Player")
		actor.set_physics_process(false)
		var camera: Camera3D = world.get_node("Player/Camera3D")
		for view in views[level_id]:
			camera.global_position = view[1]
			camera.look_at(view[2])
			camera.current = true
			for frame in 12:
				await process_frame
				RenderingServer.force_draw(false)
			var path := output.path_join(level_id+"-"+view[0]+".png")
			assert(root.get_texture().get_image().save_png(path) == OK)
			print("ROOM_VARIATION_CAPTURE ", path)
		world.queue_free()
		await process_frame
	quit()
