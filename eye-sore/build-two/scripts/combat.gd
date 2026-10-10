extends Node3D
signal combat_event(event: Dictionary)
signal player_died

var health: float = 100.0
var armor: float = 50.0
var ammo_pistol: int = 36
var ammo_shotgun: int = 12
var ammo_rivets: int = 0
var ammo_rockets: int = 0
var owned_weapons: Dictionary = {}
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
var gore: Node3D
var weapon_lighting: Node3D
const SWITCH_TIME: float = 0.22

func setup(room: Node3D, actor: CharacterBody3D) -> void:
	world = room
	player = actor
	camera = player.get_node("Camera3D")
	for id in [&"pistol", &"shotgun", &"melee", &"twin_shotgun", &"rivet_cannon", &"siege_launcher"]:
		weapons[id] = load("res://resources/weapons/%s.tres" % id)
	gore = preload("res://scripts/combat_gore.gd").new()
	gore.name = "Gore"
	add_child(gore)
	gore.setup(self, preload("res://resources/gore_profile.tres"))
	combat_event.connect(gore.handle_event)
	weapon_lighting = preload("res://scripts/weapon_lighting.gd").new()
	weapon_lighting.name = "WeaponLighting"
	add_child(weapon_lighting)
	weapon_lighting.setup(self)
	reset()

func reset() -> void:
	if is_instance_valid(weapon_lighting): weapon_lighting.reset()
	if is_instance_valid(gore): gore.reset()
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.collision_layer = 0; enemy.collision_mask = 0
			enemy.clear_corpse_surfaces()
			enemy.set_physics_process(false); enemy.queue_free()
	enemies.clear()
	for projectile in get_children():
		if projectile.has_method("is_combat_projectile"):
			projectile.resolved = true; projectile.set_physics_process(false); projectile.queue_free()
	health = 100.0; armor = 50.0; ammo_pistol = 36; ammo_shotgun = 12
	ammo_rivets = 0; ammo_rockets = 0
	owned_weapons = {&"pistol": true, &"shotgun": true, &"melee": true}
	currentweapon = &"pistol"; weapon_phase = &"idle"; phase_time = 0.0
	cooldown = 0.0; empty_cooldown = 0.0; shot_counter = 0; kills = 0; dead = false
	recoil_remaining = 0.0
	if not is_instance_valid(world) or not is_instance_valid(player): return
	var authored := world.get_node_or_null("EnemySpawns")
	if authored:
		for marker in authored.get_children():
			var enemy := spawn_enemy(StringName(marker.get_meta("kind", "unsealed")), marker.position)
			enemy.awake = false
	else:
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
	if not is_instance_valid(player) or get_tree().paused: return
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
	elif Input.is_physical_key_pressed(KEY_4): select_weapon(&"twin_shotgun")
	elif Input.is_physical_key_pressed(KEY_5): select_weapon(&"rivet_cannon")
	elif Input.is_physical_key_pressed(KEY_6): select_weapon(&"siege_launcher")
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): try_fire()

func select_weapon(id: StringName) -> bool:
	if get_tree().paused or dead or not has_weapon(id) or id == currentweapon or cooldown > 0.0: return false
	currentweapon = id; weapon_phase = &"switch"; phase_time = 0.0; phase_duration = SWITCH_TIME; cooldown = SWITCH_TIME
	emit_event({"type": &"weapon_switch", "weapon_id": id})
	return true

