extends SceneTree
## Independent native capsule/footing probes over actual authored portal lanes.
var level_id:="pale_ward_01"
var report_path:="/tmp/eyesore-v13-geometry.json"
var failures: Array[String]=[]
var checks:=0
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--level="):level_id=arg.trim_prefix("--level=")
		if arg.begins_with("--report="):report_path=arg.trim_prefix("--report=")
	call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label)
func v(a: Array) -> Vector3:return Vector3(a[0],a[1],a[2])
func run() -> void:
	var packed: PackedScene=load("res://scenes/campaign/"+level_id+".tscn")
	var world: Node3D=packed.instantiate();root.add_child(world);world.scan(world)
	world.get_node("Player").set_physics_process(false)
	var route: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://resources/campaign/"+level_id+"-route.json"))
	check(world.get_meta("design_version")==13,"v13 actual scene metadata")
	check(world.objective_profile.level_id==level_id,"native objective profile loaded")
	var exclude: Array[RID]=[]
	for node in world.find_children("*","CollisionObject3D",true,false):
		if node.has_method("reset_door") or node.has_meta("ward_lift") or node.has_meta("lift_target"):exclude.append(node.get_rid())
	await physics_frame;await physics_frame
	var space: PhysicsDirectSpaceState3D=world.get_world_3d().direct_space_state
	var capsule: CapsuleShape3D=world.get_node("Player/CollisionShape3D").shape
	check(is_equal_approx(capsule.radius,.3) and is_equal_approx(capsule.height,1.7),"actual player capsule dimensions")
	var probes:=0
	for portal in route.portals:
		if portal.lift:continue
		var points: Array=portal.traverse_points
		for i in points.size()-1:
			var a:=v(points[i]);var b:=v(points[i+1]);var length:=Vector2(b.x-a.x,b.z-a.z).length()
			var tangent: Vector3=(b-a).normalized().cross(Vector3.UP).normalized()
			for sample in range(ceili(length/.4)+1):
				var t:=float(sample)/maxf(ceili(length/.4),1)
				for offset in [-.65,0,.65]:
					var at: Vector3=a.lerp(b,t)+tangent*offset
					var ray:=PhysicsRayQueryParameters3D.create(at+Vector3.UP*.35,at-Vector3.UP*.35,1,exclude)
					var hit: Dictionary=space.intersect_ray(ray);probes+=1
					check(not hit.is_empty() and hit.normal.y>.95,portal.id+" supported lane "+str(at))
					if hit.is_empty():continue
					var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.transform=Transform3D(Basis.IDENTITY,hit.position+Vector3.UP*.87);query.collision_mask=1;query.exclude=exclude;query.margin=.001
					var overlaps: Array[Dictionary]=space.intersect_shape(query,4)
					var only_step:=not overlaps.is_empty()
					for item in overlaps:
						if not item.collider.has_meta("stage_step"):only_step=false
					if only_step:
						# The actual grounded-step resolver lifts over <=.125m authored
						# risers. Verify headroom at that height; livewalking is separate.
						query.transform.origin.y+=.126
						overlaps=space.intersect_shape(query,4)
					check(overlaps.is_empty(),portal.id+" actual capsule blocked "+str(at)+" by "+str(overlaps.map(func(item: Dictionary)->String:return String(item.collider.get_path()))))
	var file:=FileAccess.open(report_path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failures.is_empty(),"level":level_id,"checks":checks,"lane_samples":probes,"failures":failures,"excluded_operable_bodies":exclude.size(),"scope":"Actual native .3radius/1.7height capsule overlap and flat upward floor probes on all nonlift portalcenter/±.65m lanes, every.4m; intentional gates/traps/liftguards excluded from staticclearance only. Real door/lift interactions and live physical walking require separate Main route fixture."},"  ")+"\n");file.close()
	print("LEVEL_GEOMETRY_V13 ",level_id," passed=",failures.is_empty()," checks=",checks," failures=",failures.size())
	world.free();quit(0 if failures.is_empty() else 1)
