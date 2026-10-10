"""Build the coordinator-authored stages, sampling original board rectangles natively.
Every structural box uses identical BoxMesh and BoxShape3D dimensions. Room wall
openings, connector floors, stairs, and lift decks come from the explicit layout.
No source image processing occurs here; only scene/resource text is authored.
"""
from pathlib import Path
import json, math, re
P = Path(__file__).resolve().parents[1]

def vec(v): return 'Vector3(' + ', '.join(f'{x:.6g}' for x in v) + ')'
def quote(s): return json.dumps(s, ensure_ascii=False)
def arr(a): return 'Array[String]([' + ', '.join(quote(s) for s in a) + '])'

class Scene:
    def __init__(self, stage):
        self.stage = stage; self.ext=[]; self.sub=[]; self.nodes=[]; self.i=0; self.vertical_routes={}; self.combat_paths={}
        for name, path in [('level','scripts/stage_level.gd'),('door','scripts/stage_door.gd'),('lift','scripts/ward_lift.gd'),('player','scripts/player.gd'),('surface','shaders/ward_surface.gdshader')]:
            self.ext.append(f'[ext_resource type="'+('Shader' if name=='surface' else 'Script')+f'" path="res://{path}" id="{name}"]')
        self.sub.append('[sub_resource type="CapsuleShape3D" id="player_shape"]\nradius = .3\nheight = 1.7\n')
        self.mat('trim',(.12,.13,.14,1)); self.mat('recess',(.055,.05,.045,1)); self.mat('brass',(.85,.58,.14,1),1); self.mat('red',(.78,.07,.035,1),1)
        self.mat('health',(.7,.12,.08,1)); self.mat('armor',(.12,.42,.48,1)); self.mat('ammo',(.55,.49,.35,1))
    def node(self,name,typ='Node3D',parent='.',props=''):
        self.nodes.append(f'[node name="{name}" type="{typ}" parent="{parent}"]\n{props}\n')
    def mat(self,name,c,emission=0):
        self.sub.append(f'[sub_resource type="StandardMaterial3D" id="{name}"]\nalbedo_color = Color({",".join(map(str,c))})\nroughness = .9\n'+(f'emission_enabled = true\nemission = Color({",".join(map(str,c))})\nemission_energy_multiplier = {emission}\n' if emission else ''))
    def board_material(self,name,board,rect,scale=.35):
        eid='board_'+name
        self.ext.append(f'[ext_resource type="Texture2D" path="{board}" id="{eid}"]')
        self.sub.append(f'[sub_resource type="ShaderMaterial" id="{name}"]\nshader = ExtResource("surface")\nshader_parameter/painted_surface = ExtResource("{eid}")\nshader_parameter/source_region_pixels = Vector4({", ".join(map(str,rect))})\nshader_parameter/world_scale = {scale}\nshader_parameter/tint = Color(1,1,1,1)\nshader_parameter/metal = .18\nshader_parameter/base_roughness = .86\nshader_parameter/relief = .20\n')
    def daylight_material(self,rect):
        # Native panel pixels soften the daylight surface; no image processing.
        color=(.30,.25,.20,1) if self.stage['id']=='ash_citadel' else (.32,.38,.42,1)
        self.sub.append('[sub_resource type="AtlasTexture" id="daylight_panel"]\natlas = ExtResource("board_panel")\nregion = Rect2('+', '.join(map(str,rect))+')\nfilter_clip = true\n')
        self.mat('daylight',color,.5)
        self.sub[-1]+='albedo_texture = SubResource("daylight_panel")\ntexture_filter = 0\ntexture_repeat = false\n'
    def daylight_band(self,name,pos,size,axis,inward):
        self.box(name,pos,size,'daylight',False)
        cross=2 if axis==0 else 0
        intervals=math.ceil(size[axis]/1.2)
        for index in range(intervals+1):
            bar=[0,0,0];bar[axis]=-size[axis]/2+size[axis]*index/intervals;bar[cross]=inward*.055
            dimensions=[.08,size[1],.08]
            self.box('Mullion'+str(index),bar,dimensions,'trim',False,name)
    def box(self,name,pos,size,mat='wall',solid=True,parent='.',extra='',typ=None,rot=None,hit_material=None):
        self.i+=1; idx=self.i
        self.sub.append(f'[sub_resource type="BoxMesh" id="m{idx}"]\nsize = {vec(size)}\nmaterial = SubResource("{mat}")\n')
        if solid:self.sub.append(f'[sub_resource type="BoxShape3D" id="s{idx}"]\nsize = {vec(size)}\n')
        props='position = '+vec(pos)+'\n'+('rotation_degrees = '+vec(rot)+'\n' if rot else '')+extra
        if solid:props+='\ncollision_layer = 1\ncollision_mask = 3\nmetadata/hit_material = '+quote(hit_material or ('armor' if mat in ['steel','grate','trim','recess'] else 'hard'))
        self.node(name,typ or ('StaticBody3D' if solid else 'Node3D'),parent,props)
        path=name if parent=='.' else parent+'/'+name
        self.node('Visual','MeshInstance3D',path,f'mesh = SubResource("m{idx}")')
        if solid:self.node('Collision','CollisionShape3D',path,f'shape = SubResource("s{idx}")')
    def prism(self,name,pos,points,height,mat='wall'):
        # Runtime creates one indexed native mesh and collider from these vertices.
        packed='PackedVector2Array('+', '.join(str(v) for point in points for v in point)+')'
        self.node(name,'Node3D',props='position = '+vec(pos)+'\nmetadata/stage_polygon = '+packed+'\nmetadata/polygon_height = '+str(height)+'\nmetadata/polygon_material = SubResource("'+mat+'")')
    def stairs(self,name,start,end,width,mat='stairs'):
        axis=0 if abs(end[0]-start[0])>abs(end[2]-start[2]) else 2
        rise=end[1]-start[1]; assert rise>0
        length=abs(end[axis]-start[axis]); steps=math.ceil(rise/.125)
        for k in range(steps):
            h=(k+1)*rise/steps;pp=list(start);pp[axis]+=(end[axis]-start[axis])*(k+.5)/steps;pp[1]+=h/2
            size=[width,h,width];size[axis]=length/steps+.008
            self.box(name+str(k),pp,size,mat,extra='metadata/stage_step = true')
    def cylinder(self,name,pos,radius,height,mat='steel',solid=True):
        self.i+=1;idx=self.i
        self.sub.append(f'[sub_resource type="CylinderMesh" id="m{idx}"]\ntop_radius = {radius}\nbottom_radius = {radius}\nheight = {height}\nradial_segments = 24\nmaterial = SubResource("{mat}")\n')
        if solid:self.sub.append(f'[sub_resource type="CylinderShape3D" id="s{idx}"]\nradius = {radius}\nheight = {height}\n')
        self.node(name,'StaticBody3D' if solid else 'Node3D',props='position = '+vec(pos)+('\ncollision_layer = 1\ncollision_mask = 3\nmetadata/hit_material = "armor"' if solid else ''))
        self.node('Visual','MeshInstance3D',name,f'mesh = SubResource("m{idx}")')
        if solid:self.node('Collision','CollisionShape3D',name,f'shape = SubResource("s{idx}")')
    def downlight(self,name,pos,energy=4.0,reach=15):
        self.node(name,'SpotLight3D',props='position = '+vec(pos)+f'\nrotation_degrees = Vector3(-90,0,0)\nlight_color = Color(.9,.88,.8,1)\nlight_energy = {energy}\nspot_range = {reach}\nspot_angle = 62\nshadow_enabled = true\nshadow_bias = .025\nshadow_normal_bias = .35')
    def marker(self,name,pos,meta,parent='.'):
        self.node(name,'Marker3D',parent,'position = '+vec(pos)+'\n'+meta)
    def label(self,name,text,pos,parent='.',rotation=(0,0,0),color=(.82,.75,.58,1),size=44):
        self.node(name,'Label3D',parent,'position = '+vec(pos)+'\nrotation_degrees = '+vec(rotation)+'\ntext = '+quote(text)+f'\nfont_size = {size}\npixel_size = .008\noutline_size = 0\nmodulate = Color({",".join(map(str,color))})\nshaded = true\n')
    def light(self,name,pos,c,energy=2,reach=18):
        self.node(name,'OmniLight3D',props='position = '+vec(pos)+f'\nlight_color = Color({",".join(map(str,c))})\nlight_energy = {energy}\nomni_range = {reach}\n')
    def pickup(self,name,kind,pos,amount=25):
        self.node(name,props='position = '+vec(pos)+'\nmetadata/stage_pickup = '+quote(kind)+f'\nmetadata/amount = {amount}')
        if kind in ['twin_shotgun','rivet_cannon','siege_launcher']:
            # Readable native world silhouettes match the cache's actual grant.
            self.box('Receiver',(0,.06,.08),(.42,.22,.48),'steel',False,name)
            self.box('Grip',(0,-.11,.22),(.14,.32,.17),'recess',False,name,rot=(18,0,0))
            if kind=='twin_shotgun':
                for side in [-1,1]:self.box('Barrel'+str(side),(side*.11,.06,-.52),(.15,.15,.86),'steel',False,name)
                self.box('Stock',(0,.03,.54),(.28,.17,.48),'cloth',False,name)
                self.box('Pump',(0,-.025,-.35),(.38,.13,.37),'panel',False,name)
            elif kind=='rivet_cannon':
                self.box('RivetShroud',(0,.09,-.46),(.43,.29,.72),'steel',False,name)
                self.box('Magazine',(.23,-.10,.05),(.26,.4,.34),'panel',False,name)
                for band in range(3):self.box('Brace'+str(band),(0,.25,-.3-band*.18),(.47,.06,.07),'glow',False,name)
            else:
                self.box('LaunchTube',(0,.13,-.28),(.49,.36,1.16),'steel',False,name)
                self.box('Muzzle',(0,.13,-.88),(.39,.28,.018),'recess',False,name)
                self.box('Sight',(.30,.34,-.05),(.13,.11,.34),'panel',False,name)
        else: self.box('Case',(0,0,0),(.55,.34,.43),kind.removesuffix('_key') if kind in ['health','armor','brass','red','brass_key','red_key'] else 'ammo',False,name)
        self.label('Mark',{'twin_shotgun':'TWIN','rivet_cannon':'RIVET','siege_launcher':'SIEGE','rivets':'RIVETS','rockets':'ROCKETS','shells':'12G','pistol':'9MM','health':'+','armor':'A','brass':'BRASS','red':'RED','brass_key':'BRASS','red_key':'RED'}[kind],(0,.3,0),name,size=28)
    def sign(self,name,board,rect,pos,size,board_size=(1536,1024),rot=(0,0,0)):
        eid='sign_'+name; mat='sm_'+name; mesh='signmesh_'+name
        self.ext.append(f'[ext_resource type="Texture2D" path="{board}" id="{eid}"]')
        x,y,w,h=rect;bw,bh=board_size
        self.sub.append(f'[sub_resource type="StandardMaterial3D" id="{mat}"]\nalbedo_texture = ExtResource("{eid}")\ntexture_filter = 0\ntexture_repeat = false\nroughness = .9\nshading_mode = 1\nuv1_scale = {vec((w/bw,h/bh,1))}\nuv1_offset = {vec((x/bw,y/bh,0))}\n')
        self.sub.append(f'[sub_resource type="QuadMesh" id="{mesh}"]\nmaterial = SubResource("{mat}")\nsize = Vector2({size[0]}, {size[1]})\n')
        self.node(name,'MeshInstance3D',props='position = '+vec(pos)+'\nrotation_degrees = '+vec(rot)+f'\nmesh = SubResource("{mesh}")')
    def save(self,path):
        title=self.stage.get('title',self.stage['id'])
        root=f'[node name="{self.stage["id"].title().replace("_", "")}" type="Node3D"]\nscript = ExtResource("level")\nmetadata/stage_id = {quote(self.stage["id"])}\nmetadata/stage_title = {quote(title)}\n'
        out='[gd_scene load_steps='+str(len(self.ext)+len(self.sub)+1)+' format=3]\n\n'+'\n'.join(self.ext)+'\n\n'+'\n'.join(self.sub)+'\n'+root+'\n'+'\n'.join(self.nodes)
        out=re.sub(r'(?<![\w])(-?)\.(\d+)',r'\g<1>0.\2',out)
        (P/path).write_text(out.rstrip()+"\n")

