extends RefCounted
## One-time bounded raster triangulation. No image changes or alpha-derived materials.
static var frame_cache: Dictionary = {}
static var image_cache: Dictionary = {}

## Native integer rectangles may partition atlases whose dimensions do not
## divide evenly. Rendering and queries consume this same source rectangle.
static func frame_region(texture: Texture2D, columns: int, rows: int, frame: int, data: Dictionary) -> Rect2i:
	var regions: Dictionary = data.get("source_regions", {})
	var supplied: Variant = regions.get(str(frame), regions.get(frame, null))
	if supplied is Array:
		assert(supplied.size() == 4)
		var rect := Rect2i(int(supplied[0]), int(supplied[1]), int(supplied[2]), int(supplied[3]))
		assert(rect.size.x > 0 and rect.size.y > 0 and Rect2i(Vector2i.ZERO, Vector2i(texture.get_size())).encloses(rect))
		return rect
	var size := Vector2i(texture.get_width() / columns, texture.get_height() / rows)
	return Rect2i(Vector2i((frame % columns) * size.x, (frame / columns) * size.y), size)

static func build(texture: Texture2D, columns: int, rows: int, frame: int, pixels: float, foot: Vector2, data: Dictionary) -> Dictionary:
	# File-backed atlases reuse one cache entry across retry-created Texture resources.
	var texture_key := texture.resource_path if not texture.resource_path.is_empty() else "memory:%d" % texture.get_instance_id()
	var signature := "%s:%d:%d:%d:%s:%s:%s" % [texture_key, columns, rows, frame, pixels, foot, JSON.stringify(data)]
	if frame_cache.has(signature): return frame_cache[signature]
	if not image_cache.has(texture_key):
		var source := texture.get_image()
		if source.is_compressed(): source.decompress()
		image_cache[texture_key] = source
	var image: Image = image_cache[texture_key]
	var source_region := frame_region(texture, columns, rows, frame, data)
	var width := source_region.size.x
	var height := source_region.size.y
	var limit: Array = data.get("hurt_resolution", [128, 192])
	var grid := Vector2i(mini(width, clampi(int(limit[0]), 1, 128)), mini(height, clampi(int(limit[1]), 1, 192)))
	var origin := source_region.position
	var threshold: float = data.get("alpha_threshold", 0.5)
	var regions: Dictionary = data.get("hurt_material_regions", {})
	var entries: Array = regions.get(str(frame), regions.get(frame, regions.get("default", [])))
	var default_material := StringName(data.get("hurt_material_default", "flesh"))
	var geometry: Dictionary = {}
	var opaque := 0
	for y in grid.y:
		var start := 0
		var current: StringName = &""
		for x in range(grid.x + 1):
			var material: StringName = &""
			if x < grid.x:
				var uv := Vector2((x + 0.5) / grid.x, (y + 0.5) / grid.y)
				var sample := origin + Vector2i(mini(width - 1, int(uv.x * width)), mini(height - 1, int(uv.y * height)))
				if image.get_pixelv(sample).a >= threshold:
					opaque += 1
					material = default_material
					for region in entries:
						if inside_region(uv, region): material = StringName(region.get("material", default_material))
			if material != current:
				if current != &"":
					if not geometry.has(current): geometry[current] = PackedVector3Array()
					var left := (float(start) / grid.x * width - foot.x) * pixels
					var right := (float(x) / grid.x * width - foot.x) * pixels
					var top := (foot.y - float(y) / grid.y * height) * pixels
					var bottom := (foot.y - float(y + 1) / grid.y * height) * pixels
					var faces: PackedVector3Array = geometry[current]
					faces.append_array(PackedVector3Array([Vector3(left, top, 0), Vector3(right, top, 0), Vector3(right, bottom, 0), Vector3(left, top, 0), Vector3(right, bottom, 0), Vector3(left, bottom, 0)]))
					geometry[current] = faces
				start = x; current = material
	var shapes := {}
	for material in geometry:
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(geometry[material]); shape.backface_collision = true
		shapes[material] = shape
	var result := {"shapes": shapes, "grid": grid, "opaque_cells": opaque, "frame": frame, "source_region": source_region}
	frame_cache[signature] = result
	return result

static func inside_region(uv: Vector2, region: Dictionary) -> bool:
	if region.has("rect"):
		var rect: Array = region.rect
		return Rect2(rect[0], rect[1], rect[2], rect[3]).has_point(uv)
	if region.has("polygon"):
		var points := PackedVector2Array()
		for point in region.polygon: points.append(Vector2(point[0], point[1]))
		return Geometry2D.is_point_in_polygon(uv, points)
	return false
