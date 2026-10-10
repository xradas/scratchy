extends SceneTree
## Native painted-parts gallery uses the production surface mesh/material path.
var evidence_dir := "res://verification/expansion-v1/gore/full-art/gallery"
var failures: Array[String] = []
class Controller:
	extends Node3D
	var camera: Camera3D
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-dir="): evidence_dir = arg.trim_prefix("--evidence-dir=")
	call_deferred("run")
func check(value: bool, label: String) -> void:
	if not value: failures.append(label); push_error(label)
func run() -> void:
	if DisplayServer.get_name() != "headless": root.set_flag(Window.FLAG_NO_FOCUS,true)
	DirAccess.make_dir_recursive_absolute(evidence_dir)
	var owner := Controller.new(); root.add_child(owner)
	owner.camera = Camera3D.new(); owner.add_child(owner.camera); owner.camera.current = true
	owner.camera.projection = Camera3D.PROJECTION_ORTHOGONAL; owner.camera.size = 9
	owner.camera.position = Vector3(0,10,0); owner.camera.rotation_degrees = Vector3(-90,0,0)
	var floor_body := StaticBody3D.new(); floor_body.collision_layer = 1; floor_body.collision_mask = 0; owner.add_child(floor_body)
	var collision := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = Vector3(12,.2,8); collision.shape = box; floor_body.add_child(collision); floor_body.position.y = -.1
	var visible := MeshInstance3D.new(); var mesh := BoxMesh.new(); mesh.size = box.size; visible.mesh = mesh; floor_body.add_child(visible)
	var floor_mat := StandardMaterial3D.new(); floor_mat.albedo_color = Color(.24,.25,.24); floor_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; visible.material_override = floor_mat
	var gore: Node3D = preload("res://scripts/combat_gore.gd").new(); owner.add_child(gore); gore.setup(owner,load("res://resources/gore_profile.tres"))
	var regions := {4:Rect2(55,542,347,428),5:Rect2(449,611,295,313),6:Rect2(825,542,239,427),7:Rect2(1133,526,361,457)}
	var records: Array[Dictionary] = []
	await physics_frame; await physics_frame
	for theme in ["pale_ward","ash_citadel","occupied_line"]:
		gore.reset(); await process_frame
		var source: Texture2D = load("res://assets/effects/gore-v2/%s-parts-atlas.png"%theme)
		check(source.get_size() == Vector2(1536,1024),"native untouched4×2 atlas dimensions")
		var cells: Array[Dictionary] = []
		for cell in 8:
			var rect := Rect2((cell%4)*384,(cell/4)*512,384,512)
			if theme == "ash_citadel" and regions.has(cell): rect = regions[cell]
			var cropped := AtlasTexture.new(); cropped.atlas = source; cropped.region = rect; cropped.filter_clip = true
			check(cropped.get_rid() == source.get_rid(),"AtlasTexture shares source GPU texture; explicit UV conversion required")
			var at := Vector3((cell%4-1.5)*1.8,0,(cell/4-.5)*2.0)
			var patch: MeshInstance3D = gore.surface_patch(at,Vector3.UP,Vector2(1.5,1.7),cropped,1,1,0,4,0,true)
			check(is_instance_valid(patch),"native source cell produces real settled floor mesh")
			if not is_instance_valid(patch): continue
			var mat := (patch.material_override as StandardMaterial3D).duplicate(); mat.albedo_color = Color.WHITE; patch.material_override = mat
			check(mat.albedo_texture == source,"settled material receives original source texture")
			var expected := Rect2(rect.position/source.get_size(),rect.size/source.get_size())
			var uvs: PackedVector2Array = patch.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
			var low := Vector2(INF,INF); var high := Vector2(-INF,-INF)
			for uv in uvs: low = low.min(uv); high = high.max(uv)
			check(low.is_equal_approx(expected.position) and high.is_equal_approx(expected.end),"floor UVs address precise original cell/approved tight rectangle")
			cells.append({"cell":cell,"native_source_rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"uv_min":[low.x,low.y],"uv_max":[high.x,high.y],"base_texture_path":mat.albedo_texture.resource_path})
		await process_frame; await process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(evidence_dir.path_join(theme+"-settled-native.png")) == OK,"native thematic ground-parts capture")
		records.append({"theme":theme,"cells":cells,"native_source_sha256":FileAccess.get_sha256(source.resource_path)})
	var file := FileAccess.open(evidence_dir.path_join("uv-contract.json"),FileAccess.WRITE)
	if file: file.store_string(JSON.stringify({"themes":records,"failures":failures,"source_pixels_unchanged":true},"  ")); file.close()
	print("GORE_NATIVE_ART_", "OK" if failures.is_empty() else "FAILED", " ",JSON.stringify({"themes":records.size(),"native_cells":24,"failures":failures}))
	owner.queue_free(); await process_frame; quit(0 if failures.is_empty() else 1)
