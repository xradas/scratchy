extends AnimatableBody3D
## Shared visible/collision platform; passengers use CharacterBody moving-platform carry.
@export var lift_offset: Vector3 = Vector3(0, 2.4, 0)
@export var speed: float = 1.25
var origin: Vector3
var upper := false
var moving := false
func _ready() -> void:
	sync_to_physics = true; origin = position
	lift_offset = get_meta("lift_offset", lift_offset)
func activate(_has_key: bool = false) -> bool:
	if moving: return false
	upper = not upper; moving = true
	return true
func _physics_process(delta: float) -> void:
	if not moving: return
	var destination := origin + (lift_offset if upper else Vector3.ZERO)
	position = position.move_toward(destination, speed * delta)
	if position.distance_to(destination) < .001: position = destination; moving = false
func reset_lift() -> void:
	moving = false; upper = false; position = origin
