extends Node
# Original procedural mesh authorship, not imported or generated-image art.
# Coordinate units are meters. Camera faces -Z; barrel direction is -Z.
var view: SubViewport
var world: Node3D
var assembly: Node3D
var mats={}
var export_root: String
var camera: Camera3D
var current_muzzle: Node3D
var cleanup_markers: Dictionary={}
var render_metadata: Dictionary={}
func _ready():
 export_root=ProjectSettings.globalize_path("res://../assets/weapons")
 _materials()
 view=SubViewport.new(); view.size=Vector2i(320,180); view.transparent_bg=true
 view.render_target_update_mode=SubViewport.UPDATE_ALWAYS; view.own_world_3d=true
 add_child(view)
 world=Node3D.new(); view.add_child(world)
 var env=WorldEnvironment.new(); var e=Environment.new()
 e.background_mode=Environment.BG_COLOR; e.background_color=Color(0,0,0,0)
 e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color=Color("aab8c5"); e.ambient_light_energy=.35
 e.tonemap_mode=Environment.TONE_MAPPER_LINEAR; env.environment=e; world.add_child(env)
 var key=DirectionalLight3D.new(); key.rotation_degrees=Vector3(-32,-24,0); key.light_color=Color("e6ead9"); key.light_energy=1.35; world.add_child(key)
 var fill=DirectionalLight3D.new(); fill.rotation_degrees=Vector3(-5,120,0); fill.light_color=Color("587d91"); fill.light_energy=.35; world.add_child(fill)
 camera=Camera3D.new(); camera.fov=50; camera.near=.03; world.add_child(camera); camera.current=true
 var preview=TextureRect.new(); preview.texture=view.get_texture(); preview.size=Vector2(320,180); add_child(preview)
 for weapon in ["pistol","shotgun","melee"]:
  render_metadata[weapon]={}
  for pose in ["idle","fire","recover","switch"]:
   if is_instance_valid(assembly): world.remove_child(assembly); assembly.queue_free()
   assembly=Node3D.new(); assembly.position.y=.145 if weapon=="melee" else .105 if weapon=="pistol" else .090; world.add_child(assembly)
   _weapon(weapon,pose)
   for i in range(5): await RenderingServer.frame_post_draw
   var img=view.get_texture().get_image(); img.save_png(export_root+"/"+weapon+"/raw_"+pose+".png")
   var record={"muzzle":null,"cleanup_markers":{}}
   if is_instance_valid(current_muzzle): record.muzzle=_point(camera.unproject_position(current_muzzle.global_position))
   for key_name in cleanup_markers: record.cleanup_markers[key_name]=_point(camera.unproject_position(cleanup_markers[key_name].global_position))
   render_metadata[weapon][pose]=record
   print("Rendered ",weapon,"/",pose," ",img.get_size())
 var meta_file=FileAccess.open(ProjectSettings.globalize_path("res://render_metadata.json"),FileAccess.WRITE)
 meta_file.store_string(JSON.stringify(render_metadata,"  ")+"\n"); meta_file.close()
 print("Original mesh weapon frames complete.")
 get_tree().quit()
func _point(p:Vector2): return [roundi(p.x),roundi(p.y)]
func _marker(pos:Vector3,parent:Node3D,key_name:String):
 var n=Node3D.new(); n.position=pos; parent.add_child(n); cleanup_markers[key_name]=n
 return n
func _materials():
 mats.steel=_mat("35434c",.22,.65)
 mats.body=_mat("1f282d",.08,.87)
 mats.dark=_mat("17222c",.12,.78)
 mats.edge=_mat("7b8585",.23,.55)
 mats.glove=_mat("26312e",.0,.91)
 mats.glove_dark=_mat("111b1b",.0,.90)
 mats.seam=_mat("454d46",.0,.95)
 mats.polymer=_mat("3b4943",.0,.81)
 mats.scratch=_mat("697980",.44,.55)
 mats.brass=_mat("967c46",.43,.6)
 mats.orange=_mat("a36c3e",.05,.82)
