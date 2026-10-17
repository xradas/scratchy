extends Node3D
const Chunk := preload("res://scripts/gore_chunk_v12.gd")
## Resolved hurt/death events own these effects. No damage or gameplay collision lives here.
var profile: GoreProfile
var combat: Node3D
var stains: Array[MeshInstance3D] = []
var remains: Array[MeshInstance3D] = []
var particles: Array[Dictionary] = []
var seen: Dictionary = {}
var death_records: Dictionary = {}
var explosion_origins: Dictionary = {}
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
	particles.clear(); stains.clear(); remains.clear(); seen.clear(); death_records.clear(); explosion_origins.clear()
	death_count = 0
	material_cache.clear(); part_texture_cache.clear(); Chunk.clear_cache()

func should_gib(weapon: StringName, overkill: float, material: StringName = &"flesh") -> bool:
	var threshold := profile.gib_overkill * (1.4 if material == &"armor" else 1.0)
	return (weapon in [&"shotgun", &"twin_shotgun", &"rivet_cannon", &"siege_launcher"] and overkill >= threshold) or overkill >= threshold * 3.0

func handle_event(event: Dictionary) -> void:
	var type := String(event.get("type", ""))
	if type == "ordnance_explosion":
		var shot := int(event.get("shot_id",0))
		if shot>0:
			explosion_origins[shot] = event.position
			if explosion_origins.size()>32: explosion_origins.erase(explosion_origins.keys()[0])
		return
	if type not in ["enemy_hurt", "enemy_death", "corpse_hurt", "corpse_gib"]: return
	var key := "%s:%s:%s" % [type, event.get("target_id", ""), event.get("shot_id", 0)]
	if seen.has(key): return
	seen[key] = true
	if seen.size() > 2048: seen.erase(seen.keys()[0])
	var rng := RandomNumberGenerator.new(); rng.seed = hash(key)
	var weapon := String(event.get("weapon_id", "pistol"))
	var blast_weapon := weapon in ["shotgun", "twin_shotgun", "siege_launcher"]
	var settings: Dictionary = profile.weapon_bursts.get(weapon,profile.weapon_bursts.get("pistol",{}))
	var direction: Vector3 = (event.get("direction", -combat.camera.global_basis.z) as Vector3).normalized()
	if weapon == "siege_launcher" and explosion_origins.has(int(event.get("shot_id",0))):
		var outward: Vector3 = event.position - explosion_origins[int(event.shot_id)]
		if outward.length_squared()>.000001: direction = outward.normalized()
	var contact: Vector3 = event.get("contact_position", event.position)
	var armored := String(event.get("material", "flesh")) == "armor"
	if type in ["enemy_hurt", "corpse_hurt"]:
		if armored:
			burst(contact, direction, int(profile.spark_counts.get(weapon,3)), rng, true, settings)
		else:
			burst(contact, direction, int(profile.spray_counts.get(weapon,16)), rng, false, settings)
			spatter_behind(contact, direction, .4 if blast_weapon else .22, rng)
		return
	var target := String(event.target_id)
	if type == "enemy_death" and death_records.has(target): return
	if type == "corpse_gib" and (not death_records.has(target) or death_records[target].get("gibbed",false)): return
	if type == "enemy_death": death_count += 1
	var dismembered: bool = event.get("gibbed", false)
	var kind := String(event.get("enemy_kind", "unsealed"))
	var count := int(profile.death_counts.get(weapon,26))
	if dismembered: count = mini(profile.max_burst_drops,count + profile.rupture_extra_drops)
	burst(contact, direction, count, rng, false, settings)
	if armored: burst(contact,direction,int(profile.spark_counts.get(weapon,3)),rng,true,settings)
	spatter_behind(contact, direction, .62 if dismembered else .36, rng)
	var floor_hit := world_ray(event.position + Vector3.UP * .2, event.position + Vector3.DOWN * 3.0)
	var pool: MeshInstance3D
	if not floor_hit.is_empty() and floor_hit.normal.y > .65:
		var radius := 1.28 if dismembered else (.95 if blast_weapon else .78)
		pool = surface_patch(floor_hit.position, floor_hit.normal, Vector2.ONE * radius * 2,
			profile.pools, 2, 2, 1, 9, rng.randf_range(0,TAU), false)
		if is_instance_valid(pool): pool.set_meta("death_pool",true)
	var body_parts := int(profile.gib_counts.get(kind,12)) if dismembered else 0
	var presentation := "rupture" if dismembered else ("blast-collapse" if blast_weapon else ("cleave" if weapon == "melee" else "collapse"))
	for i in body_parts:
		var part := part_spec(kind,i,dismembered)
		var flying := Chunk.create(part,rng)
		add_child(flying)
		var origin: Vector3 = contact if type == "corpse_gib" else event.position
		var height := .5 if part.name in ["head","jaw"] else (-.15 if part.name == "leg" else .12)
		if type == "corpse_gib": height = .28
		flying.global_position = origin + Vector3(rng.randf_range(-.16,.16),height+rng.randf_range(-.04,.04),rng.randf_range(-.12,.12))
		var force := float(settings.get("chunk_force",3.4)) + minf(float(event.get("overkill",0))*.015,1.8)
		if part.material == "armor": force *= .72
		var side := direction.cross(Vector3.UP).normalized()
		if side.length_squared()<.5: side=Vector3.RIGHT
		var velocity := direction * rng.randf_range(force*.65,force) + side * rng.randf_range(-force*.55,force*.55) + Vector3.UP * rng.randf_range(2.8,5.0)
		append_particle({"node":flying,"velocity":velocity,"age":0.0,"life":3.2,"gib":true,"part":part.name,"material":part.material,"spin":Vector3(rng.randf_range(-8,8),rng.randf_range(-10,10),rng.randf_range(-12,12)),"blood":false,"bounces":0})

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
	var texture: Texture2D = spec.get("texture",atlas.get("texture",profile.remains))
	var columns := int(spec.get("columns",atlas.get("columns",4))); var rows := int(spec.get("rows",atlas.get("rows",2)))
	var cell := int(spec.get("cell",index % 8 if dismembered else (7 if index==0 else 3)))
	var regions: Dictionary = {} if spec.has("texture") else atlas.get("regions",{})
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
	var result := {"name":name,"material":material,"texture":texture,"columns":columns,"rows":rows,"cell":cell,"size":size,"tint":tint,"enemy_kind":kind}
	if spec.has("coat_tint"): result.coat_tint = spec.coat_tint
	return result

