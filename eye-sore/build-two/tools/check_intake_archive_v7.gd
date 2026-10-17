extends SceneTree
## Independent native archive reader: never runs the archived ELF.
var failures: Array[String] = []
var checks := 0
var expected: Dictionary
var output := ""
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok: failures.append(label)
func value(v: Variant) -> Variant:
 if v is Resource: return v.resource_path
 if v is Vector3: return [v.x,v.y,v.z]
 if v is StringName: return String(v)
 if v is Array:
  var a: Array=[]
  for item in v: a.append(value(item))
  return a
 return v
func near(a: Variant, b: Variant) -> bool:
 if a is Dictionary and b is Dictionary:
  if a.size()!=b.size(): return false
  for k in a:
   if not b.has(k) or not near(a[k],b[k]): return false
  return true
 if a is Array and b is Array:
  if a.size()!=b.size(): return false
  for i in a.size():
   if not near(a[i],b[i]): return false
  return true
 if (a is float or a is int) and (b is float or b is int): return abs(float(a)-float(b))<0.001
 return a==b
func descendants(n: Node) -> Array[Node]:
 var result: Array[Node]=[n]
 for child in n.get_children(): result.append_array(descendants(child))
 return result
func _initialize() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--expected="): expected=JSON.parse_string(FileAccess.get_file_as_string(arg.trim_prefix("--expected=")))
  if arg.begins_with("--report="): output=arg.trim_prefix("--report=")
 call_deferred("inspect")
func inspect() -> void:
 var total_props:=0
 var total_parts:=0
 var total_pickups:=0
 for path in expected.scenes:
  var world: Node3D=load(path).instantiate()
  root.add_child(world)
  var spec: Dictionary=expected.scenes[path]
  var pickups:=0
  var props:=0
  var rooms:=0
  for n in world.get_children():
   if n.has_meta("stage_pickup"):
    pickups+=1
    check(spec.pickups.has(String(n.name)),path+" pickup identity "+String(n.name))
    if not spec.pickups.has(String(n.name)): continue
    var rec: Dictionary=spec.pickups[String(n.name)]
    check(near(value(n.position),rec.position),path+" pickup position "+String(n.name))
    var metadata: Dictionary={}
    for k in n.get_meta_list():metadata[String(k)]=value(n.get_meta(k))
    check(near(metadata,rec.metadata),path+" pickup complete metadata "+String(n.name))
   if n.has_meta("stage_room") and not spec.rooms.is_empty():
    rooms+=1
    var id:=String(n.get_meta("stage_room"))
    check(spec.rooms.has(id),path+" room identity "+id)
    if not spec.rooms.has(id):continue
    var rec: Dictionary=spec.rooms[id]
    check(near(value(n.position),rec.position) and near(value(n.get_meta("room_bounds")),rec.bounds),path+" room position/bounds "+id)
    check(String(n.get_meta("room_function"))==rec.function and String(n.get_meta("layout_mode"))==rec.layout_mode,path+" room function "+id)
   if n.has_meta("room_program_object"):
    props+=1
    var id:=String(n.get_meta("room_program_object"))
    check(spec.props.has(id),path+" planned fitting "+id)
    if not spec.props.has(id):continue
    check(String(n.get_meta("prop_type"))==spec.props[id].type,path+" fitting type "+id)
    var count:=0
    for part in descendants(n):
     if part is StaticBody3D:
      count+=1;total_parts+=1
      var visual: MeshInstance3D=part.get_node_or_null("Visual")
      var shape: CollisionShape3D=part.get_node_or_null("Collision")
      check(visual!=null and shape!=null,path+" fitting physical child "+id)
      if visual==null or shape==null:continue
      if visual.mesh is BoxMesh:check(shape.shape is BoxShape3D and near(value(visual.mesh.size),value(shape.shape.size)),path+" box visual/collision dimensions "+id)
      elif visual.mesh is CylinderMesh:check(shape.shape is CylinderShape3D and near(visual.mesh.height,shape.shape.height) and near(visual.mesh.bottom_radius,shape.shape.radius),path+" cylinder visual/collision dimensions "+id)
      else:check(false,path+" unexpected physical mesh "+id)
      check(String(part.get_meta("hit_material")) in ["hard","armor"],path+" physical hit material "+id)
    check(count>0,path+" furnishing physical parts "+id)
  check(pickups==spec.pickups.size() and rooms==spec.rooms.size() and props==spec.props.size(),path+" exact room/pickup/fitting counts")
  if path.ends_with("pale_ward_01.tscn"):
   var door: Node=world.get_node("Door_shortcut_one")
   check(door.has_meta("first_open_normal") and near(value(door.get_meta("first_open_normal")),expected.shortcut.first_open_normal),"Packed Intake shortcut supply-side first-open normal")
   check(value(door.get_meta("requires"))==expected.shortcut.requires,"Packed Intake shortcut brass-key requirement")
  total_pickups+=pickups;total_props+=props
  world.free()
 var profile: Resource=load("res://resources/combat_audio.tres")
 check(profile.cues.size()==57,"Exactly57 native audio cues")
 for key in expected.profile_properties: check(value(profile.get(key))==expected.profile_properties[key],"Preserved profile property "+key)
 for i in 48:
  for key in expected.prior_cues[i]:check(value(profile.cues[i].get(key))==expected.prior_cues[i][key],"Preserved native cue "+str(i)+" "+key)
 for cue in profile.cues:
  var id:=String(cue.identifier)
  check(expected.cues.has(id),"Declared native cue "+id)
  if not expected.cues.has(id):continue
  var declared: Dictionary=expected.cues[id]
  check(String(cue.bus)==declared.bus and near(cue.gain_db,declared.gain_db) and (not declared.has("spatial") or cue.spatial==declared.spatial),"Native cue bus/gain/spatial "+id)
  check(cue.variations.size()>0,"Native cue stream "+id)
  for stream in cue.variations:check(stream is AudioStream and stream.get_length()>0,"Native decoded audio stream "+id)
  if id.begins_with("pickup_"):check(cue.variations.size()==1 and cue.variations[0].resource_path==declared.file,"Native pickup cue file "+id)
 check(total_props==508,"All508 physical typed furnishings")
 var report={"status":"passed" if failures.is_empty() else "failed","checks":checks,"failures":failures,"props":total_props,"physical_parts":total_parts,"pickups":total_pickups,"cue_count":profile.cues.size(),"engine":Engine.get_version_info().string,"scope":"External pinned Godot reader of source or archived --main-pack; no shipped ELF execution or player route claim."}
 FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
 print("INTAKE_ARCHIVE_NATIVE ",JSON.stringify(report))
 quit(0 if failures.is_empty() else 1)
