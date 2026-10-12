extends "res://scripts/release_stage_playtest.gd"
## Opt-in exported-package campaign acceptance. It reuses the proven physical
## movement, combat and E-use driver, but plans each distinct campaign graph.

var level_id := ""
var seed: Dictionary = {}
var route_path := ""
var current_route_room := "entry"
var all_levels := "--campaign-all-levels" in OS.get_cmdline_user_args()
var campaign_receipts: Array[Dictionary] = []
var peak_ammo: Dictionary = {}
var accepted_ammo: Dictionary = {}
var siege_self_hits := 0
var last_player_hurt: Dictionary = {}
var chest_aim_fallbacks := 0

func ammo_state() -> Dictionary:
	return {"pistol": combat.ammo_pistol, "shells": combat.ammo_shotgun, "rivets": combat.ammo_rivets, "rockets": combat.ammo_rockets}

func ammo_caps() -> Dictionary:
	return {"pistol": combat.ammo_capacity(&"pistol"), "shells": combat.ammo_capacity(&"shells"), "rivets": combat.ammo_capacity(&"rivets"), "rockets": combat.ammo_capacity(&"rockets")}

func reset_ammo_ledger() -> void:
	peak_ammo = ammo_state()
	accepted_ammo = {"pistol": 0, "shells": 0, "rivets": 0, "rockets": 0}
	siege_self_hits = 0
	last_player_hurt.clear()
	chest_aim_fallbacks = 0
	sample_ammo()

func sample_ammo() -> void:
	var values := ammo_state()
	var capacities := ammo_caps()
	for kind in values:
		peak_ammo[kind] = maxi(int(peak_ammo.get(kind, 0)), int(values[kind]))
		if int(values[kind]) < 0 or int(values[kind]) > int(capacities[kind]):
			require(false, "Campaign ammo outside capacity: %s=%d/%d" % [kind, values[kind], capacities[kind]])

func observe_weapon_event(event: Dictionary) -> void:
	super.observe_weapon_event(event)
	if String(event.get("type", "")) == "ammo_added":
		var kind := String(event.get("ammo_kind", ""))
		kind = "shells" if kind == "ammo_shotgun" else kind.trim_prefix("ammo_")
		if accepted_ammo.has(kind): accepted_ammo[kind] = int(accepted_ammo[kind]) + int(event.get("amount", 0))
	if String(event.get("type", "")) == "player_hurt" and String(event.get("source_id", "")) == "player_siege_launcher": siege_self_hits += 1
	if String(event.get("type", "")) == "player_hurt": last_player_hurt = {"source_id": String(event.get("source_id", "")), "damage": float(event.get("damage", 0)), "physics_tick": Engine.get_physics_frames()}
	if String(event.get("type", "")) in ["ammo_added", "weapon_granted", "shot"]: sample_ammo()

func failure_state() -> Dictionary:
	var living: Array[Dictionary] = []
	for enemy in combat.enemies:
		if enemy.dead: continue
		living.append({"id": String(enemy.target_id), "position": enemy.global_position, "arena": String(enemy.get_meta("arena_id", "")), "awake": enemy.awake})
	return {"player_position": player.global_position, "health": combat.health, "armor": combat.armor, "ammo": ammo_state(), "weapon": String(combat.currentweapon), "arena_remaining": world.arena_remaining.duplicate(), "living_enemies": living, "last_player_hurt": last_player_hurt.duplicate(), "siege_self_hits": siege_self_hits, "bot_visible_chest_fallbacks": chest_aim_fallbacks}

