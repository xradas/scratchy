extends SceneTree
## Native closed-mesh/query fixture. No production scenes/data mutated.
const Chunk=preload("res://scripts/gore_chunk_v12.gd")
var failures: Array[String]=[]
var checks:=0
var evidence_dir:="/tmp/eyesore-chunks-v12"
var arena: Node3D
var records: Array[Dictionary]=[]
var terrain: Array[Dictionary]=[]
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="):evidence_dir=arg.trim_prefix("--evidence-dir=")
	call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func block(at: Vector3,size: Vector3) -> void:
	var body:=StaticBody3D.new();body.collision_layer=1;body.collision_mask=0;arena.add_child(body);body.position=at
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=size;shape.shape=box;body.add_child(shape)
	var visual:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=size;visual.mesh=mesh;body.add_child(visual)
	var material:=StandardMaterial3D.new();material.albedo_color=Color(.18,.2,.19);visual.material_override=material
func key(p: Vector3) -> String:return "%.6f,%.6f,%.6f"%[p.x,p.y,p.z]
func mesh_check(node: MeshInstance3D,label: String) -> void:
	var edges: Dictionary={};var volume:=0.0;var count:=0
	for surface in node.mesh.get_surface_count():
		var arrays:=node.mesh.surface_get_arrays(surface)
		var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var uvs: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
		var material: StandardMaterial3D=node.mesh.surface_get_material(surface)
		check(material.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED,label+" solid material has no alpha holes")
		check(material.texture_filter==BaseMaterial3D.TEXTURE_FILTER_NEAREST,label+" native nearest sampling")
		var rect: Rect2=node.get_meta("source_uv_rect")
		for uv in uvs:check(uv.x>=rect.position.x-.000001 and uv.y>=rect.position.y-.000001 and uv.x<=rect.end.x+.000001 and uv.y<=rect.end.y+.000001,label+" UV inside exact native cell")
		for i in range(0,points.size(),3):
			var a:=points[i];var b:=points[i+1];var c:=points[i+2]
			check((b-a).cross(c-a).length()>.0000001,label+" nondegenerate face")
			volume+=a.dot(b.cross(c))/6.0;count+=1
			for edge in [[a,b],[b,c],[c,a]]:
				var first:=key(edge[0]);var second:=key(edge[1]);var pair: String=(first+"|"+second) if first<second else (second+"|"+first)
				if not edges.has(pair):edges[pair]={"count":0,"winding":0}
				edges[pair].count+=1;edges[pair].winding+=1 if first<second else -1
	for edge in edges.values():check(edge.count==2 and edge.winding==0,label+" exactly two oppositely oriented faces per edge")
	check(volume>.00002,label+" positive closed signed volume")
	var bounds:=node.mesh.get_aabb()
	check(bounds.size.x>.03 and bounds.size.y>.03 and bounds.size.z>=.0849,label+" visible depth on all axes")
	check(node.get_meta("mesh_closed") and node.get_child_count()==0,label+" zero collision/gameplay descendants")
	check(count<=196,label+" <=196 triangles")
	var source: Texture2D=node.mesh.surface_get_material(1).albedo_texture
	var image:=source.get_image();if image.is_compressed():image.decompress()
	var sample: Vector2=node.get_meta("side_sample_uv")
	check(image.get_pixelv(Vector2i(sample*source.get_size())).a>=.89,label+" sides sample opaque native tissue/armor")
	records.append({"part":label,"triangles":count,"signed_volume":volume,"depth_m":bounds.size.z,"source":node.get_meta("source_texture_path"),"source_region":str(node.get_meta("source_region")),"bounds_m":str(bounds.size)})
func support_check(world: PhysicsDirectSpaceState3D,node: MeshInstance3D,at: Vector3,label: String,expected: bool) -> void:
	var result:=Chunk.support_pose(world,node,at,node.rotation.y)
	check(result.supported==expected,label+" support expectation")
	if result.supported:
		node.global_transform=result.transform
		check(result.contacts.size()>=3,label+" >=3 actual contacts")
		var com: Vector3=result.transform.basis*node.get_meta("center_of_mass")
		check(Geometry2D.is_point_in_polygon(Vector2(com.x,com.z),result.support_polygon),label+" projected COM inside contact hull")
		var minimum:=INF
		for point in result.contacts:
			var hit:=Chunk.ray(world,point+Vector3.UP*.05,point-Vector3.UP*.05,1)
			check(not hit.is_empty() and hit.position.distance_to(point)<.002,label+" contact belongs to shared physical surface")
		for local: Vector3 in node.get_meta("local_vertices"):
			var point: Vector3=result.transform*local
			var hit:=Chunk.ray(world,Vector3(point.x,at.y+.45,point.z),Vector3(point.x,at.y-.95,point.z),1)
			if not hit.is_empty():minimum=minf(minimum,point.y-hit.position.y)
		check(minimum>=.006,label+" complete closed volume above terrain")
	terrain.append({"case":label,"supported":result.supported,"reason":result.reason,"contacts":result.get("contacts",PackedVector3Array()).size(),"transform":str(result.get("transform",Transform3D.IDENTITY))})