func try_fire() -> bool:
	if get_tree().paused or dead or not has_weapon(currentweapon) or cooldown > 0.0 or weapon_phase == &"switch" or not is_instance_valid(camera): return false
	var definition: WeaponDefinition = weapons[currentweapon]
	if definition.ammo_key != &"" and int(get(String(definition.ammo_key))) < definition.ammo_cost:
		if empty_cooldown <= 0.0:
			emit_event({"type": &"empty", "weapon_id": currentweapon})
			empty_cooldown = 0.35
		return false
	if definition.ammo_key != &"": set(String(definition.ammo_key), int(get(String(definition.ammo_key))) - definition.ammo_cost)
	shot_counter += 1
	weapon_phase = &"fire"; phase_time = 0.0; phase_duration = definition.fire_seconds; cooldown = definition.cooldown_seconds
	var origin := camera.global_position
	var forward := -camera.global_basis.z
	var seed_value := shot_counter * 7919 + 472
	# The single accepted event owns ammo, timeline, recoil, ray damage and downstream sound/graphics.
	emit_event({"type": &"shot", "weapon_id": currentweapon, "shot_id": shot_counter, "position": origin, "direction": forward, "seed": seed_value, "pellets": definition.pellets, "physics_tick": Engine.get_physics_frames(), "time_seconds": float(Engine.get_physics_frames()) / Engine.physics_ticks_per_second})
	if definition.fire_mode == "projectile":
		launch_player_ordnance(definition, origin, forward, shot_counter)
	else:
		resolve_shot(definition, origin, forward, seed_value, shot_counter)
	recoil_remaining = definition.recoil if definition.recoil >= 0.0 else (3.0 if currentweapon == &"pistol" else (7.0 if currentweapon == &"shotgun" else 2.0))
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
		if not hits.has(key): hits[key] = {"collider": collider, "position": hit.position, "damage": 0.0, "pellets": 0, "materials": {}, "corpse": collider.has_method("apply_corpse_damage") and collider.dead}
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
		if value.corpse:
			collider.apply_corpse_damage(value.damage, shot_id, definition.identifier, value.position, material)
		elif collider.has_method("apply_damage"):
			collider.apply_damage(value.damage, shot_id, definition.identifier, value.position, material)

func ray(from: Vector3, to: Vector3, exclude: Array = [], anatomical_hits: bool = false) -> Dictionary:
	var typed_exclude: Array[RID] = []
	typed_exclude.assign(exclude)
	var query := PhysicsRayQueryParameters3D.create(from, to, 15 if anatomical_hits else 3, typed_exclude)
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
	return {"health": health, "armor": armor, "ammo_pistol": ammo_pistol, "ammo_shotgun": ammo_shotgun, "ammo_rivets": ammo_rivets, "ammo_rockets": ammo_rockets, "owned_weapons": owned_weapons.keys(), "weapon_id": currentweapon, "weapon_phase": weapon_phase, "phase_progress": clampf(phase_time / maxf(phase_duration, 0.001), 0.0, 1.0), "kills": kills, "total_enemies": total_enemies, "dead": dead, "weapon_visual_path": visual_path}

func has_weapon(id: StringName) -> bool:
	return weapons.has(id) and owned_weapons.has(id)

func grant_weapon(id: StringName, ammo: int = 0) -> bool:
	if not weapons.has(id) or ammo < 0: return false
	owned_weapons[id] = true
	var definition: WeaponDefinition = weapons[id]
	if ammo > 0 and definition.ammo_key != &"": add_ammo(definition.ammo_key, ammo)
	emit_event({"type": &"weapon_granted", "weapon_id": id, "ammo": ammo})
	return true

func add_ammo(kind: StringName, amount: int) -> bool:
	if amount <= 0: return false
	var keys := {&"pistol": &"ammo_pistol", &"shells": &"ammo_shotgun", &"shotgun": &"ammo_shotgun", &"rivets": &"ammo_rivets", &"rockets": &"ammo_rockets"}
	var key: StringName = keys.get(kind, kind)
	if key not in [&"ammo_pistol", &"ammo_shotgun", &"ammo_rivets", &"ammo_rockets"]: return false
	set(String(key), int(get(String(key))) + amount)
	emit_event({"type": &"ammo_added", "ammo_kind": key, "amount": amount})
	return true

