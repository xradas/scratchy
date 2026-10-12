extends SceneTree
var records:Array=[]
func _initialize():call_deferred("run")
func vec(a:Array)->Vector3:return Vector3(a[0],a[1],a[2])
func geometry(body:Node)->Dictionary:
 if body==null:return {}
 var c:CollisionShape3D=body.get_node_or_null("Collision")
 return {"name":String(body.name),"position":[body.position.x,body.position.y,body.position.z],"basis":str(body.global_basis),"shape":str(c.shape.size) if c and c.shape is BoxShape3D else str(c.shape) if c else ""}
func run():
 var prior:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://verification/pickups-rooms-v6/physics/compact/thresholds.json"))
 for level in prior.levels:
  var current:Node3D=load("res://scenes/campaign/"+String(level.id)+".tscn").instantiate();root.add_child(current);current.get_node("Player").set_physics_process(false)
  var old:Node3D=load("/tmp/eyesore-v6-physics-initial/scenes/campaign/"+String(level.id)+".tscn").instantiate();root.add_child(old);old.get_node("Player").set_physics_process(false)
  # Keep worlds physically separate while preserving local probe coordinates.
  old.position=Vector3(1000,0,0)
  await physics_frame;await physics_frame
  for portal in level.portals:
   for direction in ["forward","backward"]:
    var trial:Dictionary=portal[direction]
    if trial.get("reached",false):continue
    var a:=vec(trial.terminal);var b:=vec(trial.goal);b.y=a.y
    var d:=(b-a).normalized()
    var ray:=current.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a,a+d*1.5,1))
    var body:Node=ray.collider if not ray.is_empty() else null
    var old_body:Node=old.get_node_or_null(String(body.name)) if body!=null else null
    var g:=geometry(body);var previous:=geometry(old_body)
    records.append({"id":level.id,"portal":String(portal.from)+":"+String(portal.to),"lane":portal.lane,"direction":direction,"current":g,"baseline":previous,"same_existing_body":g==previous})
  current.free();old.free();await physics_frame
 var f:=FileAccess.open("res://verification/pickups-rooms-v6/physics/compact/blocker-parity.json",FileAccess.WRITE)
 f.store_string(JSON.stringify({"scope":"Short forward native rays from terminal positions of near-declared-edge lane stalls; compare hit body's resolved local transforms and collision size to retained original scene. Other doors need not open because each short ray covers only the immediate stall.","records":records},"  "))
 print("BLOCKER_PARITY ",records.size());quit()
