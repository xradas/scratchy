extends "res://scripts/release_stage_playtest.gd"
## Opt-in exported-package campaign acceptance. It reuses the proven physical
## movement, combat and E-use driver, but plans each distinct campaign graph.

var level_id := ""
var seed: Dictionary = {}
var route_path := ""
var current_route_room := "entry"
var all_levels := "--campaign-all-levels" in OS.get_cmdline_user_args()
var campaign_receipts: Array[Dictionary] = []

func run() -> void:
	if all_levels:
		await run_all_levels()
		return
	if not require(app.campaign_mode and not app.campaign.current_level().is_empty(), "Campaign route test requires a campaign level"):
		await finish()
		return
	level_id = String(app.campaign.current_level().id)
	stage_id = level_id
	world = app.world; player = app.player; combat = app.combat
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--release-report-dir="):
			report_dir = argument.trim_prefix("--release-report-dir=").simplify_path()
	if report_dir.is_empty(): report_dir = OS.get_user_data_dir().path_join("campaign-route-reports")
	package_dir = (ProjectSettings.globalize_path("res://") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir()).simplify_path().trim_suffix("/")
	if not require(report_dir.is_absolute_path() and not report_dir.begins_with("res://") and report_dir != package_dir and not report_dir.begins_with(package_dir + "/"), "Report directory must be absolute and outside project/package"):
		report_dir = OS.get_user_data_dir().path_join("campaign-route-reports")
		await finish()
		return
	route_path = "res://resources/campaign/" + level_id + "-route.json"
	var seeds_path := "res://resources/campaign/route-seeds.json"
	if not require(FileAccess.file_exists(route_path) and FileAccess.file_exists(seeds_path), "Route or loadout seed is unavailable"):
		await finish()
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(route_path))
	var seeded: Variant = JSON.parse_string(FileAccess.get_file_as_string(seeds_path))
	if not require(parsed is Dictionary and String(parsed.get("id", "")) == level_id and parsed.has("rooms") and parsed.has("portals") and seeded is Dictionary and seeded.get("seeds", {}).has(level_id), "Route or loadout seed is invalid"):
		await finish()
		return
	route = parsed
	seed = seeded.seeds[level_id]
	require(world.scene_file_path == String(app.campaign.current_level().scene) and String(world.get_meta("campaign_level_id", "")) == level_id, "Main loaded wrong authored level")
	require(String(route.get("theme", "")) == String(app.campaign.current_level().theme) and String(world.get_meta("stage_id", "")) == String(route.theme), "Route, scene and catalog theme disagree")
	require(world.flags.is_empty() and not world.finished and combat.kills == 0 and combat.shot_counter == 0 and combat.total_enemies > 0, "Initial stage progression/combat changed")
	require(get_tree().paused and not app.started, "Main title did not pause initial stage")
	if not validate_seed():
		await finish()
		return
	apply_seed()
	baseline = {"health": combat.health, "armor": combat.armor, "pistol": combat.ammo_pistol, "shells": combat.ammo_shotgun, "rivets": combat.ammo_rivets, "rockets": combat.ammo_rockets, "owned_weapons": combat.owned_weapons.keys(), "kills": combat.kills, "total": combat.total_enemies, "shots": combat.shot_counter}
	combat.combat_event.connect(observe_weapon_event)
	var initial: Vector3 = combat.enemies[0].position
	for frame in 6: await get_tree().process_frame
	require(combat.enemies[0].position == initial, "Title pause did not freeze creatures")
	if failures.is_empty():
		app.enter_combat()
		require(not get_tree().paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Main did not begin campaign combat")
		await get_tree().physics_frame
		global_start = Engine.get_physics_frames()
		await route_run()
		if not failures.is_empty():
			await finish()
			return
		require(world.finished and app.level_complete and get_tree().paused, "Real exit did not reach Main completion menu")
		require(not combat.dead and combat.health > 0, "Player did not survive finite route")
		require(not world.secret_found and world.secrets.is_empty(), "Route used a secret supply")
		for flag in ["breaker", "power", "brass_key", "release", "red_key", "exit_control", "exit"]:
			require(bool(world.flags.get(flag, false)), "Required progression flag missing: " + flag)
		for arena in ["arena_one", "arena_two", "final_arena"]:
			require(int(world.arena_remaining.get(arena, -1)) == 0, "Arena uncleared: " + arena)
		require(combat.shot_counter > 0 and combat.kills > 0, "Route lacked authoritative combat")
	await finish()

func run_all_levels() -> void:
	level_id = "campaign-all"
	world = app.world; player = app.player; combat = app.combat
	report_dir = OS.get_user_data_dir().path_join("campaign-route-reports")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--release-report-dir="):
			report_dir = argument.trim_prefix("--release-report-dir=").simplify_path()
	package_dir = (ProjectSettings.globalize_path("res://") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir()).simplify_path().trim_suffix("/")
	if not require(report_dir.is_absolute_path() and not report_dir.begins_with("res://") and report_dir != package_dir and not report_dir.begins_with(package_dir + "/"), "Report directory must be absolute and outside project/package"):
		report_dir = OS.get_user_data_dir().path_join("campaign-route-reports")
		await finish_all_levels()
		return
	if not require(app.campaign_mode and app.campaign.current_index == 0 and app.campaign.levels.size() == 9, "Continuous campaign must start at Ward Intake"):
		await finish_all_levels()
		return
	var expected_carry: Dictionary = {}
	for index in app.campaign.levels.size():
		world = app.world; player = app.player; combat = app.combat
		level_id = String(app.campaign.current_level().id)
		stage_id = level_id
		route_path = "res://resources/campaign/" + level_id + "-route.json"
		if not require(FileAccess.file_exists(route_path), "Missing authored route: " + level_id): break
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(route_path))
		if not require(parsed is Dictionary and String(parsed.get("id", "")) == level_id and parsed.has("rooms") and parsed.has("portals"), "Invalid authored route: " + level_id): break
		route = parsed
		if not require(world.scene_file_path == String(app.campaign.current_level().scene) and String(world.get_meta("campaign_level_id", "")) == level_id and String(world.get_meta("stage_id", "")) == String(route.theme), "Wrong campaign scene/theme: " + level_id): break
		if not require(world.flags.is_empty() and not world.finished and combat.kills == 0 and combat.shot_counter == 0, "Dirty entry state: " + level_id): break
		var entry: Dictionary = app.campaign.capture(combat)
		if index == 0:
			require(entry.health == 100.0 and entry.armor == 50.0 and entry.ammo_pistol == 36 and entry.ammo_shotgun == 12 and entry.ammo_rivets == 0 and entry.ammo_rockets == 0 and entry.owned_weapons.size() == 3, "Continuous campaign initial loadout is not normal")
		else:
			for field in app.campaign.COMBAT_FIELDS:
				require(entry[field] == expected_carry[field], "Exit state failed to carry " + field + " into " + level_id)
		if not failures.is_empty(): break
		current_route_room = "entry"
		records.clear(); interactions.clear(); weapon_shots.clear(); weapon_kills.clear(); arsenal_events.clear()
		ticks = 0
		combat.combat_event.connect(observe_weapon_event)
		if index == 0:
			require(get_tree().paused and not app.started, "Main did not begin at campaign title")
			app.enter_combat()
		if not require(not get_tree().paused and app.started, "Campaign combat did not resume at " + level_id): break
		await get_tree().physics_frame
		global_start = Engine.get_physics_frames()
		print("CAMPAIGN_ROUTE_START ", level_id)
		await route_run()
		if not failures.is_empty():
			campaign_receipts.append({"level": level_id, "chapter": String(app.campaign.current_level().chapter_id), "scene": world.scene_file_path, "route_resource": route_path, "entry_loadout": entry, "completed": false, "health": combat.health, "kills": combat.kills, "shots": combat.shot_counter, "segments": records.duplicate(true), "interactions": interactions.duplicate(true), "flags": world.flags.duplicate()})
			break
		var cleared: bool = world.finished and app.level_complete and get_tree().paused
		require(cleared, "Physical route did not reach Main completion screen: " + level_id)
		require(not combat.dead and combat.health > 0, "Player died in continuous campaign: " + level_id)
		require(not world.secret_found and world.secrets.is_empty(), "Secret supply used in " + level_id)
		for flag in ["breaker", "power", "brass_key", "release", "red_key", "exit_control", "exit"]:
			require(bool(world.flags.get(flag, false)), "Required progression flag missing in " + level_id + ": " + flag)
		for arena in ["arena_one", "arena_two", "final_arena"]:
			require(int(world.arena_remaining.get(arena, -1)) == 0, "Arena uncleared in " + level_id + ": " + arena)
		require(combat.shot_counter > 0 and combat.kills > 0, "No authoritative shots/kills in " + level_id)
		var exit_state: Dictionary = app.campaign.capture(combat)
		campaign_receipts.append({"level": level_id, "chapter": String(app.campaign.current_level().chapter_id), "scene": world.scene_file_path, "route_resource": route_path, "entry_loadout": entry, "exit_loadout": exit_state, "completed": cleared, "health": combat.health, "kills": combat.kills, "total_enemies": combat.total_enemies, "shots": combat.shot_counter, "weapon_shots": weapon_shots.duplicate(), "weapon_kills": weapon_kills.duplicate(), "flags": world.flags.duplicate(), "secret_used": world.secret_found, "interactions": interactions.duplicate(true), "segments": records.duplicate(true), "physics_seconds": float(Engine.get_physics_frames() - global_start) / Engine.physics_ticks_per_second})
		print("CAMPAIGN_ROUTE_LEVEL ", JSON.stringify({"level": level_id, "completed": cleared, "health": combat.health, "kills": combat.kills, "shots": combat.shot_counter}))
		if not failures.is_empty(): break
		expected_carry = exit_state
		if index < app.campaign.levels.size() - 1:
			var previous_world: Node = world
			app.enter_combat()
			await get_tree().process_frame
			if not require(app.campaign.current_index == index + 1 and app.world != previous_world and not get_tree().paused, "Continue did not load next level after " + level_id): break
		else:
			require(app.menu_title.text == "CAMPAIGN COMPLETE", "Final level did not show campaign finale")
	await finish_all_levels()