func burst(point: Vector3, direction: Vector3, count: int, rng: RandomNumberGenerator, sparks: bool = false, settings: Dictionary = {}) -> void:
	var side := direction.cross(Vector3.UP).normalized()
	if side.length_squared() < .5: side = Vector3.RIGHT
	var up := side.cross(direction).normalized()
	for i in mini(count,profile.max_burst_drops):
		var node := MeshInstance3D.new(); node.mesh = spark_mesh if sparks else drop_mesh
		node.layers = 2
		add_child(node); node.global_position = point + side * rng.randf_range(-.08,.08) + up * rng.randf_range(-.08,.08)
		node.scale = Vector3.ONE * rng.randf_range(.7,1.7) * float(settings.get("size",1.0))
		var speeds: Vector2 = settings.get("speed",Vector2(5,9))
		var speed := rng.randf_range(speeds.x,speeds.y)
		var cone := float(settings.get("spread",.32)) * speed
		var velocity := direction * speed + side * rng.randf_range(-cone,cone) + up * rng.randf_range(-cone*.55,cone*.75) + Vector3.UP * .8
		append_particle({"node":node,"velocity":velocity,"age":0.0,"life":.3 if sparks else 1.15,"gib":false,"blood":not sparks,"bounces":0,"splat":i < profile.max_drop_stains_per_burst})

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
	if get_tree().paused: return
	for i in range(particles.size()-1,-1,-1):
		var p: Dictionary = particles[i]
		if not is_instance_valid(p.node): particles.remove_at(i); continue
		p.age += delta
		p.velocity.y -= profile.gravity * delta
		var from: Transform3D = p.node.global_transform
		var to := from
		to.origin += p.velocity * delta
		if p.gib:
			to.basis = from.basis.rotated(Vector3.RIGHT,p.spin.x*delta).rotated(Vector3.UP,p.spin.y*delta).rotated(Vector3.FORWARD,p.spin.z*delta)
		var hit: Dictionary
		if p.gib:
			hit = Chunk.sweep(get_world_3d().direct_space_state,p.node,from,to,1)
			if not hit.get("hit",false): hit = {}
		else: hit = world_sweep(from.origin,to.origin,.025*p.node.scale.x)
		if not hit.is_empty():
			if p.gib:
				p.node.global_transform = hit.get("transform",from)
				if hit.normal.y>.65 and (p.bounces>=2 or p.velocity.length()<3.0):
					if settle_gib(p,hit): particles.remove_at(i); continue
				p.velocity = (p.velocity as Vector3).bounce(hit.normal) * (.22 if p.material=="armor" else .34)
				p.spin *= .5; p.bounces += 1
				if p.age<p.life: continue
			elif p.blood and p.splat:
				surface_patch(hit.position,hit.normal,Vector2.ONE * .24,profile.pools,2,2,0,4,p.age*7,false)
			if not p.gib:
				p.node.queue_free(); particles.remove_at(i); continue
		else: p.node.global_transform = to
		if p.age>=p.life:
			# No unsupported snap: a piece only persists if real nearby support
			# can hold its full volume. Unsupported pieces expire cosmetically.
			if p.gib and settle_gib(p,{}): particles.remove_at(i); continue
			p.node.queue_free(); particles.remove_at(i)

func settle_gib(p: Dictionary, _hit: Dictionary) -> bool:
	var node: MeshInstance3D = p.node
	var support := Chunk.support_pose(get_world_3d().direct_space_state,node,node.global_position,node.global_rotation.y,1)
	if not support.get("supported",false): return false
	node.global_transform = support.transform
	node.set_meta("settled",true)
	if remains.size()>=profile.max_remains:
		var oldest: MeshInstance3D = remains.pop_front()
		if is_instance_valid(oldest): oldest.queue_free()
	remains.append(node)
	return true

func world_sweep(from: Vector3, to: Vector3, radius: float) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := Chunk.sphere_for(ceilf(maxf(radius,.008)*1000.0)/1000.0)
	query.shape=sphere; query.transform=Transform3D(Basis(),from); query.motion=to-from; query.collision_mask=1
	var overlap := space.get_rest_info(query)
	if not overlap.is_empty(): return {"position":overlap.point,"normal":overlap.normal}
	var fractions := space.cast_motion(query)
	if fractions[0]>=1.0: return {}
	query.transform.origin = from + (to-from) * minf(1.0,fractions[1]+.002)
	query.motion=Vector3.ZERO
	var contact := space.get_rest_info(query)
	if not contact.is_empty(): return {"position":contact.point,"normal":contact.normal}
	var ray := world_ray(from,to)
	if not ray.is_empty(): return ray
	# Conservative cast still stops a droplet if the tiny collider cannot
	# provide contact information at its exact boundary. No stain is invented.
	return {"position":from+(to-from)*fractions[0],"normal":-(to-from).normalized()}

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
