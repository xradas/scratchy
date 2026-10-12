extends StaticBody3D
## A fixed landing guard opens only when the real lift deck is docked here.
var lift: AnimatableBody3D
var opened := false

func _ready() -> void:
	lift = get_node(get_meta("lift_target", NodePath("../Lift_Observation")))
	lift.register_landing_gate(self)

func refresh() -> void:
	var landing: float = float(get_meta("landing_height"))
	var docked: bool = not lift.moving and absf(lift.position.y + 0.15 - landing) < 0.02
	var emergency_exit: bool = lift.obstructed and absf(lift.origin.y + 0.15 - landing) < 0.02
	var clear: bool = docked or emergency_exit
	if clear == opened: return
	opened = clear
	$Visual.visible = not opened
	$Collision.set_deferred("disabled", opened)

func entrance_clear() -> bool:
	# Check the actual doorway volume before enabling its collider. The lift
	# waits if a passenger straddles the entrance, rather than enclosing them.
	var volume := BoxShape3D.new()
	# Include a full player physics step before deferred collision enabling.
	# This remains a clearance query; the rendered and physical guard match.
	var clearance: float = 0.10 + preload("res://scripts/player.gd").SPEED / float(Engine.physics_ticks_per_second)
	volume.size = $Collision.shape.size + Vector3(clearance * 2, 0.12, clearance * 2)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = volume
	query.transform = global_transform
	query.collision_mask = 2 | 4
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
