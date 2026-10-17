#!/usr/bin/env python3
"""Selected Ward author: exact v13 room graphs, physical primitives, reused art.

No template stage transformation, fallback placement or writes to other maps.
Run --level pale_ward_01 first; review its actual native geometry before the rest.
"""
from __future__ import annotations
import argparse
from copy import deepcopy
import hashlib
import json
import math
from pathlib import Path
import re

import author_themed_stages as base
import room_program_v6 as props
import room_materials_v8 as surfaces
import ward_shell_v14 as shell
import ward_environment_v19

ROOT=Path(__file__).resolve().parents[1]
INPUT=ROOT/'docs/level-redesign-v13/levels.json'
WARD=('pale_ward_01','pale_ward_02','pale_ward_03')
CAPS={'pistol':96,'shells':40,'rivets':160,'rockets':12}
WEAPON_AMMO={'twin_shotgun':'shells','rivet_cannon':'rivets','siege_launcher':'rockets'}
vec,quote,arr=base.vec,base.quote,base.arr


def family(room):
    return 'surgery' if room['function'] in {'surgery','diagnostics','medical_stores'} else 'utility' if room['function'] in {'utility','reservoir','specimen_silo','decontamination','security'} else 'triage'


def load_level(level_id,path=INPUT):
    assert level_id in WARD
    level=next(deepcopy(x) for x in json.loads(Path(path).read_text())['levels'] if x['id']==level_id)
    rooms={r['id']:r for r in level['rooms']}
    assert len(rooms)==len(level['rooms']) and sum(r['enemies'] for r in rooms.values())==level['enemy_total']
    assert len({r['district'] for r in rooms.values()})==4
    assert len(level['optional_rooms'])>=4 and len(level['secret_rooms'])==2
    assert sum(bool(p['shortcut']) for p in level['portals'])>=2
    assert len({r['center'][1] for r in rooms.values()})>=3
    for room in rooms.values():
        assert all(n>0 for n in room['size'])
        for obj in room['objects']:assert obj['type'] in props.SHAPES,(level_id,obj['type'],'unapproved prop alias')
    return level


class WardScene(base.Scene):
    def __init__(self,level):
        super().__init__({'id':'pale_ward','campaign_level_id':level['id'],'title':level['title']})
        self.level=level;self.geometry=[];self.lights=[];self.fittings=[];self.shell_fits=[];self.shell_room=None
        self.ext.extend([
          '[ext_resource type="Script" path="res://scripts/stage_objective_profile.gd" id="v13_profile_script"]',
          f'[ext_resource type="Resource" path="res://resources/campaign/v13/{level["id"]}-objectives.tres" id="v13_profile"]',
          '[ext_resource type="PackedScene" path="res://scenes/fixtures/intake_light_v11.tscn" id="v13_fixture"]',
          '[ext_resource type="Script" path="res://scripts/lift_landing_gate.gd" id="lift_gate"]'])
        sources=surfaces._native_sources(surfaces._manifest())
        self.materials={f:{role:surfaces.register_material(self,f,role,source) for role in surfaces.ROLES} for f,source in sources.items()}
        # Generic prop/lift APIs use these semantic names; all aliases keep full
        # native world-projected side/top/underside texels on closed boxes.
        aliases={'wall':'wall','floor':'floor','ceiling':'ceiling','steel':'trim','grate':'floor','stairs':'floor','panel':'panel','door_skin':'door','cloth':'panel','glass':'panel','invasion':'panel','orange':'panel','pillar':'wall','damaged':'wall','banner':'panel'}
        for alias,role in aliases.items():
            source=next(s for s in self.sub if s.startswith(f'[sub_resource type="ShaderMaterial" id="v8_utility_{role}"]'))
            self.sub.append(source.replace(f'id="v8_utility_{role}"',f'id="{alias}"',1))
        self.mat('glow',(.77,.79,.62,1),1.2)
        if level['id']=='pale_ward_02':
            self.mat('v16_filter_signal',(.32,.68,.20,1),.35)
            self.mat('v16_pipe_signal',(.85,.43,.12,1),.35)
        self.mat('v13_checkpoint_inset',(.08,.25,.19,1),.08)
        self.mat('v13_liquid',(.13,.24,.08,.78));self.sub[-1]+='transparency = 1\nroughness = 0.24\ncull_mode = 2\n'
        self.board_material('v13_invasion','res://assets/materials/architecture-v2/pale_ward-atlas.png',[384,682,384,341])
        self.mat('v13_glass',(.26,.48,.25,.30));self.sub[-1]+='transparency = 1\nroughness = 0.22\ncull_mode = 2\n'
        if level['id']=='pale_ward_03':
            self.mat('v13_vista_glass',(.66,.74,.66,.12));self.sub[-1]+='transparency = 1\nroughness = 0.22\ncull_mode = 2\n'
        self.ext.append('[ext_resource type="Texture2D" path="res://assets/enemies/board-sprites/unsealed-atlas.png" id="v13_specimen_source"]')
        self.sub.append('[sub_resource type="AtlasTexture" id="v13_specimen"]\natlas = ExtResource("v13_specimen_source")\nregion = Rect2(0,0,384,512)\nfilter_clip = true\n')
        self.ext.extend(['[ext_resource type="Shader" path="res://shaders/equipment_surface_v9.gdshader" id="v13_equipment_shader"]','[ext_resource type="Script" path="res://scripts/control_presentation_v9.gd" id="v13_control_presentation"]'])
        self.equipment={}
        for f,source in sources.items():
            self.equipment[f]={}
            for mode,index in [('control',2),('exit',3)]:
                ident='v13_'+f+'_'+mode;self.equipment[f][mode]=ident
                fields=''.join('shader_parameter/'+key+' = Vector4('+', '.join(map(str,source['regions'][role]))+')\n' for key,role in [('trim_region','trim'),('face_region','door' if mode=='exit' else 'panel'),('floor_region','floor')])
                self.sub.append('[sub_resource type="ShaderMaterial" id="'+ident+'"]\nshader = ExtResource("v13_equipment_shader")\nshader_parameter/painted_surface = ExtResource("v8_source_'+f+'")\n'+fields+'shader_parameter/pixels_per_metre = 64.0\nshader_parameter/surface_mode = '+str(index)+'\nshader_parameter/local_half_size = Vector3(0.75,0.9,0.25)\n')
        self.prop_materials=props.setup_materials(self,'pale_ward')
        self.sub.append('[sub_resource type="Environment" id="environment"]\nbackground_mode = 1\nbackground_color = Color(0.025,0.025,0.035,1)\nambient_light_source = 2\nambient_light_color = Color(0.53,0.55,0.58,1)\nambient_light_energy = 0.38\ntonemap_mode = 0\n')
        self.node('WorldEnvironment','WorldEnvironment',props='environment = SubResource("environment")')

    def box(self,name,pos,size,mat='wall',solid=True,parent='.',extra='',typ=None,rot=None,hit_material=None):
        room=self.shell_room
        if room and room.get('outline_xz') and parent=='.' and '_Observation' not in name and '_WindowMullion' not in name and '_LoweredCeiling' not in name:
            fit=shell.fit_box(room,pos,size)
            if fit is None:
                self.shell_fits.append({'room':room['id'],'node':name,'action':'omit_shell_trim','old_position':list(pos),'old_size':list(size),'reason':'Named shell fitting crosses actual outline; no gameplay prop removed.'});return
            position,extent=fit
            if position!=list(pos) or extent!=list(size):self.shell_fits.append({'room':room['id'],'node':name,'action':'trim_shell_box','old_position':list(pos),'position':position,'old_size':list(size),'size':extent,'reason':'Fit closed beam/duct/trim to actual outline.'})
            pos,size=position,extent
        assert all(s>0 for s in size),(name,size)
        if hit_material is None and mat.endswith(('_trim','_door','_panel')):hit_material='armor'
        if solid:self.geometry.append({'name':name,'parent':parent,'position':list(pos),'size':list(size),'rotation':list(rot or [0,0,0]),'type':typ or 'StaticBody3D'})
        return super().box(name,pos,size,mat,solid,parent,extra,typ,rot,hit_material)

    def lamp(self,name,position,room,kind='tube',parent='.',rotation=(-90,0,0),damaged=False,energy=None,reach=None):
        if energy is None:energy=2.1 if family(room)=='utility' else 3.8
        if reach is None:reach=max(room['size'][0],room['size'][2])*.85
        color=(.76,.84,.8,1) if family(room)!='utility' else (.85,.76,.59,1)
        if damaged:color=(1,.52,.12,1)
        self.nodes.append(f'[node name="{name}" parent="{parent}" instance=ExtResource("v13_fixture")]\nposition = {vec(position)}\nrotation_degrees = {vec(rotation)}\nfixture_kind = {quote(kind)}\nenergy = {energy}\nreach = {reach}\ncone_angle = 58\nlamp_color = Color({",".join(map(str,color))})\ndamaged = {str(damaged).lower()}\nmetadata/room_id = {quote(room["id"])}\n')
        self.lights.append({'id':name,'room':room['id'],'kind':kind,'position':position,'energy':energy,'damaged':damaged})

    def serialize(self):
        level=self.level
        root=f'[node name="{level["title"].replace(" ","")}V13" type="Node3D"]\nscript = ExtResource("level")\nobjective_profile = ExtResource("v13_profile")\nmetadata/stage_id = "pale_ward"\nmetadata/campaign_level_id = {quote(level["id"])}\nmetadata/stage_title = {quote(level["title"])}\nmetadata/design_version = 13\n'
        if level.get('layout_revision'):root+='metadata/layout_revision = '+str(level['layout_revision'])+'\n'
        text=f'[gd_scene load_steps={len(self.ext)+len(self.sub)+1} format=3]\n\n'+'\n'.join(self.ext)+'\n\n'+'\n'.join(self.sub)+'\n'+root+'\n'+'\n'.join(self.nodes)
        return re.sub(r'(?<![\w])(-?)\.(\d+)',r'\g<1>0.\2',text).rstrip()+'\n'


