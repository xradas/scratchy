extends SceneTree
## Shared mounted-light contract in the three authored Pale Ward campaign scenes.
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("LIGHTING_DISTANCE: " + label)

func run() -> void:
	check(RenderingServer.get_current_rendering_method() == "gl_compatibility", "Compatibility renderer")
	for index in range(1, 4):
		var path := "res://scenes/campaign/pale_ward_%02d.tscn" % index
		var world := (load(path) as PackedScene).instantiate() as Node3D
		root.add_child(world)
		var fixtures := get_nodes_in_group("intake_lighting_v11")
		check(fixtures.size() >= 20, "%s has mounted fixtures" % path)
		for fixture in fixtures:
			var light: Light3D = fixture.light
			check(light.distance_fade_enabled, "%s/%s distance fade enabled" % [path, fixture.name])
			check(light.distance_fade_begin >= fixture.reach * 2.5, "%s/%s fade beyond spill" % [path, fixture.name])
			check(light.distance_fade_length >= 12.0, "%s/%s gradual fade" % [path, fixture.name])
			check(light.position == Vector3(0, 0, -.055), "%s/%s fixed lens emitter" % [path, fixture.name])
			for child in fixture.get_children():
				check(not child is CollisionObject3D, "%s/%s non-colliding fixture" % [path, fixture.name])
			check(is_equal_approx(light.light_energy, fixture.energy), "%s/%s authored energy" % [path, fixture.name])
			fixture.elapsed = 1.0
			fixture.reset_lighting()
			check(fixture.elapsed == 0.0 and is_equal_approx(light.light_energy, fixture.energy), "%s/%s reset" % [path, fixture.name])
		paused = true
		var paused_state: Dictionary = fixtures[0].lighting_state()
		fixtures[0]._process(.5)
		check(fixtures[0].lighting_state() == paused_state, "%s pause freezes fixture" % path)
		paused = false
		world.free()
		for frame in 2:
			await process_frame
	print("LIGHTING_DISTANCE: checks=", checks, " failures=", failures.size(), " renderer=", RenderingServer.get_current_rendering_method(), " display=", DisplayServer.get_name())
	quit(0 if failures.is_empty() else 1)
