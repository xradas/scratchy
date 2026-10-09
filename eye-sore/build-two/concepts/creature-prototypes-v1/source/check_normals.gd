extends SceneTree
func _initialize():
 var rig=load("res://creature_rig.gd").new(); root.add_child(rig); rig.configure(&"unsealed")
 for child in rig.body.get_children():
  if child is MeshInstance3D:
   var a=child.mesh.surface_get_arrays(0); var v=a[Mesh.ARRAY_VERTEX]; var n=a[Mesh.ARRAY_NORMAL]
   for i in [28,56,84]: print(v[i]," normal ",n[i]," dot ",Vector3(v[i].x,0,v[i].z).dot(n[i]))
   break
 quit()
