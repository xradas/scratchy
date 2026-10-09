"""Author the connected Pale Ward level;12 physical steps share visible/collision boxes.
Retains the earlier exact wedge resource as unused historical source.
Only writes scenes/pale_ward.tscn and resources/ward_ramp_mesh.tres. Textures supplied separately.
"""
from pathlib import Path
import subprocess, tempfile, math, re
P=Path(__file__).resolve().parents[1]
GODOT=Path('/home/rikki/.local/share/eyesore-tools/4.7.2/Godot_v4.7.2-stable_linux.x86_64')
# Offline-authored wedge: top slope + flat bottom, same six points in visible/collision.
script='''extends SceneTree
func _initialize():
 var pts=PackedVector3Array([Vector3(-3,0,-3),Vector3(3,0,-3),Vector3(-3,0,3),Vector3(3,0,3),Vector3(-3,1.5,-3),Vector3(3,1.5,-3)])
 var faces=[[4,5,3,4,3,2],[0,2,3,0,3,1],[0,1,5,0,5,4],[0,4,2],[1,3,5]]
 var normals=[Vector3(0,6,1.5).normalized(),Vector3.DOWN,Vector3(0,0,-1),Vector3.LEFT,Vector3.RIGHT]
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in range(faces.size()):
  for index in faces[i]:
   var p=pts[index];st.set_normal(normals[i]);st.set_uv(Vector2((p.x+3)/6,(p.z+3)/6));st.add_vertex(p)
 var mesh=st.commit()
 assert(ResourceSaver.save(mesh,"res://resources/ward_ramp_mesh.tres")==OK)
 quit()
'''
with tempfile.NamedTemporaryFile(mode='w',suffix='.gd',delete=False) as f:
 f.write(script); temp=Path(f.name)
try: subprocess.run([str(GODOT),'--headless','--path',str(P),'--script',str(temp)],check=True)
finally: temp.unlink(missing_ok=True)
subs=[];nodes=[];ext=[];i=0

def vec(v):return 'Vector3('+', '.join(f'{x:.6g}' for x in v)+')'
def color(c):return 'Color('+', '.join(str(x) for x in c)+')'
def add_node(name,typ='Node3D',parent='.',props=''):
 nodes.append(f'[node name="{name}" type="{typ}" parent="{parent}"]\n{props}\n')
def material(name,props):subs.append(f'[sub_resource type="StandardMaterial3D" id="{name}"]\n{props}\n')
for kind in ['player','level','door','lift']:
 file={'player':'player','level':'pale_ward_level','door':'ward_door','lift':'ward_lift'}[kind]
 ext.append(f'[ext_resource type="Script" path="res://scripts/{file}.gd" id="{kind}"]')
ext.append('[ext_resource type="ArrayMesh" path="res://resources/ward_ramp_mesh.tres" id="ramp_mesh"]')
ext.append('[ext_resource type="Shader" path="res://shaders/ward_surface.gdshader" id="ward_surface"]')
ext.append('[ext_resource type="Texture2D" path="res://assets/enemies/board-sprites/unsealed-atlas.png" id="specimen_atlas"]')
for kind,uv in [('ceramic',.30),('steel',.5),('floor',.35),('grate',.7)]:
 ext.append(f'[ext_resource type="Texture2D" path="res://assets/materials/pale-ward-approved-board.png" id="tex_{kind}"]')
 metal,rough,relief={'ceramic':(0,.68,2.8), 'steel':(.52,.38,3.5), 'floor':(.18,.50,2.3), 'grate':(.56,.40,3.3)}[kind]
 region={'ceramic':(1216,625,111,102), 'steel':(1362,625,111,102), 'floor':(1362,625,111,102), 'grate':(1216,761,111,106)}[kind]
 subs.append(f'[sub_resource type="ShaderMaterial" id="{kind}"]\nshader = ExtResource("ward_surface")\nshader_parameter/painted_surface = ExtResource("tex_{kind}")\nshader_parameter/source_region_pixels = Vector4({", ".join(str(v) for v in region)})\nshader_parameter/world_scale = {uv}\nshader_parameter/tint = {color((1,1,1,1))}\nshader_parameter/metal = {metal}\nshader_parameter/base_roughness = {rough}\nshader_parameter/relief = {relief}\n')
for name,c in [('recess',(.085,.087,.082,1)),('trim',(.22,.225,.21,1)),('rust',(.26,.12,.065,1)),('blood',(.17,.035,.025,1)),('ivory',(.55,.50,.36,1)),('sign_ink',(.06,.065,.06,1))]:
 material(name,'albedo_color = '+color(c)+'\nroughness = .93')
