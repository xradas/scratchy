extends SceneTree
## Display boundary/privacy tests, including actual native automap pixels.
const HUD=preload("res://scripts/industrial_hud_v8.gd")
const MAP=preload("res://scripts/ward_automap.gd")
var failures:Array[String]=[]
var checks:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func covered(point:Vector2,polygons:Array)->bool:
 for polygon in polygons:
  if Geometry2D.is_point_in_polygon(point,polygon):return true
 return false
func run()->void:
 root.set_flag(Window.FLAG_NO_FOCUS,true)
 var hud:=HUD.new();root.add_child(hud)
 # Independent known L: northeast 16x16 cutout, not the envelope or convex hull.
 var footprint:=PackedVector2Array([Vector2(-20,-20),Vector2(4,-20),Vector2(4,-4),Vector2(20,-4),Vector2(20,20),Vector2(-20,20)])
 var state:={"visited_rooms":["seen"],"map_rooms":[{"id":"seen","label":"L room","visited":true,"rect":Rect2(-20,-20,40,40),"footprint":footprint},{"id":"secret","visited":true,"rect":Rect2(-3,-3,6,6),"footprint":footprint},{"id":"false_seen","visited":false,"rect":Rect2(-3,-3,6,6),"footprint":footprint}]}
 var before:Dictionary=state.duplicate(true)
 for dimensions in [Vector2(1280,96),Vector2(800,80),Vector2(640,56)]:
  hud.size=dimensions
  hud.set_display_state({},state,{})
  for actor in [Vector3.ZERO,Vector3(6,0,0),Vector3(-8,0,9)]:
   hud.update_map(state,actor,0)
   var shown:Array=hud.visible_map_rooms()
   check(shown.size()==1 and shown[0].id=="seen","visited identity/flag guard %s %s"%[dimensions,actor])
   check(hud.minimap_geometry().is_empty(),"shaped room is never drawn as envelope")
   var screen:Rect2=hud.layout_snapshot().map.grow(-10)
   screen.position.y+=17;screen.size.y-=17
   var pieces:Array=hud.minimap_polygons()
   for piece in pieces:
    for point in piece:check(screen.grow(.001).has_point(point),"clipped vertex within mini-map frame")
   for sample in [Vector2(-12,-12),Vector2(12,12),Vector2(12,-12),Vector2(23,0)]:
    var projected:Vector2=screen.get_center()+(sample-Vector2(actor.x,actor.z))*2.4
    var expected:bool=screen.has_point(projected) and sample!=Vector2(12,-12) and sample!=Vector2(23,0)
    check(covered(projected,pieces)==expected,"L arms/cutout/outside actual display %s"%sample)
 check(state==before,"map consumer preserves authoritative input")
 var rectangle:={"visited_rooms":["old"],"map_rooms":[{"id":"old","visited":true,"rect":Rect2(-3,-3,6,6)}]}
 hud.update_map(rectangle,Vector3.ZERO,0);hud.set_display_state({},rectangle,{})
 check(hud.minimap_geometry().size()==1 and hud.minimap_polygons().is_empty(),"legacy rectangle remains compatible")
 hud.queue_free();await process_frame
 var automap:=MAP.new();root.add_child(automap);root.size=Vector2i(800,600);automap.size=Vector2(800,600)
 var actual:Dictionary=state.duplicate(true);actual.map_rooms=[state.map_rooms[0]]
 automap.update_map(actual,Vector3.ZERO,0)
 await process_frame
 var native:=DisplayServer.get_name()!="headless"
 if native:
  RenderingServer.force_draw(false);await RenderingServer.frame_post_draw
  var image:=root.get_texture().get_image()
  check(image.get_pixel(275,175).r>.09,"actual automap L arm has room fill")
  check(image.get_pixel(525,175).is_equal_approx(image.get_pixel(700,550)) and image.get_pixel(525,175).r<image.get_pixel(275,175).r*.6,"actual automap notch remains background")
  check(image.get_pixel(525,425).r>.09,"actual automap lower arm has room fill")
  DirAccess.make_dir_recursive_absolute("res://verification/ward-spatial-v14/map-ui")
  image.save_png("res://verification/ward-spatial-v14/map-ui/automap-L.png")
 var report:={"status":"passed" if failures.is_empty() else "failed","checks":checks,"failures":failures,"native_pixels":native,"scope":"Real HUD clipping/read-only privacy and rectangle compatibility, independently specified L arms/notch/outside; native automap rendered pixel boundaries when available. Synthetic display data, no gameplay traversal claim."}
 DirAccess.make_dir_recursive_absolute("res://verification/ward-spatial-v14/map-ui")
 FileAccess.open("res://verification/ward-spatial-v14/map-ui/"+("native" if native else "headless")+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
 print("MAP_UI_V14 ",report)
 quit(0 if failures.is_empty() else 1)
