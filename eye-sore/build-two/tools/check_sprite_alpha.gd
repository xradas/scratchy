extends SceneTree
var world: Node3D
var combat: Node3D
var target: CharacterBody3D
var player: CharacterBody3D
var results: Dictionary = {}
func _initialize() -> void: call_deferred("run_check")
func make_atlas() -> ImageTexture:
	var image := Image.create(256,192,false,Image.FORMAT_RGBA8);image.fill(Color.TRANSPARENT)
	for frame in 8:
		for y in 96:
			for x in 64:
				var uv:=Vector2((x+.5)/64.0,(y+.5)/96.0)
				var opaque:=Rect2(.25,.12,.5,.8).has_point(uv)
				if Rect2(.43,.3,.14,.1).has_point(uv):opaque=false
				if Rect2(.47,.73,.06,.19).has_point(uv):opaque=false
				if frame==3 and Rect2(.08,.22,.2,.2).has_point(uv):opaque=true
				if frame==7:opaque=Rect2(.08,.84,.84,.1).has_point(uv)
				if opaque:image.set_pixel((frame%4)*64+x,(frame/4)*96+y,Color(.3+.06*frame,.7,.5,1))
	return ImageTexture.create_from_image(image)
func sample_point(uv:Vector2)->Vector3:
	return target.sprite_pivot.to_global(Vector3((uv.x*64-target.sprite_foot.x)*.02,(target.sprite_foot.y-uv.y*96)*.02,0))
func contact(uv:Vector2)->Dictionary:
	var point:=sample_point(uv);var normal:Vector3=target.sprite_pivot.global_basis.z
	return combat.ray(point+normal*2,point-normal*2,[player.get_rid(),target.get_rid()],true)
func assert_material(uv:Vector2,material:StringName)->void:
	var hit:=contact(uv);assert(not hit.is_empty());assert(combat.material_for(hit.collider)==material)
	if material!=&"hard":assert(hit.collider.get_meta("combat_target")==target)
func run_check()->void:
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	world=Node3D.new();root.add_child(world)
	player=CharacterBody3D.new();var camera:=Camera3D.new();camera.name="Camera3D";camera.current=true;camera.position.y=.65;player.add_child(camera);world.add_child(player);player.position=Vector3(0,.87,3)
	combat=load("res://scripts/combat.gd").new();world.add_child(combat);combat.setup(world,player);combat.set_physics_process(false)
	for actor in combat.enemies:actor.set_physics_process(false);actor.position.x=50
	target=combat.enemies[0];target.position=Vector3(0,.87,0);target.health=1000
	target.definition=load("res://resources/enemies/vessel.tres").duplicate()
	var wall:=StaticBody3D.new();wall.name="OpaqueBackground";wall.position=Vector3(0,1,-.4);world.add_child(wall)
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(5,4,.1);shape.shape=box;wall.add_child(shape)
	var mesh:=MeshInstance3D.new();var box_mesh:=BoxMesh.new();box_mesh.size=box.size;var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=Color(.28,.13,.36);box_mesh.material=material;mesh.mesh=box_mesh;wall.add_child(mesh)
	var options:Dictionary={"rows":2,"pose_frames":{"chase":[0,1,2],"windup":[3],"recovery":[4],"pain":[5],"dead":[6,7]},"hurt_resolution":[128,192],"material_regions":{"0":[{"material":"armor","rect":[.3,.45,.4,.2]}],"3":[{"material":"armor","polygon":[[.25,.4],[.75,.4],[.75,.58],[.25,.58]]}]},"projectile_origin_uv":[.5,.34]}
	target.configure_sprite_texture(make_atlas(),4,1,{},.02,Vector2(32,91.2),options)
	await physics_frame;await physics_frame
	assert(target.sprite.frame==0 and target.sprite.billboard==BaseMaterial3D.BILLBOARD_DISABLED)
	assert_material(Vector2(.5,.35),&"hard");assert_material(Vector2(.3,.25),&"flesh");assert_material(Vector2(.5,.55),&"armor")
	assert_material(Vector2(.18,.3),&"hard")
	var health_before:float=target.health
	camera.look_at(sample_point(Vector2(.5,.35)));assert(combat.try_fire());assert(target.health==health_before)
	results.idle={"gap":"missed enemy, hit background","flesh":"matched opaque shoulder","armor":"matched authored chest","movement_capsule_excluded":true}
	camera.look_at(Vector3(0,1,0))
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("res://verification/combat/synthetic-alpha-contact.png")==OK)
	# Rotate the actual camera position: visual and query geometry share this pivot.
	player.position=Vector3(3,.87,0);target.rotation.y=.7;target.update_presentation()
	await physics_frame;await physics_frame
	assert_material(Vector2(.5,.55),&"armor")
	assert(target.sprite_pivot.global_basis.z.is_equal_approx(Vector3.RIGHT))
	assert(target.sprite_projectile_origin().is_equal_approx(sample_point(Vector2(.5,.34))))
	results.rotated_camera={"shared_visual_physics_facing":true,"nozzle_origin_matches_uv":true}
	# Restore a front camera; a committed windup introduces a raised-arm silhouette.
	player.position=Vector3(0,.87,3);target.change_state(&"windup")
	await physics_frame;await physics_frame
	assert(target.sprite.frame==3);assert_material(Vector2(.18,.3),&"flesh");assert_material(Vector2(.5,.55),&"armor");assert_material(Vector2(.5,.62),&"flesh")
	var shapes_before:Dictionary=load("res://scripts/sprite_hurt_geometry.gd").frame_cache
	var count_before:=shapes_before.size();target.update_presentation();assert(shapes_before.size()==count_before)
	results.windup={"frame":3,"raised_arm_query_changed":true,"material_region_follows_frame":true,"cache_reused":true}
	target.apply_damage(10000,99,&"pistol",target.global_position)
	assert(target.sprite.frame==6)
	for body in target.hurt_shapes:assert(body.collision_layer==0 and body.collision_mask==0)
	target._physics_process(1.0);assert(target.sprite.frame==7)
	target._physics_process(5.0);assert(target.sprite.frame==7)
	for body in target.hurt_shapes:assert(body.collision_layer==0)
	results.death={"fall_frame":6,"persistent_corpse_frame":7,"all_hurt_surfaces_disabled":true}
	var file:=FileAccess.open("res://verification/combat/sprite-alpha-contract.json",FileAccess.WRITE);file.store_string(JSON.stringify(results,"  ")+"\n");file.close()
	print("SPRITE_ALPHA_OK: opaque native raster hits; transparent mouth/limb misses; explicit flesh/armor; posed arm changes; camera-facing geometry; cache; nozzle anchor; persistent noncolliding corpse")
	world.free();combat=null;target=null;player=null
	load("res://scripts/sprite_hurt_geometry.gd").frame_cache.clear();load("res://scripts/sprite_hurt_geometry.gd").image_cache.clear()
	await process_frame;await process_frame;quit()
