extends SceneTree
## Isolated checkpoint/restore fixture. Teleported setup is explicit; this is not route play.

var app: Control
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
		push_error(label)

func settle(frames: int) -> void:
	for i in frames:
		await physics_frame

func at_marker(id: String) -> void:
	for marker in app.world.checkpoint_markers:
		if String(marker.get_meta("checkpoint_id")) == id:
			app.player.set_physics_process(false)
			app.player.global_position = marker.global_position
			app.player.velocity = Vector3.ZERO
			app.player.set_physics_process(true)
			return
	check(false, "Missing checkpoint marker " + id)

func run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	check(app.campaign_mode and app.world.scene_file_path == "res://scenes/campaign/ash_citadel_01.tscn", "Ash01 campaign Main must load")
	if not app.campaign_mode:
		quit(1)
		return
	app.enter_combat()
	for enemy in app.combat.enemies:
		enemy.set_physics_process(false)
		enemy.dead = true
	app.world.flags["brass"] = true
	app.world.refresh_objective()
	at_marker("crypt_credential")
	await settle(90)
	check(app.has_checkpoint() and String(app.campaign.checkpoint_snapshot.get("checkpoint_id", "")) == "crypt_credential", "Credential checkpoint must save")
	app.world.flags["gate_winch"] = true
	await settle(360)
	var bridge: Node3D = app.world.get_node("BridgeDeck")
	check(bridge.is_open(), "Bridge must physically open before winch checkpoint")
	at_marker("bridge_winch")
	await settle(90)
	check(app.has_checkpoint() and String(app.campaign.checkpoint_snapshot.get("checkpoint_id", "")) == "bridge_winch", "Winch checkpoint must supersede credential checkpoint")
	var old_world: Node3D = app.world
	app.continue_from_checkpoint()
	await settle(8)
	check(app.world != old_world and bool(app.world.flags.get("gate_winch", false)), "Continue must restore new Ash world and winch flag")
	check(app.world.get_node("BridgeDeck").is_open(), "Continue must restore physical lowered bridge")
	var query := PhysicsRayQueryParameters3D.create(Vector3(40, 7, 20), Vector3(40, -8, 20), 1)
	var hit: Dictionary = app.world.get_world_3d().direct_space_state.intersect_ray(query)
	check(not hit.is_empty() and String(hit.collider.name) == "BridgeDeck" and absf(hit.position.y - 6) < .05, "Continue must restore bridge collider")
	app.restart_level()
	await settle(8)
	check(not app.has_checkpoint() and app.world.get_node("BridgeDeck").is_closed() and not bool(app.world.flags.get("brass", false)) and not bool(app.world.flags.get("gate_winch", false)), "Full retry must reset bridge and progression flags")
	app.combat_audio.stop_all()
	app.menu_music.stop()
	app.menu_music.stream = null
	var until := Time.get_ticks_msec() + 300
	while Time.get_ticks_msec() < until:
		await process_frame
	print("ASH_CHECKPOINT_RESULT failures=", failures.size(), " details=", failures)
	quit(0 if failures.is_empty() else 1)
