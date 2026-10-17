extends AnimatableBody3D
## Ash Approach's winch lowers the same physical deck that renders the bridge.
@export var lowered_offset := Vector3(0, -8, 0)
@export var speed := 3.0
@export var wait_for_bridge: NodePath
var origin: Vector3
var opened := false

func _ready() -> void:
	sync_to_physics = true
	origin = position
	reset_door()

func reset_door() -> void:
	opened = false
	sync_to_physics = false
	position = origin
	sync_to_physics = true
	PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, global_transform)

func activate(_flags: Dictionary = {}) -> bool:
	opened = true
	return true

func is_open() -> bool:
	return opened and position.distance_to(origin + lowered_offset) < 0.02

func is_closed() -> bool:
	return not opened and position.distance_to(origin) < 0.02

func _physics_process(delta: float) -> void:
	var stage := get_parent()
	if stage != null and stage.get("flags") is Dictionary and bool(stage.flags.get("gate_winch", false)):
		if wait_for_bridge.is_empty():
			opened = true
		else:
			var bridge := get_node_or_null(wait_for_bridge)
			opened = bridge != null and bridge.has_method("is_open") and bridge.is_open()
	if opened:
		position = position.move_toward(origin + lowered_offset, speed * delta)
