class_name GoreChunkV12
extends RefCounted
## Closed cosmetic volumes: original native painted caps, opaque textured sides.
## Queries shared world geometry; never registers a physics body/collider.
const MAX_CACHE := 96
const ALPHA_THRESHOLD := .5
const SKIN := .008
static var meshes: Dictionary = {}
static var images: Dictionary = {}
static var spheres: Dictionary = {}

static func clear_cache() -> void:
	meshes.clear(); images.clear(); spheres.clear()

static func cache_state() -> Dictionary:
	return {"meshes":meshes.size(),"images":images.size(),"spheres":spheres.size(),"maximum_meshes":MAX_CACHE}

static func source_info(part: Dictionary) -> Dictionary:
	var texture: Texture2D = part.texture
	var region := Rect2(Vector2.ZERO,texture.get_size())
	while texture is AtlasTexture:
		region = Rect2(texture.region.position+region.position,texture.region.size)
		texture = texture.atlas
	var columns := maxi(int(part.get("columns",1)),1)
	var rows := maxi(int(part.get("rows",1)),1)
	var cell := clampi(int(part.get("cell",0)),0,columns*rows-1)
	var cell_size := region.size/Vector2(columns,rows)
	region = Rect2(region.position+Vector2(cell%columns,cell/columns)*cell_size,cell_size)
	return {"texture":texture,"region":region}

static func image_for(texture: Texture2D) -> Image:
	var key := texture.resource_path if not texture.resource_path.is_empty() else str(texture.get_instance_id())
	if not images.has(key):
		if images.size()>=4: images.erase(images.keys()[0])
		var image := texture.get_image()
		if image.is_compressed(): image.decompress()
		images[key]=image
	return images[key]

static func outline(image: Image, region: Rect2) -> PackedVector2Array:
	# Ten native-alpha slices retain bent limbs/anatomy while bounding complexity.
	# The generated haze is excluded at alpha.5; no full-cell rectangular cards.
	var rows: Array[Dictionary] = []
	for row in range(16):
		var y := int(region.position.y+(row+.5)*region.size.y/16.0)
		var low := INF; var high := -INF
		for column in range(0,int(region.size.x),2):
			var x := int(region.position.x)+column
			if image.get_pixel(x,y).a < ALPHA_THRESHOLD: continue
			low=minf(low,float(column)); high=maxf(high,float(column))
		if high-low>=region.size.x*.035:
			rows.append({"y":(y-region.position.y+.5)/region.size.y,"left":(low+.5)/region.size.x,"right":(high+.5)/region.size.x})
	var ring := PackedVector2Array()
	if rows.size()>=3:
		# Keep at most ten rows, including both ends. No raster resampling/writes.
		var count := mini(rows.size(),10)
		for i in count:
			var row: Dictionary=rows[roundi(float(i)*(rows.size()-1)/float(count-1))]
			ring.append(Vector2(row.left,row.y))
		for i in range(count-1,-1,-1):
			var row: Dictionary=rows[roundi(float(i)*(rows.size()-1)/float(count-1))]
			ring.append(Vector2(row.right,row.y))
	else:
		# Legacy/non-alpha source fallback is an anatomical tapered octagon, never a card.
		ring=PackedVector2Array([Vector2(.35,.1),Vector2(.18,.3),Vector2(.24,.72),Vector2(.4,.93),Vector2(.62,.89),Vector2(.8,.68),Vector2(.77,.25),Vector2(.6,.08)])
	return ring

static func material(texture: Texture2D,tint: Color,metal: bool) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_texture=texture; result.albedo_color=tint
	result.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
	result.transparency=BaseMaterial3D.TRANSPARENCY_DISABLED
	result.cull_mode=BaseMaterial3D.CULL_BACK
	result.roughness=.76 if metal else .86; result.metallic=.38 if metal else .0
	return result

static func triangle(surface: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,uv_a: Vector2,uv_b: Vector2,uv_c: Vector2,outward: Vector3) -> void:
	var normal := (b-a).cross(c-a).normalized()
	if normal.dot(outward)<0:
		var swap:=b;b=c;c=swap
		var uv_swap:=uv_b;uv_b=uv_c;uv_c=uv_swap
		normal=-normal
	for i in 3:
		surface.set_normal(normal);surface.set_uv([uv_a,uv_b,uv_c][i]);surface.add_vertex([a,b,c][i])