func siege_has_safe_swept_path(target: CharacterBody3D, distance: float) -> bool:
	# Match the actual 0.09 m swept projectile, including moving doors, stair
	# edges and other enemies. A visible target is insufficient if nearby
	# geometry would detonate the round inside its self-damage radius.
	var definition: WeaponDefinition = combat.weapons[&"siege_launcher"]
	var origin: Vector3 = player.camera.global_position
	var direction: Vector3 = -player.camera.global_basis.z
	var sweep := SphereShape3D.new()
	sweep.radius = 0.09
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sweep
	query.transform = Transform3D(Basis.IDENTITY, origin)
	query.motion = direction * minf(distance + 2.0, definition.range_units)
	query.collision_mask = 15
	query.exclude = combat.anatomical_exclusions()
	var space := player.get_world_3d().direct_space_state
	if not space.intersect_shape(query, 1).is_empty(): return false
	var fractions: PackedFloat32Array = space.cast_motion(query)
	if fractions[0] >= 1.0: return false
	var impact_distance: float = query.motion.length() * fractions[0]
	if impact_distance <= definition.blast_radius + 2.0: return false
	query.transform.origin = origin + query.motion * minf(1.0, fractions[1] + 0.002)
	query.motion = Vector3.ZERO
	var contact: Dictionary = space.get_rest_info(query)
	if contact.is_empty(): return false
	var collider: Object = instance_from_id(int(contact.collider_id))
	if collider == null: return false
	var hit_target: Object = collider.get_meta("combat_target") if collider.has_meta("combat_target") else collider
	return hit_target == target or (hit_target.has_method("apply_damage") and not hit_target.dead)

func aim_ray_hits_target(target: CharacterBody3D, point: Vector3) -> bool:
	var origin: Vector3 = player.camera.global_position
	var direction: Vector3 = origin.direction_to(point)
	var hit: Dictionary = combat.ray(origin, origin + direction * 70.0, combat.anatomical_exclusions(), true)
	if hit.is_empty(): return false
	var collider: Object = hit.collider
	return collider == target or (collider.has_meta("combat_target") and collider.get_meta("combat_target") == target)

func visible_aim_point(target: CharacterBody3D) -> Vector3:
	# The fixed actor-centre ray crosses transparent gaps in some live pain and
	# windup sprites. Only when it misses the current anatomical collider, aim
	# at the closest visible triangle on the existing opaque hurt mesh. This is
	# bot camera control, using the same geometry and ray as real player fire.
	var center: Vector3 = target.global_position + Vector3(0, 0.28, 0)
	if aim_ray_hits_target(target, center): return center
	var nearest := INF
	var chest := center
	for body_value in target.sprite_bodies.values():
		var body: StaticBody3D = body_value
		if body.collision_layer & 4 == 0: continue
		var shape: Shape3D = body.get_node("HitSurface").shape
		if not shape is ConcavePolygonShape3D: continue
		var faces: PackedVector3Array = shape.get_faces()
		for i in range(0, faces.size(), 3):
			var point: Vector3 = body.to_global((faces[i] + faces[i + 1] + faces[i + 2]) / 3.0)
			var distance: float = point.distance_squared_to(center)
			if distance < nearest:
				nearest = distance
				chest = point
	if nearest < INF and aim_ray_hits_target(target, chest):
		chest_aim_fallbacks += 1
		return chest
	return center

func choose_weapon(target: CharacterBody3D, distance: float) -> StringName:
	player.camera.look_at(visible_aim_point(target))
	if not heavy_mode:
		var ordinary: StringName = super.choose_weapon(target, distance)
		var species := String(target.definition.identifier)
		if combat.has_weapon(&"rivet_cannon") and combat.ammo_rivets > 0 and distance > 7.0 and distance < 36.0 and species in ["censer", "vessel", "ironbound"]:
			return &"rivet_cannon"
		if ordinary != &"melee": return ordinary
		# The baseline route conserves specialist ammunition until its carried
		# pistol and shell pools are empty; it never pretends an owned gun is out
		# of reach when its real ammunition is still in the pack.
		if combat.has_weapon(&"rivet_cannon") and combat.ammo_rivets > 0: return &"rivet_cannon"
		if combat.has_weapon(&"siege_launcher") and combat.ammo_rockets > 0 and distance > 10.0 and distance < 28.0 and target.can_see_player() and siege_has_safe_swept_path(target, distance): return &"siege_launcher"
		return ordinary
	var nearby := 0
	for enemy in combat.enemies:
		if not enemy.dead and enemy.global_position.distance_to(target.global_position) < 4.8:
			nearby += 1
	# Save the scarce launcher for visible groups or a tough ranged threat, and
	# keep its blast safely away from the player. This is bot policy, not damage.
	var only_rockets_left: bool = combat.ammo_pistol == 0 and combat.ammo_shotgun == 0 and combat.ammo_rivets == 0
	if combat.has_weapon(&"siege_launcher") and combat.ammo_rockets > 0 and distance > 10.0 and distance < 28.0 and (nearby >= 2 or only_rockets_left) and target.can_see_player() and siege_has_safe_swept_path(target, distance):
		return &"siege_launcher"
	if combat.has_weapon(&"twin_shotgun") and combat.ammo_shotgun >= 2 and distance < 7.0:
		return &"twin_shotgun"
	if combat.has_weapon(&"rivet_cannon") and combat.ammo_rivets > 0 and distance >= 8.0 and distance < 36.0:
		return &"rivet_cannon"
	if combat.ammo_shotgun > 0 and distance < 17.0: return &"shotgun"
	if combat.ammo_pistol > 0: return &"pistol"
	if combat.ammo_shotgun > 0: return &"shotgun"
	if combat.has_weapon(&"rivet_cannon") and combat.ammo_rivets > 0: return &"rivet_cannon"
	return &"melee"

