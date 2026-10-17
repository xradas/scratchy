extends SceneTree
## Controlled actual Main views. Frozen actors/camera poses; no route claim.
var main:Node
var capture_base:="/tmp/eyesore-v14-layout-views"
func _initialize()->void:call_deferred("run")
func run()->void:
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--layout-capture-root="):capture_base=argument.trim_prefix("--layout-capture-root=")
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
 var reserve_room:Vector3
 var arena:String
 if level=="pale_ward_01":
  poses=[["reception",Vector3(-2,.95,8),Vector3(8,1.8,-5)],["diagnostics",Vector3(45,2.95,-34),Vector3(37,3.5,-47)],["recovery",Vector3(-45,2.95,48),Vector3(-31,3.5,37)],["clinical-prep",Vector3(80,2.95,-10),Vector3(80,3.5,-44)]]
  reserve_room=Vector3(-40,0,0);arena="v14_records_reserve"
 elif level=="pale_ward_02":
  poses=[["overlook",Vector3(8,4.95,9),Vector3(0,2,-40)],["cultures",Vector3(-82,4.95,8),Vector3(-89,5.5,-7)],["waste-lab",Vector3(82,4.95,8),Vector3(89,5.5,-7)],["culture-steps",Vector3(-80,2.95,-30),Vector3(-80,5.5,-10)]]
  reserve_room=Vector3(0,4,40);arena="v14_pump_store_reserve"
 else:
  poses=[["loading",Vector3(0,8.95,8),Vector3(9,9.5,-5)],["cultivation",Vector3(-34,.95,88),Vector3(-50,1.7,73)],["rupture",Vector3(48,-3.05,130),Vector3(28,-2.5,108)],["lower-feed-hall",Vector3(-10,.95,80),Vector3(-38,1.7,80)]]
  reserve_room=Vector3(-40,8,0);arena="v14_security_store_reserve"
 var side:float=1.0 if level=="pale_ward_02" else -1.0
 poses.append(["reserve-closed",reserve_room+Vector3(0,.95,-5*side),reserve_room+Vector3(0,1.7,8*side)])
 poses.append(["reserve-open",reserve_room+Vector3(0,.95,-5*side),reserve_room+Vector3(0,1.7,8*side)])
 var records:Array=[]
 for pose in poses:
  if pose[0]=="reserve-open":
   var reward:Node3D
   for item in main.world.pickups:
    if String(item.get_meta("stable_id",""))==level+".pickup.Bonus_"+("records" if level=="pale_ward_01" else "pump_store" if level=="pale_ward_02" else "security_store"):reward=item;break
   if reward==null:push_error("Missing actual reserve reward");quit(1);return
   main.world.collect(reward)
   if not main.world.is_arena_active(arena):push_error("Actual accepted reward did not activate reserve");quit(1);return
   for frame in 90:await physics_frame
  main.player.global_position=pose[1];main.player.get_node("Camera3D").look_at(pose[2],Vector3.UP)
  for frame in 3:await process_frame
  RenderingServer.force_draw(false);await RenderingServer.frame_post_draw
  var filename:=path+"/"+String(pose[0])+".png"
  if root.get_texture().get_image().save_png(filename)!=OK:push_error("Capture failed");quit(1);return
  records.append({"name":pose[0],"player_pose":pose[1],"look_target":pose[2],"flags":main.world.flags.duplicate(),"reserve_active":main.world.is_arena_active(arena),"png_sha256":FileAccess.get_sha256(filename)})
 var receipt:={"level":level,"scene_sha256":FileAccess.get_sha256("res://scenes/campaign/"+level+".tscn"),"stage_script_sha256":FileAccess.get_sha256("res://scripts/stage_level.gd"),"checkpoint_script_sha256":FileAccess.get_sha256("res://scripts/stage_checkpoint_v13.gd"),"hud_script_sha256":FileAccess.get_sha256("res://scripts/industrial_hud_v8.gd"),"captures":records,"scope":"Actual Main rendered pixels, fixed coordinator cameras and frozen actors/movement. Reserve-open invokes collect on the real existing reward and awaits the real door; controlled acceptance, not physical traversal. No image synthesis or edits. Human visual/gameplay acceptance pending."}
 FileAccess.open(path+"/capture.json",FileAccess.WRITE).store_string(JSON.stringify(receipt,"  ")+"\n")
 print("V14_LAYOUT_CAPTURE_OK: "+path)
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
