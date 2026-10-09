extends SceneTree
## Read-only native PNG registration. No source pixel transforms or runtime edits.
## tools/godot.sh --headless --script tools/register_style_atlas.gd -- \
##   --source=/absolute/atlas.png --width=1536 --height=1024 \
##   --output=res://verification/style-v2/s03/registration.json [--layout=/absolute/layout.json]
## Optional reviewed layout: {"pose_frames": {...}, "contact_regions": {"0": [x,y,w,h]}}.
## Contact regions constrain anatomical foot/contact selection only; images stay intact.
const COLUMNS := 4
const ROWS := 2
const THRESHOLD := 0.5
const STANDING_HEIGHT := 1.8

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args: Dictionary = {}
	for argument in OS.get_cmdline_user_args():
		var parts := argument.trim_prefix("--").split("=", true, 1)
		if parts.size() == 2: args[parts[0]] = parts[1]
	for required in ["source", "width", "height", "output"]:
		if not args.has(required):
			push_error("Missing --" + required + "=value"); quit(2); return
	var image := Image.load_from_file(args.source)
	if image == null:
		push_error("Cannot load source PNG"); quit(2); return
	var expected := Vector2i(int(args.width), int(args.height))
	if image.get_size() != expected or expected.x % COLUMNS != 0 or expected.y % ROWS != 0:
		push_error("Exact supplied dimensions and integral 4x2 cells required"); quit(2); return
	var layout: Dictionary = {}
	if args.has("layout"):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(args.layout))
		if not parsed is Dictionary:
			push_error("Layout must be a JSON dictionary"); quit(2); return
		layout = parsed
	var cell := Vector2i(expected.x / COLUMNS, expected.y / ROWS)
	var records: Array = []
	var pivots: Dictionary = {}
	var failures: Array = []
	for frame in 8:
		var record := inspect_cell(image, cell, frame, layout.get("contact_regions", {}).get(str(frame), []))
		records.append(record)
		var registered_pivot: Array = record.contact_pivot.duplicate()
		if layout.has("horizontal_registration_x"):
			registered_pivot[0] = float(layout.horizontal_registration_x)
		record.registered_foot_pivot = registered_pivot
		pivots[str(frame)] = registered_pivot
		for reason in record.quality_failures: failures.append("frame %d: %s" % [frame, reason])
	var standing_pixels: int = records[0].alpha_bounds[3]
	if standing_pixels <= 0:
		push_error("Frame 0 has no standing silhouette"); quit(2); return
	var registered_pixels := STANDING_HEIGHT / float(standing_pixels)
	var options := {
		"rows": ROWS,
		"pose_frames": layout.get("pose_frames", {"chase": [0, 1, 2], "windup": [3], "recovery": [4], "pain": [5], "dead": [6, 7]}),
		"frame_pivots": pivots,
		"hurt_resolution": [128, 192],
		"alpha_threshold": THRESHOLD,
		"hurt_material_default": "flesh",
		"material_regions": {}
	}
	var report := {
		"source": args.source,
		"source_sha256": FileAccess.get_sha256(args.source),
		"source_dimensions": [expected.x, expected.y],
		"source_cell_dimensions": [cell.x, cell.y],
		"source_has_alpha": image.detect_alpha() != Image.ALPHA_NONE,
		"source_pixels_unchanged": true,
		"alpha_threshold": THRESHOLD,
		"bounds_format": "local x,y,width,height; right/bottom exclusive",
		"contact_policy": "bottom occupied pixel boundary; x center of occupied bottom 3 rows within optional reviewed contact region",
		"registered_pixel_size": registered_pixels,
		"reference_standing_frame": 0,
		"reference_standing_height_m": STANDING_HEIGHT,
		"frames": records,
		"quality_pass": failures.is_empty(),
		"quality_failures": failures,
		"review_required": "Root must inspect anatomy, pose order, isolated neighbor fragments, and all contact candidates before accepting; automated gates cannot establish art approval.",
		"directional_limitation": "Eight representative frontal poses only; full directional production remains pending.",
		"unsealed_registration": {
			"file": args.source, "columns": COLUMNS, "directions": 1, "clips": {},
			"source_dimensions": [expected.x, expected.y], "sha256": FileAccess.get_sha256(args.source),
			"pixel_size": registered_pixels, "foot_pivot": pivots["0"], "sprite_options": options
		}
	}
	var output_path: String = ProjectSettings.globalize_path(args.output)
	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	var output := FileAccess.open(output_path, FileAccess.WRITE)
	if output == null:
		push_error("Cannot write report"); quit(2); return
	output.store_string(JSON.stringify(report, "  ") + "\n")
	output.close()
	print("ATLAS_REGISTRATION_%s: %s; exact %dx%d; cells %dx%d; pixel_size=%s" % ["OK" if failures.is_empty() else "REJECTED", args.output, expected.x, expected.y, cell.x, cell.y, registered_pixels])
	quit(0 if failures.is_empty() else 1)

