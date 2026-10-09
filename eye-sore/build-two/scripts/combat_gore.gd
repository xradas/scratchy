extends Node3D
## Resolved hurt/death events own these effects. No damage or gameplay collision lives here.
var profile: GoreProfile
var combat: Node3D
var stains: Array[MeshInstance3D] = []
var remains: Array[MeshInstance3D] = []
var particles: Array[Dictionary] = []
var seen: Dictionary = {}
var death_records: Dictionary = {}
var material_cache: Dictionary = {}
var drop_mesh: SphereMesh
var spark_mesh: BoxMesh
var death_count: int = 0

func setup(owner_combat: Node3D, settings: GoreProfile) -> void:
	combat = owner_combat; profile = settings
	drop_mesh = SphereMesh.new(); drop_mesh.radius = .025; drop_mesh.height = .05
	drop_mesh.radial_segments = 6; drop_mesh.rings = 2
	var blood := StandardMaterial3D.new()
	blood.albedo_color = profile.blood_color; blood.roughness = .8
	blood.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop_mesh.material = blood
	spark_mesh = BoxMesh.new(); spark_mesh.size = Vector3(.018, .018, .055)
	var sparks := StandardMaterial3D.new(); sparks.albedo_color = Color(1,.52,.09)
	sparks.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_mesh.material = sparks

func reset() -> void:
	for particle in particles:
		if is_instance_valid(particle.node): particle.node.queue_free()
	for node in stains + remains:
		if is_instance_valid(node): node.queue_free()
	particles.clear(); stains.clear(); remains.clear(); seen.clear(); death_records.clear()
	death_count = 0

func should_gib(weapon: StringName, overkill: float) -> bool:
	return weapon == &"shotgun" and overkill >= profile.gib_overkill

func handle_event(event: Dictionary) -> void:
	var type := String(event.get("type", ""))
	if type not in ["enemy_hurt", "enemy_death"]: return
	var key := "%s:%s:%s" % [type, event.get("target_id", ""), event.get("shot_id", 0)]
	if seen.has(key): return
	seen[key] = true
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var weapon := String(event.get("weapon_id", "pistol"))
	var direction: Vector3 = event.get("direction", -combat.camera.global_basis.z)
	var contact: Vector3 = event.get("contact_position", event.position)
	if type == "enemy_hurt":
		if String(event.get("material", "flesh")) == "armor":
			burst(contact, direction, 4 if weapon == "shotgun" else 2, rng, true)
		else:
			burst(contact, direction, int(profile.spray_counts.get(weapon, 7)), rng)
			spatter_behind(contact, direction, .3 if weapon == "shotgun" else .17, rng)
		return
	var target := String(event.target_id)
	if death_records.has(target): return
	death_count += 1
	var dismembered: bool = event.get("gibbed", false)
	var count := int(profile.death_counts.get(weapon, 12))
	burst(contact, direction, count, rng)
	spatter_behind(contact, direction, .48 if weapon == "shotgun" else .27, rng)
	var floor_hit := world_ray(event.position + Vector3.UP * .2, event.position + Vector3.DOWN * 3.0)
	var pool: MeshInstance3D
	if not floor_hit.is_empty() and floor_hit.normal.y > .65:
		var radius := 1.28 if dismembered else (.95 if weapon == "shotgun" else .78)
		pool = surface_patch(floor_hit.position, floor_hit.normal, Vector2.ONE * radius * 2,
			profile.pools, 2, 2, 1, 9, rng.randf_range(0,TAU), false)
		if is_instance_valid(pool): pool.set_meta("death_pool",true)
	var body_parts := 9 if dismembered else (3 if weapon == "shotgun" else 2)
	for i in body_parts:
		var offset := Vector3(rng.randf_range(-.25,.25),rng.randf_range(-.1,.25),rng.randf_range(-.25,.25))
		var flying := Sprite3D.new()
		flying.texture = profile.remains; flying.hframes = 4; flying.vframes = 2
		flying.frame = (i % 8) if dismembered else (7 if i == 0 else 3)
		flying.pixel_size = .0017 if dismembered else .0010
		flying.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		flying.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD; flying.alpha_scissor_threshold = .12
		flying.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		# The source carries painted dimensional shading, like the creature sprites.
		flying.shaded = false; flying.modulate = Color(.72,.72,.72)
		add_child(flying); flying.global_position = event.position + offset
		var speed := 2.6 if dismembered else 1.5
		var velocity := Vector3(rng.randf_range(-speed,speed),rng.randf_range(2.0,4.5),rng.randf_range(-speed,speed)) + direction * .8
		append_particle({"node":flying,"velocity":velocity,"age":0.0,"life":2.4,"gib":true,"cell":flying.frame,"size":Vector2(.68,.9) if dismembered else Vector2(.34,.45),"rotation":rng.randf_range(0,TAU),"blood":false,"bounces":0})
	death_records[target] = {"weapon":weapon,"gibbed":dismembered,"part_count":body_parts,"pool":pool,"shot_id":event.get("shot_id",0),"damage":event.get("damage",0),"overkill":event.get("overkill",0)}

func burst(point: Vector3, direction: Vector3, count: int, rng: RandomNumberGenerator, sparks: bool = false) -> void:
	for i in count:
		var node := MeshInstance3D.new(); node.mesh = spark_mesh if sparks else drop_mesh
		add_child(node); node.global_position = point + Vector3(rng.randf_range(-.08,.08),rng.randf_range(-.08,.08),rng.randf_range(-.08,.08))
		node.scale = Vector3.ONE * rng.randf_range(.6,1.4)
		var velocity := direction * rng.randf_range(1.0,3.0) + Vector3(rng.randf_range(-2.2,2.2),rng.randf_range(.4,3.1),rng.randf_range(-2.2,2.2))
		append_particle({"node":node,"velocity":velocity,"age":0.0,"life":.25 if sparks else .7,"gib":false,"blood":not sparks,"bounces":0,"splat":i % 5 == 0})

