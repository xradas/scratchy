extends "res://tools/check_gore_v12.gd"
## Narrow instrumented actualMain fixture, separate from acceptance checks.
func _initialize() -> void:
	Engine.max_fps=60
	output="res://verification/production-v12/bursts-performance/main-phase-native.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):output=argument.trim_prefix("--report=")
	call_deferred("run")
func run() -> void:
	await install()
	var old:Node3D=app.combat.gore;var settings:GoreProfile=old.profile
	app.combat.combat_event.disconnect(old.handle_event);old.set_physics_process(false);old.queue_free()
	var probe:Node3D=load("res://tools/gore_phase_probe_v12.gd").new();app.combat.add_child(probe);probe.setup(app.combat,settings)
	app.combat.gore=probe;app.combat.combat_event.connect(probe.handle_event)
	app.player.global_position=Vector3(0,.87,7.5)
	var first:Node3D=target_at(0,Vector3(0,.87,5.5));await frames(2)
	await accepted_shot(first,&"shotgun");await frames(210)
	app.player.global_position=Vector3(0,.87,11.5)
	var crowd:=[]
	for pair in [[9,Vector3(0,.87,5.5)],[12,Vector3(1.1,.87,5.5)],[22,Vector3(-1.1,.87,5.5)],[25,Vector3(0,.87,4.4)]]:crowd.append(target_at(pair[0],pair[1]))
	tested_bursts[&"siege_launcher"]=true # This is a four-victim blast, not the base fixture single-victim count case.
	await frames(2);await accepted_shot(crowd[0],&"siege_launcher");await frames(240)
	var report:Dictionary=probe.phase_summary()
	report["helper_sha256"]=FileAccess.get_sha256("res://scripts/gore_chunk_v12.gd")
	report["main_sha256"]=FileAccess.get_sha256("res://scripts/main.gd")
	report["fixture_failures"]=failures;report["display"]=DisplayServer.get_name();report["observations"]=observations
	DirAccess.make_dir_recursive_absolute(output.get_base_dir());FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	for event in report.slowest_events.slice(0,6):print("EVENT ",JSON.stringify(event))
	for frame in report.slowest_physics.slice(0,6):print("PHYSICS ",JSON.stringify(frame))
	app.combat_audio.stop_all();app.menu_music.stop();app.queue_free();await frames(3)
	preload("res://scripts/sprite_hurt_geometry.gd").frame_cache.clear();preload("res://scripts/sprite_hurt_geometry.gd").image_cache.clear()
	quit()
