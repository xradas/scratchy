extends Node3D
## Original loft-mesh creature study. Art only: no damage, AI, signals or audio.
## Actor origin is capsule center, feet -.85, forward -Z. configure then present.
var kind: StringName = &"unsealed"
var body: Node3D
var head: Node3D
var jaw: Node3D
var arms: Array[Node3D]=[]
var elbows: Array[Node3D]=[]
var hips: Array[Node3D]=[]
var knees: Array[Node3D]=[]
var sac: Node3D
var material: Dictionary={}
var surfaces: Array[ShaderMaterial]=[]
var base_transforms: Dictionary={}
var art_bounds: AABB
var foot_contacts: Array[Node3D]=[]
var foot_vertices: Array=[]
var death_ground_correction: float=INF
var projectile_lip: Marker3D
const SKIN_SHADER='''shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 ink: source_color=vec4(.5,.5,.5,1.);
uniform vec4 scar: source_color=vec4(.32,.12,.10,1.);
uniform float grain=.17;
uniform float roughness=.84;
uniform float metal=0.;
uniform float hurt=0.;
uniform float charge=0.;
uniform bool culture=false;
uniform bool flesh=false;
varying vec3 sculpt_pos;
float hash3(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);}
float noise3(vec3 p){
 vec3 i=floor(p);vec3 f=fract(p);f=f*f*(3.-2.*f);
 return mix(mix(mix(hash3(i),hash3(i+vec3(1,0,0)),f.x),mix(hash3(i+vec3(0,1,0)),hash3(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash3(i+vec3(0,0,1)),hash3(i+vec3(1,0,1)),f.x),mix(hash3(i+vec3(0,1,1)),hash3(i+vec3(1,1,1)),f.x),f.y),f.z);
}
float culture_vein(vec2 p){
 vec2 cell=floor(p); vec2 local=fract(p); float first=8.; float second=8.;
 for(int y=-1;y<=1;y++){for(int x=-1;x<=1;x++){
  vec2 n=vec2(float(x),float(y)); vec2 site=vec2(hash3(vec3(cell+n,3.)),hash3(vec3(cell+n,9.)));
  float dist=length(n+site-local);
  if(dist<first){second=first;first=dist;}else if(dist<second){second=dist;}
 }}return 1.-smoothstep(.025,.065,second-first);
}
void vertex(){sculpt_pos=VERTEX;}
void fragment(){
 float cell=noise3(sculpt_pos*108.);
 float stain=noise3(sculpt_pos*16.+sin(sculpt_pos*9.)*.6);
 float crease=abs(sin(sculpt_pos.y*63.+sin(sculpt_pos.x*39.)*2.+sculpt_pos.z*19.));
 vec3 color=ink.rgb*(1.-grain+grain*cell);
 color=mix(color,scar.rgb,smoothstep(.62,.82,stain)*.28);
 if(flesh){
  float striation=abs(sin(sculpt_pos.y*46.+noise3(sculpt_pos*9.)*13.+sculpt_pos.z*15.));
  color=mix(color,scar.rgb,(1.-smoothstep(.02,.08,striation))*.24);
 }
 color*=.96+.04*stain;
 color=mix(color,vec3(.68,.12,.07),hurt*.40);
 ALBEDO=color; ROUGHNESS=roughness; METALLIC=metal;
 if(culture){
  float vein=culture_vein(sculpt_pos.xy*13.+sculpt_pos.z*vec2(3.7,-2.3));
  ALBEDO=mix(color,vec3(.19,.26,.085),vein*.45);
  EMISSION=ink.rgb*(.12+charge*1.2)*(1.-vein*.6);
 }
}'''
func configure(requested: StringName) -> void:
 kind=&"vessel" if str(requested).to_lower() in ["vessel","ranged","containment","containment_choir"] else &"unsealed"
 for child in get_children(): remove_child(child); child.queue_free()
 arms.clear(); elbows.clear(); hips.clear(); knees.clear(); surfaces.clear(); base_transforms.clear(); foot_contacts.clear(); foot_vertices.clear(); death_ground_correction=INF
 material={}
 material.skin=_paint("BA9884" if kind==&"unsealed" else "6B7358","55312E",.17)
 material.muscle=_paint("96735F" if kind==&"unsealed" else "535D47","412A29",.14)
 material.skin.set_shader_parameter("flesh",true); material.muscle.set_shader_parameter("flesh",true)
 material.scar=_paint("713C36","38221F",.18)
 material.bone=_paint("C7C6A7","665C42",.11)
 material.dark=_paint("17191A","0F1214",.08)
 material.tooth=_paint("958263","584831",.11)
 material.rubber=_paint("293836","171F21",.08)
 material.metal=_paint("52636A","283238",.07,.74,.20)
 material.culture=_paint("8B9E43","687935",.13,.54)
 material.culture.set_shader_parameter("culture",true)
 material.eye=_paint("DCCE83","413027",.02,.55)
 body=_joint(self,"Body",Vector3.ZERO)
 if kind==&"unsealed": body.rotation.x=-.12
 if kind==&"unsealed": _unsealed()
 else: _vessel()
 _batch(body)
 _remember(body)
 present(&"chase",0.,.45,.6,.18)
 art_bounds=body.transform*_bounds(body)
 set_meta("art_kind",kind); set_meta("feet_plane",-.85); set_meta("forward",Vector3.FORWARD)
