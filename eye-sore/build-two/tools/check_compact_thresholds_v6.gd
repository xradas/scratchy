extends SceneTree
var results: Array[Dictionary]=[]
var failures: Array[Dictionary]=[]
var only_diagonal:=false
var usable_lanes:=false
var report_name:="thresholds"
var prior_failed:Dictionary={}
var capsule:=CapsuleShape3D.new()
func _initialize()->void:
 only_diagonal="--only-diagonal" in OS.get_cmdline_user_args()
 usable_lanes="--usable-lanes" in OS.get_cmdline_user_args()
 report_name="angled-final" if only_diagonal else "usable-lanes" if usable_lanes else "thresholds"
 if usable_lanes:
  var prior:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://verification/pickups-rooms-v6/physics/compact/thresholds.json"))
  for failure in prior.failures:
   if failure.reason=="actual_walk_failed":prior_failed[String(failure.id)+":"+String(failure.portal)]=true
 capsule.radius=.3;capsule.height=1.7;call_deferred("run")
func vec(a:Array)->Vector3:return Vector3(a[0],a[1],a[2])
func xyz(p:Vector3)->Array:return [p.x,p.y,p.z]
func key(code:int,down:bool)->void:
 var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=down;Input.parse_input_event(e)
func floor_at(w:Node3D,p:Vector3,reach:=3.)->Dictionary:
 return w.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3(0,.6,0),p-Vector3(0,reach,0),1))
func prop_contacts(w:Node3D,p:Vector3,shape:Shape3D)->Array:
 var q:=PhysicsShapeQueryParameters3D.new();q.shape=shape;q.transform=Transform3D(Basis.IDENTITY,p);q.collision_mask=1;q.margin=.001
 var found:Array=[]
 for hit in w.get_world_3d().direct_space_state.intersect_shape(q,128):
  var n:Node=hit.collider
  while n!=null:
   if String(n.name).begins_with("RoomProp_"):
    found.append(String(hit.collider.get_path()));break
   n=n.get_parent()
 return found
func walk(w:Node3D,actor:CharacterBody3D,a:Vector3,b:Vector3,code:int)->Dictionary:
 actor.set_physics_process(false)
 var f:=floor_at(w,a)
 if f.is_empty():return {"reached":false,"unsupported_start":xyz(a)}
 a.y=float(f.position.y)+.87
 actor.position=a;actor.velocity=Vector3.ZERO
 var d:=b-a;d.y=0
 var yaw:=atan2(-d.x,-d.z)
 if code==KEY_S:yaw+=PI
 elif code==KEY_A:yaw-=PI/2
 elif code==KEY_D:yaw+=PI/2
 actor.rotation.y=yaw
 await physics_frame;await physics_frame;actor.set_physics_process(true)
 for n in 3:await physics_frame
 var initial:=actor.position;var min_y:=initial.y;var trace:Array=[];var elapsed:=0
 key(code,true)
 var max_ticks:=int(ceil(Vector2(d.x,d.z).length()/8*60))+90
 while elapsed<max_ticks and Vector2(actor.position.x-b.x,actor.position.z-b.z).length()>.65:
  await physics_frame;elapsed+=1;min_y=minf(min_y,actor.position.y)
  if elapsed%15==0:trace.append({"position":xyz(actor.position),"grounded":actor.is_on_floor()})
  if actor.position.y<minf(a.y,b.y)-4:break
 key(code,false)
 for n in 16:await physics_frame
 var contact:Array=[]
 for i in actor.get_slide_collision_count():
  var body:Node=actor.get_slide_collision(i).get_collider()
  if body:contact.append(String(body.get_path()))
 return {"key":OS.get_keycode_string(code),"initial":xyz(initial),"goal":xyz(b),"terminal":xyz(actor.position),"ticks":elapsed,"reached":Vector2(actor.position.x-b.x,actor.position.z-b.z).length()<.65,"grounded":actor.is_on_floor(),"min_y":min_y,"terminal_contacts":contact,"trace":trace}
func save()->void:
 var f:=FileAccess.open("res://verification/pickups-rooms-v6/physics/compact/"+report_name+".json",FileAccess.WRITE)
 f.store_string(JSON.stringify({"scope":"Actual loaded compact9scene footprints and CharacterBody W/A/S/D bidirectional threshold traversal. Explicit initial placements, doors activated with required flags=true and allowed to finish, no enemy setup. Fixed60. No runtime or scene edits.","failures":failures,"levels":results},"  "))