# Layout schema is supplied by the art/level coordinator, rather than inferred
# from image pixels. Keeping authoring separate preserves exact original boards.
def author(stage, contract):
    sc=Scene(dict(stage,title=contract['title']))
    for name,rect in stage['material_regions'].items(): sc.board_material(name,stage['board'],rect)
    # Versioned atlases are sampled in their native pixel regions, never rescaled.
    atlas=P/'assets/materials/architecture-v2'/f'{stage["id"]}-atlas.png'
    if atlas.exists():
        from struct import unpack
        bw,bh=unpack('>II',atlas.read_bytes()[16:24]);cw,ch=bw//4,bh//3
        slots=['wall','floor','ceiling','steel','grate','door_skin','panel','damaged','stairs','invasion','banner','pillar']
        for index,name in enumerate(slots):
            sc.sub=[resource for resource in sc.sub if not resource.startswith('[sub_resource type="ShaderMaterial" id="'+name+'"]')]
            sc.ext=[resource for resource in sc.ext if not resource.endswith('id="board_'+name+'"]')]
            sc.board_material(name,'res://'+str(atlas.relative_to(P)),[(index%4)*cw,(index//4)*ch,cw,ch])
    else:
        for name,source in [('ceiling','wall'),('door_skin','steel'),('panel','steel'),('damaged','wall'),('stairs','grate'),('banner','invasion'),('pillar','wall')]: sc.board_material(name,stage['board'],stage['material_regions'][source])
    sc.daylight_material([2*cw,ch,cw,ch] if atlas.exists() else stage['material_regions']['steel'])
    sc.mat('glow', {'pale_ward':(.58,.64,.20,1),'ash_citadel':(1,.27,.035,1),'occupied_line':(.12,.8,.9,1)}[stage['id']],1.4)
    sc.mat('cloth',(.28,.035,.025,1));sc.mat('glass',(.36,.42,.12,.22));sc.sub[-1]+='transparency = 1\nroughness = .22\ncull_mode = 2\n';sc.mat('orange',(.85,.31,.04,1),.3)
    if stage['id']=='pale_ward':
        sc.ext.append('[ext_resource type="Texture2D" path="res://assets/enemies/board-sprites/unsealed-atlas.png" id="specimen_source"]')
        sc.sub.append('[sub_resource type="AtlasTexture" id="specimen"]\natlas = ExtResource("specimen_source")\nregion = Rect2(0,0,384,512)\n')
    sc.sub.append('[sub_resource type="Environment" id="environment"]\nbackground_mode = 1\nbackground_color = Color(.025,.025,.035,1)\nambient_light_source = 2\nambient_light_color = Color(.53,.55,.58,1)\nambient_light_energy = .45\ntonemap_mode = 0\n')
    sc.node('WorldEnvironment','WorldEnvironment',props='environment = SubResource("environment")')
    rooms={r['id']:r for r in stage['rooms']}; openings={k:{side:[] for side in ['N','S','E','W']} for k in rooms}
    routes=[]
    for number,source_portal in enumerate(stage['portals']):
        p=dict(source_portal)
        a,b=rooms[p['from']],rooms[p['to']];ac,bc=a['center'],b['center'];asz,bsz=a['size'],b['size'];dx,dz=bc[0]-ac[0],bc[2]-ac[2];w=p['width']
        axis=0 if abs(dx)>abs(dz) else 2;cross=2 if axis==0 else 0;sign=1 if bc[axis]>ac[axis] else -1
        lo=max(ac[cross]-asz[cross]/2,bc[cross]-bsz[cross]/2)+w/2
        hi=min(ac[cross]+asz[cross]/2,bc[cross]+bsz[cross]/2)-w/2
        assert lo<=hi,(p['from'],p['to'],'corridor cross span does not overlap')
        c=max(lo,min(hi,ac[cross]));start=list(ac);end=list(bc)
        start[axis]+=sign*asz[axis]/2;end[axis]-=sign*bsz[axis]/2;start[cross]=end[cross]=c
        aside=('E' if sign>0 else 'W') if axis==0 else ('S' if sign>0 else 'N')
        bside={'E':'W','W':'E','N':'S','S':'N'}[aside]
        openings[a['id']][aside].append((c-w/2,c+w/2));openings[b['id']][bside].append((c-w/2,c+w/2))
        length=abs(end[axis]-start[axis]);assert length>0,(a['id'],b['id'])
        middle=[(start[k]+end[k])/2 for k in range(3)];floor=min(ac[1],bc[1]);h=min(asz[1],bsz[1]);name='Link_'+str(number)
        floor_size=[w,.5,w];floor_size[axis]=length+.04
        lift=p.get('lift',False);rise=bc[1]-ac[1]
        if lift:
            deck=list(end);deck[axis]-=sign*2;deck[1]=ac[1]-.15
            approach_len=length-4;fpos=list(middle);fpos[axis]=start[axis]+sign*approach_len/2;fpos[1]=ac[1]-.25
            fs=list(floor_size);fs[axis]=approach_len+.04;sc.box(name+'_Approach',fpos,fs,'floor')
            sc.box('Lift_Observation',deck,(4,.3,4),'steel',typ='AnimatableBody3D',extra='script = ExtResource("lift")\nmetadata/ward_lift = true\nmetadata/requires = '+arr(['clear_final_arena'])+'\nmetadata/locked_message = "Clear the final arena before operating this lift"\nmetadata/lift_offset = '+vec((0,rise,0))+'\nmetadata/use_anchor = Vector3(0,1,0)')
            for signpost in [-1,1]:
                pp=list(deck);pp[cross]+=signpost*2.3;pp[1]=floor+3
                sc.box('LiftGuide'+str(signpost),pp,(.15,7,.15),'steel')
        elif rise:
            low,high=(start,end) if rise>0 else (end,start)
            sc.stairs('Step_'+str(number)+'_',low,high,w)
        else:
            pp=list(middle);pp[1]=floor-.25;sc.box(name+'_Floor',pp,floor_size,'floor')
        roof=list(middle);roof[1]=max(ac[1],bc[1])+h+.15;rs=list(floor_size);rs[1]=.3;sc.box(name+'_Roof',roof,rs,'ceiling')
        for side in [-1,1]:
            pp=list(middle);pp[cross]+=side*(w/2+.2);pp[1]=floor+(h+abs(rise))/2
            ss=[.4,h+abs(rise),.4];ss[axis]=length
            sc.box(name+'_Wall'+str(side),pp,ss,'wall')
        gate_name=None
        if p.get('gate') and not lift:
            gate_name='Door_'+p['gate'];pp=list(middle);pp[1]=(ac[1]+bc[1])/2+2.3
            if p['gate']=='entry_gate':
                pp=list(end);pp[axis]-=sign*.3;pp[1]=bc[1]+2.3
            ss=[w,4.6,w];ss[axis]=.3
            required=p.get('requires',[]);tag='RED' if 'red_key' in required else 'BRASS' if 'brass_key' in required else 'POWER' if 'breaker' in required else 'RELEASE' if 'release' in required else 'EXIT' if 'exit_control' in required else 'ACCESS'
            extra='script = ExtResource("door")\nmetadata/stage_door = '+quote(p['gate'])+'\nmetadata/requires = '+arr(required)+'\nmetadata/locked_message = '+quote(tag+' access required')+'\nmetadata/label = '+quote('open '+tag.lower()+' gate')+'\nmetadata/open_offset = Vector3(0,6,0)\nmetadata/use_anchor = Vector3(0,-1.2,0)'
            if p.get('secret'):extra+='\nmetadata/secret = true'
            if p.get('shortcut'):extra+='\nmetadata/shortcut = true'
            sc.box(gate_name,pp,ss,'door_skin',typ='AnimatableBody3D',extra=extra,hit_material='armor' if tag=='ACCESS' else 'hard')
            indicator='red' if tag in ['RED','RELEASE'] else 'brass' if tag in ['BRASS','POWER'] else 'glow' if tag=='EXIT' else 'steel'
            # Two small color strips remain readable from either approach and
            # travel with the textured leaf; they have no collision surfaces.
            for face in [-1,1]:
                stripe=[0,.15,0];stripe[axis]=face*.17
                stripe_size=[min(1.5,w*.35),.12,min(1.5,w*.35)];stripe_size[axis]=.025
                sc.box('LockIndicator'+str(face),stripe,stripe_size,indicator,False,gate_name)
            if p['gate']=='entry_gate': tag='C3 / CONTAINMENT'
            sc.label('GateMark',tag,(0,.7,.18) if axis==2 else (.18,.7,0),gate_name,rotation=(0,90,0) if axis==0 else (0,0,0))
            if p['gate']=='entry_gate':
                for side in [-1,1]:
                    jp=list(pp);jp[cross]+=side*(w/2+.3);jp[1]=bc[1]+2.5
                    js=[.5,5,.5];js[axis]=1.2
                    sc.box('EntryGateJamb'+str(side),jp,js,'steel')
                jp=list(pp);jp[1]=bc[1]+4.9;js=[w+1,.45,w+1];js[axis]=1.2;sc.box('EntryGateHeader',jp,js,'steel')
        if b['id'] in ['arena_one','arena_two','final_arena']:
            trap='TrapEntry_'+b['id'];pp=list(end);pp[axis]+=sign*.15;pp[1]=bc[1]+2.3
            ss=[w,4.6,w];ss[axis]=.3
            normal=[0,0,0];normal[axis]=sign
            sc.box(trap,pp,ss,'door_skin',typ='AnimatableBody3D',extra='script = ExtResource("door")\nmetadata/trap_entry = '+quote(b['id'])+'\nmetadata/initially_open = true\nmetadata/open_offset = Vector3(0,6,0)\nmetadata/entry_normal = '+vec(normal)+'\nmetadata/entry_threshold = '+vec(end))
            p['trap_entry']=trap
        for n,point in enumerate([start,middle,end]):
            meta='metadata/stage_nav = '+arr([a['id'],b['id']])+(f'\nmetadata/stage_nav_door = NodePath("../{gate_name}")' if gate_name else '')
            sc.marker('Nav_%d_%d'%(number,n),point,meta)
        # Author bot uses this exact floor/portal route, never teleports.
        routes.append(dict(p,start=start,end=end,middle=middle,axis=axis,door=gate_name))
    sc.openings = openings
    optional=['supplies','maintenance','pump_room','armory']
    for rid,r in rooms.items():
        x,y,z=r['center'];sx,h,sz=r['size'];sc.marker('Room_'+rid,(x,y+h/2,z),'metadata/stage_room = '+quote(rid)+'\nmetadata/stage_label = '+quote(r['label'])+'\nmetadata/room_bounds = '+vec((sx/2,h/2+1,sz/2))+'\nmetadata/optional = '+str(rid in optional).lower()+(('\nmetadata/arena_id = '+quote(r['arena_id'])) if r['arena_id'] else ''))
        if stage['id']=='pale_ward' and rid=='arena_one':
            # Real recessed wet sump: four rim slabs and a lower, solid basin.
            for suffix,px,pz,wx,wz in [('West',x-6,z,24,sz),('East',x+14,z,8,sz),('North',x+8,z-(sz/2+8.5)/2,4,sz/2-8.5),('South',x+8,z+(sz/2-3.5)/2,4,sz/2+3.5)]:
                sc.box(rid+'_Floor'+suffix,(px,y-.25,pz),(wx+.04,.5,wz+.04),'floor')
            sc.box(rid+'_SumpFloor',(x+8,y-.60,z-6),(4.04,.5,5.04),'damaged')
            sc.box(rid+'_BloodSurface',(x+8,y-.34,z-6),(3.9,.018,4.9),'invasion',False)
            sc.stairs(rid+'_SumpWest',[x+7.2,y-.35,z-6],[x+6,y,z-6],3)
            sc.stairs(rid+'_SumpEast',[x+8.8,y-.35,z-6],[x+10,y,z-6],3)
        else: sc.box(rid+'_Floor',(x,y-.25,z),(sx+.04,.5,sz+.04),'floor')
        sc.box(rid+'_Roof',(x,y+h+.2,z),(sx+.8,.4,sz+.8),'ceiling')
        for side in ['N','S','E','W']:
            axis=0 if side in ['N','S'] else 2;cross=2 if axis==0 else 0;span=sx if axis==0 else sz;cent=x if axis==0 else z
            intervals=sorted(openings[rid][side]);cursor=cent-span/2;finish=cent+span/2
            for idx,(lo,hi) in enumerate(intervals+[(finish,finish)]):
                if lo>cursor+.001:
                    pp=[x,y+h/2,z];pp[axis]=(cursor+lo)/2;pp[cross]+=(1 if side in ['S','E'] else -1)*r['size'][cross]/2
                    ss=[.4,h,.4];ss[axis]=lo-cursor
                    wall_name=rid+'_'+side+str(idx)
                    if stage['id']=='ash_citadel' and r['arena_id']:
                        low=list(pp);low[1]=y+3;low_size=list(ss);low_size[1]=6;sc.box(wall_name+'_Lower',low,low_size,'wall')
                        upper=list(pp);upper[1]=y+9+(h-9)/2;upper_size=list(ss);upper_size[1]=h-9;sc.box(wall_name+'_Upper',upper,upper_size,'wall')
                        window=list(pp);window[1]=y+7.5;window[cross]+=(1 if side in ['S','E'] else -1)*.25
                        glazing=list(ss);glazing[cross]=.04;glazing[1]=3;sc.daylight_band(wall_name+'_Clerestory',window,glazing,axis,-1 if side in ['S','E'] else 1)
                        for rib in range(max(1,math.ceil((lo-cursor)/6))):
                            pier=list(pp);pier[axis]=cursor+(lo-cursor)*(rib+.5)/max(1,math.ceil((lo-cursor)/6));pier[1]=y+7.5
                            pier_size=list(ss);pier_size[axis]=.8;pier_size[1]=3;sc.box(wall_name+'_WindowPier'+str(rib),pier,pier_size,'pillar')
                    else: sc.box(wall_name,pp,ss,'wall')
                if hi>lo:
                    pp=[x,y+4.6+(h-4.6)/2,z];pp[axis]=(lo+hi)/2;pp[cross]+=(1 if side in ['S','E'] else -1)*r['size'][cross]/2
                    ss=[.4,max(.2,h-4.6),.4];ss[axis]=hi-lo;sc.box(rid+'_Lintel'+side+str(idx),pp,ss,'steel')
                cursor=max(cursor,hi)
        sc.light('Light_'+rid,(x,y+h-.7,z),{'pale_ward':(.9,.9,.72,1),'ash_citadel':(1,.48,.16,1),'occupied_line':(.61,.76,.93,1)}[stage['id']],2.5,max(sx,sz)*.8)
        sc.label('RoomName_'+rid,r['label'].upper(),(x,y+3,z-sz/2+.3))
        if stage['id']=='pale_ward' and rid=='service':
            deck_y=y+2.5;bx=x+3.8
            sc.box('ServiceBalcony',(bx,deck_y-.18,z),(2.4,.36,8),'grate')
            for end in [-1,1]:sc.stairs('ServiceBalconyStairs'+str(end),[bx,y,z+end*13],[bx,deck_y,z+end*4],2.4)
            sc.vertical_routes['service_balcony']=[[bx,y,z+13],[bx,deck_y,z+4],[bx,deck_y,z-4],[bx,y,z-13]]
        # Themes use different built architecture silhouettes and fixtures.
        if rid in ['entry','arena_one','arena_two','final_arena']:
            if rid=='entry': decorate(sc,stage,r)
            else: architecture(sc,stage,r)
    sc.node('EnemySpawns')
    enemy_index=0
    for rid,count in stage['enemy_counts'].items():
        r=rooms[rid];x,y,z=r['center'];sx,h,sz=r['size']
        for k in range(count):
            # Width-separated rows never obstruct a threshold or button.
            px=x+((k%3)-1)*min(5,sx/4);pz=z+(k//3-1)*4.0
            if r['arena_id']:
                side=-1 if k<4 else 1;slot=k if k<4 else k-4
                px=x+side*(sx/2-2.4);pz=z-9+slot*6
                closet(sc,r,side,slot,px,pz)

            kind=contract['enemy_kinds'][1 if k%3==2 else 0]
            sc.marker('Spawn_'+str(enemy_index),(px,y+.87,pz),'metadata/kind = '+quote(kind)+'\nmetadata/arena_id = '+quote(r['arena_id'])+'\nmetadata/activate_room = '+quote(rid),'EnemySpawns');enemy_index+=1
    for rid,spec in stage['weapon_cache'].items():
        r=rooms[rid];x,y,z=r['center'];platform=2.0 if rid=='arena_two' else 0.0
        if rid=='final_arena':
            platform=3.0-y if stage['id']=='occupied_line' else 2.5 if stage['id']=='pale_ward' else 4.0
            x-=7
        sc.cylinder('CachePedestal_'+rid,(x,y+platform+.15,z),.8,.125,'panel',False)
        sc.pickup('Bait_'+rid,spec['weapon'],(x,y+platform+.65,z),spec['ammo'])
        for index,node in enumerate(sc.nodes):
            if node.startswith('[node name="Bait_'+rid+'" '): sc.nodes[index]=node.rstrip()+'\nmetadata/bait_arena = '+quote(rid)+'\n\n'
        sc.downlight('CacheLight_'+rid,(x,y+r['size'][1]-.5,z),7,14)
    for rid,kind,amount in [('spine','rockets',2),('key_wing','rivets',48)]:
        r=rooms[rid];x,y,z=r['center'];sc.pickup('V2Supply_'+rid,kind,(x,y+.5,z),amount)
    for b in stage['buttons']:
        r=rooms[b['room']];x,y,z=r['center'];pp=(x+4.5,y+1.05,z-r['size'][2]/2+3)
        sc.box('Button_'+b['id'],pp,(1.1,1.5,.5),'steel',extra='metadata/stage_button = '+quote(b['sets'])+'\nmetadata/requires = '+arr(['clear_'+b['arena']])+'\nmetadata/locked_message = "Clear this arena to enable its control"\nmetadata/label = '+quote(b['label'])+'\nmetadata/activated_message = '+quote(b['label']+' · engaged'))
        sc.box('Face',(0,.12,.29),(.55,.48,.08),'brass' if b['id']=='breaker' else 'red' if b['id']=='release' else 'glow',False,'Button_'+b['id'])
        sc.label('Mark',b['label'],(0,1.1,.28),'Button_'+b['id'],size=30)
    for k in stage['keys']:
        r=rooms[k['room']];x,y,z=r['center'];sc.pickup('Key_'+k['id'],k['id'],(x,y+.6,z-3))
    # Required-route supplies match coordinator totals, independent of secrets.
    supply_rooms=['entry','service','arena_one','key_wing','key_console','return_store','spine','arena_two','red_wing','red_console','final_arena']
    budgets={'shells':stage['supplies']['main_route_shells'],'pistol':stage['supplies']['main_route_pistol'],'health':stage['supplies']['main_route_health'],'armor':stage['supplies']['main_route_armor']}
    for kind,total in budgets.items():
        for index,rid in enumerate(supply_rooms):
            amount=total//len(supply_rooms)+(1 if index<total%len(supply_rooms) else 0);r=rooms[rid];x,y,z=r['center'];k=list(budgets).index(kind)
            sc.pickup('Supply_'+kind+'_'+rid,kind,(x+(-.8 if k%2==0 else .8),y+.5,z+r['size'][2]/2-3-k//2*1.2),amount)
    for rid in optional+['secret_one','secret_two']:
        r=rooms[rid];x,y,z=r['center'];sc.pickup('Bonus_'+rid,'shells',(x,y+.5,z),12);sc.pickup('BonusHealth_'+rid,'health',(x+1,y+.5,z),25)
    r=rooms[stage['exit']['room']];x,y,z=r['center'];sc.box('ExitControl',(x,y+1.05,z-r['size'][2]/2+2),(1.5,1.8,.5),'glow',extra='metadata/stage_exit = true\nmetadata/requires = '+arr(stage['exit']['requires'])+'\nmetadata/locked_message = "Both access keys and exit control required"')
    sc.label('ExitMark','EXIT',(0,1.3,.29),'ExitControl',size=55)
    r=rooms[stage['spawn_room']];spawn=[r['center'][k]+stage['spawn_local'][k] for k in range(3)]
    sc.node('Player','CharacterBody3D',props='position = '+vec(spawn)+'\nscript = ExtResource("player")\ncollision_layer = 2\ncollision_mask = 3\nfloor_snap_length = .25\n')
    sc.node('CollisionShape3D','CollisionShape3D','Player','shape = SubResource("player_shape")')
    sc.node('Camera3D','Camera3D','Player','position = Vector3(0,.68,0)\ncurrent = true\nfov = 82\nnear = .04\nfar = 700')
    sc.marker('PlayerStart',spawn,'')
    sc.save(contract['scene'].removeprefix('res://'))
    (P/'resources/stages'/f'{stage["id"]}-route.json').write_text(json.dumps(dict(id=stage['id'],architecture_version=2,rooms=rooms,portals=routes,buttons=stage['buttons'],keys=stage['keys'],exit=stage['exit'],weapon_cache=stage['weapon_cache'],vertical_routes=sc.vertical_routes,combat_paths=sc.combat_paths),indent=2))
def closet(sc,r,side,slot,px,pz):
    y=r['center'][1];rid=r['id'];name='Closet_'+rid+'_'+str(side)+'_'+str(slot)
    # Actors exist behind an opaque physical shutter before the lure is collected.
    front=px-side*2.0
    sc.box(name+'_Back',(px+side*1.7,y+2.4,pz),(.3,4.8,4.4),'damaged')
    for end in [-1,1]:sc.box(name+'_Side'+str(end),(px,y+2.4,pz+end*2.2),(3.8,4.8,.3),'wall')
    sc.box(name+'_Roof',(px,y+4.95,pz),(4.1,.3,4.6),'ceiling')
    sc.box(name+'_Shutter',(front,y+2.4,pz),(.3,4.8,4.4),'door_skin',typ='AnimatableBody3D',extra='script = ExtResource("door")\nmetadata/trap_shutter = '+quote(rid)+'\nmetadata/open_offset = Vector3(0,6,0)')

def architecture(sc,stage,r):
    x,y,z=r['center'];sx,h,sz=r['size'];rid=r['id'];theme=stage['id']
    if not hasattr(sc,'vertical_routes'):sc.vertical_routes={};sc.combat_paths={}
    # Clipped diagonal masses replace four square corners. Shared native polygons
    # build mesh/collision from the exact same six prism vertices at runtime.
    c=r.get('chamfer',2)
    for xx in [-1,1]:
        for zz in [-1,1]:sc.prism(rid+'_Chamfer'+str(xx)+str(zz),(x+xx*sx/2,y,z+zz*sz/2),[(0,0),(-xx*c,0),(0,-zz*c)],h,'pillar')
    # Off-axis polygon plinths provide two spacious paths around central cover.
    for side in [-1,1]:
        sc.prism(rid+'_AngularCover'+str(side),(x+side*9,y,z+6),[(-1.8,-2),(1.3,-2.8),(2,1.4),(-.8,2.4)],1.3,'damaged')
    sc.combat_paths[rid]=[[[x-4.3,y,z+10],[x-4.3,y,z-10]],[[x+4.3,y,z+10],[x+4.3,y,z-10]]]
    # Altar/bridge has stairs at both ends and a full ring below for retreat.
    if rid=='arena_two':
        sc.prism(rid+'_RaisedAltar',(x,y,z),[(-3,-4),(-2,-5),(2,-5),(3,-4),(3,4),(2,5),(-2,5),(-3,4)],2,'floor')
        sc.stairs(rid+'_AltarSouth',[x,y,z+13],[x,y+2,z+5],4)
        sc.stairs(rid+'_AltarNorth',[x,y,z-13],[x,y+2,z-5],4)
        sc.vertical_routes[rid+'_altar']=[[x,y,z+13],[x,y+2,z+5],[x,y+2,z],[x,y+2,z-5],[x,y,z-13]]
    # Long accessible balcony with two stair approaches; clearance below 3m deck.
    elevation=(3.0-y if theme=='occupied_line' else 2.5 if theme=='pale_ward' else 4.0)
    bx=x-7;length=min(sz*.38,sz-2*elevation*3.6-4);deck_y=y+elevation
    sc.box(rid+'_GalleryDeck',(bx,deck_y-.18,z),(3.6,.36,length),'grate')
    for sign in [-1,1]:
        sc.stairs(rid+'_GalleryStairs'+str(sign),[bx,y,z+sign*(length/2+elevation*3.6)],[bx,deck_y,z+sign*length/2],3.6)
    sc.vertical_routes[rid+'_gallery']=[[bx,y,z+length/2+elevation*3.6],[bx,deck_y,z+length/2],[bx,deck_y,z-length/2],[bx,y,z-length/2-elevation*3.6]]
    if theme=='pale_ward' and rid=='arena_one':
        # Rim circuit has solid decking, joins the gallery and two broad stairs.
        sc.box(rid+'_EastRim',(x+7,deck_y-.18,z),(3.6,.36,length),'grate')
        for end in [-1,1]:
            sc.box(rid+'_RimCrossing'+str(end),(x,deck_y-.18,z+end*(length/2-1.8)),(14,.36,3.6),'grate')
            sc.stairs(rid+'_EastRimStairs'+str(end),[x+7,y,z+end*(length/2+elevation*3.6)],[x+7,deck_y,z+end*length/2],3.6)
        sc.vertical_routes[rid+'_rim']=[[x+7,y,z+length/2+elevation*3.6],[x+7,deck_y,z+length/2],[x-7,deck_y,z+length/2-1.8],[x-7,deck_y,z-length/2+1.8],[x+7,deck_y,z-length/2+1.8]]
    # Floor inset zoning has a solid supporting slab directly underneath.
    sc.box(rid+'_InsetZone',(x,y+.008,z),(sx*.58,.016,sz*.72),'grate' if theme!='ash_citadel' else 'damaged',False)
    if theme=='pale_ward':
        for row,pz in enumerate([z-8,z+8]):
            for side in [-1,1]:sc.box(rid+'_AngledFeed'+str(row)+str(side),(x+side*5,y+h-1,pz),(.35,.35,12),'steel',rot=(0,side*20,0))
        if rid!='arena_one': sc.box(rid+'_CultureSumpSurface',(x+8,y+.018,z-6),(4,.02,5),'invasion',False)
    elif theme=='ash_citadel':
        for row,pz in enumerate([z-12,z+12]):
            for side in [-1,1]:
                sc.prism(rid+'_VaultRib'+str(row)+str(side),(x+side*9,y+6,pz),[(-side*1.2,-.6),(side*.9,-.6),(side*2,.6),(-side*1.8,.6)],h-6,'pillar')
                sc.box(rid+'_VaultArch'+str(row)+str(side),(x+side*5,y+h-1.6,pz),(11,.8,1),'wall',rot=(0,0,side*24))
                sc.box(rid+'_Banner'+str(row)+str(side),(x+side*(sx/2-.4),y+7,pz),(.06,3.8,2.2),'banner',False)
                sc.light(rid+'_Ember'+str(row)+str(side),(x+side*10,y+2,pz),(1,.24,.03,1),3,16)
    else:
        for side in [-1,1]:sc.daylight_band(rid+'_UpperDaylight'+str(side),(x+side*(sx/2-.24),y+h-1,z),(.04,1.3,sz-3),2,-side)
        # Overhead crossing shares the gallery level; no solid low ceiling below.
        sc.box(rid+'_Crossing',(x,deck_y-.18,z),(18,.36,3.2),'grate')
        for side in [-1,1]:sc.box(rid+'_Track'+str(side),(x+side*1.8,y+.09,z),(.12,.18,sz-3),'steel')
    sc.light('V2Light_'+rid,(x,y+5,z),( .72,.80,.62,1) if theme=='pale_ward' else (1,.45,.16,1) if theme=='ash_citadel' else (.52,.73,.92,1),3,25)

def decorate(sc,stage,r):
    x,y,z=r['center'];sx,h,sz=r['size'];rid=r['id'];theme=stage['id']
    if theme=='pale_ward':
        # Broad stairs and asymmetric containment piers retain the entry silhouette.
        for side in [-1,1]:
            px=x+side*(sx/2-4);pz=z-4 if side==1 else z+2
            sc.box(rid+'_Pier'+str(side),(px,y+h/2,pz),(1.8,h,1.6),'wall')
            for band in [1.1,h-1]:sc.box(rid+'_PierBand'+str(side)+str(band),(px,y+band,pz+.84),(2,.2,.12),'steel')
            for k in range(3):
                pz=z-sz/2+4+k*(sz-8)/2;px=x+side*(sx/2-1.9)
                if any(lo-1.5 <= pz <= hi+1.5 for lo,hi in sc.openings[rid]['E' if side>0 else 'W']): continue
                sc.cylinder(rid+'_TankCase'+str(side)+str(k),(px,y+1.8,pz),.625,3.6,'glass')
                sc.node(rid+'_Specimen'+str(side)+str(k),'Sprite3D',props='position = '+vec((px,y+1.85,pz))+'\ntexture = SubResource("specimen")\npixel_size = .0045\nbillboard = 1\nmodulate = Color(.21,.23,.14,1)\nshaded = true\nalpha_cut = 1\ntexture_filter = 0')
                for band in [.2,3.5]:sc.cylinder(rid+'_TankBand'+str(side)+str(k)+str(band),(px,y+band,pz),.75,.25,'steel')
                for off in [-.62,.62]:sc.box(rid+'_TankStrut'+str(side)+str(k)+str(off),(px+off,y+1.8,pz+.67),(.12,3.2,.15),'steel')
        for k in [-2,-1,2]:sc.box(rid+'_OverheadFeed'+str(k),(x+k,y+h-.4,z),(.2,.22,sz),'steel')
        if rid=='entry':
            for row,pz in enumerate([z-10,z-2,z+6,z+13]):
                sc.box('EntryRoofRib'+str(row),(x,y+h-.3,pz),(sx,.45,.65),'steel')
                for side in [-1,1]:
                    px=x+side*5.8
                    sc.box('EntryLampHousing'+str(row)+str(side),(px,y+h-.62,pz),(1.8,.20,.6),'recess',False)
                    sc.box('EntryLampFace'+str(row)+str(side),(px,y+h-.76,pz),(1.5,.06,.43),'glow',False)
                    sc.downlight('EntryDownlight'+str(row)+str(side),(px,y+h-.85,pz),3.2,13)
                sc.box('EntryConduitBrace'+str(row),(x-1.3,y+h-.68,pz),(3.9,.13,.25),'steel',False)
            for k,px in enumerate([x-3.5,x-2.9,x+3.2]):
                name='EntryCylinderFeed'+str(k);sc.cylinder(name,(px,y+h-.78,z),.20 if k==2 else .13,sz,'steel')
                sc.nodes[-3]=sc.nodes[-3].replace('\nposition = ', '\nrotation_degrees = Vector3(90,0,0)\nposition = ',1)
            sc.box('EntryOverheadDuct',(x-5.2,y+h-1.05,z),(1.0,.6,sz),'steel')
            for row,pz in enumerate([-12,-4,4,12]):sc.box('EntryDuctBand'+str(row),(x-5.2,y+h-1.05,pz),(1.1,.73,.22),'recess',False)
            for side,pz in [(-1,1.0),(1,-1.2)]:
                px=x+side*6.1
                sc.box('EntryInstrumentPier'+str(side),(px,y+h/2,pz),(1.6,h,1.6),'wall')
                sc.box('EntryInstrumentFoot'+str(side),(px,y+.4,pz),(1.9,.8,1.9),'steel')
                sc.box('EntryInstrumentGauge'+str(side),(px,y+.9,pz+.86),(.65,.55,.16),'steel')
                sc.box('EntryInstrumentGlow'+str(side),(px,y+1.0,pz+.96),(.45,.06,.03),'glow',False)
            sc.sign('OriginalC3',stage['board'],(356,124,130,82),(x-8,y+3.1,z+2.86),(1.3,.82))
            sc.sign('OriginalBio',stage['board'],(972,150,90,85),(x+8,y+3.1,z-3.14),(1.1,1.04))
    elif theme=='ash_citadel':
        # Paired massive masonry ribs and elevated braziers make stone courts.
        for row,pz in enumerate([z-sz*.28,z+sz*.25]):
            for side in [-1,1]:
                px=x+side*(sx/2-3)
                sc.box(rid+'_Buttress'+str(row)+str(side),(px,y+h*.42,pz),(2.1,h*.84,2.8),'wall')
                sc.box(rid+'_StoneFoot'+str(row)+str(side),(px,y+.65,pz),(3.2,1.3,3.8),'wall')
                sc.box(rid+'_ArchSpring'+str(row)+str(side),(x+side*sx*.20,y+h-.9,pz),(sx*.40,.8,1.5),'wall',rot=(0,0,side*12))
                sc.box(rid+'_Banner'+str(row)+str(side),(px-side*1.15,y+h*.63,pz+1.45),(1.45,h*.40,.045),'invasion',False)
                sc.box(rid+'_BannerTear'+str(row)+str(side),(px-side*1.5,y+h*.35,pz+1.48),(.5,.7,.04),'cloth',False,rot=(0,0,12))
            sc.box(rid+'_ArchKey'+str(row),(x,y+h-.3,pz),(1.4,.8,1.65),'wall')
        for side in [-1,1]:
            px=x+side*(sx/2-5);pz=z-sz/2+6
            for k in range(4):sc.box(rid+'_BrazierStep'+str(side)+str(k),(px,y+(k+1)*.11,pz),(3.4-k*.4,.22,3.4-k*.4),'wall')
            sc.box(rid+'_Brazier'+str(side),(px,y+1.15,pz),(1.5,1.2,1.5),'steel')
            sc.box(rid+'_Coals'+str(side),(px,y+1.83,pz),(1.4,.18,1.4),'glow',False)
            sc.light(rid+'_Fire'+str(side),(px,y+2.3,pz),(1,.23,.025,1),3,12)
        # Cage bars sit at perimeter, leaving all authored route portals clear.
        for side in [-1,1]:
            for bar in range(7):
                if any(lo-.5 <= z-3+bar <= hi+.5 for lo,hi in sc.openings[rid]['E' if side>0 else 'W']): continue
                sc.box(rid+'_Cage'+str(side)+str(bar),(x+side*(sx/2-1),y+1.7,z-3+bar),(.12,3.4,.12),'steel')
            sc.box(rid+'_CageRail'+str(side),(x+side*(sx/2-1),y+3.45,z),( .2,.2,6.4),'steel')
        if rid=='entry':
            for side in [-1,1]:
                for k in range(12):
                    sh=(k+1)*.125;sc.box(rid+'_ProcessionStep'+str(side)+str(k),(x+side*7,y+sh/2,z-sz/2+7-(k+.5)*.4),(4.8,sh,.4),'wall',extra='metadata/stage_step = true')
    else:
        # Civic square piers, daylight clerestories, platforms and infestation.
        for row,pz in enumerate([z-sz*.25,z+sz*.22]):
            for side in [-1,1]:
                px=x+side*(sx/2-4)
                sc.box(rid+'_TilePier'+str(row)+str(side),(px,y+h/2,pz),(2,h,2),'steel')
                sc.box(rid+'_PierCap'+str(row)+str(side),(px,y+h-.3,pz),(2.5,.45,2.5),'wall')
                for band in [1.2,3.8]:sc.box(rid+'_RouteBand'+str(row)+str(side)+str(band),(px,y+band,pz+1.03),(2.05,.19,.035),'orange',False)
                sc.label(rid+'_PlatformMark'+str(row)+str(side),'P / '+str(row+1),(px,y+2.9,pz+1.05),size=35)
                for cable in range(3):
                    sc.box(rid+'_Cable'+str(row)+str(side)+str(cable),(px+(.4-cable*.35),y+2.3,pz-1.08),(.19,4,.18),'invasion',False,rot=(0,0,12-cable*10))
                sc.box(rid+'_Node'+str(row)+str(side),(px,y+2.3,pz-1.21),(.5,.6,.16),'glow',False)
        for side in [-1,1]:
            sc.daylight_band(rid+'_DaylightBand'+str(side),(x+side*(sx/2-.24),y+h-1,z),(.04,.9,sz-2),2,-side)
            # Substantial visible platform edges and raised bays lie off route.
            pp=x+side*(sx/2-2.2)
            segments=[];cursor=z-sz*.275;finish=z+sz*.275
            for lo,hi in sorted(sc.openings[rid]['E' if side>0 else 'W'])+[(finish,finish)]:
                lo=max(cursor,min(finish,lo-1.2));hi=min(finish,hi+1.2)
                if lo>cursor:segments.append((cursor,lo))
                cursor=max(cursor,hi)
            for index,(lo,hi) in enumerate(segments):
                sc.box(rid+'_Platform'+str(side)+str(index),(pp,y+.20,(lo+hi)/2),(3.2,.4,hi-lo),'wall')
                sc.box(rid+'_Rail'+str(side)+str(index),(pp,y+.51,(lo+hi)/2),(.13,.17,hi-lo),'steel')
            for stripe in range(14):
                zz=z-sz*.25+stripe*sz*.035
                if any(lo-.6 <= zz <= hi+.6 for lo,hi in sc.openings[rid]['E' if side>0 else 'W']):continue
                sc.box(rid+'_Hazard'+str(side)+str(stripe),(pp-side*1.62,y+.43,zz),(.12,.025,.55),'orange',False)
        if rid=='entry':
            for side in [-1,1]:
                for k in range(12):
                    sh=(k+1)*.125;sc.box(rid+'_PlatformStep'+str(side)+str(k),(x+side*7,y+sh/2,z-sz/2+7-(k+.5)*.4),(4.6,sh,.4),'wall',extra='metadata/stage_step = true')

if __name__=='__main__':
    layouts=json.loads((P/'docs/expansion-v1/layouts.json').read_text())
    contract=json.loads((P/'docs/expansion-v1/contract.json').read_text())
    for stage in layouts['stages']:
        accepted=next(s for s in contract['stages'] if s['id']==stage['id'])
        author(stage,accepted)
        print(stage['id'],len(stage['rooms']),sum(stage['enemy_counts'].values()))