func walk(point: Vector3, label: String) -> bool:
	# Keep physical movement committed to the authored waypoint while the
	# camera aims and fires at visible threats. The generic walker's combat
	# strafe can otherwise chase a target indefinitely and abandon the route.
	# AI, damage, ammunition and real weapon rays remain active throughout.
	var start := ticks
	while horizontal(player.global_position, point) > 0.28:
		if combat.dead or ticks - start > 3600:
			failures.append(label + (": player died" if combat.dead else ": traversal stalled at " + str(player.global_position)))
			stop()
			return false
		await travel_tick(point)
	stop()
	for frame in 5: await get_tree().physics_frame
	world.update_player(player, combat)
	records.append({"segment": label, "ticks": ticks - start, "position": player.global_position, "health": combat.health, "armor": combat.armor, "pistol": combat.ammo_pistol, "shells": combat.ammo_shotgun, "rivets": combat.ammo_rivets, "rockets": combat.ammo_rockets, "kills": combat.kills})
	return true

func travel_tick(destination: Vector3) -> void:
	stop()
	var direction: Vector3 = destination - player.global_position
	var progress := Vector2(direction.x, direction.z).length()
	player.rotation.y = atan2(-direction.x, -direction.z)
	var target: CharacterBody3D = closest_enemy()
	if target != null:
		player.camera.look_at(target.global_position + Vector3(0, 0.28, 0))
		var distance := horizontal(target.global_position, player.global_position)
		var weapon: StringName = choose_weapon(target, distance)
		if combat.currentweapon != weapon: combat.select_weapon(weapon)
		else: combat.try_fire()
	else:
		player.camera.rotation = Vector3.ZERO
	key(KEY_W, progress > 0.23)
	await get_tree().physics_frame
	ticks += 1

func tick(destination: Vector3, fight := true) -> void:
	if fight and combat.has_weapon(&"siege_launcher") and combat.ammo_rockets > 0 and combat.ammo_pistol == 0 and combat.ammo_shotgun == 0 and combat.ammo_rivets == 0:
		var target: CharacterBody3D = closest_enemy()
		if target != null:
			var distance := horizontal(target.global_position, player.global_position)
			if distance < 28.0 and (distance < 11.0 or not siege_has_safe_swept_path(target, distance)):
				# A loaded but unsafe launcher is not a reason to charge with
				# melee. Reposition physically until the swept blast lane clears.
				stop()
				var offset: Vector3 = target.global_position - player.global_position
				player.rotation.y = atan2(-offset.x, -offset.z)
				player.camera.look_at(target.global_position + Vector3(0, 0.28, 0))
				if distance < 11.0 and not player.test_move(player.global_transform, player.global_basis.z * 0.6):
					key(KEY_S, true)
				else:
					var lateral: Vector3 = player.global_basis.x * avoid_side
					if player.test_move(player.global_transform, lateral * 0.8): avoid_side *= -1
					key(KEY_D if avoid_side > 0 else KEY_A, true)
				await get_tree().physics_frame
				ticks += 1
				return
	await super.tick(destination, fight)