func _paint(ink:String,scar:String,grain:float,roughness:float=.84,metal:float=0.) -> ShaderMaterial:
 var mat=ShaderMaterial.new(); var shader=Shader.new(); shader.code=SKIN_SHADER; mat.shader=shader
 mat.set_shader_parameter("ink",Color(ink)); mat.set_shader_parameter("scar",Color(scar)); mat.set_shader_parameter("grain",grain)
 mat.set_shader_parameter("roughness",roughness); mat.set_shader_parameter("metal",metal); surfaces.append(mat); return mat
func _joint(parent:Node3D,label:String,pos:Vector3) -> Node3D:
 var node=Node3D.new(); node.name=label; node.position=pos; parent.add_child(node); return node
func _loft(parent:Node3D,points:Array,radii:Array,mat:Material,flatten:float=1.,sides:int=20) -> MeshInstance3D:
 # Continuous curved anatomy, each ring has independent radius and tangent.
 var verts=PackedVector3Array(); var uv=PackedVector2Array(); var indexes=PackedInt32Array()
 for ring in range(points.size()):
  var tangent:Vector3
  if ring==0: tangent=(points[1]-points[0]).normalized()
  elif ring==points.size()-1: tangent=(points[ring]-points[ring-1]).normalized()
  else: tangent=(points[ring+1]-points[ring-1]).normalized()
  var side=tangent.cross(Vector3.FORWARD).normalized()
  if side.length_squared()<.1: side=tangent.cross(Vector3.RIGHT).normalized()
  var depth=tangent.cross(side).normalized()
  for j in range(sides):
   var a=TAU*j/float(sides)
   # Subtle deliberate muscle ridges; silhouette stays coherent, not random lump noise.
   var swell=1.+sin(a*3.+ring*.8)*.025
   var p:Vector3=points[ring]+side*cos(a)*float(radii[ring])*swell+depth*sin(a)*float(radii[ring])*flatten
   verts.append(p); uv.append(Vector2(j/float(sides),ring/float(points.size()-1)))
   if ring>0:
    var n=ring*sides+j; var q=ring*sides+(j+1)%sides; var prev=n-sides; var prevq=q-sides
    indexes.append_array(PackedInt32Array([prev,n,q,prev,q,prevq]))
 # End caps are closed and follow the local tangent; no proxy primitive mesh.
 for ring in [0,points.size()-1]:
  var center=verts.size(); verts.append(points[ring]); uv.append(Vector2(.5,.5))
  for j in range(sides):
   var a=ring*sides+j; var b=ring*sides+(j+1)%sides
   indexes.append_array(PackedInt32Array([center,b,a] if ring==0 else [center,a,b]))
 var st=SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in range(verts.size()): st.set_uv(uv[i]); st.add_vertex(verts[i])
 for i in indexes: st.add_index(i)
 st.generate_normals()
 var mesh=MeshInstance3D.new(); mesh.mesh=st.commit(); mesh.material_override=mat; parent.add_child(mesh); return mesh
