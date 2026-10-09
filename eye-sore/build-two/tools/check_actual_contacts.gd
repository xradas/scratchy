extends SceneTree
## Integration fixture: real main, accepted shots, physics sprite/wall contacts,
## real installed audio profile and the owned surface light. No listening claim.
var app: Control
var trace: Array[Dictionary] = []
var results: Array[Dictionary] = []
var failures: Array[String] = []
var checks := 0
var wall: StaticBody3D
const OUT := "res://verification/grit/p11-actual-contacts.json"

func _initialize() -> void:
	call_deferred("run_check")

func check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		failures.append(message)
		push_error("P11_ACTUAL_CONTACTS_FAILED: " + message)
	return ok

func observe(event: Dictionary) -> void:
	var record := event.duplicate(true)
	record.audio_last_cue = String(app.combat_audio.last_cue)
	record.audio_counts = app.combat_audio.cue_counts.duplicate()
	record.light_shot_id = app.combat.weapon_lighting.active_shot_id
	record.light_visible = app.combat.weapon_lighting.flash.visible
	trace.append(record)

func exclusions() -> Array:
	var values: Array = [app.player.get_rid()]
	for enemy in app.combat.enemies:
		values.append(enemy.get_rid())
	return values

func front_pose(target: CharacterBody3D) -> void:
	target.dead = false
	target.gibbed = false
	target.health = 1000.0
	target.state = &"chase"
	target.state_time = 0.0
	target.velocity = Vector3.ZERO
	target.update_presentation()

func find_point(target: CharacterBody3D, material: StringName, weapon: StringName) -> Variant:
	# Discover an interior point through the installed front sprite hurt bodies.
	# Rank single-pellet points by nearby samples. For shotgun choose all seven
	# anatomical contacts with the requested dominant material using the exact next
	# shot spread seed. Combat.try_fire still performs every authoritative ray.
	var best: Variant = null
	var best_score := -1
	var camera: Camera3D = app.player.camera
	for yi in range(5, 85, 2):
		for xi in range(-24, 25, 2):
			var point: Vector3 = target.sprite_pivot.global_position + Vector3(xi * .025, yi * .025, 0)
			var hit: Dictionary = app.combat.ray(camera.global_position, point + (point-camera.global_position).normalized()*.2, exclusions(), true)
			if hit.is_empty() or not hit.collider.has_meta("combat_target") or hit.collider.get_meta("combat_target") != target or app.combat.material_for(hit.collider) != material:
				continue
			if weapon == &"shotgun":
				camera.look_at(point)
				var rng := RandomNumberGenerator.new()
				rng.seed = (app.combat.shot_counter+1)*7919+472
				var rotation := rng.randf_range(-.12,.12)
				var all_contacts := true
				var desired_contacts := 0
				var definition: WeaponDefinition = app.combat.weapons[weapon]
				for pellet in range(7):
					var yaw := 0.0
					var pitch := 0.0
					if pellet > 0:
						var angle := TAU*float(pellet-1)/6.0+rotation
						yaw = deg_to_rad(cos(angle)*definition.spread_degrees)
						pitch = deg_to_rad(sin(angle)*definition.vertical_spread_degrees)
					var direction := (-camera.global_basis.z).rotated(Vector3.UP,yaw).rotated(camera.global_basis.x,pitch).normalized()
					var pellet_hit: Dictionary = app.combat.ray(camera.global_position,camera.global_position+direction*definition.range_units,exclusions(),true)
					if pellet_hit.is_empty() or not pellet_hit.collider.has_meta("combat_target") or pellet_hit.collider.get_meta("combat_target") != target :
						all_contacts = false
						break
					if app.combat.material_for(pellet_hit.collider) == material: desired_contacts += 1
				if all_contacts and desired_contacts >= 4: return point
				continue
			var score := 0
			for offset in [Vector3(.04,0,0),Vector3(-.04,0,0),Vector3(0,.04,0),Vector3(0,-.04,0)]:
				var nearby: Vector3 = point + offset
				var sample: Dictionary = app.combat.ray(camera.global_position, nearby+(nearby-camera.global_position).normalized()*.2, exclusions(), true)
				if not sample.is_empty() and sample.collider.has_meta("combat_target") and sample.collider.get_meta("combat_target") == target and app.combat.material_for(sample.collider) == material:
					score += 1
			if score > best_score:
				best = point
				best_score = score
	return best

