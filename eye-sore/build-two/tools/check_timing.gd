extends SceneTree
var combat: Node3D
var ticks: int = 0
var active: bool = false
func _initialize() -> void: call_deferred("run_check")
func pulse() -> void:
	if active:
		combat.try_fire()
		ticks += 1
func run_check() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	Engine.physics_ticks_per_second=60
	physics_frame.connect(pulse)
	var results: Array[Dictionary]=[]
	for fps in [30,60,120]:
		Engine.max_fps=fps
		var world:=Node3D.new(); root.add_child(world)
		var floor_body:=StaticBody3D.new(); world.add_child(floor_body); floor_body.position.y=-.3
		var floor_node:=CollisionShape3D.new(); var floor_shape:=BoxShape3D.new(); floor_shape.size=Vector3(100,.6,100); floor_node.shape=floor_shape; floor_body.add_child(floor_node)
		var player:=CharacterBody3D.new(); player.set_script(load("res://scripts/player.gd")); player.position=Vector3(0,.87,0)
		var collision:=CollisionShape3D.new(); var capsule:=CapsuleShape3D.new(); capsule.radius=.3; capsule.height=1.7; collision.shape=capsule; player.add_child(collision)
		var camera:=Camera3D.new(); camera.name="Camera3D"; camera.position.y=.4; camera.current=true; player.add_child(camera); world.add_child(player)
		combat=load("res://scripts/combat.gd").new(); world.add_child(combat); combat.setup(world,player)
		for enemy in combat.enemies: enemy.set_physics_process(false); enemy.position.x=40
		await physics_frame; await physics_frame
		var event:=InputEventKey.new(); event.physical_keycode=KEY_W; event.keycode=KEY_W; event.pressed=true; Input.parse_input_event(event); Input.flush_buffered_events()
		await process_frame
		assert(Input.is_physical_key_pressed(KEY_W))
		player.velocity = Vector3.ZERO
		var draw_start := Engine.get_frames_drawn()
		var start:=player.position; var process_start:=Engine.get_process_frames(); var physics_start:=Engine.get_physics_frames()
		ticks=0; active=true
		while ticks<120: await physics_frame
		active=false
		event.pressed=false; Input.parse_input_event(event)
		var result:Dictionary={"render_cap":fps,"physics_pulses":ticks,"physics_frames":Engine.get_physics_frames()-physics_start,"process_frames":Engine.get_process_frames()-process_start,"rendered_frames":Engine.get_frames_drawn()-draw_start,"shots":combat.shot_counter,"ammo":combat.ammo_pistol,"distance":start.distance_to(player.position),"phase":combat.weapon_phase,"cooldown":combat.cooldown}
		results.append(result); print("TIMING_RESULT ",result)
		assert(ticks==120 and combat.shot_counter==6 and combat.ammo_pistol==30)
		assert(result.distance>14.5 and result.distance<16.1)
		world.queue_free(); await process_frame
	assert(absf(results[0].distance-results[1].distance)<.15 and absf(results[1].distance-results[2].distance)<.15)
	assert(results[0].phase==results[1].phase and results[1].phase==results[2].phase)
	assert(absf(results[0].cooldown-results[2].cooldown)<.018)
	assert(results[0].process_frames<results[2].process_frames, "Actual engine frame counts must differ by render cap")
	print("TIMING_CHECK_OK: real engine 30/60/120 caps; fixed 60Hz physics; identical accepted cadence/ammo/phase and grounded W movement")
	quit()