func _organic(parent:Node3D,pos:Vector3,size:Vector3,mat:Material) -> MeshInstance3D:
 # Authored seven-ring tapered muscle/organ volume. x and z extents are independent.
 var points=[]; var radii=[]
 for row in range(9):
  var y=lerpf(-size.y,size.y,row/8.)
  points.append(pos+Vector3(sin(row*.55)*size.x*.07,y,cos(row*.51)*size.z*.04))
  radii.append(maxf(.006,sqrt(maxf(0.,1.-pow(row/4.-1.,2.)))*size.x))
 return _loft(parent,points,radii,mat,size.z/maxf(size.x,.001),24)
func _curve(parent:Node3D,points:Array,r:float,mat:Material,flat:float=1.):
 var radii=[]
 for i in range(points.size()): radii.append(r*(.85+.15*sin(PI*i/maxf(1.,points.size()-1))))
 return _loft(parent,points,radii,mat,flat,12)
func _plate(parent:Node3D,points:Array,thick:float,mat:Material):
 var st=SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var center=Vector3.ZERO
 for p in points: center+=p
 center/=float(points.size()); center.z-=thick
 for i in range(points.size()):
  var j=(i+1)%points.size(); var a:Vector3=points[i]; var b:Vector3=points[j]
  st.add_vertex(center); st.add_vertex(b); st.add_vertex(a)
  st.add_vertex(a); st.add_vertex(b); st.add_vertex(b+Vector3(0,0,thick))
  st.add_vertex(a); st.add_vertex(b+Vector3(0,0,thick)); st.add_vertex(a+Vector3(0,0,thick))
 st.generate_normals(); var mesh=MeshInstance3D.new(); mesh.mesh=st.commit(); mesh.material_override=mat; parent.add_child(mesh); return mesh
func _rim(parent:Node3D,center:Vector3,outer:float,inner:float,mat:Material):
 var st=SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in range(24):
  var a=TAU*i/24.;var b=TAU*(i+1)/24.
  var u=center+Vector3(cos(a)*outer,sin(a)*outer,0);var v=center+Vector3(cos(b)*outer,sin(b)*outer,0)
  var x=center+Vector3(cos(a)*inner,sin(a)*inner,.004);var y=center+Vector3(cos(b)*inner,sin(b)*inner,.004)
  for tri in [[u,v,y],[u,y,x],[u,y,v],[u,x,y]]:
   for p in tri: st.add_vertex(p)
 st.generate_normals();var mesh=MeshInstance3D.new();mesh.mesh=st.commit();mesh.material_override=mat;parent.add_child(mesh)
