extends SceneTree
## Focused physical check for the opt-in campaign driver's altar retreat.
## Launch twice with --campaign-level=occupied_line_02 and ash_citadel_02.

var app: Control
var driver: Node
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func settle() -> void:
	for frame in 8: await physics_frame

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		push_error(label)

func attempt(label: String, start: Vector3) -> void:
	var player: CharacterBody3D = app.player
	player.set_physics_process(false)
	player.global_position = start
	player.velocity = Vector3.ZERO
	player.set_movement_active(true)
	player.set_physics_process(true)
	await settle()
	check(player.is_on_floor(), label + ": unsupported start")
	if not player.is_on_floor(): return
	if label == "recorded west floor pose":
		var center: Vector3 = driver.vector(driver.route.rooms.arena_two.center)
		var front: Vector3 = center + Vector3(0, 0, 13)
		var toward: Vector3 = front - player.global_position
		toward.y = 0
		var contact := KinematicCollision3D.new()
		var blocked: bool = player.test_move(player.global_transform, toward.normalized() * 0.65, contact)
		var collider: Object = contact.get_collider() if blocked else null
		check(blocked and collider != null and collider.get_parent().name == "arena_two_RaisedAltar", label + ": expected direct route to hit solid altar")
	var before: int = driver.failures.size()
	var record_before: int = driver.records.size()
	var reached: bool = await driver.return_to_arena_staging("arena_two")
	var expected: Vector3 = driver.room_center("arena_two")
	check(reached and driver.failures.size() == before, label + ": route failed " + str(driver.failures))
	check(player.is_on_floor() and Vector2(player.global_position.x - expected.x, player.global_position.z - expected.z).length() < 0.4, label + ": final staging point unsupported or missed at " + str(player.global_position))
	var labels: Array[String] = []
	for index in range(record_before, driver.records.size()): labels.append(String(driver.records[index].segment))
	if driver.stage_id == "occupied_line_02":
		check("Altar side retreat" in labels and "Altar ring retreat" in labels, label + ": missed authored side route " + str(labels))
	else:
		check(not "Altar side retreat" in labels and not "Altar ring retreat" in labels, label + ": used another stage's altar detour " + str(labels))
	print("ALTAR_RETREAT ", label, " reached=", reached, " position=", player.global_position)

func run() -> void:
	var level := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--campaign-level="): level = argument.trim_prefix("--campaign-level=")
	check(level in ["occupied_line_02", "ash_citadel_02"], "Choose Occupied Line 02 or Ash Citadel 02")
	if not failures.is_empty(): quit(1); return
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	check(app.world.scene_file_path == "res://scenes/campaign/" + level + ".tscn", "Wrong campaign scene")
	app.enter_combat()
	await settle()
	for enemy in app.combat.enemies:
		enemy.set_physics_process(false)
		enemy.awake = false
	driver = load("res://scripts/campaign_route_playtest.gd").new()
	root.add_child(driver)
	driver.app = app
	driver.world = app.world
	driver.player = app.player
	driver.combat = app.combat
	driver.stage_id = level
	driver.route = JSON.parse_string(FileAccess.get_file_as_string("res://resources/campaign/" + level + "-route.json"))
	if level == "occupied_line_02":
		var center: Vector3 = driver.vector(driver.route.rooms.arena_two.center)
		await attempt("recorded west floor pose", Vector3(34.76627, -0.649852, -170.6331))
		await attempt("east floor pose", Vector3(center.x + 2.3, center.y, center.z - 5.12))
		await attempt("rear altar top", Vector3(center.x, center.y + 2.0, center.z - 4.6))
	else:
		await attempt("Ash outer west floor pose", Vector3(-48.58244, 0.85094, -160.8484))
	app.combat_audio.stop_all()
	app.menu_music.stop()
	app.menu_music.stream = null
	var until := Time.get_ticks_msec() + 300
	while Time.get_ticks_msec() < until: await process_frame
	print("ALTAR_RETREAT_RESULT failures=", failures.size(), " labels=", failures)
	quit(1 if not failures.is_empty() else 0)