def mouth(room,target):
    center=room['center'];delta=[target[i]-center[i] for i in range(3)]
    axis=0 if abs(delta[0])>abs(delta[2]) else 2;cross=2 if axis==0 else 0
    assert abs(delta[cross])<.001,(room['id'],target,'first/last corridor leg must align with room center; author explicit bend')
    sign=1 if delta[axis]>0 else -1
    point=list(center);point[axis]+=sign*room['size'][axis]/2
    side=('E' if sign>0 else 'W') if axis==0 else ('S' if sign>0 else 'N')
    return point,axis,sign,side


def doors(sc,p,points,rooms):
    if not (p['requires'] or p['secret'] or p['shortcut'] or p.get('service_door')):return None
    a=rooms[p['from']];start,end=points[0],points[1]
    axis=0 if abs(end[0]-start[0])>abs(end[2]-start[2]) else 2
    sign=1 if end[axis]>start[axis] else -1
    at=list(start);at[axis]-=sign*.35;at[1]=a['center'][1]+1.9
    size=[p['width'],3.8,p['width']];size[axis]=.24
    name='Door_'+p['id']
    extra='script = ExtResource("door")\nmetadata/stage_door = '+quote(p['id'])+'\nmetadata/stable_id = '+quote(sc.level['id']+'.door.'+p['id'])+'\nmetadata/requires = '+arr(p['requires'])+'\nmetadata/open_offset = Vector3(0,5,0)\nmetadata/use_anchor = Vector3(0,-1,0)\nmetadata/label = '+quote('release shortcut' if p['shortcut'] else 'inspect damaged wall panel' if p['secret'] else 'open containment bulkhead' if p.get('service_door') else 'open access gate')+'\nmetadata/locked_message = '+quote('Complete the marked objective to release this gate')
    if p['secret']:extra+='\nmetadata/secret = true'
    if p['shortcut']:extra+='\nmetadata/shortcut = true'
    if p.get('first_open_from'):
        normal=[0,0,0];normal[axis]=sign if p['first_open_from']==p['to'] else -sign
        extra+='\nmetadata/first_open_normal = '+vec(normal)
    sc.box(name,at,size,sc.materials[family(a)]['wall' if p['secret'] else 'door'],typ='AnimatableBody3D',extra=extra)
    if p['secret']:
        # These leaves read as worn wall cladding, with a small asymmetric
        # service seam as a clue rather than the usual lit access strips.
        for face in [-1,1]:
            pp=[0,.55,0];pp[axis]=face*.137;pp[2 if axis==0 else 0]=size[2 if axis==0 else 0]*.27
            ss=[.025,1.0,.025];ss[axis]=.025
            sc.box('DamagedSeam'+str(face),pp,ss,'recess',False,name)
    else:
        for face in [-1,1]:
            pp=[0,.1,0];pp[axis]=face*.135;ss=[1.3,.12,1.3];ss[axis]=.025
            sc.box('AccessStrip'+str(face),pp,ss,'brass' if p['requires'] else 'glow',False,name)
    return name


def lift(sc,name,start,end,width):
    axis=0 if abs(end[0]-start[0])>abs(end[2]-start[2]) else 2;cross=2 if axis==0 else 0
    assert end[1]>start[1]
    sign=1 if end[axis]>start[axis] else -1;length=abs(end[axis]-start[axis]);rise=end[1]-start[1]
    deck=list(end);deck[axis]-=sign*2;deck[1]=start[1]-.15
    approach=list(start);approach[axis]+=sign*(length-4)/2;approach[1]-=.25
    ss=[width,.5,width];ss[axis]=length-4+.12;sc.box(name+'_Approach',approach,ss,'floor')
    ss=[width+.1,.5,width+.1];ss[axis]=4.1;pp=list(deck);pp[1]=start[1]-.55;sc.box(name+'_ShaftBase',pp,ss,'floor')
    pp=list(deck);pp[axis]-=sign*1.75;pp[1]=start[1]-.225;ss=[width,.15,width];ss[axis]=.5;sc.box(name+'_EmergencyTread',pp,ss,'stairs',extra='metadata/stage_step = true')
    pp=list(end);pp[axis]+=sign*.15;pp[1]=(start[1]-.3+end[1])/2;ss=[width+.1,rise+.3,width+.1];ss[axis]=.3;sc.box(name+'_BackWall',pp,ss,'steel')
    lower=[0,1.1,0];upper=[0,1.1,0];lower[axis]=-sign*2.7;upper[axis]=sign*2.7;lower[cross]=upper[cross]=1.1
    extra='script = ExtResource("lift")\nmetadata/stable_id = '+quote(sc.level['id']+'.'+name)+'\nmetadata/ward_lift = true\nmetadata/requires = '+arr(sc.level['exit']['requires'])+'\nmetadata/lift_offset = '+vec((0,rise,0))+'\nmetadata/use_anchor = Vector3(0,1,0)\nmetadata/lower_use_anchor = '+vec(lower)+'\nmetadata/upper_use_anchor = '+vec(upper)
    sc.box(name,deck,(4,.3,4),'steel',typ='AnimatableBody3D',extra=extra)
    for label,side,landing in [('Lower',-1,start[1]),('Upper',1,end[1])]:
        pp=list(deck);pp[axis]+=sign*side*2;pp[1]=landing+.7;ss=[width,1.4,width];ss[axis]=.18
        sc.box(name+'_'+label+'Gate',pp,ss,'steel',extra='script = ExtResource("lift_gate")\nmetadata/lift_target = NodePath("../'+name+'")\nmetadata/landing_height = '+str(landing))
        plate=list(deck);plate[axis]+=sign*side*2.7;plate[cross]+=1.1;plate[1]=landing+1.1
        sc.box(name+'_'+label+'Call',plate,(.12,.65,.55) if axis==0 else (.55,.65,.12),'panel',False)
        sc.label(name+'_'+label+'Sign','E  CALL TRANSFER LIFT',(plate[0],plate[1]+.65,plate[2]),rotation=(0,90,0) if axis==0 else (0,0,0),size=24)
    return {'node':name,'deck':deck,'lower_floor':start[1],'upper_floor':end[1],'axis':axis,'sign':sign,'lower_call':[deck[i]+lower[i] for i in range(3)],'upper_call':[deck[i]+upper[i]+(rise if i==1 else 0) for i in range(3)]}


