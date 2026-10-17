extends SceneTree
## Bounded baseline/current repro using the exact committed v8 player script.
var baseline := ""
var player_script := ""
var report_path := ""
var world: Node3D
var actor: CharacterBody3D
var results: Array[Dictionary] = []
var geometry: Array[Dictionary] = []
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--baseline="): baseline=arg.trim_prefix("--baseline=")
		if arg.begins_with("--player-script="): player_script=arg.trim_prefix("--player-script=")
		if arg.begins_with("--report="): report_path=arg.trim_prefix("--report=")
	call_deferred("run")
func xyz(v: Vector3) -> Array: return [v.x,v.y,v.z]
func key(code: int, down: bool) -> void:
	var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=down;Input.parse_input_event(e)
func ticks(n: int) -> void:
	for i in n: await physics_frame
func walk(label: String, reverse: bool) -> void:
	var start:=Vector3(-11,.87,-1);var end:=Vector3(-21,.87,-1)
	if reverse: var swap:=start;start=end;end=swap
	var code:=KEY_S if reverse else KEY_W
	actor.set_physics_process(false);key(KEY_W,false);key(KEY_S,false)
	actor.global_position=start;actor.rotation.y=PI*.5;actor.velocity=Vector3.ZERO
	await ticks(3);actor.set_physics_process(true);await ticks(4)
	key(code,true)
	var trace: Array=[];var lost: Array=[];var stuck: Array=[];var elapsed:=0;var previous:=actor.global_position
	while elapsed<255 and Vector2(actor.global_position.x-end.x,actor.global_position.z-end.z).length()>.70:
		await physics_frame;elapsed+=1
		var pressed:=Input.is_physical_key_pressed(code)
		if not pressed:lost.append(elapsed)
		var contacts: Array=[]
		for i in actor.get_slide_collision_count():
			var collision:=actor.get_slide_collision(i)
			contacts.append({"body":String(world.get_path_to(collision.get_collider())),"normal":xyz(collision.get_normal())})
		var sample:={"tick":elapsed,"position":xyz(actor.global_position),"velocity":xyz(actor.velocity),"input_pressed":pressed,"grounded":actor.is_on_floor(),"contacts":contacts}
		if elapsed%6==0:trace.append(sample)
		if elapsed>20 and actor.global_position.distance_to(previous)<.001 and stuck.size()<12:stuck.append(sample)
		previous=actor.global_position
	key(code,false);await ticks(16);actor.set_physics_process(false)
	var error:=Vector2(actor.global_position.x-end.x,actor.global_position.z-end.z).length()
	results.append({"scene":label,"reverse":reverse,"key":OS.get_keycode_string(code),"initial":xyz(start),"goal":xyz(end),"terminal":xyz(actor.global_position),"goal_xz_error":error,"reached":error<.6,"grounded":actor.is_on_floor(),"ticks":elapsed,"lost_input_ticks":lost,"stagnant_samples":stuck,"trace":trace})
func run() -> void:
	for fixture in [["committed-v8",baseline],["current-v9","res://scenes/campaign/pale_ward_01.tscn"]]:
		world=load(fixture[1]).instantiate();actor=world.get_node("Player")
		actor.set_script(load(player_script));root.add_child(world);actor.set_physics_process(false);world.scan(world)
		var floors: Array=[]
		for name in ["entry_Floor","Link_14_Floor","supplies_Floor"]:
			var body: Node3D=world.get_node(name);var collision: CollisionShape3D=body.get_node("Collision")
			floors.append({"name":name,"position":xyz(body.position),"size":xyz(collision.shape.size),"layer":body.collision_layer,"mask":body.collision_mask,"disabled":collision.disabled})
		geometry.append({"scene":fixture[0],"floors":floors,"door":"none; portal14 has empty gate"})
		for reverse in [false,true]: await walk(fixture[0],reverse)
		world.free();await process_frame
	var failures: Array=[]
	for walk_result in results:
		if not walk_result.reached:failures.append(walk_result.scene+" "+walk_result.key)
	var report:={"passed":failures.is_empty(),"failures":failures,"baseline_geometry_equals_current":geometry[0].floors==geometry[1].floors,"geometry":geometry,"walks":results,"engine":Engine.get_version_info(),"display_server":DisplayServer.get_name(),"rendering_method":RenderingServer.get_current_rendering_method(),"reported_average_fps":Engine.get_frames_per_second(),"physics_hz":Engine.physics_ticks_per_second,"player_script_sha256":FileAccess.get_sha256(player_script),"baseline_scene_sha256":FileAccess.get_sha256(baseline),"current_scene_sha256":FileAccess.get_sha256("res://scenes/campaign/pale_ward_01.tscn"),"limits":["Only four declared walks using committed v8 movement; no motion repair, door opening or geometry edits.","If no snag occurs, this does not explain the earlier failure or prove focus/input interference.","The contemporaneous v9 movement script is deliberately excluded to separate layout from movement changes."]}
	var file:=FileAccess.open(report_path,FileAccess.WRITE);file.store_string(JSON.stringify(report,"  ")+"\n");file.close()
	print("LINK14_V9_REPRO passed=",failures.is_empty()," walks=",results.size()," identical_floors=",report.baseline_geometry_equals_current)
	quit(0 if failures.is_empty() else 1)
