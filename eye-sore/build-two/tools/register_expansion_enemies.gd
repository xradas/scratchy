extends "res://tools/register_style_atlas.gd"
## Native, read-only 4x4 atlas measurement; writes a candidate for root review.
## --kind=ironbound --source=res://assets/enemies/expansion-v1/ironbound-atlas.png
## --layout=res://verification/expansion-v1/enemies/ironbound-layout.json
## --width=1536 --height=2048 [--output=res://verification/expansion-v1/enemies/ironbound-candidate.json]
## Layout requires manually authored material_regions for all 16 cells (empty
## corpse arrays allowed), contact_regions optional, projectile_origin_uv optional.
const HEIGHTS := {"ironbound": 2.05, "censer": 1.6, "reaver": 2.15, "surveyor": 2.2}
const POSES := {"chase": [0, 8, 9], "windup": [10], "recovery": [11, 12], "pain": [13], "dead": [14, 15]}

func run() -> void:
	var args: Dictionary = {}
	for argument in OS.get_cmdline_user_args():
		var parts := argument.trim_prefix("--").split("=", true, 1)
		if parts.size() == 2: args[parts[0]] = parts[1]
	if args.get("global_components", "false") == "true": report_global_components(args); return
	for key in ["kind", "source", "layout", "width", "height"]:
		if not args.has(key): push_error("Missing --" + key); quit(2); return
	var kind := String(args.kind)
	if not HEIGHTS.has(kind): push_error("Unknown expansion enemy kind"); quit(2); return
	var image := Image.load_from_file(args.source)
	var layout_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(args.layout))
	if image == null or not layout_value is Dictionary: push_error("Missing native PNG or authored layout JSON"); quit(2); return
	var layout: Dictionary = layout_value
	var expected := Vector2i(int(args.width), int(args.height))
	if image.get_size() != expected or expected.x < 4 or expected.y < 4:
		push_error("Supplied exact dimensions must match native atlas"); quit(2); return
	var failures: Array = []
	if image.detect_alpha() == Image.ALPHA_NONE: failures.append("Source lacks transparent alpha")
	var source_regions: Dictionary = layout.get("source_regions", {})
	if source_regions.is_empty():
		for frame in 16:
			var column := frame % 4; var row := frame / 4
			var x := roundi(column * expected.x / 4.0); var y := roundi(row * expected.y / 4.0)
			var right := roundi((column + 1) * expected.x / 4.0); var bottom := roundi((row + 1) * expected.y / 4.0)
			source_regions[str(frame)] = [x, y, right - x, bottom - y]
	var records: Array = []
	var pivots: Dictionary = {}
	var materials: Dictionary = layout.get("material_regions", {})
	materials = materials.duplicate(true)
	for frame in 16:
		var supplied: Variant = source_regions.get(str(frame), null)
		if not supplied is Array or supplied.size() != 4: push_error("Every frame requires a native source rectangle"); quit(2); return
		var rect := Rect2i(int(supplied[0]), int(supplied[1]), int(supplied[2]), int(supplied[3]))
		if rect.size.x <= 0 or rect.size.y <= 0 or not Rect2i(Vector2i.ZERO, expected).encloses(rect): push_error("Invalid native source rectangle"); quit(2); return
		var cell := rect.size
		if layout.get("material_region_space", "region") == "rounded_uniform_grid":
			var column := frame % 4; var row := frame / 4
			var old_origin := Vector2(roundi(column * expected.x / 4.0), roundi(row * expected.y / 4.0))
			var old_size := Vector2(roundi((column + 1) * expected.x / 4.0), roundi((row + 1) * expected.y / 4.0)) - old_origin
			for region in materials.get(str(frame), []):
				if region.has("polygon"):
					for i in region.polygon.size():
						var point := Vector2(region.polygon[i][0], region.polygon[i][1])
						point = (old_origin + point * old_size - Vector2(rect.position)) / Vector2(rect.size)
						region.polygon[i] = [point.x, point.y]
				elif region.has("rect"):
					var old: Array = region.rect
					var pos := (old_origin + Vector2(old[0], old[1]) * old_size - Vector2(rect.position)) / Vector2(rect.size)
					var extent := Vector2(old[2], old[3]) * old_size / Vector2(rect.size)
					region.rect = [pos.x, pos.y, extent.x, extent.y]
		# Temporary read-only measurement view; no source or output pixels written.
		var record := inspect_cell(image.get_region(rect), cell, 0, layout.get("contact_regions", {}).get(str(frame), []))
		record.frame = frame; record.cell_origin = [rect.position.x, rect.position.y]
		record.pose_role = "corpse_ground_contact" if frame >= 14 else "stance_foot_contact"
		record.registered_foot_pivot = record.contact_pivot.duplicate()
		if layout.has("horizontal_registration_x"): record.registered_foot_pivot[0] = float(layout.horizontal_registration_x)
		record.source_region = [record.cell_origin[0], record.cell_origin[1], cell.x, cell.y]
		pivots[str(frame)] = record.registered_foot_pivot
		var reviewed_parts := false
		for approved_frame in layout.get("reviewed_disconnected_frames", []):
			if int(approved_frame) == frame: reviewed_parts = true
		for reason in record.quality_failures:
			if reason.begins_with("multiple significant disconnected") and reviewed_parts: continue
			failures.append("frame %d: %s" % [frame, reason])
		record.reviewed_disconnected_parts = reviewed_parts
		if not materials.has(str(frame)): failures.append("frame %d: missing manually authored material regions" % frame)
		var valid_regions: Array = []
		var authored_regions: Variant = materials.get(str(frame), [])
		if not authored_regions is Array:
			failures.append("frame %d: material regions must be an array" % frame)
		else:
			for region in authored_regions:
				if valid_material_region(region): valid_regions.append(region)
				else: failures.append("frame %d: invalid normalized flesh/armor material region" % frame)
		var material_counts := {"flesh": 0, "armor": 0}
		for y in 192:
			for x in 128:
				var uv := Vector2((x + 0.5) / 128.0, (y + 0.5) / 192.0)
				var source_point := Vector2i(record.cell_origin[0], record.cell_origin[1]) + Vector2i(int(uv.x * cell.x), int(uv.y * cell.y))
				if image.get_pixelv(source_point).a < THRESHOLD: continue
				var material := "flesh"
				for region in valid_regions:
					if preload("res://scripts/sprite_hurt_geometry.gd").inside_region(uv, region): material = String(region.get("material", "flesh"))
				material_counts[material] = int(material_counts.get(material, 0)) + 1
		record.hurt_grid_material_cell_counts = material_counts
		if frame < 14 and (material_counts.flesh == 0 or material_counts.armor == 0): failures.append("frame %d: live flesh and armor mapping must both intersect opaque anatomy" % frame)
		records.append(record)
	var standing: int = records[0].alpha_bounds[3]
	if standing <= 0: push_error("Empty reference standing silhouette"); quit(2); return
	var pixel_size: float = HEIGHTS[kind] / standing
	var options := {"rows": 4, "source_regions": source_regions, "pose_frames": POSES, "direction_frames": [0, 1, 2, 3, 4, 5, 6, 7], "direction_count": 8,
		"frame_pivots": pivots, "hurt_resolution": [128, 192], "alpha_threshold": THRESHOLD,
		"hurt_material_default": "flesh", "material_regions": materials, "precache_frames": true}
	for key in ["projectile_origin_uv", "frame_projectile_origins_uv", "projectile_origin_local", "release_pose_seconds"]:
		if layout.has(key): options[key] = layout[key]
	var sha := FileAccess.get_sha256(args.source)
	var entry := {"file": args.source, "columns": 4, "directions": 8, "clips": {}, "pixel_size": pixel_size,
		"foot_pivot": pivots["0"], "sprite_options": options, "source_dimensions": [expected.x, expected.y],
		"source_regions": source_regions, "sha256": sha,
		"presentation": "Original-board-referenced transparent atlas. Eight directional movement facings, frontal combat sequence; root visual review required."}
	var report := {"enemies": {kind: entry}, "kind": kind, "source": args.source, "source_sha256": sha,
		"source_dimensions": [expected.x, expected.y], "source_regions": source_regions, "source_pixels_unchanged": true,
		"alpha_threshold": THRESHOLD, "reference_standing_frame": 0, "reference_standing_height_m": HEIGHTS[kind],
		"registered_pixel_size": pixel_size, "frames": records, "authored_layout": args.layout,
		"authored_layout_sha256": FileAccess.get_sha256(args.layout), "quality_pass": failures.is_empty(), "quality_failures": failures,
		"contact_policy": "Measured occupied alpha>=0.5 bottom boundary; center of occupied bottom three rows, within optional reviewed contact region.",
		"directional_limitation": "Eight single movement facings; combat animation is frontal. No synthesized animation or source pixel transforms.",
		"review_required": "Root must inspect anatomy, pose order, facing order, foot candidates and armor masks before merge; measurement is not art approval."}
	var output_path := String(args.get("output", "res://verification/expansion-v1/enemies/%s-candidate.json" % kind))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_path).get_base_dir())
	if FileAccess.file_exists(output_path):
		var previous_text := FileAccess.get_file_as_string(output_path)
		var previous: Variant = JSON.parse_string(previous_text)
		if previous is Dictionary and not bool(previous.get("quality_pass", true)):
			var archive_path := output_path.get_base_dir().path_join("%s-rejected-%s.json" % [kind, FileAccess.get_sha256(output_path).substr(0, 12)])
			var archive := FileAccess.open(archive_path, FileAccess.WRITE); archive.store_string(previous_text); archive.close()
			report.replaced_rejected_report = archive_path
	var output := FileAccess.open(output_path, FileAccess.WRITE)
	if output == null: push_error("Cannot write candidate"); quit(2); return
	output.store_string(JSON.stringify(report, "  ") + "\n"); output.close()
	print("EXPANSION_ENEMY_REGISTRATION_%s %s; %d failures; %s" % ["OK" if failures.is_empty() else "REJECTED", kind, failures.size(), output_path])
	quit(0 if failures.is_empty() else 1)

