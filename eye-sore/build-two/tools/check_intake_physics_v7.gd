extends SceneTree
## Isolated native physics: initial placements and fully-open access doors declared.
## Actual production CharacterBody and input; no movement repair or runtime edits.
var world: Node3D
var actor: CharacterBody3D
var route: Dictionary
var failures: Array[String] = []
var checks := 0
var ray_count := 0
var shape_count := 0
var report_path := "res://verification/intake-v7/physics/native.json"
var rate_only := false
var walks: Array = []
var supports: Array = []
var blocked_samples: Array = []
var opened: Array = []
var ticks_total := 0
func _initialize() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--report="): report_path = arg.trim_prefix("--report=")
  elif arg == "--rate-only": rate_only = true
 call_deferred("run")
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok: failures.append(label); push_error("INTAKE_PHYSICS: " + label)
func vec(a: Array) -> Vector3: return Vector3(a[0],a[1],a[2])
func xyz(p: Vector3) -> Array: return [p.x,p.y,p.z]
func ticks(n: int) -> void:
 for i in n: await physics_frame
func key(code: int, down: bool) -> void:
 var event := InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=down; Input.parse_input_event(event)
func stop() -> void:
 for code in [KEY_W,KEY_A,KEY_S,KEY_D]: key(code,false)
func ray(a: Vector3,b: Vector3) -> Dictionary:
 ray_count += 1
 return world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,1))
func shape(point: Vector3, radius := .3, height := 1.7) -> Array:
 var capsule := CapsuleShape3D.new(); capsule.radius=radius; capsule.height=height
 var q := PhysicsShapeQueryParameters3D.new(); q.shape=capsule; q.transform=Transform3D(Basis.IDENTITY,point); q.collision_mask=1; q.margin=.001
 shape_count += 1
 return world.get_world_3d().direct_space_state.intersect_shape(q,128)
func relative(n: Node) -> String: return String(world.get_path_to(n))
func prop(n: Node) -> bool:
 var p := n
 while p != null and p != world:
  if String(p.name).begins_with("RoomProp_") or String(p.name).begins_with("IntakePresentation_"): return true
  p=p.get_parent()
 return false
func corridor(portal: Dictionary, index: int) -> void:
 var a := vec(portal.start); var b := vec(portal.end)
 var normal := b-a; normal.y=0; normal=normal.normalized()
 var cross := Vector3(-normal.z,0,normal.x)
 var first := a-normal*1.0; var last := b+normal*1.0
 var length := Vector2(first.x-last.x,first.z-last.z).length()
 var width := float(portal.width)
 var missing: Array = []; var heights: Array = []; var overhead_contacts: Array = []
 var longitudinal := int(ceil(length/.10))
 var lateral := int(ceil((width-.64)/.12))
 for i in range(longitudinal+1):
  var p := first.lerp(last,float(i)/longitudinal)
  for j in range(lateral+1):
   var offset := -(width/2-.32)+(width-.64)*float(j)/lateral
   var point := p+cross*offset
   var hit := ray(point+Vector3(0,1.0,0),point-Vector3(0,1.0,0))
   if hit.is_empty(): missing.append(xyz(point)); continue
   if absf(float(hit.position.y)-point.y)>.4: heights.append({"position":xyz(point),"floor":xyz(hit.position),"body":relative(hit.collider)})
   # Exact capsule at surveyed floor; checks structural collision above feet,
   # excluding support itself via slight floor clearance (.02 m).
   if j==int(lateral/2) or j==0 or j==lateral:
    var center := Vector3(point.x,float(hit.position.y)+.87,point.z)
    for contact in shape(center):
     if String(contact.collider.get_path()).contains("IntakePresentation_"):
      overhead_contacts.append({"point":xyz(center),"body":relative(contact.collider)})
 check(missing.is_empty(),"link%d full-width floor has no gaps"%index)
 check(heights.is_empty(),"link%d floor within .4m authored grade"%index)
 check(overhead_contacts.is_empty(),"link%d actor capsule clear of overhead additions"%index)
 supports.append({"index":index,"from":portal.from,"to":portal.to,"longitudinal_samples":longitudinal+1,"lateral_samples":lateral+1,"rays":(longitudinal+1)*(lateral+1),"missing":missing,"grade_deviations":heights,"presentation_capsule_contacts":overhead_contacts})