func finish_all_levels() -> void:
	stop(); key(KEY_E, false)
	var receipt_path := report_dir.path_join("campaign-all-route.json")
	var completed_count := 0
	for receipt in campaign_receipts:
		if bool(receipt.get("completed", false)): completed_count += 1
	var report := {"campaign": "Eyesore", "levels_completed": completed_count, "expected_levels": app.campaign.levels.size() if is_instance_valid(app) else 9, "initial_loadout": campaign_receipts[0].entry_loadout if not campaign_receipts.is_empty() else {}, "levels": campaign_receipts, "finale": app.menu_title.text if is_instance_valid(app) else "", "source_package_dir": package_dir, "executable": OS.get_executable_path(), "engine_arguments": OS.get_cmdline_args(), "physics_ticks_per_second": Engine.physics_ticks_per_second, "editor_feature": OS.has_feature("editor"), "failures": failures, "scope": "Single continuous native Main campaign: normal starting loadout, actual exit health/ammo/ownership carried by Continue through all nine physical routes; real CharacterBody movement, AI, damage, weapon rays and E-use. No reseed, teleport, secret supply or completion signal injection. Fixed simulation rate is explicit in engine arguments when used; this is automated gameplay, not a human duration."}
	var error := DirAccess.make_dir_recursive_absolute(report_dir)
	require(error == OK, "Could not create report directory")
	if error == OK:
		var file := FileAccess.open(receipt_path, FileAccess.WRITE)
		if require(file != null, "Could not write continuous campaign receipt"):
			report.failures = failures.duplicate()
			file.store_string(JSON.stringify(report, "  "))
			file.close()
	print("CAMPAIGN_ALL_ROUTE_OK " if failures.is_empty() and completed_count == 9 else "CAMPAIGN_ALL_ROUTE_FAILED ", JSON.stringify({"levels_completed": completed_count, "receipt": receipt_path, "failures": failures}))
	if is_instance_valid(app.menu_music):
		app.menu_music.stream_paused = false; app.menu_music.stop(); app.menu_music.stream = null
	if is_instance_valid(app.combat_audio): app.combat_audio.stop_all()
	var retire_until := Time.get_ticks_msec() + 300
	while Time.get_ticks_msec() < retire_until: await get_tree().process_frame
	await app.quit_game()
	if not failures.is_empty() or completed_count != 9: get_tree().quit(1)

