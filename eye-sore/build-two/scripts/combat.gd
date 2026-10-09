extends Node3D
signal combat_event(event: Dictionary)
signal player_died

var health: float = 100.0
var armor: float = 50.0
var ammo_pistol: int = 36
var ammo_shotgun: int = 12
var currentweapon: StringName = &"pistol"
var weapon_phase: StringName = &"idle"
var phase_time: float = 0.0
var phase_duration: float = 0.0
var cooldown: float = 0.0
var shot_counter: int = 0
var empty_cooldown: float = 0.0
var kills: int = 0
var total_enemies: int = 0
var dead: bool = false
var world: Node3D
var player: CharacterBody3D
var camera: Camera3D
var enemies: Array[CharacterBody3D] = []
var weapons: Dictionary = {}
var weapon_visuals: Dictionary = {}
var recoil_remaining: float = 0.0
const SWITCH_TIME: float = 0.22

func setup(room: Node3D, actor: CharacterBody3D) -> void:
	world = room
	player = actor
	camera = player.get_node("Camera3D")
	for id in [&"pistol", &"shotgun", &"melee"]:
		weapons[id] = load("res://resources/weapons/%s.tres" % id)
	reset()

func reset() -> void:
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.collision_layer = 0; enemy.collision_mask = 0
			enemy.set_physics_process(false); enemy.queue_free()
	enemies.clear()
	for projectile in get_children():
		if projectile.has_method("is_combat_projectile"):
			projectile.resolved = true; projectile.set_physics_process(false); projectile.queue_free()
	health = 100.0; armor = 50.0; ammo_pistol = 36; ammo_shotgun = 12
	currentweapon = &"pistol"; weapon_phase = &"idle"; phase_time = 0.0
	cooldown = 0.0; empty_cooldown = 0.0; shot_counter = 0; kills = 0; dead = false
	recoil_remaining = 0.0
	if not is_instance_valid(world) or not is_instance_valid(player): return
	spawn_enemy(&"unsealed", Vector3(0, 0.87, 10))
	spawn_enemy(&"vessel", Vector3(2.0, 0.87, 2.5))
	total_enemies = enemies.size()
	emit_event({"type": &"encounter_started", "total_enemies": total_enemies})

func spawn_enemy(kind: StringName, position_value: Vector3) -> CharacterBody3D:
	var enemy: CharacterBody3D = preload("res://scenes/combat_enemy.tscn").instantiate()
	enemy.position = position_value
	world.add_child(enemy)
	enemy.setup(self, player, load("res://resources/enemies/%s.tres" % kind), "enemy_%s_%d" % [kind, enemies.size()])
	enemies.append(enemy)
	return enemy

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player): return
	cooldown = maxf(0.0, cooldown - delta)
	empty_cooldown = maxf(0.0, empty_cooldown - delta)
	# Recoil is a view-weapon offset only. Firing never moves the aiming camera.
	recoil_remaining = move_toward(recoil_remaining, 0.0, delta * 40.0)
	if weapon_phase != &"idle":
		phase_time += delta
		if phase_time >= phase_duration:
			if weapon_phase == &"fire":
				weapon_phase = &"recover"; phase_time = 0.0
				phase_duration = maxf(0.01, weapons[currentweapon].cooldown_seconds - weapons[currentweapon].fire_seconds)
			else: weapon_phase = &"idle"; phase_time = 0.0
	if dead or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return
	if Input.is_physical_key_pressed(KEY_1): select_weapon(&"pistol")
	elif Input.is_physical_key_pressed(KEY_2): select_weapon(&"shotgun")
	elif Input.is_physical_key_pressed(KEY_3): select_weapon(&"melee")
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): try_fire()

func select_weapon(id: StringName) -> bool:
	if dead or not weapons.has(id) or id == currentweapon or cooldown > 0.0: return false
	currentweapon = id; weapon_phase = &"switch"; phase_time = 0.0; phase_duration = SWITCH_TIME; cooldown = SWITCH_TIME
	emit_event({"type": &"weapon_switch", "weapon_id": id})
	return true

func try_fire() -> bool:
	if dead or cooldown > 0.0 or weapon_phase == &"switch" or not is_instance_valid(camera): return false
	var definition: WeaponDefinition = weapons[currentweapon]
	if definition.ammo_key != &"" and int(get(String(definition.ammo_key))) <= 0:
		if empty_cooldown <= 0.0:
			emit_event({"type": &"empty", "weapon_id": currentweapon})
			empty_cooldown = 0.35
		return false
	if definition.ammo_key != &"": set(String(definition.ammo_key), int(get(String(definition.ammo_key))) - 1)
	shot_counter += 1
	weapon_phase = &"fire"; phase_time = 0.0; phase_duration = definition.fire_seconds; cooldown = definition.cooldown_seconds
	var origin := camera.global_position
	var forward := -camera.global_basis.z
	var seed_value := shot_counter * 7919 + 472
	# The single accepted event owns ammo, timeline, recoil, ray damage and downstream sound/graphics.
	emit_event({"type": &"shot", "weapon_id": currentweapon, "shot_id": shot_counter, "position": origin, "direction": forward, "seed": seed_value, "pellets": definition.pellets, "physics_tick": Engine.get_physics_frames(), "time_seconds": float(Engine.get_physics_frames()) / Engine.physics_ticks_per_second})
	resolve_shot(definition, origin, forward, seed_value, shot_counter)
	recoil_remaining = 3.0 if currentweapon == &"pistol" else (7.0 if currentweapon == &"shotgun" else 2.0)
	return true

