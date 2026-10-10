extends AnimatableBody3D
## The same body owns visual and collision; permanent opening never crushes actors.
@export var open_offset := Vector3(0, 5.5, 0)
@export var speed := 4.0
var origin: Vector3
var opened := false
var initialized := false
func _ready() -> void:
	sync_to_physics = true
	origin = position; initialized = true
	open_offset = get_meta("open_offset", open_offset)
func activate(flags: Dictionary = {}) -> bool:
	for requirement in get_meta("requires", []):
		if not flags.get(String(requirement), false): return false
	opened = true
	return true
func _physics_process(delta: float) -> void:
	if opened: position = position.move_toward(origin + open_offset, speed * delta)
func reset_door() -> void:
	opened = false
	if initialized: position = origin
func is_open() -> bool:
	return opened and position.distance_to(origin + open_offset) < .02