material('tube','albedo_color = Color(.63,.68,.16,.28)\ntransparency = 1\nmetallic = .12\nroughness = .18\ncull_mode = 2\nemission_enabled = true\nemission = Color(.19,.23,.035,1)\nemission_energy_multiplier = .35')
material('fluid','albedo_color = Color(.26,.24,.075,.48)\ntransparency = 1\nroughness = .7')
for name,c,energy in [('lamp',(.72,.68,.54,1),1.6),('olive',(.42,.40,.06,1),1.1),('key',(.76,.52,.10,1),1.0),('health',(.51,.14,.10,1),.25),('armor',(.17,.24,.27,1),.25)]:
 material(name,'albedo_color = '+color(c)+'\nroughness = .75\nemission_enabled = true\nemission = '+color(c)+f'\nemission_energy_multiplier = {energy}')
subs.append('''[sub_resource type="Environment" id="environment"]
background_mode = 1
background_color = Color(.025,.027,.025,1)
ambient_light_source = 2
ambient_light_color = Color(.52,.53,.55,1)
ambient_light_energy = .30
tonemap_mode = 0
fog_enabled = true
fog_light_color = Color(.09,.105,.115,1)
fog_density = .008
''')
subs.append('[sub_resource type="CapsuleShape3D" id="player_shape"]\nradius = .3\nheight = 1.7\n')
subs.append('[sub_resource type="AtlasTexture" id="specimen"]\natlas = ExtResource("specimen_atlas")\nregion = Rect2(0,0,384,512)\n')

def box(name,pos,size,mat='ceramic',solid=True,rot=None,typ=None,extra='',parent='.'):
 global i
 i+=1;mid=f'm{i}';sid=f's{i}'
 subs.append(f'[sub_resource type="BoxMesh" id="{mid}"]\nsize = {vec(size)}\nmaterial = SubResource("{mat}")\n')
 if solid:subs.append(f'[sub_resource type="BoxShape3D" id="{sid}"]\nsize = {vec(size)}\n')
 props='position = '+vec(pos)+'\n'+('rotation_degrees = '+vec(rot)+'\n' if rot else '')+extra
 if solid:props+='\ncollision_layer = 1\ncollision_mask = 3\nmetadata/hit_material = "armor"' if mat in ['steel','grate','trim','recess'] else '\ncollision_layer = 1\ncollision_mask = 3\nmetadata/hit_material = "hard"'
 add_node(name,typ or ('StaticBody3D' if solid else 'Node3D'),parent=parent,props=props)
 path=name if parent=='.' else parent+'/'+name
 add_node('Visual','MeshInstance3D',path,f'mesh = SubResource("{mid}")')
 if solid:add_node('Collision','CollisionShape3D',path,f'shape = SubResource("{sid}")')

def cylinder(name,pos,r,h,mat='steel',rot=None,solid=False):
 global i
 i+=1;mid=f'm{i}';sid=f's{i}'
 subs.append(f'[sub_resource type="CylinderMesh" id="{mid}"]\ntop_radius = {r}\nbottom_radius = {r}\nheight = {h}\nradial_segments = 24\nmaterial = SubResource("{mat}")\n')
 if solid:subs.append(f'[sub_resource type="CylinderShape3D" id="{sid}"]\nradius = {r}\nheight = {h}\n')
 add_node(name,'StaticBody3D' if solid else 'Node3D',props='position = '+vec(pos)+'\n'+('rotation_degrees = '+vec(rot)+'\n' if rot else '')+('collision_layer = 1\ncollision_mask = 3\nmetadata/hit_material = "armor"' if solid else ''))
 add_node('Visual','MeshInstance3D',name,f'mesh = SubResource("{mid}")\ncast_shadow = '+('0' if mat in ['tube','fluid'] else '1'))
 if solid:add_node('Collision','CollisionShape3D',name,f'shape = SubResource("{sid}")')

def light(name,pos,color_v,energy=2,range_v=10,shadow=False):
 add_node(name,'OmniLight3D',props=f'position = {vec(pos)}\nlight_color = {color(color_v)}\nlight_energy = {energy}\nomni_range = {range_v}\nshadow_enabled = '+str(shadow).lower())

def downlight(name,pos,energy=4.5,range_v=11):
 add_node(name,'SpotLight3D',props=f'position = {vec(pos)}\nrotation_degrees = Vector3(-90,0,0)\nlight_color = Color(.95,.95,.91,1)\nlight_energy = {energy}\nspot_range = {range_v}\nspot_angle = 58\nspot_attenuation = 1.2\nshadow_enabled = true\nshadow_bias = .025\nshadow_normal_bias = .35\n')

def label(name,text,pos,rotation=(0,0,0),size=65,pixel=.006,tint=(.1,.11,.10,1),parent='.'):
 add_node(name,'Label3D',parent=parent,props='position = '+vec(pos)+'\nrotation_degrees = '+vec(rotation)+f'\ntext = "{text}"\nfont_size = {size}\npixel_size = {pixel}\nmodulate = '+color(tint)+'\noutline_size = 0\nno_depth_test = false\nshaded = true\n')