func anatomical_exclusions() -> Array[RID]:
	var exclusions: Array[RID] = [player.get_rid()]
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.hurt_shapes.is_empty(): exclusions.append(enemy.get_rid())
	return exclusions

func launch_player_ordnance(definition: WeaponDefinition, origin: Vector3, direction: Vector3, shot_id: int) -> Node3D:
	var projectile: Node3D = preload("res://scenes/player_ordnance.tscn").instantiate()
	add_child(projectile)
	projectile.global_position = origin
	projectile.setup(self, definition, direction, shot_id)
	return projectile

# Called only by the swept ordnance after it atomically marks itself resolved.
# Direct and splash are combined before applying damage: enemy shot dedup remains intact.
func resolve_ordnance_explosion(definition: WeaponDefinition, origin: Vector3, direct: Object, direct_material: StringName, shot_id: int) -> void:
	emit_event({"type": &"ordnance_explosion", "weapon_id": definition.identifier, "shot_id": shot_id, "position": origin, "radius": definition.blast_radius, "damage": definition.blast_damage})
	var hits: Dictionary = {}
	if is_instance_valid(direct):
		if direct.has_meta("combat_target"): direct = direct.get_meta("combat_target")
		if direct.has_method("apply_damage"):
			hits[direct.get_instance_id()] = {"target": direct, "damage": definition.damage + definition.blast_damage, "position": origin, "material": direct_material, "direct": true}
		else:
			emit_event({"type": &"impact", "weapon_id": definition.identifier, "shot_id": shot_id, "position": origin, "target_id": str(direct.get_instance_id()), "material": direct_material, "pellets": 1})
	var sphere := SphereShape3D.new(); sphere.radius = definition.blast_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere; query.transform = Transform3D(Basis.IDENTITY, origin)
	query.collision_mask = 14; query.exclude = anatomical_exclusions()
	var candidates := get_world_3d().direct_space_state.intersect_shape(query, 256)
	var splash: Dictionary = {}
	for contact in candidates:
		var body: Object = contact.collider
		var target: Object = body.get_meta("combat_target") if body.has_meta("combat_target") else body
		if not target.has_method("apply_damage") or target.gibbed: continue
		var point: Vector3 = body.global_position
		var shape_node := body.get_node_or_null("HitSurface") as CollisionShape3D
		if shape_node == null: shape_node = body.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if shape_node != null and shape_node.shape != null:
			point = shape_node.global_transform * shape_node.shape.get_debug_mesh().get_aabb().get_center()
		var distance := origin.distance_to(point)
		var key: int = target.get_instance_id()
		# A direct surface contact receives the contact blast at zero distance.
		# It was already aggregated above and must never be applied a second time.
		if hits.has(key): continue
		if distance >= definition.blast_radius or not blast_visible(origin, point): continue
		var amount := definition.blast_damage * (1.0 - distance / definition.blast_radius)
		if not splash.has(key) or splash[key].damage < amount:
			splash[key] = {"target": target, "damage": amount, "position": point, "material": material_for(body), "direct": false}
	for key in splash: hits[key] = splash[key]
	for value in hits.values():
		var target: Object = value.target
		emit_event({"type": &"impact", "weapon_id": definition.identifier, "shot_id": shot_id, "target_id": target.target_id, "material": value.material, "position": value.position, "pellets": 1, "damage": value.damage, "direct": value.direct})
		if target.dead: target.apply_corpse_damage(value.damage, shot_id, definition.identifier, value.position, value.material)
		else: target.apply_damage(value.damage, shot_id, definition.identifier, value.position, value.material)
	var self_distance := origin.distance_to(player.global_position)
	if self_distance < definition.blast_radius and blast_visible(origin, player.global_position):
		receive_player_damage(60.0 * (1.0 - self_distance / definition.blast_radius), "player_siege_launcher", origin)

func blast_visible(from: Vector3, to: Vector3) -> bool:
	if from.is_equal_approx(to): return true
	# World layer includes static walls and current moving-door collision geometry.
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()