func run() -> void:
	DirAccess.make_dir_recursive_absolute(evidence_dir)
	root.size=Vector2i(960,540);root.set_flag(Window.FLAG_NO_FOCUS,true)
	arena=Node3D.new();root.add_child(arena)
	block(Vector3(0,-.25,0),Vector3(4,.5,4));block(Vector3(0,1,-1.5),Vector3(4,2,.08))
	for i in 4:block(Vector3(5,.1*(i+1)-.1,-i*.6),Vector3(2,.2*(i+1),.6))
	block(Vector3(10,-.1,0),Vector3(1,.2,1))
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-50,-35,0);light.light_energy=1.6;arena.add_child(light)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(.07,.08,.09);environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color(.6,.6,.6);environment.environment.ambient_light_energy=.6;arena.add_child(environment)
	var gore:=preload("res://scripts/combat_gore.gd").new();gore.profile=load("res://resources/gore_profile.tres")
	var rng:=RandomNumberGenerator.new();rng.seed=12012
	var representatives: Array[MeshInstance3D]=[]
	for kind in gore.profile.species_atlases:
		var parts: Array=gore.profile.species_atlases[kind].parts
		for i in parts.size():
			var spec: Dictionary=gore.part_spec(kind,i,true)
			var chunk:=Chunk.create(spec,rng)
			mesh_check(chunk,String(kind)+"/"+String(spec.name)+"/"+str(i))
			if kind in ["unsealed","ironbound"] and spec.name in ["head","arm","leg","ribcage"] and representatives.size()<8:representatives.append(chunk);arena.add_child(chunk)
			else:chunk.free()
	gore.free()
	await physics_frame;await physics_frame
	var world:=arena.get_world_3d().direct_space_state
	var orientations: Dictionary={}
	for i in representatives.size():
		var chunk:=representatives[i]
		chunk.basis=Basis.from_euler(Vector3(.3+i*.23,i*.68,-.2+i*.37))
		support_check(world,chunk,Vector3((i%4-1.5)*.72,.45,(i/4-.5)*.85),"flat/"+str(i),true)
		orientations[str(chunk.basis)]=true
	check(orientations.size()>=4,"varied actual supported rest orientations")
	var chunk:=representatives[0]
	for i in 4:
		chunk.basis=Basis.from_euler(Vector3(PI*.5,0,0))
		support_check(world,chunk,Vector3(5,.2*(i+1)+.3,-i*.6),"stair-tread/"+str(i),true)
	chunk.basis=Basis.from_euler(Vector3(PI*.5,.4,0))
	support_check(world,chunk,Vector3(10,.3,0),"ledge-center",true)
	support_check(world,chunk,Vector3(10.85,.3,0),"unsupported-edge",false)
	support_check(world,chunk,Vector3(14,.3,0),"unsupported-empty",false)
	var base:=Transform3D(Basis.IDENTITY,Vector3(0,1,0))
	var fall:=Chunk.sweep(world,chunk,base,Transform3D(Basis.from_euler(Vector3(1,2,3)),Vector3(0,-2,0)))
	check(fall.hit and fall.normal.y>.9 and fall.transform.origin.y>=chunk.get_meta("bounds_radius"),"swept rotating volume stops above floor")
	var wall:=Chunk.sweep(world,chunk,base,Transform3D(Basis.from_euler(Vector3(1,2,3)),Vector3(0,1,-3)))
	check(wall.hit and absf(wall.normal.z)>.9 and wall.transform.origin.z> -1.46+chunk.get_meta("bounds_radius"),"swept volume cannot tunnel thin wall")
	var overlap:=Chunk.sweep(world,chunk,Transform3D(Basis.IDENTITY,Vector3(0,1,-1.5)),base)
	check(overlap.hit and overlap.starting_overlap and overlap.overlap_recovered,"starting wall overlap recovers before advancing")
	# Return gallery representative to a support-fitted floor position for side views.
	chunk.basis=Basis.from_euler(Vector3(.8,.4,.2));support_check(world,chunk,Vector3(-1.1,.4,-.5),"gallery-return",true)
	var camera:=Camera3D.new();arena.add_child(camera);camera.current=true
	for view in [["low",Vector3(1.4,.45,1.5),Vector3(0,.15,0)],["side",Vector3(1.9,.9,2.3),Vector3(0,.12,0)]]:
		camera.position=view[1];camera.look_at(view[2])
		if DisplayServer.get_name()!="headless":
			for i in 4:await process_frame;RenderingServer.force_draw(false)
			root.get_texture().get_image().save_png(evidence_dir.path_join("chunks-"+view[0]+".png"))
	var report:={"passed":failures.is_empty(),"checks":checks,"failures":failures,"parts":records,"terrain":terrain,"cache":Chunk.cache_state(),"engine":Engine.get_version_info(),"display_server":DisplayServer.get_name(),"scope":"Closed opposite-edge winding/native atlas UV and opaque sides for all actual species parts; native shared-world floor/stair/unsupported support and volume wall/floor/starting-overlap sweeps. Cosmetic only; no production mutations. Native low/side gallery is separate from actual Main combat acceptance."}
	var file:=FileAccess.open(evidence_dir.path_join("checks.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"  ")+"\n");file.close()
	arena.free();Chunk.clear_cache();print("CHUNKS_V12 passed=",failures.is_empty()," checks=",checks);quit(0 if failures.is_empty() else 1)