def original_sign(name,region,pos,size):
 # Preserve approved board pixels through native UV mapping; QuadMesh faces +Z.
 texture='[ext_resource type="Texture2D" path="res://assets/materials/pale-ward-approved-board.png" id="approved_sign_board"]'
 if texture not in ext:ext.append(texture)
 x,y,w,h=region
 mat=name+'_material';mesh=name+'_mesh'
 material(mat,'albedo_texture = ExtResource("approved_sign_board")\ntexture_filter = 0\ntexture_repeat = false\nroughness = .9\nshading_mode = 1\ncull_mode = 0\nuv1_scale = '+vec((w/1536,h/1024,1))+'\nuv1_offset = '+vec((x/1536,y/1024,0)))
 subs.append(f'[sub_resource type="QuadMesh" id="{mesh}"]\nmaterial = SubResource("{mat}")\nsize = Vector2({size[0]}, {size[1]})\norientation = 2\n')
 add_node(name,'MeshInstance3D',props='position = '+vec(pos)+f'\nmesh = SubResource("{mesh}")\n')

def marker(name,pos,meta,typ='Marker3D',extra=''):
 add_node(name,typ,props='position = '+vec(pos)+'\n'+meta+'\n'+extra)

def room(id,center,half):marker('Room_'+id,center,f'metadata/ward_room = "{id}"\nmetadata/room_bounds = {vec(half)}')
def nav(name,pos,rooms,door=None):
 marker('Nav_'+name,pos,'metadata/ward_nav = Array[String](['+', '.join('"'+r+'"' for r in rooms)+'])'+(f'\nmetadata/ward_nav_door = NodePath("../{door}")' if door else ''))

def pickup(name,kind,pos,amount=25):
 marker('Pickup_'+name,pos,f'metadata/ward_pickup = "{kind}"\nmetadata/amount = {amount}','Node3D')
 global i
 i+=1;mid=f'm{i}'
 material_id=kind if kind in ['key','health','armor'] else 'ivory'
 subs.append(f'[sub_resource type="BoxMesh" id="{mid}"]\nsize = Vector3(.48,.32,.35)\nmaterial = SubResource("{material_id}")\n')
 add_node('Case','MeshInstance3D','Pickup_'+name,f'mesh = SubResource("{mid}")\nlayers = 2')
 add_node('Mark','Label3D','Pickup_'+name,f'text = "'+{'health':'+','armor':'A','key':'C3','shells':'12G','pistol':'9MM'}[kind]+'"\nposition = Vector3(0,.20,0)\nfont_size = 34\npixel_size = .004\nmodulate = Color(.88,.83,.68,1)\noutline_size = 0\nbillboard = 1\nlayers = 2')

# Ground-connected architecture; every passable threshold has a shared exact floor elevation.
box('HallFloor',(0,-.25,1),(12,.5,34),'floor')
box('HallGratedAisle',(0,-.015,4.5),(7,.03,23),'grate',False)
box('HallCeiling',(0,6.1,1),(12.7,.4,34.7),'ceramic')
box('HallSouthWall',(0,3,18.25),(12.7,6,.5))
# Leftwall gap for secret, rightwall two independent wing/shortcut openings.
for j,(lo,hi) in enumerate([(-16,6),(10,18)]):box(f'HallWest{j}',(-6.25,3,(lo+hi)/2),(.5,6,hi-lo))
for j,(lo,hi) in enumerate([(-16,-4),(-1,3),(8,18)]):box(f'HallEast{j}',(6.25,3,(lo+hi)/2),(.5,6,hi-lo))
box('SecretLintel',(-6.25,4.6,8),(.5,2.8,4))
box('BioPortalLintel',(6.25,4.6,5.5),(.5,2.8,5))
box('ShortcutPortalLintel',(6.25,4.6,-2.5),(.5,2.8,3))
# Raised rear platform and12real steps. No decorative treads over a different collider.
box('RearPlatform',(0,.75,-14),(12,1.5,4),'grate')
add_node('MainRamp',props='position = Vector3(0,0,-9)\nmetadata/ward_stairs = true')
for step in range(12):
 height=(step+1)*.125
 box('Step%02d'%step,(0,height/2,2.75-step*.5),(6,height,.5),'grate',parent='MainRamp',extra='metadata/ward_step = true\n')
# Lower flank pads avoid false collision risers while making the slope frame legible.
for s in [-1,1]:
 box('RampFrame'+str(s),(s*3.10,.80,-9),(.18,.16,6.18),'steel',False,(-math.degrees(math.atan(.25)),0,0))
 box('RearDoorJamb'+str(s),(s*2.55,3.45,-15.7),(.35,4.0,.65),'steel')