func _mat(hex:String,metal:float,rough:float)->StandardMaterial3D:
 var m=StandardMaterial3D.new(); m.albedo_color=Color(hex); m.metallic=metal; m.roughness=rough
 m.cull_mode=BaseMaterial3D.CULL_DISABLED
 var noise=FastNoiseLite.new(); noise.seed=hex.hex_to_int()%10000; noise.noise_type=FastNoiseLite.TYPE_VALUE; noise.frequency=.41; noise.fractal_octaves=1
 var texture=NoiseTexture2D.new(); texture.width=64; texture.height=64; texture.noise=noise; texture.seamless=true; texture.generate_mipmaps=false
 var ramp=Gradient.new(); ramp.interpolation_mode=Gradient.GRADIENT_INTERPOLATE_CONSTANT
 ramp.offsets=PackedFloat32Array([0.0,.24,.44,.65,.82,1.0]); ramp.colors=PackedColorArray([Color(.90,.90,.91),Color(.93,.93,.94),Color(.95,.95,.96),Color(.97,.97,.97),Color(.99,.99,.99),Color(1,1,1)])
 texture.color_ramp=ramp; m.albedo_texture=texture; m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
 return m
func _mesh(mesh:Mesh,pos:Vector3,mat:Material,parent:Node3D=assembly)->MeshInstance3D:
 var n=MeshInstance3D.new(); n.mesh=mesh; n.material_override=mat; n.position=pos; parent.add_child(n); return n
func _box(pos:Vector3,size:Vector3,mat:Material,parent:Node3D=assembly):
 var b=BoxMesh.new(); b.size=size; return _mesh(b,pos,mat,parent)
func _ball(pos:Vector3,scale_v:Vector3,mat:Material,parent:Node3D=assembly):
 var s=SphereMesh.new(); s.radius=1; s.height=2; s.radial_segments=12; s.rings=8
 var n=_mesh(s,pos,mat,parent); n.scale=scale_v; return n
func _bone(a:Vector3,b:Vector3,r:float,mat:Material,parent:Node3D=assembly):
 var cy=CylinderMesh.new(); cy.top_radius=r*.91; cy.bottom_radius=r; cy.height=a.distance_to(b); cy.radial_segments=10
 var n=_mesh(cy,(a+b)*.5,mat,parent)
 var dir=(b-a).normalized(); n.quaternion=Quaternion(Vector3.UP,dir); return n
func _tube(pos:Vector3,radius:float,length_v:float,mat:Material,parent:Node3D=assembly):
 var cy=CylinderMesh.new(); cy.top_radius=radius; cy.bottom_radius=radius; cy.height=length_v; cy.radial_segments=12
 var n=_mesh(cy,pos,mat,parent); n.rotation_degrees.x=90; return n
func _chamfer(pos:Vector3,size:Vector3,bevel:float,mat:Material,parent:Node3D=assembly):
 # Eight-sided real solid extrusion; silhouette corners and face normals are authored.
 var x=size.x*.5; var y=size.y*.5; var z=size.z*.5; var v=bevel
 var p=[Vector2(-x+v,-y),Vector2(x-v,-y),Vector2(x,-y+v),Vector2(x,y-v),Vector2(x-v,y),Vector2(-x+v,y),Vector2(-x,y-v),Vector2(-x,-y+v)]
 var st=SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in range(8):
  var j=(i+1)%8
  _tri(st,Vector3(p[i].x,p[i].y,-z),Vector3(p[j].x,p[j].y,-z),Vector3(p[j].x,p[j].y,z))
  _tri(st,Vector3(p[i].x,p[i].y,-z),Vector3(p[j].x,p[j].y,z),Vector3(p[i].x,p[i].y,z))
  _tri(st,Vector3(0,0,-z),Vector3(p[j].x,p[j].y,-z),Vector3(p[i].x,p[i].y,-z))
  _tri(st,Vector3(0,0,z),Vector3(p[i].x,p[i].y,z),Vector3(p[j].x,p[j].y,z))
 st.generate_normals(); return _mesh(st.commit(),pos,mat,parent)
