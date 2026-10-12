extends "check_balance_release.gd"
## Bounded additive v6 native checks; inherited historical probe stays unchanged.
func native_audio_value(v: Variant) -> Variant:
	if v is Resource:return v.resource_path
	if v is StringName:return String(v)
	if v is Array:
		var result: Array=[]
		for item in v:result.append(native_audio_value(item))
		return result
	return v
func inspect_v6_audio() -> void:
	var contract: Dictionary=expected.v6
	var profile: Resource=load("res://resources/combat_audio.tres")
	check(profile.cues.size()==57,"V6 native exactly48 prior +9 specified cue resources")
	for key in contract.profile_properties:check(native_audio_value(profile.get(key))==contract.profile_properties[key],"V6 prior profile property unchanged "+key)
	for index in 48:
		var cue: Resource=profile.cues[index]
		for key in contract.prior_cues[index]:check(native_audio_value(cue.get(key))==contract.prior_cues[index][key],"V6 prior native cue/stream unchanged "+String(cue.identifier)+" "+key)
	for index in 9:
		var cue: Resource=profile.cues[48+index]
		var id: String=contract.added_cues[index]
		var item: Dictionary=contract.new_audio_manifest.cues[id]
		check(String(cue.identifier)==id and cue.bus==&"UI" and not cue.spatial and cue.gain_db==0 and cue.variations.size()==1,"V6 specified UI/nonspatial receipt "+id)
		check(cue.variations[0].resource_path==item.runtime,"V6 native designed receipt stream "+id)
func all_nodes(node: Node) -> Array[Node]:
	var result: Array[Node]=[node]
	for child in node.get_children():result.append_array(all_nodes(child))
	return result
