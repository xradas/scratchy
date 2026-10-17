extends SceneTree
## Controlled cameras in actual Main; no image synthesis or gameplay-route claim.
var main:Node
func _initialize()->void:call_deferred("run")
func run()->void:
 root.set_flag(Window.FLAG_NO_FOCUS,true)
 main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 await process_frame;await physics_frame
 main.enter_combat()
 main.world.set_physics_process(false);main.player.set_physics_process(false);main.combat.set_physics_process(false)
 for enemy in main.combat.enemies:enemy.set_physics_process(false)
 var level:String=main.campaign.current_level().id
 var path:="/tmp/eyesore-v13-layout-views/"+level
 DirAccess.make_dir_recursive_absolute(path)
 var poses:Array=[]
 if level=="pale_ward_01":
  poses=[['reception',Vector3(8,.95,9),Vector3(0,1.8,-14)],['triage',Vector3(8,.95,-30),Vector3(-4,1.7,-48)],['theatre',Vector3(86,2.95,8),Vector3(74,3.4,-7)],['decon',Vector3(8,2.95,88),Vector3(0,3.7,70)],['transfer',Vector3(46,4.95,89),Vector3(40,5.7,110)]]
 elif level=="pale_ward_02":
  poses=[['overlook',Vector3(8,4.95,9),Vector3(0,2,-40)],['culture',Vector3(-72,4.95,8),Vector3(-84,5.6,-10)],['reservoir',Vector3(8,.95,-30),Vector3(-3,2,-45)],['bridge',Vector3(-12,6.95,-40),Vector3(30,7,-40)]]
 else:
  poses=[['upper',Vector3(46,8.95,-30),Vector3(40,9.7,-48)],['middle',Vector3(46,4.95,50),Vector3(36,5.7,28)],['lower',Vector3(46,.95,90),Vector3(35,1.7,70)],['rupture',Vector3(48,-3.05,130),Vector3(35,-2.5,110)],['silo-vista',Vector3(48,8.95,-30),Vector3(40,4,15)],['silo-bridge',Vector3(40,6.95,0),Vector3(42,-1,15)]]
 for pose in poses:
  main.player.global_position=pose[1];main.player.get_node("Camera3D").look_at(pose[2],Vector3.UP)
  for frame in 3:await process_frame
  RenderingServer.force_draw(false);await RenderingServer.frame_post_draw
  var result=root.get_texture().get_image().save_png(path+"/"+pose[0]+".png")
  if result!=OK:push_error("Capture failed");quit(1);return
 print("V13_LAYOUT_CAPTURE_OK: "+path+" controlled actual-Main views; AI/movement frozen, no route or human acceptance claim")
 main.queue_free();await process_frame;quit(0)