func _unsealed():
 # One continuous pelvis/waist/ribcage/neck mass with a bent spinal profile.
 _loft(body,[Vector3(0,-.19,.06),Vector3(0,-.08,.04),Vector3(0,.035,.005),Vector3(0,.17,-.055),Vector3(0,.32,-.11),Vector3(0,.43,-.145),Vector3(0,.49,-.16)], [.13,.205,.17,.24,.32,.285,.13],material.skin,.68,28)
 for s in [-1.,1.]:
  # Pectoral and abdominal volumes flow over the thorax rather than detached balls.
  _organic(body,Vector3(s*.165,.25,-.215),Vector3(.177,.13,.076),material.skin)
  _curve(body,[Vector3(s*.31,.37,-.15),Vector3(s*.20,.35,-.20),Vector3(s*.08,.33,-.225)],.018,material.muscle,.7)
  for row in range(4):
   var y=.05-row*.065
   _organic(body,Vector3(s*.070,y,-.151),Vector3(.074,.052,.040),material.muscle)
  for rib in range(4):
   var y=.17-rib*.075
   _curve(body,[Vector3(s*.22,y,-.105),Vector3(s*.245,y+.02,-.145),Vector3(s*.19,y+.03,-.191)],.016,material.skin,.72)
  _curve(body,[Vector3(s*.06,-.23,-.095),Vector3(s*.14,-.12,-.17),Vector3(s*.22,.07,-.165)],.019,material.scar,.7)
  _arm(s,false); _leg(s,false)
 # Central sternum and raised scars interrupt a doll-like smooth torso.
 _curve(body,[Vector3(0,.36,-.204),Vector3(0,.21,-.227),Vector3(0,.09,-.179)],.020,material.bone,.62)
 _curve(body,[Vector3(-.29,.39,-.10),Vector3(-.22,.32,-.20),Vector3(-.18,.23,-.286)],.014,material.scar,.75)
 _curve(body,[Vector3(.18,.20,-.284),Vector3(.23,.10,-.18),Vector3(.14,.05,-.19)],.012,material.scar,.75)
 _loft(body,[Vector3(0,.405,-.13),Vector3(0,.49,-.205),Vector3(0,.51,-.245)],[.14,.105,.11],material.skin,.79)
 head=_joint(body,"Head",Vector3(0,.45,-.255)); head.scale.x=.81; head.rotation.x=-.11
 _loft(head,[Vector3(0,-.04,.035),Vector3(0,.015,.025),Vector3(0,.11,.01),Vector3(0,.20,.023),Vector3(0,.28,.025),Vector3(0,.335,.027),Vector3(0,.36,.025)], [.10,.145,.165,.149,.125,.080,.015],material.skin,.91,24)
 # Deep eye sockets and a vertical split-maw framed by sculpted jaw branches.
 for s in [-1.,1.]:
  _organic(head,Vector3(s*.090,.174,-.132),Vector3(.035,.022,.020),material.dark)
  _organic(head,Vector3(s*.090,.170,-.155),Vector3(.012,.006,.005),material.eye)
  _curve(head,[Vector3(s*.025,.207,-.152),Vector3(s*.076,.224,-.143),Vector3(s*.146,.190,-.093)],.016,material.skin,.65)
  _curve(head,[Vector3(s*.131,.146,-.098),Vector3(s*.127,.060,-.170),Vector3(s*.075,-.013,-.168)],.030,material.skin,.77)
 _organic(head,Vector3(0,.044,-.172),Vector3(.064,.118,.023),material.dark)
 for s in [-1.,1.]:
  _curve(head,[Vector3(s*.062,.157,-.164),Vector3(s*.075,.110,-.203),Vector3(s*.062,.012,-.214),Vector3(s*.039,-.065,-.195)],.018,material.scar,.74)
  _curve(head,[Vector3(s*.13,.142,-.115),Vector3(s*.105,.065,-.179),Vector3(s*.089,-.02,-.183)],.023,material.muscle,.72)
 _curve(head,[Vector3(0,.211,-.131),Vector3(0,.164,-.164),Vector3(0,.129,-.203)],.016,material.skin,.62)
 jaw=_joint(head,"Jaw",Vector3(0,-.045,-.154))
 _curve(jaw,[Vector3(-.075,.015,-.047),Vector3(-.045,-.03,-.060),Vector3(0,-.052,-.061),Vector3(.045,-.03,-.060),Vector3(.075,.015,-.047)],.024,material.scar,.9)
 for x in [-.065,-.040,-.015,.015,.040,.065]:
  _loft(head,[Vector3(x,.145,-.215),Vector3(x,.116,-.227),Vector3(x*.9,.090,-.220)],[.014,.008,.001],material.tooth,.70,8)
  _loft(jaw,[Vector3(x*.8,-.028,-.065),Vector3(x*.8,.003,-.066),Vector3(x*.8,.025,-.062)],[.012,.007,.001],material.tooth,.70,8)
 projectile_lip=Marker3D.new(); projectile_lip.name="ProjectileLip"; projectile_lip.position=Vector3(0,.05,-.225); head.add_child(projectile_lip)
 _curve(head,[Vector3(-.015,.318,-.10),Vector3(.01,.277,-.135),Vector3(.009,.211,-.151)],.009,material.scar,.6)
