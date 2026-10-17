extends CharacterBody3D

const SPEED: float = 8.0
const ACCELERATION: float = 42.0
const GRAVITY: float = 24.0
const STEP_HEIGHT: float = 0.18
var sensitivity: float = 0.002
@onready var camera: Camera3D = $Camera3D

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.screen_relative.x * sensitivity)
		camera.rotation.x = clampf(camera.rotation.x - event.screen_relative.y * sensitivity, -1.48, 1.48)

func _physics_process(delta: float) -> void:
	var movement := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W): movement.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S): movement.y += 1.0
	if Input.is_physical_key_pressed(KEY_A): movement.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D): movement.x += 1.0
	var direction := transform.basis * Vector3(movement.x, 0, movement.y).normalized()
	velocity.x = move_toward(velocity.x, direction.x * SPEED, ACCELERATION * delta)
	velocity.z = move_toward(velocity.z, direction.z * SPEED, ACCELERATION * delta)
	if not is_on_floor(): velocity.y -= GRAVITY * delta
	else: velocity.y = 0.0
	step_up(Vector3(velocity.x, 0, velocity.z) * delta)
	move_and_slide()
	apply_floor_snap()

func step_up(motion: Vector3) -> void:
	# A grounded step is a short clearance test, never a jump or an airborne boost.
	preload("res://scripts/grounded_step.gd").climb(self, motion, STEP_HEIGHT)
