extends SceneTree
## Loaded native resources and root pickup preservation, not regex scene checks.
var manifest: Dictionary = {}
var report_path := "res://verification/pickup-art-v6/source-audit.json"
var baseline_path := "res://verification/pickup-art-v6/pickup-baseline.json"
var record_baseline := false
var fingerprint_only := ""
var authorized: Dictionary = {}
var checks := 0
var failures: Array[String] = []
var scenes: Dictionary = {}
var old: Dictionary = {}
var kinds: Dictionary = {}
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--record-baseline": record_baseline = true
		elif arg.begins_with("--fingerprint-only="): fingerprint_only = arg.trim_prefix("--fingerprint-only=")
		elif arg.begins_with("--report="): report_path = arg.trim_prefix("--report=")
		elif arg.begins_with("--baseline="): baseline_path = arg.trim_prefix("--baseline=")
	call_deferred("run")
func verify(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label); push_error("PICKUP_ART_FAILED: "+label)
func xyz(v: Vector3) -> Array: return [v.x,v.y,v.z]
func native_value(value: Variant) -> Variant:
	if value is Vector3: return xyz(value)
	if value is StringName or value is NodePath: return String(value)
	return value
func same_value(expected: Variant, actual: Variant) -> bool:
	if (expected is int or expected is float) and (actual is int or actual is float):return float(expected)==float(actual)
	if expected is Dictionary and actual is Dictionary:
		if expected.size()!=actual.size():return false
		for key in actual:
			if not expected.has(key) or not same_value(expected[key],actual[key]):return false
		return true
	if expected is Array and actual is Array:
		if expected.size()!=actual.size():return false
		for index in actual.size():
			if not same_value(expected[index],actual[index]):return false
		return true
	return expected==actual
func pixel_hash(source: Image) -> String:
	var image := source.duplicate()
	if image.is_compressed(): image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	var hash := HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(image.get_data()); return hash.finish().hex_encode()
func meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D: result.append(node)
	for child in node.get_children(): result.append_array(meshes(child))
	return result
func inspect_pickup(item: Node3D, kind: String, scene: String) -> void:
	var canonical: String = manifest.aliases.get(kind,kind)
	if not manifest.items.has(canonical): return
	var label := scene+"/"+String(item.name)
	kinds[canonical] = int(kinds.get(canonical,0))+1
	verify(item.get_node_or_null("Case")==null and item.get_node_or_null("Mark")==null,label+" replaced flat fallback and floating label")
	var presentation: Node3D = item.get_node_or_null("PresentationV6")
	verify(presentation!=null,label+" actual presentation exists")
	if presentation==null:return
	verify(presentation.position==Vector3.ZERO,label+" visual root does not move pickup")
	verify(String(presentation.get_meta("atlas_source_sha256",""))==manifest.source_sha256,label+" source hash metadata")
	var record: Dictionary = manifest.items[canonical]
	var found := meshes(presentation)
	verify(found.size()==6 if record.geometry=="box" else found.size()==19,label+" actual closed 3D geometry mesh count")
	if record.geometry=="key":
		verify(presentation.get_node("OpenBow").mesh is TorusMesh,label+" actual open metallic key bow")
		verify(presentation.has_node("Shaft") and presentation.has_node("Tooth0") and presentation.has_node("Tooth1"),label+" extruded key shaft and teeth")
	else:
		var size := Vector3(record.size[0],record.size[1],record.size[2])
		var box: Node3D = presentation.get_node("AmmoBox")
		verify(box.get_node("Front").position.is_equal_approx(Vector3(0,0,size.z/2)) and box.get_node("Back").position.is_equal_approx(Vector3(0,0,-size.z/2)),label+" separated front and back planes")
		verify(box.get_node("Right").position.is_equal_approx(Vector3(size.x/2,0,0)) and box.get_node("Left").position.is_equal_approx(Vector3(-size.x/2,0,0)),label+" separated side planes")
		verify(box.get_node("Top").position.is_equal_approx(Vector3(0,size.y/2,0)) and box.get_node("Bottom").position.is_equal_approx(Vector3(0,-size.y/2,0)),label+" separated top and bottom planes")
	for mesh in found:
		verify(mesh.get_node_or_null("Collision")==null,label+" visuals add no collider")
		var material: StandardMaterial3D = mesh.mesh.surface_get_material(0)
		verify(material!=null and material.albedo_texture is AtlasTexture,label+" native atlas material "+String(mesh.name))
		if material==null or not material.albedo_texture is AtlasTexture:continue
		var texture: AtlasTexture = material.albedo_texture
		verify(material.texture_filter==BaseMaterial3D.TEXTURE_FILTER_NEAREST and not material.texture_repeat and texture.filter_clip,label+" nearest native clipping "+String(mesh.name))
		verify(texture.atlas.resource_path==manifest.atlas,label+" atlas ownership "+String(mesh.name))
		var slot := "metal" if record.geometry=="key" else ("side" if String(mesh.name) in ["Right","Left"] else ("top" if String(mesh.name) in ["Top","Bottom"] else "front"))
		var rect: Array = record.regions[slot]
		verify(texture.region==Rect2(rect[0],rect[1],rect[2],rect[3]),label+" actual native source rectangle "+slot)
		var canvas: Array = manifest.source_canvas
		verify(material.uv1_scale.is_equal_approx(Vector3((float(rect[2])-1)/canvas[0],(float(rect[3])-1)/canvas[1],1)) and material.uv1_offset.is_equal_approx(Vector3((float(rect[0])+.5)/canvas[0],(float(rect[1])+.5)/canvas[1],0)),label+" actual 3D UV maps only native region pixel centers "+slot)
