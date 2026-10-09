extends SceneTree
## Rendering cadence may vary; stair speed and support remain on the fixed physics clock.
var records: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func key(pressed: bool) -> void:
	var event := InputEventKey.new(); event.physical_keycode = KEY_W; event.keycode = KEY_W
	event.pressed = pressed; Input.parse_input_event(event); Input.flush_buffered_events()

func run() -> void:
	if DisplayServer.get_name() != "headless": root.set_flag(Window.FLAG_NO_FOCUS, true)
	for cap in [30, 60, 120]:
		Engine.max_fps = cap
		var world: Node3D = load("res://scenes/pale_ward.tscn").instantiate(); root.add_child(world)
		var player: CharacterBody3D = world.get_node("Player")
		player.position = Vector3(0, .87, -5); player.rotation = Vector3.ZERO
		for i in 8: await physics_frame
		var airborne := 0; var max_distance := 0.0
		var before := player.position; var first_frame := Engine.get_frames_drawn()
		key(true)
		for i in 80:
			await physics_frame
			if not player.is_on_floor(): airborne += 1
			var distance := Vector2(player.position.x - before.x, player.position.z - before.z).length()
			max_distance = maxf(max_distance, distance); before = player.position
		key(false)
		# Capsule corners can report a transient unsupported tick while settling on
		# a riser. Bound those transitions and require grounded arrival, no fall.
		assert(airborne <= 4 and player.is_on_floor(), "Stairs lost sustained support at " + str(cap))
		assert(max_distance <= 8.0 / 60.0 + .002, "Step handling accelerated horizontal movement")
		assert(player.position.z < -14 and player.position.y > 2.3)
		records.append({"render_fps_cap":cap,"rendered_frames":Engine.get_frames_drawn()-first_frame,"physics_ticks":80,"end":player.position,"airborne_ticks":airborne,"max_horizontal_tick_distance":max_distance})
		world.free(); await process_frame
	var baseline: Vector3 = records[0].end
	for record in records:
		assert(baseline.distance_to(record.end) < .16, "Render cadence changed fixed-tick movement")
	var file := FileAccess.open("res://verification/level/stair-cadence.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(records,"  ")); file.close()
	print("WARD_MOVEMENT_OK ", JSON.stringify(records)); quit()
