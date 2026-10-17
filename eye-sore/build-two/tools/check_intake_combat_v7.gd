extends SceneTree
## Controlled source Main contacts, not live traversal or human mouse acceptance.
var app: Control
var failures: Array[String] = []
var checks := 0
var events: Array[Dictionary] = []
var cases: Array[Dictionary] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error("INTAKE_COMBAT: " + label)
func count(kind: String, target := "") -> int:
	var result := 0
	for event in events:
		if String(event.type) == kind and (target.is_empty() or String(event.get("target_id", "")) == target): result += 1
	return result
func anchor(enemy: CharacterBody3D) -> Vector3:
	var best := INF
	var point := enemy.global_position
	for key in enemy.sprite_bodies:
		var body: StaticBody3D = enemy.sprite_bodies[key]
		var faces: PackedVector3Array = body.get_node("HitSurface").shape.get_faces()
		for i in range(0, faces.size(), 3):
			var candidate := body.to_global((faces[i] + faces[i+1] + faces[i+2]) / 3)
			var distance := candidate.distance_squared_to(enemy.global_position + Vector3(0,.22,0))
			if distance < best: best = distance; point = candidate
	return point
func run() -> void:
	app = load("res://scenes/main.tscn").instantiate(); root.add_child(app)
	app.enter_combat(); app.player.set_physics_process(false); app.combat.set_physics_process(false); app.world.set_physics_process(false)
	app.combat.combat_event.connect(func(event: Dictionary): events.append(event.duplicate(true)))
	for enemy in app.combat.enemies:
		enemy.set_physics_process(false); enemy.collision_layer = 0
		for body in enemy.hurt_shapes: body.collision_layer = 0
	var target: CharacterBody3D = app.combat.enemies[0]
	target.global_position = Vector3(0,-.13,-76)
	app.player.global_position = Vector3(0,-.13,-72)
	target.state = &"chase"; target.state_time = 0; target.update_sprite()
	for body in target.hurt_shapes: body.collision_layer = 4
	app.combat.grant_weapon(&"twin_shotgun", 12)
	await physics_frame; await physics_frame
	check(app.campaign_mode and app.campaign.current_level().id == "pale_ward_01", "actual Intake Main selected")
	for weapon in [&"pistol", &"shotgun", &"twin_shotgun"]:
		target.health = 1000; target.dead = false; target.state = &"chase"; target.state_time = 0; target.update_sprite()
		app.player.camera.look_at(anchor(target)); await physics_frame; await physics_frame
		app.combat.currentweapon = weapon; app.combat.cooldown = 0; app.combat.weapon_phase = &"idle"
		var definition: Resource = app.combat.weapons[weapon]
		var before_ammo: int = app.combat.get(String(definition.ammo_key))
		var before_camera: Transform3D = app.player.camera.global_transform
		events.clear(); var accepted: bool = app.combat.try_fire()
		check(accepted and count("shot") == 1, String(weapon) + " one authoritative shot")
		check(before_ammo - int(app.combat.get(String(definition.ammo_key))) == definition.ammo_cost, String(weapon) + " exact ammunition ownership")
		check(target.health < 1000 and count("enemy_hurt", String(target.target_id)) == 1, String(weapon) + " actual native hurt geometry receives damage once")
		check(count("impact", String(target.target_id)) == 1, String(weapon) + " aggregated target impact")
		var id: int = app.combat.shot_counter
		for frame in 12: app._process(1.0/60.0)
		check(app.combat.shot_counter == id and app.player.camera.global_transform == before_camera, String(weapon) + " cosmetics never fire or move aim")
		check(not app.combat.try_fire() and app.combat.shot_counter == id, String(weapon) + " cooldown rejects duplicate")
		cases.append({"weapon": weapon, "damage": 1000-target.health, "events": events.duplicate(true), "fixture_enemy_position": target.global_position})
	# Aim at a real authored intake cabinet side; no fixture collider is added.
	var prop: StaticBody3D = app.world.get_node("RoomProp_pale_ward_01_entry_intake_desk_01_1/CabinetLeg-1")
	app.player.global_position = prop.global_position + Vector3(0,0,-2)
	app.player.camera.look_at(prop.global_position)
	await physics_frame; await physics_frame
	app.combat.currentweapon = &"pistol"; app.combat.cooldown = 0; app.combat.weapon_phase = &"idle"; events.clear()
	check(app.combat.try_fire(), "authored hard furnishing shot accepted")
	var hit_prop := false
	for event in events:
		if String(event.type) == "impact" and String(event.target_id) == str(prop.get_instance_id()):
			hit_prop = String(event.material) == "hard"
	check(hit_prop and count("enemy_hurt") == 0, "actual cabinet collision resolves hard without enemy damage")
	cases.append({"authored_prop": String(prop.get_path()), "events": events.duplicate(true)})
	var report := {"status": "passed" if failures.is_empty() else "failed", "checks": checks, "failures": failures, "cases": cases, "scene_sha256": FileAccess.get_sha256("res://scenes/campaign/pale_ward_01.tscn"), "scope": "Actual Main Intake source, current Ward native hurt silhouette and actual authored desk collision. AI, actor/world physics frozen; target/player repositioned and target HP raised to isolate contacts, Twin granted 12 shells. Cosmetics manually advanced. Not finite route, physical mouse feel, live encounter, or human visual approval."}
	var path := "res://verification/intake-v7/combat/intake-contacts.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")+"\n"); file.close()
	print("INTAKE_COMBAT ", report.status, " ", checks, " ", failures)
	await app.quit_game()
	quit(0 if failures.is_empty() else 1)
