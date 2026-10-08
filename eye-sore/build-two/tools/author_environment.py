"""Deterministic original pixel materials and offline-authored 3D concept-room scene.
Run from any directory. No downloaded art, game assets, or third-party textures.
"""
from pathlib import Path
import random
import struct, zlib
class Raster:
 def __init__(self): self.pixels=[(0,0,0)]*(128*128)
 def __setitem__(self,xy,v):
  x,y=xy
  if 0<=x<128 and 0<=y<128:self.pixels[y*128+x]=v
 def save(self,path):
  def chunk(kind,data): return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
  scan=b''.join(b'\0'+bytes(v for pix in self.pixels[y*128:(y+1)*128] for v in pix) for y in range(128))
  path.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',128,128,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(scan))+chunk(b'IEND',b''))
 def rectangle(self,coords,fill=None,outline=None,width=1):
  x0,y0,x1,y1=coords
  for y in range(y0,y1+1):
   for x in range(x0,x1+1):
    if fill:self[x,y]=fill
    elif outline and (min(x-x0,x1-x,y-y0,y1-y)<width):self[x,y]=outline
 def line(self,coords,fill,width=1):
  x0,y0,x1,y1=coords; steps=max(abs(x1-x0),abs(y1-y0),1)
  for j in range(steps+1):
   x=round(x0+(x1-x0)*j/steps);y=round(y0+(y1-y0)*j/steps)
   self.rectangle((x,y,x+width-1,y+width-1),fill=fill)
 def point(self,xy,fill):self[xy]=fill
p=Path(__file__).resolve().parents[1]
rng=random.Random(472)
for name,base in [('concrete',(78,83,79)),('steel',(73,81,77)),('floor',(48,53,50)),('grate',(69,75,68))]:
 im=Raster(); pix=im
 for y in range(128):
  for x in range(128):
   d=rng.randrange(-4,5)
   pix[x,y]=tuple(max(0,min(255,v+d)) for v in base)
 draw=im
 if name=='concrete':
  for yy in [0,63,127]: draw.line((0,yy,127,yy),fill=(30,35,32),width=2)
  for xx,y0,y1 in [(0,0,63),(64,64,127)]: draw.line((xx,y0,xx,y1),fill=(36,40,37),width=2)
  for _ in range(18):
   x,y=rng.randrange(128),rng.randrange(128); draw.line((x,y,x+3,y+1),fill=(44,48,43))
 if name=='steel':
  draw.rectangle((2,2,125,125),outline=(29,35,31),width=4)
  draw.line((7,7,120,7),fill=(109,117,108),width=2)
  draw.line((7,8,7,120),fill=(95,103,95),width=2)
  for x in [11,116]:
   for y in [11,116]: draw.rectangle((x-2,y-2,x+2,y+2),fill=(27,31,27)); draw.point((x-1,y-1),fill=(121,129,118))
  for _ in range(18):
   x,y=rng.randrange(14,112),rng.randrange(14,110); draw.line((x,y,x+2,y+7),fill=(63,53,41),width=1)
 if name=='floor':
  for j in range(0,128,32):
   draw.line((j,0,j,127),fill=(22,27,23),width=2); draw.line((0,j,127,j),fill=(22,27,23),width=2)
  for y in range(8,128,16):
   for x in range(8,128,16): draw.line((x,y,x+4,y-3),fill=(71,78,65),width=2)
 if name=='grate':
  for y in range(0,128,8): draw.rectangle((0,y,127,y+3),fill=(20,25,21)); draw.line((0,y+4,127,y+4),fill=(114,120,101))
 im.save(p/'assets/materials'/f'{name}.png')