func _arm(s:float,vessel:bool):
 var origin=Vector3(s*(.41 if vessel else .325),.27 if vessel else .37,-.075 if vessel else -.16)
 var upper=_joint(body,"ArmL" if s<0 else "ArmR",origin); arms.append(upper)
 _organic(upper,Vector3(s*.029,-.035,.007),Vector3(.18 if vessel else .127,.16,.125),material.skin)
 var end=Vector3(s*(.19 if vessel else .16),-.35,-.12)
 _loft(upper,[Vector3.ZERO,Vector3(s*.045,-.07,-.025),Vector3(s*.09,-.16,-.033),Vector3(s*.14,-.25,-.075),end],[.11,.15 if vessel else .118,.145 if vessel else .125,.09,.073],material.skin,.88)
 _curve(upper,[Vector3(s*.05,-.055,-.115),Vector3(s*.10,-.16,-.142),Vector3(s*.13,-.25,-.13)],.016,material.muscle)
 var elbow=_joint(upper,"Elbow",end); elbows.append(elbow)
 var wrist=Vector3(s*(-.025 if vessel else .025),-.37 if vessel else -.41,-.035 if vessel else -.09)
 _loft(elbow,[Vector3.ZERO,Vector3(s*.012,-.06,-.010),Vector3(s*.012,-.20 if not vessel else -.17,-.040),Vector3(s*.009,-.32 if not vessel else -.27,-.065),wrist],[.071,.116 if vessel else .088,.105 if vessel else .078,.058,.044],material.skin,.80)
 _curve(elbow,[Vector3(s*.029,-.075,-.096),Vector3(s*.022,-.19,-.105),Vector3(s*.015,-.31,-.071)],.015,material.scar,.65)
 _hand(elbow,wrist,s,vessel)
func _hand(parent:Node3D,wrist:Vector3,s:float,vessel:bool):
 _organic(parent,wrist+Vector3(0,-.067,-.01),Vector3(.066,.092,.033),material.skin)
 for finger in range(4):
  var x=(finger-1.5)*.036
  var len_v=.135+(.022 if finger in [1,2] else 0.)
  var start=wrist+Vector3(x,-.112,-.014)
  var tip=start+Vector3(x*.17,-len_v,-.030)
  _loft(parent,[start,start+Vector3(x*.20,-.045,-.010),start+Vector3(x*.32,-.095,-.044),tip,tip+Vector3(-x*.22,.010,-.035)],[.019,.022,.015,.010,.001],material.skin,.78,10)
  _loft(parent,[tip+Vector3(0,.010,-.009),tip+Vector3(-x*.10,-.007,-.040),tip+Vector3(-x*.27,.012,-.054)],[.012,.008,.001],material.tooth,.68,8)
 _loft(parent,[wrist+Vector3(-s*.059,-.05,-.01),wrist+Vector3(-s*.095,-.09,-.039),wrist+Vector3(-s*.082,-.145,-.066)],[.025,.021,.002],material.skin,.83,10)
func _leg(s:float,vessel:bool):
 var origin=Vector3(s*(.24 if vessel else .143),-.25 if vessel else -.120,.035)
 var hip=_joint(body,"HipL" if s<0 else "HipR",origin); hips.append(hip)
 var knee=Vector3(s*(.100 if vessel else .075),-.285 if vessel else -.340,.005 if vessel else -.085)
 _loft(hip,[Vector3.ZERO,Vector3(s*.027,-.067,-.008),Vector3(s*.06,-.15 if vessel else -.195,-.03),knee],[.133 if vessel else .104,.184 if vessel else .133,.143 if vessel else .121,.080],material.skin,.95)
 _organic(hip,knee+Vector3(0,.013,-.065),Vector3(.075,.070,.031),material.bone if vessel else material.skin)
 var shin=_joint(hip,"Knee",knee); knees.append(shin)
 _loft(shin,[Vector3.ZERO,Vector3(0,-.045,.022),Vector3(s*.02,-.135,.033),Vector3(s*.022,-.235 if vessel else -.305,.050),Vector3(s*.025,-.28 if vessel else -.350,.057)],[.080,.103 if vessel else .076,.089 if vessel else .067,.065,.052],material.skin,.83)
 var ankle=Vector3(s*.025,-.27 if vessel else -.340,.045)
 foot_contacts.append(_joint(shin,"Sole",ankle+Vector3(0,-.048,-.066)))
 var foot_mesh=_organic(shin,ankle+Vector3(0,-.018,-.066),Vector3(.097 if vessel else .077,.030,.145 if vessel else .111),material.skin)
 foot_vertices.append([shin,foot_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]])
 for toe in range(4):
  var x=(toe-1.5)*(.043 if vessel else .034)
  _loft(shin,[ankle+Vector3(x,-.01,-.080),ankle+Vector3(x,-.018,-.168),ankle+Vector3(x*.9,-.023,-.194)],[.021,.018,.001],material.tooth,.6,8)
