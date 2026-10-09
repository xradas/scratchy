extends SceneTree
## Native comparison of exact approved-board samples and the scene's real materials.
## Run: tools/godot.sh --script tools/capture_approved_materials.gd -- --evidence-dir=res://verification/grit
const SCENE := "res://scenes/pale_ward.tscn"
const SHEET_SIZE := Vector2i(1280, 1000)
const MATERIAL_NAMES := ["ceramic", "steel", "floor", "grate"]
var evidence_dir := "res://verification/grit"
var materials: Dictionary = {}
var report := {"status": "failed", "scene": SCENE, "renderer": "", "floor_source": "steel", "materials": []}

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-dir="):
			evidence_dir = argument.trim_prefix("--evidence-dir=")
	call_deferred("capture")

func fail_capture(message: String) -> void:
	report["error"] = message
	write_report()
	push_error("MATERIAL_PREVIEW_FAILED: " + message)
	quit(2)

func write_report() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence_dir))
	var file := FileAccess.open(evidence_dir.path_join("material-preview-report.json"), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "\t") + "\n")

func collect_materials(node: Node) -> void:
	if node is MeshInstance3D and node.mesh:
		for surface in node.mesh.get_surface_count():
			var material: Material = node.get_active_material(surface)
			if material is ShaderMaterial:
				for material_name in MATERIAL_NAMES:
					if material.resource_path.get_slice("::", 1) == material_name:
						materials[material_name] = material
	for child in node.get_children():
		collect_materials(child)

func label_at(parent: Control, text: String, point: Vector2, font_size := 18) -> void:
	var label := Label.new()
	label.text = text
	label.position = point
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.91, 0.92, 0.93))
	parent.add_child(label)

func lit_box(parent: Control, material: ShaderMaterial, point: Vector2) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(512, 172)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	root.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.12, 0.12, 0.12)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.65
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment_node.environment = environment
	world.add_child(environment_node)
	var light := DirectionalLight3D.new()
	light.light_color = Color.WHITE
	light.light_energy = 1.1
	light.rotation_degrees = Vector3(-40, -30, 0)
	light.shadow_enabled = false
	world.add_child(light)
	var box := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(2.4, 1.5, 1.5)
	mesh.material = material
	box.mesh = mesh
	world.add_child(box)
	var camera := Camera3D.new()
	camera.position = Vector3(2.7, 1.7, 3.7)
	camera.fov = 35.0
	camera.near = 0.05
	world.add_child(camera)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	var panel := TextureRect.new()
	panel.position = point
	panel.size = Vector2(512, 172)
	panel.texture = viewport.get_texture()
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(panel)

func capture() -> void:
	report["renderer"] = DisplayServer.get_name()
	if DisplayServer.get_name() == "headless":
		fail_capture("Headless display has no native framebuffer. Run with a graphical display (or Xvfb); no PNG was captured.")
		return
	var packed := load(SCENE) as PackedScene
	if packed == null:
		fail_capture("Cannot load pale_ward scene")
		return
	# Never add this instance to the tree: gameplay _ready/process never runs.
	var scene := packed.instantiate()
	collect_materials(scene)
	scene.free()
	if materials.size() != MATERIAL_NAMES.size():
		fail_capture("Expected all four scene ShaderMaterials; found " + str(materials.keys()))
		return
	root.size = SHEET_SIZE
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	var sheet := SubViewport.new()
	sheet.size = SHEET_SIZE
	sheet.disable_3d = true
	sheet.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sheet)
	var canvas := Control.new()
	canvas.size = Vector2(SHEET_SIZE)
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sheet.add_child(canvas)
	var background := ColorRect.new()
	background.color = Color(0.065, 0.07, 0.075)
	background.size = Vector2(SHEET_SIZE)
	canvas.add_child(background)
	label_at(canvas, "Approved source pixels / actual Pale Ward ShaderMaterials", Vector2(32, 14), 26)
	label_at(canvas, "Nearest filtering | white light | close camera | floor uses the steel sample", Vector2(32, 50), 18)
	label_at(canvas, "original sample", Vector2(220, 85), 20)
	label_at(canvas, "lit game material", Vector2(640, 85), 20)
	for index in MATERIAL_NAMES.size():
		var material_name: String = MATERIAL_NAMES[index]
		var material: ShaderMaterial = materials[material_name]
		var region: Vector4 = material.get_shader_parameter("source_region_pixels")
		var texture: Texture2D = material.get_shader_parameter("painted_surface")
		var y := 122.0 + index * 215.0
		label_at(canvas, material_name + (" (steel source)" if material_name == "floor" else ""), Vector2(32, y + 48))
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(region.x, region.y, region.z, region.w)
		atlas.filter_clip = true
		var sample := TextureRect.new()
		sample.texture = atlas
		sample.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sample.position = Vector2(220, y + 15)
		# Native source dimensions: one framebuffer pixel per original sample pixel.
		sample.size = Vector2(region.z, region.w)
		canvas.add_child(sample)
		label_at(canvas, "bounds: %d, %d / %d x %d px" % [region.x, region.y, region.z, region.w], Vector2(220, y + 136), 16)
		lit_box(canvas, material, Vector2(640, y))
		report["materials"].append({"name": material_name, "resource": material.resource_path, "source_texture": texture.resource_path, "region_pixels": [region.x, region.y, region.z, region.w], "sample_display_scale": 1})
	for frame in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := sheet.get_texture().get_image()
	if image == null or image.is_empty() or image.get_size() != SHEET_SIZE:
		fail_capture("Native viewport returned an empty or wrong-sized image")
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence_dir))
	var output := evidence_dir.path_join("material-preview-sheet.png")
	var error := image.save_png(output)
	if error != OK:
		fail_capture("Cannot save native PNG: " + error_string(error))
		return
	report["status"] = "captured"
	report["output"] = output
	report["size"] = [SHEET_SIZE.x, SHEET_SIZE.y]
	write_report()
	print("MATERIAL_PREVIEW_OK: " + output)
	quit(0)