box('RearWallL',(-4.35,3.75,-16),(3.3,4.5,.65))
box('RearWallR',(4.35,3.75,-16),(3.3,4.5,.65))
box('RearWallHeader',(0,5.55,-16),(5.4,.9,.65),'ceramic')
box('Door_Rear',(0,3.3,-16),(4.8,3.6,.35),'steel',typ='AnimatableBody3D',extra='script = ExtResource("door")\nmetadata/ward_door = "rear"\nmetadata/required_key = true\nmetadata/open_offset = Vector3(0,3.8,0)\nmetadata/use_anchor = Vector3(0,-.95,.30)\n')
label('RearDoorMark','C3 / CONTAINMENT',(0,1.15,.20),size=72,pixel=.008,tint=(.56,.52,.38,1),parent='Door_Rear')
box('RearStatus',(2.88,2.7,-15.5),(.14,.85,.10),'olive',False)
# Bio-wing and operating room; no overlaid closed walls at the joins.
box('BioFloor',(13,-.25,6),(14,.5,10),'floor')
box('BioCeiling',(13,4.8,6),(14.5,.4,10.5))
box('BioSouthWall',(13,2.3,11.25),(14.5,4.6,.5))
box('BioEastWall',(20.25,2.3,6),(.5,4.6,10.5))
box('BioNorthLeft',(11,2.3,.75),(10,4.6,.5))
box('BioNorthRight',(20,2.3,.75),(.5,4.6,.5))
box('BioOperatingLintel',(18,3.8,.75),(4,1.6,.5))
box('OperatingFloor',(19,-.25,-4.5),(10,.5,11),'floor')
box('OperatingCeiling',(19,4.8,-4.5),(10.5,.4,11.5))
box('OperatingNorth',(19,2.3,-10.25),(10.5,4.6,.5))
box('OperatingEast',(24.25,2.3,-4.5),(.5,4.6,11.5))
box('OperatingWestA',(13.75,2.3,-7),(.5,4.6,6))
box('OperatingWestB',(13.75,2.3,0),(.5,4.6,2))
box('OperatingShortcutLintel',(13.75,3.8,-2.5),(.5,1.6,3))
box('OperatingSouthEast',(22,2.3,1.25),(4,4.6,.5))
box('OperatingSouthWest',(15,2.3,1.25),(2,4.6,.5))
# Returning shortcut corridor uses a persistent upward slab.
box('ShortcutFloor',(10,-.25,-2.5),(8,.5,3),'floor')
box('ShortcutCeiling',(10,3.7,-2.5),(8,.3,3))
box('ShortcutNorth',(10,1.75,-4.25),(8,3.5,.5))
box('ShortcutSouth',(10,1.75,-.75),(8,3.5,.5))
box('Door_Shortcut',(10,1.65,-2.5),(.3,3.3,3),'steel',typ='AnimatableBody3D',extra='script = ExtResource("door")\nmetadata/ward_door = "shortcut"\nmetadata/open_offset = Vector3(0,3.5,0)\nmetadata/use_anchor = Vector3(.30,-.75,0)\n')
# Optional side secret, deliberately small and off the critical route.
box('SecretFloor',(-8,-.25,8),(4,.5,4),'floor')
box('SecretRoof',(-8,3.5,8),(4,.3,4))
box('SecretWest',(-10.25,1.7,8),(.5,3.4,4.5))
box('SecretNorth',(-8,1.7,5.75),(4,3.4,.5))
box('SecretSouth',(-8,1.7,10.25),(4,3.4,.5))
box('Door_Secret',(-6.15,1.65,8),(.3,3.3,4),'ceramic',typ='AnimatableBody3D',extra='script = ExtResource("door")\nmetadata/ward_door = "secret"\nmetadata/open_offset = Vector3(0,3.5,0)\nmetadata/use_anchor = Vector3(.30,-.75,0)\n')
# Rear lab, upper gallery and open, precisely matching platform shaft.
box('RearLabFloor',(0,1.25,-23),(14,.5,14),'floor')
box('RearLabWest',(-7.25,4.9,-23),(.5,6.8,14.5))
box('RearLabEast',(7.25,4.9,-23),(.5,6.8,14.5))
box('RearLabNorth',(0,4.9,-30.25),(14.5,6.8,.5))
box('RearLabRoof',(0,8.4,-23),(14.5,.4,14.5))
for j,(pos,size) in enumerate([((0,4.35,-29),(14,.3,2)),((0,4.35,-24),(14,.3,2)),((-6.5,4.35,-26.5),(1,.3,3)),((2,4.35,-26.5),(10,.3,3))]):box('GalleryFloor'+str(j),pos,size,'grate')
box('Lift_Exit',(-4.5,1.35,-26.5),(3,.3,3),'steel',typ='AnimatableBody3D',extra='script = ExtResource("lift")\nmetadata/ward_lift = true\nmetadata/lift_offset = Vector3(0,3,0)\nmetadata/use_anchor = Vector3(0,1,0)\n')
for j,(x,z) in enumerate([(-6.12,-28.12),(-2.88,-28.12),(-6.12,-24.88),(-2.88,-24.88)]):cylinder('LiftGuide'+str(j),(x,4.4,z),.10,6,'steel')
# Upper gallery guardrail borders the open lab edge, leaving lift boarding unobstructed.
for k,x in enumerate([-6,-3,0,3,6]):box('GalleryRailPost'+str(k),(x,5.04,-23.15),(.09,1.08,.09),'steel')
box('GalleryRail',(0,5.56,-23.15),(13,.09,.09),'steel')
# Secondary-room fixtures give the side route its own hierarchy and directions.
box('BioGratedWalk',(13,.012,6),(10,.025,3.1),'grate',False)
box('BioPortalFrame',(18,3.35,.55),(4.35,.28,.24),'steel',False)
box('OperatingLightHousing',(19,4.35,-5),(2.8,.18,.75),'recess',False)
box('OperatingLight',(19,4.23,-5),(2.5,.05,.54),'lamp',False)
for k,x in enumerate([15.1,21.9]):
 box('OperatingCabinet'+str(k),(x,1.15,-9.55),(1.4,2.3,.55),'steel')
 box('OperatingCabinetGlass'+str(k),(x,1.57,-9.23),(1.05,.72,.045),'recess',False)
 box('OperatingCabinetGauge'+str(k),(x,1.77,-9.19),(.61,.04,.025),'olive',False)