def build_portals(sc,rooms):
    cuts={rid:{side:[] for side in ['N','S','E','W']} for rid in rooms}
    routes=[]
    for p in sc.level['portals']:
        p=deepcopy(p);a,b=rooms[p['from']],rooms[p['to']];middle=p.get('waypoints',[])
        structural=next((s for s in sc.level.get('structural_connections',[]) if s.get('portal')==p['id']),None)
        start,axis,sign,aside=mouth(a,middle[0] if middle else b['center']);end,_,_,bside=mouth(b,middle[-1] if middle else a['center'])
        points=[start]+deepcopy(middle)+[end]
        if p.get('bridge'):
            for room in rooms.values():
                if room['id'] in [a['id'],b['id']]:continue
                for first,last in zip(points,points[1:]):
                    leg_axis=0 if abs(last[0]-first[0])>abs(last[2]-first[2]) else 2;cross=2 if leg_axis==0 else 0
                    for sign_ in [-1,1]:
                        plane=room['center'][leg_axis]+sign_*room['size'][leg_axis]/2
                        t=(plane-first[leg_axis])/(last[leg_axis]-first[leg_axis])
                        if not 0<t<1:continue
                        value=first[cross]+t*(last[cross]-first[cross]);floor=first[1]+t*(last[1]-first[1])
                        if abs(value-room['center'][cross])<room['size'][cross]/2:
                            side_=('E' if sign_>0 else 'W') if leg_axis==0 else ('S' if sign_>0 else 'N')
                            cuts[room['id']][side_].append((value-p['width']/2-.08,value+p['width']/2+.08,floor-.15,min(floor+3.8,room['center'][1]+room['size'][1])))
        cuts[a['id']][aside].append((start[2 if axis==0 else 0]-p['width']/2,start[2 if axis==0 else 0]+p['width']/2,start[1],start[1]+3.8))
        end_axis=0 if bside in ['E','W'] else 2
        cuts[b['id']][bside].append((end[2 if end_axis==0 else 0]-p['width']/2,end[2 if end_axis==0 else 0]+p['width']/2,end[1],end[1]+3.8))
        for i,(first,last) in enumerate(zip(points,points[1:])):
            if structural:continue # Authored shared volume replaces this closed corridor.
            name='Link_'+p['id']+'_'+str(i);dx,dz=last[0]-first[0],last[2]-first[2]
            axis=0 if abs(dx)>abs(dz) else 2;cross=2 if axis==0 else 0
            assert abs(last[cross]-first[cross])<.001,(p['id'],first,last,'orthogonal authored legs required')
            length=abs(last[axis]-first[axis]);assert length>0
            center=[(first[k]+last[k])/2 for k in range(3)];width=p['width'];rise=last[1]-first[1]
            ss=[width+.12,.5,width+.12];ss[axis]=length+.12
            if p.get('lift'):
                p['lift_data']=lift(sc,'Lift_'+p['id'],first,last,width)
            elif abs(rise)>.001:
                low,high=(first,last) if rise>0 else (last,first)
                sc.stairs(name+'_Step_',low,high,width+.12,sc.materials[family(a)]['floor'])
            else:sc.box(name+'_Floor',(center[0],center[1]-.25,center[2]),ss,sc.materials[family(a)]['floor'])
            # Physical overlap at both mouths removes subcentimetre seams.
            if not p.get('lift'):
                for label,point in [('A',first),('B',last)]:
                    ss2=[width+.12,.5,width+.12];ss2[axis]=.35
                    sc.box(name+'_Landing'+label,(point[0],point[1]-.25,point[2]),ss2,sc.materials[family(a)]['floor'],extra='metadata/stage_step = true')
            if not p.get('bridge'):
                h=4.8;roof=list(center);roof[1]=max(first[1],last[1])+h+.15;ss=[width+.8,.3,width+.8];ss[axis]=length+.12;sc.box(name+'_Roof',roof,ss,sc.materials[family(a)]['ceiling'])
                for side in [-1,1]:
                    pp=list(center);pp[cross]+=side*(width/2+.2);pp[1]=min(first[1],last[1])+(h+abs(rise))/2
                    size=[.4,h+abs(rise),.4];size[axis]=length
                    sc.box(name+'_Wall'+str(side),pp,size,sc.materials[family(a)]['wall'])
            else:
                # Bridge volume is closed; fixed solid guardrails make jumping
                # unnecessary and prevent entering the undrained basin below.
                segments=max(1,math.ceil(abs(rise)/.125))
                for side in [-1,1]:
                    for step in range(segments):
                        t=(step+.5)/segments;pp=[first[k]+t*(last[k]-first[k]) for k in range(3)];pp[cross]+=side*(width/2+.09);pp[1]+=1.3/2+.125/2
                        ss=[.18,1.3+.125,.18];ss[axis]=length/segments+.02
                        guard=name+'_Guard'+str(side)+'_'+str(step)
                        sc.box(guard,pp,ss,'v13_vista_glass' if sc.level['id']=='pale_ward_03' else 'v13_glass',hit_material='armor')
                        # The full transparent pane remains the real shot/actor
                        # collider. Thin visible metal framing is cosmetic only.
                        bar_size=list(ss);bar_size[1]=.075
                        for label,yy in [('Foot',-ss[1]/2+.08),('Top',ss[1]/2-.04)]:sc.box(label,(0,yy,0),bar_size,'steel',False,guard)
                        if step%4==0:
                            post=[.07,ss[1],.07];sc.box('Post',(0,0,0),post,'steel',False,guard)
                if p['id']=='cross_feed_bridge' and i==1:
                    for px in [-12,12]:sc.box(name+'_Pier'+str(px),(px,2.75,center[2]),(.8,5.5,.8),'steel')
                    sc.box(name+'_LampBeam',(0,9.05,center[2]),(.2,.18,width+.6),'steel')
                    for side in [-1,1]:sc.box(name+'_LampHanger'+str(side),(0,9.55,center[2]+side*(width/2+.2)),(.08,.9,.08),'steel')
                    sc.lamp(name+'_MountedLamp',(0,8.82,center[2]),a,energy=2.8)
            if p.get('bridge') and sc.level['id']=='pale_ward_03':
                top=min(first[1],last[1]);height=top+4
                for side in [-1,1]:
                    pp=list(center);pp[cross]+=side*(width/2-.3);pp[1]=-4+height/2
                    sc.box(name+'_ShaftSupport'+str(side),pp,(.5,height,.5),'steel')
            if i==0 and not p.get('bridge'):sc.lamp(name+'_Fixture',(center[0],max(first[1],last[1])+4.62,center[2]),a,energy=1.6)
        p['door']=doors(sc,p,points,rooms)
        if p['to'] in sc.level['encounters'] and sc.level['encounters'][p['to']].get('seal'):
            at=list(end);last_axis=end_axis;direction=1 if end[last_axis]>points[-2][last_axis] else -1;at[last_axis]+=direction*.2;at[1]+=1.9;ss=[p['width'],3.8,p['width']];ss[last_axis]=.24
            normal=[0,0,0];normal[last_axis]=direction
            name='TrapEntry_'+p['to'];sc.box(name,at,ss,sc.materials[family(b)]['door'],typ='AnimatableBody3D',extra='script = ExtResource("door")\nmetadata/stable_id = '+quote(sc.level['id']+'.'+name)+'\nmetadata/trap_entry = '+quote(p['to'])+'\nmetadata/initially_open = true\nmetadata/open_offset = Vector3(0,5,0)\nmetadata/entry_normal = '+vec(normal)+'\nmetadata/entry_threshold = '+vec(end));p['trap_entry']=name
        for i,point in enumerate(points):
            meta='metadata/stage_nav = '+arr([a['id'],b['id']])
            if p['door']:meta+='\nmetadata/stage_nav_door = NodePath("../'+p['door']+'")'
            sc.marker('Nav_'+p['id']+'_'+str(i),point,meta)
        p.update(start=start,end=end,middle=[(start[k]+end[k])/2 for k in range(3)],points=points,traverse_points=[a['center']]+points+[b['center']],axis=axis)
        if structural:
            p['structural_connection']=structural['id']
            p['traverse_points']=structural.get('traverse_points',p['traverse_points'])
        routes.append(p)
    return cuts,routes


def walls(sc,room,cuts):
    x,y,z=room['center'];sx,h,sz=room['size'];m=sc.materials[family(room)]
    if room.get('outline_xz'):
        shell.slab(sc,room,room['id']+'_Floor',-.6,.6,m['floor']);shell.slab(sc,room,room['id']+'_Roof',h,.4,m['ceiling']);shell.walls(sc,room,cuts,m['wall'])
    else:
        sc.box(room['id']+'_Floor',(x,y-.3,z),(sx+.12,.6,sz+.12),m['floor'])
        sc.box(room['id']+'_Roof',(x,y+h+.2,z),(sx+.8,.4,sz+.8),m['ceiling'])
    for side in ([] if room.get('outline_xz') else ['N','S','E','W']):
        axis=0 if side in ['N','S'] else 2;cross=2 if axis==0 else 0;span=room['size'][axis];center=room['center'][axis]
        lo,hi=center-span/2,center+span/2
        openings=cuts[side]
        xs=sorted({lo,hi}|{max(lo,min(hi,v)) for cut in openings for v in cut[:2]})
        ys=sorted({y,y+h}|{max(y,min(y+h,v)) for cut in openings for v in cut[2:]})
        index=0
        for a,b in zip(xs,xs[1:]):
            for low,high in zip(ys,ys[1:]):
                if any(c[0]<(a+b)/2<c[1] and c[2]<(low+high)/2<c[3] for c in openings):continue
                at=[x,(low+high)/2,z];at[axis]=(a+b)/2;at[cross]+=(1 if side in ['S','E'] else -1)*room['size'][cross]/2;size=[.4,high-low,.4];size[axis]=b-a
                sc.box(room['id']+'_Wall_'+side+str(index),at,size,m['wall']);index+=1
    arena=sc.level['encounters'].get(room['id'],{}).get('arena_id','')
    metadata='metadata/stage_room = '+quote(room['id'])+'\nmetadata/stage_label = '+quote(room['label'])+'\nmetadata/room_bounds = '+vec((sx/2,h/2+1,sz/2))+'\nmetadata/district = '+quote(room['district'])+'\nmetadata/room_function = '+quote(room['function'])+'\nmetadata/optional = '+str(room['optional']).lower()+'\nmetadata/arena_id = '+quote(arena)
    if room.get('outline_xz'):metadata+='\nmetadata/footprint_xz = PackedVector2Array('+', '.join(str(v) for point in room['outline_xz'] for v in point)+')'
    sc.marker('Room_'+room['id'],(x,y+h/2,z),metadata)
    sc.label('RoomSign_'+room['id'],room['label'].upper(),(x,y+2.7,z-sz/2+.23),size=32)
    for i,side in enumerate([-1,1]):sc.lamp('Fixture_'+room['id']+'_'+str(i),(x+side*sx*.22,y+(3.22 if room['id']=='reception' and i==0 else ceiling_height(room)-.18),z+side*sz*.21),room)
    if room['id'] in {'maintenance','secret_filter'}:sc.lamp('Warning_'+room['id'],(x+sx/2-.18,y+2.8,z),room,'warning',rotation=(0,90,0),damaged=True,energy=.26)


def architecture_cuts(sc,rooms,cuts):
    for connection in sc.level.get('structural_connections',[]):
        for aperture in connection['apertures']:
            cuts[aperture['room']][aperture['side']].append((*aperture['span'],*aperture['height']))
    for room in rooms.values():
        if room['function'] in {'diagnostics','surgery'}:
            x,y,z=room['center'];lo,hi=shell.observation(room);cuts[room['id']]['E'].append((z+lo,z+hi,y+1.5,y+4.1))


    if sc.level['id']=='pale_ward_02':
        for rid,side in [('overlook','N'),('reservoir','S')]:
            for sign in [-1,1]:
                center=sign*8.5;cuts[rid][side].append((center-4.5,center+4.5,4.4,8.3))


    if sc.level['id']=='pale_ward_03':
        for sign in [-1,1]:
            center=40+sign*8.5;cuts['upper_gallery']['S'].append((center-4.25,center+4.25,9,13.5))