func _tri(st:SurfaceTool,a:Vector3,b:Vector3,c:Vector3):
 st.set_uv(Vector2(a.x*6.0,a.z*6.0+a.y*4.0)); st.add_vertex(a)
 st.set_uv(Vector2(b.x*6.0,b.z*6.0+b.y*4.0)); st.add_vertex(b)
 st.set_uv(Vector2(c.x*6.0,c.z*6.0+c.y*4.0)); st.add_vertex(c)
func _glove(pos:Vector3,rot:Vector3,side:int=1,parent:Node3D=assembly):
 # A modeled palm, thumb opposition and four segmented curled fingers.
 var hand=Node3D.new(); parent.add_child(hand); hand.position=pos; hand.rotation_degrees=rot
 _ball(Vector3(0,0,0),Vector3(.066,.078,.044),mats.glove,hand)
 _chamfer(Vector3(0,.011,.036),Vector3(.095,.066,.014),.013,mats.glove_dark,hand)
 _box(Vector3(-.020,.016,.048),Vector3(.006,.043,.003),mats.polymer,hand)
 _box(Vector3(.020,.016,.048),Vector3(.006,.043,.003),mats.polymer,hand)
 # Four fingers wrap the grip, with individual metacarpal pads and seam loops.
 for i in range(4):
  var x=(i-1.5)*.029
  _chamfer(Vector3(x,.057,-.008),Vector3(.030,.029,.032),.006,mats.glove,hand)
  _ball(Vector3(x,.070,-.009),Vector3(.015,.014,.017),mats.glove,hand)
  _bone(Vector3(x,.042,-.02),Vector3(x,.020,-.066),.014,mats.glove,hand)
  _ball(Vector3(x,.018,-.060),Vector3(.016,.018,.017),mats.glove_dark,hand)
  _bone(Vector3(x,.017,-.063),Vector3(x,-.014,-.070),.013,mats.glove,hand)
  _bone(Vector3(x-.011,.054,.009),Vector3(x+.010,.054,.009),.003,mats.seam,hand)
 # Opposed thumb across grip’s inner side.
 _bone(Vector3(-.061*side,-.014,.001),Vector3(-.057*side,.039,-.035),.022,mats.glove,hand)
 _ball(Vector3(-.056*side,.039,-.035),Vector3(.023,.022,.020),mats.glove,hand)
 _bone(Vector3(-.056*side,.039,-.035),Vector3(-.030*side,.054,-.053),.018,mats.glove,hand)
 _chamfer(Vector3(0,-.063,.003),Vector3(.127,.035,.080),.009,mats.glove_dark,hand)
 _box(Vector3(0,-.064,.048),Vector3(.082,.017,.008),mats.polymer,hand)
 return hand
func _arm(a:Vector3,b:Vector3,parent:Node3D=assembly):
 _bone(a,b,.067,mats.glove_dark,parent)
 _bone(a.lerp(b,.45),b,.070,mats.glove,parent)
 _bone(a.lerp(b,.74),a.lerp(b,.82),.074,mats.seam,parent)
func _grip_hand(parent:Node3D=assembly):
 _arm(Vector3(.29,-.62,-.25),Vector3(.085,-.360,-.548),parent)
 _glove(Vector3(.080,-.318,-.589),Vector3(8,-8,-24),1,parent)
