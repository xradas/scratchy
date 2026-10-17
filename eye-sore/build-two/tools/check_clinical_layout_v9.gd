extends SceneTree
## Native capsule passage against the private, actually furnished candidate.
var candidate := ""
var report_path := ""
var failures: Array[String] = []
var checks := 0
var samples := 0
var passages: Array[Dictionary] = []
var world: Node3D
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--candidate="): candidate = arg.trim_prefix("--candidate=")
		if arg.begins_with("--report="): report_path = arg.trim_prefix("--report=")
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error("CLINICAL_V9: " + label)
func contacts(at: Vector3, radius: float) -> Array:
	var capsule := CapsuleShape3D.new(); capsule.radius = radius; capsule.height = 1.7
	var query := PhysicsShapeQueryParameters3D.new(); query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY, at); query.margin = .001; query.collision_mask = 1
	return world.get_world_3d().direct_space_state.intersect_shape(query,64)
func passage(room: Dictionary, path: Dictionary, radius: float) -> void:
	var blocked: Array = []; var unsupported: Array = []; var count := 0
	var center := Vector3(room.center[0],room.center[1],room.center[2])
	for segment in range(path.points_local_xz.size()-1):
		var a: Array = path.points_local_xz[segment]; var b: Array = path.points_local_xz[segment+1]
		var start := center+Vector3(a[0],0,a[1]); var end := center+Vector3(b[0],0,b[1])
		var direction := (end-start).normalized(); var cross_axis := Vector3(-direction.z,0,direction.x)
		var steps := maxi(1,int(ceil(start.distance_to(end)/.10)))
		var width := maxf(0,float(path.minimum_clear_width_m)*.5-radius)
		for i in range(steps+1):
			for offset in [-width,0.0,width]:
				var point: Vector3 = start.lerp(end,float(i)/steps)+cross_axis*float(offset)
				var query := PhysicsRayQueryParameters3D.create(point+Vector3.UP*.25,point-Vector3.UP*.25,1)
				var support := world.get_world_3d().direct_space_state.intersect_ray(query)
				if support.is_empty(): unsupported.append([point.x,point.y,point.z])
				var at: Vector3 = point+Vector3.UP*.87
				var found := contacts(at,radius)
				for contact in found:
					if blocked.size()<32: blocked.append({"at":[at.x,at.y,at.z],"body":String(world.get_path_to(contact.collider))})
				count += 1; samples += 1
	check(blocked.is_empty() and unsupported.is_empty(), "%s/%s radius%.2f capsule lane" % [room.id,path.id,radius])
	passages.append({"room":room.id,"id":path.id,"radius":radius,"height":1.7,"declared_clear_width":path.minimum_clear_width_m,"samples":count,"blocked":blocked,"unsupported":unsupported})
func run() -> void:
	var packed := load(candidate) as PackedScene
	if packed == null: push_error("Invalid private candidate"); quit(1); return
	world = packed.instantiate(); root.add_child(world)
	world.get_node("Player").set_physics_process(false); world.scan(world)
	for i in 3: await physics_frame
	var plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/production-v9/clinical-layout.json"))
	for room in plan.rooms:
		for path in room.passages:
			for radius in [.30,.38]: passage(room,path,radius)
	var count := 0; var part_count := 0
	for room in plan.rooms:
		for group in room.groups:
			for ordinal in int(group.count):
				var id: String = group.id+"."+str(ordinal+1)
				var node := world.get_node("RoomProp_"+id.replace(".","_"))
				var at: Array = group.authored_positions[ordinal]
				check(node.position.is_equal_approx(Vector3(room.center[0]+at[0],room.center[1],room.center[2]+at[1])), "native exact placement "+id)
				check(is_equal_approx(node.rotation_degrees.y,float(at[2])), "native exact heading "+id)
				count += 1
				for body in node.get_children():
					if not body is StaticBody3D: continue
					part_count += 1
					var visual: MeshInstance3D = body.get_node("Visual")
					var collision: CollisionShape3D = body.get_node("Collision")
					check(visual.transform == collision.transform and visual.mesh is BoxMesh and collision.shape is BoxShape3D and visual.mesh.size == collision.shape.size, "native physical/visual part "+id+"/"+body.name)
	var table := world.get_node("RoomProp_pale_ward_01_key_console_surgical_table_01_1")
	check(table.has_node("CentralPedestal") and table.has_node("EnamelSegment2") and not table.has_node("Headboard") and not table.has_node("Mattress"), "theatre geometry distinct from ward bed")
	for body in table.get_children():
		if not body is StaticBody3D: continue
		var half: Vector3 = body.get_node("Collision").shape.size*.5
		check(absf(body.position.x)+half.x<=1.20001 and absf(body.position.z)+half.z<=.55001 and body.position.y-half.y>=-.00001 and body.position.y+half.y<=.90001, "table solid stays in approved envelope "+body.name)
	var report := {"passed":failures.is_empty(),"checks":checks,"failures":failures,"engine":Engine.get_version_info(),"candidate":candidate,"candidate_sha256":FileAccess.get_sha256(candidate),"objects":count,"physical_parts":part_count,"capsule_samples":samples,"passages":passages,"scope":"Exact furnished positions and matched physical/visual parts; player.30/NPC.38 radius1.7m capsule lanes sampled every.1m including declared lateral clearance; local floor support. No live enemy AI, continuous campaign or visual acceptance claim."}
	var file := FileAccess.open(report_path,FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")+"\n"); file.close()
	print("CLINICAL_V9 %s checks=%d samples=%d" % ["PASS" if failures.is_empty() else "FAIL",checks,samples])
	world.free(); quit(0 if failures.is_empty() else 1)