func walk(portal: Dictionary,index: int,reverse: bool,code: int) -> void:
 var a := vec(portal.start); var b := vec(portal.end)
 var direction := b-a; direction.y=0; direction=direction.normalized()
 var start := a-direction*1.0
 var end := b+direction*1.0
 if reverse: var swap:=start; start=end; end=swap
 actor.set_physics_process(false); stop(); actor.global_position=start+Vector3(0,.87,0); actor.velocity=Vector3.ZERO
 var motion := end-start; motion.y=0
 var yaw := atan2(-motion.x,-motion.z)
 if code==KEY_S: yaw+=PI
 elif code==KEY_A: yaw-=PI/2
 elif code==KEY_D: yaw+=PI/2
 actor.rotation.y=yaw
 await ticks(3); actor.set_physics_process(true); await ticks(4)
 var initial := actor.global_position; var previous := initial; var distance := 0.0
 var samples: Array = []; var unsupported: Array = [];var contacts: Dictionary={}; var min_y := actor.global_position.y; var elapsed := 0
 var limit := int(ceil(Vector2(start.x-end.x,start.z-end.z).length()/8*60))+180
 key(code,true)
 while elapsed<limit and Vector2(actor.global_position.x-end.x,actor.global_position.z-end.z).length()>.70:
  await physics_frame; elapsed+=1; ticks_total+=1
  for c in actor.get_slide_collision_count():
   var object:=actor.get_slide_collision(c).get_collider()
   if object is Node: contacts[relative(object)]=true
  var p := actor.global_position; distance+=p.distance_to(previous); previous=p; min_y=minf(min_y,p.y)
  var hit := ray(p-Vector3(0,.81,0),p-Vector3(0,2.0,0))
  if hit.is_empty(): unsupported.append({"tick":elapsed,"position":xyz(p)})
  if elapsed%12==0: samples.append({"tick":elapsed,"position":xyz(p),"grounded":actor.is_on_floor()})
  if p.y < minf(start.y,end.y)-5.0: break
 stop(); await ticks(16)
 var error := Vector2(actor.global_position.x-end.x,actor.global_position.z-end.z).length()
 var reached := error<.60
 check(reached,"link%d %s %s reached"%[index,"reverse" if reverse else "forward",OS.get_keycode_string(code)])
 check(actor.is_on_floor(),"link%d terminal grounded"%index)
 check(unsupported.is_empty(),"link%d traversed without unsupported feet"%index)
 walks.append({"link":index,"from":portal.from,"to":portal.to,"reverse":reverse,"key":OS.get_keycode_string(code),"initial":xyz(initial),"goal_floor":xyz(end),"terminal":xyz(actor.global_position),"goal_xz_error":error,"reached":reached,"grounded":actor.is_on_floor(),"ticks":elapsed,"physics_seconds":float(elapsed)/60,"path_distance":distance,"minimum_y":min_y,"unsupported":unsupported,"slide_colliders":contacts.keys(),"trace":samples})
 actor.set_physics_process(false)