func inspect_scene(path: String) -> void:
	var world: Node3D = load(path).instantiate(); root.add_child(world)
	var records: Dictionary = {}
	for node in world.get_children():
		if not node is Node3D or not node.has_meta("stage_pickup"):continue
		var metadata: Dictionary = {}
		for key in node.get_meta_list():metadata[String(key)] = native_value(node.get_meta(key))
		var kind := String(node.get_meta("stage_pickup"))
		var record := {"position":xyz(node.position),"metadata":metadata}
		records[String(node.name)] = record
		if not record_baseline:
			var expected: Dictionary = old.scenes[path].pickups.get(String(node.name),{})
			var previous: Array = expected.get("position",[])
			var relocation: Dictionary = authorized.get("scenes",{}).get(path,{}).get(String(node.name),{})
			if not relocation.is_empty():previous=relocation.expected_position
			verify(previous.size()==3 and node.position==Vector3(previous[0],previous[1],previous[2]),path+"/"+String(node.name)+(" independently derived authorized side-room Z position" if not relocation.is_empty() else " exact original native root position"))
			# JSON numbers load as floats. Compare exact numeric values recursively,
			# preserving keys/types otherwise, rather than native integer identity.
			verify(same_value(expected.get("metadata",{}),metadata),path+"/"+String(node.name)+" exact original root name/amount/all metadata")
			inspect_pickup(node,kind,path)
	if not record_baseline:verify(records.size()==old.scenes[path].pickups.size(),path+" exact pickup roster")
	scenes[path] = {"scene_sha256":FileAccess.get_sha256(path),"pickups":records}
	world.free()
func save(path: String, value: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path,FileAccess.WRITE); file.store_string(JSON.stringify(value,"  ")+"\n"); file.close()
func run() -> void:
	if not fingerprint_only.is_empty():
		var image := Image.load_from_file(fingerprint_only)
		verify(image!=null and not image.is_empty(),"Native PNG decoder succeeded")
		if image==null or image.is_empty():quit(1);return
		save(report_path,{"status":"passed","dimensions":[image.get_width(),image.get_height()],"source_sha256":FileAccess.get_sha256(fingerprint_only),"native_rgba8_sha256":pixel_hash(image)})
		quit();return
	if not record_baseline:
		manifest = JSON.parse_string(FileAccess.get_file_as_string("res://resources/pickups/presentation-v6.json"))
		old = JSON.parse_string(FileAccess.get_file_as_string(baseline_path))
		if FileAccess.file_exists("res://docs/pickup-art-v6/authorized-positions.json"):authorized=JSON.parse_string(FileAccess.get_file_as_string("res://docs/pickup-art-v6/authorized-positions.json"))
		if FileAccess.file_exists(manifest.atlas):verify(FileAccess.get_sha256(manifest.atlas)==manifest.source_sha256,"Byte-original atlas source SHA256")
		var texture: Texture2D = load(manifest.atlas)
		verify(texture.get_width()==manifest.source_canvas[0] and texture.get_height()==manifest.source_canvas[1],"Native canvas dimensions")
		verify(pixel_hash(texture.get_image())==manifest.native_rgba8_sha256,"Loaded native imported pixel bytes equal original PNG RGBA8 fingerprint")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/campaign/catalog.json"))
	for chapter in catalog.chapters:
		for level in chapter.levels:inspect_scene(level.scene)
	var standalone: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/stages/catalog.json"))
	for stage in standalone.stages:inspect_scene(stage.scene)
	verify(scenes.size()==12,"All nine campaign and three standalone scenes loaded")
	if record_baseline:save(baseline_path,{"scope":"Actual loaded pre-v6 root pickup names, local positions and all metadata. No pickup source edits.","scenes":scenes})
	else:
		for kind in ["pistol","shells","rivets","rockets","brass","red"]:verify(int(kinds.get(kind,0))>0,"Actual supported kind present: "+kind)
	save(report_path,{"status":"passed" if failures.is_empty() else "failed","checks":checks,"failures":failures,"record_baseline":record_baseline,"scope":"Loaded native twelve-scene resources, original PNG/imported pixels, exact pickup root preservation and perpendicular textured 3D faces/key geometry. No ordinary input route or collection/gameplay claim.","script_sha256":FileAccess.get_sha256("res://tools/check_pickup_art_v6.gd"),"manifest_sha256":FileAccess.get_sha256("res://resources/pickups/presentation-v6.json") if not record_baseline else "","baseline_sha256":FileAccess.get_sha256(baseline_path),"kinds":kinds,"scenes":scenes})
	print("PICKUP_ART_NATIVE_OK: ",checks," checks; failures=",failures.size()," baseline=",record_baseline)
	quit(0 if failures.is_empty() else 1)