func _vessel():
 _loft(body,[Vector3(0,-.37,.05),Vector3(0,-.25,.08),Vector3(0,-.10,.08),Vector3(0,.10,.07),Vector3(0,.30,.06),Vector3(0,.43,.08),Vector3(0,.51,.10)], [.25,.37,.445,.48,.43,.32,.14],material.skin,.78,28)
 for s in [-1.,1.]:
  _arm(s,true); _leg(s,true)
  _organic(body,Vector3(s*.31,.28,.045),Vector3(.23,.26,.20),material.muscle)
  for row in range(3):
   var y=.38-row*.14
   _plate(body,[Vector3(s*.21,y+.07,-.045),Vector3(s*.42,y+.04,-.06),Vector3(s*.50,y-.06,-.03),Vector3(s*.30,y-.105,-.15)],.07,material.bone)
  # Ruined tubing loops connect back/shoulder to the throat apparatus.
  _curve(body,[Vector3(s*.32,.28,.18),Vector3(s*.38,.45,.29),Vector3(s*.27,.60,.29),Vector3(s*.13,.58,.18),Vector3(s*.09,.43,-.10)],.038,material.rubber)
  for i in range(5):
   _organic(body,Vector3(s*.37,.34+i*.045,.225),Vector3(.047,.022,.037),material.metal)
 sac=_joint(body,"CultureSac",Vector3(0,-.01,-.315))
 _organic(sac,Vector3.ZERO,Vector3(.30,.34,.175),material.culture)
 # Ceramic ribs follow the bulging sac; broken ends expose dark tissue between them.
 for s in [-1.,1.]:
  for i in range(3):
   var x=.10+i*.080
   _curve(body,[Vector3(s*x,.345,-.29),Vector3(s*(x+.035),.22,-.42),Vector3(s*(x+.05),.065,-.455),Vector3(s*(x+.022),-.095+(i-1)*.022,-.454)],.026,material.bone,.74)
   _curve(body,[Vector3(s*(x+.022),-.14,-.43),Vector3(s*x,-.25,-.375),Vector3(s*(x-.012),-.31,-.29)],.028,material.bone,.75)
  _curve(body,[Vector3(s*.36,.24,-.17),Vector3(s*.28,.30,-.29),Vector3(s*.12,.33,-.38)],.033,material.bone,.70)
 _curve(body,[Vector3(-.28,-.22,-.38),Vector3(-.15,-.32,-.39),Vector3(0,-.35,-.33),Vector3(.16,-.31,-.39),Vector3(.28,-.22,-.38)],.033,material.rubber,.75)
 head=_joint(body,"Head",Vector3(0,.42,-.14))
 _organic(head,Vector3(0,.063,.004),Vector3(.20,.18,.16),material.muscle)
 for s in [-1.,1.]:
  _plate(head,[Vector3(s*.02,.215,-.07),Vector3(s*.18,.17,-.02),Vector3(s*.19,.065,-.095),Vector3(s*.03,.093,-.163)],.032,material.bone)
  _organic(head,Vector3(s*.133,.103,-.119),Vector3(.047,.016,.013),material.dark)
  _organic(head,Vector3(s*.133,.099,-.133),Vector3(.016,.006,.004),material.culture)
 # Three actual forward-facing fleshy throat vents with recessed dark bores.
 for entry in [[-.083,.041,-.145,.062],[.012,.121,-.16,.066],[.094,.023,-.12,.053]]:
  var x:float=entry[0]; var y:float=entry[1]; var z:float=entry[2]; var r:float=entry[3]
  _loft(head,[Vector3(x,y,z+.07),Vector3(x,y,z-.04),Vector3(x,y,z-.24)],[r*.9,r,r*1.12],material.scar,1.,18)
  _organic(head,Vector3(x,y,z-.249),Vector3(r*.75,r*.75,.013),material.dark)
  _rim(head,Vector3(x,y,z-.268),r*1.05,r*.75,material.scar)
  _curve(head,[Vector3(x-r*.5,y-r*.3,z-.258),Vector3(x,y-r*.48,z-.269),Vector3(x+r*.5,y-r*.28,z-.258)],.014,material.scar)
 projectile_lip=Marker3D.new(); projectile_lip.name="ProjectileLip"; projectile_lip.position=Vector3(.012,.121,-.428); head.add_child(projectile_lip)
 # Back armor is dimensional, with broad curved plates rather than a rectangle shell.
 for s in [-1.,1.]:
  for row in range(3):
   var y=.35-row*.16
   _organic(body,Vector3(s*.16,y,.30),Vector3(.20,.115,.055),material.bone)