static func create(part: Dictionary,rng: RandomNumberGenerator) -> MeshInstance3D:
	var source := source_info(part)
	var texture: Texture2D=source.texture
	var region: Rect2=source.region
	var size: Vector2=part.get("size",Vector2(.25,.4))
	size=size.clamp(Vector2(.08,.08),Vector2(.7,.7))
	var depth:=clampf(float(part.get("depth",minf(size.x,size.y)*.62)),.085,.26)
	var name:=String(part.get("name","flesh"))
	var armor:=String(part.get("material","flesh"))=="armor"
	var tint: Color=part.get("tint",Color.WHITE)
	var side_tint: Color=part.get("coat_tint",part.get("exposed_tint",tint))
	var key: String=str([texture.resource_path,texture.get_instance_id(),region,size,depth,name,armor,tint,side_tint])
	if not meshes.has(key):
		var image:=image_for(texture)
		var ring:=outline(image,region)
		var n:=ring.size()
		var vertices:=PackedVector3Array()
		var uvs:=PackedVector2Array()
		var texture_size:=texture.get_size()
		# Native half-texel bounds; back and side UVs never address another cell.
		var uv_rect:=Rect2((region.position+Vector2(.5,.5))/texture_size,(region.size-Vector2.ONE)/texture_size)
		for layer in 3:
			var bevel:=.72 if layer!=1 else 1.0
			var z: float=[depth*.5,0.0,-depth*.5][layer]
			for point in ring:
				vertices.append(Vector3((point.x-.5)*size.x*bevel,(.5-point.y)*size.y*bevel,z))
				uvs.append(uv_rect.position+point*uv_rect.size)
		var projected:=PackedVector2Array()
		for p in vertices.slice(0,n):projected.append(Vector2(p.x,p.y))
		var caps:=Geometry2D.triangulate_polygon(projected)
		assert(caps.size()>0,"Anatomical alpha outline must triangulate")
		var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for side in [0,2]:
			for i in range(0,caps.size(),3):
				var a: int=int(caps[i])+side*n;var b: int=int(caps[i+1])+side*n;var c: int=int(caps[i+2])+side*n
				triangle(surface,vertices[a],vertices[b],vertices[c],uvs[a],uvs[b],uvs[c],Vector3.BACK if side==0 else Vector3.FORWARD)
		var mesh:=surface.commit()
		mesh.surface_set_material(0,material(texture,tint,armor))
		# Choose actual opaque native tissue/metal texels for the continuous side skin.
		var center_uv:=uv_rect.get_center()
		var best:=INF;var patch_half:=.5
		for y in range(0,int(region.size.y),4):
			for x in range(0,int(region.size.x),4):
				var pixel:=Vector2i(region.position)+Vector2i(x,y)
				if image.get_pixelv(pixel).a<.9:continue
				var metric:=Vector2(x,y).distance_squared_to(region.size*.5)
				if metric>=best:continue
				var opaque_patch:=true
				for dy in [-8,0,8]:
					for dx in [-8,0,8]:
						var probe:=pixel+Vector2i(dx,dy)
						if not region.has_point(Vector2(probe)) or image.get_pixelv(probe).a<.9:opaque_patch=false
				if not opaque_patch:continue
				best=metric;patch_half=8.0;center_uv=(Vector2(pixel)+Vector2(.5,.5))/texture_size
		var half_uv:=Vector2(patch_half,patch_half)/texture_size
		var side_uvs: Array[Vector2]=[center_uv-half_uv,center_uv+Vector2(half_uv.x,-half_uv.y),center_uv+half_uv,center_uv+Vector2(-half_uv.x,half_uv.y)]
		surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var normals:=PackedVector3Array([Vector3.FORWARD,Vector3.BACK])
		for layer in 2:
			for i in n:
				var next: int=(i+1)%n;var a: int=layer*n+i;var b: int=layer*n+next;var c: int=(layer+1)*n+next;var d: int=(layer+1)*n+i
				var normal: Vector3=(vertices[b]-vertices[a]).cross(vertices[c]-vertices[a]).normalized()
				if not Geometry2D.is_polygon_clockwise(projected):normal=-normal
				triangle(surface,vertices[a],vertices[b],vertices[c],side_uvs[0],side_uvs[1],side_uvs[2],normal)
				triangle(surface,vertices[a],vertices[c],vertices[d],side_uvs[0],side_uvs[2],side_uvs[3],normal)
				normals.append(normal)
		surface.commit(mesh);mesh.surface_set_material(1,material(texture,side_tint,armor))
		var radius:=0.0;var center_of_mass:=Vector3.ZERO;var volume6:=0.0
		for v in vertices:radius=maxf(radius,v.length())
		# Uniform solid COM from the oriented closed triangles, not vertex density.
		for index in mesh.get_surface_count():
			var triangles: PackedVector3Array=mesh.surface_get_arrays(index)[Mesh.ARRAY_VERTEX]
			for i in range(0,triangles.size(),3):
				var a:=triangles[i];var b:=triangles[i+1];var c:=triangles[i+2]
				var weight:=a.dot(b.cross(c));volume6+=weight;center_of_mass+=(a+b+c)*weight*.25
		center_of_mass/=volume6
		if meshes.size()>=MAX_CACHE:meshes.erase(meshes.keys()[0])
		var query_shape:=ConvexPolygonShape3D.new();query_shape.points=vertices
		meshes[key]={"center_of_mass":center_of_mass,"query_shape":query_shape,"mesh":mesh,"vertices":vertices,"radius":radius,"depth":depth,"normals":normals,"region":region,"uv_rect":uv_rect,"side_sample_uv":center_uv,"side_patch_half_pixels":patch_half,"triangles":caps.size()/3*2+n*8}
	var cached: Dictionary=meshes[key]
	var node:=MeshInstance3D.new();node.mesh=cached.mesh;node.layers=2
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.set_meta("query_shape",cached.query_shape)
	node.set_meta("side_patch_half_pixels",cached.side_patch_half_pixels)
	node.set_meta("center_of_mass",cached.center_of_mass)
	for field in ["vertices","radius","depth","normals","region","uv_rect","side_sample_uv","triangles"]:
		node.set_meta({"vertices":"local_vertices","radius":"bounds_radius","depth":"volume_depth_m","normals":"support_normals","region":"source_region","uv_rect":"source_uv_rect","side_sample_uv":"side_sample_uv","triangles":"triangle_count"}[field],cached[field])
	node.set_meta("mesh_closed",true);node.set_meta("gore_chunk_version",12)
	node.set_meta("anatomical_part",name);node.set_meta("hit_material",part.get("material","flesh"));node.set_meta("source_texture_path",texture.resource_path)
	node.set_meta("rest_yaw_offset",rng.randf_range(-PI,PI));node.set_meta("coat_tint",part.get("coat_tint",Color.WHITE))
	return node

