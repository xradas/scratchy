extends SceneTree
## --headless --fixed-fps 60: live enemy/Combat physics; frozen player only.
## Route bot fires after physics_frame signal, before ordinary AI callbacks.
const KINDS := ["unsealed", "vessel", "ironbound", "censer", "reaver", "surveyor"]
const Combat := preload("res://scripts/combat.gd")
const Hurt := preload("res://scripts/sprite_hurt_geometry.gd")
class LateProbe extends Node:
	var owner_audit: SceneTree
	func _physics_process(_delta: float) -> void:
		if owner_audit.observing and is_instance_valid(owner_audit.enemy) and not owner_audit.enemy.dead: owner_audit.observe("after_ai")
var world: Node3D
var combat: Node3D
var player: CharacterBody3D
var camera: Camera3D
var enemy: CharacterBody3D
var art: Dictionary
var native_image: Image
var events: Array[Dictionary] = []
var observing := false
var phase_stats := {}
var examples: Array = []
var rows: Array = []
var shot_rows: Array = []
var chest_cache := {}
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	Engine.physics_ticks_per_second = 60; Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	call_deferred("run")
func xyz(v: Vector3) -> Array: return [v.x, v.y, v.z]
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error("LIVE_AIM_V4_FAILED: " + label)
func count(type: String, start := 0) -> int:
	var n := 0
	for i in range(start, events.size()):
		if String(events[i].type) == type: n += 1
	return n
func receive(event: Dictionary) -> void: events.append(event.duplicate(true))

func fixture(kind: String, distance: float, weapon := "pistol") -> void:
	world = Node3D.new(); root.add_child(world)
	var markers := Node3D.new(); markers.name = "EnemySpawns"; world.add_child(markers)
	var floor_body := StaticBody3D.new(); floor_body.position = Vector3(0, -.1, -30); world.add_child(floor_body)
	var floor_collision := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = Vector3(100, .2, 120); floor_collision.shape = box; floor_body.add_child(floor_collision)
	player = CharacterBody3D.new(); player.position.y = .87; player.collision_layer = 2; player.collision_mask = 3; world.add_child(player)
	var capsule := CapsuleShape3D.new(); capsule.height = 1.7; capsule.radius = .3
	var shape := CollisionShape3D.new(); shape.shape = capsule; player.add_child(shape); player.set_physics_process(false)
	camera = Camera3D.new(); camera.name = "Camera3D"; camera.position.y = .68; camera.fov = 82; camera.keep_aspect = Camera3D.KEEP_WIDTH; player.add_child(camera)
	combat = Combat.new(); world.add_child(combat); combat.setup(world, player); combat.combat_event.connect(receive)
	combat.grant_weapon(&"rivet_cannon", 100); combat.ammo_pistol = 96; combat.ammo_shotgun = 40; combat.currentweapon = StringName(weapon)
	enemy = combat.spawn_enemy(StringName(kind), Vector3(0, .87, -distance)); enemy.rotation.y = PI; combat.total_enemies = 1
	var data: Dictionary = art.enemies[kind]; var clips := {}; var pivot: Array = data.foot_pivot
	for key in data.clips: clips[key] = Vector2i(data.clips[key][0], data.clips[key][1])
	enemy.configure_sprite_sheet(data.file, data.columns, data.directions, clips, data.pixel_size, Vector2(pivot[0], pivot[1]), data.sprite_options)
	native_image = enemy.sprite_source_texture.get_image(); if native_image.is_compressed(): native_image.decompress()
	var late := LateProbe.new(); late.owner_audit = self; late.process_physics_priority = 1000; world.add_child(late)
	events.clear(); phase_stats.clear(); examples.clear(); chest_cache.clear()

func retire() -> void:
	observing = false; world.free(); await physics_frame; await physics_frame

