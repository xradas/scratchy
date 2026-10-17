extends SceneTree
## Controlled cameras in actual Main; no image synthesis or gameplay-route claim.
var main:Node
var capture_base := "/tmp/eyesore-v13-layout-views"
var structural := false
func _initialize()->void:call_deferred("run")
func run()->void:
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--layout-capture-root="):capture_base=argument.trim_prefix("--layout-capture-root=")
  if argument=="--structural-views":structural=true
 root.set_flag(Window.FLAG_NO_FOCUS,true)
 main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 await process_frame;await physics_frame
 main.enter_combat()
 main.world.set_physics_process(false);main.player.set_physics_process(false);main.combat.set_physics_process(false)
 for enemy in main.combat.enemies:enemy.set_physics_process(false)
 var level:String=main.campaign.current_level().id
 var path:=capture_base+"/"+level
 DirAccess.make_dir_recursive_absolute(path)
 var poses:Array=[]
 var capture_records:Array=[]
 if level=="pale_ward_01":
  poses=[['reception',Vector3(8,.95,9),Vector3(0,1.8,-14)],['triage',Vector3(8,.95,-30),Vector3(-4,1.7,-48)],['theatre',Vector3(86,2.95,8),Vector3(74,3.4,-7)],['decon',Vector3(8,2.95,88),Vector3(0,3.7,70)],['transfer',Vector3(46,4.95,89),Vector3(40,5.7,110)]]
 elif level=="pale_ward_02":
  poses=[['overlook',Vector3(8,4.95,9),Vector3(0,2,-40)],['culture',Vector3(-72,4.95,8),Vector3(-84,5.6,-10)],['reservoir',Vector3(8,.95,-30),Vector3(-3,2,-45)],['bridge',Vector3(-12,6.95,-40),Vector3(30,7,-40)]]
 else:
  poses=[['upper',Vector3(46,8.95,-30),Vector3(40,9.7,-48)],['middle',Vector3(46,4.95,50),Vector3(36,5.7,28)],['lower',Vector3(46,.95,90),Vector3(35,1.7,70)],['rupture',Vector3(48,-3.05,130),Vector3(35,-2.5,110)],['silo-vista',Vector3(48,8.95,-30),Vector3(40,4,15)],['silo-bridge',Vector3(40,6.95,0),Vector3(42,-1,15)]]
 if structural:
  if level=="pale_ward_01":poses=[['triage-court',Vector3(-10,.95,-32),Vector3(-30,1.7,-41)],['nurse-return',Vector3(-32,2.2,-43),Vector3(-8,1.6,-37)]]
  elif level=="pale_ward_02":poses=[['balcony-sealed',Vector3(8,4.95,-17),Vector3(8,2,-40)],['balcony-drained',Vector3(8,4.95,-17),Vector3(6,1.7,-40)]]
  else:poses=[['transfer-court',Vector3(72,4.95,47),Vector3(48,5.7,37)],['crossfire-return',Vector3(48,4.95,35),Vector3(75,5.7,42)]]
 for pose in poses:
  if pose[0]=="balcony-drained":
   main.world.set_progress_flag("isolation_a");main.world.set_progress_flag("isolation_b")
   main.world.set_physics_process(true)
   for frame in 120:await physics_frame
   main.world.set_physics_process(false)
  main.player.global_position=pose[1];main.player.get_node("Camera3D").look_at(pose[2],Vector3.UP)
  for frame in 3:await process_frame
  RenderingServer.force_draw(false);await RenderingServer.frame_post_draw
  var result=root.get_texture().get_image().save_png(path+"/"+pose[0]+".png")
  if result!=OK:push_error("Capture failed");quit(1);return
  capture_records.append({"name":pose[0],"player_pose":pose[1],"look_target":pose[2],"flags":main.world.flags.duplicate(),"png_sha256":FileAccess.get_sha256(path+"/"+pose[0]+".png")})
 var capture_receipt:={"level":level,"scene_sha256":FileAccess.get_sha256("res://scenes/campaign/"+level+".tscn"),"stage_script_sha256":FileAccess.get_sha256("res://scripts/stage_level.gd"),"structural":structural,"captures":capture_records,"scope":"Controlled actual Main rendering; positioned player and camera, frozen AI/movement. Containment drained view explicitly sets both feed flags, not a played objective sequence. No image processing or human acceptance claim."}
 FileAccess.open(path+"/capture.json",FileAccess.WRITE).store_string(JSON.stringify(capture_receipt,"  ")+"\n")
 print("V13_LAYOUT_CAPTURE_OK: "+path+" controlled actual-Main views; AI/movement frozen, no route or human acceptance claim")
 # Real wall time lets the audio backend retire voices in accelerated captures.
 main.combat_audio.stop_all();main.menu_music.stop();main.menu_music.stream=null
 var stopped_at:=Time.get_ticks_msec()
 while Time.get_ticks_msec()-stopped_at<300:await process_frame
 main.combat.gore.reset()
 main.queue_free();main=null
 for frame in 4:await physics_frame
 preload("res://scripts/sprite_hurt_geometry.gd").frame_cache.clear()
 preload("res://scripts/sprite_hurt_geometry.gd").image_cache.clear()
 var freed_at:=Time.get_ticks_msec()
 while Time.get_ticks_msec()-freed_at<250:await process_frame
 quit(0)