func interior_exposure(id: String) -> bool:
	# Search the inner floor from the traversable north rim, approaching the
	# last occluded arena targets from ahead of their live positions. Side
	# flanks alone cannot see behind some central plinths/gallery supports.
	var room: Dictionary = route.rooms[id]
	var center: Vector3 = vector(room.center)
	var north: Vector3 = room_center(id)
	if not await return_to_arena_staging(id): return false
	for enemy in combat.enemies:
		if enemy.dead or String(enemy.get_meta("arena_id", "")) != id: continue
		var approach_x := clampf(enemy.global_position.x, center.x - 4.0, center.x + 4.0)
		var approach_z := clampf(enemy.global_position.z + 4.0, center.z - 8.0, north.z - 2.0)
		if not await walk(Vector3(approach_x, center.y, north.z), "Interior north lane " + id): return false
		if not await walk(Vector3(approach_x, center.y, approach_z), "Interior exposure " + id): return false
		for frame in 180:
			if enemy.dead or int(world.arena_remaining.get(id, 0)) == 0: break
			if closest_enemy() == null: break
			await tick(Vector3(approach_x, center.y, approach_z))
	return true

func return_to_arena_staging(id: String) -> bool:
	# The final court's west gallery foot is a physical opening into its north
	# staging rim. A direct sweep down the outer west lane from that corner runs
	# into the gallery support in Citadel03; retrace the traversed gallery foot.
	if id == "final_arena" and route.vertical_routes.has(id + "_gallery"):
		var room: Dictionary = route.rooms[id]
		var center: Vector3 = vector(room.center)
		var north_band: float = center.z + float(room.size[2]) / 2.0 - 12.0
		if player.global_position.x < center.x - 7.0 and player.global_position.z > north_band:
			var foot: Vector3 = vector(route.vertical_routes[id + "_gallery"][0])
			if not await walk(foot, "Gallery-foot retreat " + id): return false
			if not await walk(room_center(id), "North staging retreat " + id): return false
			return true
	return await super.return_to_arena_staging(id)