func valid_material_region(region: Variant) -> bool:
	if not region is Dictionary or not region.get("material", "") in ["flesh", "armor"]: return false
	if region.has("rect"):
		if not region.rect is Array or region.rect.size() != 4: return false
		for value in region.rect:
			if not (value is float or value is int) or not is_finite(float(value)): return false
		return float(region.rect[2]) > 0 and float(region.rect[3]) > 0
	if region.has("polygon"):
		if not region.polygon is Array or region.polygon.size() < 3: return false
		for point in region.polygon:
			if not point is Array or point.size() != 2: return false
			for value in point:
				if not (value is float or value is int) or not is_finite(float(value)): return false
		return true
	return false

func report_global_components(args: Dictionary) -> void:
	if not args.has("source") or not args.has("kind"): push_error("Global components requires source and kind"); quit(2); return
	var image := Image.load_from_file(args.source)
	if image == null: push_error("Missing native source image"); quit(2); return
	var size := image.get_size()
	var mask := PackedByteArray(); mask.resize(size.x * size.y)
	var opaque := 0
	for y in size.y:
		for x in size.x:
			if image.get_pixel(x, y).a >= THRESHOLD: mask[y * size.x + x] = 1; opaque += 1
	var seen := PackedByteArray(); seen.resize(mask.size())
	var components: Array = []
	var minimum_component := maxi(1, int(args.get("minimum_component_pixels", 16)))
	for start in mask.size():
		if mask[start] == 0 or seen[start] == 1: continue
		var queue := PackedInt32Array([start]); seen[start] = 1
		var minimum := size; var maximum := Vector2i(-1, -1)
		var cursor := 0
		while cursor < queue.size():
			var position := queue[cursor]; cursor += 1
			var x := position % size.x; var y := position / size.x
			minimum = minimum.min(Vector2i(x, y)); maximum = maximum.max(Vector2i(x, y))
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var point := Vector2i(x + dx, y + dy)
					if point.x < 0 or point.x >= size.x or point.y < 0 or point.y >= size.y: continue
					var index := point.y * size.x + point.x
					if mask[index] == 1 and seen[index] == 0: seen[index] = 1; queue.append(index)
		if queue.size() >= minimum_component:
			var extent := maximum - minimum + Vector2i.ONE
			components.append({"opaque_pixels": queue.size(), "global_bounds": [minimum.x, minimum.y, extent.x, extent.y],
				"over_one_percent_total_opaque": queue.size() > opaque * .01})
	components.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.opaque_pixels > b.opaque_pixels)
	var result := {"source": args.source, "source_sha256": FileAccess.get_sha256(args.source), "source_dimensions": [size.x, size.y],
		"alpha_threshold": THRESHOLD, "total_opaque_pixels": opaque, "minimum_recorded_component_pixels": minimum_component,
		"components": components, "components_at_least_16_pixels": components.filter(func(item: Dictionary) -> bool: return item.opaque_pixels >= 16),
		"bounds_format": "Global native x,y,width,height, right/bottom exclusive; no raster writes; root must assign parts to poses."}
	var output_path: String = args.get("output", "res://verification/expansion-v1/enemies/%s-global-components.json" % args.kind)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_path).get_base_dir())
	var file := FileAccess.open(output_path, FileAccess.WRITE); file.store_string(JSON.stringify(result, "  ") + "\n"); file.close()
	print("EXPANSION_GLOBAL_COMPONENTS_OK %s: %d measured components" % [args.kind, components.size()]); quit()