func append_particle(particle: Dictionary) -> void:
	if particles.size() >= profile.max_particles:
		var old: Dictionary = particles.pop_front()
		if is_instance_valid(old.node): old.node.queue_free()
	particles.append(particle)

func _physics_process(delta: float) -> void:
	for i in range(particles.size()-1,-1,-1):
		var p: Dictionary = particles[i]
		if not is_instance_valid(p.node): particles.remove_at(i); continue
		p.age += delta
		p.velocity.y -= profile.gravity * delta
		var from: Vector3 = p.node.global_position
		var to: Vector3 = from + p.velocity * delta
		var hit := world_ray(from,to)
		if not hit.is_empty():
			if p.gib:
				if hit.normal.y < .65 and p.bounces < 2:
					p.velocity = (p.velocity as Vector3).bounce(hit.normal) * .3
					p.node.global_position = hit.position + hit.normal * .02
					p.bounces += 1
					continue
				settle_gib(p,hit)
			elif p.blood and p.splat:
				surface_patch(hit.position,hit.normal,Vector2.ONE * .24,profile.pools,2,2,0,4,p.age * 7,false)
			p.node.queue_free(); particles.remove_at(i); continue
		p.node.global_position = to
		if p.gib: p.node.rotation.z += delta * 5.0
		if p.age >= p.life:
			if p.gib:
				var floor_hit := world_ray(to + Vector3.UP, to + Vector3.DOWN * 4)
				if not floor_hit.is_empty(): settle_gib(p,floor_hit)
			p.node.queue_free(); particles.remove_at(i)

func settle_gib(p: Dictionary, hit: Dictionary) -> void:
	if hit.normal.y <= .65: return
	surface_patch(hit.position,hit.normal,p.size,profile.remains,4,2,p.cell,4,p.rotation,true)

func spatter_behind(point: Vector3, direction: Vector3, size: float, rng: RandomNumberGenerator) -> void:
	var hit := world_ray(point + direction * .04, point + direction * 2.4)
	if not hit.is_empty(): surface_patch(hit.position,hit.normal,Vector2.ONE * size * 2,profile.pools,2,2,0,4,rng.randf_range(0,TAU),false)

func world_ray(from: Vector3, to: Vector3) -> Dictionary:
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,to,1))

func surface_patch(center: Vector3, normal: Vector3, extent: Vector2, texture: Texture2D, columns: int, rows: int, cell: int, grid: int, angle: float, is_remains: bool) -> MeshInstance3D:
	# Compatibility has no projected Decal node. Sample the shared world geometry,
	# omit unsupported triangles and split at risers; blood cannot bridge thin air.
	var tangent := normal.cross(Vector3.FORWARD).normalized()
	if tangent.length_squared() < .5: tangent = normal.cross(Vector3.RIGHT).normalized()
	tangent = tangent.rotated(normal,angle)
	var bitangent := normal.cross(tangent).normalized()
	var points: Array = []; var normals: Array[Vector3] = []; var uvs: Array[Vector2] = []
	for y in grid:
		for x in grid:
			var uv := Vector2(x / float(grid-1), y / float(grid-1))
			var probe := center + tangent * (uv.x-.5) * extent.x + bitangent * (uv.y-.5) * extent.y
			var hit := world_ray(probe + normal * .32,probe - normal * .42)
			var lift := .026 if is_remains else .009
			points.append(hit.position + hit.normal * lift - center if not hit.is_empty() and hit.normal.dot(normal) > .92 else null)
			normals.append(hit.normal if not hit.is_empty() else normal)
			uvs.append((uv + Vector2(cell % columns, cell / columns)) / Vector2(columns,rows))
	var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var triangles := 0
	for y in grid-1:
		for x in grid-1:
			var a := y*grid+x; var b := a+1; var c := a+grid+1; var d := a+grid
			for indices in [[a,b,c],[a,c,d]]:
				if points[indices[0]] == null or points[indices[1]] == null or points[indices[2]] == null: continue
				var heights: Array[float] = []
				for index in indices: heights.append((points[index] as Vector3).dot(normal))
				if heights.max()-heights.min() > .025: continue
				for index in indices:
					surface.set_normal(normals[index]); surface.set_uv(uvs[index]); surface.add_vertex(points[index])
				triangles += 1
	if triangles == 0: return null
	var material_key := texture.resource_path
	if not material_cache.has(material_key):
		var material := StandardMaterial3D.new(); material.albedo_texture = texture
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.alpha_scissor_threshold = .12; material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		material.roughness = .88
		if is_remains:
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.albedo_color = Color(.72,.72,.72)
		material_cache[material_key] = material
	var mesh := MeshInstance3D.new(); mesh.mesh = surface.commit(); mesh.material_override = material_cache[material_key]
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.set_meta("gore_remains",is_remains); mesh.set_meta("surface_normal",normal); mesh.set_meta("cell",cell)
	add_child(mesh); mesh.global_position = center
	var collection: Array[MeshInstance3D] = remains if is_remains else stains
	var maximum := profile.max_remains if is_remains else profile.max_stains
	if collection.size() >= maximum:
		var oldest := 0
		for index in collection.size():
			if not collection[index].get_meta("death_pool",false): oldest = index; break
		var old: MeshInstance3D = collection[oldest]; collection.remove_at(oldest)
		if is_instance_valid(old): old.queue_free()
	collection.append(mesh)
	return mesh