func connect_rooms(a: String, b: String) -> bool:
	# The cleared arena_two altar rises across its central diagonal. After the
	# south release control, traverse the already-authored side ring to the
	# north staging rim before the inherited portal connector heads west/east.
	if a == "arena_two":
		var room: Dictionary = route.rooms[a]
		var center: Vector3 = vector(room.center)
		if player.global_position.y < center.y + 1.0 and player.global_position.z < center.z - 4.0:
			var side := -1.0 if player.global_position.x < center.x else 1.0
			var lane_x: float = center.x + side * 4.3
			if not await walk(Vector3(lane_x, center.y, player.global_position.z), "Altar side connector " + a): return false
			if not await walk(Vector3(lane_x, center.y, room_center(a).z), "Altar north connector " + a): return false
	return await super.connect_rooms(a, b)

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
	reset_ammo_ledger()
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
		# Main snapshots the exact carry before a new level begins. A live
		# entry pickup can be contacted on the next process/physics frame, so
		# distinguish that actual starting state from the pre-contact carry.
		var entry: Dictionary = app.campaign.entry_snapshot.duplicate(true)
		var active_entry: Dictionary = app.campaign.capture(combat)
		reset_ammo_ledger()
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
			campaign_receipts.append({"level": level_id, "chapter": String(app.campaign.current_level().chapter_id), "scene": world.scene_file_path, "route_resource": route_path, "entry_loadout": entry, "active_entry_loadout": active_entry, "entry_ammo": {"pistol": active_entry.ammo_pistol, "shells": active_entry.ammo_shotgun, "rivets": active_entry.ammo_rivets, "rockets": active_entry.ammo_rockets}, "peak_ammo": peak_ammo.duplicate(), "ammo_caps": ammo_caps(), "accepted_ammo": accepted_ammo.duplicate(), "siege_self_hits": siege_self_hits, "bot_visible_chest_fallbacks": chest_aim_fallbacks, "use_heavy_weapons": heavy_mode, "completed": false, "health": combat.health, "kills": combat.kills, "shots": combat.shot_counter, "weapon_shots": weapon_shots.duplicate(), "weapon_kills": weapon_kills.duplicate(), "failure_state": failure_state(), "segments": records.duplicate(true), "interactions": interactions.duplicate(true), "flags": world.flags.duplicate()})
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
		sample_ammo()
		if heavy_mode: require(siege_self_hits == 0, "Heavy bot detonated Siege inside self-damage radius: " + level_id)
		campaign_receipts.append({"level": level_id, "chapter": String(app.campaign.current_level().chapter_id), "scene": world.scene_file_path, "route_resource": route_path, "entry_loadout": entry, "active_entry_loadout": active_entry, "exit_loadout": exit_state, "entry_ammo": {"pistol": active_entry.ammo_pistol, "shells": active_entry.ammo_shotgun, "rivets": active_entry.ammo_rivets, "rockets": active_entry.ammo_rockets}, "exit_ammo": ammo_state(), "peak_ammo": peak_ammo.duplicate(), "ammo_caps": ammo_caps(), "accepted_ammo": accepted_ammo.duplicate(), "siege_self_hits": siege_self_hits, "bot_visible_chest_fallbacks": chest_aim_fallbacks, "use_heavy_weapons": heavy_mode, "completed": cleared, "health": combat.health, "kills": combat.kills, "total_enemies": combat.total_enemies, "shots": combat.shot_counter, "weapon_shots": weapon_shots.duplicate(), "weapon_kills": weapon_kills.duplicate(), "flags": world.flags.duplicate(), "secret_used": world.secret_found, "interactions": interactions.duplicate(true), "segments": records.duplicate(true), "physics_seconds": float(Engine.get_physics_frames() - global_start) / Engine.physics_ticks_per_second})
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
	if heavy_mode and completed_count == 9:
		for weapon in ["twin_shotgun", "rivet_cannon", "siege_launcher"]:
			var shots := 0
			var kills := 0
			for receipt in campaign_receipts:
				shots += int(receipt.get("weapon_shots", {}).get(weapon, 0))
				kills += int(receipt.get("weapon_kills", {}).get(weapon, 0))
			require(shots > 0 and kills > 0, "Heavy route lacked authoritative shots/kills for " + weapon)
	var report := {"campaign": "Eyesore", "levels_completed": completed_count, "expected_levels": app.campaign.levels.size() if is_instance_valid(app) else 9, "initial_loadout": campaign_receipts[0].entry_loadout if not campaign_receipts.is_empty() else {}, "use_heavy_weapons": heavy_mode, "levels": campaign_receipts, "finale": app.menu_title.text if is_instance_valid(app) else "", "source_package_dir": package_dir, "executable": OS.get_executable_path(), "engine_arguments": OS.get_cmdline_args(), "physics_ticks_per_second": Engine.physics_ticks_per_second, "editor_feature": OS.has_feature("editor"), "failures": failures, "scope": "Single continuous native Main campaign: normal starting loadout, actual exit health/ammo/ownership carried by Continue through all nine physical routes; real CharacterBody movement, AI, damage, weapon rays and E-use. No reseed, teleport, secret supply or completion signal injection. Optional heavy-weapon selection is bot policy; combat tuning is unchanged. Fixed simulation rate is explicit in engine arguments when used; this is automated gameplay, not a human duration."}
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
	combat.normalize_ammo()
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
		if id == "final_arena" and route.vertical_routes.has(id + "_gallery"):
			var return_gallery: Array = route.vertical_routes[id + "_gallery"]
			if not await walk(vector(return_gallery[1]), "Retreat along launcher gallery"): return false
			if not await walk(vector(return_gallery[0]), "Descend launcher gallery under fire"): return false
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
			if not await interior_exposure(id): return false
			if int(world.arena_remaining.get(id, 0)) == 0: break
			var survivors: Array[String] = []
			for enemy in combat.enemies:
				if not enemy.dead and String(enemy.get_meta("arena_id", "")) == id:
					survivors.append("%s at %s awake=%s visible=%s" % [String(enemy.target_id), str(enemy.global_position), str(enemy.awake), str(enemy.can_see_player())])
			failures.append(id + ": remaining enemies cannot be exposed from authored flanks: " + str(survivors))
			return false
		if patrols > 1 and not await return_to_arena_staging(id): return false
		for flank_index in route.combat_flanks[id].size():
			if int(world.arena_remaining.get(id, 0)) == 0: break
			# Cross sides via the open north staging rim. A straight diagonal
			# between the final west point and first east point cuts through the
			# raised altar/stair collision in some campaign layouts.
			if flank_index == route.combat_flanks[id].size() / 2:
				if not await return_to_arena_staging(id): return false
			var waypoint: Array = route.combat_flanks[id][flank_index]
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
	# Optional release regression takes the real observation detour after
	# clearing the arena. Ordinary play and normal campaign tests are unchanged.
	if "--check-lift-route" in OS.get_cmdline_user_args() and world.has_node("Lift_Observation"):
		if not await ride_lift(): return
	if not await travel_to("exit_gallery"): return
	var exit: Node3D = world.get_node_or_null("ExitControl")
	if not require(exit != null, "Authored exit absent"): return
	if not await walk(exit.global_position + Vector3(0, -0.18, 1.3), "Enabled campaign exit"): return
	if not await use("ExitControl"): return
	require(world.finished and app.level_complete and get_tree().paused, "Main completion screen absent after physical E use")

