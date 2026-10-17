extends SceneTree
## Private scene pair; never writes production data. Native optional captures.
var baseline := ""
var candidate := ""
var report_dir := "/tmp/eyesore-lighting-v11"
var failures: Array[String] = []
var checks := 0
var fixtures: Array[Node] = []
var timing: Array[Dictionary] = []
var world: Node3D
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--baseline="):baseline=arg.trim_prefix("--baseline=")
		if arg.begins_with("--candidate="):candidate=arg.trim_prefix("--candidate=")
		if arg.begins_with("--report-dir="):report_dir=arg.trim_prefix("--report-dir=")
	call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error("LIGHTING_V11: "+label)
func xyz(v: Vector3) -> Array:return [v.x,v.y,v.z]
func collider_records(node: Node, transform_: Transform3D=Transform3D.IDENTITY) -> Array:
	var records: Array=[]
	if node is Node3D:transform_=transform_*node.transform
	if node is CollisionShape3D:
		var shape=node.shape
		var data: Variant=[]
		if shape is BoxShape3D:data=xyz(shape.size)
		elif shape is CylinderShape3D or shape is CapsuleShape3D:data=[shape.radius,shape.height]
		elif shape is ConvexPolygonShape3D:
			for point in shape.points:data.append(xyz(point))
		else:failures.append("Unhandled collider "+shape.get_class())
		records.append({"transform":transform_,"shape":shape.get_class(),"data":data,"disabled":node.disabled,"layer":node.get_parent().collision_layer,"mask":node.get_parent().collision_mask,"hit":node.get_parent().get_meta("hit_material","")})
	for child in node.get_children():records.append_array(collider_records(child,transform_))
	return records
func install(path: String) -> void:
	world=load(path).instantiate();root.add_child(world);world.scan(world)
	world.get_node("Player").set_physics_process(false)
	for i in 2:await physics_frame
func fixture_checks() -> void:
	fixtures=get_nodes_in_group("intake_lighting_v11")
	check(fixtures.size()==56,"exact56 mounted lights")
	var damaged:=0
	for fixture in fixtures:
		check(fixture.light is Light3D,"one real light per physical lens")
		check(fixture.light.position==Vector3(0,0,-.055),"emitter2cm outside lens front")
		check(collider_records(fixture).is_empty(),"fixture adds no physical collider")
		if not fixture.existing_lens_path.is_empty():
			var lens: MeshInstance3D=fixture.get_node(fixture.existing_lens_path)
			check(lens.global_position.distance_to(fixture.global_position)<.001,"fixture anchored at actual existing lens")
		fixture.set_process(false)
		if fixture.damaged:damaged+=1
		var minimum:=1.0
		for i in range(5001 if fixture.damaged else 3):
			var t:=float(i)*.01
			var factor: float=fixture.intensity_at(t)
			minimum=minf(minimum,factor)
			check(factor>=.81999 and factor<=1.00001,"bounded mild flicker")
			check(is_equal_approx(factor,fixture.intensity_at(t)),"deterministic phase")
		check(minimum<.9 if fixture.damaged else minimum==1.0,"only damaged fixtures vary")
		fixture.reset_lighting();fixture._process(13.0-fixture.flicker_offset)
		fixture.set_flicker_enabled(false)
		check(is_equal_approx(fixture.light.light_energy,fixture.energy),"accessibility toggle immediately steady")
		fixture.set_flicker_enabled(true);fixture.reset_lighting()
		check(fixture.elapsed==0 and is_equal_approx(fixture.light.light_energy,fixture.energy),"reset deterministic and steady")
		var before: Dictionary=fixture.lighting_state()
		paused=true;fixture._process(.5)
		check(fixture.lighting_state()==before,"paused manual/process call freezes phase/lens/light")
		paused=false
	check(damaged==2,"only two low-energy warning fixtures flicker")
	for fixture in fixtures:fixture.set_process(true)
	paused=true
	var before: Array=[]
	for fixture in fixtures:before.append(fixture.elapsed)
	for i in 3:await process_frame
	for i in fixtures.size():check(fixtures[i].elapsed==before[i],"native pause freezes every fixture")
	paused=false
	for fixture in fixtures:fixture.reset_lighting()
func render_views(label: String) -> void:
	if DisplayServer.get_name()=="headless":return
	var camera: Camera3D=world.get_node("Player/Camera3D")
	world.get_node("Player").rotation=Vector3.ZERO
	var views=[ ["triage-bank",Vector3(-12.8,.65,-90.6),Vector3(-16.44,-.25,-90.6)], ["surgery",Vector3(65.0,3.15,-74.5),Vector3(66.6,2.35,-79.5)], ["service",Vector3(0,3.15,-33),Vector3(-4,3.0,-41)], ["exit",Vector3(0,4.65,-240),Vector3(0,4.0,-251)], ["triage-control",Vector3(4.5,.65,-90),Vector3(4.5,.3,-93)], ["exit-control",Vector3(4.5,3.15,-224),Vector3(4.5,2.8,-227)], ["exit-stair",Vector3(0,3.15,-220),Vector3(0,4.5,-235)] ]
	for view in views:
		camera.global_position=view[1];camera.look_at(view[2]);camera.current=true
		for i in 24:await process_frame;RenderingServer.force_draw(false)
		var start:=Time.get_ticks_usec()
		for i in 60:await process_frame;RenderingServer.force_draw(false)
		var duration:=float(Time.get_ticks_usec()-start)/1000.0
		var image:=root.get_texture().get_image()
		image.save_png(report_dir.path_join(label+"-"+view[0]+".png"))
		timing.append({"scene":label,"view":view[0],"frames":60,"wall_ms":duration,"ms_per_frame":duration/60,"note":"Uncapped native window, force_draw; includes presentation overhead, not a GPU-only benchmark."})
func run() -> void:
	DirAccess.make_dir_recursive_absolute(report_dir)
	root.size=Vector2i(640,360);root.set_flag(Window.FLAG_NO_FOCUS,true)
	var cold_before=load(baseline).instantiate()
	var cold_after=load(candidate).instantiate()
	cold_before.scan(cold_before);cold_after.scan(cold_after)
	var before:=collider_records(cold_before)
	var after:=collider_records(cold_after)
	check(before==after,"every cold collider shape/transform/layer/mask/hit metadata unchanged")
	cold_before.free();cold_after.free()
	await install(baseline)
	await render_views("before")
	world.free()
	await install(candidate)
	await fixture_checks()
	await render_views("after")
	var report:={"passed":failures.is_empty(),"checks":checks,"failures":failures,"colliders":after.size(),"mounted_lights":fixtures.size(),"flickering_lights":2,"engine":Engine.get_version_info(),"display_server":DisplayServer.get_name(),"rendering_method":RenderingServer.get_current_rendering_method(),"timing":timing,"scope":"Private source/candidate native collider equality, lens/emitter alignment, deterministic mild flicker, pause/reset/toggle and representative640x360 room timing/captures. No enemy combat or human visual acceptance claim."}
	var file:=FileAccess.open(report_dir.path_join("checks.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"  ")+"\n");file.close()
	world.free();print("LIGHTING_V11 passed=",failures.is_empty()," checks=",checks)
	quit(0 if failures.is_empty() else 1)
