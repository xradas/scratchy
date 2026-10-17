extends Node3D
## Security siege ordnance: swept physical collision and short, LOS-gated splash.
## The player weapon remains more powerful; this telegraphed version is fair indoors.
var combat: Node3D
var shooter: CharacterBody3D
var velocity: Vector3
var resolved := false
var lifetime := 0.0
var sweep_shape := SphereShape3D.new()
const BLAST_RADIUS := 2.7
const DIRECT_DAMAGE := 24.0
const SPLASH_DAMAGE := 16.0

func setup(controller: Node3D, enemy: CharacterBody3D, motion: Vector3) -> void:
	combat = controller
	shooter = enemy
	velocity = motion
	sweep_shape.radius = 0.16
	var shell := MeshInstance3D.new()
	shell.name = "RocketShell"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.07
	mesh.bottom_radius = 0.11
	mesh.height = 0.35
	shell.mesh = mesh
	shell.rotation = Vector3(PI / 2, 0, 0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.75, 0.18, 0.1)
	material.emission_enabled = true
	material.emission = Color(0.9, 0.18, 0.08)
	shell.material_override = material
	add_child(shell)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.28, 0.1)
	glow.light_energy = 1.5
	glow.omni_range = 2.0
	add_child(glow)

func is_combat_projectile() -> bool: return true

func _physics_process(delta: float) -> void:
	if resolved or not is_instance_valid(combat) or get_tree().paused: return
	lifetime += delta
	if lifetime > 5.0: resolved = true; queue_free(); return
	var motion := velocity * delta
	var exclude: Array[RID] = []
	if is_instance_valid(shooter): exclude.append(shooter.get_rid())
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sweep_shape
	query.transform = global_transform
	query.motion = motion
	query.collision_mask = 3
	query.exclude = exclude
	var space := get_world_3d().direct_space_state
	var overlaps := space.intersect_shape(query, 1)
	var fractions := space.cast_motion(query)
	var collision: Object = null
	var contact := global_position + motion
	if not overlaps.is_empty():
		collision = overlaps[0].collider
		contact = global_position
	elif fractions[0] < 1.0:
		query.motion = Vector3.ZERO
		query.transform.origin += motion * minf(1.0, fractions[1] + 0.001)
		var rest := space.get_rest_info(query)
		if not rest.is_empty():
			collision = instance_from_id(rest.collider_id)
			contact = rest.point
		else:
			var ray_hit: Dictionary = combat.ray(global_position, global_position + motion, exclude)
			if not ray_hit.is_empty():
				collision = ray_hit.collider
				contact = ray_hit.position
	if collision != null or fractions[0] < 1.0:
		explode(contact, collision)
		return
	global_position += motion

func explode(at: Vector3, direct: Object) -> void:
	if resolved: return
	resolved = true
	var player: CharacterBody3D = combat.player
	if is_instance_valid(player) and not combat.dead:
		var target := player.global_position + Vector3(0, 0.3, 0)
		var distance := at.distance_to(target)
		if direct == player:
			combat.receive_player_damage(DIRECT_DAMAGE, shooter.target_id if is_instance_valid(shooter) else "siege_rocket", at)
		elif distance < BLAST_RADIUS:
			var exclusions: Array[RID] = []
			if is_instance_valid(shooter): exclusions.append(shooter.get_rid())
			var hit: Dictionary = combat.ray(at + (target - at).normalized() * 0.08, target, exclusions)
			if not hit.is_empty() and hit.collider == player:
				combat.receive_player_damage(SPLASH_DAMAGE * (1.0 - distance / BLAST_RADIUS), shooter.target_id if is_instance_valid(shooter) else "siege_rocket", at)
	combat.emit_event({"type": &"ordnance_explosion", "weapon_id": &"siege_launcher", "enemy_kind": shooter.definition.identifier if is_instance_valid(shooter) else &"infected_security", "target_id": shooter.target_id if is_instance_valid(shooter) else "siege_rocket", "position": at, "radius": BLAST_RADIUS, "damage": DIRECT_DAMAGE})
	queue_free()