func accepted_shot(weapon: StringName, material: StringName, target: CharacterBody3D = null) -> void:
	var combat: Node3D = app.combat
	var audio: Node3D = app.combat_audio
	var light: Node3D = combat.weapon_lighting
	combat.currentweapon = weapon
	combat.weapon_phase = &"idle"
	combat.cooldown = 0.0
	light.reset()
	var before_counts: Dictionary = audio.cue_counts.duplicate()
	var before_trace := trace.size()
	var before_shot: int = combat.shot_counter
	var before_health: float = target.health if target != null else 0.0
	var world_health_before: Array = [combat.health, combat.armor]
	for enemy in combat.enemies: world_health_before.append(enemy.health)
	var before_ammo: int = combat.ammo_pistol if weapon == &"pistol" else combat.ammo_shotgun
	if not check(combat.try_fire(), "accepted real " + String(weapon) + "/" + String(material)):
		return
	var events: Array[Dictionary] = []
	for i in range(before_trace, trace.size()): events.append(trace[i])
	var shots: Array[Dictionary] = []
	var impacts: Array[Dictionary] = []
	var hurts: Array[Dictionary] = []
	for event in events:
		if event.type == &"shot": shots.append(event)
		if event.type == &"impact": impacts.append(event)
		if event.type == &"enemy_hurt": hurts.append(event)
	check(combat.shot_counter == before_shot+1 and shots.size() == 1, "one accepted shot identity")
	if not check(impacts.size() == 1, "one aggregated actual target impact"):
		return
	var impact: Dictionary = impacts[0]
	check(impact.material == material, "physics resolves expected " + String(material))
	check(impact.shot_id == combat.shot_counter, "contact belongs to accepted shot")
	var fire_cue := "melee_swing" if weapon == &"melee" else String(weapon)+"_fire"
	var contact_cue := String(weapon)+"_"+String(material)
	check(shots[0].audio_last_cue == fire_cue and int(audio.cue_counts.get(StringName(fire_cue),0))-int(before_counts.get(StringName(fire_cue),0)) == 1, "accepted shot routes own fire/swing cue once")
	check(impact.audio_last_cue == contact_cue and int(audio.cue_counts.get(StringName(contact_cue),0))-int(before_counts.get(StringName(contact_cue),0)) == 1, "actual impact routes own weapon/material cue once")
	check(shots[0].light_shot_id == (0 if weapon == &"melee" else combat.shot_counter) and shots[0].light_visible == (weapon != &"melee"), "same accepted shot owns surface flash")
	check(light.active_shot_id == (0 if weapon == &"melee" else impact.shot_id), "contact shares live flash shot identity")
	if weapon != &"melee":
		var ammo_after: int = combat.ammo_pistol if weapon == &"pistol" else combat.ammo_shotgun
		check(ammo_after == before_ammo-1, "accepted shot consumes exactly one ammunition")
	var damage := 0.0
	if target != null:
		var per_pellet := 20.0 if weapon == &"pistol" else (16.0 if weapon == &"shotgun" else 30.0)
		damage = before_health-target.health
		check(damage == per_pellet*int(impact.pellets), "actual health loss matches approved damage and contact pellets")
		check(int(impact.pellets) >= 1 and int(impact.pellets) <= (7 if weapon == &"shotgun" else 1), "pellet count bounded by weapon contract")
		check(hurts.size() == 1, "one pain event per actual aggregated damage")
		if hurts.size() == 1:
			var pain_cue := String(target.definition.identifier)+"_hurt"
			check(hurts[0].shot_id == impact.shot_id and hurts[0].material == material and hurts[0].damage == damage, "pain carries actual material damage and shot")
			check(audio.last_cue == StringName(pain_cue) and int(audio.cue_counts.get(StringName(pain_cue),0))-int(before_counts.get(StringName(pain_cue),0)) == 1, "actual enemy pain cue once")
	else:
		check(hurts.is_empty() and audio.last_cue == StringName(contact_cue), "hard wall creates own contact cue without enemy pain")
		var world_health_after: Array = [combat.health, combat.armor]
		for enemy in combat.enemies: world_health_after.append(enemy.health)
		check(world_health_after == world_health_before, "hard wall leaves all actor health and armor unchanged")
	# Replay only genuine observed events into the presentation consumer. This must
	# not change cue counters, authoritative health, ammo, or the surface flash.
	var counts_before_replay: Dictionary = audio.cue_counts.duplicate()
	var health_before_replay: float = target.health if target != null else 0.0
	for event in events: audio.handle_event(event)
	check(audio.cue_counts == counts_before_replay, "genuine event replay dedupes every presentation cue")
	check(target == null or target.health == health_before_replay, "presentation replay never repeats damage")
	results.append({"weapon":weapon,"material":material,"enemy":String(target.definition.identifier) if target != null else "wall","shot_id":impact.shot_id,"pellets":impact.pellets,"damage":damage,"health_before":before_health,"health_after":target.health if target != null else null,"contact_cue":contact_cue,"last_cue":audio.last_cue,"flash_shot_id":light.active_shot_id,"event_count":events.size(),"dedupe_unchanged":audio.cue_counts == counts_before_replay})

