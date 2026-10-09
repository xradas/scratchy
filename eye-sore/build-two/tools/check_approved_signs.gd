extends SceneTree
## P15: validate original board signage without entering gameplay.
func _initialize() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/materials/approved-sign-regions.json"))
	if not require(FileAccess.get_sha256(manifest.source) == manifest.source_sha256, "Approved source pixels changed"):
		return
	var packed: PackedScene = load("res://scenes/pale_ward.tscn")
	var ward := packed.instantiate()
	for record in manifest.regions:
		var sign := ward.get_node(record.node) as MeshInstance3D
		if not require(sign != null, "Missing native signage: " + record.node):
			return
		if not require(sign.get_child_count() == 0, "Signage acquired children/collision"):
			return
		if not require(sign.position.is_equal_approx(Vector3(record.position[0], record.position[1], record.position[2])), "Sign placement changed"):
			return
		if not require(sign.rotation.is_equal_approx(Vector3.ZERO), "Sign front must face +Z"):
			return
		var quad := sign.mesh as QuadMesh
		if not require(quad != null and quad.orientation == PlaneMesh.FACE_Z, "Sign must use a +Z QuadMesh"):
			return
		if not require(quad.size.is_equal_approx(Vector2(record.size[0], record.size[1])), "Sign dimensions changed"):
			return
		var mat := quad.material as StandardMaterial3D
		if not require(mat != null, "Sign must use native StandardMaterial3D"):
			return
		if not require(mat.albedo_texture.resource_path == manifest.source, "Sign must sample the original board"):
			return
		if not require(mat.albedo_texture.get_width() == manifest.source_size_pixels[0] and mat.albedo_texture.get_height() == manifest.source_size_pixels[1], "Board dimensions changed"):
			return
		if not require(mat.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST, "Sign filtering must be nearest without mipmaps"):
			return
		if not require(not mat.texture_repeat, "Sign must not repeat"):
			return
		if not require(mat.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL and is_equal_approx(mat.roughness, record.roughness), "Sign surface shading changed"):
			return
		if not require(mat.cull_mode == BaseMaterial3D.CULL_BACK, "Sign front/back culling changed"):
			return
		var rect: Array = record.rect_pixels
		var expected_scale := Vector3(rect[2] / 1536.0, rect[3] / 1024.0, 1)
		var expected_offset := Vector3(rect[0] / 1536.0, rect[1] / 1024.0, 0)
		if not require(mat.uv1_scale.distance_to(expected_scale) < 0.000001, "Sign source crop scale changed"):
			return
		if not require(mat.uv1_offset.distance_to(expected_offset) < 0.000001, "Sign source crop offset changed"):
			return
	if not require(not ward.has_node("PierContainment") and not ward.has_node("PierArrow"), "Superseded generated signage remains"):
		return
	ward.free()
	print("P15_APPROVED_SIGNS_OK: two native quads preserve approved board regions, placement, shading and source hash")
	quit()

func require(condition: bool, message: String) -> bool:
	if not condition:
		push_error("P15_APPROVED_SIGNS_FAILED: " + message)
		quit(1)
	return condition
