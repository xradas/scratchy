extends AnimatableBody3D
## Visual and collider share this body. Trap closure waits for an empty sweep.
@export var open_offset := Vector3(0, 5.5, 0)
@export var speed := 4.0
var origin: Vector3
var opened := false
var initialized := false
var sealing := false
func _ready() -> void:
	sync_to_physics = true
	origin = position; initialized = true
	open_offset = get_meta("open_offset", open_offset)
	reset_door()
func activate(flags: Dictionary = {}) -> bool:
	for requirement in get_meta("requires", []):
		if not flags.get(String(requirement), false): return false
	opened = true; sealing = false
	return true
func sweep_is_clear() -> bool:
	var collision: CollisionShape3D = get_node_or_null("Collision")
	if collision == null or not collision.shape is BoxShape3D: return false
	var volume := BoxShape3D.new()
	volume.size = collision.shape.size + Vector3(1.4,1.4,1.4)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = volume
	query.transform = Transform3D(global_basis,get_parent().to_global(origin))
	query.collision_mask = 2 | 4
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
func seal() -> bool:
	if not sweep_is_clear(): return false
	opened = false; sealing = true
	return true
func _physics_process(delta: float) -> void:
	if opened: position = position.move_toward(origin + open_offset, speed * delta)
	elif sealing and sweep_is_clear(): position = position.move_toward(origin, speed * delta)
func reset_door() -> void:
	opened = bool(get_meta("initially_open", false)); sealing = false
	if initialized:
		sync_to_physics = false
		position = origin + open_offset if opened else origin
		sync_to_physics = true
func is_open() -> bool:
	return opened and position.distance_to(origin + open_offset) < .02
func is_closed() -> bool:
	return not opened and position.distance_to(origin) < .02