func rejected_checks() -> void:
	var combat: Node3D = app.combat
	var audio: Node3D = app.combat_audio
	var light: Node3D = combat.weapon_lighting
	# Active cooldown rejection must not refresh the existing flash or any voice.
	var counts: Dictionary = audio.cue_counts.duplicate()
	var previous_remaining: float = light.remaining
	var previous_shot: int = combat.shot_counter
	var previous_trace := trace.size()
	check(not combat.try_fire(), "cooldown rejects second click")
	check(audio.cue_counts == counts and trace.size() == previous_trace and combat.shot_counter == previous_shot and light.remaining == previous_remaining, "cooldown rejection has no event cue shot or refreshed light")
	for weapon in [&"pistol", &"shotgun"]:
		combat.currentweapon = weapon
		combat.cooldown = 0.0
		combat.weapon_phase = &"idle"
		combat.empty_cooldown = 0.0
		combat.set("ammo_"+String(weapon),0)
		light.reset()
		counts = audio.cue_counts.duplicate()
		previous_trace = trace.size()
		check(not combat.try_fire(), "empty ammunition rejects " + String(weapon))
		var expected := counts.duplicate()
		expected[&"empty"] = int(expected.get(&"empty",0))+1
		check(audio.cue_counts == expected and audio.last_cue == &"empty", "empty click creates only legitimate empty feedback")
		check(trace.size() == previous_trace+1 and trace.back().type == &"empty" and combat.shot_counter == previous_shot and not light.flash.visible and light.active_shot_id == 0 and light.remaining == 0.0, "empty rejection creates no accepted shot contact pain or surface flash")
		counts = audio.cue_counts.duplicate()
		check(not combat.try_fire() and audio.cue_counts == counts, "empty feedback throttle suppresses repeated immediate click")