func validate_seed() -> bool:
	var allowed := ["pistol", "shotgun", "melee", "twin_shotgun", "rivet_cannon", "siege_launcher"]
	var expected: Array = ["pistol", "shotgun", "melee"]
	if app.campaign.current_index >= 1: expected.append("twin_shotgun")
	if app.campaign.current_index >= 2: expected.append("rivet_cannon")
	if app.campaign.current_index >= 3: expected.append("siege_launcher")
	var ownership: Array = seed.get("owned_weapons", [])
	if not require(ownership.size() == expected.size(), "Seed ownership does not match campaign progression"): return false
	for id in ownership:
		if not require(id in allowed and id in expected, "Seed has an unavailable weapon: " + String(id)): return false
	for field in ["health", "armor", "ammo_pistol", "ammo_shotgun", "ammo_rivets", "ammo_rockets"]:
		if not require(seed.has(field) and float(seed[field]) >= 0.0, "Seed missing/negative " + field): return false
	return require(float(seed.health) <= 100.0 and float(seed.armor) <= 50.0 and int(seed.ammo_pistol) <= 36 and int(seed.ammo_shotgun) <= 12 and int(seed.ammo_rivets) <= 12 and int(seed.ammo_rockets) <= 3, "Seed exceeds finite campaign fixture bounds")

