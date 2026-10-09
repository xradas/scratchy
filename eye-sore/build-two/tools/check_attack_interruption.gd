extends SceneTree
## Integrated fixture: main.tscn --calibration, both shipped definitions and live AI.
## Only player movement is disabled. No manual enemy/combat physics calls.
var app: Control
var target: CharacterBody3D
var trace: Array[Dictionary] = []
var results: Array[Dictionary] = []
var failures: Array[String] = []
var stage := "startup"
var path := "res://verification/grit/p12-attack-interruption.json"

func _initialize() -> void:
	Engine.physics_ticks_per_second = 60
	Engine.max_fps = 120
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-path="): path = argument.trim_prefix("--evidence-path=")
	call_deferred("run")

func check(condition: bool, message: String) -> bool:
	if not condition:
		failures.append(stage + ": " + message)
		print("P12_FAIL ", failures.back())
	return condition

func record(event: Dictionary) -> void:
	var value := event.duplicate(true)
	value.physics_tick = Engine.get_physics_frames()
	value.stage = stage
	if is_instance_valid(app) and is_instance_valid(app.combat_audio):
		value.audio_cue_counts = app.combat_audio.cue_counts.duplicate()
	if is_instance_valid(target):
		value.observed_state = target.state
		value.observed_state_time = target.state_time
	trace.append(value)

func event_count(type: String, id: int = -1) -> int:
	var count := 0
	for event in trace:
		if String(event.type) == type and event.get("target_id", "") == target.target_id and (id < 0 or event.get("attack_id", -1) == id): count += 1
	return count

func release_type() -> String:
	return "projectile_release" if target.definition.ranged else "enemy_melee_release"

func cues(key: String) -> int:
	return int(app.combat_audio.cue_counts.get(StringName(key), 0))

func projectiles() -> int:
	var count := 0
	for node in app.combat.get_children():
		if node.has_method("is_combat_projectile") and not node.is_queued_for_deletion(): count += 1
	return count

func frames(count: int) -> void:
	for i in count: await physics_frame

func wait_state(state: StringName, limit := 240) -> bool:
	for i in limit:
		await physics_frame
		if target.state == state: return true
	return check(false, "Timed out awaiting " + String(state))

func setup_fixture(kind: String) -> void:
	stage = kind + "/setup"
	if is_instance_valid(app):
		app.restart_combat()
	else:
		app = preload("res://scenes/main.tscn").instantiate()
		root.add_child(app)
		app.enter_combat()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	app.player.set_physics_process(false)
	app.player.position = Vector3(0, .87, 11)
	app.combat.combat_event.connect(record)
	check(app.combat.enemies.size() == 2, "Expected actual calibration two-enemy encounter; pass --calibration")
	for enemy in app.combat.enemies:
		enemy.set_physics_process(false)
		enemy.position = Vector3(70, .87, 0)
		if String(enemy.definition.identifier) == kind: target = enemy
	target.position = Vector3(0, .87, 9.6 if kind == "unsealed" else 7)
	target.awake = true
	await frames(3)
	target.set_physics_process(true)

func aim_and_fire() -> bool:
	var exclusions: Array = [app.player.get_rid()]
	for enemy in app.combat.enemies:
		if not enemy.hurt_shapes.is_empty(): exclusions.append(enemy.get_rid())
	var found := false
	for y in [.25, .05, -.15, .45, -.35]:
		for x in [0.0, .15, -.15, .3, -.3]:
			var point := target.global_position + Vector3(x, y, 0)
			var origin: Vector3 = app.player.camera.global_position
			var hit: Dictionary = app.combat.ray(origin, origin + (point-origin).normalized()*60, exclusions, true)
			if not hit.is_empty() and hit.collider.get_meta("combat_target", null) == target:
				app.player.camera.look_at(point)
				found = true
				break
		if found: break
	if not check(found, "No actual opaque sprite contact for shot"): return false
	check(target.state == &"windup" and not target.released, "Shot must occur in live unreleased windup")
	var health_before: float = target.health
	var shot_before: int = app.combat.shot_counter
	var accepted: bool = app.combat.try_fire()
	check(accepted and app.combat.shot_counter == shot_before+1, "Combat must accept one genuine ray shot on physics frame")
	check(target.health < health_before, "Accepted shot must resolve actual target damage")
	return accepted

