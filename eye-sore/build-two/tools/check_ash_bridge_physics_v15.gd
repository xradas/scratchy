extends SceneTree
## Independent source-scene collision check for Ash Approach's real bridge.

var stage: Node3D
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
		push_error(label)

func settle(frames: int = 4) -> void:
	for i in frames:
		await physics_frame

func hit(start: Vector3, finish: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(start, finish, 1)
	return stage.get_world_3d().direct_space_state.intersect_ray(query)

func collider_name(result: Dictionary) -> String:
	return String(result.collider.name) if not result.is_empty() else "none"

func route_point_floor(point: Array, label: String) -> void:
	var at := Vector3(float(point[0]), float(point[1]), float(point[2]))
	var ground := hit(at + Vector3.UP * 1.5, at - Vector3.UP * 2.0)
	check(not ground.is_empty() and absf(ground.position.y - at.y) < 0.35,
		label + " must have supported route floor at " + str(at) + " hit=" + collider_name(ground))

func run() -> void:
	stage = load("res://scenes/campaign/ash_citadel_01.tscn").instantiate()
	root.add_child(stage)
	await settle()
	var bridge: Node3D = stage.get_node_or_null("BridgeDeck")
	var safety: Node3D = stage.get_node_or_null("BridgeSafetyGate")
	var gate: Node3D = stage.get_node_or_null("Door_bridge_gate")
	check(bridge != null and safety != null and gate != null, "Bridge, safety gate and inner gate must exist")
	if bridge == null or safety == null or gate == null:
		quit(1)
		return
	var down := hit(Vector3(40, 18, 20), Vector3(40, -8, 20))
	check(collider_name(down) == "BridgeDeck" and absf(down.position.y - 14) < 0.05, "Closed bridge must be raised physically")
	var closed_barrier := hit(Vector3(40, 7, 12.8), Vector3(40, 7, 15.5))
	check(collider_name(closed_barrier) == "BridgeSafetyGate", "Closed safety gate must block the bridge mouth")
	var pit := hit(Vector3(40, 5, 20), Vector3(40, -8, 20))
	check(collider_name(pit) == "BridgePitFloor" and absf(pit.position.y + 2.0) < 0.05, "Closed bridge pit must catch a fall")
	stage.flags["gate_winch"] = true
	await settle(360)
	check(bridge.is_open() and safety.is_open(), "Winch must finish deck and safety gate motion")
	var open_deck := hit(Vector3(40, 7, 20), Vector3(40, -8, 20))
	check(collider_name(open_deck) == "BridgeDeck" and absf(open_deck.position.y - 6) < 0.05, "Lowered deck must provide physical crossing floor")
	var open_mouth := hit(Vector3(40, 7, 12.8), Vector3(40, 7, 15.5))
	check(open_mouth.is_empty(), "Lowered bridge safety gate must clear walking height")
	var closed_gate := hit(Vector3(40, 7, 24.9), Vector3(40, 7, 26.5))
	check(collider_name(closed_gate) == "Door_bridge_gate", "Inner gate must block until operated")
	check(gate.activate({"gate_winch":true}), "Inner gate must accept winch flag")
	await settle(150)
	var open_gate := hit(Vector3(40, 7, 24.9), Vector3(40, 7, 26.5))
	check(open_gate.is_empty(), "Operated inner gate must clear walking height")
	var route: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/campaign/ash_citadel_01-route.json"))
	for portal in route.portals:
		var points: Array = portal.get("traverse_points", [])
		for index in points.size():
			route_point_floor(points[index], String(portal.id) + " sample " + str(index))
	stage.flags.clear()
	bridge.reset_door()
	safety.reset_door()
	gate.reset_door()
	await settle()
	check(collider_name(hit(Vector3(40, 7, 12.8), Vector3(40, 7, 15.5))) == "BridgeSafetyGate", "Retry must restore blocked bridge mouth")
	print("ASH_BRIDGE_PHYSICS_RESULT failures=", failures.size(), " details=", failures)
	quit(0 if failures.is_empty() else 1)