subs=[]; nodes=[]; ext=[]; idx=0
ext.append('[ext_resource type="Script" path="res://scripts/player.gd" id="player"]')
for name in ['concrete','steel','floor','grate']:
 ext.append(f'[ext_resource type="Texture2D" path="res://assets/materials/{name}.png" id="tex_{name}"]')
 subs.append(f'''[sub_resource type="StandardMaterial3D" id="{name}"]
albedo_texture = ExtResource("tex_{name}")
texture_filter = 0
roughness = 0.88
uv1_scale = Vector3({", ".join(map(str,{"concrete":(8,4,1),"floor":(8,11,1),"steel":(2,2,1),"grate":(3,8,1)}[name]))})
''')
for name,color in [('dark',(0.13,.16,.14)),('trim',(.3,.34,.29)),('rust',(.32,.19,.10)),('cyan',(.28,.75,.52)),('amber',(.95,.47,.13))]:
 subs.append(f'''[sub_resource type="StandardMaterial3D" id="{name}"]
albedo_color = Color({', '.join(map(str,color))}, 1)
roughness = 0.8
'''+ ('emission_enabled = true\nemission = Color('+', '.join(map(str,color))+', 1)\nemission_energy_multiplier = 1.5\n' if name in ['cyan','amber'] else ''))
subs.append('''[sub_resource type="Environment" id="environment"]
background_mode = 1
background_color = Color(0.018, 0.025, 0.022, 1)
ambient_light_source = 3
ambient_light_color = Color(0.44, 0.5, 0.45, 1)
ambient_light_energy = 0.42
tonemap_mode = 0
fog_enabled = true
fog_light_color = Color(0.06, 0.09, 0.07, 1)
fog_density = 0.008
''')
subs.append('[sub_resource type="CapsuleShape3D" id="player_shape"]\nradius = 0.3\nheight = 1.7\n')
def vec(x): return 'Vector3('+', '.join(map(str,x))+')'
def box(name,pos,size,mat='steel',solid=True,rot=None):
 global idx
 idx+=1; mesh=f'mesh_{idx}'; shape=f'shape_{idx}'
 subs.append(f'[sub_resource type="BoxMesh" id="{mesh}"]\nsize = {vec(size)}\nmaterial = SubResource("{mat}")\n')
 if solid: subs.append(f'[sub_resource type="BoxShape3D" id="{shape}"]\nsize = {vec(size)}\n')
 nodes.append(f'[node name="{name}" type="'+('StaticBody3D' if solid else 'Node3D')+'" parent="."]\nposition = '+vec(pos)+'\n'+('rotation_degrees = '+vec(rot)+'\n' if rot else ''))
 nodes.append(f'[node name="Visual" type="MeshInstance3D" parent="{name}"]\nmesh = SubResource("{mesh}")\n')
 if solid: nodes.append(f'[node name="Collision" type="CollisionShape3D" parent="{name}"]\nshape = SubResource("{shape}")\n')
def cylinder(name,pos,radius,height,mat='steel',rot=None,solid=True):
 global idx
 idx+=1; mesh=f'mesh_{idx}'; shape=f'shape_{idx}'
 subs.append(f'[sub_resource type="CylinderMesh" id="{mesh}"]\ntop_radius = {radius}\nbottom_radius = {radius}\nheight = {height}\nradial_segments = 12\nrings = 1\nmaterial = SubResource("{mat}")\n')
 if solid: subs.append(f'[sub_resource type="CylinderShape3D" id="{shape}"]\nradius = {radius}\nheight = {height}\n')
 nodes.append(f'[node name="{name}" type="'+('StaticBody3D' if solid else 'Node3D')+'" parent="."]\nposition = '+vec(pos)+'\n'+('rotation_degrees = '+vec(rot)+'\n' if rot else ''))
 nodes.append(f'[node name="Visual" type="MeshInstance3D" parent="{name}"]\nmesh = SubResource("{mesh}")\n')
 if solid:nodes.append(f'[node name="Collision" type="CollisionShape3D" parent="{name}"]\nshape = SubResource("{shape}")\n')
