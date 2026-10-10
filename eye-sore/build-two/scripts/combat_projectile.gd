extends Node3D
var combat: Node3D
var owner_enemy: CharacterBody3D
var velocity: Vector3
var damage: float
var lifetime: float = 0.0
var resolved: bool = false
var sweep_shape := SphereShape3D.new()

func setup(controller: Node3D, enemy: CharacterBody3D, motion: Vector3, amount: float) -> void:
	combat = controller; owner_enemy = enemy; velocity = motion; damage = amount; sweep_shape.radius = 0.12
	# Per-instance visual override preserves the shared Vessel mesh/material.
	var palette := {&"censer": Color(1, .3, .045), &"surveyor": Color(.08, .72, .9)}
	$Visual.material_override = null
	if palette.has(enemy.definition.identifier):
		var material: StandardMaterial3D = $Visual.mesh.surface_get_material(0).duplicate()
		material.albedo_color = palette[enemy.definition.identifier]
		material.emission = palette[enemy.definition.identifier]
		$Visual.material_override = material

func is_combat_projectile() -> bool: return true

func _physics_process(delta: float) -> void:
	if resolved or not is_instance_valid(combat): return
	lifetime += delta
	if lifetime > 6.0: resolved = true; queue_free(); return
	var motion := velocity * delta
	var exclude: Array[RID] = []
	if is_instance_valid(owner_enemy): exclude.append(owner_enemy.get_rid())
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sweep_shape; query.transform = global_transform; query.motion = motion; query.collision_mask = 3; query.exclude = exclude
	var space := get_world_3d().direct_space_state
	var overlaps := space.intersect_shape(query, 1)
	var fractions := space.cast_motion(query)
	var collision: Object = null
	var hit_position := global_position
	if not overlaps.is_empty(): collision = overlaps[0].collider
	elif fractions[0] < 1.0:
		query.motion = Vector3.ZERO
		query.transform.origin += motion * minf(1.0, fractions[1] + 0.001)
		var contact := space.get_rest_info(query)
		if not contact.is_empty(): collision = instance_from_id(contact.collider_id); hit_position = contact.point
		if collision == null:
			var ray_hit: Dictionary = combat.ray(global_position, global_position + motion, exclude)
			if not ray_hit.is_empty(): collision = ray_hit.collider; hit_position = ray_hit.position
	if collision != null:
		resolved = true
		if collision == combat.player:
			combat.receive_player_damage(damage, owner_enemy.target_id if is_instance_valid(owner_enemy) else "projectile", hit_position)
		combat.emit_event({"type": &"projectile_impact", "enemy_kind": owner_enemy.definition.identifier if is_instance_valid(owner_enemy) else &"vessel", "position": hit_position, "material": &"flesh" if collision == combat.player else combat.material_for(collision)})
		queue_free(); return
	# A swept obstacle without recoverable collider information still blocks motion.
	if fractions[0] < 1.0: resolved = true; queue_free(); return
	global_position += motion
