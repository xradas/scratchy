extends SceneTree
## Runtime render ownership contract on the real main scene and resolved shots.
## Render layers are checked independently from CharacterBody3D physics layers.
var app: Control
var failures: Array[String] = []
var records: Dictionary = {}
var evidence_dir := "res://verification/grit"

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-dir="):
			evidence_dir = argument.trim_prefix("--evidence-dir=")
	if evidence_dir.is_empty():
		push_error("REFLECTION_OWNERSHIP: evidence directory is empty")
		quit(1)
		return
	var error := DirAccess.make_dir_recursive_absolute(evidence_dir)
	if error != OK:
		push_error("REFLECTION_OWNERSHIP: cannot create evidence directory: " + error_string(error))
		quit(1)
		return
	call_deferred("run")

func check(condition: bool, message: String) -> bool:
	if not condition:
		failures.append(message)
		push_error("REFLECTION_OWNERSHIP: " + message)
	return condition

func descendants(node: Node) -> Array[Node]:
	var found: Array[Node] = []
	for child in node.get_children():
		found.append(child)
		found.append_array(descendants(child))
	return found

func check_probes(world: Node3D) -> Array[Node]:
	var probes: Array[Node] = []
	for node in descendants(world):
		if node is ReflectionProbe: probes.append(node)
	check(probes.size() == 2, "actual world must own exactly two reflection probes")
	var names: Array[String] = []
	for probe in probes:
		names.append(String(probe.name))
		check(probe.update_mode == ReflectionProbe.UPDATE_ONCE, "%s must use static UPDATE_ONCE" % probe.name)
		check(probe.cull_mask == 1, "%s reflection render cull mask must equal 1" % probe.name)
		check(world.is_ancestor_of(probe), "%s must belong to current world" % probe.name)
	names.sort()
	check(names == ["Reflection_HallFront", "Reflection_HallRear"], "expected HallFront/HallRear probe identities")
	return probes

func check_render_ownership(owner: Node, camera: Camera3D, label: String) -> Dictionary:
	var counts := {"meshes": 0, "sprites": 0}
	for node in descendants(owner):
		if node is MeshInstance3D or node is Sprite3D:
			if node is MeshInstance3D: counts.meshes += 1
			else: counts.sprites += 1
			check(node.layers == 2, "%s %s transient render layers must equal 2" % [label, node.get_path()])
			check((node.layers & 1) == 0, "%s %s leaked into static reflection render layer" % [label, node.get_path()])
			check((node.layers & camera.cull_mask) != 0, "%s %s excluded by world camera render cull mask" % [label, node.get_path()])
	return counts

func shot(enemy: CharacterBody3D, weapon: StringName, health: float) -> bool:
	enemy.health = health
	enemy.position = Vector3(0, .87, 7)
	enemy.change_state(&"chase")
	app.combat.currentweapon = weapon
	app.combat.weapon_phase = &"idle"
	app.combat.cooldown = 0
	app.player.camera.look_at(enemy.global_position + Vector3(0, .28, 0))
	await physics_frame
	await physics_frame
	return check(app.combat.try_fire(), "%s actual shot fixture failed to fire" % weapon)