def ceiling_height(room):
    return min(room['size'][1],4.6 if room['function']=='triage_reception' else 5.2 if room['function'] in {'diagnostics','surgery','medical_stores'} else 5.8 if room['function'] not in {'triage_ward','reservoir','specimen_silo'} else room['size'][1])


def pipe(sc,name,at,length,axis,material='steel',radius=.12,parent='.'):
    if sc.shell_room and sc.shell_room.get('outline_xz') and parent=='.':
        size=[radius*2,radius*2,radius*2];size[axis]=length
        fit=shell.fit_box(sc.shell_room,at,size) if axis in [0,2] else (shell.fit_feature(sc.shell_room,at,size),size)
        if fit is None:
            sc.shell_fits.append({'room':sc.shell_room['id'],'node':name,'action':'omit_shell_pipe','reason':'Pipe lies outside actual outline.'});return
        position,extent=fit
        if position!=list(at) or extent[axis]!=length:sc.shell_fits.append({'room':sc.shell_room['id'],'node':name,'action':'fit_shell_pipe','old_position':list(at),'position':position,'old_length':length,'length':extent[axis]})
        at,length=position,extent[axis]
    # Closed cylindrical fittings keep painted ends as well as their sides.
    root=name+'_Mount';rotation=(0,0,90) if axis==0 else (90,0,0) if axis==2 else (0,0,0)
    sc.node(root,props='position = '+vec(at)+'\nrotation_degrees = '+vec(rotation),parent=parent)
    sc.cylinder(name,(0,0,0),radius,length,material,False,root)


def authored_architecture(sc,room):
    x,y,z=room['center'];sx,h,sz=room['size'];rid=room['id'];m=sc.materials[family(room)];ch=ceiling_height(room)
    if ch<h:
        if room.get('outline_xz'):shell.slab(sc,room,rid+'_LoweredCeiling',ch,.24,m['ceiling'])
        else:sc.box(rid+'_LoweredCeiling',(x,y+ch+.12,z),(sx-.4,.24,sz-.4),m['ceiling'])
    # Ductwork and exposed ribs are placed above usable capsule height.
    if room['function']!='triage_ward':
        for side in [-1,1]:
            sc.box(rid+'_Duct'+str(side),(x+side*(sx/2-1.25),y+ch-.55,z),(.7,.55,sz-1.5),m['trim'],False)
            for end in [-1,1]:sc.box(rid+'_DuctFlange'+str(side)+str(end),(x+side*(sx/2-1.25),y+ch-.55,z+end*(sz/2-1.1)),(.84,.68,.13),m['trim'],False)
        for index,zz in enumerate([-sz*.3,sz*.3]):sc.box(rid+'_CeilingRib'+str(index),(x,y+ch-.32,z+zz),(sx-.5,.45,.35),m['trim'])
    if rid=='reception':
        # Admissions counter canopy, service hatch and parallel queue rails.
        sc.box('ReceptionQueueCanopy',(x-7,y+3.5,z-5),(12,.22,6),sc.materials['triage']['panel'])
        for px in [-13,-2]:sc.box('ReceptionCanopyPost'+str(px),(x+px,y+1.72,z-7.6),(.35,3.44,.35),m['trim'])
        for side in [-1,1]:
            for index,zz in enumerate([3,8]):
                sc.cylinder('QueuePost'+str(side)+str(index),(x+side*3,y+.52,z+zz),.07,1.04,'steel')
            pipe(sc,'QueueRail'+str(side),(x+side*3,y+.94,z+5.5),5,2,radius=.04)
        sc.box('ReceptionServiceRecess',(x-sx/2+.22,y+2.1,z+6),(.08,1.65,5.2),'recess',False)
        sc.box('ReceptionServiceGlass',(x-sx/2+.28,y+2.1,z+6),(.04,1.4,4.8),'v13_glass',False)
        sc.box('ReceptionServiceShelf',(x-sx/2+.65,y+1.25,z+6),(1,.18,5.6),m['trim'])
        sc.label('ReceptionServiceLabel','PATIENT RECORDS',(x-sx/2+.35,y+3.1,z+6),rotation=(0,90,0),size=25)
    if rid in {'triage','recovery'}:
        # A large C3 arrival composition frames the real five-metre door.
        entrance=z+sz/2-.55
        for side in [-1,1]:
            sc.box(rid+'_HeroPillar'+str(side),(x+side*3.9,y+2.5,entrance),(1.4,5,1.8),m['trim'])
            sc.box(rid+'_PillarFoot'+str(side),(x+side*3.9,y+.22,entrance),(1.7,.44,2.0),m['panel'])
            for index in range(2):pipe(sc,rid+'_OverheadPipe'+str(side)+str(index),(x+side*(4.3+index*.36),y+6.2,z),sz-3,2,radius=.16)
        sc.box(rid+'_HeroLintel',(x,y+4.7,entrance),(10.4,1.1,1.8),m['trim'])
        sc.box(rid+'_HeroSignBack',(x,y+4.65,entrance+.93),(8.9,.86,.08),'recess',False)
        sc.label(rid+'_C3Sign','C3  EMERGENCY TRIAGE' if rid=='triage' else 'RECOVERY  /  TRANSFER',(x,y+4.65,entrance+.99),size=43,color=(.68,.75,.43,1))
        for index,zz in enumerate([-sz*.24,sz*.24]):sc.box(rid+'_OverheadGantry'+str(index),(x,y+6.65,z+zz),(sx-1.5,.5,.7),m['trim'])
        if rid=='triage':
            # Real sealed specimen-glass bays, backed by native creature art.
            for side in [-1,1]:
                px=x+side*7;pz=z-sz/2+1.5
                sc.box('SpecimenBayBack'+str(side),(px,y+2.4,pz-.8),(3.2,4.8,.4),m['panel'])
                sc.cylinder('SpecimenBayBase'+str(side),(px,y+.16,pz),1.2,.32,'steel')
                sc.cylinder('SpecimenGlass'+str(side),(px,y+2.45,pz),1.12,4.3,'v13_glass')
                sc.cylinder('SpecimenBayCap'+str(side),(px,y+4.68,pz),1.25,.2,'steel')
                sc.node('ContainedSpecimen'+str(side),'Sprite3D',props='position = '+vec((px,y+2.4,pz))+'\ntexture = SubResource("v13_specimen")\npixel_size = 0.006\ntexture_filter = 0\nshaded = true')
    if room['function'] in {'diagnostics','surgery'}:
        # A glazed observation recess has actual depth, side/back/ceiling and
        # a solid transparent pane, rather than exposing the outside void.
        lo,hi=shell.observation(room);width=hi-lo;wx=x+sx/2;wz=z+(lo+hi)/2
        if room.get('outline_xz') and (lo,hi)!=(4,9):sc.shell_fits.append({'room':rid,'node':rid+'_Observation','action':'trim_sealed_alcove','local_z_span':[lo,hi],'reason':'Actual straight east boundary ends at chamfer/notch; closed nontraversable alcove fits its aperture.'})
        sc.box(rid+'_ObservationBack',(wx+1.5,y+2.8,wz),(.25,2.8,width+.4),m['panel'])
        for side in [-1,1]:sc.box(rid+'_ObservationSide'+str(side),(wx+.7,y+2.8,wz+side*(width/2+.2)),(1.6,2.8,.25),m['wall'])
        for label,yy in [('Base',1.42),('Top',4.18)]:sc.box(rid+'_Observation'+label,(wx+.7,y+yy,wz),(1.6,.18,width+.6),m['trim'])
        sc.box(rid+'_ObservationGlass',(wx-.04,y+2.8,wz),(.08,2.6,width),'v13_glass')
        sc.box(rid+'_ObservationConsole',(wx+1.3,y+2.7,wz),(.12,1.5,min(2.3,width-.3)),sc.prop_materials['face'],False)
        for side in [-1,1]:sc.box(rid+'_WindowMullion'+str(side),(wx-.1,y+2.8,wz+side*min(.9,width*.28)),(.12,2.7,.09),m['trim'],False)
        # Broken panel edges expose darker service texture beneath intact tile.
        bx=x-sx*.27;bz=z-sz/2+.23
        sc.box(rid+'_OpenServicePanel',(bx,y+2.6,bz),(2.4,1.65,.12),'recess',False)
        for index in range(4):pipe(sc,rid+'_ExposedCable'+str(index),(bx-.8+index*.5,y+2.6,bz+.09),1.3,1,radius=.025)
        sc.box(rid+'_BrokenPanelFlap',(bx+.95,y+2.15,bz+.15),(.45,.7,.06),m['panel'],False,rot=(18,-12,9))
    if room['function'] in {'utility','decontamination'}:
        # Pump banks have cylindrical sealed pressure vessels and manifold runs.
        for side in [-1,1]:
            px=x+side*(sx/2-1.6);pz=z-sz/2+3.0
            sc.cylinder(rid+'_PressureVessel'+str(side),(px,y+1.7,pz),.85,3.4,'steel')
            for yy in [.2,3.2]:sc.cylinder(rid+'_VesselCollar'+str(side)+str(yy),(px,y+yy,pz),.94,.18,'panel',False)
            pipe(sc,rid+'_FeedPipe'+str(side),(px,y+3.8,z),sz-2,2,radius=.13)
            pipe(sc,rid+'_FeedDrop'+str(side),(px,y+2.9,pz),1.8,1,radius=.13)
    if rid in {'transfer','lift_lobby','exit'}:
        for index,zz in enumerate([-sz*.3,0,sz*.3]):sc.box(rid+'_TransferRib'+str(index),(x,y+ch-.65,z+zz),(sx-.7,.65,.5),'steel')
        sc.label(rid+'_TransferWayfinding','TRANSFER  /  CONTAINMENT',(x,y+3.3,z-sz/2+.3),size=28,color=(.56,.65,.55,1))


