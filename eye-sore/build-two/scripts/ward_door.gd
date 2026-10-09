extends AnimatableBody3D
## One-way persistent opening keeps shortcuts readable and cannot crush actors.
@export var open_offset: Vector3 = Vector3(0, 3.5, 0)
@export var speed: float = 2.8
@export var required_key: bool = false
var opened := false
var origin: Vector3
var initialized := false
func _ready() -> void:
	sync_to_physics = true
	origin = position; initialized = true
	open_offset = get_meta("open_offset", open_offset)
	required_key = bool(get_meta("required_key", required_key))
func activate(has_key: bool) -> bool:
	if required_key and not has_key: return false
	opened = true
	return true
func _physics_process(delta: float) -> void:
	if opened: position = position.move_toward(origin + open_offset, speed * delta)
func reset_door() -> void:
	# Reset is only called during a fresh/reset encounter, never closes on active play.
	opened = false
	if initialized: position = origin
func is_open() -> bool:
	return opened and position.distance_to(origin + open_offset) < .02
