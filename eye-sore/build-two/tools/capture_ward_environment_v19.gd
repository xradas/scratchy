extends SceneTree
## Native Compatibility render of the authored bridge and its exterior basin.
## Example: tools/godot.sh --position 20000,20000 --audio-driver Dummy \
##   --script tools/capture_ward_environment_v19.gd -- --output=/tmp/ward-v19
var output := "/tmp/ward-v19"

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	call_deferred("capture")

func capture() -> void:
	root.size = Vector2i(960, 540)
	DirAccess.make_dir_recursive_absolute(output)
	var scene: PackedScene = load("res://scenes/campaign/pale_ward_03.tscn")
	assert(scene != null)
	var world: Node3D = scene.instantiate()
	root.add_child(world)
	world.scan(world)
	world.set_physics_process(false)
	var actor: CharacterBody3D = world.get_node("Player")
	actor.set_physics_process(false)
	var camera: Camera3D = world.get_node("Player/Camera3D")
	var views := [
		{"name":"bridge-deck", "at":Vector3(0,-2.25,120), "toward":Vector3(22,-7,152)},
		{"name":"bridge-basin", "at":Vector3(0,-2.25,128), "toward":Vector3(22,-8,158)},
	]
	for view in views:
		camera.global_position = view.at
		camera.look_at(view.toward)
		camera.current = true
		for frame in 30:
			await process_frame
			RenderingServer.force_draw(false)
		var image: Image = root.get_texture().get_image()
		var path := output.path_join("pale-ward-03-"+view.name+".png")
		assert(image.save_png(path) == OK)
		print("WARD_ENVIRONMENT_CAPTURE ",path)
	quit()
