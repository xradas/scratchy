extends SceneTree
## Actual Main bound scene is the target. A temporary copy stripped ONLY of v9
## presentation compares physical geometry; all captures use production scene.
## Production scene/source are never written. Camera/state fixture, not route play.
var app: Control
var failures: Array[String] = []
var checks := 0
var capture := false
var fixture := "/tmp/eyesore-equipment-v9-baseline.tscn"
const OUTPUT := "res://verification/production-v9/surfaces"
func _initialize() -> void:
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--surface-baseline="): fixture=argument.trim_prefix("--surface-baseline=")
 call_deferred("run")
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok: failures.append(label); push_error("SURFACES_V9: " + label)
func descendants(node: Node) -> Array[Node]:
 var result: Array[Node] = [node]
 for child in node.get_children(): result.append_array(descendants(child))
 return result
func stable_path(node: Node) -> String:
 var expression := RegEx.new(); expression.compile("@[A-Za-z0-9_]+@[0-9]+")
 return expression.sub(String(app.world.get_path_to(node)), "<generated>", true)
func geometry_snapshot() -> Dictionary:
 var result := {}
 for node in descendants(app.world):
  if node is CollisionObject3D:
   result[stable_path(node)+"/body"] = {"transform":str(node.transform),"layer":node.collision_layer,"mask":node.collision_mask,"hit":String(node.get_meta("hit_material", ""))}
  if node is CollisionShape3D:
   var shape: Shape3D = node.shape
   var detail := str(shape.get_class())
   if shape is BoxShape3D: detail += str(shape.size)
   elif shape is CylinderShape3D: detail += str(shape.radius)+str(shape.height)
   elif shape is CapsuleShape3D: detail += str(shape.radius)+str(shape.height)
   elif shape is ConvexPolygonShape3D: detail += str(shape.points)
   result[stable_path(node)+"/shape"] = {"transform":str(node.transform),"geometry":detail}
  if node is MeshInstance3D and not "PresentationV9" in String(node.get_path()):
   result[stable_path(node)+"/mesh"] = {"transform":str(node.transform),"faces":str(node.mesh.get_faces())}
 return result
func freeze() -> void:
 app.player.set_physics_process(false);app.world.set_physics_process(false);app.combat.set_physics_process(false)
 for node in descendants(app.world): node.set_physics_process(false)
func frame() -> void: await process_frame; await process_frame
func controls() -> Array[Node]:
 var result: Array[Node] = []
 for node in get_nodes_in_group("equipment_controls_v9"):
  if app.world.is_ancestor_of(node): result.append(node)
 return result
func update_controls() -> void:
 # Actual Main _process drives its discovered world-scoped component group.
 await frame()
func view(camera: Camera3D, target: Node3D, offset: Vector3, label: String, local_focus := Vector3.ZERO) -> void:
 camera.global_position = target.to_global(local_focus+offset)
 camera.look_at(target.to_global(local_focus))
 await frame()
 if capture:
  RenderingServer.force_draw(false)
  root.get_texture().get_image().save_png(OUTPUT+"/"+label+".png")
