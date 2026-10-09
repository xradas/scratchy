extends SceneTree
const SpriteHurt := preload("res://scripts/sprite_hurt_geometry.gd")
var enemy: CharacterBody3D

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var args: Dictionary = {}
	for argument in OS.get_cmdline_user_args():
		var parts := argument.trim_prefix("--").split("=", true, 1)
		if parts.size() == 2: args[parts[0]] = parts[1]
	var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/combat_art.json")).enemies.unsealed.duplicate(true)
	if args.has("registration"):
		metadata = JSON.parse_string(FileAccess.get_file_as_string(args.registration)).unsealed_registration
	var image := Image.load_from_file(metadata.file)
	assert(image != null)
	var checksum := FileAccess.get_sha256(metadata.file)
	var texture := ImageTexture.create_from_image(image)
	texture.take_over_path("res://verification/style-v2/s03/cache-isolation/" + checksum + ".png")
	var other := ImageTexture.create_from_image(image)
	other.take_over_path("res://verification/style-v2/s03/cache-isolation/other-path-" + checksum + ".png")
	enemy = load("res://scenes/combat_enemy.tscn").instantiate()
	enemy.definition = load("res://resources/enemies/unsealed.tres").duplicate()
	enemy.set_physics_process(false)
	root.add_child(enemy)
	enemy.position.y = enemy.get_node("CollisionShape3D").shape.height * 0.5
	var original_capsule_height: float = enemy.get_node("CollisionShape3D").shape.height
	var original_capsule_radius: float = enemy.get_node("CollisionShape3D").shape.radius
	enemy.configure_sprite_texture(texture, metadata.columns, metadata.directions, {}, metadata.pixel_size, Vector2(metadata.foot_pivot[0], metadata.foot_pivot[1]), metadata.sprite_options)
	var cell := Vector2i(image.get_width() / 4, image.get_height() / 2)
	var records: Array = []
	for frame in 8:
		enemy.dead = frame >= 6; enemy.velocity = Vector3.ZERO; enemy.state_time = 0.0
		if frame < 3:
			enemy.state = &"chase"
			if frame > 0: enemy.velocity.x = 1.0; enemy.state_time = 0.125 if frame == 2 else 0.0
		elif frame == 3: enemy.state = &"windup"
		elif frame == 4: enemy.state = &"recovery"
		elif frame == 5: enemy.state = &"pain"
		else: enemy.state = &"dead"; enemy.state_time = 1.0 if frame == 7 else 0.0
		enemy.update_presentation()
		await physics_frame; await physics_frame
		assert(enemy.sprite.frame == frame)
		assert(absf(enemy.sprite_pivot.global_position.y) < 0.00001)
		var expected_foot: Array = metadata.sprite_options.frame_pivots[str(frame)]
		assert(enemy.sprite_foot.is_equal_approx(Vector2(expected_foot[0], expected_foot[1])))
		var hits := 0
		var misses := 0
		if frame < 6:
			for gy in range(4, 192, 8):
				for gx in range(4, 128, 8):
					var uv := Vector2((gx + 0.5) / 128.0, (gy + 0.5) / 192.0)
					var pixel := Vector2i(int(uv.x * cell.x), int(uv.y * cell.y)) + Vector2i((frame % 4) * cell.x, (frame / 4) * cell.y)
					var expected := image.get_pixelv(pixel).a >= 0.5
					var point: Vector3 = enemy.sprite_pivot.to_global(Vector3((uv.x * cell.x - enemy.sprite_foot.x) * metadata.pixel_size, (enemy.sprite_foot.y - uv.y * cell.y) * metadata.pixel_size, 0))
					var query := PhysicsRayQueryParameters3D.create(point + Vector3(0, 0, 2), point - Vector3(0, 0, 2), 4)
					var hit := enemy.get_world_3d().direct_space_state.intersect_ray(query)
					assert(not hit.is_empty() == expected)
					if expected:
						assert(hit.collider.get_meta("hit_material") == &"flesh")
						hits += 1
					else: misses += 1
		else:
			for body in enemy.hurt_shapes: assert(body.collision_layer == 0)
		records.append({"frame": frame, "foot": expected_foot, "ground_y": enemy.sprite_pivot.global_position.y, "opaque_hits": hits, "transparent_misses": misses, "corpse_queries_disabled": frame >= 6})
	var cache_before := SpriteHurt.frame_cache.size()
	SpriteHurt.build(texture, 4, 2, 0, enemy.sprite.pixel_size, Vector2(metadata.foot_pivot[0], metadata.foot_pivot[1]), enemy.sprite_data)
	assert(SpriteHurt.frame_cache.size() == cache_before)
	SpriteHurt.build(other, 4, 2, 0, enemy.sprite.pixel_size, Vector2(metadata.foot_pivot[0], metadata.foot_pivot[1]), enemy.sprite_data)
	assert(SpriteHurt.frame_cache.size() == cache_before + 1)
	assert(SpriteHurt.image_cache.has(texture.resource_path) and SpriteHurt.image_cache.has(other.resource_path))
	assert(FileAccess.get_sha256(metadata.file) == checksum)
	assert(enemy.get_node("CollisionShape3D").shape.height == original_capsule_height)
	assert(enemy.get_node("CollisionShape3D").shape.radius == original_capsule_radius)
	var output: String = args.get("output", "res://verification/style-v2/s03/existing-atlas-runtime.json")
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"source": metadata.file, "sha256": checksum, "source_unchanged": true, "capsule_unchanged": true, "cache_reuse": true, "cache_path_hash_isolation": true, "pixel_size": metadata.pixel_size, "cell_dimensions": [cell.x, cell.y], "frames": records, "scope": "Native sprite contacts at bounded 128x192 raster sample centers; frontal poses only."}, "  ") + "\n")
	file.close()
	print("REGISTRATION_RUNTIME_OK: 8 grounded poses; native alpha contacts; corpse disabled; path/hash isolated caches; capsule unchanged")
	enemy.free(); enemy = null
	SpriteHurt.frame_cache.clear(); SpriteHurt.image_cache.clear()
	await process_frame; quit()