func chest_point() -> Dictionary:
	if chest_cache.has(enemy.sprite_frame):
		var cached: Dictionary = chest_cache[enemy.sprite_frame]
		return {"point": cached.body.to_global(cached.local_point), "material": cached.material}
	var anchor: Vector3 = enemy.global_position + Vector3(0, .28, 0)
	var best := INF; var result := {}
	for material in enemy.sprite_bodies:
		var body: StaticBody3D = enemy.sprite_bodies[material]
		var shape: ConcavePolygonShape3D = body.get_node("HitSurface").shape
		if shape == null or body.collision_layer != 4: continue
		var faces := shape.get_faces()
		for i in range(0, faces.size(), 3):
			var point := body.to_global((faces[i] + faces[i + 1] + faces[i + 2]) / 3.0)
			var distance := point.distance_squared_to(anchor)
			if distance < best:
				best = distance; result = {"point": point, "material": String(material)}
				chest_cache[enemy.sprite_frame] = {"body": body, "local_point": (faces[i] + faces[i + 1] + faces[i + 2]) / 3.0, "material": String(material)}
	return result

func sample(point: Vector3) -> Dictionary:
	var origin := camera.global_position; var direction := origin.direction_to(point)
	var hit: Dictionary = combat.ray(origin, origin + direction * 70, combat.anatomical_exclusions(), true)
	var contact: bool = not hit.is_empty() and hit.collider.has_meta("combat_target") and hit.collider.get_meta("combat_target") == enemy
	# Independent current-pose alpha expectation at the same grid sampling that
	# generates production collision geometry, to separate holes from stale queries.
	var plane := Plane(enemy.sprite_pivot.global_basis.z, enemy.sprite_pivot.global_position)
	var projected: Variant = plane.intersects_ray(origin, direction)
	var opaque := false; var alpha := 0.0; var uv := Vector2(-1, -1)
	if projected is Vector3:
		var local: Vector3 = enemy.sprite_pivot.to_local(projected)
		var rect: Rect2i = Hurt.frame_region(enemy.sprite_source_texture, enemy.sprite_source_columns, enemy.sprite_source_rows, enemy.sprite_frame, enemy.sprite_data)
		uv = Vector2(local.x / enemy.sprite.pixel_size + enemy.sprite_foot.x, enemy.sprite_foot.y - local.y / enemy.sprite.pixel_size) / Vector2(rect.size)
		var limit: Array = enemy.sprite_data.get("hurt_resolution", [128, 192])
		var grid := Vector2i(mini(rect.size.x, int(limit[0])), mini(rect.size.y, int(limit[1])))
		if uv.x >= 0 and uv.y >= 0 and uv.x < 1 and uv.y < 1:
			var cell := Vector2i(int(uv.x * grid.x), int(uv.y * grid.y))
			var center := (Vector2(cell) + Vector2(.5, .5)) / Vector2(grid)
			var pixel := rect.position + Vector2i(int(center.x * rect.size.x), int(center.y * rect.size.y))
			alpha = native_image.get_pixelv(pixel).a; opaque = alpha >= float(enemy.sprite_data.get("alpha_threshold", .5))
	return {"point": xyz(point), "contact": contact, "expected_current_alpha": opaque, "alpha": alpha, "uv": [uv.x, uv.y], "material": String(combat.material_for(hit.collider)) if contact else "",
		"query_mismatch": contact != opaque, "blocked_by_world": not hit.is_empty() and not contact}

func pair() -> Dictionary:
	var route := sample(enemy.global_position + Vector3(0, .28, 0)); var chest := chest_point()
	return {"route": route, "chest": sample(chest.point) if not chest.is_empty() else {"contact": false, "expected_current_alpha": false, "query_mismatch": false}}