func run() -> void:
 capture = "--capture-surfaces-v9" in OS.get_cmdline_user_args()
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
 app = load("res://scenes/main.tscn").instantiate();root.add_child(app)
 if not app.campaign_mode: app.start_new_campaign()
 freeze();app.enter_combat();await frame()
 # Bound and stripped comparison use identical warmed-up frozen physics states.
 var baseline := geometry_snapshot()
 app.campaign.levels[app.campaign.current_index].scene = fixture
 app.restart_combat();freeze()
 await frame()
 var actual := geometry_snapshot()
 var geometry_differences: Array[Dictionary] = []
 for key in baseline:
  if not actual.has(key) or baseline[key] != actual[key]: geometry_differences.append({"path":key,"bound":baseline[key],"stripped":actual.get(key)})
 for key in actual:
  if not baseline.has(key): geometry_differences.append({"path":key,"bound":null,"stripped":actual[key]})
 if not geometry_differences.is_empty(): FileAccess.open(OUTPUT+"/geometry-differences.json",FileAccess.WRITE).store_string(JSON.stringify(geometry_differences,"  "))
 check(actual == baseline, "every original runtime physical body/shape and mesh vertex/transform matches baseline")
 app.campaign.levels[app.campaign.current_index].scene = "res://scenes/campaign/pale_ward_01.tscn"
 app.restart_combat();freeze();await frame()
 check(app.world.scene_file_path == "res://scenes/campaign/pale_ward_01.tscn", "actual production-bound Main scene used for all state checks/captures")
 check(controls().size()==4, "exactly three controls plus exit in world-scoped group")
 var stage_before: Dictionary = app.world.get_level_state().duplicate(true)
 await update_controls()
 check(app.world.get_level_state()==stage_before, "state presentation never writes stage flags")
 for component in controls():
  check(not component.active, String(component.get_parent().name)+" initial inactive/locked")
  for child in descendants(component):
   check(not child is CollisionObject3D and not child is CollisionShape3D, String(component.get_parent().name)+" decoration has no collision")
   if child is MeshInstance3D:
    var local: AABB = child.mesh.get_aabb()
    var bounds: AABB = component.get_parent().global_transform.affine_inverse() * child.global_transform * local
    check(AABB(Vector3(-.55,-.75,-.25),Vector3(1.1,1.5,.58)).encloses(bounds), String(component.get_parent().name)+" indicator inside original combined body/Face envelope")
 var exit_component: Node = app.world.get_node("ExitControl/ControlPresentationV9")
 app.world.flags.exit_control = true;await update_controls()
 check(not exit_component.active, "exit control alone cannot show unlocked exit without both keys")
 app.world.flags.brass_key = true;app.world.flags.red_key = true;await update_controls()
 check(exit_component.active and exit_component._local_surface.get_shader_parameter("engaged"), "exit indicator reads all actual required flags")
 app.world.flags.clear()
 var button: Node = app.world.get_node("Button_breaker/ControlPresentationV9")
 await update_controls()
 var camera := Camera3D.new();camera.fov=68;camera.near=.035;camera.far=700;app.world.add_child(camera);camera.current=true
 app.enter_combat();freeze();root.size=Vector2i(1280,720);await frame();app.layout_view()
 await view(camera,app.world.get_node("Button_breaker"),Vector3(0,.1,2.4),"control-front-inactive")
 var inactive_geometry := {"off":button._off_icon.visible,"on":button._on_icon.visible,"extent":button._stripe.scale.x}
 app.world.flags.breaker = true;await update_controls()
 check(button.active and not button._off_icon.visible and button._on_icon.visible and button._stripe.scale.x > inactive_geometry.extent, "control state changes glyph and stripe extent as well as color")
 await view(camera,app.world.get_node("Button_breaker"),Vector3(0,.1,2.4),"control-front-active")
 await view(camera,app.world.get_node("Button_breaker"),Vector3(2,.2,.4),"control-side")
 await view(camera,app.world.get_node("Button_breaker"),Vector3(0,.1,-2.4),"control-back")
 await view(camera,app.world.get_node("Button_breaker"),Vector3(.7,-1.1,.7),"control-underside")
 var platform: Node3D = app.world.get_node("arena_one_GalleryDeck")
 var platform_mesh: MeshInstance3D = platform.get_node("Visual")
 check(platform_mesh.mesh.get_faces().size()==36 and platform_mesh.material_override.get_shader_parameter("surface_mode")==1, "real gallery BoxMesh retains six closed faces with floor top/trim sides and underside")
 await view(camera,platform,Vector3(0,1.5,11),"platform-front")
 await view(camera,platform,Vector3(7,1.4,0),"platform-side")
 await view(camera,platform,Vector3(0,1.5,-11),"platform-back")
 await view(camera,platform,Vector3(.7,-1.35,.7),"platform-underside")
 var prism: Node3D = app.world.get_node("arena_two_RaisedAltar")
 var prism_mesh: MeshInstance3D
 for child in descendants(prism):
  if child is MeshInstance3D: prism_mesh=child
 check(prism_mesh!=null and prism_mesh.mesh.get_faces().size()==(4*prism.get_meta("stage_polygon").size()-4)*3, "generated convex platform retains both caps and every side")
 check(prism_mesh!=null and prism_mesh.material_override is ShaderMaterial and prism_mesh.material_override.get_shader_parameter("surface_mode")==1, "UV-less generated prism receives deferred native world-projected material")
 var cabinet: Node3D = app.world.get_node("RoomProp_pale_ward_01_entry_records_cabinet_03_1/Body")
 await view(camera,cabinet,Vector3(0,.1,3),"equipment-front")
 await view(camera,cabinet,Vector3(2.7,.1,.3),"equipment-side")
 await view(camera,cabinet,Vector3(0,.1,-3),"equipment-back")
 # Body rests on floor; this angle checks its exposed lower side, not a fake gap.
 await view(camera,cabinet,Vector3(.9,-.9,.9),"equipment-low-side")
 app.world.flags.clear();await update_controls()
 var exit: Node3D = app.world.get_node("ExitControl")
 await view(camera,exit,Vector3(0,.1,2.8),"exit-front-locked")
 app.world.flags.brass_key=true;app.world.flags.red_key=true;app.world.flags.exit_control=true;await update_controls()
 await view(camera,exit,Vector3(0,.1,2.8),"exit-front-ready")
 await view(camera,exit,Vector3(2.3,.1,.3),"exit-side")
 await view(camera,exit,Vector3(0,.1,-2.8),"exit-back")
 await view(camera,exit,Vector3(.6,-1.2,.7),"exit-underside")
 app.set_paused(true)
 var before: Dictionary = app.world.get_level_state().duplicate(true);await update_controls();await frame()
 check(app.world.get_level_state()==before, "pause leaves all actual control/exit gameplay state unchanged")
 var report := {"status":"passed" if failures.is_empty() else "failed","checks":checks,"failures":failures,"original_runtime_geometry_records":baseline.size(),"source_scene_sha256":FileAccess.get_sha256("res://scenes/campaign/pale_ward_01.tscn"),"fixture_scene_sha256":FileAccess.get_sha256(fixture),"scope":"Actual production-bound Main scene and actual Main per-frame stage-snapshot group refresh. A temporary copy stripped only of v9 presentation compares original runtime mesh vertices/colliders/local transforms/hit tags. No injected replacement for state checks/captures and no production edit. Controlled actual flags/free inspection camera; actors frozen. Native views include real deck underside. Cabinet lower-side view does not claim a physical gap beneath a floor-supported body. Not route/human visual acceptance."}
 FileAccess.open(OUTPUT+"/checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
 print("SURFACES_V9 ",report.status," ",checks," ",failures)
 await app.quit_game();quit(0 if failures.is_empty() else 1)