func _remember(node:Node3D):
 base_transforms[node]=node.transform
 for child in node.get_children():
  if child is Node3D: _remember(child)
func present(state: StringName,time: float,windup_duration: float=.45,recovery_duration: float=.60,pain_duration: float=.18) -> void:
 if not is_instance_valid(body): return
 for node in base_transforms:
  if is_instance_valid(node): node.transform=base_transforms[node]
 var phase=0.
 var beat=sin(time*(6.8 if kind==&"unsealed" else 4.1))
 var hurt=0.; var charge=0.
 if state in [&"chase",&"idle"]:
  body.position.y=absf(beat)*(.018 if kind==&"unsealed" else .011)
  body.rotation.z=beat*.023
  for i in range(2):
   var swing=sin(time*(6.8 if kind==&"unsealed" else 4.1)+i*PI)
   hips[i].rotation.x=swing*(.26 if kind==&"unsealed" else .13)
   knees[i].rotation.x=maxf(0.,-swing)*.23
   arms[i].rotation.x=-swing*(.19 if kind==&"unsealed" else .05)
   elbows[i].rotation.x=.07+maxf(0.,swing)*.12
 elif state==&"windup":
  phase=clampf(time/maxf(.001,windup_duration),0.,1.)
  body.rotation.x=(-.12-.10*phase) if kind==&"unsealed" else .09*phase; head.rotation.x=-.13*phase
  for i in range(2):
   arms[i].rotation.x=phase*(.66 if kind==&"unsealed" else -.08)
   arms[i].rotation.z=(1. if i==0 else -1.)*.13*phase
   elbows[i].rotation.x=.25*phase
  if kind==&"unsealed" and is_instance_valid(jaw): jaw.rotation.x=.35*phase
  if kind==&"vessel": sac.scale=Vector3.ONE*(1.+phase*.065); charge=phase
 elif state==&"recovery":
  phase=clampf(time/maxf(.001,recovery_duration),0.,1.); var remain=1.-phase
  body.rotation.x=(-.12-.10*remain) if kind==&"unsealed" else .16*remain
  for i in range(2):
   arms[i].rotation.x=remain*(.82 if kind==&"unsealed" else .16)
   elbows[i].rotation.x=remain*.44
  head.rotation.x=.12*remain
  if kind==&"vessel": charge=remain*.35
 elif state==&"pain":
  phase=clampf(time/maxf(.001,pain_duration),0.,1.); hurt=sin(PI*phase)
  body.rotation.z=-hurt*.14; body.rotation.x=(-.12+hurt*.11) if kind==&"unsealed" else -hurt*.11; head.rotation.x=-hurt*.21
  for arm in arms: arm.rotation.x=-hurt*.12
 elif state in [&"dead",&"death"]:
  phase=clampf(time/.65,0.,1.); var p=phase*phase*(3.-2.*phase)
  body.rotation.x=deg_to_rad(84.)*p
  body.position.y=(-.49 if kind==&"vessel" else -.51)*p
  body.rotation.z=.12*p
  for i in range(2):
   arms[i].rotation.z=(1. if i==0 else -1.)*.33*p
   elbows[i].rotation.x=.22*p
   hips[i].rotation.x=(.10 if i==0 else -.15)*p
   knees[i].rotation.x=.16*p
  head.rotation.x=-.12*p
 # Register the lowest planted sole to the capsule floor, with actual corpse vertices at rest.
 if state in [&"dead",&"death"]:
  if phase>=1.:
   if is_inf(death_ground_correction): death_ground_correction=-.85-_exact_min_y(body,body.transform)
   body.position.y+=death_ground_correction
  else:
   var bound=body.transform*_bounds(body)
   if bound.position.y<-.85: body.position.y+=-.85-bound.position.y
 else:
  var floor_y=INF
  for entry in foot_vertices:
   var t=global_transform.affine_inverse()*entry[0].global_transform
   for v in entry[1]: floor_y=minf(floor_y,(t*v).y)
  if not is_inf(floor_y): body.position.y+=-.85-floor_y
 for mat in surfaces: mat.set_shader_parameter("hurt",hurt)
 material.culture.set_shader_parameter("charge",charge)