def light(name,pos,color,energy=2,range_=10):
 nodes.append(f'[node name="{name}" type="OmniLight3D" parent="."]\nposition = {vec(pos)}\nlight_color = Color({", ".join(map(str,color))}, 1)\nlight_energy = {energy}\nomni_range = {range_}\nshadow_enabled = true\n')
# Two connected architectural volumes; opening is physically empty, jambs are thick solids.
box('MainFloor',(0,-.35,10),(16,.7,22),'floor')
box('AnnexFloor',(0,-.35,-10),(16,.7,16),'floor')
box('MainCeiling',(0,6.1,10),(16,.5,22),'concrete')
box('AnnexCeiling',(0,5.0,-10),(16,.5,16),'concrete')
for name,pos,size in [('LeftMain',(-8.35,3,10),(.7,6,22)),('RightMain',(8.35,3,10),(.7,6,22)),('RearMain',(0,3,21.35),(17.4,6,.7)),('LeftAnnex',(-8.35,2.4,-10),(.7,4.8,16)),('RightAnnex',(8.35,2.4,-10),(.7,4.8,16)),('EndAnnex',(0,2.4,-18.35),(17.4,4.8,.7)),('PortalLeft',(-5.6,3,-1),(4.8,6,1.5)),('PortalRight',(5.6,3,-1),(4.8,6,1.5)),('PortalLintel',(0,4.9,-1),(6.4,2.2,1.5))]: box(name,pos,size,'concrete')
for x in [-3.15,3.15]:
 box('PortalJamb'+str(x).replace('.','_'),(x,1.9,-.12),(.32,3.8,.45),'steel')
box('PortalHeader',(0,3.7,-.12),(6.6,.4,.45),'steel')
box('PortalAccent',(0,3.58,.13),(4.5,.06,.06),'cyan',False)
# Structural frames make depth and repeated spatial intervals legible.
for j,z in enumerate([3,9,15]):
 for side,x in [('L',-7.72),('R',7.72)]:
  box(f'Rib{j}{side}',(x,3,z),(.55,6,.65),'steel')
  box(f'Foot{j}{side}',(x,.45,z),(.8,.9,1),'dark')
 box(f'Beam{j}',(0,5.65,z),(16,.6,.65),'steel')
 for side,x in [('L',-5.5),('R',5.5)]:
  box(f'LampHousing{j}{side}',(x,5.24,z),(1.7,.22,.6),'dark',False)
  box(f'LampFace{j}{side}',(x,5.10,z),(1.4,.06,.4),'amber' if j==2 else 'cyan',False)
# Raised service walkway left, with actual six-step silhouettes and an invisible sloped collision.
box('ServiceWalkway',(-5.8,.45,4.65),(3,.9,7.3),'grate')
for j in range(6):
 h=(j+1)*.15
 box(f'Step{j}',(-5.8,h/2,10.5-j*.4),(3,h,.4),'steel',False)
idx+=1; ramp=f'ramp_{idx}'
subs.append(f'[sub_resource type="ConvexPolygonShape3D" id="{ramp}"]\npoints = PackedVector3Array(-1.5, 0, -1.2, 1.5, 0, -1.2, -1.5, 0, 1.2, 1.5, 0, 1.2, -1.5, 0.9, -1.2, 1.5, 0.9, -1.2)\n')
nodes.append(f'[node name="StairRampCollision" type="StaticBody3D" parent="."]\nposition = Vector3(-5.8, 0, 9.5)\n[node name="Collision" type="CollisionShape3D" parent="StairRampCollision"]\nshape = SubResource("{ramp}")\n')
for j,z in enumerate([1.2,3.5,5.8,8.4]):
 box(f'RailPost{j}',(-4.25,1.45,z),(.09,1.1,.09),'trim')