def chapter_architecture(sc,room):
    x,y,z=room['center'];sx,h,sz=room['size'];rid=room['id'];m=sc.materials[family(room)]
    if sc.level['id']=='pale_ward_02' and rid=='overlook':
        fighting=bool(sc.level.get('structural_connections'))
        # Fighting galleries retain actual side guards and permanent firing
        # parapets; auto shutters block LOS until both feeds drain the basin.
        for side in [-1,1]:
            px=x+side*8.5;midz=-19.5
            sc.box('OverlookSightFloor'+str(side),(px,3.8,midz),(9,.4,13.2),m['floor'])
            sc.box('OverlookSightRoof'+str(side),(px,8.65,midz),(9.6,.3,13.2),m['ceiling'])
            for edge in [-1,1]:sc.box('OverlookSightSide'+str(side)+str(edge),(px+edge*4.65,4.7 if fighting else 6.25,midz),(.3,1.4 if fighting else 4.6,13.2),m['trim'] if fighting else m['wall'])
            if not fighting:
                for label,zz in [('Near',-13),('Far',-26)]:sc.box('OverlookSightGlass'+str(side)+label,(px,6.35,zz),(9,3.9,.08),'v13_glass')
            sc.box('OverlookSightPier'+str(side),(px,1.85,-22),(.7,3.7,.7),'steel')
        sc.label('ReservoirOverlookSign','CULTURE RESERVOIR / DUAL FEED ISOLATION',(x,y+3.3,z-sz/2+.25),size=33,color=(.53,.7,.44,1))
    if room['function']=='reservoir':
        for side in [-1,1]:
            for end in [-1,1]:
                px=x+side*(sx/2-1.4);pz=z+end*(sz/2-2)
                if room.get('outline_xz'):
                    old=(px,pz);px,_,pz=shell.fit_feature(room,(px,y,pz),(1.2,1,1.2))
                    if (px,pz)!=old:sc.shell_fits.append({'room':rid,'node':rid+'_ReservoirColumn'+str(side)+str(end),'action':'fit_shell_column','old_xz':old,'xz':[px,pz],'reason':'Keep structural column inside actual L footprint.'})
                sc.cylinder(rid+'_ReservoirColumn'+str(side)+str(end),(px,y+(h-1.5)/2,pz),.6,h-1.5,'steel')
            pipe(sc,rid+'_ReservoirMain'+str(side),(x,y+h-1.0,z+side*(sz/2-2)),sx-3,0,radius=.24)
            sc.box(rid+'_TankRim'+str(side),(x+side*(sx/2-.25),y+h-1.5,z),(.6,.45,sz-.5),'steel')
        if sc.level['id']=='pale_ward_02' and rid=='reservoir':
            sc.ext.append('[ext_resource type="Script" path="res://scripts/reservoir_effect_v13.gd" id="v13_reservoir_effect"]')
            sc.node('ReservoirLiquid',props='position = '+vec((x,3.5,z))+'\nscript = ExtResource("v13_reservoir_effect")\nhigh_y = 3.5\nlow_y = -0.2\nmetadata/cosmetic_only = true\nmetadata/required_flags = '+arr(['isolation_a','isolation_b']))
            sc.box('LiquidSurface',(0,0,0),(sx-1,.035,sz-1),'v13_liquid',False,'ReservoirLiquid')
            sc.label('BasinDrainMark','BOTH FEEDS ISOLATED / LOWER BASIN ACCESS',(x,y+1.8,z-sz/2+.25),size=27,color=(.43,.65,.38,1))
    if room['function']=='specimen_silo':
        for side in [-1,1]:
            for end in [-1,1]:
                px=x+side*(sx/2-1.1);pz=z+end*(sz/2-2)
                if room.get('outline_xz'):
                    old=(px,pz);px,_,pz=shell.fit_feature(room,(px,y,pz),(1.3,1,1.3))
                    if (px,pz)!=old:sc.shell_fits.append({'room':rid,'node':rid+'_SiloButtress'+str(side)+str(end),'action':'fit_shell_buttress','old_xz':old,'xz':[px,pz],'reason':'Inset closed structural rib/feed assembly from actual chamfer.'})
                sc.box(rid+'_SiloButtress'+str(side)+str(end),(px,y+(h-1)/2,pz),(.9,h-1,1.1),'steel')
                sc.cylinder(rid+'_SiloFeed'+str(side)+str(end),(px+side*.6,y+(h-1)/2,pz),.18,h-1,'panel',False)
            sc.box(rid+'_SuspendedGantry'+str(side),(x,y+h-1.4,z+side*sz*.27),(sx-1.2,.75,.9),'steel')
        sc.box(rid+'_CeilingSpine',(x,y+h-.8,z),(5,.65,sz-2),'panel')
        if rid=='rupture':
            for side in [-1,1]:
                # Organic rupture surfaces have solid underlying room floor;
                # no hidden fall holes, unreachable actors or jump requirements.
                sc.box('RuptureFloorVein'+str(side),(x+side*10.2,y+.014,z),(1.5,.028,sz-2),'v13_invasion',False)
                for end in [-1,1]:
                    px=x+side*(sx/2-2);pz=z+end*(sz/2-2)
                    if room.get('outline_xz'):
                        old=(px,pz);px,_,pz=shell.fit_feature(room,(px,y,pz),(2.0,1,1.4))
                        if (px,pz)!=old:sc.shell_fits.append({'room':rid,'node':'RuptureAngularGrowth'+str(side)+str(end),'action':'fit_shell_growth','old_xz':old,'xz':[px,pz],'reason':'Keep closed organic boundary dressing inside chamfer; no prop inventory/type change.'})
                    sc.prism('RuptureAngularGrowth'+str(side)+str(end),(px,y,pz),[(-.8,-.7),(.7,-.5),(1,.6),(-.5,.9)],1.2,'v13_invasion')
            sc.label('RuptureHeader','BIOLOGICAL SEAL RUPTURE / BURIED TRANSFER',(x,y+5,z-sz/2+.3),size=35,color=(.61,.42,.25,1))
    if sc.level['id']=='pale_ward_03' and rid=='exit':
        for side in [-1,1]:
            sc.box('AshPassagePillar'+str(side),(x+side*4.1,y+2.6,z-7),(1.6,5.2,1.7),'v13_invasion')
            sc.box('AshPassagePillarBand'+str(side),(x+side*4.1,y+2.9,z-6.1),(1.85,.45,.25),'steel',False)
        sc.box('AshPassageArch',(x,y+4.8,z-7),(10.2,1.25,1.9),'v13_invasion')
        sc.box('AshPassageThreshold',(x,y+.05,z-6.8),(6,.1,2.3),'steel',extra='metadata/stage_step = true')
        sc.label('AshPassageDestination','ASH CITADEL / BURIED PASSAGE',(x,y+4.8,z-5.98),size=39,color=(.69,.43,.24,1))
    if sc.level['id']=='pale_ward_03' and rid=='bridge':
        px=x-sx/2+.35
        for side in [-1,1]:sc.box('BuriedGatePillar'+str(side),(px,y+2.5,z+side*3.9),(1.6,5,1.4),'v13_invasion')
        sc.box('BuriedGateCrown',(px,y+4.8,z),(1.8,1.1,10.5),'steel')
        sc.label('BuriedTransferSign','BURIED TRANSFER',(px+.95,y+4.7,z),rotation=(0,90,0),size=40,color=(.65,.48,.28,1))


