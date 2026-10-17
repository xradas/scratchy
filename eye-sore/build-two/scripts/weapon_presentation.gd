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

static func pose(placement: Dictionary, frame_size: Vector2, source_canvas_height: float, layer_size: Vector2 = NATIVE_SIZE, recoil: float = 0.0, phase_progress: float = 0.0) -> Dictionary:
	var factor := layer_size.y / source_canvas_height * float(placement.get("scale", 1.0))
	# Optional continuous kick around an authored barrel vanishing point. Uniform
	# scaling around that fixed point keeps BOTH physical barrel axes aimed at
	# the camera; translating a twin barrel sprite cannot do that during recoil.
	var vanishing_kick := String(placement.get("recoil_mode", "translate")) == "vanishing_scale"
	if vanishing_kick:
		factor *= 1.0 + maxf(0.0, recoil) * float(placement.get("recoil_scale_per_unit", 0.002))
	var marker := point(placement.marker)
	var target := point(placement.get("target", [0.5, 0.64]))
	if placement.has("switch_from_target"):
		var progress := clampf(phase_progress, 0.0, 1.0)
		progress = progress * progress * (3.0 - 2.0 * progress)
		target = point(placement.switch_from_target).lerp(target, progress)
	var origin := layer_size * target - marker * factor
	# The illustrated pose kicks down during recoil; recompute the horizontal
	# convergence from that translated barrel so its forward line still crosses
	# the fixed camera aim throughout the kick.
	if not vanishing_kick: origin.y += recoil * layer_size.y / 180.0
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
	# Every marker remains in source-region coordinates. These are real painted
	# left/right barrel axes, not two offsets from a computational centerline.
	var projected_bores: Array[Dictionary] = []
	var muzzles: Array[Vector2] = []
	var authored_bores: Array = placement.get("bores", [])
	if authored_bores.is_empty() and placement.has("bore"):
		authored_bores = [placement.bore]
	for authored in authored_bores:
		var local_breech := origin + point(authored.breech) * factor
		var local_muzzle := origin + point(authored.muzzle) * factor
		projected_bores.append({"breech":local_breech, "muzzle":local_muzzle, "aim_x":line_x_at_y(local_breech, local_muzzle, layer_size.y * 0.5)})
		muzzles.append(local_muzzle)
	result.bores = projected_bores
	result.muzzles = muzzles
	result.position = origin
	return result
