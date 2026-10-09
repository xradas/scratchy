extends SceneTree
## Run with fresh temporary XDG_CONFIG_HOME/XDG_DATA_HOME and --isolated-user-root.
## Refuses normal or previously populated user storage before any settings writes.
var evidence_dir := "res://verification/combat"
var isolated_root := ""
var app: Control
var records: Array[Dictionary] = []

func require_check(condition: bool, message: String) -> bool:
	if condition: return true
	push_error("CAMERA_SETTINGS_FAILED: " + message)
	quit(1)
	return false

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-dir="):
			evidence_dir = argument.trim_prefix("--evidence-dir=")
		elif argument.begins_with("--isolated-user-root="):
			isolated_root = argument.trim_prefix("--isolated-user-root=").simplify_path().trim_suffix("/")
	if not require_check(isolated_root.begins_with("/tmp/") and isolated_root.length() > 5, "requires a temporary /tmp isolated user root"): return
	for variable in ["XDG_CONFIG_HOME", "XDG_DATA_HOME"]:
		if not require_check(OS.get_environment(variable).simplify_path().begins_with(isolated_root + "/"), variable + " must be inside the isolated root"): return
	if not require_check(OS.get_user_data_dir().simplify_path().begins_with(isolated_root + "/"), "user:// resolved outside isolated storage"): return
	if not require_check(not FileAccess.file_exists("user://calibration_settings.cfg"), "isolated settings already exist; use a fresh directory"): return
	if not require_check(not evidence_dir.is_empty(), "empty evidence directory"): return
	call_deferred("run_check")

func new_app() -> void:
	app = preload("res://scenes/main.tscn").instantiate()
	root.add_child(app)

func discard_app() -> void:
	if is_instance_valid(app.menu_music): app.menu_music.stop()
	if is_instance_valid(app.combat_audio): app.combat_audio.stop_all()
	app.free()

func run_check() -> void:
	new_app()
	if not require_check(is_equal_approx(app.field_of_view, 90.0) and is_equal_approx(app.sensitivity, 0.002) and not app.muted, "fresh defaults differ"): return
	for sample in [
		{"case": "valid", "fov": 103.0, "sensitivity": 0.0037, "muted": true, "expected_fov": 103.0, "expected_sensitivity": 0.0037},
		{"case": "lower_clamp", "fov": 20.0, "sensitivity": -1.0, "muted": false, "expected_fov": 60.0, "expected_sensitivity": 0.0005},
		{"case": "upper_clamp", "fov": 170.0, "sensitivity": 1.0, "muted": true, "expected_fov": 110.0, "expected_sensitivity": 0.006},
	]:
		app.field_of_view = sample.fov
		app.sensitivity = sample.sensitivity
		app.muted = sample.muted
		app.save_settings()
		var saved := ConfigFile.new()
		if not require_check(saved.load(app.SETTINGS_PATH) == OK, "saved settings could not be read"): return
		if not require_check(is_equal_approx(float(saved.get_value("display", "fov")), sample.fov) and is_equal_approx(float(saved.get_value("input", "sensitivity")), sample.sensitivity) and bool(saved.get_value("audio", "muted")) == sample.muted, "settings save differs from requested values"): return
		if not require_check(saved.get_value("display", "fov_axis") == "horizontal", "saved FOV axis differs"): return
		discard_app()
		new_app()
		if not require_check(is_equal_approx(app.field_of_view, sample.expected_fov) and is_equal_approx(app.sensitivity, sample.expected_sensitivity) and app.muted == sample.muted, "fresh scene reload or bounds clamp failed: " + sample.case): return
		if not require_check(is_equal_approx(app.player.sensitivity, sample.expected_sensitivity), "reloaded sensitivity not applied to player"): return
		var camera: Camera3D = app.player.get_node("Camera3D")
		if not require_check(is_equal_approx(camera.fov, sample.expected_fov) and camera.keep_aspect == Camera3D.KEEP_WIDTH, "reloaded horizontal FOV not applied to camera"): return
		if not require_check(AudioServer.is_bus_mute(0) == sample.muted, "reloaded mute not applied"): return
		# Persist the clamped values, then verify a further reload remains stable.
		app.save_settings()
		discard_app()
		new_app()
		if not require_check(is_equal_approx(app.field_of_view, sample.expected_fov) and is_equal_approx(app.sensitivity, sample.expected_sensitivity) and app.muted == sample.muted, "clamped settings did not survive a second save/reload"): return
		records.append({"case": sample.case, "saved_fov": sample.fov, "saved_sensitivity": sample.sensitivity, "reloaded_fov": app.field_of_view, "reloaded_sensitivity": app.sensitivity, "muted": app.muted, "horizontal_camera": true, "player_applied": true, "audio_applied": true, "second_reload": true})
	var directory_error := DirAccess.make_dir_recursive_absolute(evidence_dir)
	if not require_check(directory_error == OK, "cannot create evidence directory: " + error_string(directory_error)): return
	var file := FileAccess.open(evidence_dir.path_join("camera-settings.json"), FileAccess.WRITE)
	if not require_check(file != null, "cannot open evidence: " + error_string(FileAccess.get_open_error())): return
	file.store_string(JSON.stringify({"isolated_user_data_dir": OS.get_user_data_dir(), "fresh_defaults": true, "cases": records, "scope": "Real main scene settings save and fresh scene reload; temporary XDG user storage only."}, "  ") + "\n")
	file.flush()
	var write_error := file.get_error()
	file.close()
	if not require_check(write_error == OK, "cannot write evidence: " + error_string(write_error)): return
	print("CAMERA_SETTINGS_OK: isolated user storage; FOV/sensitivity/mute save/reload; both bounds clamped; horizontal camera/player/audio applied")
	await app.quit_game()
