extends SceneTree
## Editor-only launcher for the same Main opt-in driver shipped in the ELF.
## Actual ELF runs use --v13-route-test directly, never release --script.
func _initialize() -> void:call_deferred("run")
func run() -> void:
	if not "--v13-route-test" in OS.get_cmdline_user_args():
		push_error("Explicit --v13-route-test required; pass --release-report-dir outside project")
		quit(1);return
	var app: Control=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