for k,z in enumerate([4.5,7.5]):
 box('BioWallPanel'+str(k),(20.02,2.25,z),(.045,1.25,1.8),'steel',False)
 box('BioWallInset'+str(k),(19.96,2.27,z),(.04,.88,1.45),'recess',False)
 label('BioPanelText'+str(k),'CULTURE / 0'+str(k+1),(19.92,2.27,z),(0,-90,0),size=38,pixel=.007,tint=(.49,.49,.32,1))
label('BioPortalDirection','A2 / OPERATING →',(17.7,3.63,1.1),size=49,pixel=.008,tint=(.17,.18,.14,1))
label('RearLabRoute','DISCHARGE LIFT ←',(0,3.4,-29.95),size=69,pixel=.008,tint=(.19,.20,.16,1))
# View-defining repeated structural frame/ducts/lights instead of flat featureless boxes.
for j,z in enumerate([-11,-3,5,13]):
 for s in [-1,1]:
  # pilasters stay outside the walking opening, and never seal a route.
  if not (s==1 and z in [-3,5]) and not(s==-1 and z==5):
   box(f'Pilaster{j}_{s}',(s*5.78,3,z),(.40,6,.5),'steel')
   box(f'Footing{j}_{s}',(s*5.62,.38,z),(.72,.76,.85),'steel')
 box('RoofBeam'+str(j),(0,5.72,z),(12,.45,.48),'steel')
 for s in [-1,1]:
  box(f'LampHousing{j}_{s}',(s*3.25,5.45,z),(1.4,.15,.48),'recess',False)
  box(f'LampFace{j}_{s}',(s*3.25,5.35,z),(1.22,.05,.35),'lamp',False)
 light('HallWarm'+str(j),(0,4.7,z),(.80,.85,.91,1),.32,8)
 downlight('HallKey'+str(j),(0,5.3,z),5.0,11)
for j,x in enumerate([-1.5,-.9,2.25]):
 cylinder('MainConduit'+str(j),(x,5.28,1),.14 if j<2 else .25,33,'steel',(90,0,0))
 for k,z in enumerate([-12,-4,4,12]):cylinder(f'PipeCollar{j}_{k}',(x,5.28,z),.19 if j<2 else .31,.11,'recess',(90,0,0))
