extends Area3D
## A fall into the bridge outfall hurts, then returns the actor to solid deck.
@export var safe_position := Vector3.ZERO
@export var fall_damage := 25.0

func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	var stage := get_parent()
	if body != stage.player or not is_instance_valid(stage.combat): return
	stage.combat.receive_player_damage(fall_damage, "toxic_outfall", body.global_position)
	if stage.combat.dead: return
	body.set_deferred("global_position", safe_position)
	body.set_deferred("velocity", Vector3.ZERO)
