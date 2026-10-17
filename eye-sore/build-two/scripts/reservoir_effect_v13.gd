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
	var drained:=true
	for flag in required_flags:
		if not bool(stage.flags.get(flag,false)):drained=false
	position.y=low_y if drained else high_y
func _process(_delta: float) -> void:
	if not get_tree().paused:refresh_visual()
