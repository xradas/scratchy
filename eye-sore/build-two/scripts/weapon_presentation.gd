extends RefCounted
## Pure geometry for a first-person atlas pose. All returned points are native
## 640x360 weapon-layer coordinates; the camera and shot rays are untouched.

const NATIVE_SIZE := Vector2(640.0, 360.0)

static func point(values: Array) -> Vector2:
	return Vector2(float(values[0]), float(values[1]))

static func window_world_rect(window_size: Vector2) -> Rect2:
	var enlargement := minf(window_size.x / NATIVE_SIZE.x, window_size.y / NATIVE_SIZE.y)
	if enlargement >= 1.0: enlargement = floorf(enlargement)
	var display_size := NATIVE_SIZE * enlargement
	return Rect2((window_size - display_size) * 0.5, display_size)

static func to_window(native_point: Vector2, window_size: Vector2) -> Vector2:
	var world_rect := window_world_rect(window_size)
	return world_rect.position + native_point * world_rect.size / NATIVE_SIZE

static func line_x_at_y(breech: Vector2, muzzle: Vector2, y: float) -> float:
	if absf(muzzle.y - breech.y) < 0.001: return NAN
	return muzzle.x + (y - muzzle.y) * (muzzle.x - breech.x) / (muzzle.y - breech.y)

static func pose(placement: Dictionary, frame_size: Vector2, source_canvas_height: float, layer_size: Vector2 = NATIVE_SIZE, recoil: float = 0.0) -> Dictionary:
	var factor := layer_size.y / source_canvas_height * float(placement.get("scale", 1.0))
	var marker := point(placement.marker)
	var target := point(placement.get("target", [0.5, 0.64]))
	var origin := layer_size * target - marker * factor
	# The illustrated pose kicks down during recoil; recompute the horizontal
	# convergence from that translated barrel so its forward line still crosses
	# the fixed camera aim throughout the kick.
	origin.y += recoil * layer_size.y / 180.0
	var result := {"position": origin, "size": frame_size * factor, "scale": factor, "alignment_shift_x": 0.0}
	if placement.has("bore"):
		var bore: Dictionary = placement.bore
		var breech := origin + point(bore.breech) * factor
		var muzzle := origin + point(bore.muzzle) * factor
		var aim_x := line_x_at_y(breech, muzzle, layer_size.y * 0.5)
		if is_finite(aim_x) and bool(placement.get("align_bore", true)):
			var shift_x := layer_size.x * 0.5 - aim_x
			origin.x += shift_x
			result.alignment_shift_x = shift_x
			breech.x += shift_x
			muzzle.x += shift_x
		result.breech = breech
		result.muzzle = muzzle
		result.aim_x = line_x_at_y(breech, muzzle, layer_size.y * 0.5)
	result.position = origin
	return result