func run()->void:
 var sphere:=SphereShape3D.new();sphere.radius=.12
 for theme in ["pale_ward","ash_citadel","occupied_line"]:
  for number in range(1,4):
   var id:String=String(theme)+"_%02d"%number
   if only_diagonal and id!="ash_citadel_02":continue
   var path:="res://scenes/campaign/"+id+".tscn"
   var w:Node3D=load(path).instantiate();root.add_child(w);w.set_physics_process(false)
   var actor:CharacterBody3D=w.get_node("Player");actor.set_physics_process(false)
   var route:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://resources/campaign/"+id+"-route.json"))
   var old:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("/tmp/eyesore-v6-physics-initial/resources/campaign/"+id+"-route.json"))
   var changed:Array=[]
   for room in route.rooms:
    if route.rooms[room].size!=old.rooms[room].size:changed.append(room)
   for child in w.get_children():
    if child.has_method("activate") and child is AnimatableBody3D and String(child.name).begins_with("Door_"):
     var flags:Dictionary={}
     for requirement in child.get_meta("requires",[]):flags[String(requirement)]=true
     child.activate(flags)
   for n in 130:await physics_frame
   var placements:Array=[]
   for child in w.get_children():
    if only_diagonal or usable_lanes:continue
    if not child.has_meta("stage_pickup"):continue
    var p:Vector3=child.global_position;var f:=floor_at(w,p,6.)
    var hits:=prop_contacts(w,p,sphere)
    placements.append({"type":"pickup","node":String(child.name),"position":xyz(p),"floor":xyz(f.position) if not f.is_empty() else [],"prop_contacts":hits})
    if f.is_empty():failures.append({"id":id,"pickup":String(child.name),"reason":"no_floor_below"})
    if not hits.is_empty():failures.append({"id":id,"pickup":String(child.name),"reason":"prop_contact","contacts":hits})
   for spawn in w.get_node("EnemySpawns").get_children():
    if only_diagonal or usable_lanes:continue
    var p:Vector3=spawn.global_position;var f:=floor_at(w,p,3.)
    var hits:=prop_contacts(w,p,capsule)
    placements.append({"type":"spawn","node":String(spawn.name),"position":xyz(p),"floor":xyz(f.position) if not f.is_empty() else [],"prop_contacts":hits})
    if f.is_empty() or not hits.is_empty():failures.append({"id":id,"spawn":String(spawn.name),"reason":"no_support_or_prop_overlap","contacts":hits})
   var portals:Array=[];var rays:=0;var gaps:Array=[]
   for portal in route.portals:
    if only_diagonal and not bool(portal.get("diagonal",false)):continue
    if usable_lanes and not prior_failed.has(id+":"+String(portal.from)+":"+String(portal.to)):continue
    if bool(portal.get("lift",false)) or (not portal.from in changed and not portal.to in changed and not bool(portal.get("diagonal",false))):continue
    var a:=vec(portal.start);var b:=vec(portal.end);var normal:=b-a;normal.y=0;normal=normal.normalized();var cross:=Vector3(-normal.z,0,normal.x)
    var extent:float=.45 if usable_lanes else float(portal.width)/2-.34
    var start:=a-normal*1.5;var end:=b+normal*1.5
    for lane in [-extent,0.,extent]:
     if usable_lanes and lane==0.:continue
     var aa:Vector3=start+cross*lane;var bb:Vector3=end+cross*lane
     for sample in range(int(ceil(aa.distance_to(bb)/.18))+1):
      var p:Vector3=aa.lerp(bb,minf(1,float(sample)*.18/aa.distance_to(bb)))
      for foot in [Vector3.ZERO,cross*.29,-cross*.29,normal*.29,-normal*.29]:
       rays+=1;var f:=floor_at(w,p+foot)
       if f.is_empty() or float(f.normal.y)<.85:gaps.append({"portal":String(portal.from)+":"+String(portal.to),"position":xyz(p+foot),"collider":String(f.collider.name) if not f.is_empty() else ""})
     var forward:Dictionary=await walk(w,actor,aa,bb,KEY_W if lane==0. else KEY_A)
     var backward:Dictionary=await walk(w,actor,bb,aa,KEY_S if lane==0. else KEY_D)
     portals.append({"from":portal.from,"to":portal.to,"diagonal":portal.get("diagonal",false),"lane":lane,"forward":forward,"backward":backward})
     if not forward.get("reached",false) or not backward.get("reached",false):failures.append({"id":id,"portal":String(portal.from)+":"+String(portal.to),"lane":lane,"reason":"actual_walk_failed"})
   if not gaps.is_empty():failures.append({"id":id,"reason":"floor_footprint_gaps","samples":gaps})
   var join_geometry:Array=[];var exact_replay:Array=[]
   if only_diagonal:
    for body_name in ["Link_11_Floor","Link_11_MouthFloorFrom","Link_11_MouthFloorTo"]:
     var body:Node3D=w.get_node(body_name)
     var visual:MeshInstance3D=body.get_node("Visual");var collision:CollisionShape3D=body.get_node("Collision")
     join_geometry.append({"body":body_name,"position":xyz(body.position),"box_size":xyz(collision.shape.size),"matching_visible_collision":visual.mesh.size==collision.shape.size and visual.transform==collision.transform,"rotation_y":body.rotation.y})
    var prior:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://verification/pickups-rooms-v6/physics/compact/thresholds.json"))
    for failure in prior.failures:
     if failure.reason!="floor_footprint_gaps":continue
     for sample in failure.samples:
      var f:=floor_at(w,vec(sample.position))
      exact_replay.append({"position":sample.position,"supported":not f.is_empty(),"collider":String(f.collider.name) if not f.is_empty() else "","floor_y":float(f.position.y) if not f.is_empty() else null,"normal":xyz(f.normal) if not f.is_empty() else []})
   results.append({"id":id,"scene_sha256":FileAccess.get_sha256(path),"changed_rooms":changed,"footprint_rays":rays,"floor_gaps":gaps,"portals":portals,"placements":placements,"join_geometry":join_geometry,"exact_prior_gap_replay":exact_replay})
   save();print("COMPACT_THRESHOLDS ",id," portals=",portals.size()," rays=",rays," gaps=",gaps.size()," cumulative_failures=",failures.size())
   w.free();await physics_frame
 save();quit(0 if failures.is_empty() else 1)
