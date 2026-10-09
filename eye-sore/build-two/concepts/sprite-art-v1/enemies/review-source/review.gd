extends Node2D
var modes=["near","poses"]
var mode="near"
var creatures={}
func _ready():
 texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 for kind in ["unsealed","vessel"]:
  var im=Image.load_from_file(ProjectSettings.globalize_path("res://../"+kind+"/atlas.png"))
  var report=JSON.parse_string(FileAccess.get_file_as_string("res://../"+kind+"/inspection-final.json"))
  creatures[kind]={"texture":ImageTexture.create_from_image(im),"cells":report.cells}
 for m in modes:
  mode=m;queue_redraw()
  for frame in range(4): await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../review/"+m+"-640.png"))
 get_tree().quit()
func _sprite(kind:String,i:int,anchor:Vector2,scale_v:float):
 var cell=creatures[kind].cells[i]
 var region=cell.region;var pivot=Vector2(cell.foot_pivot[0],cell.foot_pivot[1])
 draw_texture_rect_region(creatures[kind].texture,Rect2(anchor-pivot*scale_v,Vector2(384,512)*scale_v),Rect2(region[0],region[1],region[2],region[3]))
func _draw():
 draw_rect(Rect2(0,0,640,360),Color("182028"))
 var font=ThemeDB.fallback_font
 draw_string(font,Vector2(12,23),"Approved-design sprite study | original atlas regions",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("C6CFC9"))
 if mode=="near":
  _sprite("unsealed",0,Vector2(177,325),.70)
  _sprite("vessel",0,Vector2(465,325),.70)
  draw_string(font,Vector2(137,348),"UNSEALED",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("BAC9C1"))
  draw_string(font,Vector2(432,348),"VESSEL",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("BAC9C1"))
 else:
  var labels=["idle","left","right","windup","release","pain","fold","corpse"]
  for row in range(2):
   var kind="unsealed" if row==0 else "vessel"
   for i in range(8):
    _sprite(kind,i,Vector2(40+i*80,170+row*165),.23)
    draw_string(font,Vector2(9+i*80,187+row*165),labels[i],HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("9EAFA8"))