func inspect_cell(image: Image, size: Vector2i, frame: int, reviewed_region: Array) -> Dictionary:
	var origin := Vector2i((frame % COLUMNS) * size.x, (frame / COLUMNS) * size.y)
	var minimum := size
	var maximum := Vector2i(-1, -1)
	var opaque := 0
	var partial := 0
	var nonzero := 0
	var edge_nonzero := 0
	var edge_opaque := 0
	var edge_alpha_max := 0.0
	var edge_opaque_locations: Array = []
	var mask := PackedByteArray()
	mask.resize(size.x * size.y)
	for y in size.y:
		for x in size.x:
			var alpha := image.get_pixelv(origin + Vector2i(x, y)).a
			if alpha > 0.0:
				nonzero += 1
				if x == 0 or y == 0 or x == size.x - 1 or y == size.y - 1:
					edge_nonzero += 1
					edge_alpha_max = maxf(edge_alpha_max, alpha)
					if alpha >= THRESHOLD:
						edge_opaque += 1
						edge_opaque_locations.append([x, y, alpha])
			if alpha > 0.0 and alpha < THRESHOLD: partial += 1
			if alpha >= THRESHOLD:
				mask[y * size.x + x] = 1
				opaque += 1
				minimum = minimum.min(Vector2i(x, y)); maximum = maximum.max(Vector2i(x, y))
	var failures: Array = []
	if opaque == 0: failures.append("empty alpha>=0.5 silhouette")
	if edge_opaque > 0: failures.append("alpha>=0.5 cell edge: opaque clipping or neighboring pose spill")
	var contact_rect := Rect2i(Vector2i.ZERO, size)
	if reviewed_region.size() == 4:
		contact_rect = Rect2i(int(reviewed_region[0]), int(reviewed_region[1]), int(reviewed_region[2]), int(reviewed_region[3])).intersection(contact_rect)
	var bottom := -1
	for y in range(contact_rect.position.y, contact_rect.end.y):
		for x in range(contact_rect.position.x, contact_rect.end.x):
			if mask[y * size.x + x] == 1: bottom = maxi(bottom, y)
	var contact_left := size.x
	var contact_right := -1
	for y in range(maxi(contact_rect.position.y, bottom - 2), bottom + 1):
		for x in range(contact_rect.position.x, contact_rect.end.x):
			if mask[y * size.x + x] == 1:
				contact_left = mini(contact_left, x); contact_right = maxi(contact_right, x)
	if bottom < 0: failures.append("reviewed contact region has no alpha>=0.5 pixels")
	var background_partial := 0
	var background_alpha_bins := {"above_0.01": 0, "above_0.05": 0, "above_0.1": 0, "above_0.25": 0}
	var padded_bounds := Rect2i(minimum - Vector2i(4, 4), maximum - minimum + Vector2i(9, 9))
	for y in size.y:
		for x in size.x:
			if not padded_bounds.has_point(Vector2i(x, y)):
				var alpha := image.get_pixelv(origin + Vector2i(x, y)).a
				if alpha > 0.0 and alpha < THRESHOLD:
					background_partial += 1
					for threshold in [0.01, 0.05, 0.1, 0.25]:
						if alpha > threshold: background_alpha_bins["above_" + str(threshold)] += 1
	# Sub-byte feathering is not a background box. Reject broad measurable halos,
	# and expose all alpha counts for the root's source-art acceptance review.
	if background_alpha_bins["above_0.05"] > int(size.x * size.y * 0.01):
		failures.append("broad semitransparent background outside opaque bounds (>1% cell at alpha>0.05)")
	var components := connected_components(mask, size)
	var significant := 0
	for count in components:
		if count >= maxi(16, int(opaque * 0.01)): significant += 1
	if significant > 1: failures.append("multiple significant disconnected silhouettes: inspect neighboring arms/fragments")
	return {
		"frame": frame, "cell_origin": [origin.x, origin.y],
		"alpha_bounds": [minimum.x, minimum.y, maxi(0, maximum.x - minimum.x + 1), maxi(0, maximum.y - minimum.y + 1)],
		"contact_pivot": [(contact_left + contact_right + 1) * 0.5, bottom + 1],
		"contact_is_reviewed_region": reviewed_region.size() == 4,
		"pose_role": "corpse_ground_contact" if frame >= 6 else "stance_foot_contact",
		"opaque_pixels": opaque, "nonzero_alpha_pixels": nonzero,
		"subthreshold_pixels": partial, "cell_edge_nonzero_pixels": edge_nonzero,
		"cell_edge_opaque_pixels": edge_opaque, "cell_edge_alpha_max": edge_alpha_max,
		"cell_edge_opaque_locations": edge_opaque_locations,
		"background_subthreshold_pixels": background_partial,
		"background_alpha_bins": background_alpha_bins,
		"connected_component_pixel_counts": components,
		"quality_failures": failures
	}

func connected_components(mask: PackedByteArray, size: Vector2i) -> Array:
	var seen := PackedByteArray()
	seen.resize(mask.size())
	var counts: Array = []
	for start in mask.size():
		if mask[start] == 0 or seen[start] == 1: continue
		var queue := PackedInt32Array([start])
		seen[start] = 1
		var cursor := 0
		while cursor < queue.size():
			var position := queue[cursor]
			cursor += 1
			var x := position % size.x
			var y := position / size.x
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var neighbor := Vector2i(x + dx, y + dy)
					if neighbor.x < 0 or neighbor.x >= size.x or neighbor.y < 0 or neighbor.y >= size.y: continue
					var index := neighbor.y * size.x + neighbor.x
					if mask[index] == 1 and seen[index] == 0:
						seen[index] = 1; queue.append(index)
		counts.append(queue.size())
	counts.sort(); counts.reverse()
	return counts
