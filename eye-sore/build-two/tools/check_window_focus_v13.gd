extends SceneTree
## Local pinned-engine CLI/API probe; no game scene or input is loaded.
var report_path := "/tmp/eyesore-v13-window-focus.json"
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report_path=arg.trim_prefix("--report=")
	call_deferred("run")
func run() -> void:
	var before := root.get_flag(Window.FLAG_NO_FOCUS)
	var display_before := DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS)
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	var after := root.get_flag(Window.FLAG_NO_FOCUS)
	var display_after := DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS)
	root.mode=Window.MODE_MINIMIZED
	var until: int=Time.get_ticks_msec()+200
	while Time.get_ticks_msec()<until:await process_frame
	var result := {"engine":Engine.get_version_info(),"display":DisplayServer.get_name(),"arguments":OS.get_cmdline_args(),"window_flag_before_api":before,"display_flag_before_api":display_before,"window_flag_after_api":after,"display_flag_after_api":display_after,"window_minimized_after_api":root.mode==Window.MODE_MINIMIZED,"scope":"Pinned native window property probe, no Main or gameplay. A false before flag when --no-focus is present demonstrates the CLI option did not set NO_FOCUS. Does not claim that a flag set after startup prevented initial OS activation."}
	FileAccess.open(report_path,FileAccess.WRITE).store_string(JSON.stringify(result,"  ")+"\n")
	print(JSON.stringify(result));quit(0 if after and display_after else 1)
