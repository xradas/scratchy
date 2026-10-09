extends SceneTree
var world:Node3D
var combat:Node3D
var player:CharacterBody3D
var target:CharacterBody3D
var records:Array[Dictionary]=[]
func _initialize()->void:call_deferred("run_check")
func set_pose(frame:int)->void:
	target.dead=frame>=6;target.state_time=0;target.velocity=Vector3.ZERO
	if frame==0:target.state=&"chase"
	elif frame==1 or frame==2:target.state=&"chase";target.velocity.x=1;target.state_time=.125 if frame==2 else 0.0
	elif frame==3:target.state=&"windup"
	elif frame==4:target.state=&"recovery"
	elif frame==5:target.state=&"pain"
	else:target.state=&"dead";target.state_time=1.0 if frame==7 else 0.0
	target.update_presentation()
	assert(target.sprite.frame==frame)
func run_check()->void:
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	world=Node3D.new();root.add_child(world)
	player=CharacterBody3D.new();var camera:=Camera3D.new();camera.name="Camera3D";camera.position.y=.65;camera.current=true;player.add_child(camera);world.add_child(player);player.position=Vector3(0,.87,3.6)
	combat=load("res://scripts/combat.gd").new();world.add_child(combat);combat.setup(world,player);combat.set_physics_process(false)
	for actor in combat.enemies:actor.set_physics_process(false);actor.position.x=50
	target=combat.enemies[0];target.position=Vector3(0,.85,0)
	for kind in ["unsealed","vessel"]:
		var base:String=ProjectSettings.globalize_path("res://concepts/sprite-art-v1/enemies/"+kind+"/")
		var inspection:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(base+"inspection-final.json"))
		var source:=Image.load_from_file(base+"atlas.png");assert(source!=null)
		var texture:=ImageTexture.create_from_image(source)
		var pivots:Dictionary={}
		for cell in inspection.cells:pivots[str(int(cell.index))]=cell.foot_pivot
		var bounds:Array=inspection.cells[0].alpha_bounds_threshold128
		var pixels:float=(1.8 if kind=="unsealed" else 1.6)/float(bounds[3]-bounds[1])
		var options:Dictionary={"rows":2,"pose_frames":{"chase":[0,1,2],"windup":[3],"recovery":[4],"pain":[5],"dead":[6,7]},"frame_pivots":pivots,"hurt_resolution":[128,192],"hurt_material_default":"flesh"}
		if kind=="vessel":
			var reviewed:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://verification/combat/vessel-material-regions.json"))
			options.merge(reviewed.sprite_options,true)
		target.definition=load("res://resources/enemies/"+kind+".tres").duplicate();target.dead=false
		target.configure_sprite_texture(texture,4,1,{},pixels,Vector2(192,inspection.cells[0].foot_pivot[1]),options)
		for frame in 8:
			set_pose(frame);await physics_frame;await physics_frame
			var foot:Array=pivots[str(frame)]
			if options.get("frame_projectile_origins_uv",{}).has(str(frame)):
				var nozzle:Array=options.frame_projectile_origins_uv[str(frame)]
				var anchor:Vector3=target.sprite_pivot.to_global(Vector3((nozzle[0]*384-foot[0])*pixels,(foot[1]-nozzle[1]*512)*pixels,0))
				assert(target.sprite_projectile_origin().is_equal_approx(anchor),"Nozzle must follow frame pivot")
			assert(target.sprite_foot.is_equal_approx(Vector2(foot[0],foot[1])))
			var visible_foot:Vector3=target.sprite_pivot.to_global(Vector3(0,0,0))
			assert(absf(visible_foot.y)<.0001)
			var opaque_hits:=0;var transparent_misses:=0;var armor_contacts:=0
			if frame<6:
				for gy in range(4,192,8):
					for gx in range(4,128,8):
						var uv:=Vector2((gx+.5)/128.0,(gy+.5)/192.0)
						var pixel:=Vector2i(int(uv.x*384),int(uv.y*512))+Vector2i((frame%4)*384,(frame/4)*512)
						var expected:=source.get_pixelv(pixel).a>=.5
						var point:Vector3=target.sprite_pivot.to_global(Vector3((uv.x*384-foot[0])*pixels,(foot[1]-uv.y*512)*pixels,0))
						var normal:Vector3=target.sprite_pivot.global_basis.z
						var hit:Dictionary=combat.ray(point+normal*2,point-normal*2,[target.get_rid(),player.get_rid()],true)
						var contact:bool=not hit.is_empty() and hit.collider.has_meta("combat_target") and hit.collider.get_meta("combat_target")==target
						assert(contact==expected,"Actual native atlas alpha and query silhouette disagree")
						if expected:
							opaque_hits+=1
							var expected_material:StringName=&"flesh"
							for region in options.get("material_regions",{}).get(str(frame),[]):
								if load("res://scripts/sprite_hurt_geometry.gd").inside_region(uv,region):expected_material=&"armor"
							assert(combat.material_for(hit.collider)==expected_material)
						else:transparent_misses+=1
				# Exercise every authored hardware band at its interior raster center.
				for region in options.get("material_regions",{}).get(str(frame),[]):
					var center:=Vector2.ZERO
					for vertex in region.polygon:center+=Vector2(vertex[0],vertex[1])
					center/=region.polygon.size()
					center=Vector2((floorf(center.x*128)+.5)/128,(floorf(center.y*192)+.5)/192)
					var hardware_point:Vector3=target.sprite_pivot.to_global(Vector3((center.x*384-foot[0])*pixels,(foot[1]-center.y*512)*pixels,0))
					var normal:Vector3=target.sprite_pivot.global_basis.z
					var hardware_hit:Dictionary=combat.ray(hardware_point+normal*2,hardware_point-normal*2,[target.get_rid(),player.get_rid()],true)
					assert(not hardware_hit.is_empty() and combat.material_for(hardware_hit.collider)==&"armor","Reviewed visible cage band must route armor")
					armor_contacts+=1
			else:
				for body in target.hurt_shapes:assert(body.collision_layer==0)
			records.append({"kind":kind,"frame":frame,"source_foot_pivot":foot,"ground_y":visible_foot.y,"opaque_alpha_hits":opaque_hits,"transparent_alpha_misses":transparent_misses,"corpse_query_disabled":frame>=6,"pixel_size":pixels,"reviewed_hardware_contacts":armor_contacts})
			if DisplayServer.get_name()!="headless" and frame in [0,3,7]:
				camera.look_at(Vector3(0,.95,0));await RenderingServer.frame_post_draw
				assert(root.get_texture().get_image().save_png("res://verification/combat/atlas-"+kind+"-frame"+str(frame)+".png")==OK)
	var file:=FileAccess.open("res://verification/combat/actual-atlas-contacts.json",FileAccess.WRITE);file.store_string(JSON.stringify({"records":records,"collision_resolution":[128,192],"native_images_unchanged":true,"source_atlas_sha256":{"unsealed":FileAccess.get_sha256(ProjectSettings.globalize_path("res://concepts/sprite-art-v1/enemies/unsealed/atlas.png")),"vessel":FileAccess.get_sha256(ProjectSettings.globalize_path("res://concepts/sprite-art-v1/enemies/vessel/atlas.png"))},"scope":"Front-view representative poses only. Contact equivalence sampled at gameplay raster cell centers; source sub-cell details are bounded raster approximation. Conservative manually traced Vessel collar/rib bands route armor; other opaque tissue defaults flesh."},"  ")+"\n");file.close()
	print("ACTUAL_ATLAS_CONTACTS_OK: both original384x512-cell RGBA atlases; all8 per-frame feet on ground; six living pose alpha samples agree; corpse6/7 query disabled")
	world.free();combat=null;target=null;player=null
	load("res://scripts/sprite_hurt_geometry.gd").frame_cache.clear();load("res://scripts/sprite_hurt_geometry.gd").image_cache.clear()
	await process_frame;await process_frame;quit()
