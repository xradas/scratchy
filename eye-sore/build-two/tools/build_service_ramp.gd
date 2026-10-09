extends SceneTree
## Offline mesh authoring. Same six wedge vertices as the collision resource.
func _initialize() -> void:
	var points := PackedVector3Array([Vector3(-1.5,0,-1.2),Vector3(1.5,0,-1.2),Vector3(-1.5,0,1.2),Vector3(1.5,0,1.2),Vector3(-1.5,.9,-1.2),Vector3(1.5,.9,-1.2)])
	var mesh := ArrayMesh.new()
	var tool := SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := [[4,5,3,4,3,2],[0,2,3,0,3,1],[0,1,5,0,5,4],[0,4,2],[1,3,5]]
	var normals := [Vector3(0,2.4,.9).normalized(),Vector3.DOWN,Vector3(0,0,-1),Vector3.LEFT,Vector3.RIGHT]
	for i in faces.size():
		for index in faces[i]:
			var point := points[index]
			tool.set_normal(normals[i])
			tool.set_uv(Vector2((point.x+1.5)/3.0,(point.z+1.2)/2.4) if i<2 else Vector2((point.z+1.2)/2.4 if i>2 else (point.x+1.5)/3.0,point.y/.9))
			tool.add_vertex(point)
	tool.commit(mesh)
	assert(ResourceSaver.save(mesh,"res://resources/service_ramp_mesh.tres")==OK)
	print("SERVICE_RAMP_MESH_AUTHORED: exact six collision vertices, 8 triangles, normals and UVs")
	quit()
