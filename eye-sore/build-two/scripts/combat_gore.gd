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
var part_texture_cache: Dictionary = {}
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
	material_cache.clear(); part_texture_cache.clear()

func should_gib(weapon: StringName, overkill: float, material: StringName = &"flesh") -> bool:
	var threshold := profile.gib_overkill * (1.4 if material == &"armor" else 1.0)
	return (weapon == &"shotgun" and overkill >= threshold) or overkill >= threshold * 3.0

func handle_event(event: Dictionary) -> void:
	var type := String(event.get("type", ""))
	if type not in ["enemy_hurt", "enemy_death", "corpse_hurt", "corpse_gib"]: return
	var key := "%s:%s:%s" % [type, event.get("target_id", ""), event.get("shot_id", 0)]
	if seen.has(key): return
	seen[key] = true
	if seen.size() > 2048: seen.erase(seen.keys()[0])
	var rng := RandomNumberGenerator.new(); rng.seed = hash(key)
	var weapon := String(event.get("weapon_id", "pistol"))
	var direction: Vector3 = (event.get("direction", -combat.camera.global_basis.z) as Vector3).normalized()
	var contact: Vector3 = event.get("contact_position", event.position)
	var armored := String(event.get("material", "flesh")) == "armor"
	if type in ["enemy_hurt", "corpse_hurt"]:
		if armored:
			burst(contact, direction, 6 if weapon == "shotgun" else 2, rng, true)
		else:
			burst(contact, direction, int(profile.spray_counts.get(weapon, 11)), rng)
			spatter_behind(contact, direction, .4 if weapon == "shotgun" else .22, rng)
		return
	var target := String(event.target_id)
	if type == "enemy_death" and death_records.has(target): return
	if type == "corpse_gib" and (not death_records.has(target) or death_records[target].get("gibbed",false)): return
	if type == "enemy_death": death_count += 1
	var dismembered: bool = event.get("gibbed", false)
	var kind := String(event.get("enemy_kind", "unsealed"))
	var count := int(profile.death_counts.get(weapon, 20))
	burst(contact, direction, count, rng)
	if armored: burst(contact,direction,8,rng,true)
	spatter_behind(contact, direction, .62 if dismembered else .36, rng)
	var floor_hit := world_ray(event.position + Vector3.UP * .2, event.position + Vector3.DOWN * 3.0)
	var pool: MeshInstance3D
	if not floor_hit.is_empty() and floor_hit.normal.y > .65:
		var radius := 1.28 if dismembered else (.95 if weapon == "shotgun" else .78)
		pool = surface_patch(floor_hit.position, floor_hit.normal, Vector2.ONE * radius * 2,
			profile.pools, 2, 2, 1, 9, rng.randf_range(0,TAU), false)
		if is_instance_valid(pool): pool.set_meta("death_pool",true)
	var body_parts := int(profile.gib_counts.get(kind,12)) if dismembered else (3 if weapon == "shotgun" else 2)
	var presentation := "rupture" if dismembered else ("blast-collapse" if weapon == "shotgun" else ("cleave" if weapon == "melee" else "collapse"))
	for i in body_parts:
		var part := part_spec(kind,i,dismembered)
		var flying := Sprite3D.new(); flying.layers = 2
		flying.texture = part.texture; flying.hframes = part.columns; flying.vframes = part.rows; flying.frame = part.cell
		flying.pixel_size = float(part.size.y) / (flying.texture.get_height() / float(flying.vframes))
		var width_scale := float(part.size.x) / ((flying.texture.get_width() / float(flying.hframes)) * flying.pixel_size)
		flying.scale.x = width_scale
		flying.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		flying.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD; flying.alpha_scissor_threshold = .12
		flying.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		flying.shaded = false; flying.modulate = part.tint
		flying.set_meta("anatomical_part",part.name); flying.set_meta("enemy_kind",kind); flying.set_meta("hit_material",part.material)
		add_child(flying)
		var origin: Vector3 = contact if type == "corpse_gib" else event.position
		var height := .5 if part.name in ["head","jaw"] else (-.35 if part.name == "leg" else .12)
		if type == "corpse_gib": height *= .25
		flying.global_position = origin + Vector3(rng.randf_range(-.24,.24),height+rng.randf_range(-.08,.08),rng.randf_range(-.16,.16))
		var force := (4.4 if weapon == "shotgun" else 2.8) if dismembered else 1.5
		force += minf(float(event.get("overkill",0)) * .015,1.8)
		if part.material == "armor": force *= .72
		var side := direction.cross(Vector3.UP).normalized()
		var velocity := direction * rng.randf_range(force*.65,force) + side * rng.randf_range(-force*.55,force*.55) + Vector3.UP * rng.randf_range(2.8,5.0)
		append_particle({"node":flying,"velocity":velocity,"age":0.0,"life":3.2,"gib":true,"cell":part.cell,"size":part.size,"texture":part.texture,"columns":part.columns,"rows":part.rows,"tint":part.tint,"part":part.name,"material":part.material,"rotation":rng.randf_range(0,TAU),"spin":rng.randf_range(-12,12),"width_scale":width_scale,"blood":false,"bounces":0})
	var record := {"weapon":weapon,"enemy_kind":kind,"presentation":presentation,"gibbed":dismembered,"part_count":body_parts,"pool":pool,"shot_id":event.get("shot_id",0),"damage":event.get("damage",0),"overkill":event.get("overkill",0),"corpse_bursts":0}
	if type == "corpse_gib":
		death_records[target].gibbed = true; death_records[target].corpse_bursts = 1
		death_records[target].part_count += body_parts; death_records[target].presentation = "corpse-rupture"
	else: death_records[target] = record

