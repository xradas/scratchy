extends SceneTree

var checks: int = 0

func _initialize() -> void:
	call_deferred("run_check")

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error("WEAPON_LIGHTING_CHECK_FAILED: " + message)
		quit(1)
		assert(condition, message)
	checks += 1

func ready_to_fire(combat: Node3D, weapon: StringName) -> void:
	combat.currentweapon = weapon
	combat.weapon_phase = &"idle"
	combat.cooldown = 0.0

func run_check() -> void:
	var world := Node3D.new()
	root.add_child(world)
	# An empty authored spawn collection keeps this contract fixture deterministic.
	var spawns := Node3D.new()
	spawns.name = "EnemySpawns"
	world.add_child(spawns)
	var player := CharacterBody3D.new()
	world.add_child(player)
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	player.add_child(camera)
	camera.position = Vector3(1.0, 1.5, 2.0)
	camera.rotation.y = 0.7
	var combat: Node3D = load("res://scripts/combat.gd").new()
	world.add_child(combat)
	combat.setup(world, player)
	combat.set_physics_process(false)
	var lighting: Node3D = combat.weapon_lighting
	check(is_instance_valid(lighting) and lighting.get_parent() == combat and lighting.name == "WeaponLighting" and lighting.combat == combat, "Combat owns configured weapon lighting")
	var owned_lights: int = 0
	for child in combat.get_children():
		if child.get_script() == preload("res://scripts/weapon_lighting.gd"):
			owned_lights += 1
	check(owned_lights == 1, "one owned weapon lighting node")
	# Calling setup again must retain the same light and a single signal binding.
	var light_id: int = lighting.flash.get_instance_id()
	lighting.setup(combat)
	check(lighting.flash.get_instance_id() == light_id and lighting.get_child_count() == 1, "one reusable light")
	check(not lighting.flash.visible and lighting.remaining == 0.0, "initially dark")
	await physics_frame
	ready_to_fire(combat, &"pistol")
	check(combat.try_fire(), "actual combat accepts pistol")
	check(lighting.flash.visible and lighting.active_shot_id == combat.shot_counter, "accepted shot immediately lights surfaces")
	check(is_equal_approx(lighting.remaining, 0.055) and lighting.flash.omni_range == 5.0 and lighting.flash.light_energy == 2.5, "pistol profile")
	check(lighting.flash.global_position.is_equal_approx(camera.global_position - camera.global_basis.z * 0.4), "camera forward placement")
	check(not lighting.flash.shadow_enabled, "flash has no shadow cost")
	check(lighting.flash.light_color == Color(1.0, 0.88, 0.72), "warm neutral flash")
	lighting._process(0.02)
	var before: float = lighting.remaining
	check(not combat.try_fire() and lighting.remaining == before, "cooldown rejection does not refresh light")
	ready_to_fire(combat, &"shotgun")
	check(combat.try_fire(), "actual combat accepts shotgun")
	check(lighting.flash.get_instance_id() == light_id and lighting.get_child_count() == 1, "repeated accepted shots reuse light")
	check(is_equal_approx(lighting.remaining, 0.08) and lighting.flash.omni_range == 7.0 and lighting.flash.light_energy == 4.0, "shotgun refreshes profile")
	lighting.reset()
	ready_to_fire(combat, &"pistol")
	combat.ammo_pistol = 0
	check(not combat.try_fire() and not lighting.flash.visible and lighting.remaining == 0.0, "empty fire emits no light")
	ready_to_fire(combat, &"melee")
	check(combat.try_fire() and not lighting.flash.visible and lighting.remaining == 0.0, "accepted melee emits no light")
	ready_to_fire(combat, &"pistol")
	combat.ammo_pistol = 2
	check(combat.try_fire(), "pistol accepts before pause")
	before = lighting.remaining
	paused = true
	await create_timer(0.12, true).timeout
	check(lighting.remaining == before and lighting.flash.visible, "tree pause freezes countdown beyond flash duration")
	paused = false
	await create_timer(0.12, true).timeout
	check(lighting.remaining == 0.0 and not lighting.flash.visible, "resume expires flash")
	ready_to_fire(combat, &"shotgun")
	check(combat.try_fire(), "shotgun accepts before world reset")
	combat.reset()
	check(not lighting.flash.visible and lighting.remaining == 0.0 and lighting.active_shot_id == 0, "authoritative world reset clears active shot ownership")
	check(combat.try_fire() and lighting.flash.visible, "reset preserves event binding for next encounter")
	lighting.reset()
	check(not lighting.flash.visible and lighting.flash.light_energy == 0.0 and lighting.active_shot_id == 0, "public reset clears flash")
	world.free()
	check(not is_instance_valid(lighting), "world cleanup frees owned lighting")
	print("WEAPON_LIGHTING_CHECK_OK: %d checks; real accepted Combat shots, pistol/shotgun profiles, reusable surface light, cooldown/empty/melee exclusion, camera placement, pause/resume, world/public reset" % checks)
	quit()