func run_kind(kind: String) -> void:
	await setup_fixture(kind)
	if not await wait_state(&"windup"): return
	stage = kind + "/pain-interruption"
	await frames(8)
	var cancelled_id: int = target.attack_id
	var release_before := event_count(release_type())
	var release_cue_before := cues("projectile_release" if target.definition.ranged else "player_hurt")
	var warning_before := cues(kind + "_attack_warning")
	check(warning_before == 1 and event_count("enemy_attack_warning", cancelled_id) == 1, "Initial warning event and audio agree exactly once")
	app.combat.currentweapon = &"pistol"
	await aim_and_fire()
	check(target.state == &"pain" and target.released and not target.dead, "Nonlethal accepted shot cancels pending attack into pain")
	check(event_count("enemy_hurt") == 1, "Pain emits one resolved hurt")
	check(cues(kind + "_hurt") == 1, "One hurt audio cue agrees with damage")
	for voice in app.combat_audio.voices:
		if is_instance_valid(voice) and voice.get_meta("target_id", "") == target.target_id and voice.get_meta("role", "") == "enemy_attack_warning":
			check(voice.is_queued_for_deletion() or not voice.playing, "Hurt retires interrupted warning voice")
	var pain_tick := Engine.get_physics_frames()
	if not await wait_state(&"windup"): return
	var fresh_tick := Engine.get_physics_frames()
	var fresh_id: int = target.attack_id
	check(event_count("enemy_attack_warning", cancelled_id) == 1 and event_count("enemy_attack_warning", fresh_id) == 1, "Cancelled and fresh ids each own exactly one warning event")
	check(fresh_id == cancelled_id+1 and not target.released, "Pain requires a fresh attack id and unreleased windup")
	check(event_count(release_type(), cancelled_id) == 0 and projectiles() == 0, "Cancelled windup has no release or stray projectile")
	check(event_count(release_type()) == release_before and cues("projectile_release" if target.definition.ranged else "player_hurt") == release_cue_before, "Cancelled windup has no release sound/damage")
	check(cues(kind + "_attack_warning") == warning_before+1, "Fresh warning emits exactly one corresponding cue")
	check(float(fresh_tick-pain_tick)/60.0 >= target.definition.pain_seconds, "Pain lasts definition duration before new windup")
	stage = kind + "/pause-resume-natural-release"
	await frames(6)
	var frozen_time: float = target.state_time
	var frozen_position: Vector3 = target.global_position
	var frozen_count := trace.size()
	app.set_paused(true)
	await create_timer(.35, true).timeout
	check(target.state == &"windup" and target.state_time == frozen_time and target.global_position == frozen_position, "Pause freezes live pending windup")
	check(trace.size() == frozen_count and projectiles() == 0, "Pause produces no release/event/projectile")
	app.set_paused(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var resumed_tick := Engine.get_physics_frames()
	for i in 100:
		await physics_frame
		if event_count(release_type(), fresh_id) > 0: break
	var commit_ticks := Engine.get_physics_frames()-resumed_tick
	var remaining: float = target.definition.windup_seconds-frozen_time
	check(event_count(release_type(), fresh_id) == 1, "Fresh attack naturally commits exactly once")
	check(absf(float(commit_ticks)/60.0-remaining) <= 2.0/60.0, "Resume preserves remaining definition windup time")
	check(cues("projectile_release" if target.definition.ranged else "player_hurt") == release_cue_before+1, "Natural release audio agrees exactly once")
	if target.definition.ranged: check(projectiles() == 1, "Natural ranged release owns exactly one projectile")
	else: check(app.combat.health < 100 and app.combat.armor < 50, "Natural melee release damages actual player once")
	stage = kind + "/defensive-direct-release-guard"
	# Explicit defensive API case; not evidence of natural physics commit.
	target.release_attack(); target.release_attack()
	check(event_count(release_type(), fresh_id) == 1, "Direct duplicate release guard prevents second commit")
	check(cues("projectile_release" if target.definition.ranged else "player_hurt") == release_cue_before+1, "Duplicate defensive calls emit no release audio")
	await frames(8)
	check(event_count(release_type(), fresh_id) == 1, "Recovery frames do not commit again")
	results.append({"kind":kind,"cancelled_attack_id":cancelled_id,"fresh_attack_id":fresh_id,"definition_windup":target.definition.windup_seconds,"definition_pain":target.definition.pain_seconds,"remaining_at_pause":remaining,"resume_commit_ticks":commit_ticks,"natural_release_count":event_count(release_type(), fresh_id)})
	# New actual main encounter avoids manual resurrection/collision restoration.
	await setup_fixture(kind)
	stage = kind + "/lethal-windup-shot"
	if not await wait_state(&"windup"): return
	await frames(7)
	var dead_id: int = target.attack_id
	var lethal_release_before := event_count(release_type())
	var lethal_audio_before := cues("projectile_release" if target.definition.ranged else "player_hurt")
	# Fixture health varies only; shipped definition and all attack timings stay intact.
	target.health = 10.0
	app.combat.currentweapon = &"pistol"
	await aim_and_fire()
	check(target.dead and target.state == &"dead" and target.released, "Actual lethal accepted ray during windup resolves death")
	check(event_count("enemy_death") == 1 and cues(kind+"_death") == 1, "Death event and audio agree exactly once")
	for voice in app.combat_audio.voices:
		if is_instance_valid(voice) and voice.get_meta("target_id", "") == target.target_id and voice.get_meta("role", "") == "enemy_attack_warning":
			check(voice.is_queued_for_deletion() or not voice.playing, "Death retires unreleased warning voice")
	check(event_count(release_type()) == lethal_release_before and projectiles() == 0, "Death immediately prevents unreleased attack/projectile")
	stage = kind + "/defensive-dead-release-guard"
	target.release_attack()
	stage = kind + "/dead-later-physics"
	await frames(int(ceil((target.definition.windup_seconds+target.definition.recovery_seconds+target.definition.pain_seconds)*60))+10)
	check(target.dead and event_count(release_type()) == lethal_release_before and projectiles() == 0, "Dead enemy never releases now or on later real physics frames")
	check(cues("projectile_release" if target.definition.ranged else "player_hurt") == lethal_audio_before, "Dead enemy emits no stray release audio")
	results.back().lethal_fixture_health = 10.0
	results.back().lethal_attack_id = dead_id
	results.back().no_dead_release = true

func run() -> void:
	if DisplayServer.get_name() != "headless": root.set_flag(Window.FLAG_NO_FOCUS, true)
	if "--calibration" not in OS.get_cmdline_user_args():
		check(false, "Requires --calibration actual two-enemy main scene")
	else:
		for kind in ["unsealed", "vessel"]: await run_kind(kind)
	var data := {"passed":failures.is_empty(),"failures":failures,"results":results,"trace":trace,"scope":"Actual main.tscn calibration encounter, live enemy/combat physics at 60 Hz, player movement disabled, genuine accepted pistol rays; fixture health=10 only for death. Direct release calls are defensive guards only."}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: check(false, "Cannot write evidence " + path)
	else:
		file.store_string(JSON.stringify(data, "  ")+"\n")
		file.close()
	print("P12_ATTACK_INTERRUPTION_", "OK" if failures.is_empty() else "FAILED", " ", JSON.stringify(results))
	if is_instance_valid(app):
		if failures.is_empty(): await app.quit_game()
		else:
			app.set_paused(true)
			app.combat_audio.stop_all()
			if is_instance_valid(app.menu_music): app.menu_music.stop(); app.menu_music.stream = null
			await create_timer(.25, true).timeout
			quit(1)
	else: quit(1)
