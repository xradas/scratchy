extends SceneTree
## Bounded six-species integration audit. --resources-only is an early definition
## check; default requires registered art, authored stage rosters and live attacks.
var failures: Array[String] = []
var checks := 0
var resources_only := false
var evidence_path := "res://verification/expansion-v1/enemies/integration.json"
var report := {"species": {}, "stages": {}, "checks": 0, "failures": []}
var fixture: Node3D
var combat: Node3D
var player: CharacterBody3D
var trace: Array[Dictionary] = []
const KINDS := ["unsealed", "vessel", "ironbound", "censer", "reaver", "surveyor"]
const EXPECTED := {
	"ironbound": [120.0, 2.65, false, 18.0, 2.05, .70, .85, .24, 9.0],
	"censer": [180.0, 1.8, true, 16.0, 18.0, .80, 1.10, .24, 8.0],
	"reaver": [100.0, 3.4, false, 14.0, 1.9, .52, .72, .18, 9.0],
	"surveyor": [140.0, 2.25, true, 12.0, 20.0, .60, .88, .22, 10.0]}
const PROPERTY_ORDER := ["health", "speed", "ranged", "damage", "attack_range", "windup_seconds", "recovery_seconds", "pain_seconds", "projectile_speed"]

func _initialize() -> void:
	Engine.physics_ticks_per_second = 60; Engine.max_fps = 120
	for arg in OS.get_cmdline_user_args():
		if arg == "--resources-only": resources_only = true
		if arg.begins_with("--evidence-path="): evidence_path = arg.trim_prefix("--evidence-path=")
	call_deferred("run")

func check(value: bool, message: String) -> bool:
	checks += 1
	if not value: failures.append(message); push_error("EXPANSION_ENEMIES_FAILED: " + message)
	return value

func frames(count: int) -> void:
	for i in count: await physics_frame

func definitions() -> void:
	for kind in KINDS:
		var data: EnemyDefinition = load("res://resources/enemies/%s.tres" % kind)
		if not check(data != null, kind + " definition exists"): continue
		check(String(data.identifier) == kind, kind + " stable resource identifier")
		check(data.audio_bus == &"Creatures", kind + " creature audio bus retained")
		var values: Dictionary = {}
		for key in PROPERTY_ORDER: values[key] = data.get(key)
		if EXPECTED.has(kind):
			var visible_height := {"ironbound": 2.05, "censer": 1.6, "reaver": 2.15, "surveyor": 2.2}
			check(is_equal_approx(float(data.get_meta("visible_height_m", 0)), visible_height[kind]), kind + " visible height metadata")
			for i in PROPERTY_ORDER.size():
				var value: Variant = data.get(PROPERTY_ORDER[i])
				check(value == EXPECTED[kind][i] if value is bool else is_equal_approx(float(value), float(EXPECTED[kind][i])), kind + " contract " + PROPERTY_ORDER[i])
		report.species[kind] = {"definition": values}

func stage_rosters() -> void:
	var contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/expansion-v1/contract.json"))
	for stage in contract.stages:
		if not check(ResourceLoader.exists(stage.scene), stage.id + " authored stage exists"): continue
		var scene: PackedScene = load(stage.scene)
		var level := scene.instantiate()
		var markers := level.get_node_or_null("EnemySpawns")
		if check(markers != null, stage.id + " has authored enemy markers"):
			var roster: Dictionary = {}
			for marker in markers.get_children():
				var kind := String(marker.get_meta("kind", ""))
				check(kind in stage.enemy_kinds, stage.id + " themed species " + kind)
				check(marker.has_meta("arena_id"), stage.id + " spawn arena membership")
				roster[kind] = int(roster.get(kind, 0)) + 1
			for kind in stage.enemy_kinds: check(roster.has(kind), stage.id + " includes " + kind)
			report.stages[stage.id] = roster
		level.free()

func make_fixture() -> void:
	fixture = Node3D.new(); root.add_child(fixture)
	var floor_body := StaticBody3D.new(); floor_body.position.y = -.1; fixture.add_child(floor_body)
	var floor_shape := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = Vector3(100, .2, 100); floor_shape.shape = box; floor_body.add_child(floor_shape)
	player = CharacterBody3D.new(); player.collision_layer = 2; player.collision_mask = 3; fixture.add_child(player)
	var shape := CollisionShape3D.new(); var capsule := CapsuleShape3D.new(); capsule.height = 1.7; capsule.radius = .32; shape.shape = capsule; player.add_child(shape)
	var camera := Camera3D.new(); camera.name = "Camera3D"; camera.position.y = .60; camera.current = true; player.add_child(camera)
	combat = load("res://scripts/combat.gd").new(); fixture.add_child(combat); combat.setup(fixture, player); combat.set_physics_process(false)
	combat.combat_event.connect(func(event: Dictionary): trace.append(event.duplicate(true)))
	for enemy in combat.enemies:
		enemy.set_physics_process(false); enemy.collision_layer = 0; enemy.position = Vector3(70, .85, 70)