func _batch(node:Node3D):
 # Merge static features per joint/material; moving limb hierarchy is retained.
 var groups={}
 for child in node.get_children():
  if child is MeshInstance3D:
   var mat=child.material_override
   if not groups.has(mat): groups[mat]=[]
   groups[mat].append(child)
  elif child is Node3D: _batch(child)
 for mat in groups:
  var st=SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
  for mesh_node in groups[mat]: st.append_from(mesh_node.mesh,0,mesh_node.transform)
  var merged=MeshInstance3D.new(); merged.mesh=st.commit(); merged.material_override=mat; merged.name="SculptSurface"
  var hit_material="armor" if kind==&"vessel" and mat in [material.metal,material.bone,material.rubber] else "flesh"
  merged.set_meta("hit_material",hit_material); node.add_child(merged)
  for old in groups[mat]: node.remove_child(old); old.queue_free()
func _bounds(node:Node3D) -> AABB:
 var result=AABB(); var first=true
 for child in node.get_children():
  var b:AABB
  if child is MeshInstance3D: b=child.transform*child.mesh.get_aabb()
  elif child is Node3D: b=child.transform*_bounds(child)
  else: continue
  if b.size.length_squared()<.00001: continue
  if first: result=b; first=false
  else: result=result.merge(b)
 return result
func _exact_min_y(node:Node3D,transform_accum:Transform3D) -> float:
 var min_y=INF
 for child in node.get_children():
  var t=transform_accum*child.transform
  if child is MeshInstance3D:
   for surface in range(child.mesh.get_surface_count()):
    var array=child.mesh.surface_get_arrays(surface)
    for vertex in array[Mesh.ARRAY_VERTEX]: min_y=minf(min_y,(t*vertex).y)
  elif child is Node3D: min_y=minf(min_y,_exact_min_y(child,t))
 return min_y
func _exact_bounds(node:Node3D,t:Transform3D) -> AABB:
 var result=AABB(); var first=true
 for child in node.get_children():
  var transform_accum=t*child.transform
  if child is MeshInstance3D:
   for surface in range(child.mesh.get_surface_count()):
    for vertex in child.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
     var p=transform_accum*vertex
     if first: result=AABB(p,Vector3.ZERO); first=false
     else: result=result.expand(p)
  elif child is Node3D:
   var b=_exact_bounds(child,transform_accum)
   if b.size.length_squared()<.00001: continue
   if first: result=b; first=false
   else: result=result.merge(b)
 return result
func bounds_now() -> AABB: return _exact_bounds(body,body.transform)

func get_projectile_origin() -> Vector3:
 return projectile_lip.global_position if is_instance_valid(projectile_lip) else global_position