func inspect_parts() -> Dictionary:
 var part_records: Array = []; var mismatches: Array = []; var shots: Array = []; var presentation_count:=0; var prop_count:=0
 for group in world.get_children():
  if not (String(group.name).begins_with("RoomProp_") or String(group.name).begins_with("IntakePresentation_")): continue
  for body in group.get_children():
   if not body is StaticBody3D: continue
   var visual: MeshInstance3D=body.get_node_or_null("Visual"); var collision: CollisionShape3D=body.get_node_or_null("Collision")
   var matched := visual!=null and collision!=null
   if matched:
    matched=visual.transform==collision.transform
    if visual.mesh is BoxMesh and collision.shape is BoxShape3D: matched=matched and visual.mesh.size.is_equal_approx(collision.shape.size)
    elif visual.mesh is CylinderMesh and collision.shape is CylinderShape3D: matched=matched and is_equal_approx(visual.mesh.height,collision.shape.height) and is_equal_approx(visual.mesh.top_radius,collision.shape.radius)
    else: matched=false
   if not matched: mismatches.append(relative(body))
   var presentation:=String(group.name).begins_with("IntakePresentation_")
   if presentation: presentation_count+=1
   else: prop_count+=1
   var minimum_y: float=body.global_position.y
   var half:=Vector3.ZERO
   if collision!=null and collision.shape is BoxShape3D: half=collision.shape.size/2
   elif collision!=null and collision.shape is CylinderShape3D: half=Vector3(collision.shape.radius,collision.shape.height/2,collision.shape.radius)
   minimum_y-=half.y
   part_records.append({"body":relative(body),"presentation":presentation,"minimum_y":minimum_y,"center":xyz(body.global_position),"half_extent":xyz(half),"matching":matched})
   if presentation:
    # Direct unobstructed local ray against each exact physical body verifies
    # native shot-query participation, not gameplay weapon damage.
    var q:=PhysicsRayQueryParameters3D.create(body.global_position+Vector3(0,half.y+.03,0),body.global_position,1)
    ray_count+=1
    var hit:=world.get_world_3d().direct_space_state.intersect_ray(q)
    var exact: bool=not hit.is_empty() and hit.collider==body
    shots.append({"expected":relative(body),"hit":relative(hit.collider) if not hit.is_empty() else "","matched":exact,"material":String(body.get_meta("hit_material",""))})
 check(mismatches.is_empty(),"all physical prop/presentation dimensions match visible mesh")
 check(presentation_count==117,"117 overhead/presentation physical parts")
 var clearances: Array = []
 for entry in part_records:
  if not entry.presentation: continue
  var center:=vec(entry.center); var bottom:=Vector3(center.x,float(entry.minimum_y)-.02,center.z)
  var floor_query:=PhysicsRayQueryParameters3D.create(bottom,bottom-Vector3(0,15,0),1)
  var group: Node=world.get_node(String(entry.body)).get_parent()
  var excluded: Array[RID]=[]
  for member in group.get_children():
   if member is CollisionObject3D: excluded.append(member.get_rid())
  floor_query.exclude=excluded;ray_count+=1
  var below:=world.get_world_3d().direct_space_state.intersect_ray(floor_query)
  var distance:=float(entry.minimum_y)-float(below.position.y) if not below.is_empty() else -1.0
  clearances.append({"body":entry.body,"clearance_to_surface_below":distance,"below_body":relative(below.collider) if not below.is_empty() else "","excluded_same_overhead_group":String(group.name)})
  check(distance>=1.70,"added overhead body leaves actor height: "+String(entry.body))
 var missing_shots:=shots.filter(func(s):return not s.matched)
 check(missing_shots.is_empty(),"all 117 added bodies participate in shot ray blocking")
 return {"furnishing_parts":prop_count,"presentation_parts":presentation_count,"mismatches":mismatches,"parts":part_records,"direct_shot_rays":shots,"vertical_clearances":clearances}
func inspect_spawns() -> Array:
 var result: Array = []; var candidates: Array = []
 candidates.append(world.get_node("PlayerStart"))
 for n in world.get_node("EnemySpawns").get_children(): candidates.append(n)
 for n in world.get_children():
  if n.has_meta("stage_pickup"): candidates.append(n)
 for n in candidates:
  var point: Vector3=n.global_position
  var hit:=ray(point+Vector3(0,.2,0),point-Vector3(0,8,0))
  var grounded := not hit.is_empty()
  var contacts: Array = []
  if grounded:
   var center:=Vector3(point.x,float(hit.position.y)+.87,point.z)
   for contact in shape(center):
    if prop(contact.collider):contacts.append(relative(contact.collider))
  var good:=grounded and contacts.is_empty()
  check(good,"spawn/pickup support and prop clearance: "+String(n.name))
  result.append({"name":String(n.name),"position":xyz(point),"supported":grounded,"floor":xyz(hit.position) if grounded else null,"prop_contacts":contacts,"kind":String(n.get_meta("stage_pickup","spawn"))})
 return result
func inspect_old_pocket() -> Dictionary:
 var missing: Array=[]; var wrong_height: Array=[]
 var count:=0
 # Former sump was x6..10,z-84.5..-79.5; include a2m perimeter
 # and every former tread seam on a0.1m grid.
 for ix in range(81):
  for iz in range(101):
   var p:=Vector3(4.0+float(ix)*.1,-.7,-87.0+float(iz)*.1)
   var hit:=ray(p,p-Vector3(0,3,0));count+=1
   if hit.is_empty(): missing.append(xyz(p))
   elif absf(hit.position.y+1.0)>.02:wrong_height.append({"position":xyz(p),"height":hit.position.y,"body":relative(hit.collider)})
 check(missing.is_empty(),"former triage pocket fullfootprint support")
 check(wrong_height.is_empty(),"former triage pocket flush atroomfloor-1m")
 return {"rays":count,"step":.1,"bounds_xz":[4,12,-87,-77],"query_origin_y":-.7,"query_end_y":-3.7,"scope":"Underlying structural floor plane, including beneath intentionally retained raised rim and stairs. Low-origin ray confirms bottom support only; not free passage through raised stairs. Separate real walks cover usable corridors and both below-rim pocket diagonals.","missing":missing,"nonflush":wrong_height}