func run_check() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://verification/grit"))
	app = preload("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.enter_combat()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	app.player.set_physics_process(false)
	app.combat.set_physics_process(false)
	app.world.set_process(false)
	app.world.set_physics_process(false)
	app.combat.weapon_lighting.set_process(false)
	app.player.position = Vector3(100,.87,100.6)
	app.player.rotation = Vector3.ZERO
	app.player.camera.rotation = Vector3.ZERO
	for enemy in app.combat.enemies:
		enemy.set_physics_process(false)
		enemy.position = Vector3(130,.87,100)
	check(is_instance_valid(app.combat_audio) and not app.combat_audio.cue_map.is_empty(), "actual main audio profile configured")
	check(app.combat.weapons[&"pistol"].damage == 20.0 and app.combat.weapons[&"shotgun"].damage == 16.0 and app.combat.weapons[&"shotgun"].pellets == 7 and app.combat.weapons[&"melee"].damage == 30.0, "approved current damage definitions")
	app.combat.combat_event.connect(observe)
	wall = StaticBody3D.new()
	wall.name = "P11PhysicsHardWall"
	wall.collision_layer = 1
	wall.collision_mask = 0
	wall.set_meta("hit_material", &"hard")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20,20,.3)
	shape.shape = box
	wall.add_child(shape)
	app.world.add_child(wall)
	wall.position = Vector3(100,1,97)
	await physics_frame
	await physics_frame
	for weapon in [&"pistol", &"shotgun"]:
		app.player.camera.look_at(Vector3(100,1.5,97))
		accepted_shot(weapon,&"hard")
	var original_wall_id := wall.get_instance_id()
	check(results.size() >= 2 and results[0].contact_cue != results[1].contact_cue and trace[1].target_id == str(original_wall_id), "pistol and shotgun distinct cues on same actual hard wall")
	var by_kind := {}
	for enemy in app.combat.enemies:
		if not by_kind.has(enemy.definition.identifier): by_kind[enemy.definition.identifier] = enemy
	for kind in [&"unsealed", &"vessel"]:
		if not check(by_kind.has(kind), "actual main spawns " + String(kind)): continue
		var target: CharacterBody3D = by_kind[kind]
		target.position = Vector3(100,.87,100)
		front_pose(target)
		check(is_instance_valid(target.sprite) and not target.hurt_shapes.is_empty(), "actual installed sprite hurt geometry " + String(kind))
		await physics_frame
		await physics_frame
		var materials: Array[StringName] = [&"flesh"]
		if kind == &"vessel": materials.append(&"armor")
		for material in materials:
			for weapon in [&"pistol", &"shotgun", &"melee"]:
				front_pose(target)
				await physics_frame
				await physics_frame
				var point: Variant = find_point(target,material,weapon)
				if not check(point != null,"actual front " + String(kind)+" exposes "+String(material)): continue
				app.player.camera.look_at(point)
				accepted_shot(weapon,material,target)
		target.position = Vector3(130,.87,100)
		await physics_frame
	check(results.size() == 11, "all eleven wall/flesh/armor weapon contacts completed")
	for result in results:
		if result.weapon == &"shotgun" and result.enemy != "wall":
			check(result.pellets == 7 and result.damage == 112.0, "actual seven-pellet maximum damage " + String(result.enemy) + "/" + String(result.material))
	rejected_checks()
	var identities := {}
	for event in trace:
		if int(event.shot_id) <= 0: continue
		var identity := "%s:%s:%s" % [event.type,event.shot_id,event.target_id]
		check(not identities.has(identity), "unique authoritative event " + identity)
		identities[identity] = true
	var file := FileAccess.open(OUT,FileAccess.WRITE)
	if check(file != null,"open unique p11 verification report"):
		file.store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"fixture":"actual scenes/main.tscn and installed resources; isolated physics wall in same actual world; actual authored front sprite hurt geometry","scope":"Programmatic routing/contact/damage/light ownership only; no human listening or sound quality assessment.","contacts":results,"event_trace":trace,"empty_feedback_expected":true},"  ")+"\n")
		file.close()
	var code := 0 if failures.is_empty() else 1
	print("P11_ACTUAL_CONTACTS_%s: %d checks; %d actual accepted physics contacts; trace %s" % ["OK" if code == 0 else "FAILED",checks,results.size(),OUT])
	app.combat_audio.stop_all()
	if is_instance_valid(app.menu_music):
		app.menu_music.stop()
		app.menu_music.stream = null
	# Match main shutdown: allow the mix thread to retire stopped Ogg playbacks.
	await create_timer(.25,true).timeout
	app.free()
	load("res://scripts/sprite_hurt_geometry.gd").frame_cache.clear()
	load("res://scripts/sprite_hurt_geometry.gd").image_cache.clear()
	await process_frame
	await process_frame
	quit(code)