box('RailTop',(-4.25,2.0,4.8),(.1,.1,7.4),'trim')
# Machined biotech-adjacent forms: two tall processing vessels, ribs, recessed service recess.
for k,(x,z) in enumerate([(-5.8,3.6),(4.6,-10.5)]):
 cylinder(f'Vessel{k}',(x,2.2,z),1.05,3.4,'steel')
 for j,y in enumerate([.65,1.3,3.1,3.75]): cylinder(f'VesselRing{k}_{j}',(x,y,z),1.15,.18,'dark')
 cylinder(f'VesselCap{k}',(x,4.0,z),.7,.4,'steel')
 box(f'VesselGauge{k}',(x,.0+2.2,z+1.08),(.45,1.05,.16),'dark',False)
 for j in range(4): box(f'VesselGaugeMark{k}_{j}',(x,1.85+j*.21,z+1.18),(.24,.06,.04),'cyan',False)
box('AnnexPartition',(-3,2,-9),(1,4,9),'concrete')
box('AnnexPlinth',(4.6,.2,-10.5),(3.2,.4,3.2),'steel')
box('UtilityCabinet',(6.75,1.3,6),(1.7,2.6,2.1),'steel')
box('CabinetInset',(5.86,1.7,6),(.06,.9,1.4),'dark',False)
for j in range(5): box(f'VentSlat{j}',(5.81,1.38+j*.14,6),(.05,.05,1.15),'trim',False)
# Overhead conduits connect architecture; short hanging sections add silhouette.
for j,x in enumerate([-2.3,-1.65]):
 cylinder(f'MainPipe{j}',(x,5.08,8),.18,18,'rust',(90,0,0),False)
 cylinder(f'AnnexPipe{j}',(x,4.3,-9),.18,16,'rust',(90,0,0),False)
 cylinder(f'PortalDrop{j}',(x,4.65,-.9),.18,.85,'rust',None,False)
 for k,z in enumerate([2,8,14]): cylinder(f'PipeCollar{j}_{k}',(x,5.08,z),.23,.12,'dark',(90,0,0),False)
for j,z in enumerate([3,9,15]): box(f'PipeSupport{j}',(-1.97,5.42,z),(1.2,.12,.16),'dark',False)
# Deep annex light and local warm utility light create hierarchy without flattening material detail.
light('MainKey',(1,4.5,8),(.72,.83,.72),2.6,12)
light('PortalLight',(-1,3.2,-3),(.25,.7,.46),2.1,11)
light('AnnexKey',(4,3.8,-11),(.7,.79,.62),2.6,11)
light('WarmUtility',(6.6,3.8,14),(1,.53,.25),1.9,9)
root='''[node name="Calibration" type="Node3D"]
process_mode = 1
[node name="Environment" type="WorldEnvironment" parent="."]
environment = SubResource("environment")
[node name="DirectionalFill" type="DirectionalLight3D" parent="."]
rotation_degrees = Vector3(-55, -20, 0)
light_color = Color(0.6, 0.67, 0.59, 1)
light_energy = 0.24
shadow_enabled = true
[node name="AnnexPreviewPose" type="Marker3D" parent="."]
position = Vector3(1.4, 0.86, -3.6)
rotation_degrees = Vector3(0, -14, 0)
[node name="Player" type="CharacterBody3D" parent="."]
position = Vector3(5.7, 0.86, 16.3)
rotation_degrees = Vector3(0, 20, 0)
script = ExtResource("player")
[node name="CollisionShape3D" type="CollisionShape3D" parent="Player"]
shape = SubResource("player_shape")
[node name="Camera3D" type="Camera3D" parent="Player"]
position = Vector3(0, 0.65, 0)
rotation_degrees = Vector3(-2, 0, 0)
current = true
fov = 90.0
'''
scene=f'[gd_scene load_steps={1+len(ext)+len(subs)} format=3]\n\n'+'\n'.join(ext)+'\n\n'+'\n'.join(subs)+'\n'+root+'\n'.join(nodes)
(p/'scenes/calibration.tscn').write_text(scene)
print('Authored original materials: 4; subresources:',len(subs),'geometry nodes:',len(nodes))