func part_spec(kind: String, index: int, dismembered: bool) -> Dictionary:
	# Authored original atlas cells: head, ribs, arm, leg, organ and flesh shards.
	# Species weights expose different silhouettes and hardware without recoloring source files.
	var names := ["head","ribcage","arm","leg","organ","jaw","spine","flesh"]
	var hardware := {"vessel":"containment","ironbound":"armor","censer":"furnace","reaver":"carapace","surveyor":"hardware"}
	var atlas: Dictionary = profile.species_atlases.get(kind,{})
	var authored: Array = atlas.get("parts",[])
	var spec: Dictionary = authored[index % authored.size()].duplicate() if not authored.is_empty() else {}
	var name := String(spec.get("name", names[index % names.size()] if dismembered else ("flesh" if index==0 else "leg")))
	var material := String(spec.get("material", "armor" if hardware.has(kind) and index >= 8 and index % 2 == 0 else "flesh"))
	if material == "armor" and not spec.has("name"): name = hardware.get(kind,"armor")
	var texture: Texture2D = atlas.get("texture",profile.remains)
	var columns := int(atlas.get("columns",4)); var rows := int(atlas.get("rows",2))
	var cell := int(spec.get("cell",index % 8 if dismembered else (7 if index==0 else 3)))
	var regions: Dictionary = atlas.get("regions",{})
	if regions.has(name):
		var region: Variant = regions[name]
		var rectangle: Rect2 = region if region is Rect2 else Rect2(region[0],region[1],region[2],region[3])
		var cache_key := "%s:%s" % [texture.resource_path if not texture.resource_path.is_empty() else str(texture.get_instance_id()),rectangle]
		if not part_texture_cache.has(cache_key):
			var cropped := AtlasTexture.new(); cropped.atlas = texture; cropped.region = rectangle; cropped.filter_clip = true
			part_texture_cache[cache_key] = cropped
		texture = part_texture_cache[cache_key]; columns = 1; rows = 1; cell = 0
	var size: Vector2 = spec.get("size",Vector2(.48,.64) if dismembered else Vector2(.28,.38))
	if name in ["ribcage","furnace","containment"]: size *= 1.25
	if name in ["organ","flesh","jaw"]: size *= .65
	var tint: Color = spec.get("tint",Color(.72,.72,.72) if material == "flesh" else Color(.52,.52,.5))
	return {"name":name,"material":material,"texture":texture,"columns":columns,"rows":rows,"cell":cell,"size":size,"tint":tint}

func burst(point: Vector3, direction: Vector3, count: int, rng: RandomNumberGenerator, sparks: bool = false) -> void:
	var side := direction.cross(Vector3.UP).normalized()
	if side.length_squared() < .5: side = Vector3.RIGHT
	var up := side.cross(direction).normalized()
	for i in count:
		var node := MeshInstance3D.new(); node.mesh = spark_mesh if sparks else drop_mesh
		node.layers = 2
		add_child(node); node.global_position = point + side * rng.randf_range(-.08,.08) + up * rng.randf_range(-.08,.08)
		node.scale = Vector3.ONE * rng.randf_range(.7,1.7)
		var speed := rng.randf_range(3.5,8.0)
		var velocity := direction * speed + side * rng.randf_range(-2.8,2.8) + up * rng.randf_range(-1.4,2.4) + Vector3.UP * .8
		append_particle({"node":node,"velocity":velocity,"age":0.0,"life":.3 if sparks else .95,"gib":false,"blood":not sparks,"bounces":0,"splat":i % 3 == 0})

func append_particle(particle: Dictionary) -> void:
	if particles.size() >= profile.max_particles:
		# Preserve anatomical silhouettes during a crowded volley; transient droplets
		# yield the budget before larger physical pieces do.
		var oldest := -1
		for index in particles.size():
			if not particles[index].gib: oldest = index; break
		if oldest < 0 and not particle.gib:
			particle.node.queue_free(); return
		if oldest < 0: oldest = 0
		var old: Dictionary = particles[oldest]; particles.remove_at(oldest)
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
				if p.bounces < 2 and (hit.normal.y < .65 or p.velocity.length() > 2.7):
					p.velocity = (p.velocity as Vector3).bounce(hit.normal) * (.22 if p.material == "armor" else .34)
					p.node.global_position = hit.position + hit.normal * .02
					p.bounces += 1
					continue
				settle_gib(p,hit)
			elif p.blood and p.splat:
				surface_patch(hit.position,hit.normal,Vector2.ONE * .24,profile.pools,2,2,0,4,p.age * 7,false)
			p.node.queue_free(); particles.remove_at(i); continue
		p.node.global_position = to
		if p.gib:
			p.rotation += delta * p.spin
			p.node.rotation.z = p.rotation
			p.node.scale.x = p.width_scale * (.7 + .3 * absf(cos(p.age * p.spin * .6)))
		if p.age >= p.life:
			if p.gib:
				var floor_hit := world_ray(to + Vector3.UP, to + Vector3.DOWN * 4)
				if not floor_hit.is_empty(): settle_gib(p,floor_hit)
			p.node.queue_free(); particles.remove_at(i)

