extends AnimatableBody3D
## One-way persistent opening keeps shortcuts readable and cannot crush actors.
const OPEN_SOUND := preload("res://assets/audio/ward-v19/door_open.ogg")
@export var open_offset: Vector3 = Vector3(0, 3.5, 0)
@export var speed: float = 2.8
@export var required_key: bool = false
var opened := false
var origin: Vector3
var initialized := false
var motor: AudioStreamPlayer3D
func _ready() -> void:
	sync_to_physics = true
	origin = position; initialized = true
	open_offset = get_meta("open_offset", open_offset)
	required_key = bool(get_meta("required_key", required_key))
	motor = AudioStreamPlayer3D.new()
	motor.name = "DoorMotor"
	motor.bus = &"World"
	motor.volume_db = -4.0
	motor.unit_size = 5.0
	motor.max_distance = 30.0
	add_child(motor)
func activate(has_key: bool) -> bool:
	if required_key and not has_key: return false
	if not opened and is_instance_valid(motor):
		motor.stop()
		motor.stream = OPEN_SOUND
		motor.play()
	opened = true
	return true
func _physics_process(delta: float) -> void:
	if opened: position = position.move_toward(origin + open_offset, speed * delta)
func reset_door() -> void:
	# Reset is only called during a fresh/reset encounter, never closes on active play.
	if is_instance_valid(motor): motor.stop()
	opened = false
	if initialized: position = origin
func is_open() -> bool:
	return opened and position.distance_to(origin + open_offset) < .02