def furnishing(sc,room):
    room=dict(room,layout_mode='authored_v13')
    for obj in room['objects']:
        typ=obj['type'];pos=obj['position_local'];name=sc.level['id']+'.'+obj['id'];root='RoomProp_'+name.replace('.','_')
        if typ in {'surgical_table','surgical_lamp'}:
            x,y,z=room['center'];sc.node(root,props='position = '+vec((x+pos[0],y+pos[1],z+pos[2]))+'\nrotation_degrees = '+vec((0,obj['heading'],0))+'\nmetadata/room_program_object = '+quote(name)+'\nmetadata/prop_type = '+quote(typ))
            if typ=='surgical_table':
                for label,at,size in [('TBase',(0,.07,0),(1.7,.14,.32)),('Pedestal',(0,.39,0),(.42,.66,.52)),('Support',(0,.67,0),(2.4,.1,1.1))]:sc.box(label,at,size,'steel',parent=root,hit_material='armor')
                for side in [-1,1]:sc.box('Foot'+str(side),(side*.65,.06,0),(.2,.12,1),'steel',parent=root,hit_material='armor')
                for i,xx in enumerate([-.8,0,.8]):sc.box('Enamel'+str(i),(xx,.81,0),(.76,.18,1.02),sc.materials['surgery']['panel'],parent=root,hit_material='armor')
            else:
                sc.box('Foot',(0,.06,0),(.7,.12,.7),'steel',parent=root)
                sc.box('Mast',(0,1.1,-.18),(.09,2.2,.09),'steel',parent=root)
                sc.box('Arm',(0,2.2,-.05),(.1,.1,.36),'steel',parent=root)
                sc.lamp('TaskHead',(0,2.1,.1),room,'surgical',parent=root,energy=1.6)
        else:
            props._emit_prop(sc,name,{'type':typ},room,(pos[0],pos[2],obj['heading']),sc.prop_materials,'authored_v13')
            if sc.level['id']=='pale_ward_02' and typ in {'filter_unit','pipe_manifold'}:
                # The shared fixture recipe hangs its housing above the floor.
                # These Ward utility fittings are freestanding, so give each a
                # visible, collidable route down to the room's actual floor.
                if typ=='filter_unit':
                    sc.box('FloorCabinet',(0,.64,0),(1.2,1.28,.58),'steel',parent=root,hit_material='armor')
                    for side in [-1,1]:
                        sc.box('FilterRail'+str(side),(side*.45,1.83,.33),(.09,.73,.06),'steel',False,root)
                    sc.box('FilterStatusBand',(0,.94,.303),(.96,.21,.045),'v16_filter_signal',False,root)
                    sc.label('EquipmentLabel','AIR FILTER',(0,1.82,.36),root,size=21,color=(.66,.83,.66,1))
                else:
                    for side in [-1,1]:
                        sc.cylinder('FloorFeed'+str(side),(side*.36,.68,0),.095,1.36,'steel',True,root)
                        sc.box('PipeCollar'+str(side),(side*.36,1.14,.13),(.27,.19,.18),'v16_pipe_signal',False,root)
                    sc.box('ValveBridge',(0,.48,.08),(1.03,.16,.2),'steel',False,root)
                    sc.label('EquipmentLabel','PIPE FEED',(0,1.82,.36),root,size=21,color=(1,.76,.39,1))
        sc.fittings.append({'id':name,'room':room['id'],'type':typ,'position_local':pos,'heading':obj['heading']})


def stable_pickup(sc,name,kind,at,amount):
    sc.pickup(name,kind,at,amount)
    if kind in {'health','armor'}:
        # The box artwork identifies the category; the front badge makes the
        # 1/25/50 denomination readable before contact.
        sc.label('DoseValue','+'+str(amount),(0,.29,.255),name,size=20,
                 color=(.96,.67,.53,1) if kind=='health' else (.55,.88,.96,1))
    for i,block in enumerate(sc.nodes):
        if block.startswith('[node name="'+name+'" '):sc.nodes[i]=block.rstrip()+'\nmetadata/stable_id = '+quote(sc.level['id']+'.pickup.'+name)+'\n'


