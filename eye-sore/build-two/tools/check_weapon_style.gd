extends SceneTree
## Read-only weapon atlas and registration audit. Accepts a candidate manifest before
## assets/combat_art.json is changed. Diagnostic PNGs are rendered by Godot.
## tools/godot.sh --headless --script tools/check_weapon_style.gd -- \
##   --manifest=/absolute/combat_art-candidate.json \
##   --evidence-dir=res://verification/weapon-style-v3

const WEAPONS := ["pistol", "shotgun", "melee"]
const PHASES := ["idle", "fire", "recover", "switch"]
const WINDOWS := [Vector2i(1280, 720), Vector2i(1560, 900), Vector2i(800, 600)]
const ALPHA_THRESHOLD := 0.02

var manifest_path := "res://assets/combat_art.json"
var evidence_dir := "res://verification/weapon-style-v3"
var failures: Array[String] = []
var checks := 0
var report: Dictionary = {"weapons": {}, "screens": [], "failures": []}

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--manifest="): manifest_path = argument.trim_prefix("--manifest=")
		if argument.begins_with("--evidence-dir="): evidence_dir = argument.trim_prefix("--evidence-dir=")
	call_deferred("run_check")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("WEAPON_STYLE_FAILED: " + message)

func absolute(path: String) -> String:
	return ProjectSettings.globalize_path(path) if path.begins_with("res://") or path.begins_with("user://") else path

func pair(values: Array) -> Vector2:
	return Vector2(float(values[0]), float(values[1]))

func rect_values(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]

func rgba_image(path: String) -> Image:
	var image := Image.load_from_file(absolute(path))
	if image != null and not image.is_empty(): image.convert(Image.FORMAT_RGBA8)
	return image

func inspect_region(image: Image, region: Rect2i, marker: Vector2) -> Dictionary:
	var minimum := Vector2i(region.size.x, region.size.y)
	var maximum := Vector2i(-1, -1)
	var occupied := 0
	var transparent := 0
	var partial := 0
	var solid := 0
	var edge := {"left": 0, "right": 0, "top": 0, "bottom": 0}
	var edge_positions := {"left": [], "right": [], "top": [], "bottom": []}
	var edge_nonzero_positions := {"left": [], "right": [], "top": [], "bottom": []}
	var corner_alpha: Array = []
	for point in [region.position, region.position + Vector2i(region.size.x - 1, 0), region.position + Vector2i(0, region.size.y - 1), region.end - Vector2i.ONE]:
		corner_alpha.append(image.get_pixelv(point).a)
	for y in region.size.y:
		for x in region.size.x:
			var alpha := image.get_pixel(region.position.x + x, region.position.y + y).a
			if alpha > 0.0:
				if x == 0: edge_nonzero_positions.left.append([x, y, alpha])
				if x == region.size.x - 1: edge_nonzero_positions.right.append([x, y, alpha])
				if y == 0: edge_nonzero_positions.top.append([x, y, alpha])
				if y == region.size.y - 1: edge_nonzero_positions.bottom.append([x, y, alpha])
			if alpha <= ALPHA_THRESHOLD:
				transparent += 1
				continue
			if alpha >= 0.98: solid += 1
			else: partial += 1
			occupied += 1
			minimum.x = mini(minimum.x, x)
			minimum.y = mini(minimum.y, y)
			maximum.x = maxi(maximum.x, x)
			maximum.y = maxi(maximum.y, y)
			if x == 0:
				edge.left += 1
				edge_positions.left.append([x, y])
			if x == region.size.x - 1:
				edge.right += 1
				edge_positions.right.append([x, y])
			if y == 0:
				edge.top += 1
				edge_positions.top.append([x, y])
			if y == region.size.y - 1:
				edge.bottom += 1
				edge_positions.bottom.append([x, y])
	var bounds := []
	if occupied > 0: bounds = [minimum.x, minimum.y, maximum.x - minimum.x + 1, maximum.y - minimum.y + 1]
	return {"alpha_threshold": ALPHA_THRESHOLD, "occupied_pixels": occupied, "transparent_pixels": transparent, "partial_alpha_pixels": partial, "solid_alpha_pixels": solid, "alpha_bounds_local": bounds, "edge_occupied_pixels": edge, "edge_positions_local": edge_positions, "edge_nonzero_positions_local": edge_nonzero_positions, "edge_positions_format": "[x,y] or [x,y,alpha] relative to registered region; add region origin for source atlas coordinate", "corner_alpha": corner_alpha, "marker_local": [marker.x, marker.y], "marker_alpha": image.get_pixelv(region.position + Vector2i(marker)).a}

