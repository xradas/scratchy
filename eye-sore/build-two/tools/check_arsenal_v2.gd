extends SceneTree
## Actual Combat acceptance and physics contacts, with release-safe failures.
var combat: Node3D
var world: Node3D
var player: CharacterBody3D
var camera: Camera3D
var events: Array[Dictionary] = []
var checks: int = 0

func _initialize() -> void: call_deferred("run")

func check(condition: bool, message: String) -> bool:
	if not condition:
		push_error("ARSENAL_V2_FAILED: " + message)
		quit(1)
		return false
	checks += 1
	return true

func count(kind: StringName, target: String = "") -> int:
	var total := 0
	for event in events:
		if event.type == kind and (target == "" or String(event.target_id) == target): total += 1
	return total

func ready_weapon(id: StringName) -> void:
	combat.currentweapon = id; combat.cooldown = 0.0; combat.weapon_phase = &"idle"

func enemy_at(point: Vector3, hp: float = 1000.0, kind: StringName = &"unsealed") -> CharacterBody3D:
	var enemy: CharacterBody3D = combat.spawn_enemy(kind, point)
	enemy.set_physics_process(false); enemy.health = hp
	return enemy

func fixture() -> void:
	world = Node3D.new(); root.add_child(world)
	var spawns := Node3D.new(); spawns.name = "EnemySpawns"; world.add_child(spawns)
	player = CharacterBody3D.new(); player.collision_layer = 2; player.collision_mask = 3; world.add_child(player)
	player.position = Vector3(0, .87, 0)
	var capsule := CapsuleShape3D.new(); capsule.height = 1.7; capsule.radius = .3
	var shape := CollisionShape3D.new(); shape.shape = capsule; player.add_child(shape)
	camera = Camera3D.new(); camera.name = "Camera3D"; camera.position.y = .4; player.add_child(camera)
	combat = load("res://scripts/combat.gd").new(); world.add_child(combat)
	combat.setup(world, player); combat.set_physics_process(false)
	combat.combat_event.connect(func(event: Dictionary): events.append(event.duplicate()))

func ordnance() -> Node3D:
	for child in combat.get_children():
		if child.get_script() == preload("res://scripts/player_ordnance.gd") and not child.resolved:
			child.set_physics_process(false)
			return child
	return null

func step_projectile(projectile: Node3D, fps: int, limit: int = 600) -> bool:
	for step in limit:
		if not is_instance_valid(projectile): return true
		projectile._physics_process(1.0 / fps)
		if projectile.resolved: return true
		await physics_frame
	return false

func barrier(point: Vector3, size: Vector3, moving: bool = false) -> StaticBody3D:
	var body: StaticBody3D = AnimatableBody3D.new() if moving else StaticBody3D.new()
	body.collision_layer = 1; body.set_meta("hit_material", &"hard"); world.add_child(body); body.position = point
	var shape := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = size; shape.shape = box; body.add_child(shape)
	return body