func apply_seed() -> void:
	for field in ["health", "armor", "ammo_pistol", "ammo_shotgun", "ammo_rivets", "ammo_rockets"]: combat.set(field, seed[field])
	combat.owned_weapons.clear()
	for id in seed.owned_weapons: combat.owned_weapons[StringName(id)] = true
	combat.currentweapon = &"pistol"
	app.campaign.entry_snapshot = app.campaign.capture(combat)

func gate_available(portal: Dictionary) -> bool:
	var gate := String(portal.get("gate", ""))
	if gate.begins_with("secret") or gate.begins_with("shortcut") or bool(portal.get("lift", false)): return false
	match gate:
		"breaker": return bool(world.flags.get("breaker", false))
		"brass_gate": return bool(world.flags.get("brass_key", false))
		"release": return bool(world.flags.get("release", false))
		"red_gate": return bool(world.flags.get("red_key", false))
		"exit_gate": return bool(world.flags.get("exit", false))
	return true

func path_to(destination: String) -> Array[String]:
	var queue: Array[String] = [current_route_room]
	var parent: Dictionary = {}
	parent[current_route_room] = ""
	while not queue.is_empty():
		var here: String = queue.pop_front()
		if here == destination: break
		for portal in route.portals:
			if not gate_available(portal): continue
			var neighbor := ""
			if String(portal.from) == here: neighbor = String(portal.to)
			elif String(portal.to) == here: neighbor = String(portal.from)
			if neighbor.is_empty() or parent.has(neighbor): continue
			parent[neighbor] = here
			queue.append(neighbor)
	if not parent.has(destination): return []
	var result: Array[String] = []
	var cursor := destination
	while cursor != current_route_room:
		result.push_front(cursor)
		cursor = String(parent[cursor])
	return result

func travel_to(destination: String) -> bool:
	var path := path_to(destination)
	if destination != current_route_room and not require(not path.is_empty(), "No unlocked authored path to " + destination): return false
	for next_room in path:
		if not await connect_rooms(current_route_room, next_room): return false
		current_route_room = next_room
	return true

func clear_arena(id: String) -> bool:
	if not route.has("combat_flanks") or not route.combat_flanks.has(id): return await super.clear_arena(id)
	# A campaign arena can have different perimeter geometry. Search only the
	# walkable lanes declared by that level's route, while all kills still use
	# live AI visibility and authoritative weapon fire.
	var bait: Node3D = world.get_node_or_null("Bait_" + id)
	if bait != null and not world.traps.get(id, {}).get("triggered", false):
		if id == "arena_two":
			var floor_point: Vector3 = vector(route.rooms[id].center)
			if not await walk(floor_point + Vector3(0, 0, 13), "Altar stair approach"): return false
			if not await walk(floor_point + Vector3(0, 2, 5), "Climb altar stairs"): return false
		if id == "final_arena" and route.vertical_routes.has(id + "_gallery"):
			var gallery: Array = route.vertical_routes[id + "_gallery"]
			if not await walk(vector(gallery[0]), "Launcher gallery stair approach"): return false
			if not await walk(vector(gallery[1]), "Climb launcher gallery stairs"): return false
		if not await walk(bait.global_position, "Physical weapon cache " + id): return false
		world.update_player(player, combat)
		if not require(bool(world.traps.get(id, {}).get("triggered", false)), id + ": physical bait did not trigger ambush"): return false
		for frame in 130:
			await tick(player.global_position, false)
			if world.is_arena_active(id): break
		if not require(world.is_arena_active(id) or int(world.arena_remaining.get(id, 0)) == 0, id + ": closet opening did not wake enemies"): return false
	var start := ticks
	var patrols := 0
	while int(world.arena_remaining.get(id, 0)) > 0:
		if combat.dead or ticks - start > 6000:
			failures.append(id + ": arena clear failed after physical combat")
			return false
		var target := closest_enemy()
		if target != null:
			await tick(room_center(id))
			continue
		if patrols == 0 and not await return_to_arena_staging(id): return false
		patrols += 1
		if patrols > 3:
			var survivors: Array[String] = []
			for enemy in combat.enemies:
				if not enemy.dead and String(enemy.get_meta("arena_id", "")) == id:
					survivors.append("%s at %s awake=%s visible=%s" % [String(enemy.target_id), str(enemy.global_position), str(enemy.awake), str(enemy.can_see_player())])
			failures.append(id + ": remaining enemies cannot be exposed from authored flanks: " + str(survivors))
			return false
		if patrols > 1 and route.combat_flanks[id].size() >= 8:
			for bridge in [route.combat_flanks[id][7], route.combat_flanks[id][6], route.combat_flanks[id][0]]:
				if not await walk(vector(bridge), "Combat flank return " + id): return false
		for waypoint in route.combat_flanks[id]:
			if int(world.arena_remaining.get(id, 0)) == 0: break
			if not await walk(vector(waypoint), "Authored combat flank " + id): return false
	stop()
	return true

