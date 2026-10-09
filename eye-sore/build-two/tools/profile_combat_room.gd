extends SceneTree
var app: Control
var active := false
var pulses := 0

func _initialize() -> void: call_deferred("run_profile")
func pulse() -> void:
	if active:
		app.combat.try_fire()
		pulses += 1

func run_profile() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	physics_frame.connect(pulse)
	var results: Array[Dictionary] = []
	for cap in [30,60,120]:
		Engine.max_fps = cap
		app = preload("res://scenes/main.tscn").instantiate()
		root.add_child(app)
		app.enter_combat()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		app.player.set_physics_process(false)
		app.player.position = Vector3(0,0.87,14)
		app.player.rotation = Vector3.ZERO
		app.player.camera.rotation = Vector3.ZERO
		app.combat.health = 10000
		app.combat.armor = 0
		app.combat.enemies[0].position = Vector3(-1.5,0.87,9.5)
		app.combat.enemies[1].position = Vector3(1.8,0.87,7)
		await physics_frame
		await physics_frame
		pulses = 0
		var start_draw := Engine.get_frames_drawn()
		var start_usec := Time.get_ticks_usec()
		active = true
		while pulses < 120: await physics_frame
		active = false
		var seconds := (Time.get_ticks_usec()-start_usec)/1000000.0
		var record := {"cap":cap,"physics_frames":pulses,"rendered_frames":Engine.get_frames_drawn()-start_draw,"elapsed_seconds":seconds,"shots":app.combat.shot_counter,"ammo":app.combat.ammo_pistol,"live_creature_meshes":true}
		assert(app.combat.shot_counter == 6 and app.combat.ammo_pistol == 30)
		assert(record.rendered_frames >= cap*1.6,"Integrated scene failed to approach requested cap")
		results.append(record)
		app.menu_music.stop()
		app.menu_music.stream = null
		app.combat_audio.stop_all()
		app.free()
		app = null
		await create_timer(0.25,true).timeout
	var file := FileAccess.open("res://verification/combat/live-room-timing.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"results":results,"scope":"Native integrated room with live rigs, triangle contacts, AI/projectiles and repeated shots; 120 fixed physics frames per rendering cap. Not a sustained complete-level playtest."},"  ")+"\n")
	file.close()
	print("LIVE_ROOM_TIMING_OK: integrated animated creatures and AI; cap30/60/120; identical6 shots and30 ammo across120 physics ticks ",results)
	quit()
