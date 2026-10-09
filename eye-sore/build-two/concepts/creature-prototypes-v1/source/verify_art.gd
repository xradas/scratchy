extends SceneTree
const Rig=preload("res://creature_rig.gd")
var failures:Array[String]=[]
func _initialize():
 call_deferred("run")
func expect(value:bool,label:String):
 if not value: failures.append(label)
func count_mesh(node:Node) -> Dictionary:
 var totals={"meshes":0,"vertices":0,"triangles":0,"armor":0,"flesh":0}
 for child in node.get_children():
  if child is MeshInstance3D:
   totals.meshes+=1
   var cue=str(child.get_meta("hit_material",""));expect(cue in ["armor","flesh"],"tag "+str(child.get_path()))
   totals[cue]+=1
   for surface in range(child.mesh.get_surface_count()):
    var a=child.mesh.surface_get_arrays(surface);totals.vertices+=a[Mesh.ARRAY_VERTEX].size();totals.triangles+=(a[Mesh.ARRAY_INDEX].size() if a[Mesh.ARRAY_INDEX]!=null else a[Mesh.ARRAY_VERTEX].size())/3
  var sub=count_mesh(child)
  for key in totals: totals[key]+=sub[key]
 return totals
func run():
 var report={"floor_plane":-.85,"forward":[0,0,-1],"kinds":{}}
 for kind in [&"unsealed",&"vessel"]:
  var rig=Rig.new();root.add_child(rig);rig.configure(kind)
  var metrics=count_mesh(rig);var state_data={}
  for state in [&"chase",&"windup",&"recovery",&"pain",&"dead"]:
   for t in [0.,.1,.4,2.,20.]:
    rig.present(state,t,.45,.6,.18)
    var b=rig.bounds_now();expect(b.position.is_finite() and b.size.is_finite(),str(kind)+" finite "+str(state))
    expect(b.position.y>=-.851,str(kind)+" clipping "+str(state)+" "+str(t)+" "+str(b.position.y))
    expect(rig.get_projectile_origin().is_finite(),"muzzle finite")
   state_data[str(state)]={"min":[rig.bounds_now().position.x,rig.bounds_now().position.y,rig.bounds_now().position.z],"max":[rig.bounds_now().end.x,rig.bounds_now().end.y,rig.bounds_now().end.z]}
  rig.present(&"dead",2.);var corpse=rig.body.transform;rig.present(&"dead",20.);expect(corpse.is_equal_approx(rig.body.transform),"persistent corpse "+str(kind))
  rig.present(&"chase",.2);expect(rig.bounds_now().end.y>.5,"reset dead pose "+str(kind))
  var marker=rig.get_projectile_origin();rig.position=Vector3(4,2,1);expect(rig.get_projectile_origin().is_equal_approx(marker+Vector3(4,2,1)),"world muzzle "+str(kind))
  report.kinds[str(kind)]={"geometry":metrics,"states":state_data}
  root.remove_child(rig);rig.free()
 report["passed"]=failures.is_empty();report["failures"]=failures
 var f=FileAccess.open("res://../verification.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  ")+"\n");f.close()
 print(JSON.stringify(report))
 quit(0 if failures.is_empty() else 1)
