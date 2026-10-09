extends RefCounted
## Player and enemies climb the same authored low risers using actual shape queries.
static func climb(body: CharacterBody3D, motion: Vector3, height: float = 0.18) -> void:
	if not body.is_on_floor() or motion.length_squared() < 0.000001: return
	if not body.test_move(body.global_transform, motion): return
	# Wall sliding cancels speed; the next tick's acceleration can be only .7m/s.
	# Probe far enough to find a tread beyond the rounded capsule's front edge.
	var probe := motion.normalized() * maxf(motion.length(), 0.35)
	var elevated := body.global_transform
	if body.test_move(elevated, Vector3.UP * height): return
	elevated.origin.y += height
	if body.test_move(elevated, probe): return
	elevated.origin += probe
	var landing := KinematicCollision3D.new()
	if not body.test_move(elevated, Vector3.DOWN * (height + 0.02), landing): return
	if landing.get_normal().y < cos(body.floor_max_angle): return
	var rise := height + landing.get_travel().y
	if rise <= 0.002 or rise > height: return
	# Horizontal movement remains owned by move_and_slide, so speed is unchanged.
	# Leave full clearance for the horizontal sweep; floor snap settles to the
	# measured landing in the same tick instead of re-contacting the riser corner.
	body.global_position.y += height
	body.velocity.y = 0.0