for j,z in enumerate([-10,-2,6,14]):box('DuctBrace'+str(j),(-1.2,5.43,z),(1.35,.12,.2),'steel',False)
# Tall yellow-fluid tanks: translucent outer cylinder, weathered steel frames, contained silhouettes.
for j,(x,z,floor) in enumerate([(-4.8,12,0),(-4.8,3,0),(-4.8,-5,0),(4.8,11,0),(4.8,-3.5,0),(4.8,-10,0),(10.2,8.8,0),(4.7,-22,1.5)]):
 cylinder(f'Tank{j}_Glass',(x,floor+2.14,z),.71,3.54,'tube',solid=True)
 cylinder(f'Tank{j}_Fluid',(x,floor+2.00,z),.64,3.12,'fluid')
 for k,y in enumerate([.27,.58,3.78,4.0]):cylinder(f'Tank{j}_Ring{k}',(x,floor+y,z),.84,.20 if k in [0,3] else .10,'steel',solid=True)
 cylinder(f'Tank{j}_Base',(x,floor+.11,z),.90,.22,'recess',solid=True)
 cylinder(f'Tank{j}_Cap',(x,floor+4.20,z),.51,.30,'steel')
 for k,ang in enumerate([45,135,225,315]):
  a=math.radians(ang);xx=x+math.sin(a)*.77;zz=z+math.cos(a)*.77
  box(f'Tank{j}_Strut{k}',(xx,floor+2.14,zz),(.12,3.54,.12),'steel',False)
 # Canvas center places silhouette feet .79 above floor, face at2.63. Deliberately no gameplay enemy node.
 add_node(f'Tank{j}_Specimen','Sprite3D',props=f'position = {vec((x,floor+1.90,z))}\ntexture = SubResource("specimen")\npixel_size = .0055\nbillboard = 1\nmodulate = Color(.21,.23,.14,1)\nshaded = true\nalpha_cut = 1\ntexture_filter = 0\n')
 light(f'Tank{j}_Glow',(x,floor+2.1,z),(.62,.67,.16,1),1.5,3.3)
 box(f'Tank{j}_Valve',(x,floor+.52,z+.89),(.23,.24,.20),'steel',False)
# Reference signage carries the identity at the player's opening viewpoint.
# The concept frames the stairs with two substantial machinery piers. They are
# real colliders, clear of the central route and the existing Bio Wing portal.
for s in [-1,1]:
 x=-3.8 if s<0 else 3.4
 z=1.0 if s<0 else -1.2
 box('ContainmentPier'+str(s),(x,3.0,z),(1.45,6.0,1.4),'ceramic')
 box('PierFoot'+str(s),(x,.40,z),(1.70,.80,1.68),'steel')
 box('PierCap'+str(s),(x,5.54,z),(1.65,.28,1.60),'steel')
 for edge in [-1,1]:
  box(f'PierEdge{s}_{edge}',(x+edge*.70,3.15,z+.745),(.10,4.25,.10),'steel')
 for y in [1.10,4.55]:box(f'PierBand{s}_{y}',(x,y,z+.745),(1.45,.18,.10),'steel')
 box('PierInstrument'+str(s),(x,.78,z+.76),(.65,.40,.24),'steel')
 box('PierGauge'+str(s),(x,.82,z+.90),(.37,.065,.02),'olive',False)
original_sign('PierC3',(356,124,130,82),(-3.8,3.3,1.76),(1.28,.808))
original_sign('PierBio',(972,150,90,85),(3.4,3.35,-.44),(1.20,1.133))
# Short wall fixtures pick out grime and cast shadows across the framing piers.
for s in [-1,1]:
 x=-4.25 if s<0 else 3.85
 z=1.0 if s<0 else -1.2
 box('PierLightCase'+str(s),(x,4.38,z+.9),(.27,.58,.28),'steel')
 box('PierLightFace'+str(s),(x,4.38,z+1.055),(.16,.43,.03),'lamp',False)
 light('PierPool'+str(s),(x,4.2,z+1.28),(.94,.94,.84,1),.85,3.2,True)
for k,z in enumerate([-4.0,1.0,6.0]):
 box('MaintenancePlate'+str(k),(.9 if k%2 else -.65,.012,z),(1.65,.024,1.2),'steel')
 for x in [-.6,.6]:box(f'PlateLip{k}_{x}',((.9 if k%2 else -.65)+x,.021,z),(.045,.012,1.16),'steel')
# Broken-up wall services keep the broad surfaces from reading as bare cubes.
for side in [-1,1]:
 for k,z in enumerate([-13,-9,-5,12,16]):
  box(f'WallService{side}_{k}',(side*5.96,.61,z),(.07,.55,2.15),'steel')
  for offset in [-.6,0,.6]:box(f'WallRib{side}_{k}_{offset}',(side*5.91,.64,z+offset),(.055,.045,.36),'recess',False)
 for k,z in enumerate([-13,-9,-5,12,16]):
  cylinder(f'WallFeed{side}_{k}',(side*5.87,3.95,z),.055,2.7,'steel')
# The right-hand junction has containment hardware instead of a bare wall.
box('BioJunctionHousing',(5.85,1.66,.25),(.30,2.15,1.55),'steel')
box('BioJunctionInset',(5.68,1.75,.25),(.07,1.52,1.16),'recess',False)
for k,y in enumerate([1.20,1.45,1.70,1.95,2.20]):
 box('BioJunctionVent'+str(k),(5.63,y,.25),(.05,.08,1.05),'steel',False)