func _weapon(weapon:String,pose:String):
 cleanup_markers={}; current_muzzle=null
 if weapon=="melee":
  _melee(pose); return
 # Shared stable held-view hierarchy; each weapon has independently authored forms.
 var yaw=Node3D.new(); assembly.add_child(yaw)
 var aim_pivot=Vector3(0,-.24,-1.02 if weapon=="pistol" else -1.54)
 yaw.position=aim_pivot; yaw.rotation_degrees.y=4.5
 var grip_pivot=Vector3(0,-.24,-.58 if weapon=="pistol" else -.50)
 var grip_rig=Node3D.new(); yaw.add_child(grip_rig); grip_rig.position=grip_pivot-aim_pivot
 grip_rig.rotation_degrees.x=10 if weapon=="pistol" else 8.5
 var gun=Node3D.new(); grip_rig.add_child(gun); gun.position=-grip_pivot
 if pose=="fire": grip_rig.position+=Vector3(0,-.006,.055); grip_rig.rotation_degrees.x+=7
 elif pose=="recover": grip_rig.position+=Vector3(0,-.008,.020); grip_rig.rotation_degrees.x+=2.4
 elif pose=="switch": grip_rig.position+=Vector3(.11,-.17,.055); grip_rig.rotation_degrees+=Vector3(12,14,-10)
 if weapon=="pistol":
  _pistol(gun,pose); current_muzzle=_marker(Vector3(0,-.255,-1.025),gun,"muzzle")
  _marker(Vector3(-.048,-.202,-.82),gun,"slide_chip")
  _marker(Vector3(-.026,-.186,-.805),gun,"slide_scratch")
  _marker(Vector3(.055,-.261,-.604),gun,"latch")
 else:
  _shotgun(gun,pose); current_muzzle=_marker(Vector3(0,-.219,-1.553),gun,"muzzle")
  _marker(Vector3(-.010,-.185,-1.205),gun,"barrel_nick")
  _marker(Vector3(-.047,-.218,-.664),gun,"receiver_wear")
  _marker(Vector3(.075,-.283,-.513),gun,"safety")
func _pistol(gun:Node3D,pose:String):
 # Compact service pistol. Slide, frame, ports, sights and grip are actual solids.
 var slide=Node3D.new(); gun.add_child(slide); slide.position.z=.035 if pose=="fire" else .012 if pose=="recover" else 0.0
 _chamfer(Vector3(0,-.237,-.77),Vector3(.125,.097,.40),.019,mats.body,slide)
 _chamfer(Vector3(0,-.186,-.770),Vector3(.104,.008,.364),.006,mats.steel,slide)
 _chamfer(Vector3(0,-.239,-.566),Vector3(.083,.047,.008),.008,mats.dark,slide)
 _box(Vector3(-.027,-.239,-.559),Vector3(.007,.030,.004),mats.scratch,slide)
 _box(Vector3(.027,-.239,-.559),Vector3(.007,.030,.004),mats.scratch,slide)
 _chamfer(Vector3(0,-.279,-.73),Vector3(.108,.057,.39),.011,mats.dark,gun)
 _tube(Vector3(0,-.255,-.923),.021,.20,mats.dark,gun)
 _tube(Vector3(0,-.255,-1.02),.025,.008,mats.edge,gun)
 _chamfer(Vector3(0,-.184,-.792),Vector3(.052,.014,.235),.005,mats.dark,slide)
 for i in range(5): _box(Vector3(0,-.175,-.719-i*.029),Vector3(.047,.003,.006),mats.scratch,slide)
 _box(Vector3(.046,-.215,-.768),Vector3(.017,.031,.108),mats.dark,slide)
 _box(Vector3(.052,-.213,-.76),Vector3(.006,.006,.091),mats.edge,slide)
 # Rear serrations, deliberately separated solids, no flat stencil substitute.
 for i in range(6):
  _box(Vector3(.059,-.24,-.601-i*.015),Vector3(.006,.058,.005),mats.dark,slide)
  _box(Vector3(-.059,-.24,-.601-i*.015),Vector3(.006,.058,.005),mats.dark,slide)
 _box(Vector3(0,-.177,-.955),Vector3(.016,.032,.027),mats.dark,slide)
 _box(Vector3(0,-.164,-.952),Vector3(.007,.007,.008),mats.polymer,slide)
 _box(Vector3(-.043,-.180,-.612),Vector3(.027,.024,.022),mats.dark,slide)
 _box(Vector3(.043,-.180,-.612),Vector3(.027,.024,.022),mats.dark,slide)
 _box(Vector3(-.040,-.169,-.602),Vector3(.011,.005,.007),mats.polymer,slide)
 _box(Vector3(.040,-.169,-.602),Vector3(.011,.005,.007),mats.polymer,slide)
 var grip=_chamfer(Vector3(0,-.382,-.58),Vector3(.101,.190,.115),.018,mats.dark,gun); grip.rotation_degrees.x=-14
 for i in range(5): _box(Vector3(.047,-.332-i*.026,-.573),Vector3(.011,.007,.073),mats.polymer,gun)
 # Open trigger guard is an authored curve of connected solid pieces.
 _bone(Vector3(0,-.304,-.72),Vector3(0,-.365,-.735),.010,mats.dark,gun)
 _bone(Vector3(0,-.365,-.735),Vector3(0,-.382,-.647),.010,mats.dark,gun)
 _bone(Vector3(0,-.306,-.669),Vector3(0,-.353,-.695),.009,mats.steel,gun)
 _grip_hand(gun)
 # Slide recoils only on accepted-fire pose; same mesh construction each frame.
 if pose=="fire": _box(Vector3(.04,-.209,-.65),Vector3(.02,.02,.031),mats.brass,gun)
 # Small stamped wear strokes are modeled shallow inlay, consistently projected.
 _box(Vector3(-.047,-.205,-.797),Vector3(.006,.003,.262),mats.edge,gun)
 _box(Vector3(-.027,-.186,-.803),Vector3(.026,.001,.004),mats.scratch,gun)
 _box(Vector3(.022,-.186,-.718),Vector3(.012,.001,.004),mats.scratch,gun)