func art_entry(kind: String, manifest: Dictionary) -> Dictionary:
	if manifest.get("enemies", {}).has(kind): return manifest.enemies[kind]
	var path := "res://verification/expansion-v1/enemies/%s-candidate.json" % kind
	if FileAccess.file_exists(path):
		var candidate: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		# Rejected art can still expose adapter/gameplay faults in this audit.
		# Its failed measurement keeps the overall report failed, so exercising
		# the pixels never promotes a candidate into accepted runtime artwork.
		check(bool(candidate.get("quality_pass", false)), kind + " candidate measurement passed")
		return candidate.enemies[kind]
	check(false, kind + " registered art entry missing"); return {}

func material_contacts(enemy: CharacterBody3D, label: String) -> void:
	await frames(2)
	var bodies: Dictionary = enemy.corpse_bodies if enemy.dead else enemy.sprite_bodies
	for material in bodies:
		var body: StaticBody3D = bodies[material]
		var shape: ConcavePolygonShape3D = body.get_node("HitSurface").shape
		if shape == null: continue
		var faces := shape.get_faces()
		if not check(faces.size() >= 3, label + " opaque geometry " + String(material)): continue
		check(body.collision_layer == (8 if enemy.dead else 4), label + " anatomical query layer " + String(material))
		var point: Vector3 = body.to_global((faces[0] + faces[1] + faces[2]) / 3.0)
		var normal: Vector3 = enemy.sprite_pivot.global_basis.z
		var hit: Dictionary = combat.ray(point + normal * .2, point - normal * .2, [player.get_rid(), enemy.get_rid()], true)
		check(not hit.is_empty() and hit.collider.get_meta("combat_target", null) == enemy and combat.material_for(hit.collider) == material, label + " actual mapped " + String(material) + " ray contact")

func event_count(kind: String, target_id: String) -> int:
	var count := 0
	for event in trace:
		if String(event.type) == kind and String(event.get("target_id", "")) == target_id: count += 1
	return count

func audit_native_frames(enemy: CharacterBody3D, kind: String, options: Dictionary) -> void:
	var image: Image = enemy.sprite_source_texture.get_image()
	if image.is_compressed(): image.decompress()
	var original_poses: Dictionary = enemy.sprite_data.poses.duplicate(true)
	for frame in enemy.sprite_source_columns * enemy.sprite_source_rows:
		var rect: Rect2i = preload("res://scripts/sprite_hurt_geometry.gd").frame_region(enemy.sprite_source_texture, enemy.sprite_source_columns, enemy.sprite_source_rows, frame, enemy.sprite_data)
		var width: int = rect.size.x; var height: int = rect.size.y
		# Isolated presentation audit selects the original cell directly; AI stays
		# disabled here. Live attack and actual pain/death selection are checked later.
		enemy.sprite_data.poses.pain = [frame]; enemy.state = &"pain"; enemy.state_time = 0
		enemy.update_presentation()
		var foot: Array = options.frame_pivots[str(frame)]
		check(enemy.sprite_frame == frame and enemy.sprite_foot == Vector2(foot[0], foot[1]), "%s cell%d measured foot pivot" % [kind, frame])
		if enemy.sprite.texture is AtlasTexture:
			check((enemy.sprite.texture as AtlasTexture).region == Rect2(rect), "%s cell%d render/query source rectangle identical" % [kind, frame])
			var presented: Image = enemy.sprite.texture.get_image()
			if presented.is_compressed(): presented.decompress()
			check(presented.get_size() == rect.size and presented.get_data() == image.get_region(rect).get_data(), "%s cell%d runtime texture contains exact native source pixels" % [kind, frame])
		await material_contacts(enemy, "%s/cell%d" % [kind, frame])
		var uv := Vector2(.5 / 128.0, .5 / 192.0)
		var origin := rect.position
		var alpha := image.get_pixelv(origin + Vector2i(int(uv.x * width), int(uv.y * height))).a
		if alpha < float(options.get("alpha_threshold", .5)):
			var point: Vector3 = enemy.sprite_pivot.to_global(Vector3((uv.x * width - enemy.sprite_foot.x) * enemy.sprite.pixel_size, (enemy.sprite_foot.y - uv.y * height) * enemy.sprite.pixel_size, 0))
			var normal: Vector3 = enemy.sprite_pivot.global_basis.z
			var hit: Dictionary = combat.ray(point + normal * .2, point - normal * .2, [player.get_rid(), enemy.get_rid()], true)
			check(hit.is_empty() or hit.collider.get_meta("combat_target", null) != enemy, "%s cell%d native transparent corner misses anatomy" % [kind, frame])
	enemy.sprite_data.poses = original_poses; enemy.state = &"chase"; enemy.state_time = 0; enemy.update_presentation()

