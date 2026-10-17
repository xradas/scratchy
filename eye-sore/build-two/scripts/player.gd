extends CharacterBody3D

const SPEED: float = 8.0
const ACCELERATION: float = 42.0
const GRAVITY: float = 24.0
const STEP_HEIGHT: float = 0.18
const CROUCH_HEIGHT: float = 1.10
const CROUCH_SPEED: float = 0.55
const SPRINT_SPEED: float = 1.35
const BOB_STRIDE: float = 3.2
const BOB_SIDE: float = 0.018
const BOB_DOWN: float = 0.022
var sensitivity: float = 0.002
var bob_intensity: float = 0.35
var is_crouching: bool = false
var is_sprinting: bool = false
var _movement_active: bool = true
var _wait_for_key_release: bool = false
var _standing_height: float
var _standing_camera_position: Vector3
var _standing_shape: CapsuleShape3D
var _bob_distance: float = 0.0
var _bob_offset := Vector3.ZERO
@onready var camera: Camera3D = $Camera3D
@onready var body_collision: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	# Scene instances otherwise share this mutable subresource. Crouching one
	# actor must never resize another actor or the next world loaded by Retry.
	assert(body_collision.shape is CapsuleShape3D)
	body_collision.shape = body_collision.shape.duplicate()
	_standing_height = body_collision.shape.height
	_standing_shape = body_collision.shape.duplicate()
	_standing_camera_position = camera.position
	_wait_for_key_release = _movement_keys_down()

func set_motion_settings(value: float) -> void:
	bob_intensity = clampf(value, 0.0, 1.0)
	if is_node_ready() and is_zero_approx(bob_intensity): _neutral_bob()

func set_movement_active(active: bool) -> void:
	_movement_active = active
	if not active:
		velocity = Vector3.ZERO
		is_sprinting = false
		_wait_for_key_release = true
		if is_node_ready(): _neutral_bob()

func _notification(what: int) -> void:
	if not is_node_ready(): return
	if what == NOTIFICATION_PAUSED:
		velocity = Vector3.ZERO
		is_sprinting = false
		_neutral_bob()
	elif what == NOTIFICATION_UNPAUSED:
		_wait_for_key_release = _movement_keys_down()

func _movement_keys_down() -> bool:
	for code in [KEY_W, KEY_S, KEY_A, KEY_D, KEY_CTRL, KEY_SHIFT]:
		if Input.is_physical_key_pressed(code): return true
	return false

func _neutral_camera_position() -> Vector3:
	var neutral := _standing_camera_position
	neutral.y -= (_standing_height - float(body_collision.shape.height)) * 0.5
	return neutral

func _neutral_bob() -> void:
	_bob_distance = 0.0
	_bob_offset = Vector3.ZERO
	camera.position = _neutral_camera_position()

func _can_stand() -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _standing_shape
	query.transform = body_collision.global_transform
	query.transform.origin.y += (_standing_height - float(body_collision.shape.height)) * 0.5 + 0.002
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	# Existing side contacts are safe to retain when expanding vertically. An
	# extra query margin would falsely prevent standing beside an ordinary wall.
	query.margin = 0.0
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func _set_crouching(crouch: bool) -> void:
	if crouch == is_crouching: return
	if not crouch and not _can_stand(): return
	var height := maxf(CROUCH_HEIGHT, body_collision.shape.radius * 2.0) if crouch else _standing_height
	var difference := height - float(body_collision.shape.height)
	body_collision.shape.height = height
	# The collision shape stays centered; moving the body by half the height
	# change preserves its feet and the camera's head clearance together.
	global_position.y += difference * 0.5
	is_crouching = crouch
	camera.position = _neutral_camera_position() + _bob_offset

func _update_bob(delta: float, travel: Vector3, grounded: bool) -> void:
	var horizontal := Vector2(travel.x, travel.z).length()
	var wanted := Vector3.ZERO
	if grounded and horizontal > 0.00001 and bob_intensity > 0.0:
		_bob_distance = fposmod(_bob_distance + horizontal, BOB_STRIDE)
		var phase := _bob_distance / BOB_STRIDE * TAU
		wanted = Vector3(sin(phase) * BOB_SIDE, -absf(sin(phase)) * BOB_DOWN, 0.0) * bob_intensity
	_bob_offset = _bob_offset.lerp(wanted, 1.0 - exp(-18.0 * delta))
	if _bob_offset.length_squared() < 0.00000001 and wanted == Vector3.ZERO: _bob_offset = Vector3.ZERO
	camera.position = _neutral_camera_position() + _bob_offset

func _unhandled_input(event: InputEvent) -> void:
	if _movement_active and not get_tree().paused and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.screen_relative.x * sensitivity)
		camera.rotation.x = clampf(camera.rotation.x - event.screen_relative.y * sensitivity, -1.48, 1.48)

func _physics_process(delta: float) -> void:
	if get_tree().paused or not _movement_active:
		velocity = Vector3.ZERO
		is_sprinting = false
		_neutral_bob()
		return
	var movement := Vector2.ZERO
	if _wait_for_key_release and not _movement_keys_down(): _wait_for_key_release = false
	if not _wait_for_key_release:
		if Input.is_physical_key_pressed(KEY_W): movement.y -= 1.0
		if Input.is_physical_key_pressed(KEY_S): movement.y += 1.0
		if Input.is_physical_key_pressed(KEY_A): movement.x -= 1.0
		if Input.is_physical_key_pressed(KEY_D): movement.x += 1.0
	_set_crouching(not _wait_for_key_release and Input.is_physical_key_pressed(KEY_CTRL))
	is_sprinting = not _wait_for_key_release and not is_crouching and is_on_floor() and movement != Vector2.ZERO and Input.is_physical_key_pressed(KEY_SHIFT)
	var speed := SPEED * (CROUCH_SPEED if is_crouching else (SPRINT_SPEED if is_sprinting else 1.0))
	var direction := transform.basis * Vector3(movement.x, 0, movement.y).normalized()
	velocity.x = move_toward(velocity.x, direction.x * speed, ACCELERATION * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, ACCELERATION * delta)
	if not is_on_floor(): velocity.y -= GRAVITY * delta
	else: velocity.y = 0.0
	var before := global_position
	var grounded := is_on_floor()
	step_up(Vector3(velocity.x, 0, velocity.z) * delta)
	move_and_slide()
	apply_floor_snap()
	_update_bob(delta, global_position - before, grounded and is_on_floor())
	if not is_on_floor(): is_sprinting = false

func step_up(motion: Vector3) -> void:
	# A grounded step is a short clearance test, never a jump or an airborne boost.
	preload("res://scripts/grounded_step.gd").climb(self, motion, STEP_HEIGHT)
