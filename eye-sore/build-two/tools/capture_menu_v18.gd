extends SceneTree
## Save one actual title-menu frame for visual review.

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var output := "/tmp/eyesore-menu-v18.png"
	var capture_seconds := 3.0
	var shot_time := -1.0
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
		elif argument.begins_with("--seconds="):
			capture_seconds = float(argument.trim_prefix("--seconds="))
		elif argument.begins_with("--shot-time="):
			shot_time = float(argument.trim_prefix("--shot-time="))
	var app: Control = preload("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	if shot_time >= 0.0: app.menu_flythrough.elapsed = shot_time
	await create_timer(capture_seconds, true).timeout
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(output)
	assert(error == OK)
	assert(app.menu_flythrough.active)
	print("MENU_V18_CAPTURE_OK path=", output, " level=", app.current_level_label(),
		" title_camera=", app.menu_flythrough.camera.current)
	app.queue_free()
	quit()
