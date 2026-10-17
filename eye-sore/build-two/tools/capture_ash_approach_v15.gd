extends SceneTree
## Controlled actual-Main native views for Ash Approach art review.

var main: Node
var output := "/tmp/eyesore-ash-approach-v15-art"

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Native renderer required for Ash Approach pictures")
		quit(1)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ash-art-root="):
			output = arg.trim_prefix("--ash-art-root=")
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	root.size = Vector2i(1280, 720)
	AudioServer.set_bus_mute(0, true)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.campaign.seek("ash_citadel_01")
	main.campaign_mode = true
	main.stage_id = "ash_citadel"
	main.level_complete = false
	main.replace_world({})
	main.enter_combat()
	main.world.set_physics_process(false)
	main.player.set_physics_process(false)
	main.combat.set_physics_process(false)
	for enemy in main.combat.enemies:
		enemy.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	DirAccess.make_dir_recursive_absolute(output)
	var poses := [
		["approach", Vector3(0, .87, 8), Vector3(0, 2.4, -10)],
		["bridge_vista", Vector3(0, .87, 8), Vector3(40, 10, 20)],
		["trench", Vector3(-40, -1.13, 8), Vector3(-60, .7, 0)],
		["gatehouse", Vector3(80, 6.87, 8), Vector3(80, 9, -8)],
		["winch", Vector3(40, 6.87, 8), Vector3(40, 9, -8)],
		["cloister", Vector3(80, 2.87, 48), Vector3(80, 5, 26)],
		["furnace_gate", Vector3(40, 2.87, 93), Vector3(40, 5, 66)],
	]
	var records: Array[Dictionary] = []
	for pose in poses:
		main.player.global_position = pose[1]
		main.player.camera.look_at(pose[2], Vector3.UP)
		for frame in 5:
			await process_frame
		RenderingServer.force_draw(false)
		await RenderingServer.frame_post_draw
		var path: String = output.path_join(pose[0] + ".png")
		if root.get_texture().get_image().save_png(path) != OK:
			push_error("Could not capture " + path)
			quit(1)
			return
		records.append({"name": pose[0], "position": pose[1], "look_at": pose[2], "sha256": FileAccess.get_sha256(path)})
	var receipt := {"scope": "Controlled actual-Main Compatibility views. Player and AI physics frozen; no route play or acceptance claim.", "scene_sha256": FileAccess.get_sha256("res://scenes/campaign/ash_citadel_01.tscn"), "captures": records}
	var file := FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(receipt, "  ") + "\n")
	file.close()
	print("ASH_APPROACH_V15_ART_CAPTURE_OK ", output)
	main.combat_audio.stop_all()
	main.menu_music.stop()
	main.menu_music.stream = null
	main.queue_free()
	await process_frame
	quit(0)
