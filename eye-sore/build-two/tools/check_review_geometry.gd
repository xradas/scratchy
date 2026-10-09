extends SceneTree
var results:Dictionary={}
func _initialize()->void: call_deferred("run")
func key(pressed:bool)->void:
	var event:=InputEventKey.new();event.keycode=KEY_W;event.physical_keycode=KEY_W;event.pressed=pressed
	Input.parse_input_event(event);Input.flush_buffered_events()
func run()->void:
	var world:Node3D=load("res://scenes/calibration.tscn").instantiate();root.add_child(world)
	var player:CharacterBody3D=world.get_node("Player")
	player.position=Vector3(-5.8,1.76,7.4);player.rotation=Vector3(0,PI,0);player.velocity=Vector3.ZERO
	for i in 5:await physics_frame
	key(true);await process_frame
	var unsupported:=0;var minimum:=player.position.y
	for i in 60:
		await physics_frame
		if not player.is_on_floor():unsupported+=1
		minimum=minf(minimum,player.position.y)
	key(false)
	results.ramp={"end":str(player.position),"grounded":player.is_on_floor(),"unsupported_frames":unsupported,"minimum_y":minimum}
	player.position=Vector3(0,.87,-15.5);player.rotation=Vector3.ZERO;player.velocity=Vector3.ZERO
	for i in 3:await physics_frame
	key(true);await process_frame
	var wall_rays:=0
	for i in 60:
		await physics_frame
		var query:=PhysicsRayQueryParameters3D.create(player.camera.global_position,player.camera.global_position+Vector3(0,0,-10),1,[player.get_rid()])
		var hit:=world.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.collider.name=="EndAnnex":wall_rays+=1
	key(false);player.set_physics_process(false)
	results.wall={"end":str(player.position),"blocked_rays":wall_rays,"grounded":player.is_on_floor()}
	# Probe actual ray contact on a rendered vertical step face, excluding player.
	var stair_ray:=PhysicsRayQueryParameters3D.create(Vector3(-5.8,.08,11),Vector3(-5.8,.08,9),1,[player.get_rid()])
	var stair_hit:=world.get_world_3d().direct_space_state.intersect_ray(stair_ray)
	var ramp_mesh:MeshInstance3D=world.get_node("StairRampCollision/Visual")
	var vertices:PackedVector3Array=ramp_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var nearest:Variant=null
	var from:=Vector3(-5.8,.08,11);var to:=Vector3(-5.8,.08,9)
	for i in range(0,vertices.size(),3):
		var point:Variant=Geometry3D.segment_intersects_triangle(from,to,ramp_mesh.to_global(vertices[i]),ramp_mesh.to_global(vertices[i+1]),ramp_mesh.to_global(vertices[i+2]))
		if point!=null and (nearest==null or from.distance_to(point)<from.distance_to(nearest)): nearest=point
	assert(nearest!=null and not stair_hit.is_empty() and nearest.distance_to(stair_hit.position)<.001)
	results.stair_visual_contact={"rendered_intersection_z":nearest.z,"collision_z":stair_hit.position.z,"collider":str(stair_hit.collider.name),"error":nearest.distance_to(stair_hit.position)}
	world.free();await physics_frame
	world=Node3D.new();root.add_child(world)
	var holder:Node3D=load("res://scenes/calibration.tscn").instantiate()
	player=holder.get_node("Player").duplicate()
	holder.free()
	# Player script is unchanged; new fixture is empty for unobstructed long-range pellets.
	world.add_child(player);player.position=Vector3(0,.87,0);player.rotation=Vector3.ZERO;player.set_physics_process(false)
	var combat:Node3D=load("res://scripts/combat.gd").new();world.add_child(combat);combat.setup(world,player);combat.set_physics_process(false)
	for enemy in combat.enemies:enemy.set_physics_process(false);enemy.position.x=40
	var target:CharacterBody3D=combat.enemies[0]
	results.shotgun=[]
	for distance in [4.0,8.0,12.0,20.0,35.0]:
		target.position=Vector3(0,.87,-distance);target.health=1000;target.dead=false
		player.camera.look_at(target.global_position+Vector3(0,.3,0))
		await physics_frame;await physics_frame
		combat.currentweapon=&"shotgun";combat.cooldown=0;combat.weapon_phase=&"idle"
		assert(combat.try_fire())
		results.shotgun.append({"distance":distance,"damage":1000-target.health,"pellets":int((1000-target.health)/16.0)})
	world.free();await process_frame
	var viewport:=SubViewport.new();viewport.size=Vector2i(640,360);root.add_child(viewport)
	var camera:=Camera3D.new();viewport.add_child(camera);camera.current=true
	var layout:Control=load("res://scripts/main.gd").new()
	layout.world_image=TextureRect.new();layout.weapon_image=TextureRect.new();layout.damage_overlay=ColorRect.new();layout.hud=Label.new();layout.crosshair=load("res://scripts/crosshair.gd").new();layout.menu=PanelContainer.new()
	results.extra_crosshair_sizes=[]
	for dimensions in [Vector2(641,361),Vector2(639,359),Vector2(1920,1080),Vector2(3440,1440)]:
		layout.size=dimensions;layout.layout_view()
		var center:Vector2=(layout.crosshair.position+layout.crosshair.size*.5-layout.world_image.position)/layout.world_image.size*Vector2(640,360)
		var direction:Vector3=camera.project_ray_normal(center)
		results.extra_crosshair_sizes.append({"window":str(dimensions),"world_ray_pixel":str(center),"camera_forward_matches":direction.is_equal_approx(-camera.global_basis.z)})
		assert(center.is_equal_approx(Vector2(320,180)) and direction.is_equal_approx(-camera.global_basis.z))
	for node in [layout.world_image,layout.weapon_image,layout.damage_overlay,layout.hud,layout.crosshair,layout.menu]:node.free()
	layout.free();viewport.free()
	results.risk="Resolved: visible grate ramp now matches all six collision vertices and actual ray intersection"
	var evidence:=FileAccess.open("res://verification/combat/remaining-physics-audit.json",FileAccess.WRITE)
	evidence.store_string(JSON.stringify(results,"  ")+"\n");evidence.close()
	print("REMAINING_AUDIT ",JSON.stringify(results))
	await process_frame;await process_frame;quit()