func finish() -> void:
	stop(); key(KEY_E, false)
	var receipt_path := report_dir.path_join(level_id + "-campaign-route.json")
	var report := {"campaign_level": level_id, "theme": String(route.get("theme", "")), "scene": world.scene_file_path if is_instance_valid(world) else "", "route_resource": route_path, "seed_resource": "res://resources/campaign/route-seeds.json", "seed": seed, "source_package_dir": package_dir, "executable": OS.get_executable_path(), "engine_arguments": OS.get_cmdline_args(), "physics_ticks_per_second": Engine.physics_ticks_per_second, "editor_feature": OS.has_feature("editor"), "use_heavy_weapons": heavy_mode, "completed": world.finished if is_instance_valid(world) else false, "completion_menu_paused": app.level_complete and get_tree().paused, "lift_round_trip": lift_returned, "lift_route_requested": "--check-lift-route" in OS.get_cmdline_user_args(), "baseline": baseline, "entry_ammo": {"pistol": baseline.get("pistol", 0), "shells": baseline.get("shells", 0), "rivets": baseline.get("rivets", 0), "rockets": baseline.get("rockets", 0)}, "exit_ammo": ammo_state() if is_instance_valid(combat) else {}, "peak_ammo": peak_ammo, "ammo_caps": ammo_caps() if is_instance_valid(combat) else {}, "accepted_ammo": accepted_ammo, "siege_self_hits": siege_self_hits, "bot_visible_chest_fallbacks": chest_aim_fallbacks, "health": combat.health if is_instance_valid(combat) else 0, "armor": combat.armor if is_instance_valid(combat) else 0, "kills": combat.kills if is_instance_valid(combat) else 0, "total_enemies": combat.total_enemies if is_instance_valid(combat) else 0, "shots": combat.shot_counter if is_instance_valid(combat) else 0, "final_ammo": final_ammo() if is_instance_valid(combat) else {}, "weapon_shots": weapon_shots, "weapon_kills": weapon_kills, "flags": world.flags.duplicate() if is_instance_valid(world) else {}, "secret_used": world.secret_found if is_instance_valid(world) else false, "interactions": interactions, "segments": records, "physics_seconds": float(Engine.get_physics_frames() - global_start) / Engine.physics_ticks_per_second if global_start > 0 else 0.0, "failures": failures, "scope": "Opt-in native Main campaign route: finite source-declared loadout; physical CharacterBody movement, AI, ordinary damage, real weapon rays and E-use. No teleport, secret supplies or completion signal injection. Optional heavy-weapon selection is bot policy; combat tuning is unchanged. Fixed simulation rate is explicit in engine arguments when used."}
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