static func sphere_for(radius: float) -> SphereShape3D:
	var key:=ceilf(radius*1000.0)/1000.0
	if not spheres.has(key):
		if spheres.size()>=MAX_CACHE:spheres.erase(spheres.keys()[0])
		var shape:=SphereShape3D.new();shape.radius=key;spheres[key]=shape
	return spheres[key]

static func sphere_query(radius: float,at: Vector3,mask: int) -> PhysicsShapeQueryParameters3D:
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=sphere_for(radius)
	query.transform=Transform3D(Basis.IDENTITY,at);query.collision_mask=mask;query.margin=.001
	query.collide_with_bodies=true;query.collide_with_areas=false
	return query

static func sweep(world: PhysicsDirectSpaceState3D,chunk: MeshInstance3D,from: Transform3D,to: Transform3D,mask: int=1) -> Dictionary:
	# A conservative sphere encloses every rotation of the closed volume, avoiding
	# thin-wall tunnelling without adding a body to gameplay physics.
	var radius: float=chunk.get_meta("bounds_radius",.2)
	var query:=sphere_query(radius,from.origin,mask)
	var start:=world.get_rest_info(query)
	var starting_overlap:=not world.intersect_shape(query,1).is_empty()
	if starting_overlap:
		var safe:=from
		for i in 4:
			var overlap_query:=sphere_query(radius,safe.origin,mask)
			if world.intersect_shape(overlap_query,1).is_empty():break
			var overlap:=world.get_rest_info(overlap_query)
			# Godot may report overlap but no rest normal when sphere center is
			# inside a thin wall. Probe inward from six bounded exterior points.
			if overlap.is_empty():
				var nearest:=INF
				for axis in [Vector3.RIGHT,Vector3.LEFT,Vector3.UP,Vector3.DOWN,Vector3.FORWARD,Vector3.BACK]:
					var contact:=ray(world,safe.origin+axis*(radius+1.0),safe.origin,mask)
					if contact.is_empty():continue
					var distance: float=safe.origin.distance_to(contact.position)
					if distance<nearest:
						nearest=distance;overlap={"point":contact.position,"normal":contact.normal}
			if overlap.is_empty():break
			if start.is_empty():start=overlap
			var distance: float=(safe.origin-overlap.point).dot(overlap.normal)
			safe.origin+=overlap.normal*maxf(radius-distance+SKIN,.012)
		var normal: Vector3=start.get("normal",Vector3.UP)
		return {"hit":true,"fraction":0.0,"transform":safe,"position":start.get("point",from.origin),"normal":normal,"starting_overlap":true,"overlap_recovered":world.intersect_shape(sphere_query(radius,safe.origin,mask),1).is_empty()}
	query.motion=to.origin-from.origin
	var fraction:=world.cast_motion(query)
	if fraction.size()<2 or fraction[0]>=1.0:
		return {"hit":false,"fraction":1.0,"transform":to}
	var safe:=to;safe.origin=from.origin.lerp(to.origin,maxf(0.0,fraction[0]-.001))
	query.transform.origin=from.origin.lerp(to.origin,minf(1.0,fraction[1]+.003));query.motion=Vector3.ZERO
	var info:=world.get_rest_info(query)
	var normal: Vector3=info.get("normal",(from.origin-to.origin).normalized())
	return {"hit":true,"fraction":fraction[0],"transform":safe,"position":info.get("point",safe.origin-normal*radius),"normal":normal,"starting_overlap":false}

