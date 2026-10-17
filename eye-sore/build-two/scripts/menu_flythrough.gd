extends Node3D

# These are deliberately short moves within individual authored rooms. Cutting
# between rooms avoids flying a spectator camera through a closed gameplay door.
const SHOT_SECONDS := 12.0
const FADE_SECONDS := 0.55
const WARD_INTAKE_SHOTS := [
	{"from": Vector3(-10.0, 2.2, 8.0), "to": Vector3(-5.0, 2.4, 5.0), "look_from": Vector3(0.0, 1.8, -6.0), "look_to": Vector3(4.0, 1.9, -8.0)},
	{"from": Vector3(8.0, 2.1, -34.0), "to": Vector3(-6.0, 2.3, -34.0), "look_from": Vector3(0.0, 1.8, -44.0), "look_to": Vector3(-2.0, 1.8, -45.0)},
	{"from": Vector3(72.0, 4.1, 7.0), "to": Vector3(78.0, 4.3, 8.0), "look_from": Vector3(80.0, 3.7, -5.0), "look_to": Vector3(84.0, 3.6, -4.0)},
	{"from": Vector3(-7.0, 4.0, 87.0), "to": Vector3(7.0, 4.3, 87.0), "look_from": Vector3(0.0, 3.6, 74.0), "look_to": Vector3(2.0, 3.8, 75.0)},
]

var camera: Camera3D
var fade: ColorRect
var active := false
var elapsed := 0.0
var hidden_enemies: Dictionary = {}
var previous_camera: Camera3D
var combat: Node3D
var shots: Array[Dictionary] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	camera = Camera3D.new()
	camera.name = "TitleCamera"
	camera.fov = 74.0
	camera.near = 0.05
	camera.far = 200.0
	add_child(camera)
	set_process(false)

func setup(combat_node: Node3D, gameplay_camera: Camera3D, fade_rect: ColorRect, level_id: String = "") -> void:
	stop()
	combat = combat_node
	previous_camera = gameplay_camera
	fade = fade_rect
	shots.clear()
	if level_id == "pale_ward_01":
		for shot in WARD_INTAKE_SHOTS: shots.append(shot)
	else:
		var path := "res://resources/campaign/%s-layout.json" % level_id
		if not level_id.is_empty() and FileAccess.file_exists(path):
			var layout: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if layout is Dictionary:
				var rooms: Array = layout.get("rooms", [])
				for fraction in [0.0, 0.25, 0.5, 0.75]:
					if rooms.is_empty(): break
					var room: Dictionary = rooms[mini(int(floorf(rooms.size() * fraction)), rooms.size() - 1)]
					shots.append(_room_shot(room))
	if shots.is_empty():
		var spawn := previous_camera.global_position
		shots.append({"from": spawn + Vector3(-1.5, 0.3, 0.0), "to": spawn + Vector3(1.5, 0.4, 0.0), "look_from": spawn + Vector3(0.0, 0.0, -8.0), "look_to": spawn + Vector3(0.0, 0.0, -8.0)})
	if is_instance_valid(fade): fade.color.a = 0.0

func _room_shot(room: Dictionary) -> Dictionary:
	var center_data: Array = room.get("center", [0, 0, 0])
	var size_data: Array = room.get("size", [20, 7, 20])
	var center := Vector3(float(center_data[0]), float(center_data[1]), float(center_data[2]))
	var extent_x := minf(4.0, float(size_data[0]) * 0.17)
	var extent_z := minf(4.0, float(size_data[2]) * 0.16)
	# Elevating the camera clears most props; authored room bounds keep all four
	# moving points several metres from walls and closed door planes.
	return {"from": center + Vector3(-extent_x, 2.5, extent_z), "to": center + Vector3(extent_x, 2.7, extent_z * 0.7), "look_from": center + Vector3(0.0, 2.0, -extent_z), "look_to": center + Vector3(-extent_x * 0.45, 2.1, -extent_z)}

func start() -> bool:
	if not is_instance_valid(combat) or not is_instance_valid(camera) or shots.is_empty(): return false
	if not is_instance_valid(previous_camera): return false
	# The world remains paused at title. Hiding the authored enemy instances keeps
	# the environment intact, without changing their health or encounter state.
	hidden_enemies.clear()
	for enemy in combat.enemies:
		if not is_instance_valid(enemy): continue
		hidden_enemies[enemy] = enemy.visible
		enemy.visible = false
	elapsed = 0.0
	active = true
	_render_shot()
	camera.make_current()
	set_process(true)
	return true

func stop() -> void:
	if not active: return
	active = false
	set_process(false)
	for enemy in hidden_enemies:
		if is_instance_valid(enemy): enemy.visible = hidden_enemies[enemy]
	hidden_enemies.clear()
	if is_instance_valid(fade): fade.color.a = 0.0
	if is_instance_valid(previous_camera): previous_camera.make_current()

func _process(delta: float) -> void:
	if not active: return
	elapsed = fposmod(elapsed + delta, SHOT_SECONDS * shots.size())
	_render_shot()

func _render_shot() -> void:
	var shot_index := int(elapsed / SHOT_SECONDS)
	var shot: Dictionary = shots[shot_index]
	var phase := fposmod(elapsed, SHOT_SECONDS)
	var t := smoothstep(0.0, SHOT_SECONDS, phase)
	camera.position = (shot["from"] as Vector3).lerp(shot["to"], t)
	camera.look_at((shot["look_from"] as Vector3).lerp(shot["look_to"], t))
	if is_instance_valid(fade):
		var edge := minf(phase, SHOT_SECONDS - phase)
		fade.color.a = 1.0 - smoothstep(0.0, FADE_SECONDS, edge)