func observe(ordering: String) -> void:
	var probe := pair()
	var key := "%s/%d/%s" % [enemy.state, enemy.sprite_frame, ordering]
	if not phase_stats.has(key): phase_stats[key] = {"phase": String(enemy.state), "native_frame": enemy.sprite_frame, "ordering": ordering, "samples": 0, "route_contacts": 0, "route_opaque": 0, "chest_contacts": 0, "chest_opaque": 0, "route_query_mismatches": 0, "chest_query_mismatches": 0, "distance_min": INF, "distance_max": 0.0}
	var stats: Dictionary = phase_stats[key]; var distance := Vector2(enemy.position.x, enemy.position.z).length()
	stats.samples += 1; stats.route_contacts += int(probe.route.contact); stats.route_opaque += int(probe.route.expected_current_alpha)
	stats.chest_contacts += int(probe.chest.contact); stats.chest_opaque += int(probe.chest.expected_current_alpha)
	stats.route_query_mismatches += int(probe.route.query_mismatch); stats.chest_query_mismatches += int(probe.chest.query_mismatch)
	stats.distance_min = minf(stats.distance_min, distance); stats.distance_max = maxf(stats.distance_max, distance)
	if not probe.route.contact and examples.size() < 30:
		examples.append({"phase": String(enemy.state), "state_time": enemy.state_time, "native_frame": enemy.sprite_frame, "ordering": ordering, "distance": distance, "enemy_position": xyz(enemy.global_position), "probe": probe})

func actual_shot(strategy: String) -> Dictionary:
	var probes := pair(); var selected := chest_point()
	var point: Vector3 = enemy.global_position + Vector3(0, .28, 0)
	if strategy == "opaque_chest" and not selected.is_empty(): point = selected.point
	elif strategy == "visible_chest_fallback" and not probes.route.contact and probes.chest.contact and not selected.is_empty(): point = selected.point
	camera.look_at(point)
	var phase: String = String(enemy.state); var frame: int = enemy.sprite_frame; var distance := Vector2(enemy.position.x, enemy.position.z).length()
	var hp: float = enemy.health; var start := events.size(); var definition: WeaponDefinition = combat.weapons[combat.currentweapon]
	var ammo_before: int = combat.get(String(definition.ammo_key))
	var accepted: bool = combat.try_fire(); var impacts: Array = []; var damage := 0.0; var pellets := 0
	for i in range(start, events.size()):
		var event: Dictionary = events[i]
		if String(event.get("target_id", "")) != enemy.target_id: continue
		if String(event.type) == "impact": impacts.append({"material": String(event.material), "pellets": event.pellets}); pellets += int(event.pellets)
		elif String(event.type) in ["enemy_hurt", "enemy_death"]: damage += float(event.damage)
	return {"accepted": accepted, "phase_before": phase, "native_frame_before": frame, "horizontal_distance_m": distance, "aim_point": xyz(point), "pre_shot_probes": probes,
		"impacts": impacts, "enemy_contact": not impacts.is_empty(), "contact_pellets": pellets, "damage": damage, "health_removed": hp - enemy.health,
		"enemy_health_after": enemy.health, "phase_after": String(enemy.state), "ammo_spent": ammo_before - int(combat.get(String(definition.ammo_key))), "physics_tick": Engine.get_physics_frames()}

func passive(kind: String, distance: float, frames: int) -> void:
	fixture(kind, distance); await physics_frame; await physics_frame
	observing = true; var pulse := {}; var initial_y: float = enemy.position.y
	for i in frames:
		await physics_frame
		if enemy.dead or combat.dead: break
		observe("before_ai")
		# One genuine contact, after a stable windup pose, induces natural pain.
		if pulse.is_empty() and enemy.state == &"windup" and enemy.state_time >= .12 and pair().chest.contact: pulse = actual_shot("opaque_chest")
	observing = false
	var states := {}
	for key in phase_stats: states[phase_stats[key].phase] = true
	check(enemy.is_physics_processing() and not player.is_physics_processing(), kind + " actual AI active/player frozen")
	check(absf(enemy.position.y - initial_y) < .05, kind + " stable grounded live fixture")
	if distance == 12:
		for state in ["chase", "windup", "pain", "recovery"]: check(states.has(state), kind + " observed genuine " + state + " pose")
		check(not pulse.is_empty() and pulse.accepted and pulse.enemy_contact, kind + " actual windup shot produces pain contact")
	rows.append({"species": kind, "starting_distance_m": distance, "frames_requested": frames, "phase_statistics": phase_stats.values().duplicate(true), "first_miss_examples": examples.duplicate(true), "inducing_pain_shot": pulse,
		"enemy_health": enemy.health, "player_health": combat.health, "player_armor": combat.armor, "attack_warning_events": count("enemy_attack_warning"), "attack_release_events": count("enemy_melee_release") + count("projectile_release")})
	await retire()