static func ray(world: PhysicsDirectSpaceState3D,from: Vector3,to: Vector3,mask: int) -> Dictionary:
	return world.intersect_ray(PhysicsRayQueryParameters3D.create(from,to,mask))

static func fit_candidate(world: PhysicsDirectSpaceState3D,vertices: PackedVector3Array,basis: Basis,at: Vector3,mask: int,shape: Shape3D,center_of_mass: Vector3) -> Dictionary:
	var rotated:=PackedVector3Array();var hits: Array[Dictionary]=[]
	var height: float=-INF
	for vertex in vertices:
		var offset:=basis*vertex;rotated.append(offset)
		var hit:=ray(world,Vector3(at.x+offset.x,at.y+.45,at.z+offset.z),Vector3(at.x+offset.x,at.y-.95,at.z+offset.z),mask)
		if hit.is_empty() or hit.normal.y<.65:hits.append({});continue
		hits.append(hit);height=maxf(height,hit.position.y-offset.y+SKIN)
	if not is_finite(height) or height-at.y>.5 or at.y-height>.95:return {"supported":false,"reason":"no local walkable support"}
	var contacts:=PackedVector3Array();var points:=PackedVector2Array()
	for i in vertices.size():
		if hits[i].is_empty():continue
		var point:=Vector3(at.x,height,at.z)+rotated[i]
		if absf(point.y-SKIN-hits[i].position.y)<.018:
			contacts.append(hits[i].position);points.append(Vector2(rotated[i].x,rotated[i].z))
	if points.size()<3:return {"supported":false,"reason":"fewer than three volume contacts"}
	var hull:=Geometry2D.convex_hull(points)
	if hull.size()<4 or not Geometry2D.is_point_in_polygon(Vector2((basis*center_of_mass).x,(basis*center_of_mass).z),hull):return {"supported":false,"reason":"center of mass outside support polygon"}
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape
	query.transform=Transform3D(basis,Vector3(at.x,height,at.z));query.collision_mask=mask;query.margin=.001
	if not world.intersect_shape(query,1).is_empty():return {"supported":false,"reason":"volume intersects terrain/wall"}
	# Reject interpenetration by sampling every mesh vertex against actual terrain.
	# The maximum-height fit places the complete nonconvex body above all tread hits.
	return {"supported":true,"transform":Transform3D(basis,Vector3(at.x,height,at.z)),"contacts":contacts,"support_polygon":hull,"reason":"volume contacts enclose projected center"}

static func support_pose(world: PhysicsDirectSpaceState3D,chunk: MeshInstance3D,at: Vector3,yaw: float,mask: int=1) -> Dictionary:
	var vertices: PackedVector3Array=chunk.get_meta("local_vertices",PackedVector3Array())
	if vertices.is_empty():return {"supported":false,"reason":"missing volume"}
	var current: Basis=chunk.global_basis.orthonormalized() if chunk.is_inside_tree() else Basis(Vector3.UP,yaw)
	var normals: PackedVector3Array=chunk.get_meta("support_normals",PackedVector3Array([Vector3.FORWARD,Vector3.BACK]))
	var candidates: Array[Dictionary]=[]
	for normal in normals:
		var direction: Vector3=current*normal
		var rotation:=Quaternion(direction,Vector3.DOWN)
		candidates.append({"score":direction.dot(Vector3.DOWN),"basis":Basis(rotation)*current})
	candidates.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return a.score>b.score)
	for entry in candidates:
		var result:=fit_candidate(world,vertices,entry.basis,at,mask,chunk.get_meta("query_shape"),chunk.get_meta("center_of_mass"))
		if result.supported:
			chunk.set_meta("support_contacts",result.contacts);chunk.set_meta("support_reason",result.reason)
			return result
	return {"supported":false,"reason":"no stable local support; continue falling"}