func run() -> void:
 route=JSON.parse_string(FileAccess.get_file_as_string("res://resources/campaign/pale_ward_01-route.json"))
 world=load("res://scenes/campaign/pale_ward_01.tscn").instantiate(); root.add_child(world)
 world.set_physics_process(false); world.scan(world); actor=world.get_node("Player"); actor.set_physics_process(false)
 # Door collision geometry stays enabled. Only actual production activate()
 # moves each door to its visible upper position with declared all-access flags.
 var flags: Dictionary={}
 for portal in route.portals:
  for need in portal.requires:flags[String(need)]=true
 for n in world.get_children():
  if n.has_method("activate") and (n.has_meta("stage_door") or n.has_meta("trap_entry") or n.has_meta("trap_shutter")):
   n.activate(flags); opened.append(String(n.name))
 await ticks(120)
 var parts: Dictionary={}; var spawns: Array=[];var pocket: Dictionary={}
 var indices: Array=[0,1,2,3,4,5,6,14,15]
 if rate_only:indices=[0,1,2,6]
 else:
  parts=inspect_parts(); spawns=inspect_spawns(); pocket=inspect_old_pocket()
  for i in indices:corridor(route.portals[i],i)
 for i in indices:
  for reverse in [false,true]:
   var code:=KEY_W if not reverse else KEY_S
   await walk(route.portals[i],i,reverse,code)
 # All four physical keys also climb the steepest modified link both directions.
 for code in [KEY_A,KEY_D]:
  for reverse in [false,true]:await walk(route.portals[2],2,reverse,code)
 if not rate_only:
  var starts: Array=[Vector3(5.8,-1,-82.2),Vector3(5.8,-1,-79.8)]
  var ends: Array=[Vector3(9.6,-1,-79.8),Vector3(9.6,-1,-82.2)]
  for i in range(2):
   var crossing:={"from":"former_sump_approach","to":"former_sump_far_edge","start":xyz(starts[i]),"end":xyz(ends[i])}
   for reverse in [false,true]:await walk(crossing,90+i,reverse,KEY_W)
 var report:={"passed":failures.is_empty(),"checks":checks,"failures":failures,"scene_sha256":FileAccess.get_sha256("res://scenes/campaign/pale_ward_01.tscn"),"fixture_sha256":FileAccess.get_sha256("res://tools/check_intake_physics_v7.gd"),"engine":Engine.get_version_info(),"display_server":DisplayServer.get_name(),"rendering_method":RenderingServer.get_current_rendering_method(),"physics_rate":Engine.physics_ticks_per_second,"reported_average_fps":Engine.get_frames_per_second(),"command_line":OS.get_cmdline_args(),"door_fixture":{"access_flags":flags,"activated_bodies":opened,"note":"All access doors and trap shutters activated through their real method before traversals; isolated geometry probes, no encounter or progression proof."},"scope":"Native production CharacterBody input along nine first-section links both ways; .1m longitudinal/.12m full-width floor survey including mouths; independent initial placements, no recovery. Prop/presentation physical geometry and initial pickup/NPC support.","runtime_polygon_geometry":"Production world.scan(world) expands metadata polygons before native queries, exactly as setup does, without injecting combat controller.","limitations":["No live enemies instantiated: spawn markers surveyed with player-size capsule, not enemy navigation proof.","Actor is independently placed at each declared start; not continuous human route or combat proof.","Near-wall capsule center margin .32m leaves actual capsule inside corridor.","No audio/visual acceptance claim."],"ray_queries":ray_count,"shape_queries":shape_count,"physics_motion_ticks":ticks_total,"floor_surveys":supports,"former_pocket":pocket,"walks":walks,"inventory":parts,"spawn_pickup_checks":spawns}
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(report_path).get_base_dir())
 var file:=FileAccess.open(report_path,FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
 print("INTAKE_PHYSICS_COMPLETE passed=",failures.is_empty()," checks=",checks," rays=",ray_count," shapes=",shape_count," walks=",walks.size())
 world.free();quit(0 if failures.is_empty() else 1)
