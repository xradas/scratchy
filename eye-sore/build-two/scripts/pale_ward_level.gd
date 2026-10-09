extends Node3D
signal completed
signal message_changed(text: String)
const Door = preload("res://scripts/ward_door.gd")
const Lift = preload("res://scripts/ward_lift.gd")
const ROOM_LABELS = {"ContainmentHall":"Containment Hall","BioWing":"Bio Wing","OperatingRoom":"Operating Room","RearLab":"Rear Lab","ExitGallery":"Discharge Gallery","Secret":"Service Alcove"}
var combat: Node
var player: CharacterBody3D
var rooms: Array[Node3D] = []
var pickups: Array[Node3D] = []
var mechanisms: Array[Node3D] = []
var navigation: Array[Node3D] = []
var exit_marker: Node3D
var collected: Dictionary = {}
var visited: Dictionary = {}
var has_key := false
var shortcut_open := false
var secret_found := false
var finished := false
var prompt := ""
var objective := "Find the containment key in the bio-wing."
var current_room := ""
func setup(controller: Node, actor: CharacterBody3D) -> void:
	combat = controller; player = actor
	rooms.clear(); pickups.clear(); mechanisms.clear(); navigation.clear(); exit_marker = null
	scan(self if has_node("Player") else get_parent())
	reset()
func scan(node: Node) -> void:
	if node is Node3D:
		if node.has_meta("ward_room"): rooms.append(node)
		if node.has_meta("ward_nav"): navigation.append(node)
		if node.has_meta("ward_pickup"): pickups.append(node)
		if node.has_meta("ward_exit"): exit_marker = node
		if node.has_meta("ward_door") or node.has_meta("ward_lift"):
			assert(node is AnimatableBody3D,"Ward mechanisms require shared AnimatableBody3D mesh/collision")
			if node.get_script() == null:
				node.set_script(Lift if node.has_meta("ward_lift") else Door)
				node._ready()
			mechanisms.append(node)
	for child in node.get_children():
		if child != self: scan(child)
func reset() -> void:
	collected.clear(); visited.clear(); has_key = false; shortcut_open = false
	secret_found = false; finished = false; current_room = ""; prompt = ""
	objective = "Find the containment key in the bio-wing."
	for item in pickups: item.visible = true
	for mechanism in mechanisms:
		if mechanism.has_method("reset_door"): mechanism.reset_door()
		if mechanism.has_method("reset_lift"): mechanism.reset_lift()
func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player) or finished or combat.dead: return
	for room in rooms:
		var extent: Vector3 = room.get_meta("room_bounds", Vector3(5, 3, 5))
		var local := room.to_local(player.global_position)
		if absf(local.x) <= extent.x and absf(local.y) <= extent.y and absf(local.z) <= extent.z:
			current_room = String(room.get_meta("ward_room")); visited[current_room] = true
	for item in pickups:
		if not collected.has(item.get_instance_id()) and player.global_position.distance_to(item.global_position) <= 1.05:
			collect(item)
	var selected := nearest_mechanism()
	prompt = ""
	if selected != null:
		if selected.has_meta("ward_exit"):
			prompt = "E · leave the Pale Ward" if has_key else "Find the containment key first"
		elif selected.has_meta("ward_lift"):
			prompt = "Lift travelling" if selected.moving else "E · operate lift"
		elif selected.required_key and not has_key: prompt = "Containment key required"
		elif not selected.opened: prompt = "E · open " + String(selected.get_meta("ward_door"))
func collect(item: Node3D) -> void:
	var kind := String(item.get_meta("ward_pickup"))
	var amount := int(item.get_meta("amount", 25 if kind in ["health", "armor"] else 12))
	if kind == "health":
		if combat.health >= 100: return
		combat.health = minf(100, combat.health + amount)
	elif kind == "armor":
		if combat.armor >= 100: return
		combat.armor = minf(100, combat.armor + amount)
	elif kind == "pistol": combat.ammo_pistol += amount
	elif kind == "shells": combat.ammo_shotgun += amount
	elif kind == "key":
		has_key = true; objective = "Return to the raised containment door; reach the discharge exit."
	else: return
	collected[item.get_instance_id()] = true; item.visible = false
	message_changed.emit("Containment key acquired" if kind == "key" else "%s +%d" % [kind.capitalize(), amount])