func nearest_alpha(image: Image, region: Rect2i, point: Vector2) -> Dictionary:
	var nearest := Vector2i(-1, -1)
	var distance := INF
	var nearest_clear := Vector2i(-1, -1)
	var clear_distance := INF
	var center := Vector2i(point.round())
	for y in range(maxi(0, center.y - 48), mini(region.size.y, center.y + 49)):
		for x in range(maxi(0, center.x - 48), mini(region.size.x, center.x + 49)):
			var candidate := Vector2(x, y).distance_to(point)
			if image.get_pixel(region.position.x + x, region.position.y + y).a <= ALPHA_THRESHOLD:
				if candidate < clear_distance:
					clear_distance = candidate
					nearest_clear = Vector2i(x, y)
			elif candidate < distance:
				distance = candidate
				nearest = Vector2i(x, y)
	return {"anchor_local": [point.x, point.y], "nearest_occupied_local": [nearest.x, nearest.y] if nearest.x >= 0 else null, "distance_px": distance if nearest.x >= 0 else null, "nearest_transparent_local": [nearest_clear.x, nearest_clear.y] if nearest_clear.x >= 0 else null, "silhouette_boundary_distance_px": clear_distance if nearest_clear.x >= 0 else null, "search_radius_px": 48}

func inspect_separator(image: Image, recover: Array, switching: Array) -> Dictionary:
	var seam := int(switching[0])
	var first_y := int(recover[1])
	var last_y := mini(int(recover[1] + recover[3]), int(switching[1] + switching[3]))
	var columns: Array = []
	for x in range(maxi(0, seam - 24), mini(image.get_width(), seam + 25)):
		var exact_nonzero := 0
		var visible_occupied := 0
		for y in range(first_y, last_y):
			var alpha := image.get_pixel(x, y).a
			if alpha > 0.0: exact_nonzero += 1
			if alpha > ALPHA_THRESHOLD: visible_occupied += 1
		columns.append({"source_x": x, "exact_nonzero_rows": exact_nonzero, "visible_occupied_rows": visible_occupied})
	return {"seam_source_x": seam, "source_y_start": first_y, "source_y_end_exclusive": last_y, "columns": columns}

func overlay_cross(parent: Control, center: Vector2, color: Color, radius: float = 8.0) -> void:
	for dimensions in [Vector2(radius * 2.0 + 1.0, 1), Vector2(1, radius * 2.0 + 1.0)]:
		var line := ColorRect.new()
		line.color = color
		line.position = center - dimensions * 0.5
		line.size = dimensions
		parent.add_child(line)

func overlay_border(parent: Control, rect: Rect2, color: Color) -> void:
	var border := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = color
	style.set_border_width_all(2)
	border.add_theme_stylebox_override("panel", style)
	border.position = rect.position
	border.size = rect.size
	parent.add_child(border)