def distribute(total,rooms):
    weights=[max(3,r['enemies']) for r in rooms];n=sum(weights);values=[total*w//n for w in weights]
    for i in sorted(range(len(rooms)),key=lambda i:-(total*weights[i]%n))[:total-sum(values)]:values[i]+=1
    return values


RANGED_PROMOTIONS={
    'pale_ward_01': {'generator','surgical_access','decon','transfer'},
    'pale_ward_02': {'cultures','waste_lab','reservoir','purge'},
    'pale_ward_03': {'upper_gallery','crossfire','cultivation','rupture'},
}


def survival_denominations(kind,total):
    # One-value shards are frequent but small. Only two 50-point reserves per
    # route; the same original route budget remains available without secrets.
    fifties=2
    singles=25
    assert kind in {'health','armor'} and (total-singles-50*fifties)%25==0
    quarters=(total-singles-50*fifties)//25
    large=[25]*quarters+[50]*fifties
    amounts=[]
    for value in large:
        amounts.append(value)
        for _ in range(2):
            if singles:amounts.append(1);singles-=1
    amounts.extend([1]*singles)
    return amounts


def scatter_supply(sc,level,rooms,supply_rooms,kind,total,pickups):
    amounts=survival_denominations(kind,total) if kind in {'health','armor'} else [n for n in distribute(total,supply_rooms)]
    # All six supply families share each room's placement cursor. Keeping a
    # cursor per kind piled several cases on the same spot, including directly
    # behind the physical anchor-C pylon in Breach Circuit.
    assigned=sc.__dict__.setdefault('supply_slots',{})
    bays=[(-2,-1),(-1,-1),(0,-1),(-2,0),(-1,0),(0,0),(1,0),(2,0),(-1,1),(0,1),(1,1),(2,1)]
    for index,amount in enumerate(amounts):
        if amount<=0:continue
        room=supply_rooms[index%len(supply_rooms)] if kind in {'health','armor'} else supply_rooms[index]
        slot=assigned.get(room['id'],0);assigned[room['id']]=slot+1
        assert slot<len(bays),(level['id'],room['id'],'not enough authored supply bays')
        x,y,z=room['center'];sx,_,sz=room['size']
        # The south row stays on the left/centre, clear of controls and
        # shootable anchors at +X/-Z. Later cases fan across the open centre
        # and north bays; no stacked pickup hotspots.
        bx,bz=bays[slot]
        at=[x+bx*min(2.1,sx*.08),y+.5,z+bz*min(5.0,sz*.21)]
        name='Supply_'+kind+'_'+room['id']+'_'+str(slot)
        stable_pickup(sc,name,kind,at,amount)
        pickups.append({'node':name,'kind':kind,'amount':amount,'room':room['id'],'position':at})


def populate(sc,rooms):
    level=sc.level;sc.node('EnemySpawns');enemy_records=[]
    for room in rooms.values():
        for i in range(room['enemies']):
            staff=room['function'] in {'triage_reception','triage_ward','control_room','diagnostics','surgery','medical_stores','security','records','staff_room'}
            kind=('infected_security' if i%3==2 or room['function']=='security' else 'infected_scientist') if staff else ('vessel' if i%3==2 else 'unsealed')
            if i==0 and room['id'] in RANGED_PROMOTIONS[level['id']]:kind='infected_security'
            x,y,z=room['center'];at=[x+((i%3)-1)*5,y+.87,z-4+(i//3)*4]
            stable=level['id']+'.'+room['id']+'.enemy.'+str(i)
            activation_room=room['id'];arena=level['encounters'].get(room['id'],{}).get('arena_id','')
            for connection in [*level.get('structural_connections',[]),{'actor_overrides':level.get('actor_overrides',[])}]:
                for override in connection.get('actor_overrides',[]):
                    if override['stable_id']==stable:
                        assert override['kind']==kind,(stable,'actor type/count must be preserved')
                        at=override['position'];activation_room=override.get('activation_room',activation_room);arena=override.get('arena_id',arena)
            actual=next((r['id'] for r in rooms.values() if abs(at[0]-r['center'][0])<=r['size'][0]/2 and abs(at[2]-r['center'][2])<=r['size'][2]/2 and (not r.get('outline_xz') or shell.inside((at[0]-r['center'][0],at[2]-r['center'][2]),r['outline_xz']))),None)
            sc.marker('Spawn_'+str(len(enemy_records)),at,'metadata/stable_id = '+quote(stable)+'\nmetadata/kind = '+quote(kind)+'\nmetadata/arena_id = '+quote(arena)+'\nmetadata/activate_room = '+quote(activation_room),'EnemySpawns')
            enemy_records.append({'stable_id':stable,'room':actual or activation_room,'source_room':room['id'],'actual_room':actual,'activation_room':activation_room,'arena_id':arena,'kind':kind,'position':at})
    level['enemy_roster_counts']={kind:sum(1 for enemy in enemy_records if enemy['kind']==kind) for kind in sorted({enemy['kind'] for enemy in enemy_records})}
    for item in level['controls']:
        room=rooms[item['room']];x,y,z=room['center'];at=[x+3.5,y+.95,z-4];name='Control_'+item['id'];rules=level['objective_profile']['controls'][item['id']]
        sc.box(name,at,(1.1,1.5,.5),sc.equipment[family(room)]['control'],extra='metadata/stage_button = '+quote(item['id'])+'\nmetadata/stable_id = '+quote(level['id']+'.control.'+item['id'])+'\nmetadata/requires = '+arr(rules.get('requires',[]))+'\nmetadata/label = '+quote(item['id'].replace('_',' '))+'\nmetadata/activated_message = '+quote(item['id'].replace('_',' ')+' engaged'))
        message=level.get('navigation',{}).get('control_messages',{}).get(item['id'])
        if message:
            for index,block in enumerate(sc.nodes):
                if block.startswith('[node name="'+name+'" '):sc.nodes[index]=re.sub(r'metadata/activated_message = .*', 'metadata/activated_message = '+quote(message),block)
        if level.get('layout_revision')==14 and level['id']=='pale_ward_02' and item['id'] in ['isolation_a','isolation_b']:
            for index,block in enumerate(sc.nodes):
                if block.startswith('[node name="'+name+'" '):sc.nodes[index]=block.rstrip()+'\nmetadata/activated_complete_requires = '+arr(['isolation_a','isolation_b'])+'\nmetadata/activated_complete_message = '+quote('Both feeds isolated · basin drained; return to Overlook for discharge.')+'\n'
        sc.box('ControlFoot',(0,-.85,0),(.8,.2,.45),sc.materials[family(room)]['trim'],True,name);sc.box('ControlFace',(0,.12,.29),(.55,.48,.08),sc.equipment[family(room)]['control'],False,name);sc.node('ControlPresentationV9',parent=name,props='script = ExtResource("v13_control_presentation")\nflag_key = &'+quote(item['id'])+'\nrequired_flags = PackedStringArray('+', '.join(map(quote,rules.get('requires',[])))+')');sc.label('Label',item['id'].replace('_',' ').upper(),(0,1.2,.33),name,size=28);item['node']=name;item['position']=at
    for item in level['keys']:
        room=rooms[item['room']];x,y,z=room['center'];at=[x,y+.65,z-4];name='Key_'+item['kind'];stable_pickup(sc,name,item['kind'],at,1);item['node']=name;item['position']=at
    if level['anchors']:
        sc.ext.append('[ext_resource type="Script" path="res://scripts/shootable_mechanism_v13.gd" id="v13_anchor"]')
    for item in level['anchors']:
        room=rooms[item['room']];x,y,z=room['center'];at=[x+4.5,y+1.4,z-6];name='Anchor_'+item['id']
        sc.box(name,at,(1.8,2.4,1.2),sc.materials['utility']['panel'],extra='script = ExtResource("v13_anchor")\nhealth = '+str(float(item['health']))+'\ncompletion_flag = '+quote(item['id'])+'\nmetadata/completion_flag = '+quote(item['id'])+'\nmetadata/stable_id = '+quote(level['id']+'.anchor.'+item['id'])+'\nmetadata/requires = '+arr(item['requires']),hit_material='armor')
        for index,text in enumerate(sc.nodes):
            if text.startswith('[node name="'+name+'" '):sc.nodes[index]=text.replace('collision_layer = 1','collision_layer = 5')
        sc.box('AnchorFoot',(0,-1.3,0),(2.3,.2,1.6),'steel',True,name)
        for side in [-1,1]:sc.box('AnchorPylon'+str(side),(side*1.35,.2,0),(.45,3.2,1.5),'steel',True,name)
        sc.box('LiveIndicator',(0,.05,.63),(.7,.7,.08),'red',False,name)
        sc.node('BrokenIndicator',parent=name,props='visible = false');sc.box('DisabledFace',(0,.05,.64),(.85,.8,.09),'recess',False,name+'/BrokenIndicator')
        sc.label('AnchorLabel','CONTAINMENT '+item['id'].replace('anchor_','').upper(),(0,2.05,.72),name,size=27)
        item['node']=name;item['position']=at
    for item in level['checkpoints']:
        room=rooms[item['room']];at=[room['center'][i]+item['offset'][i] for i in range(3)]
        sc.marker('Checkpoint_'+item['id'],at,'metadata/checkpoint_id = '+quote(item['id'])+'\nmetadata/stable_id = '+quote(level['id']+'.checkpoint.'+item['id'])+'\nmetadata/requires = '+arr(item['requires'])+'\nmetadata/radius = '+str(item['radius']));item['position']=at;item['node']='Checkpoint_'+item['id']
        sc.box('CheckpointMarker_'+item['id'],(at[0],at[1]+.008,at[2]),(1.4,.016,1.4),'v13_checkpoint_inset',False)
        station='CheckpointStation_'+item['id'];sc.box(station,(at[0]+2.8,at[1]+.85,at[2]),(1.0,1.7,.65),sc.materials[family(room)]['panel'])
        sc.box('StationFace',(0,.15,.35),(.7,.5,.05),sc.prop_materials['face'],False,station);sc.label('StationLabel','CHECKPOINT · PAUSE HERE',(0,1.25,.36),station,size=23,color=(.42,.66,.52,1))
    weapon=level['weapon'];room=rooms[weapon['room']];x,y,z=room['center'];weapon['node']='FirstGunCache';weapon['position']=[x,y+.65,z+4];stable_pickup(sc,'FirstGunCache',weapon['kind'],weapon['position'],weapon['amount'])
    supply_rooms=[r for r in rooms.values() if not r['optional'] and not r['secret'] and r['id']!=level['exit']['room']]
    pickups=[]
    for kind,total in dict(level['main_route_ammo'],health=level['main_route_health'],armor=level['main_route_armor']).items():
        if kind==WEAPON_AMMO[weapon['kind']]:total-=weapon['amount']
        scatter_supply(sc,level,rooms,supply_rooms,kind,total,pickups)
    for room in rooms.values():
        if room['optional'] or room['secret']:
            x,y,z=room['center'];stable_pickup(sc,'Bonus_'+room['id'],'shells',[x-2,y+.5,z+2],12);stable_pickup(sc,'BonusHealth_'+room['id'],'health',[x+2,y+.5,z-2],25)
    # Rare overdrive is distinct from ordinary top-ups; one secret per level
    # rewards exploration without making the main route depend on it.
    secret_room=rooms[level['secret_rooms'][0]]
    overdrive_kind='health' if level['id']!='pale_ward_02' else 'armor'
    x,y,z=secret_room['center'];overdrive_name='Overdrive_'+overdrive_kind
    stable_pickup(sc,overdrive_name,overdrive_kind,[x,y+.5,z-2],100)
    for index,block in enumerate(sc.nodes):
        if block.startswith('[node name="'+overdrive_name+'" '):
            sc.nodes[index]=block.rstrip()+'\nmetadata/overdrive = true\n'
            break
    sc.box('OverdriveHalo',(0,-.475,0),(.82,.04,.82),'glow',False,overdrive_name)
    room=rooms[level['exit']['room']];x,y,z=room['center'];at=[x,y+1,z-4]
    sc.box('ExitControl',at,(1.5,1.8,.5),sc.equipment[family(room)]['exit'],extra='metadata/stage_exit = true\nmetadata/stable_id = '+quote(level['id']+'.exit')+'\nmetadata/requires = '+arr(level['exit']['requires'])+'\nmetadata/locked_message = "Complete the remaining objectives"')
    sc.box('ExitFoot',(0,-.95,0),(1.1,.1,.45),sc.materials[family(room)]['trim'],True,'ExitControl');sc.node('ControlPresentationV9',parent='ExitControl',props='script = ExtResource("v13_control_presentation")\nis_exit = true\nrequired_flags = PackedStringArray('+', '.join(map(quote,level['exit']['requires']))+')\nsurface_material = SubResource("'+sc.equipment[family(room)]['exit']+'")');sc.label('ExitLabel',{'pale_ward_01':'TO CONTAINMENT / RESERVOIR TRANSFER','pale_ward_02':'TO BREACH / SPECIMEN SILO','pale_ward_03':'ASH CITADEL / BURIED PASSAGE'}[level['id']],(0,1.3,.3),'ExitControl',size=34);level['exit'].update(node='ExitControl',position=at)
    room=rooms[level['spawn_room']];spawn=[room['center'][i]+level['spawn_local'][i] for i in range(3)]
    sc.node('Player','CharacterBody3D',props='position = '+vec(spawn)+'\nscript = ExtResource("player")\ncollision_layer = 2\ncollision_mask = 3\nfloor_snap_length = 0.25')
    sc.node('CollisionShape3D','CollisionShape3D','Player','shape = SubResource("player_shape")');sc.node('Camera3D','Camera3D','Player','position = Vector3(0,0.68,0)\ncurrent = true\nfov = 82\nnear = 0.04\nfar = 700');sc.marker('PlayerStart',spawn,'');level['spawn_position']=spawn
    return enemy_records,pickups


def objective_resource(level):
    data=deepcopy(level['objective_profile']);data['encounters']=level['encounters']
    header='[gd_resource type="Resource" script_class="StageObjectiveProfile" load_steps=2 format=3]\n[ext_resource type="Script" path="res://scripts/stage_objective_profile.gd" id="profile_script"]\n[resource]\nscript = ExtResource("profile_script")\n'
    for key,value in data.items():
        encoded='Array[Dictionary]('+json.dumps(value,ensure_ascii=False)+')' if key=='objectives' else arr(value) if key=='exit_requires' else json.dumps(value,ensure_ascii=False)
        header+=key+' = '+encoded+'\n'
    return header


def descent_atrium(sc):
    if sc.level['id']!='pale_ward_03':return
    # Root-authored sealed silo, not another room/objective. The unchanged
    # return connector descends through this shared volume with full guards.
    m=sc.materials['utility']
    sc.box('DescentAtrium_Base',(40,-4.3,0),(32.4,.6,54.4),m['floor'])
    sc.box('DescentAtrium_Roof',(40,18.2,0),(32.8,.4,54.8),m['ceiling'])
    for side in [-1,1]:
        sc.box('DescentAtrium_Side'+str(side),(40+side*16,7,0),(.4,22,54.4),m['wall'])
        for index,zz in enumerate([-22,-10,10,22]):
            sc.box('DescentAtrium_Buttress'+str(side)+str(index),(40+side*15.2,6.5,zz),(.85,21,1.3),m['trim'])
        for index,zz in enumerate([-18,18]):
            sc.cylinder('DescentAtrium_VerticalPipe'+str(side)+str(index),(40+side*12,6.1,zz),.7,20.2,'steel')
            for yy in [-2,4,10,15]:sc.cylinder('DescentAtrium_PipeCollar'+str(side)+str(index)+str(yy),(40+side*12,yy,zz),.86,.22,'panel',False)
    # Upper-gallery's real south wall supplies the upper north closure; this
    # lower wall closes the shaft beneath that existing elevated floor.
    sc.box('DescentAtrium_NorthBelowGallery',(40,2,-27),(32.4,12,.4),m['wall'])
    for side in [-1,1]:
        sc.box('DescentAtrium_SouthPier'+str(side),(40+side*9.3,7,27),(13.8,22,.4),m['wall'])
    sc.box('DescentAtrium_SouthBelowDoor',(40,-.075,27),(5.0,7.85,.4),m['wall'])
    sc.box('DescentAtrium_SouthOverDoor',(40,12.9,27),(5.0,10.2,.4),m['wall'])
    for side in [-1,1]:
        xx=40+side*8.5
        sc.box('DescentObservationGlass'+str(side),(xx,11.25,-27),(8.5,4.5,.08),'v13_vista_glass')
        for edge in [-1,1]:sc.box('DescentObservationMullion'+str(side)+str(edge),(xx+edge*4.25,11.25,-27.08),(.12,4.6,.15),'steel')
        sc.box('DescentObservationSill'+str(side),(xx,8.95,-27.1),(8.8,.16,.3),'steel')
    lamp_room={'id':'descent_atrium','function':'utility','size':[32,22,54]}
    sc.lamp('DescentAtrium_UpperWallLamp',(24.38,12,-12),lamp_room,rotation=(0,-90,0),energy=4.5)
    sc.lamp('DescentAtrium_LowerWallLamp',(55.62,3,12),lamp_room,rotation=(0,90,0),energy=4.5)
    # Suspended physical kit gives the vertical pipes and lower shaft a broad,
    # warm pool without altering the bridge, glass or traversal colliders.
    for side in [-1,1]:sc.box('DescentAtrium_LampSuspension'+str(side),(40+side*.72,17.05,0),(.065,2.1,.065),'steel',False)
    sc.box('DescentAtrium_LampCrossbeam',(40,16.15,0),(2.2,.15,.65),'steel',False)
    sc.lamp('DescentAtrium_SuspendedLamp',(40,16,0),lamp_room,energy=10.0,reach=35.0)
    sc.label('DescentSiloLandmark','SPECIMEN SILO / LOWER CROSSFEED',(55.75,9,0),rotation=(0,-90,0),size=42,color=(.5,.61,.41,1))


def structural_connections(sc,rooms):
    """Exact authored apertures, closed supports, cover, real stairs and actors.

    Data is mirrored into runtime routes and author reports for independent
    native contact/walking tests. Metadata does not establish acceptance.
    """
    for connection in sc.level.get('structural_connections',[]):
        prefix='Structural_'+connection['id']+'_';material=sc.materials[family(rooms[connection['rooms'][0]])]
        for box in connection.get('boxes',[]):
            sc.box(prefix+box['id'],box['position'],box['size'],material[box['role']])
        for stair in connection.get('stairs',[]):
            sc.stairs(prefix+stair['id']+'_',stair['start'],stair['end'],stair['width'],material['floor'])
        for shutter in connection.get('shutters',[]):
            extra='script = ExtResource("door")\nmetadata/stage_door = '+quote(shutter['stage_door'])+'\nmetadata/stable_id = '+quote(shutter['stable_id'])+'\nmetadata/requires = '+arr(shutter['requires'])+'\nmetadata/auto_open = true\nmetadata/drain_controller = NodePath('+quote(shutter['drain_controller'])+')\nmetadata/open_offset = '+vec(shutter['open_offset'])
            sc.box(shutter['id'],shutter['position'],shutter['size'],material['door'],typ='AnimatableBody3D',extra=extra,hit_material='armor')
        for light in connection.get('lights',[]):
            sc.lamp(prefix+light['id'],light['position'],rooms[light['room']],energy=light['energy'])


def optional_reserve(sc,rooms):
    reserve=sc.level.get('optional_reserve')
    if not reserve:return
    room=rooms[reserve['room']];m=sc.materials[family(room)];x0,x1=reserve['x_span'];d0,d1=reserve['door_x_span'];z=reserve['partition_z'];floor=reserve['floor'];height=reserve['partition_height'];prefix='Reserve_'+reserve['arena_id']
    for name,lo,hi in [('Left',x0,d0),('Right',d1,x1)]:sc.box(prefix+'_'+name,((lo+hi)/2,floor+height/2,z),(hi-lo,height,.3),m['wall'])
    sc.box(prefix+'_Header',((d0+d1)/2,floor+(reserve['door_height']+height)/2,z),(d1-d0,height-reserve['door_height'],.3),m['trim'])
    cap=reserve['closet_roof_y']-floor-height
    sc.box(prefix+'_UpperCap',((x0+x1)/2,floor+height+cap/2,z),(x1-x0,cap,.3),m['wall'])
    back=room['center'][2]+(1 if reserve.get('closet_side')=='south' else -1)*room['size'][2]/2
    sc.box(prefix+'_Roof',((x0+x1)/2,reserve['closet_roof_y']+.12,(back+z)/2),(x1-x0+.2,.24,abs(z-back)+.3),m['ceiling'])
    name=reserve['door_node'];extra='script = ExtResource("door")\nmetadata/stage_door = '+quote(reserve['arena_id'])+'\nmetadata/stable_id = '+quote(reserve['release_door_stable_id'])+'\nmetadata/open_offset = '+vec(reserve['door_open_offset'])+'\nmetadata/requires = '+arr(reserve['requires'])
    sc.box(name,((d0+d1)/2,floor+reserve['door_height']/2,z),(d1-d0,reserve['door_height'],.3),m['door'],typ='AnimatableBody3D',extra=extra)
    south=reserve.get('closet_side')=='south'
    sc.label(prefix+'_Sign',reserve['sign'],((x0+x1)/2,floor+2.85,z+(-.18 if south else .18)),rotation=(0,180 if south else 0,0),size=26,color=(.73,.62,.36,1))


def navigation_signs(sc):
    for index,sign in enumerate(sc.level.get('navigation',{}).get('landmarks',[])):
        sc.label('NavigationV14_'+str(index),sign['label'],sign['position'],rotation=(0,sign['yaw'],0),size=28,color=(.62,.77,.5,1))


def author_selected(level_id,path=INPUT):
    level=load_level(level_id,path);rooms={r['id']:r for r in level['rooms']};sc=WardScene(level)
    protected={p:hashlib.sha256(p.read_bytes()).hexdigest() for p in list((ROOT/'scenes/campaign').glob('*.tscn'))+list((ROOT/'resources/campaign').glob('*-layout.json'))+list((ROOT/'resources/campaign').glob('*-route.json'))+list((ROOT/'assets').rglob('*')) if p.is_file() and not p.name.startswith(level_id)}
    cuts,routes=build_portals(sc,rooms)
    architecture_cuts(sc,rooms,cuts)
    descent_atrium(sc)
    structural_connections(sc,rooms)
    for room in rooms.values():
        walls(sc,room,cuts[room['id']]);sc.shell_room=room;authored_architecture(sc,room);chapter_architecture(sc,room);sc.shell_room=None;furnishing(sc,room)
    ward_environment_v19.apply(sc,level,rooms)
    optional_reserve(sc,rooms);navigation_signs(sc)
    enemies,supplies=populate(sc,rooms)
    assert len(enemies)==level['enemy_total']
    scene=sc.serialize();layout=deepcopy(level);layout['theme']='pale_ward';layout['geometry_version']=13
    route=dict(deepcopy(level),architecture_version=13,design_version=13,rooms=rooms,portals=routes,enemy_spawns=enemies,supplies=supplies,vertical_routes={},combat_paths={},combat_flanks={},entry_weapon=level['weapon']['kind'])
    paths={ROOT/'scenes/campaign'/f'{level_id}.tscn':scene,ROOT/'resources/campaign'/f'{level_id}-layout.json':json.dumps(layout,indent=2)+'\n',ROOT/'resources/campaign'/f'{level_id}-route.json':json.dumps(route,indent=2)+'\n',ROOT/'resources/campaign/v13'/f'{level_id}-objectives.tres':objective_resource(level)}
    for output,text in paths.items():output.parent.mkdir(parents=True,exist_ok=True);output.write_text(text)
    assert all(p.is_file() and hashlib.sha256(p.read_bytes()).hexdigest()==digest for p,digest in protected.items()),'Protected scene/art changed'
    report={'level':level_id,'rooms':len(rooms),'portals':len(routes),'enemies':len(enemies),'fittings':len(sc.fittings),'mounted_lights':len(sc.lights),'height_bands':sorted({r['center'][1] for r in rooms.values()}),'protected_scene_art_files':len(protected),'outputs':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths},'geometry':sc.geometry,'furnishings':sc.fittings,'light_fixtures':sc.lights,'structural_connections':level.get('structural_connections',[])}
    report.update(layout_revision=level.get('layout_revision',13),room_outlines={r['id']:{'outline_xz':r['outline_xz'],'convex_floor_cells':shell.cells(r),'floor_y':r['center'][1],'roof_y':r['center'][1]+r['size'][1]} for r in rooms.values() if r.get('outline_xz')},shell_fits=sc.shell_fits,optional_reserve=level.get('optional_reserve'))
    report_path=ROOT/'resources/campaign/v13'/f'{level_id}-author-report.json';report_path.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({k:v for k,v in report.items() if k not in ['geometry','furnishings','light_fixtures']},indent=2));return report


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--level',choices=WARD,required=True);parser.add_argument('--input',type=Path,default=INPUT);args=parser.parse_args();author_selected(args.level,args.input)
if __name__=='__main__':main()
