extends SceneTree
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	if not value: failures.append(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world: Node3D = load("res://scenes/campaign/pale_ward_01.tscn").instantiate()
	root.add_child(world)
	var player: CharacterBody3D = world.get_node("Player")
	player.set_physics_process(false)
	var combat: Node3D = load("res://scripts/combat.gd").new()
	world.add_child(combat)
	combat.setup(world, player)
	combat.set_physics_process(false)
	world.setup(combat, player)
	world.set_physics_process(false)
	for enemy in combat.enemies: enemy.set_physics_process(false)
	var shotgun_carrier: CharacterBody3D
	var pistol_carrier: CharacterBody3D
	for enemy in combat.enemies:
		if enemy.target_id == "pale_ward_01.triage.enemy.5": shotgun_carrier = enemy
		if enemy.target_id == "pale_ward_01.triage.enemy.2": pistol_carrier = enemy
	check(is_instance_valid(shotgun_carrier), "early shotgun carrier missing")
	check(is_instance_valid(pistol_carrier), "pistol carrier missing")
	var pending_drop_state: Dictionary = {}
	if shotgun_carrier != null:
		check(shotgun_carrier.definition.identifier == &"infected_security_shotgun", "early shotgun guard is not its own troop type")
		check(shotgun_carrier.carried_weapon == &"shotgun", "early carrier not firing shotgun")
		shotgun_carrier.apply_damage(999.0, 1, &"pistol", shotgun_carrier.global_position)
		check(shotgun_carrier.dead and is_instance_valid(shotgun_carrier.weapon_drop), "shotgun drop not persistent on death")
		pending_drop_state = world.capture_checkpoint_state()
		if is_instance_valid(shotgun_carrier.weapon_drop):
			check(shotgun_carrier.weapon_drop.get_meta("weapon_drop") == &"shotgun", "shotgun visual pickup identity")
			check(shotgun_carrier.weapon_drop.try_collect(), "first shotgun pickup rejected")
			check(combat.has_weapon(&"shotgun") and combat.ammo_shotgun > 0, "shotgun not granted with finite shells")
			check(shotgun_carrier.drop_collected, "drop ownership not recorded")
	if pistol_carrier != null:
		check(pistol_carrier.carried_weapon == &"pistol", "ordinary guard not firing pistol")
		var before: int = combat.ammo_pistol
		pistol_carrier.apply_damage(999.0, 2, &"pistol", pistol_carrier.global_position)
		if is_instance_valid(pistol_carrier.weapon_drop):
			pistol_carrier.weapon_drop.try_collect()
			check(combat.ammo_pistol >= before and combat.ammo_pistol <= before + 9, "pistol reward not finite")
		else: check(false, "pistol drop missing")
	combat.reset()
	world.reset()
	check(not combat.has_weapon(&"shotgun"), "retry retained enemy weapon")
	for enemy in combat.enemies:
		if enemy.target_id == "pale_ward_01.triage.enemy.5":
			check(not enemy.dead and not is_instance_valid(enemy.weapon_drop), "retry retained dead actor drop")
	if not pending_drop_state.is_empty():
		check(world.restore_checkpoint_state(pending_drop_state), "checkpoint could not restore an uncollected drop")
		for enemy in combat.enemies:
			if enemy.target_id == "pale_ward_01.triage.enemy.5":
				check(enemy.dead and is_instance_valid(enemy.weapon_drop), "checkpoint lost persistent shotgun drop")
				if is_instance_valid(enemy.weapon_drop):
					check(enemy.weapon_drop.try_collect(), "restored shotgun drop not collectible")
					var collected_state: Dictionary = world.capture_checkpoint_state()
					combat.reset();world.reset()
					check(world.restore_checkpoint_state(collected_state), "checkpoint could not restore collected drop")
					for restored in combat.enemies:
						if restored.target_id == "pale_ward_01.triage.enemy.5":
							check(restored.drop_collected and not is_instance_valid(restored.weapon_drop), "checkpoint duplicated collected shotgun")
				break
	world.queue_free()
	await process_frame
	for case in [
		{"level":"pale_ward_02","target":"pale_ward_02.isolation_a.enemy.2","weapon":&"shotgun","ammo":3,"barrels":1},
		{"level":"pale_ward_03","target":"pale_ward_03.crossfire.enemy.0","weapon":&"shotgun","ammo":3,"barrels":1},
		{"level":"pale_ward_01","target":"pale_ward_01.generator.enemy.0","weapon":&"twin_shotgun","ammo":4,"barrels":2},
		{"level":"pale_ward_02","target":"pale_ward_02.culture_access.enemy.2","weapon":&"rivet_cannon","ammo":12,"barrels":1},
		{"level":"pale_ward_03","target":"pale_ward_03.upper_gallery.enemy.0","weapon":&"siege_launcher","ammo":2,"barrels":1},
	]:
		var stage: Node3D = load("res://scenes/campaign/%s.tscn" % case.level).instantiate()
		root.add_child(stage)
		var actor: CharacterBody3D = stage.get_node("Player")
		actor.set_physics_process(false)
		var fight: Node3D = load("res://scripts/combat.gd").new()
		stage.add_child(fight)
		fight.setup(stage, actor)
		fight.set_physics_process(false)
		stage.setup(fight, actor)
		stage.set_physics_process(false)
		for enemy in fight.enemies: enemy.set_physics_process(false)
		var carrier: CharacterBody3D
		for enemy in fight.enemies:
			if enemy.target_id == case.target: carrier = enemy; break
		check(is_instance_valid(carrier), "%s carrier missing" % case.weapon)
		if carrier != null:
			if case.weapon == &"shotgun":
				check(carrier.definition.identifier == &"infected_security_shotgun", "%s shotgun troop kind missing" % case.level)
			check(carrier.carried_weapon == case.weapon, "%s carrier uses wrong gun" % case.weapon)
			check(is_instance_valid(carrier.carried_visual) and carrier.carried_visual.visible, "%s carried gun invisible" % case.weapon)
			var barrels := 0
			if is_instance_valid(carrier.carried_visual):
				for child in carrier.carried_visual.get_children():
					if String(child.name).begins_with("Barrel_"): barrels += 1
			check(barrels == case.barrels, "%s carried silhouette wrong" % case.weapon)
			var ammo_key: StringName = fight.weapons[case.weapon].ammo_key
			var amount_before: int = fight.ammo_amount(ammo_key)
			carrier.apply_damage(999.0, 100, &"pistol", carrier.global_position)
			check(carrier.dead and is_instance_valid(carrier.weapon_drop), "%s drop missing" % case.weapon)
			check(not carrier.carried_visual.visible, "%s corpse still holds gun" % case.weapon)
			if is_instance_valid(carrier.weapon_drop):
				check(carrier.weapon_drop.ammo == case.ammo, "%s drop amount wrong" % case.weapon)
				check(carrier.weapon_drop.try_collect(), "%s drop not collectible" % case.weapon)
				check(fight.has_weapon(case.weapon), "%s ownership not granted" % case.weapon)
				check(fight.ammo_amount(ammo_key) > amount_before and fight.ammo_amount(ammo_key) <= amount_before + case.ammo, "%s ammo not finite" % case.weapon)
			if case.weapon == &"siege_launcher":
				var rocket: Node3D = load("res://scripts/enemy_siege_rocket.gd").new()
				fight.add_child(rocket)
				rocket.global_position = actor.global_position + Vector3(0, 0, 2)
				rocket.setup(fight, carrier, Vector3(0, 0, -11))
				var before_total: float = fight.health + fight.armor
				rocket.explode(actor.global_position, actor)
				check(rocket.resolved and absf(before_total - fight.health - fight.armor - 24.0) < 0.01, "enemy rocket direct damage not bounded")
		stage.queue_free()
		await process_frame
	for failure in failures: printerr(failure)
	print("ENEMY_WEAPON_DROPS passed=", failures.is_empty(), " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
