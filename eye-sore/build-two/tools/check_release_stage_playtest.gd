extends SceneTree
## Source-only driver; the export instantiates the same Node through Main's CLI hook.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var app: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	var harness: Node = load("res://scripts/release_stage_playtest.gd").new()
	root.add_child(harness)
	harness.setup(app)