func run() -> void:
	create_timer(45, true).timeout.connect(func():
		push_error("REFLECTION_OWNERSHIP: runtime check timed out")
		quit(1))
	app = preload("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.enter_combat()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	app.player.set_physics_process(false)
	app.combat.set_physics_process(false)
	app.player.position = Vector3(0, .87, 11)
	var world: Node3D = app.world
	var camera: Camera3D = app.player.camera
	var probes := check_probes(world)
	check((camera.cull_mask & 3) == 3, "world camera must see static layer 1 and transient layer 2")
	check(app.combat.enemies.size() >= 3, "actual main must have enough enemies for two shot fixtures")
	if app.combat.enemies.size() < 3:
		finish()
		return
	for enemy in app.combat.enemies:
		check(enemy.collision_layer == 2, "%s actor physics collision layer must remain 2" % enemy.name)
		check(enemy.sprite is Sprite3D, "%s actual enemy render must be Sprite3D" % enemy.name)
		check(enemy.sprite.layers == 2, "%s enemy sprite render layers must equal 2" % enemy.name)
		check((enemy.sprite.layers & camera.cull_mask) != 0, "%s enemy sprite invisible to world camera mask" % enemy.name)
		enemy.set_physics_process(false)
		enemy.position.x = 80
	var old_blood_count := 0
	for node in descendants(world):
		if node is MeshInstance3D and String(node.name).begins_with("OldBlood"):
			old_blood_count += 1
			check(node.layers == 1, "%s authored persistent old blood must remain static world layer 1" % node.name)
	check(old_blood_count > 0, "actual world must include persistent authored old blood")
	records.world = {"probe_count": probes.size(), "probe_update_mode": "UPDATE_ONCE", "probe_render_cull_mask": 1, "camera_render_cull_mask": camera.cull_mask, "enemy_count": app.combat.enemies.size(), "enemy_sprite_render_layers": 2, "enemy_actor_physics_layer": 2, "persistent_old_blood_static_meshes": old_blood_count}
	var gore: Node3D = app.combat.gore
	var first: CharacterBody3D = app.combat.enemies[0]
	var second: CharacterBody3D = app.combat.enemies[2]
	if not await shot(first, &"pistol", 20):
		finish()
		return
	check(first.dead and not first.gibbed and first.sprite.visible, "pistol must produce visible non-gib corpse")
	check(first.sprite.layers == 2, "visible corpse sprite must remain on transient render layer 2")
	records.pistol = check_render_ownership(gore, camera, "pistol")
	check(records.pistol.meshes > 0 and records.pistol.sprites == 2, "pistol must generate transient gore meshes and two flying parts")
	first.position.x = -4
	if not await shot(second, &"shotgun", 80):
		finish()
		return
	check(second.dead and second.gibbed and not second.sprite.visible, "shotgun must produce actual resolved gib death")
	check(gore.death_count == 2, "actual shots must resolve exactly two death events")
	check(gore.death_records.has(second.target_id), "shotgun must record resolved target death")
	if gore.death_records.has(second.target_id):
		check(gore.death_records[second.target_id].part_count == 9, "shotgun must generate nine gib parts")
	records.shotgun = check_render_ownership(gore, camera, "shotgun")
	check(records.shotgun.meshes > 0 and records.shotgun.sprites >= 9, "shotgun fixture must contain live transient gore meshes and gib sprites")
	for tick in 160: await physics_frame
	check(gore.particles.is_empty(), "gore particles must settle after 160 physics ticks")
	check(gore.remains.size() == 11, "both actual deaths must leave eleven settled body parts")
	records.settled = check_render_ownership(gore, camera, "settled gore")
	check(records.settled.meshes > 0 and records.settled.sprites == 0, "settled gore recursive check must cover generated meshes")
	var old_ids: Array[int] = [world.get_instance_id(), gore.get_instance_id(), camera.get_instance_id()]
	for node in descendants(world):
		if node is MeshInstance3D or node is Sprite3D or node is ReflectionProbe:
			old_ids.append(node.get_instance_id())
	app.restart_combat()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for old_id in old_ids:
		check(not is_instance_valid(instance_from_id(old_id)), "restart retained previous world/render/probe instance %d" % old_id)
	var new_probes := check_probes(app.world)
	for probe in new_probes:
		check(not old_ids.has(probe.get_instance_id()), "restart must construct fresh world-owned reflection probes")
	check(app.combat.gore.stains.is_empty() and app.combat.gore.remains.is_empty() and app.combat.gore.particles.is_empty(), "restart must clear generated gore render entities")
	records.restart = {"retired_instance_count": old_ids.size(), "fresh_world_probes": new_probes.size(), "generated_gore_cleared": true}
	finish()

func finish() -> void:
	records.failures = failures
	records.passed = failures.is_empty()
	var path := evidence_dir.path_join("p10-reflection-ownership.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("REFLECTION_OWNERSHIP: cannot open evidence: " + error_string(FileAccess.get_open_error()))
		quit(1)
		return
	file.store_string(JSON.stringify(records, "  ") + "\n")
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		push_error("REFLECTION_OWNERSHIP: cannot write evidence: " + error_string(error))
		quit(1)
		return
	if failures.is_empty(): print("REFLECTION_OWNERSHIP_CHECK_OK ", JSON.stringify(records))
	else: print("REFLECTION_OWNERSHIP_CHECK_FAILED ", JSON.stringify(records))
	if failures.is_empty() and is_instance_valid(app):
		await app.quit_game()
	else:
		quit(1)