func exercise(kind: String, entry: Dictionary) -> void:
	if entry.is_empty(): return
	var enemy: CharacterBody3D = combat.spawn_enemy(StringName(kind), Vector3(0, .85, 0))
	enemy.set_physics_process(false)
	var options: Dictionary = entry.sprite_options
	var pivot: Array = entry.foot_pivot
	enemy.configure_sprite_sheet(entry.file, int(entry.columns), int(entry.directions), {}, float(entry.pixel_size), Vector2(pivot[0], pivot[1]), options)
	if not check(is_instance_valid(enemy.sprite), kind + " spawned sprite configured"): enemy.queue_free(); return
	check(FileAccess.get_sha256(entry.file) == String(entry.get("sha256", FileAccess.get_sha256(entry.file))), kind + " native registered source hash")
	var dimensions: Array = entry.get("source_dimensions", [1536, 1024])
	check(enemy.sprite_source_texture.get_size() == Vector2(dimensions[0], dimensions[1]), kind + " native dimensions retained")
	player.position = Vector3(0, .85, -4); enemy.rotation.y = 0
	await audit_native_frames(enemy, kind, options)
	if EXPECTED.has(kind):
		check(enemy.sprite_source_columns == 4 and enemy.sprite_source_rows == 4, kind + " sixteen cells")
		check(enemy.sprite.texture is AtlasTexture and enemy.sprite.hframes == 1 and enemy.sprite.vframes == 1, kind + " native rectangle presentation")
		for direction in 8:
			var angle: float = direction * TAU / 8.0
			player.position = Vector3(-sin(angle) * 4, .85, -cos(angle) * 4)
			enemy.update_presentation()
			check(enemy.sprite_frame == direction, "%s directional facing %d" % [kind, direction])
			await material_contacts(enemy, "%s/facing%d" % [kind, direction])
	player.position = Vector3(0, .85, -1.4 if not enemy.definition.ranged else -5.0)
	enemy.update_presentation(); await frames(2)
	combat.health = 10000; combat.armor = 0
	var health_before: float = combat.health
	enemy.awake = true; enemy.set_physics_process(true)
	var release_event := "projectile_release" if enemy.definition.ranged else "enemy_melee_release"
	for i in 180:
		await physics_frame
		if event_count(release_event, enemy.target_id) > 0 and combat.health < health_before: break
	check(event_count("enemy_attack_warning", enemy.target_id) > 0, kind + " live AI warning")
	check(event_count(release_event, enemy.target_id) > 0, kind + " live AI attack release")
	check(combat.health < health_before, kind + " actual attack damages player")
	enemy.set_physics_process(false)
	for projectile in combat.get_children():
		if projectile.has_method("is_combat_projectile"): projectile.resolved = true; projectile.queue_free()
	var result: Dictionary = enemy.apply_damage(1, 10001, &"pistol", enemy.global_position, &"flesh")
	check(result.get("type") == &"enemy_hurt" and enemy.state == &"pain", kind + " damage enters pain")
	if EXPECTED.has(kind): check(enemy.sprite_frame == 13, kind + " registered pain frame")
	await material_contacts(enemy, kind + "/pain")
	var deaths_before: int = combat.kills
	result = enemy.apply_damage(enemy.health, 10002, &"pistol", enemy.global_position, &"flesh")
	check(enemy.dead and result.get("type") == &"enemy_death" and combat.kills == deaths_before + 1, kind + " death counted once")
	if EXPECTED.has(kind): check(enemy.sprite_frame == 14, kind + " death fall frame")
	enemy.state_time = 2; enemy.update_presentation(); await frames(2)
	if EXPECTED.has(kind): check(enemy.sprite_frame == 15, kind + " persistent corpse frame")
	for body in enemy.hurt_shapes: check(body.collision_layer != 4, kind + " corpse has no live anatomical damage surface")
	await material_contacts(enemy, kind + "/persistent_corpse")
	var releases_before := event_count(release_event, enemy.target_id)
	enemy.set_physics_process(true); await frames(60); enemy.set_physics_process(false)
	check(event_count(release_event, enemy.target_id) == releases_before, kind + " dead actor cannot attack")
	report.species[kind].runtime = {"warning_events": event_count("enemy_attack_warning", enemy.target_id), "release_events": releases_before,
		"actual_player_damage": health_before - combat.health, "hurt_events": event_count("enemy_hurt", enemy.target_id),
		"death_events": event_count("enemy_death", enemy.target_id), "corpse_frame": enemy.sprite_frame, "source_sha256": FileAccess.get_sha256(entry.file)}
	enemy.queue_free(); await frames(2)

func run() -> void:
	definitions()
	if not resources_only:
		stage_rosters(); make_fixture()
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/combat_art.json"))
		for kind in KINDS: await exercise(kind, art_entry(kind, manifest))
		fixture.free(); await process_frame
		preload("res://scripts/sprite_hurt_geometry.gd").frame_cache.clear()
		preload("res://scripts/sprite_hurt_geometry.gd").image_cache.clear()
	report.checks = checks; report.failures = failures; report.pass = failures.is_empty(); report.resources_only = resources_only
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence_path).get_base_dir())
	var file := FileAccess.open(evidence_path, FileAccess.WRITE); file.store_string(JSON.stringify(report, "  ") + "\n"); file.close()
	print("EXPANSION_ENEMIES_%s: %d checks; %d failures; resources_only=%s" % ["OK" if failures.is_empty() else "FAILED", checks, failures.size(), resources_only])
	quit(0 if failures.is_empty() else 1)