cylinder('BioJunctionFeed',(5.74,3.70,.25),.11,2.10,'steel',solid=True)
cylinder('BioUpperManifold',(5.66,4.65,-4),.19,12.5,'steel',(90,0,0))
# Cached captures contain only static world meshes. No monsters, pickups or
# corpses can remain baked into the floor reflections after a kill/retry.
for name,pos,size in [('HallFront',(0,2.8,6),(12.4,6.6,20)),('HallRear',(0,3,-9),(12.4,7.0,12))]:
 add_node('Reflection_'+name,'ReflectionProbe',props=f'position = {vec(pos)}\nsize = {vec(size)}\nbox_projection = true\ninterior = true\nambient_mode = 0\nintensity = .78\nblend_distance = 2.0\nupdate_mode = 0\ncull_mask = 1\nenable_shadows = true\n')
# The art has old blood in the room before combat, separate from new death gore.
ext.append('[ext_resource type="Texture2D" path="res://assets/effects/gore-v1/pools-atlas.png" id="old_blood"]')
material('old_blood','albedo_texture = ExtResource("old_blood")\nalbedo_color = Color(.8,.8,.8,1)\ntransparency = 2\nalpha_scissor_threshold = .12\ntexture_filter = 2\nroughness = .30\ncull_mode = 2\nuv1_scale = Vector3(.5,.5,1)\nuv1_offset = Vector3(.5,0,0)')
for k,(x,z,width,depth,angle) in enumerate([(-2.0,3.3,2.6,2.8,13),(-1.6,6.1,2.4,1.5,47),(2.3,4.9,1.4,3.4,12),(4.6,2.7,2.2,2.3,-22),(-1.2,-5.0,2.0,1.3,53)]):
 i+=1;mid=f'm{i}'
 subs.append(f'[sub_resource type="PlaneMesh" id="{mid}"]\nsize = Vector2({width},{depth})\nmaterial = SubResource("old_blood")\n')
 add_node('OldBlood'+str(k),'MeshInstance3D',props=f'position = {vec((x,.008,z))}\nrotation_degrees = Vector3(0,{angle},0)\nmesh = SubResource("{mid}")\ncast_shadow = 0')
# Door faces carry actual raised inset plates, ribs, hinges and a central lock.
for s in [-1,1]:
 box('RearInset'+str(s),(s*1.12,-.08,.19),(1.89,2.28,.035),'steel',False,parent='Door_Rear')
 for y in [-1.25,1.18]:box(f'RearBrace{s}_{y}',(s*1.12,y,.23),(1.90,.10,.09),'steel',False,parent='Door_Rear')
 for y in [-1.18,1.13]:cylinder(f'RearHinge{s}_{y}',(s*2.3,3.3+y,-15.72),.07,.18,'steel',(90,0,0))
box('RearLock',(0,-.20,.24),(.23,.72,.18),'steel',False,parent='Door_Rear')
label('RearWarning','BIOHAZARD', (0,.38,.25),size=50,pixel=.007,tint=(.46,.42,.24,1),parent='Door_Rear')
label('OperatingSign','OPERATING / A2',(18,3.32,.45),size=67,pixel=.007,tint=(.62,.57,.43,1))
label('ExitSign','DISCHARGE',(3,6.4,-29.92),size=83,pixel=.010,tint=(.59,.62,.45,1))
# Operating apparatus, lab stations and actual contextual supply cases.
box('OperatingTable',(17.1,.80,-5.4),(1.65,.24,3.0),'steel')
for k,(x,z) in enumerate([(16.5,-6.4),(17.7,-6.4),(16.5,-4.4),(17.7,-4.4)]):box('TableLeg'+str(k),(x,.37,z),(.12,.74,.12),'steel',False)
box('KeyPedestal',(20,.25,-7),(.8,.50,.8),'steel')
box('BioConsole',(12,.65,2.1),(3.0,1.3,.8),'steel')
box('RearLabConsole',(3.7,2.15,-19.8),(3,1.3,1.0),'steel')
light('BioKey',(15,3.5,6),(.88,.84,.71,1),2.5,10,True)
light('OperatingKey',(20,3.8,-5),(.86,.83,.73,1),2.5,10,True)
light('RearLabKey',(0,6.8,-22),(.74,.75,.65,1),3.4,14,True)
light('ExitWarm',(3,7.2,-28),(.83,.84,.68,1),2.6,9)
pickup('ContainmentKey','key',(20,.68,-7),1)
pickup('HallPistol','pistol',(-2.6,.24,6.4),20)
pickup('HallHealth','health',(4.6,.24,8.5),25)
pickup('BioShells','shells',(12,.24,8),8)
pickup('OperatingHealth','health',(22.5,.24,-8),25)
pickup('RearArmor','armor',(-2.0,1.76,-20.5),30)
pickup('RearShells','shells',(5.1,1.76,-27),8)
pickup('SecretArmor','armor',(-8.6,.24,8),50)
pickup('SecretShells','shells',(-8,.24,8.8),8)
room('ContainmentHall',(0,2.5,1),(6,3.3,17))
room('BioWing',(13,1.8,6),(7,2.3,5))
room('OperatingRoom',(19,1.8,-4.5),(5,2.3,5.5))
room('RearLab',(0,3,-23),(7,1.48,7))
room('ExitGallery',(0,5.8,-26.5),(7,1.3,3.5))
room('Secret',(-8,1.7,8),(2,2,2))
nav('BioPortal',(6,.87,5.5),['ContainmentHall','BioWing'])
nav('OperatingPortal',(18,.87,1),['BioWing','OperatingRoom'])
nav('ShortcutPortal',(10,.87,-2.5),['OperatingRoom','ContainmentHall'],'Door_Shortcut')
nav('RearPortal',(0,2.37,-16),['ContainmentHall','RearLab'],'Door_Rear')
nav('SecretPortal',(-6,.87,8),['ContainmentHall','Secret'],'Door_Secret')
marker('Exit_Discharge',(3,5.37,-28.5),'metadata/ward_exit = true')
add_node('EnemySpawns')
for n,(kind,encounter,pos) in enumerate([
 ('unsealed','ContainmentHall',(-2.0,.87,3.3)),('vessel','ContainmentHall',(4.6,.87,.7)),('unsealed','ContainmentHall',(-4.3,.87,-7.0)),
 ('unsealed','BioWing',(11.8,.87,5.8)),('vessel','BioWing',(17.8,.87,7.7)),
 ('unsealed','OperatingRoom',(21.8,.87,-4.3)),('vessel','OperatingRoom',(15.8,.87,-8.4)),
 ('unsealed','RearLab',(-1.8,2.37,-20)),('vessel','RearLab',(3.7,2.37,-24.5)),('unsealed','RearLab',(0.5,2.37,-27.4)),
 ('unsealed','Secret',(-8.6,.87,7.0))]):
 add_node('Spawn'+str(n),'Marker3D','EnemySpawns',f'position = {vec(pos)}\nmetadata/kind = "{kind}"\nmetadata/encounter = "{encounter}"')