func settle_gib(p: Dictionary, hit: Dictionary) -> void:
	if hit.normal.y <= .65: return
	var patch := surface_patch(hit.position,hit.normal,p.size,p.texture,p.columns,p.rows,p.cell,4,p.rotation,true)
	if is_instance_valid(patch):
		patch.set_meta("anatomical_part",p.part); patch.set_meta("hit_material",p.material)
		patch.set_meta("settled",true)
		var material := (patch.material_override as StandardMaterial3D).duplicate()
		material.albedo_color = p.tint; patch.material_override = material

func spatter_behind(point: Vector3, direction: Vector3, size: float, rng: RandomNumberGenerator) -> void:
	var side := direction.cross(Vector3.UP).normalized()
	if side.length_squared() < .5: side = Vector3.RIGHT
	# One wide core splat plus smaller directional flecks, stopped by real world surfaces.
	for i in 5:
		var spread := Vector3.ZERO if i == 0 else side * rng.randf_range(-.24,.24) + Vector3.UP * rng.randf_range(-.17,.18)
		var fan := (direction + spread).normalized()
		var hit := world_ray(point + fan * .04, point + fan * rng.randf_range(2.8,4.0))
		if not hit.is_empty():
			var scale_value := 1.0 if i == 0 else rng.randf_range(.18,.35)
			surface_patch(hit.position,hit.normal,Vector2(1.25,.8) * size * 2 * scale_value,profile.pools,2,2,0,5,rng.randf_range(0,TAU),false)

func world_ray(from: Vector3, to: Vector3) -> Dictionary:
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,to,1))

func surface_patch(center: Vector3, normal: Vector3, extent: Vector2, texture: Texture2D, columns: int, rows: int, cell: int, grid: int, angle: float, is_remains: bool) -> MeshInstance3D:
	# Compatibility has no projected Decal node. Sample the shared world geometry,
	# omit unsupported triangles and split at risers; blood cannot bridge thin air.
	var tangent := normal.cross(Vector3.FORWARD).normalized()
	if tangent.length_squared() < .5: tangent = normal.cross(Vector3.RIGHT).normalized()
	tangent = tangent.rotated(normal,angle)
	var bitangent := normal.cross(tangent).normalized()
	# Sprite3D understands AtlasTexture rectangles. A 3D material receives the
	# source GPU texture RID, so settled mesh UVs must explicitly address that rect.
	var render_texture: Texture2D = texture
	var source_region := Rect2(Vector2.ZERO,texture.get_size())
	if texture is AtlasTexture:
		render_texture = texture.atlas; source_region = texture.region
	var source_uv_rect := Rect2(source_region.position / render_texture.get_size(),source_region.size / render_texture.get_size())
	var points: Array = []; var normals: Array[Vector3] = []; var uvs: Array[Vector2] = []
	for y in grid:
		for x in grid:
			var uv := Vector2(x / float(grid-1), y / float(grid-1))
			var probe := center + tangent * (uv.x-.5) * extent.x + bitangent * (uv.y-.5) * extent.y
			var hit := world_ray(probe + normal * .32,probe - normal * .42)
			var lift := .026 if is_remains else .009
			points.append(hit.position + hit.normal * lift - center if not hit.is_empty() and hit.normal.dot(normal) > .92 else null)
			normals.append(hit.normal if not hit.is_empty() else normal)
			var cell_uv := (uv + Vector2(cell % columns, cell / columns)) / Vector2(columns,rows)
			uvs.append(source_uv_rect.position + cell_uv * source_uv_rect.size)
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
	var material_key := "%s:%s" % [render_texture.resource_path if not render_texture.resource_path.is_empty() else str(render_texture.get_instance_id()), is_remains]
	if not material_cache.has(material_key):
		var material := StandardMaterial3D.new(); material.albedo_texture = render_texture
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.alpha_scissor_threshold = .12; material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		material.roughness = .88
		if is_remains:
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.albedo_color = Color(.72,.72,.72)
		material_cache[material_key] = material
	var mesh := MeshInstance3D.new(); mesh.mesh = surface.commit(); mesh.material_override = material_cache[material_key]
	mesh.layers = 2
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.set_meta("gore_remains",is_remains); mesh.set_meta("surface_normal",normal); mesh.set_meta("cell",cell)
	mesh.set_meta("source_texture_path",render_texture.resource_path); mesh.set_meta("source_region",source_region); mesh.set_meta("source_uv_rect",source_uv_rect)
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