func nearest_mechanism() -> Node3D:
	if not is_instance_valid(player): return null
	var choices: Array[Node3D] = mechanisms.duplicate()
	if exit_marker != null: choices.append(exit_marker)
	var best: Node3D; var distance := 2.6
	for candidate in choices:
		var anchor: Vector3 = candidate.get_meta("use_anchor", Vector3.ZERO)
		# Door interaction anchor stays at its original closed position after opening.
		var point := candidate.to_global(anchor)
		if candidate.has_method("reset_door"): point = candidate.get_parent().to_global(candidate.origin + anchor)
		var delta := player.global_position.distance_to(point)
		if delta < distance:
			var camera: Camera3D = player.get_node_or_null("Camera3D")
			if camera != null:
				var query := PhysicsRayQueryParameters3D.create(camera.global_position, point, 1, [player.get_rid()])
				var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
				if not hit.is_empty() and hit.collider != candidate and hit.position.distance_to(point) > .12: continue
			best = candidate; distance = delta
	return best
func interact() -> bool:
	if finished or not is_instance_valid(player) or combat.dead: return false
	var selected := nearest_mechanism()
	if selected == null: return false
	if selected.has_meta("ward_exit"):
		if not has_key: message_changed.emit("Containment key required"); return false
		finished = true; objective = "Pale Ward cleared."; prompt = ""; completed.emit(); return true
	if not selected.activate(has_key):
		message_changed.emit("Containment key required" if selected.has_meta("ward_door") else "Lift travelling"); return false
	var id := String(selected.get_meta("ward_door", ""))
	if id == "shortcut": shortcut_open = true
	if id == "secret": secret_found = true; message_changed.emit("Secret found")
	return true
func get_level_state() -> Dictionary:
	var map: Array[Dictionary] = []
	for room in rooms:
		var id := String(room.get_meta("ward_room"))
		if visited.has(id):
			var bounds:Vector3=room.get_meta("room_bounds",Vector3(5,3,5))
			map.append({"id":id,"label":room.get_meta("ward_label",ROOM_LABELS.get(id,id)),"rect":Rect2(Vector2(room.global_position.x-bounds.x,room.global_position.z-bounds.z),Vector2(bounds.x*2,bounds.z*2)),"visited":true,"position":room.global_position,"bounds":bounds})
	return {"objective":objective,"prompt":prompt,"current_room":current_room,"visited_rooms":visited.keys(),"map_rooms":map,"key":has_key,"shortcut_open":shortcut_open,"secret_found":secret_found,"exit_ready":has_key,"completed":finished,"pickups_remaining":pickups.size()-collected.size()}

func room_at(point: Vector3) -> String:
	var result := ""; var best := INF
	for room in rooms:
		var bounds:Vector3=room.get_meta("room_bounds",Vector3(5,3,5))
		var local:Vector3=room.to_local(point)
		if absf(local.x)<=bounds.x+.3 and absf(local.z)<=bounds.z+.3 and absf(local.y)<=bounds.y:
			var score:float=local.length_squared()
			if score<best: best=score;result=String(room.get_meta("ward_room"))
	return result
func get_chase_target(enemy_position: Vector3, player_position: Vector3) -> Vector3:
	var start:=room_at(enemy_position);var goal:=room_at(player_position)
	if start=="" or goal=="" or start==goal:return player_position
	var queue:Array[String]=[start];var seen:Dictionary={start:true};var first:Dictionary={}
	while not queue.is_empty():
		var current:String=queue.pop_front()
		for portal in navigation:
			var pair:Array=portal.get_meta("ward_nav",[])
			if pair.size()!=2 or not pair.has(current):continue
			if portal.has_meta("ward_nav_door"):
				var door:Node=portal.get_node_or_null(portal.get_meta("ward_nav_door"))
				if door!=null and not door.is_open():continue
			var next:String=String(pair[1] if pair[0]==current else pair[0])
			if seen.has(next):continue
			seen[next]=true;first[next]=portal if current==start else first[current]
			if next==goal:
				var selected:Node3D=first[next]
				var target:Vector3=selected.global_position
				# Continue through the portal, rather than stop on a room boundary.
				var direction:Vector3=(player_position-target);direction.y=0
				return target+direction.normalized()*.8
			queue.append(next)
	return enemy_position