# Optional raster infestation cutout is root-provided and remains outside route collision.
if (P/'assets/environment/ward-infestation.png').exists():
 ext.append('[ext_resource type="Texture2D" path="res://assets/environment/ward-infestation.png" id="infestation_tex"]')
 material('infestation','albedo_texture = ExtResource("infestation_tex")\ntransparency = 1\nroughness = .92\ncull_mode = 2\ntexture_filter = 0')
 for n,(pos,sz,rot) in enumerate([((-5.96,2.4,1.8),(4.8,7),(0,0,-90)),((-3.1,.022,4.4),(3.5,5),(0,0,0))]):
  i+=1;mid=f'm{i}';subs.append(f'[sub_resource type="PlaneMesh" id="{mid}"]\nsize = Vector2({sz[0]}, {sz[1]})\nmaterial = SubResource("infestation")\n')
  add_node('Infestation'+str(n),'MeshInstance3D',props=f'position = {vec(pos)}\nrotation_degrees = {vec(rot)}\nmesh = SubResource("{mid}")\ncast_shadow = 0')
root='''[node name="PaleWard" type="Node3D"]
script = ExtResource("level")
[node name="Environment" type="WorldEnvironment" parent="."]
environment = SubResource("environment")
[node name="DirectionalFill" type="DirectionalLight3D" parent="."]
rotation_degrees = Vector3(-58,-22,0)
light_color = Color(.55,.63,.72,1)
light_energy = .08
shadow_enabled = false
[node name="Player" type="CharacterBody3D" parent="."]
position = Vector3(0,.87,7.4)
script = ExtResource("player")
collision_layer = 2
collision_mask = 3
floor_snap_length = .22
[node name="CollisionShape3D" type="CollisionShape3D" parent="Player"]
shape = SubResource("player_shape")
[node name="Camera3D" type="Camera3D" parent="Player"]
position = Vector3(0,.65,0)
rotation_degrees = Vector3(-2,0,0)
current = true
fov = 90.0
[node name="AnnexPreviewPose" type="Marker3D" parent="."]
position = Vector3(7.8,.87,5.5)
rotation_degrees = Vector3(0,-90,0)
'''
scene=f'[gd_scene load_steps={1+len(ext)+len(subs)} format=3]\n\n'+'\n'.join(ext)+'\n\n'+'\n'.join(subs)+'\n'+root+'\n'.join(nodes)
scene=re.sub(r'(?<![\w])(-?)\.(\d+)',r'\g<1>0.\2',scene)
(P/'scenes/pale_ward.tscn').write_text(scene)
print(f'PALE_WARD_AUTHORED: {len(subs)} resources, {len(nodes)} node records,11 enemy markers,6 rooms,5 portal markers; infestation='+str((P/'assets/environment/ward-infestation.png').exists()))