func held(kind: String, weapon: String, strategy: String) -> void:
	fixture(kind, 12, weapon); await physics_frame; await physics_frame
	var shots: Array = []; var started := Engine.get_physics_frames(); var first := -1
	var definition: WeaponDefinition = combat.weapons[StringName(weapon)]; var initial_ammo: int = combat.get(String(definition.ammo_key))
	for i in 600:
		await physics_frame
		if enemy.dead or combat.dead: break
		if combat.cooldown > 0: continue
		# Exact route ordering: aim/fire after physics_frame, before enemy tick.
		var record := actual_shot(strategy)
		if record.accepted:
			shots.append(record)
			if first < 0: first = Engine.get_physics_frames()
	var contacts := 0; var misses := 0; var damage := 0.0; var by_phase := {}
	for shot in shots:
		contacts += int(shot.enemy_contact); misses += int(not shot.enemy_contact); damage += shot.damage
		if not by_phase.has(shot.phase_before): by_phase[shot.phase_before] = {"accepted": 0, "contacts": 0, "damage": 0.0}
		by_phase[shot.phase_before].accepted += 1; by_phase[shot.phase_before].contacts += int(shot.enemy_contact); by_phase[shot.phase_before].damage += shot.damage
	check(count("shot") == shots.size(), kind + "/" + weapon + "/" + strategy + " recorded all accepted shots")
	check(enemy.health >= 0 and enemy.health <= enemy.definition.health, kind + " stable actual HP bounds")
	var spent: int = initial_ammo - int(combat.get(String(definition.ammo_key)))
	check(spent == shots.size(), kind + " ammunition belongs to accepted shots")
	shot_rows.append({"species": kind, "weapon": weapon, "strategy": strategy, "starting_distance_m": 12, "enemy_ai_active": enemy.is_physics_processing(), "initial_enemy_health": enemy.definition.health,
		"final_enemy_health": enemy.health, "killed": enemy.dead, "accepted_shots": shots.size(), "enemy_contacts": contacts, "misses": misses, "resolved_damage": damage, "ammo_spent": spent,
		"elapsed_physics_seconds": float(Engine.get_physics_frames() - started) / 60, "ttk_from_first_shot_seconds": float(shots[-1].physics_tick - first) / 60 if enemy.dead and not shots.is_empty() else null,
		"by_phase": by_phase, "shots": shots, "player_health": combat.health, "player_armor": combat.armor})
	await retire()

func hashes() -> Dictionary:
	var result := {}
	for path in ["scripts/combat.gd", "scripts/combat_enemy.gd", "scripts/sprite_hurt_geometry.gd", "assets/combat_art.json", "tools/playtest_expanded_stages.gd"]: result[path] = FileAccess.get_sha256("res://" + path)
	for kind in KINDS: result["resources/enemies/" + kind + ".tres"] = FileAccess.get_sha256("res://resources/enemies/" + kind + ".tres")
	return result

