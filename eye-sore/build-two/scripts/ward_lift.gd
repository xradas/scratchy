extends AnimatableBody3D
## Shared visible/collision platform; passengers use CharacterBody moving-platform carry.
@export var lift_offset: Vector3 = Vector3(0, 2.4, 0)
@export var speed: float = 1.25
var origin: Vector3
var upper := false
var moving := false
var obstructed := false
var departure_pending := false
var landing_gates: Array[Node] = []
var departure_gates: Array[Node] = []
func _ready() -> void:
	sync_to_physics = true; origin = position
	lift_offset = get_meta("lift_offset", lift_offset)
func activate(_has_key: bool = false) -> bool:
	if moving: return false
	departure_gates.clear()
	for gate in landing_gates:
		if gate.opened:
			if not gate.entrance_clear(): return false
			departure_gates.append(gate)
	upper = not upper; moving = true
	departure_pending = not departure_gates.is_empty()
	refresh_landing_gates()
	return true
func register_landing_gate(gate: Node) -> void:
	landing_gates.append(gate)
	gate.refresh()
func refresh_landing_gates() -> void:
	for gate in landing_gates: gate.refresh()
func _physics_process(delta: float) -> void:
	if not moving: return
	if departure_pending:
		# Give deferred guard colliders a physics boundary before deck motion.
		# Recheck in case a body entered during the activation frame.
		for gate in departure_gates:
			if not gate.entrance_clear():
				upper = not upper; moving = false; departure_pending = false
				refresh_landing_gates()
				return
		departure_pending = false
		return
	var destination := origin + (lift_offset if upper else Vector3.ZERO)
	var next := position.move_toward(destination, speed * delta)
	if next.y < position.y and body_below(next):
		obstructed = true
		refresh_landing_gates()
		return
	if obstructed:
		# Lower emergency egress stays open until the body has also cleared
		# its guard, then the guard closes before descent resumes.
		for gate in landing_gates:
			if gate.opened and not gate.entrance_clear(): return
		obstructed = false
		refresh_landing_gates()
		return
	position = next
	if position.distance_to(destination) < .001: position = destination; moving = false
	refresh_landing_gates()
func body_below(next_position: Vector3) -> bool:
	var collision: CollisionShape3D = get_node_or_null("Collision")
	if collision == null or not collision.shape is BoxShape3D: return false
	# Preserve the prospective top surface, extending only the underside
	# clearance by 0.4m. Riders standing above the deck are not obstructions.
	var volume := BoxShape3D.new()
	volume.size = collision.shape.size + Vector3(0, 0.4, 0)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = volume
	query.transform = global_transform
	query.transform.origin = get_parent().to_global(next_position - Vector3(0, 0.2, 0))
	query.margin = 0.001
	query.collision_mask = 2 | 4
	return not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
func reset_lift() -> void:
	moving = false; upper = false; obstructed = false; departure_pending = false; position = origin
	departure_gates.clear()
	refresh_landing_gates()