func _shotgun(gun:Node3D,pose:String):
 var pump_offset=.065 if pose=="recover" else 0.0
 # Pump shotgun: barrel, separate magazine, receiver, fore-end, carrier and sights.
 _chamfer(Vector3(0,-.272,-.638),Vector3(.143,.129,.327),.026,mats.body,gun)
 _chamfer(Vector3(0,-.201,-.638),Vector3(.117,.012,.290),.008,mats.steel,gun)
 _chamfer(Vector3(0,-.265,-.472),Vector3(.096,.076,.008),.012,mats.dark,gun)
 _box(Vector3(-.028,-.247,-.466),Vector3(.008,.008,.003),mats.edge,gun)
 _box(Vector3(.028,-.247,-.466),Vector3(.008,.008,.003),mats.edge,gun)
 _box(Vector3(0,-.272,-.466),Vector3(.052,.006,.003),mats.scratch,gun)
 _chamfer(Vector3(0,-.330,-.551),Vector3(.118,.068,.196),.018,mats.dark,gun)
 _tube(Vector3(0,-.219,-1.158),.032,.772,mats.steel,gun)
 _box(Vector3(-.012,-.188,-1.167),Vector3(.009,.002,.685),mats.edge,gun)
 _box(Vector3(.020,-.193,-1.171),Vector3(.005,.002,.674),mats.dark,gun)
 _tube(Vector3(0,-.281,-1.094),.027,.584,mats.dark,gun)
 _tube(Vector3(0,-.218,-1.535),.037,.016,mats.edge,gun)
 _tube(Vector3(0,-.281,-1.378),.031,.014,mats.edge,gun)
 _tube(Vector3(0,-.253,-.862),.045,.040,mats.dark,gun)
 _tube(Vector3(0,-.281,-1.06+pump_offset),.058,.235,mats.polymer,gun)
 for i in range(9): _tube(Vector3(0,-.281,-.956-i*.024+pump_offset),.061,.008,mats.dark,gun)
 _box(Vector3(0,-.168,-1.45),Vector3(.012,.039,.025),mats.dark,gun)
 _box(Vector3(0,-.149,-1.45),Vector3(.008,.005,.008),mats.brass,gun)
 _box(Vector3(-.045,-.194,-.524),Vector3(.025,.022,.027),mats.dark,gun)
 _box(Vector3(.045,-.194,-.524),Vector3(.025,.022,.027),mats.dark,gun)
 # Receiver ejection port and exposed mechanical lip.
 _chamfer(Vector3(0,-.185,-.639),Vector3(.056,.013,.201),.006,mats.dark,gun)
 for i in range(6): _box(Vector3(0,-.176,-.561-i*.026),Vector3(.052,.004,.007),mats.scratch,gun)
 _box(Vector3(.071,-.251,-.675),Vector3(.005,.052,.133),mats.dark,gun)
 _box(Vector3(.075,-.227,-.674),Vector3(.004,.006,.114),mats.edge,gun)
 var grip=_chamfer(Vector3(0,-.414,-.496),Vector3(.092,.20,.117),.019,mats.dark,gun); grip.rotation_degrees.x=-19
 _bone(Vector3(0,-.334,-.676),Vector3(0,-.395,-.679),.011,mats.dark,gun)
 _bone(Vector3(0,-.395,-.679),Vector3(0,-.403,-.550),.011,mats.dark,gun)
 _bone(Vector3(0,-.334,-.587),Vector3(0,-.379,-.612),.009,mats.steel,gun)
 _grip_hand(gun)
 _arm(Vector3(-.28,-.64,-.34),Vector3(-.077,-.346,-.995+pump_offset),gun)
 _glove(Vector3(-.059,-.306,-1.032+pump_offset),Vector3(-70,2,74),-1,gun)
 # Deliberate asymmetrical shallow scratches and riveted safety catch.
 _box(Vector3(-.027,-.207,-.603),Vector3(.021,.001,.008),mats.scratch,gun)
 _box(Vector3(.021,-.208,-.700),Vector3(.028,.001,.004),mats.scratch,gun)
 _ball(Vector3(.074,-.283,-.513),Vector3(.011,.010,.005),mats.brass,gun)