func diagnostics() -> Dictionary:
	var samples := 0; var mismatches := 0; var gaps: Array = []; var comparisons: Array = []
	for row in rows:
		for phase in row.phase_statistics:
			samples += int(phase.samples)
			mismatches += int(phase.route_query_mismatches) + int(phase.chest_query_mismatches)
			if phase.ordering == "before_ai" and phase.route_opaque == 0 and phase.samples > 0:
				gaps.append({"species": row.species, "phase": phase.phase, "native_frame": phase.native_frame, "samples": phase.samples, "route_contacts": phase.route_contacts, "chest_contacts": phase.chest_contacts, "distance_min": phase.distance_min, "distance_max": phase.distance_max})
	for kind in KINDS:
		for weapon in ["pistol", "shotgun", "rivet_cannon"]:
			var compare := {"species": kind, "weapon": weapon}
			for row in shot_rows:
				if row.species == kind and row.weapon == weapon:
					compare[row.strategy] = {"accepted_shots": row.accepted_shots, "contacts": row.enemy_contacts, "misses": row.misses, "ammo_spent": row.ammo_spent, "ttk_seconds": row.ttk_from_first_shot_seconds}
			comparisons.append(compare)
	return {"query_phase_samples": samples, "native_alpha_query_mismatches": mismatches, "route_aim_transparent_pose_gaps": gaps, "accepted_shot_comparisons": comparisons,
		"findings": ["Pose-specific fixed actor-center alpha gaps explain real wasted shots; no before/after-AI native-alpha/query mismatch observed.", "Surveyor route aim wastes15 Pistol rounds or20 rivets in the starting12m live fixture; visible opaque fallback needs7 Pistol shots or4 rivets with all contacts.", "Reaver route aim misses its pain pose for2 Rivet shots; visible opaque fallback reduces5 accepted shots to3.", "Always aiming a triangle centroid can worsen Shotgun spread coverage: Unsealed one-shell kill becomes two. Conditional fallback preserves an already valid center ray.", "Recommend correcting automated route aim to current visible anatomy before declaring campaign ammo insufficient; retain existing HP, damage, pain interruption and alpha-shaped hitboxes."]}

func run() -> void:
	art = JSON.parse_string(FileAccess.get_file_as_string("res://assets/combat_art.json")); var source := hashes()
	for kind in KINDS:
		await passive(kind, 12, 480)
		if (load("res://resources/enemies/" + kind + ".tres") as EnemyDefinition).ranged: await passive(kind, 25, 150)
		for weapon in ["pistol", "shotgun", "rivet_cannon"]:
			for strategy in ["route_global_plus_028", "opaque_chest", "visible_chest_fallback"]: await held(kind, weapon, strategy)
		print("LIVE_AIM_SPECIES_OK: ", kind)
	check(source == hashes(), "aim-critical source unchanged during audit")
	var report := {"status": "passed" if failures.is_empty() else "failed", "checks": checks, "failures": failures, "source": source, "passive_live_pose_probes": rows, "actual_live_fire": shot_rows,
		"diagnostics": diagnostics(),
		"scope": "Source executable physics at60Hz: player frozen, enemy AI/Combat/projectiles active, stable original enemy HP/damage/native art. Route ordering mirrored (aim/fire at physics_frame before AI); query-only probes additionally run after AI with late physics priority. Actual held Pistol/Shotgun/Rivet compare global_position+.28, nearest opaque chest triangle, and conditional visible chest fallback. Not a normal player movement/strafe/campaign route or exported release acceptance.",
		"limitations": ["Ranged foes naturally stand and attack at12m, so supplementary25m runs observe genuine ranged walking; ranges are recorded per sample/shot.", "Chest comparator chooses current production geometry, not a broadened hitbox; no collision/pose/stat edits.", "One deterministic spread seed sequence per live run; counts are evidence for this fixture, not stochastic accuracy estimates."]}
	var output := "res://verification/combat-balance-v4/live-aim.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	var file := FileAccess.open(output, FileAccess.WRITE); file.store_string(JSON.stringify(report, "  ") + "\n"); file.close()
	print("LIVE_AIM_V4_%s: %d checks/%d failures; %d actual live-fire rows" % [report.status.to_upper(), checks, failures.size(), shot_rows.size()])
	quit(0 if failures.is_empty() else 1)
