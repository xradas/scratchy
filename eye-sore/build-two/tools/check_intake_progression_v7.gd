extends SceneTree
## Controlled actual Main ownership/progression checks. No traversal claim.
var app: Control
var checks := 0
var failures: Array[String] = []
var events: Array[Dictionary] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error("INTAKE_V7: " + label)
func observe(event: Dictionary) -> void: events.append(event.duplicate(true))
func receipts() -> int:
	var result := 0
	for event in events:
		if String(event.get("type", "")) == "item_collected": result += 1
	return result
func named_pickup(name: String) -> Node3D:
	for item in app.world.pickups:
		if item.name == name: return item
	return null
func mechanism(id: String, key := "stage_door") -> Node3D:
	for node in app.world.mechanisms:
		if String(node.get_meta(key, "")) == id: return node
	return null
func freeze() -> void:
	app.automated_input = true
	app.player.set_physics_process(false); app.combat.set_physics_process(false)
	app.world.set_physics_process(false)
	for enemy in app.combat.enemies: enemy.set_physics_process(false)
	app.combat.combat_event.connect(observe)
func run() -> void:
	app = load("res://scenes/main.tscn").instantiate(); root.add_child(app)
	app.automated_input = true; app.campaign_mode = true; app.campaign.seek("pale_ward_01")
	app.stage_id = "pale_ward"; app.replace_world({}); app.campaign.entry_snapshot = app.campaign.capture(app.combat)
	app.enter_combat(); freeze()
	var world: Node3D = app.world
	var bait: Node3D = named_pickup("Bait_arena_one")
	var brass: Node3D = named_pickup("Key_brass_key")
	if brass == null: brass = named_pickup("Key_brass")
	var shortcut: Node3D = mechanism("shortcut_one")
	var breaker: Node3D = mechanism("breaker", "stage_button")
	check(bait != null and brass != null and shortcut != null and breaker != null, "authored Intake nodes present")
	if bait == null or brass == null or shortcut == null or breaker == null: finish(); return
	# Can run before coordinator regeneration; production metadata is reported separately.
	var authored_side := shortcut.has_meta("first_open_normal")
	check(authored_side, "generated shortcut carries first-open world normal")
	if not authored_side: shortcut.set_meta("first_open_normal", Vector3.RIGHT)
	check(Array(shortcut.get_meta("requires", [])) == ["breaker", "brass_key"], "generated shortcut requires power alias and key")
	var before := receipts()
	world.collect(brass)
	check(brass.visible and receipts() == before and not world.flags.get("brass", false), "brass rejected before power without receipt")
	app.combat.grant_weapon(&"twin_shotgun", 0); app.combat.ammo_shotgun = 40
	before = receipts(); world.collect(bait)
	check(world.traps.arena_one.triggered and not bait.visible, "saturated owned lure consumed and trap triggered")
	check(receipts() == before, "saturated owned lure has no false pickup cue receipt")
	world.collect(bait)
	check(receipts() == before and world.traps.arena_one.triggered, "duplicate lure collection cannot retrigger receipt")
	check("clear_arena_one" in world.missing_requirements(breaker), "breaker locked while triage populated")
	var arena_ids: Array[String] = []
	for enemy in app.combat.enemies:
		if String(enemy.get_meta("arena_id", "")) == "arena_one": arena_ids.append(String(enemy.target_id))
	check(arena_ids.size() == 5, "five original triage actors")
	world.notify_enemy_death(arena_ids[0]); var remaining: int = world.arena_remaining.arena_one
	world.notify_enemy_death(arena_ids[0])
	check(world.arena_remaining.arena_one == remaining, "duplicate death cannot decrement twice")
	for id in arena_ids.slice(1): world.notify_enemy_death(id)
	check(world.traps.arena_one.cleared and world.trap_entries.arena_one.opened, "last unique death clears trap and reopens entry")
	check(world.missing_requirements(breaker).is_empty(), "breaker enabled only after clear")
	app.player.global_position = shortcut.global_position + Vector3.RIGHT * 1.3
	check("breaker" in world.missing_requirements(shortcut) and "brass_key" in world.missing_requirements(shortcut), "supply-side release still requires both power and key")
	var saved_player: CharacterBody3D = world.player
	world.player = null
	check("first_open_side" in world.missing_requirements(shortcut), "missing player cannot release one-way shortcut")
	world.player = saved_player
	# Explicit state injection isolates door/receipt rules from route-use geometry.
	world.flags.breaker = true; world.flags.power = true
	before = receipts(); world.collect(brass); world.collect(brass)
	check(world.flags.get("brass_key", false) and world.flags.get("brass", false), "powered brass collection owns both key aliases")
	check(receipts() == before + 1, "brass collection and duplicate produce one receipt")
	app.player.global_position = shortcut.global_position - Vector3.RIGHT * 1.3
	check("first_open_side" in world.missing_requirements(shortcut), "entry-side first opening denied even with power and key")
	check(not world.try_use(app.player) and not shortcut.opened, "ordinary interaction rejects entry-side opening")
	app.player.global_position = shortcut.global_position + Vector3.RIGHT * .01
	check("first_open_side" in world.missing_requirements(shortcut), "door-plane ambiguity cannot release shortcut")
	app.player.global_position = shortcut.global_position + Vector3.RIGHT * 1.3
	check(world.missing_requirements(shortcut).is_empty(), "supply-side opening accepted with prerequisites")
	check(world.try_use(app.player) and shortcut.opened and world.shortcut_open, "ordinary interaction accepts supply release and owns shortcut state")
	app.player.global_position = shortcut.global_position - Vector3.RIGHT * 1.3
	check(world.missing_requirements(shortcut).is_empty(), "opened shortcut accepts both sides")
	world.reset()
	check(world.flags.is_empty() and world.collected.is_empty(), "reset clears progression and collected state")
	check(bait.visible and brass.visible and not shortcut.opened, "reset restores key, lure and closed shortcut")
	check(not world.traps.arena_one.triggered and world.arena_remaining.arena_one == 5, "reset restores untriggered five-actor encounter")
	check("first_open_side" in world.missing_requirements(shortcut), "reset restores one-way release requirement")
	finish()
func finish() -> void:
	var report := {"engine": Engine.get_version_info(), "scene_sha256": FileAccess.get_sha256("res://scenes/campaign/pale_ward_01.tscn"), "stage_runtime_sha256": FileAccess.get_sha256("res://scripts/stage_level.gd"), "fixture_sha256": FileAccess.get_sha256("res://tools/check_intake_progression_v7.gd"), "passed": failures.is_empty(), "checks": checks, "failures": failures, "scope": "Controlled actual Main Intake state transitions; direct collection and death notifications; no live traversal, enemy combat or listening claim."}
	var target := "/tmp/eyesore-intake-progression-v7.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): target = arg.trim_prefix("--report=")
	var file := FileAccess.open(target, FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(report, "  ") + "\n"); file.close()
	if is_instance_valid(app):
		app.menu_music.stop(); app.menu_music.stream = null
		app.combat_audio.stop_all(); app.free(); app = null
	await create_timer(.4, true).timeout
	print("INTAKE_V7_%s: %d checks" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)