func resolve_shot(definition: WeaponDefinition, origin: Vector3, forward: Vector3, seed_value: int, shot_id: int) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = seed_value
	var pattern_rotation := rng.randf_range(-0.12, 0.12)
	var hits: Dictionary = {}
	var exclusions: Array = [player.get_rid()]
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.hurt_shapes.is_empty(): exclusions.append(enemy.get_rid())
	for pellet in range(definition.pellets):
		# One exact-center pellet plus an even ring avoids random empty-center volleys.
		var yaw := 0.0
		var pitch := 0.0
		if pellet > 0:
			var angle := TAU * float(pellet - 1) / float(definition.pellets - 1) + pattern_rotation
			yaw = deg_to_rad(cos(angle) * definition.spread_degrees)
			pitch = deg_to_rad(sin(angle) * definition.vertical_spread_degrees)
		var direction := forward.rotated(Vector3.UP, yaw).rotated(camera.global_basis.x, pitch).normalized()
		var hit := ray(origin, origin + direction * definition.range_units, exclusions, true)
		if hit.is_empty(): continue
		var collider: Object = hit.collider
		var contact_material := material_for(collider)
		if collider.has_meta("combat_target"):
			collider = collider.get_meta("combat_target")
		var key := collider.get_instance_id()
		if not hits.has(key): hits[key] = {"collider": collider, "position": hit.position, "damage": 0.0, "pellets": 0, "materials": {}}
		hits[key].damage += definition.damage; hits[key].pellets += 1
		hits[key].materials[contact_material] = hits[key].materials.get(contact_material, 0) + 1
	for value in hits.values():
		var collider: Object = value.collider
		var target_id: String = collider.target_id if collider.has_method("apply_damage") else str(collider.get_instance_id())
		var material := material_for(collider)
		var most_contacts := 0
		for struck_material in value.materials:
			if value.materials[struck_material] > most_contacts:
				material = struck_material
				most_contacts = value.materials[struck_material]
		emit_event({"type": &"impact", "weapon_id": definition.identifier, "shot_id": shot_id, "target_id": target_id, "material": material, "position": value.position, "pellets": value.pellets})
		if collider.has_method("apply_damage"):
			collider.apply_damage(value.damage, shot_id, definition.identifier, value.position, material)

func ray(from: Vector3, to: Vector3, exclude: Array = [], anatomical_hits: bool = false) -> Dictionary:
	var typed_exclude: Array[RID] = []
	typed_exclude.assign(exclude)
	var query := PhysicsRayQueryParameters3D.create(from, to, 7 if anatomical_hits else 3, typed_exclude)
	return get_world_3d().direct_space_state.intersect_ray(query)

func material_for(collider: Object) -> StringName:
	if collider.has_method("apply_damage"): return collider.definition.hit_material
	if collider.has_meta("hit_material"): return StringName(collider.get_meta("hit_material"))
	# Explicit hard-surface fallback, never infer enemy flesh from a node's visual name.
	return &"hard"

func receive_player_damage(amount: float, source_id: String, position_value: Vector3) -> void:
	if dead or amount <= 0.0: return
	var absorbed := minf(armor, amount * 0.6); armor -= absorbed; health = maxf(0.0, health - (amount - absorbed))
	emit_event({"type": &"player_hurt", "target_id": "player", "source_id": source_id, "position": position_value, "damage": amount})
	if health <= 0.0:
		dead = true; emit_event({"type": &"player_death", "target_id": "player"}); player_died.emit()

func launch_projectile(enemy: CharacterBody3D, origin: Vector3, direction: Vector3) -> Node3D:
	var projectile: Node3D = preload("res://scenes/combat_projectile.tscn").instantiate()
	add_child(projectile); projectile.global_position = origin
	projectile.setup(self, enemy, direction * enemy.definition.projectile_speed, enemy.definition.damage)
	return projectile

func enemy_killed(enemy: CharacterBody3D) -> void:
	kills += 1
	if kills == total_enemies: emit_event({"type": &"encounter_complete"})

func emit_event(event: Dictionary) -> void:
	for key in ["weapon_id", "target_id", "material"]:
		if not event.has(key): event[key] = &""
	if not event.has("position"): event.position = global_position
	if not event.has("shot_id"): event.shot_id = 0
	combat_event.emit(event)

func configure_weapon_visuals(paths: Dictionary) -> void:
	weapon_visuals = paths

func get_hud_state() -> Dictionary:
	var visual_path: String = ""
	if weapon_visuals.has(currentweapon): visual_path = weapon_visuals[currentweapon].get(weapon_phase, "")
	return {"health": health, "armor": armor, "ammo_pistol": ammo_pistol, "ammo_shotgun": ammo_shotgun, "weapon_id": currentweapon, "weapon_phase": weapon_phase, "phase_progress": clampf(phase_time / maxf(phase_duration, 0.001), 0.0, 1.0), "kills": kills, "total_enemies": total_enemies, "dead": dead, "weapon_visual_path": visual_path}