func _fist(pos:Vector3,rotation_v:Vector3,parent:Node3D=assembly):
 var fist=Node3D.new(); parent.add_child(fist); fist.position=pos; fist.rotation_degrees=rotation_v
 _ball(Vector3.ZERO,Vector3(.077,.078,.060),mats.glove,fist)
 _chamfer(Vector3(0,.008,.054),Vector3(.115,.073,.013),.017,mats.glove_dark,fist)
 _box(Vector3(-.022,.016,.064),Vector3(.006,.047,.004),mats.polymer,fist)
 _box(Vector3(.022,.016,.064),Vector3(.006,.047,.004),mats.polymer,fist)
 for i in range(4):
  var x=(i-1.5)*.037
  _chamfer(Vector3(x,.044,-.053),Vector3(.033,.028,.036),.007,mats.glove,fist)
  _ball(Vector3(x,.056,-.052),Vector3(.017,.015,.020),mats.glove,fist)
  _ball(Vector3(x,.003,-.067),Vector3(.023,.031,.020),mats.glove_dark,fist)
  _bone(Vector3(x-.015,.052,-.066),Vector3(x+.015,.052,-.066),.004,mats.seam,fist)
 _bone(Vector3(-.070,-.010,-.014),Vector3(-.039,-.032,-.064),.024,mats.glove,fist)
 _chamfer(Vector3(0,-.076,.007),Vector3(.135,.037,.094),.015,mats.glove_dark,fist)
 _box(Vector3(0,-.075,.059),Vector3(.074,.018,.008),mats.polymer,fist)
 return fist
func _melee(pose:String):
 var right=Vector3(.21,-.28,-.58); var rot=Vector3(54,-20,-20)
 if pose=="fire": right=Vector3(.025,-.067,-.59); rot=Vector3(22,0,8)
 elif pose=="recover": right=Vector3(.09,-.17,-.63); rot=Vector3(8,-10,-7)
 elif pose=="switch": right=Vector3(.26,-.43,-.5)
 var left=Vector3(-.22,-.30,-.7)
 if pose=="switch": left.y-=.17
 _arm(Vector3(.35,-.68,-.28),right+Vector3(0,-.08,.06)); _fist(right,rot)
 _arm(Vector3(-.35,-.63,-.3),left+Vector3(0,-.075,.06)); _fist(left,Vector3(58,24,13))