func render_diagnostic(atlas_path: String, image: Image, region: Rect2, weapon: String, phase: String, pose: Dictionary, anchor: Array, flash_path: String, flash_size: float, window: Vector2i, alpha_bounds: Array) -> Dictionary:
	var factor := minf(window.x / 640.0, window.y / 360.0)
	if factor >= 1.0: factor = floorf(factor)
	var world_rect := Rect2((Vector2(window) - Vector2(640, 360) * factor) * 0.5, Vector2(640, 360) * factor)
	var marker := pair(pose.marker)
	var target := pair(pose.target)
	var scale: float = world_rect.size.y / float(pose.source_canvas_height) * float(pose.scale)
	var weapon_rect := Rect2(world_rect.position + world_rect.size * target - marker * scale, region.size * scale)
	var silhouette_rect := Rect2(weapon_rect.position + pair(alpha_bounds.slice(0, 2)) * scale, pair(alpha_bounds.slice(2, 4)) * scale) if alpha_bounds.size() == 4 else Rect2()
	var flash_center := Vector2.ZERO
	var flash_rect := Rect2()
	if not anchor.is_empty():
		flash_center = weapon_rect.position + pair(anchor) * weapon_rect.size / Vector2(320, 180)
		var diameter := flash_size * world_rect.size.y / 360.0
		flash_rect = Rect2(flash_center - Vector2.ONE * diameter * 0.5, Vector2.ONE * diameter)
	var viewport := SubViewport.new()
	viewport.size = window
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var canvas := Control.new()
	canvas.size = window
	viewport.add_child(canvas)
	var background := ColorRect.new()
	background.color = Color("171c20")
	background.size = window
	canvas.add_child(background)
	var world := ColorRect.new()
	world.color = Color("333b3c")
	world.position = world_rect.position
	world.size = world_rect.size
	canvas.add_child(world)
	var atlas := ImageTexture.create_from_image(image)
	var frame := AtlasTexture.new()
	frame.atlas = atlas
	frame.region = region
	frame.filter_clip = true
	var sprite := TextureRect.new()
	sprite.texture = frame
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_SCALE
	sprite.position = weapon_rect.position
	sprite.size = weapon_rect.size
	canvas.add_child(sprite)
	overlay_border(canvas, weapon_rect, Color("efb751"))
	overlay_cross(canvas, world_rect.position + world_rect.size * target, Color("f6cb63"))
	if not anchor.is_empty():
		var flash_image := rgba_image(flash_path)
		if flash_image != null and not flash_image.is_empty():
			var flash_sprite := TextureRect.new()
			flash_sprite.texture = ImageTexture.create_from_image(flash_image)
			flash_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			flash_sprite.stretch_mode = TextureRect.STRETCH_SCALE
			flash_sprite.position = flash_rect.position
			flash_sprite.size = flash_rect.size
			canvas.add_child(flash_sprite)
		overlay_cross(canvas, flash_center, Color("ef6a5d"), 11.0)
	var label := Label.new()
	label.text = "FIXTURE %s %s | %dx%d | amber: marker/region  red: flash anchor" % [weapon, phase, window.x, window.y]
	label.position = Vector2(12, 10)
	canvas.add_child(label)
	for i in 3:
		await process_frame
		RenderingServer.force_draw(false)
	var output := evidence_dir.path_join("%s-%s-%dx%d.png" % [weapon, phase, window.x, window.y])
	var screenshot := viewport.get_texture().get_image()
	check(screenshot != null and not screenshot.is_empty() and screenshot.save_png(absolute(output)) == OK, "diagnostic render saved: " + output)
	viewport.free()
	return {"weapon": weapon, "phase": phase, "window": [window.x, window.y], "world_rect": rect_values(world_rect), "weapon_rect": rect_values(weapon_rect), "silhouette_rect": rect_values(silhouette_rect), "silhouette_visible_rect": rect_values(silhouette_rect.intersection(world_rect)), "marker_screen": [world_rect.position.x + world_rect.size.x * target.x, world_rect.position.y + world_rect.size.y * target.y], "flash_center": [flash_center.x, flash_center.y] if not anchor.is_empty() else null, "flash_rect": rect_values(flash_rect) if not anchor.is_empty() else null, "diagnostic_png": output}