func route_run() -> void:
	if not await travel_to("arena_one"): return
	if not await clear_arena("arena_one") or not await button("breaker"): return
	if not await travel_to("key_console") or not await key_room("key_console", "brass_key"): return
	if not await travel_to("arena_two"): return
	if not await clear_arena("arena_two") or not await button("release"): return
	if not await travel_to("red_console") or not await key_room("red_console", "red_key"): return
	if not await travel_to("final_arena"): return
	if not await clear_arena("final_arena") or not await button("exit_control"): return
	if not await travel_to("exit_gallery"): return
	var exit: Node3D = world.get_node_or_null("ExitControl")
	if not require(exit != null, "Authored exit absent"): return
	if not await walk(exit.global_position + Vector3(0, -0.18, 1.3), "Enabled campaign exit"): return
	if not await use("ExitControl"): return
	require(world.finished and app.level_complete and get_tree().paused, "Main completion screen absent after physical E use")

func finish() -> void:
	stop(); key(KEY_E, false)
	var receipt_path := report_dir.path_join(level_id + "-campaign-route.json")
	var report := {"campaign_level": level_id, "theme": String(route.get("theme", "")), "scene": world.scene_file_path if is_instance_valid(world) else "", "route_resource": route_path, "seed_resource": "res://resources/campaign/route-seeds.json", "seed": seed, "source_package_dir": package_dir, "executable": OS.get_executable_path(), "engine_arguments": OS.get_cmdline_args(), "physics_ticks_per_second": Engine.physics_ticks_per_second, "editor_feature": OS.has_feature("editor"), "completed": world.finished if is_instance_valid(world) else false, "completion_menu_paused": app.level_complete and get_tree().paused, "baseline": baseline, "health": combat.health if is_instance_valid(combat) else 0, "armor": combat.armor if is_instance_valid(combat) else 0, "kills": combat.kills if is_instance_valid(combat) else 0, "total_enemies": combat.total_enemies if is_instance_valid(combat) else 0, "shots": combat.shot_counter if is_instance_valid(combat) else 0, "final_ammo": final_ammo() if is_instance_valid(combat) else {}, "weapon_shots": weapon_shots, "weapon_kills": weapon_kills, "flags": world.flags.duplicate() if is_instance_valid(world) else {}, "secret_used": world.secret_found if is_instance_valid(world) else false, "interactions": interactions, "segments": records, "physics_seconds": float(Engine.get_physics_frames() - global_start) / Engine.physics_ticks_per_second if global_start > 0 else 0.0, "failures": failures, "scope": "Opt-in native Main campaign route: finite source-declared loadout; physical CharacterBody movement, AI, ordinary damage, real weapon rays and E-use. No teleport, secret supplies or completion signal injection. Fixed simulation rate is explicit in engine arguments when used."}
	var error := DirAccess.make_dir_recursive_absolute(report_dir)
	require(error == OK, "Could not create report directory")
	if error == OK:
		var file := FileAccess.open(receipt_path, FileAccess.WRITE)
		if require(file != null, "Could not write campaign receipt"):
			report.failures = failures.duplicate()
			file.store_string(JSON.stringify(report, "  "))
			file.close()
	print("CAMPAIGN_ROUTE_OK " if failures.is_empty() else "CAMPAIGN_ROUTE_FAILED ", JSON.stringify({"level": level_id, "receipt": receipt_path, "failures": failures}))
	if is_instance_valid(app.menu_music):
		app.menu_music.stream_paused = false; app.menu_music.stop(); app.menu_music.stream = null
	if is_instance_valid(app.combat_audio): app.combat_audio.stop_all()
	var retire_until := Time.get_ticks_msec() + 300
	while Time.get_ticks_msec() < retire_until: await get_tree().process_frame
	await app.quit_game()
	if not failures.is_empty(): get_tree().quit(1)
