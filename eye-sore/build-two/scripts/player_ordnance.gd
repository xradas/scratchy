extends Node3D
## One swept projectile owns one explosion. Presentation never applies damage.
var combat: Node3D
var definition: WeaponDefinition
var velocity: Vector3
var shot_id: int = 0
var lifetime: float = 0.0
var travelled: float = 0.0
var resolved: bool = false
var sweep_shape := SphereShape3D.new()

func setup(controller: Node3D, settings: WeaponDefinition, direction: Vector3, accepted_shot_id: int) -> void:
	combat = controller; definition = settings; shot_id = accepted_shot_id
	velocity = direction.normalized() * definition.projectile_speed
	sweep_shape.radius = 0.09
	process_mode = Node.PROCESS_MODE_PAUSABLE

func is_combat_projectile() -> bool: return true

func _physics_process(delta: float) -> void:
	if resolved or not is_instance_valid(combat) or get_tree().paused: return
	var step_time := minf(delta, maxf(0.0, definition.projectile_lifetime - lifetime))
	var remaining_range := maxf(0.0, definition.range_units - travelled)
	var motion := velocity * step_time
	if motion.length() > remaining_range: motion = motion.normalized() * remaining_range
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sweep_shape; query.transform = Transform3D(Basis.IDENTITY, global_position)
	query.motion = motion; query.collision_mask = 15; query.exclude = combat.anatomical_exclusions()
	var space := get_world_3d().direct_space_state
	var overlaps := space.intersect_shape(query, 1)
	if not overlaps.is_empty():
		finish(global_position, overlaps[0].collider)
		return
	var fractions := space.cast_motion(query)
	if fractions[0] < 1.0:
		var safe_position := global_position + motion * fractions[0]
		query.motion = Vector3.ZERO
		query.transform.origin = global_position + motion * minf(1.0, fractions[1] + .002)
		var contact := space.get_rest_info(query)
		var collider: Object = instance_from_id(contact.collider_id) if not contact.is_empty() else null
		if collider == null:
			var ray_hit: Dictionary = combat.ray(global_position, global_position + motion, query.exclude, true)
			if not ray_hit.is_empty(): collider = ray_hit.collider
		# Even unrecoverable contact geometry stops the ordnance and explodes once.
		finish(safe_position, collider)
		return
	global_position += motion
	travelled += motion.length(); lifetime += step_time
	if lifetime >= definition.projectile_lifetime or travelled >= definition.range_units:
		# An airburst also has a single accepted shot identity and radial ownership.
		finish(global_position, null)

func finish(at: Vector3, collider: Object) -> void:
	if resolved: return
	resolved = true
	set_physics_process(false)
	var material: StringName = combat.material_for(collider) if is_instance_valid(collider) else &"hard"
	combat.resolve_ordnance_explosion(definition, at, collider, material, shot_id)
	queue_free()
