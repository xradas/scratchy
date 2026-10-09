extends Node
const Rig=preload("res://creature_rig.gd")
var viewport:SubViewport
var creature:Node3D
var camera:Camera3D
func _ready():
 viewport=SubViewport.new(); viewport.size=Vector2i(640,360); viewport.own_world_3d=true; viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; add_child(viewport)
 var root=Node3D.new(); viewport.add_child(root)
 var env=WorldEnvironment.new(); var e=Environment.new(); e.background_mode=Environment.BG_COLOR; e.background_color=Color("1C252C"); e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color=Color("909CA1"); e.ambient_light_energy=.36; env.environment=e; root.add_child(env)
 var key=DirectionalLight3D.new(); key.rotation_degrees=Vector3(-35,-24,0); key.light_color=Color("F0E5CF"); key.light_energy=1.65; key.shadow_enabled=true; root.add_child(key)
 var rim=DirectionalLight3D.new(); rim.rotation_degrees=Vector3(-20,140,0); rim.light_color=Color("779794"); rim.light_energy=.65; root.add_child(rim)
 var floor_mesh=MeshInstance3D.new(); var floor_plane=PlaneMesh.new(); floor_plane.size=Vector2(12,12); floor_mesh.mesh=floor_plane; floor_mesh.position.y=-.85; var floor_mat=StandardMaterial3D.new(); floor_mat.albedo_color=Color("303C42"); floor_mat.roughness=1.; floor_mesh.material_override=floor_mat; root.add_child(floor_mesh)
 camera=Camera3D.new(); camera.fov=48; camera.position=Vector3(0,.22,-3.2); root.add_child(camera); camera.look_at(Vector3(0,.01,0)); camera.current=true
 var preview=TextureRect.new(); preview.texture=viewport.get_texture(); preview.size=Vector2(640,360); add_child(preview)
 var report={}
 for kind in [&"unsealed",&"vessel"]:
  creature=Rig.new(); root.add_child(creature); creature.configure(kind); report[str(kind)]={}
  for pose in [&"chase",&"windup",&"recovery",&"pain",&"dead"]:
   var t=.19 if pose==&"chase" else .40 if pose==&"windup" else .15 if pose==&"recovery" else .09 if pose==&"pain" else 2.
   creature.present(pose,t,.45,.6,.18)
   for frame in range(5): await RenderingServer.frame_post_draw
   viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../renders/"+str(kind)+"_"+str(pose)+".png"))
   var b: AABB=creature.bounds_now(); report[str(kind)][str(pose)]={"min":[b.position.x,b.position.y,b.position.z],"max":[b.end.x,b.end.y,b.end.z]}
  creature.present(&"chase",0.,.45,.6,.18)
  for angle in [0,45,90,135,180]:
   creature.rotation.y=deg_to_rad(angle)
   for frame in range(4): await RenderingServer.frame_post_draw
   viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../renders/"+str(kind)+"_angle_"+str(angle)+".png"))
  creature.rotation.y=0; camera.position=Vector3(0,.22,-6.); camera.look_at(Vector3(0,.10,0)); creature.present(&"chase",.19)
  for frame in range(5): await RenderingServer.frame_post_draw
  viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../renders/"+str(kind)+"_game_scale_6m.png"))
  camera.position=Vector3(0,.58,-1.10); camera.look_at(Vector3(0,.40,-.10)); creature.present(&"chase",0.)
  for frame in range(5): await RenderingServer.frame_post_draw
  viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../renders/"+str(kind)+"_closeup.png"))
  camera.position=Vector3(0,.22,-3.2); camera.look_at(Vector3(0,.01,0)); root.remove_child(creature); creature.queue_free()
 var file=FileAccess.open(ProjectSettings.globalize_path("res://../bounds.json"),FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")+"\n"); file.close()
 print("Rendered original live creature study at640x360; bounds saved.")
 get_tree().quit()