func inspect_v6_scene(path: String, inspector: SceneTree) -> void:
	var world: Node3D=load(path).instantiate();root.add_child(world)
	var before: Dictionary=expected.v6.pickup_baseline.scenes[path].pickups
	var moves: Dictionary=expected.v6.positions.scenes.get(path,{})
	var seen: Dictionary={};var props: Dictionary={};var rooms: Dictionary={}
	var theme: String=String(world.get_meta("stage_id"))
	for node in world.get_children():
		if node.has_meta("stage_pickup"):
			var name:=String(node.name);seen[name]=true
			check(before.has(name),path+" V6 original pickup root exists "+name)
			if not before.has(name):continue
			var meta: Dictionary={}
			for key in node.get_meta_list():meta[String(key)]=inspector.native_value(node.get_meta(key))
			check(inspector.same_value(before[name].metadata,meta),path+" V6 exact original pickup kind/amount/allmetadata "+name)
			var position: Array=moves[name].expected_position if moves.has(name) else before[name].position
			check(node.position==Vector3(position[0],position[1],position[2]),path+" V6 exact original or independently derived native position "+name)
			inspector.inspect_pickup(node,String(node.get_meta("stage_pickup")),path)
		if node.has_meta("stage_room") and expected.v6.rooms.has(path):
			var id:=String(node.get_meta("stage_room"));rooms[id]=true
			var entry: Dictionary=expected.v6.rooms[path][id]
			check(node.position==Vector3(entry.position[0],entry.position[1],entry.position[2]),path+" V6 original room centres/heights "+id)
			check(node.get_meta("room_bounds")==Vector3(entry.bounds[0],entry.bounds[1],entry.bounds[2]),path+" V6 explicit authored compact/core native footprint "+id)
			check(String(node.get_meta("room_function"))==entry.function and String(node.get_meta("layout_mode"))==entry.layout_mode,path+" V6 authored room function/layout "+id)
		if node.has_meta("room_program_object"):
			var id:=String(node.get_meta("room_program_object"));props[id]=true
			check(expected.v6.props[path].has(id),path+" V6 planned physical fitting instance "+id)
			if not expected.v6.props[path].has(id):continue
			var entry: Dictionary=expected.v6.props[path][id]
			check(String(node.get_meta("prop_type"))==entry.type and String(node.get_meta("room_function"))==entry.function and String(node.get_meta("layout_mode"))==entry.layout_mode,path+" V6 fitting type/purpose fields "+id)
			var physical_count:=0
			for part in all_nodes(node):
				if part is StaticBody3D:
					physical_count+=1
					var visual: MeshInstance3D=part.get_node("Visual")
					var collision: CollisionShape3D=part.get_node("Collision")
					check(visual.mesh.size==collision.shape.size if visual.mesh is BoxMesh else visual.mesh.height==collision.shape.height and visual.mesh.bottom_radius==collision.shape.radius,path+" V6 visible/physical part dimensions "+String(part.name))
					check(String(part.get_meta("hit_material")) in ["hard","armor"],path+" V6 explicit physical impact field "+String(part.name))
				if part is MeshInstance3D:
					var material: Material=part.mesh.surface_get_material(0)
					if not material is ShaderMaterial:continue
					check(material.shader.resource_path=="res://shaders/room_prop_local_uv.gdshader",path+" V6 actual per-face UV shader "+String(part.name))
					var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(material.shader.get_code().to_utf8_buffer())
					check(hash.finish().hex_encode()==expected.v6.shader_sha256,path+" V6 loaded shader matches frozen source")
					var atlas: Texture2D=material.get_shader_parameter("painted_surface")
					check(atlas.resource_path==expected.v6.prop_atlases[theme].path,path+" V6 theme-owned painted prop source")
					var rect: Vector4=material.get_shader_parameter("source_region_pixels")
					check([rect.x,rect.y,rect.z,rect.w] in expected.v6.prop_atlases[theme].regions,path+" V6 explicit native prop region")
					check(bool(material.get_shader_parameter("box_mesh_uv"))==(part.mesh is BoxMesh),path+" V6 actual native cube-unwrapped/cylinder sampler mode")
			check(physical_count>0,path+" V6 furnishing has actual physical parts "+id)
	check(seen.size()==before.size(),path+" V6 exact original pickup roster")
	if expected.v6.rooms.has(path):check(rooms.size()==expected.v6.rooms[path].size() and props.size()==expected.v6.props[path].size(),path+" V6 full authored room/fitting inventory")
	for item in expected.v6.progression.get(path,[]):
		var id: String=item.id
		var object: Node=world.get_node_or_null(("Button_" if item.type=="switch" else "Door_" if item.type=="gate" else "Key_" if item.type=="key" else "ExitControl")+ (id if item.type!="exit" else ""))
		check(object!=null,path+" V6 actual planned progression object "+id)
		if object==null:continue
		if item.type=="switch":check(String(object.get_meta("stage_button")) in item.sets and native_audio_value(object.get_meta("requires"))==item.requires,path+" V6 native switch flags "+id)
		elif item.type=="gate":check(String(object.get_meta("stage_door"))==id and native_audio_value(object.get_meta("requires"))==item.requires,path+" V6 native gate requirements "+id)
		elif item.type=="key":check(String(object.get_meta("stage_pickup"))==id,path+" V6 native key identity "+id)
		else:check(object.get_meta("stage_exit") and native_audio_value(object.get_meta("requires"))==item.requires,path+" V6 native final exit requirements")
	world.free()
func inspect_v6() -> void:
	inspect_v6_audio()
	var inspector: SceneTree=load(get_script().resource_path.get_base_dir().path_join("check_pickup_art_v6.gd")).new()
	inspector.manifest=expected.v6.pickup_manifest
	var texture: Texture2D=load(inspector.manifest.atlas)
	check(inspector.pixel_hash(texture.get_image())==inspector.manifest.native_rgba8_sha256,"V6 actual imported original pickup atlas pixels")
	for theme in expected.v6.prop_atlases:
		var entry: Dictionary=expected.v6.prop_atlases[theme]
		var prop_texture: Texture2D=load(entry.path)
		check(inspector.pixel_hash(prop_texture.get_image())==entry.rgba8_sha256,"V6 actual native byte-original painted prop pixels "+theme)
	for path in expected.v6.pickup_baseline.scenes:inspect_v6_scene(path,inspector)
	report.checks+=inspector.checks
	for failure in inspector.failures:report.failures.append(failure)
	report.v6={"source_intent":"docs/room-program-v6/levels.json authored before creation","exact_original_asset_pins":77,"prior_native_cues":48,"added_UI_cues":9,"pickup_roots":711,"authorized_side_room_supply_moves":158,"explicit_compact_rooms":55,"planned_physical_fittings":508,"pickup_art_checks":inspector.checks,"scope":"Native loaded resource/physical-presentation contracts. Separate controlled images and ordinary routes are required for visual/movement judgments."}
	inspector.free()
func run() -> void:
	inspect_v6()
	await super.run()
