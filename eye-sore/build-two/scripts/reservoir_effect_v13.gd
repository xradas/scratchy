extends Node3D
## Pure derived cosmetic height: both isolation flags expose the drained basin.
## No body/collider, damage, reward, signals or persistent state lives here.
@export var high_y := 3.5
@export var low_y := -.2
@export var required_flags := PackedStringArray(["isolation_a","isolation_b"])
var stage: Node
func _ready() -> void:
	stage=get_parent()
	process_mode=Node.PROCESS_MODE_PAUSABLE
	refresh_visual()
func refresh_visual() -> void:
	if not is_instance_valid(stage):return
	position.y=low_y if drainage_enabled() else high_y
func drainage_enabled() -> bool:
	if not is_instance_valid(stage):return false
	for flag in required_flags:
		if not bool(stage.flags.get(flag,false)):return false
	return true
func is_drained() -> bool:
	return drainage_enabled() and is_equal_approx(position.y,low_y)
func _process(_delta: float) -> void:
	if not get_tree().paused:refresh_visual()