func run() -> void:
	fixture()
	if not check(combat.has_weapon(&"pistol") and combat.has_weapon(&"shotgun") and combat.has_weapon(&"melee"), "legacy three initially owned"): return
	for id in [&"twin_shotgun", &"rivet_cannon", &"siege_launcher"]:
		if not check(not combat.has_weapon(id) and not combat.select_weapon(id), "unowned selection rejected: " + String(id)): return
		ready_weapon(id)
		if not check(not combat.try_fire() and count(&"shot") == 0, "unowned forced selection cannot fire"): return
	if not check(not combat.grant_weapon(&"invalid", 3) and not combat.grant_weapon(&"rivet_cannon", -1) and not combat.add_ammo(&"bogus", 1), "invalid pickup APIs rejected"): return
	if not check(combat.grant_weapon(&"twin_shotgun") and combat.grant_weapon(&"rivet_cannon", 20) and combat.grant_weapon(&"siege_launcher", 20), "grant APIs equip inventory"): return
	if not check(combat.add_ammo(&"shells", 8) and combat.add_ammo(&"pistol", 2) and combat.add_ammo(&"rivets", 3) and combat.add_ammo(&"rockets", 2), "all four ammo families"): return
	var hud: Dictionary = combat.get_hud_state()
	if not check(hud.ammo_rivets == 23 and hud.ammo_rockets == 22 and hud.owned_weapons.size() == 6, "HUD complete owned inventory"): return
	# Accepted shot cadence remains tied to seconds at each supported physics rate.
	for fps in [30, 60, 120]:
		for id in [&"twin_shotgun", &"rivet_cannon"]:
			ready_weapon(id); combat.ammo_shotgun = 100; combat.ammo_rivets = 100; events.clear()
			if not check(combat.try_fire(), "cadence initial acceptance"): return
			var seconds: float = combat.weapons[id].cooldown_seconds
			var elapsed := 0.0
			var accepted := false
			for tick in range(int(ceil(seconds * fps)) + 2):
				combat._physics_process(1.0 / fps); elapsed += 1.0 / fps
				accepted = combat.try_fire()
				if accepted: break
			if not check(accepted and elapsed + .00001 >= seconds and elapsed <= seconds + 1.0 / fps + .00001 and count(&"shot") == 2, "accepted " + String(id) + " cadence at " + str(fps)): return
	combat.ammo_rivets = 23
	var target := enemy_at(Vector3(0, 1.27, -2))
	await physics_frame; await physics_frame
	ready_weapon(&"twin_shotgun"); combat.ammo_shotgun = 1; events.clear()
	if not check(not combat.try_fire() and combat.ammo_shotgun == 1 and count(&"empty") == 1, "twin requires both shells before acceptance"): return
	combat.ammo_shotgun = 4; var view_before := camera.global_transform; events.clear()
	if not check(combat.try_fire() and combat.ammo_shotgun == 2 and target.health == 712.0, "actual sixteen pellet twin volley deals 288 and costs two shells"): return
	if not check(count(&"shot") == 1 and count(&"impact", target.target_id) == 1 and count(&"enemy_hurt", target.target_id) == 1, "one twin acceptance and aggregate contact"): return
	if not check(not combat.try_fire() and combat.ammo_shotgun == 2 and combat.recoil_remaining == 11.0 and camera.global_transform == view_before, "cooldown rejects without ammo; recoil preserves camera aim"): return
	if not check(combat.weapon_lighting.active_shot_id == combat.shot_counter and combat.weapon_lighting.flash.visible, "new weapon accepted event owns surface flash"): return
	ready_weapon(&"rivet_cannon"); events.clear()
	if not check(combat.try_fire() and target.health == 676.0 and combat.ammo_rivets == 22 and count(&"impact") == 1, "actual centered rivet hit and separate ammo"): return
	# A physical thin wall must intercept both centered shots and an entire twin volley.
	var wall := barrier(Vector3(0, 1.27, -1), Vector3(6, 4, .04))
	await physics_frame; await physics_frame
	for id in [&"twin_shotgun", &"rivet_cannon"]:
		ready_weapon(id); combat.ammo_shotgun = 8; events.clear(); var before: float = target.health
		if not check(combat.try_fire() and target.health == before and count(&"impact") == 1, "wall blocks actual " + String(id)): return
		if not check(events[1].material == &"hard", "wall impact retains hard metadata"): return
	wall.queue_free(); target.queue_free(); combat.enemies.erase(target)
	await physics_frame; await physics_frame
	# At 30/60/120 Hz the same very thin wall intercepts swept rockets and blocks splash.
	for fps in [30, 60, 120]:
		var blocked := enemy_at(Vector3(0, 1.27, -3))
		wall = barrier(Vector3(0, 1.27, -2), Vector3(8, 5, .015), true)
		await physics_frame; await physics_frame
		ready_weapon(&"siege_launcher"); events.clear(); var hp: float = combat.health
		if not check(combat.try_fire(), "siege accepted at " + str(fps)): return
		var projectile := ordnance()
		if not check(is_instance_valid(projectile) and projectile.shot_id == combat.shot_counter, "accepted shot owns one projectile"): return
		if not check(await step_projectile(projectile, fps), "swept rocket hits thin moving door at " + str(fps)): return
		if not check(count(&"ordnance_explosion") == 1 and count(&"impact") == 1 and blocked.health == 1000.0, "one wall explosion; splash cannot cross closed door at " + str(fps)): return
		if not check(hp - combat.health <= 60.0 and count(&"player_hurt") <= 1, "self blast bounded and once"): return
		wall.position.x = 10
		await physics_frame; await physics_frame
		ready_weapon(&"siege_launcher"); events.clear(); combat.health = 100; combat.armor = 50
		var bystander := enemy_at(Vector3(1.3, 1.27, -3))
		await physics_frame; await physics_frame
		if not check(combat.try_fire() and await step_projectile(ordnance(), fps), "opening moved door permits direct rocket"): return
		if not check(is_equal_approx(blocked.health, 790.0) and bystander.health < 1000.0, "direct 120 plus contact blast 90; nearby splash falls off at " + str(fps)): return
		if not check(count(&"impact", blocked.target_id) == 1 and count(&"enemy_hurt", blocked.target_id) == 1 and count(&"ordnance_explosion") == 1, "direct and radial share one target resolution"): return
		for event in events:
			if event.type in [&"impact", &"enemy_hurt", &"ordnance_explosion"]:
				if not check(event.shot_id == combat.shot_counter, "impact retains accepted launch shot id"): return
		wall.queue_free(); blocked.queue_free(); bystander.queue_free(); combat.enemies.clear()
		await physics_frame; await physics_frame
	# A query-only anatomical triangle leaves a deliberate gap through the movement
	# capsule. Heavy hits must use query geometry and its armor metadata.
	var armored := enemy_at(Vector3(0, 1.27, -3), 1000, &"vessel")
	var hardware := StaticBody3D.new(); hardware.collision_layer = 4; hardware.collision_mask = 0
	hardware.set_meta("combat_target", armored); hardware.set_meta("hit_material", &"armor")
	armored.add_child(hardware); hardware.position.x = .65
	var hardware_shape := CollisionShape3D.new(); hardware_shape.name = "HitSurface"
	var triangle := ConcavePolygonShape3D.new(); triangle.backface_collision = true
	triangle.set_faces(PackedVector3Array([Vector3(-.25, -.35, 0), Vector3(.25, -.35, 0), Vector3(.25, .35, 0), Vector3(-.25, -.35, 0), Vector3(.25, .35, 0), Vector3(-.25, .35, 0)]))
	hardware_shape.shape = triangle; hardware.add_child(hardware_shape); armored.hurt_shapes.append(hardware)
	await physics_frame; await physics_frame
	ready_weapon(&"rivet_cannon"); events.clear()
	if not check(combat.try_fire() and armored.health == 1000.0 and count(&"impact") == 0, "centered rivet respects anatomical gap through movement capsule"): return
	ready_weapon(&"siege_launcher"); events.clear()
	if not check(combat.try_fire() and await step_projectile(ordnance(), 60) and armored.health == 1000.0 and count(&"impact") == 0, "swept siege respects anatomical gap and owner capsule"): return
	camera.look_at(hardware.global_position)
	ready_weapon(&"rivet_cannon"); events.clear()
	if not check(combat.try_fire() and armored.health == 964.0 and count(&"impact", armored.target_id) == 1, "rivet contacts actual anatomical hardware"): return
	for event in events:
		if event.type == &"impact":
			if not check(event.material == &"armor", "rivet preserves armor query material"): return
	ready_weapon(&"siege_launcher"); events.clear()
	if not check(combat.try_fire() and await step_projectile(ordnance(), 120) and armored.health == 754.0, "swept siege hits anatomical triangles once"): return
	for event in events:
		if event.type == &"impact" and event.target_id == armored.target_id:
			if not check(event.material == &"armor", "siege preserves armor query material"): return
	armored.queue_free(); combat.enemies.clear(); camera.rotation = Vector3.ZERO
	await physics_frame; await physics_frame
	# Corpse triangles remain hittable, then breakup removes finite query geometry.
	var corpse := enemy_at(Vector3(0, .87, -3), 20)
	await physics_frame; await physics_frame
	ready_weapon(&"pistol"); camera.look_at(corpse.global_position)
	if not check(combat.try_fire() and corpse.dead and not corpse.gibbed, "pistol leaves finite corpse"): return
	await physics_frame; await physics_frame
	camera.look_at(corpse.get_node("Visual").global_position)
	ready_weapon(&"twin_shotgun"); combat.ammo_shotgun = 8; events.clear(); var kills: int = combat.kills
	if not check(combat.try_fire() and corpse.gibbed and count(&"corpse_gib") == 1 and combat.kills == kills, "heavy gun resolves corpse geometry without another kill"): return
	await physics_frame; await physics_frame
	ready_weapon(&"twin_shotgun"); events.clear()
	if not check(combat.try_fire() and count(&"corpse_gib") == 0 and count(&"impact") == 0, "broken corpse has no repeated impact or breakup"): return
	corpse.queue_free(); combat.enemies.clear(); camera.rotation = Vector3.ZERO
	await physics_frame; await physics_frame
	# Misses retain exactly one launch and one lifetime/range airburst, never tunneling.
	ready_weapon(&"siege_launcher"); events.clear(); combat.health = 100; combat.armor = 50
	if not check(combat.try_fire(), "miss accepts launch"): return
	var missed := ordnance()
	if not check(await step_projectile(missed, 30), "miss ends at range or lifetime"): return
	if not check(count(&"shot") == 1 and count(&"ordnance_explosion") == 1 and count(&"impact") == 0, "miss airburst retains sole shot ownership"): return
	# Pause freezes both timeline and live projectile, including direct method calls.
	ready_weapon(&"siege_launcher"); events.clear()
	if not check(combat.try_fire(), "launch before pause"): return
	var paused_projectile := ordnance(); var pos: Vector3 = paused_projectile.global_position
	var ammo: int = combat.ammo_rockets; var cooldown: float = combat.cooldown
	paused = true
	paused_projectile._physics_process(.5); combat._physics_process(.5)
	await create_timer(.08, true).timeout
	if not check(paused_projectile.global_position == pos and combat.cooldown == cooldown and not combat.try_fire() and combat.ammo_rockets == ammo, "pause freezes projectile and shot acceptance"): return
	paused = false
	paused_projectile._physics_process(.01)
	if not check(paused_projectile.global_position != pos, "resume moves existing shot"): return
	combat.reset(); combat.set_physics_process(false)
	if not check(paused_projectile.resolved and count(&"ordnance_explosion") == 0, "reset cancels live ordnance without late explosion"): return
	if not check(combat.ammo_rivets == 0 and combat.ammo_rockets == 0 and combat.get_hud_state().owned_weapons.size() == 3 and not combat.has_weapon(&"twin_shotgun"), "ordinary reset clears new weapons and ammo"): return
	print("ARSENAL_V2_OK: %d release-safe checks; actual twin/rivet shots, owned inventory, ammo, recoil/flash, swept siege 30/60/120 Hz, moved-door splash occlusion, direct+radial dedup, finite corpses, miss lifetime, pause and reset" % checks)
	world.free(); quit(0)
