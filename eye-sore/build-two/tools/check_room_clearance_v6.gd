extends SceneTree
## Independent resolved native furnishing contacts; no authored reservation data.
var records: Array[Dictionary] = []
var candidate_contacts: Array[Dictionary] = []
var initial_snapshot := false
var capsule := CapsuleShape3D.new()
func _initialize() -> void:
 initial_snapshot="--initial-snapshot" in OS.get_cmdline_user_args()
 capsule.radius=.3; capsule.height=1.7
 call_deferred("run")
func v(a: Array) -> Vector3:return Vector3(a[0],a[1],a[2])
func xyz(p: Vector3) -> Array:return [p.x,p.y,p.z]
func prop_parent(body: Node) -> Node:
 var n:=body
 while n != null:
  if String(n.name).begins_with("RoomProp_"):return n
  n=n.get_parent()
 return null
func contacts(world: Node3D, point: Vector3) -> Array:
 var query:=PhysicsShapeQueryParameters3D.new()
 query.shape=capsule;query.transform=Transform3D(Basis.IDENTITY,point);query.collision_mask=1;query.margin=.001
 var result: Array=[]
 for hit in world.get_world_3d().direct_space_state.intersect_shape(query,128):
  var prop:=prop_parent(hit.collider)
  if prop != null:result.append({"body":String(hit.collider.get_path()),"prop":String(prop.name),"type":String(prop.get_meta("prop_type","")),"material":String(hit.collider.get_meta("hit_material",""))})
 return result
func lane(world: Node3D, a: Vector3,b: Vector3,label: String) -> void:
 var last:=""
 for i in range(int(ceil(a.distance_to(b)/.15))+1):
  var p:=a.lerp(b,minf(1,float(i)*.15/maxf(.001,a.distance_to(b))))+Vector3(0,.87,0)
  var hits:=contacts(world,p)
  if not hits.is_empty():
   var key:=str(hits)
   if key!=last:candidate_contacts.append({"scene":world.scene_file_path,"lane":label,"position":xyz(p),"contacts":hits})
   last=key
  else:last=""
func inventory(world: Node3D) -> Dictionary:
 var bodies:=0;var mismatch: Array=[];var samples: Array=[];var seen: Dictionary={}
 for prop in world.get_children():
  if not String(prop.name).begins_with("RoomProp_"):continue
  for body in prop.get_children():
   if not body is StaticBody3D:continue
   bodies+=1
   var visual: MeshInstance3D=body.get_node("Visual")
   var collision: CollisionShape3D=body.get_node("Collision")
   var matches:=visual.transform==collision.transform
   if visual.mesh is BoxMesh and collision.shape is BoxShape3D:matches=matches and visual.mesh.size==collision.shape.size
   elif visual.mesh is CylinderMesh and collision.shape is CylinderShape3D:matches=matches and is_equal_approx(visual.mesh.height,collision.shape.height) and is_equal_approx(visual.mesh.top_radius,collision.shape.radius)
   else:matches=false
   if not matches:mismatch.append(String(body.get_path()))
   var type:=String(prop.get_meta("prop_type",""))
   if seen.has(type):continue
   seen[type]=true
   var center: Vector3=body.global_position
   var extent: float=collision.shape.size.z/2 if collision.shape is BoxShape3D else collision.shape.radius
   var start: Vector3=body.to_global(collision.position+Vector3(0,0,extent+.04))
   var hit:=world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start,center,1))
   samples.append({"type":type,"expected_body":String(body.get_path()),"ray_body":String(hit.collider.get_path()) if not hit.is_empty() else "","material":String(hit.collider.get_meta("hit_material","")) if not hit.is_empty() else "","matching_shape":matches,"ray_start":xyz(start),"ray_end":xyz(center)})
 return {"parts":bodies,"mismatches":mismatch,"representative_rays":samples}
func run() -> void:
 for theme in ["pale_ward","ash_citadel","occupied_line"]:
  for n in range(1,4):
   var id: String=String(theme)+"_%02d"%n
   var scene: String="res://scenes/campaign/"+id+".tscn"
   var loaded_scene: String=("/tmp/eyesore-v6-physics-initial/scenes/campaign/"+id+".tscn") if initial_snapshot else scene
   var world: Node3D=load(loaded_scene).instantiate();root.add_child(world)
   world.set_physics_process(false)
   await physics_frame;await physics_frame
   var route: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://resources/campaign/"+id+"-route.json"))
   var before:=candidate_contacts.size()
   for button in route.buttons:
    var control: Node3D=world.get_node_or_null("Button_"+String(button.id))
    if control==null:continue
    var room: Dictionary=route.rooms[String(button.room)]
    var start:=control.global_position;start.y=float(room.center[1])
    var center:=v(room.center)
    for side in [-1,1]:lane(world,start,Vector3(center.x+side*4.3,center.y,start.z),"control-to-inner-ring:"+String(button.id)+":"+str(side))
   for arena in ["arena_one","arena_two","final_arena"]:
    var room: Dictionary=route.rooms[arena];var center:=v(room.center)
    var ring_z: float=center.z-float(room.size[2])/2+1.3
    for side in [-1,1]:
     var inner:=Vector3(center.x+side*4.3,center.y,ring_z)
     lane(world,Vector3(center.x+side*(float(room.size[0])/2-7),center.y,ring_z),inner,"south-ring-lateral:"+arena+":"+str(side))
     lane(world,inner,Vector3(inner.x,center.y,center.z+10),"inner-ring-longitudinal:"+arena+":"+str(side))
   for portal in route.portals:
    var normal:=v(portal.end)-v(portal.start);normal.y=0;normal=normal.normalized()
    var cross:=Vector3(-normal.z,0,normal.x)
    for key in ["start","end"]:
     var mouth:=v(portal[key]);var inside:=mouth+normal*(-2 if key=="start" else 2)
     for offset in [-1.2,0.,1.2]:lane(world,mouth+cross*offset,inside+cross*offset,"portal-mouth:"+String(portal.from)+":"+String(portal.to)+":"+key)
   records.append({"id":id,"scene_sha256":FileAccess.get_sha256(loaded_scene),"inventory":inventory(world),"candidate_contacts":candidate_contacts.size()-before})
   world.free();await physics_frame
 var receipt:={"scope":"Native prop-only capsule queries at control-to-inner-ring straight connectors and portal mouths; contacts are review candidates, not proof of inaccessible route. Representative real world rays and resolved mesh/shape parity. No AI/game state modifications.","levels":records,"contacts":candidate_contacts}
 var f:=FileAccess.open("res://verification/pickups-rooms-v6/physics/room-clearance-"+("initial-snapshot" if initial_snapshot else "candidate")+".json",FileAccess.WRITE);f.store_string(JSON.stringify(receipt,"  "))
 print("ROOM_CLEARANCE_CANDIDATE ",candidate_contacts.size());quit()