func run_check() -> void:
	DirAccess.make_dir_recursive_absolute(absolute(evidence_dir))
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(absolute(manifest_path)))
	if not parsed is Dictionary:
		push_error("Manifest is not a JSON object: " + manifest_path)
		quit(2)
		return
	var art: Dictionary = parsed
	report.manifest = manifest_path
	report.manifest_sha256 = FileAccess.get_sha256(absolute(manifest_path))
	report.scope = "Raw PNG alpha/region audit and native-rendered fixture placement diagnostics; overlays are not actual main gameplay. Anatomy and visual style require human review."
	var flash: Dictionary = art.get("flash", {})
	for weapon in WEAPONS:
		var definition: Dictionary = art.get("weapon_atlases", {}).get(weapon, {})
		check(not definition.is_empty(), weapon + " atlas registration exists")
		if definition.is_empty(): continue
		var atlas_path: String = art.get("weapons", {}).get(weapon, {}).get("idle", "")
		check(not atlas_path.is_empty(), weapon + " idle PNG path exists")
		if atlas_path.is_empty(): continue
		var source_image := Image.load_from_file(absolute(atlas_path))
		var source_has_alpha := source_image != null and source_image.detect_alpha() != Image.ALPHA_NONE
		var image := rgba_image(atlas_path)
		check(image != null and not image.is_empty(), weapon + " raw PNG loads")
		if image == null or image.is_empty(): continue
		var dimensions := image.get_size()
		var expected: Array = definition.get("source_dimensions", definition.get("atlas_dimensions", [1536, 1024]))
		check(dimensions == Vector2i(int(expected[0]), int(expected[1])), weapon + " raw dimensions match registration")
		check(source_has_alpha, weapon + " raw PNG has alpha channel")
		if definition.has("sha256"): check(FileAccess.get_sha256(absolute(atlas_path)) == String(definition.sha256), weapon + " SHA256 matches registration")
		var weapon_report := {"path": atlas_path, "sha256": FileAccess.get_sha256(absolute(atlas_path)), "dimensions": [dimensions.x, dimensions.y], "regions": {}}
		for phase in PHASES:
			var path: String = art.get("weapons", {}).get(weapon, {}).get(phase, "")
			check(path == atlas_path, weapon + " " + phase + " uses registered atlas")
			var coordinates: Array = definition.get("regions", {}).get(phase, [])
			var pose: Dictionary = definition.get("placement", {}).get(phase, {})
			check(coordinates.size() == 4 and pose.has("marker") and pose.has("target") and pose.has("scale"), weapon + " " + phase + " has region and placement")
			if coordinates.size() != 4 or not pose.has("marker") or not pose.has("target") or not pose.has("scale"): continue
			var region := Rect2i(int(coordinates[0]), int(coordinates[1]), int(coordinates[2]), int(coordinates[3]))
			check(region.has_area() and Rect2i(Vector2i.ZERO, dimensions).encloses(region), weapon + " " + phase + " region inside raw PNG")
			if not region.has_area() or not Rect2i(Vector2i.ZERO, dimensions).encloses(region): continue
			var marker := pair(pose.marker)
			check(Rect2(Vector2.ZERO, region.size).has_point(marker), weapon + " " + phase + " marker inside region")
			var inspected := inspect_region(image, region, marker)
			check(inspected.occupied_pixels > 0, weapon + " " + phase + " has nontransparent art")
			check(inspected.corner_alpha.all(func(value): return value <= ALPHA_THRESHOLD), weapon + " " + phase + " corners transparent")
			# A touched side can indicate artwork cropped at a registered boundary.
			# Bottom contact can be intentional, so retain edge counts for review.
			check(inspected.edge_occupied_pixels.left == 0 and inspected.edge_occupied_pixels.right == 0 and inspected.edge_occupied_pixels.top == 0, weapon + " " + phase + " art clear of left/right/top clipping")
			if weapon == "shotgun" and phase in ["recover", "switch"]:
				var seam_side := "right" if phase == "recover" else "left"
				check(inspected.edge_nonzero_positions_local[seam_side].is_empty(), weapon + " " + phase + " revised separator has zero alpha on every row")
			var anchor_value = flash.get("anchors", {}).get(weapon, {}).get(phase, [])
			var anchor: Array = anchor_value if anchor_value is Array else []
			if weapon != "melee": check(anchor.size() == 2, weapon + " " + phase + " flash anchor registered")
			else: anchor = []
			var cell_index: int = int(definition.get("cells", {}).get(phase, -1))
			var columns: int = int(definition.get("columns", 2))
			var rows: int = int(definition.get("rows", 2))
			check(cell_index >= 0 and cell_index < columns * rows, weapon + " " + phase + " cell index valid")
			var cell_size := Vector2(dimensions) / Vector2(columns, rows)
			var cell_rect := Rect2(Vector2(cell_index % columns, cell_index / columns) * cell_size, cell_size)
			# Explicit regions take precedence over the nominal grid; older pistol
			# and shotgun top regions extend 32 pixels into the nominal lower cell.
			var region_inside_cell := cell_rect.encloses(Rect2(region))
			var tip := nearest_alpha(image, region, pair(anchor) * Vector2(region.size) / Vector2(320, 180)) if anchor.size() == 2 else {}
			var region_report := {"region": coordinates, "cell": cell_index, "nominal_cell_rect": rect_values(cell_rect), "region_inside_nominal_cell": region_inside_cell, "placement": pose, "alpha": inspected, "flash_anchor_320x180": anchor, "barrel_tip_proximity": tip}
			weapon_report.regions[phase] = region_report
			var render_pose := pose.duplicate()
			render_pose.source_canvas_height = definition.get("source_canvas_height", 860)
			for window in WINDOWS:
				report.screens.append(await render_diagnostic(atlas_path, image, Rect2(region), weapon, phase, render_pose, anchor, String(flash.get("file", "")), float(flash.get("world_size", 36)), window, inspected.alpha_bounds_local))
		if weapon == "shotgun" and weapon_report.regions.has("recover") and weapon_report.regions.has("switch"):
			weapon_report.lower_separator = inspect_separator(image, weapon_report.regions.recover.region, weapon_report.regions.switch.region)
		report.weapons[weapon] = weapon_report
	report.checks = checks
	report.failures = failures
	report.passed = failures.is_empty()
	var output := evidence_dir.path_join("weapon-style-audit.json")
	var file := FileAccess.open(absolute(output), FileAccess.WRITE)
	if file == null:
		push_error("Cannot write " + output)
		quit(2)
		return
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	print("WEAPON_STYLE_%s: %d checks, %d failures; report %s" % ["OK" if failures.is_empty() else "FAILED", checks, failures.size(), output])
	quit(0 if failures.is_empty() else 1)
