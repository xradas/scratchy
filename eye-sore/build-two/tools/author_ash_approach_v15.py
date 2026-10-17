#!/usr/bin/env python3
"""Author the first Ash Citadel map from its explicit route and object programme.

Only ash_citadel_01 scene, layout, route and objective resource are published.
The former playable scene is preserved by Git and by the v14 portable build.
"""
from __future__ import annotations

from copy import deepcopy
import hashlib
import json
import math
from pathlib import Path
import re

import author_themed_stages as base
import ash_approach_art_v15 as art

ROOT = Path(__file__).resolve().parents[1]
LEVEL_ID = "ash_citadel_01"
OUT = ROOT / "resources/campaign"
V15 = OUT / "v15"
SCENE = ROOT / "scenes/campaign/ash_citadel_01.tscn"
vec, quote, arr = base.vec, base.quote, base.arr

# This is the prebuild object list. Each room has a purpose and its functional
# fittings; portals below establish the credential, winch and return loop.
ROOMS = [
    ("siege_approach", "Siege overlook", (0, 0, 0), (28, 8, 28), "rampart", 2, ("barricade", "weapon_rack", "banner_standard")),
    ("trench", "Broken trench", (-40, -2, 0), (26, 7, 26), "barricade", 3, ("barricade", "supply_crate", "weapon_rack")),
    ("breach_camp", "Breach camp", (-80, -2, 0), (26, 7, 26), "guardhouse", 3, ("guard_table", "weapon_rack", "barricade")),
    ("flank_tunnel", "Flank tunnel", (-80, -2, -40), (24, 6, 26), "crypt", 2, ("ossuary_rack", "banner_standard")),
    ("lower_crypt", "Lower crypt", (-40, -2, -40), (26, 7, 26), "crypt", 3, ("ossuary_rack", "reliquary", "guard_table")),
    ("stair_tower", "Stair tower", (0, 2, -40), (26, 10, 26), "guardhouse", 3, ("weapon_rack", "banner_standard")),
    ("battlement", "High battlement", (40, 6, -40), (26, 8, 26), "rampart", 3, ("barricade", "banner_standard", "weapon_rack")),
    ("crosswall", "Crosswall", (80, 6, -40), (26, 8, 26), "rampart", 3, ("barricade", "banner_standard")),
    ("gatehouse", "Gatehouse", (80, 6, 0), (28, 9, 28), "guardhouse", 4, ("guard_table", "weapon_rack", "chain_winch")),
    ("winch", "Bridge winch", (40, 6, 0), (28, 9, 28), "forge", 3, ("chain_winch", "anvil", "forge_hearth")),
    ("inner_bridge", "Inner bridgehead", (40, 6, 40), (28, 8, 28), "rampart", 2, ("banner_standard", "barricade")),
    ("cloister", "Ash cloister", (80, 2, 40), (28, 9, 28), "chapel", 4, ("stone_bench", "reliquary", "banner_standard")),
    ("armory_hall", "Armory hall", (80, 2, 80), (26, 8, 26), "guardhouse", 3, ("weapon_rack", "anvil", "supply_crate")),
    ("furnace_gate", "Furnace gate", (40, 2, 80), (28, 10, 28), "forge", 4, ("forge_hearth", "chain_winch", "banner_standard")),
    ("quartermaster", "Quartermaster", (0, 0, 40), (18, 6, 18), "stores", 1, ("supply_crate", "weapon_rack")),
    ("watch_post", "Watch post", (40, 6, -80), (18, 6, 18), "rampart", 1, ("guard_table", "banner_standard")),
    ("tithe_vault", "Hidden tithe vault", (-80, -2, 40), (16, 6, 16), "reliquary", 1, ("reliquary", "supply_crate")),
]

PORTALS = [
    ("approach_trench", "siege_approach", "trench", [], False, False),
    ("trench_camp", "trench", "breach_camp", [], False, False),
    ("camp_flank", "breach_camp", "flank_tunnel", [], False, False),
    ("flank_crypt", "flank_tunnel", "lower_crypt", [], False, False),
    ("crypt_tower", "lower_crypt", "stair_tower", [], False, False),
    ("tower_battlement", "stair_tower", "battlement", [], False, False),
    ("battlement_crosswall", "battlement", "crosswall", [], False, False),
    ("crosswall_gatehouse", "crosswall", "gatehouse", [], False, False),
    ("gatehouse_winch", "gatehouse", "winch", [], False, False),
    ("lowering_bridge", "winch", "inner_bridge", ["gate_winch"], False, False),
    ("bridge_cloister", "inner_bridge", "cloister", [], False, False),
    ("cloister_armory", "cloister", "armory_hall", [], False, False),
    ("armory_furnace", "armory_hall", "furnace_gate", [], False, False),
    ("tower_return", "stair_tower", "siege_approach", [], True, False),
    ("approach_supplies", "siege_approach", "quartermaster", [], False, False),
    ("battlement_watch", "battlement", "watch_post", [], False, False),
    ("hidden_tithe", "breach_camp", "tithe_vault", [], False, True),
]

def room_program():
    optional = {"quartermaster", "watch_post", "tithe_vault"}
    return [{"id": rid, "label": label, "center": list(center), "size": list(size),
             "function": function, "district": "siege" if rid in {"siege_approach", "trench", "breach_camp", "quartermaster"} else "crypt" if rid in {"flank_tunnel", "lower_crypt", "tithe_vault"} else "ramparts" if rid in {"stair_tower", "battlement", "crosswall", "gatehouse", "winch", "watch_post"} else "inner",
             "enemies": enemies, "objects": list(objects), "optional": rid in optional,
             "secret": rid == "tithe_vault"} for rid, label, center, size, function, enemies, objects in ROOMS]

def append_root(sc, level):
    root = '[node name="AshApproachV15" type="Node3D"]\nscript = ExtResource("level")\nobjective_profile = ExtResource("ash_profile")\nmetadata/stage_id = "ash_citadel"\nmetadata/stage_title = "Ash Approach"\nmetadata/campaign_level_id = "ash_citadel_01"\nmetadata/campaign_chapter = "ash_citadel"\nmetadata/design_version = 15\n'
    body = f'[gd_scene load_steps={len(sc.ext)+len(sc.sub)+1} format=3]\n\n' + '\n'.join(sc.ext) + '\n\n' + '\n'.join(sc.sub) + '\n' + root + '\n' + '\n'.join(sc.nodes)
    return re.sub(r'(?<![\w])(-?)\.(\d+)', r'\g<1>0.\2', body).rstrip() + '\n'

def room_box(sc, room, cuts):
    rid = room['id']; x,y,z = room['center']; sx,h,sz = room['size']
    sc.box(rid+'_Floor', (x,y-.3,z), (sx+.1,.6,sz+.1), 'floor')
    sc.box(rid+'_Roof', (x,y+h+.2,z), (sx+.8,.4,sz+.8), 'ceiling')
    for side in ('N','S','E','W'):
        along = 0 if side in ('N','S') else 2
        across = 2 if along == 0 else 0
        cent = room['center'][along]; span = room['size'][along]
        cuts_here = cuts[side]
        xs = sorted({cent-span/2, cent+span/2} | {q for opening in cuts_here for q in opening[:2]})
        ys = sorted({y,y+h} | {q for opening in cuts_here for q in opening[2:]})
        for i,(lo,hi) in enumerate(zip(xs,xs[1:])):
            for j,(bottom,top) in enumerate(zip(ys,ys[1:])):
                if any(a<(lo+hi)/2<b and c<(bottom+top)/2<d for a,b,c,d in cuts_here): continue
                at=[x,(bottom+top)/2,z]; at[along]=(lo+hi)/2; at[across]+=(1 if side in ('S','E') else -1)*room['size'][across]/2
                size=[.4,top-bottom,.4];size[along]=hi-lo
                sc.box(f'{rid}_Wall_{side}{i}_{j}', at, size, 'wall')
    sc.marker('Room_'+rid,(x,y+h/2,z),'metadata/stage_room = '+quote(rid)+'\nmetadata/stage_label = '+quote(room['label'])+'\nmetadata/room_bounds = '+vec((sx/2,h/2+1,sz/2))+'\nmetadata/optional = '+str(room['optional']).lower()+'\nmetadata/district = '+quote(room['district'])+'\nmetadata/room_function = '+quote(room['function']))
    sc.label('RoomSign_'+rid,room['label'].upper(),(x,y+3,z-sz/2+.3),size=31)
    sc.light('Light_'+rid,(x,y+h-.65,z),(1,.43,.13,1),2.5,max(sx,sz)*.8)

def functional_fittings(sc, room):
    """Materialize the prebuild object list against the room's perimeter."""
    x,y,z=room['center'];sx,_,sz=room['size'];rid=room['id']
    for index,kind in enumerate(room['objects']):
        at=[x+(-1 if index in (0,2) else 1)*(sx/2-3),y,z+(-1 if index==2 else 1)*(sz/2-3)]
        name=f'Fitting_{rid}_{index}_{kind}'
        if kind=='banner_standard':
            sc.box(name+'_Pole',(at[0],y+1.65,at[2]),(.16,3.3,.16),'steel')
            sc.box(name+'_Cloth',(at[0],y+2.35,at[2]+.13),(1.2,1.55,.06),'banner',False)
        elif kind in ('weapon_rack','ossuary_rack'):
            sc.box(name,(at[0],y+1.1,at[2]),(2.2,2.2,.6),'steel')
            for j in range(3):sc.box(name+'_Slot'+str(j),(at[0]-0.65+j*.65,y+1.2,at[2]+.32),(.12,1.3,.05),'damaged',False)
        elif kind=='chain_winch':
            sc.box(name+'_Base',(at[0],y+.45,at[2]),(2.1,.9,1.3),'steel')
            sc.cylinder(name+'_Drum',(at[0],y+1.15,at[2]),.58,.55,'pillar')
            sc.box(name+'_Lever',(at[0]+.8,y+1.7,at[2]),(.12,1.1,.12),'steel',False)
        elif kind=='forge_hearth':
            sc.box(name+'_Frame',(at[0],y+.7,at[2]),(2.4,1.4,1.6),'steel')
            sc.box(name+'_Ember',(at[0],y+1.42,at[2]),(1.15,.09,.7),'glow',False)
        else:
            dims={'barricade':(3.0,1.25,.8),'supply_crate':(1.2,1.1,1.2),'guard_table':(2.2,.8,1.1),
                  'reliquary':(1.7,1.35,1.0),'anvil':(1.4,1.05,.8),'stone_bench':(2.3,.52,.9)}[kind]
            material='damaged' if kind=='barricade' else 'panel' if kind in ('supply_crate','reliquary') else 'steel'
            sc.box(name,(at[0],y+dims[1]/2,at[2]),dims,material)
            if kind=='reliquary':sc.box(name+'_Ember',(at[0],y+dims[1]+.03,at[2]),(.8,.06,.5),'glow',False)

def portal_geometry(sc, level, rooms):
    cuts={rid:{s:[] for s in ('N','S','E','W')} for rid in rooms};routes=[]
    for index,(pid,from_id,to_id,requires,shortcut,secret) in enumerate(PORTALS):
        a,b=rooms[from_id],rooms[to_id];ac,bc=a['center'],b['center'];dx,dz=bc[0]-ac[0],bc[2]-ac[2]
        axis=0 if abs(dx)>abs(dz) else 2; cross=2 if axis==0 else 0;sign=1 if bc[axis]>ac[axis] else -1
        assert abs(ac[cross]-bc[cross])<.01,(pid,'nonorthogonal')
        width=6 if pid=='lowering_bridge' else 4.8 if pid in ('tower_return','approach_trench') else 4.2
        start=list(ac);end=list(bc);start[axis]+=sign*a['size'][axis]/2;end[axis]-=sign*b['size'][axis]/2
        c=ac[cross];start[cross]=end[cross]=c;length=abs(end[axis]-start[axis]);assert length>1
        side=('E' if sign>0 else 'W') if axis==0 else ('S' if sign>0 else 'N')
        other={'E':'W','W':'E','N':'S','S':'N'}[side]
        cuts[from_id][side].append((c-width/2,c+width/2,ac[1],min(ac[1]+4.6,ac[1]+a['size'][1])))
        cuts[to_id][other].append((c-width/2,c+width/2,bc[1],min(bc[1]+4.6,bc[1]+b['size'][1])))
        middle=[(start[k]+end[k])/2 for k in range(3)];name='Link_'+pid
        deck_size=[width+.1,.5,width+.1];deck_size[axis]=length+.15
        low,high=(start,end) if start[1]<end[1] else (end,start)
        if pid=='lowering_bridge':
            deck_at=list(middle);deck_at[1]=ac[1]+8-.25
            size=list(deck_size);size[1]=.5
            sc.box('BridgeDeck',deck_at,size,'steel',typ='AnimatableBody3D',extra='script = ExtResource("bridge")\nmetadata/stage_door = "lowering_bridge"\nmetadata/auto_open = true\nmetadata/ash_bridge = true\nmetadata/stable_id = "ash_citadel_01.bridge.deck"\nmetadata/requires = '+arr(['gate_winch'])+'\nmetadata/use_anchor = Vector3(0,-8,0)')
            guard_at=list(start);guard_at[axis]+=sign*.15;guard_at[1]=ac[1]+2.3
            guard_size=[width,4.6,width];guard_size[axis]=.3
            sc.box('BridgeSafetyGate',guard_at,guard_size,'door_skin',typ='AnimatableBody3D',extra='script = ExtResource("bridge")\nlowered_offset = Vector3(0, 6, 0)\nspeed = 8.0\nwait_for_bridge = NodePath("../BridgeDeck")\nmetadata/stage_door = "bridge_safety"\nmetadata/auto_open = true\nmetadata/stable_id = "ash_citadel_01.bridge.safety_gate"')
            # The void has a closed floor and high walls. A missed step never
            # exits the world; crossing at bridge height requires the winch.
            pit=list(middle);pit[1]=-2.25;sc.box('BridgePitFloor',pit,deck_size,'damaged')
            for s in (-1,1):
                rail=list(middle);rail[cross]+=s*(width/2+.2);rail[1]=ac[1]-1
                wall=[.4,14,.4];wall[axis]=length+.4;sc.box('BridgePitWall'+str(s),rail,wall,'wall')
                deck_rail=[0,.9,0];deck_rail[cross]=s*(width/2-.08)
                rail_size=[.16,1.7,.16];rail_size[axis]=length+.1
                sc.box('Guard'+str(s),deck_rail,rail_size,'steel',True,'BridgeDeck')
            # Solid keyed leaf keeps the lowered span a causal route.
            door_at=list(end);door_at[axis]-=sign*.25;door_at[1]=bc[1]+2.3
            door_size=[width,4.6,width];door_size[axis]=.3
            sc.box('Door_bridge_gate',door_at,door_size,'door_skin',typ='AnimatableBody3D',extra='script = ExtResource("door")\nmetadata/stage_door = "bridge_gate"\nmetadata/stable_id = "ash_citadel_01.door.bridge_gate"\nmetadata/requires = '+arr(['gate_winch'])+'\nmetadata/locked_message = "Operate the gatehouse winch"\nmetadata/open_offset = Vector3(0,6,0)')
            door='Door_bridge_gate'
        else:
            if abs(end[1]-start[1])>.01:
                sc.stairs(name+'_Step_',low,high,width+.1,'stairs')
            else:
                floor=list(middle);floor[1]=ac[1]-.25;sc.box(name+'_Floor',floor,deck_size,'floor')
            roof=list(middle);roof[1]=max(start[1],end[1])+5.0
            roof_size=list(deck_size);roof_size[1]=.3;sc.box(name+'_Roof',roof,roof_size,'ceiling')
            for s in (-1,1):
                wall=list(middle);wall[cross]+=s*(width/2+.2);wall[1]=min(start[1],end[1])+(5.1+abs(end[1]-start[1]))/2
                wall_size=[.4,5.1+abs(end[1]-start[1]),.4];wall_size[axis]=length+.2
                sc.box(name+'_Wall'+str(s),wall,wall_size,'wall')
            door=None
            if shortcut or secret:
                door='Door_'+pid;door_at=list(end);door_at[axis]-=sign*.32;door_at[1]=end[1]+2.3
                size=[width,4.6,width];size[axis]=.3
                extra='script = ExtResource("door")\nmetadata/stage_door = '+quote(pid)+'\nmetadata/stable_id = '+quote(LEVEL_ID+'.door.'+pid)+'\nmetadata/requires = '+arr(requires)+'\nmetadata/open_offset = Vector3(0,6,0)\nmetadata/label = '+quote('open hidden tithe wall' if secret else 'open return hatch')
                if secret:extra+='\nmetadata/secret = true'
                if shortcut:extra+='\nmetadata/shortcut = true\nmetadata/first_open_normal = '+vec(tuple(-sign if k==axis else 0 for k in range(3)))
                sc.box(door,door_at,size,'door_skin',typ='AnimatableBody3D',extra=extra)
        points=[start,middle,end]
        for n,point in enumerate(points):
            meta='metadata/stage_nav = '+arr([from_id,to_id])+(('\nmetadata/stage_nav_door = NodePath("../'+door+'")') if door else '')
            sc.marker(f'Nav_{pid}_{n}',point,meta)
        routes.append({'id':pid,'from':from_id,'to':to_id,'width':width,'requires':requires,'shortcut':shortcut,'secret':secret,'first_open_from':from_id if shortcut else '', 'door':door,'start':start,'middle':middle,'end':end,'points':points,'traverse_points':[ac,*points,bc],'axis':axis})
    return cuts,routes

def stable_pickup(sc,name,kind,at,amount):
    sc.pickup(name,kind,at,amount)
    for i,node in enumerate(sc.nodes):
        if node.startswith('[node name="'+name+'" '):sc.nodes[i]=node.rstrip()+'\nmetadata/stable_id = '+quote(LEVEL_ID+'.pickup.'+name)+'\n'

def populate(sc,level,rooms):
    sc.node('EnemySpawns');enemies=[]
    for r in level['rooms']:
        if r['optional']:continue
        x,y,z=r['center'];sx,h,sz=r['size']
        for n in range(r['enemies']):
            kind='censer' if n%3==2 else 'ironbound'
            at=[x+((n%3)-1)*min(5,sx/4),y+.87,z-3+(n//3)*4]
            stable=f'{LEVEL_ID}.{r["id"]}.enemy.{n}'
            sc.marker('Spawn_'+str(len(enemies)),at,'metadata/stable_id = '+quote(stable)+'\nmetadata/kind = '+quote(kind)+'\nmetadata/activate_room = '+quote(r['id']),'EnemySpawns')
            enemies.append({'stable_id':stable,'kind':kind,'room':r['id'],'position':at,'arena_id':''})
    keyroom=rooms['lower_crypt'];x,y,z=keyroom['center'];key_at=[x,y+.6,z-4]
    stable_pickup(sc,'Key_gatehouse','brass_key',key_at,1)
    sc.label('CredentialSign','GATEHOUSE CREDENTIAL',(x,y+2.3,z-4),size=27)
    winch=rooms['winch'];x,y,z=winch['center'];control_at=[x+4,y+1.05,z+1]
    sc.box('Control_gate_winch',control_at,(1.2,1.5,.6),'panel',extra='metadata/stage_button = "gate_winch"\nmetadata/stable_id = "ash_citadel_01.control.gate_winch"\nmetadata/requires = '+arr(['brass'])+'\nmetadata/locked_message = "Retrieve the crypt gatehouse credential"\nmetadata/label = "LOWER INNER BRIDGE"\nmetadata/activated_message = "Bridge descending · cross to the furnace gate"')
    sc.box('WinchFace',(0,.15,.34),(.7,.5,.06),'glow',False,'Control_gate_winch')
    sc.label('WinchLabel','E · LOWER INNER BRIDGE',(0,1.1,.32),'Control_gate_winch',size=29)
    supplies=[]
    for rid,kind,amount in [('siege_approach','twin_shotgun',8),('trench','shells',8),('breach_camp','pistol',16),('lower_crypt','health',25),('stair_tower','armor',25),('battlement','shells',8),('gatehouse','rivets',24),('winch','health',25),('inner_bridge','shells',8),('cloister','rockets',3),('armory_hall','rivets',24),('furnace_gate','health',25),('quartermaster','shells',12),('watch_post','armor',25),('tithe_vault','rockets',4)]:
        r=rooms[rid];x,y,z=r['center'];at=[x+(-4 if kind=='health' else 4),y+.6,z+4]
        name='Supply_'+kind+'_'+rid;stable_pickup(sc,name,kind,at,amount)
        supplies.append({'node':name,'room':rid,'kind':kind,'amount':amount,'position':at,'optional':rooms[rid]['optional']})
    for checkpoint_id,rid,requires in [('crypt_credential','lower_crypt',['brass']),('bridge_winch','winch',['gate_winch'])]:
        r=rooms[rid];x,y,z=r['center'];at=[x-6,y+.87,z+5]
        sc.marker('Checkpoint_'+checkpoint_id,at,'metadata/checkpoint_id = '+quote(checkpoint_id)+'\nmetadata/stable_id = '+quote(LEVEL_ID+'.checkpoint.'+checkpoint_id)+'\nmetadata/requires = '+arr(requires)+'\nmetadata/radius = 1.8')
        sc.box('CheckpointMark_'+checkpoint_id,(at[0],y+.01,at[2]),(1.4,.02,1.4),'glow',False)
    out=rooms['furnace_gate'];x,y,z=out['center'];exit_at=[x,y+1,z+5]
    sc.box('ExitControl',exit_at,(1.5,1.8,.5),'glow',extra='metadata/stage_exit = true\nmetadata/stable_id = "ash_citadel_01.exit"\nmetadata/requires = '+arr(['gate_winch','visited_inner_bridge'])+'\nmetadata/locked_message = "Lower and cross the inner bridge"')
    sc.label('ExitMark','TO FURNACE CHOIR',(0,1.25,.3),'ExitControl',size=35)
    spawn=[0,.87,8]
    sc.node('Player','CharacterBody3D',props='position = '+vec(spawn)+'\nscript = ExtResource("player")\ncollision_layer = 2\ncollision_mask = 3\nfloor_snap_length = .25')
    sc.node('CollisionShape3D','CollisionShape3D','Player','shape = SubResource("player_shape")')
    sc.node('Camera3D','Camera3D','Player','position = Vector3(0,.68,0)\ncurrent = true\nfov = 82\nnear = .04\nfar = 700')
    sc.marker('PlayerStart',spawn,'')
    return enemies,supplies,key_at,control_at,exit_at,spawn

def profile_text():
    data={'level_id':LEVEL_ID,'initial_flags':{},'objectives':[
        {'requires':[],'complete_flag':'brass','text':'Descend the broken trench and recover the gatehouse credential in the lower crypt.'},
        {'requires':['brass'],'complete_flag':'gate_winch','text':'Climb the battlement to the gatehouse and lower the inner bridge.'},
        {'requires':['gate_winch'],'complete_flag':'finished','text':'Cross the lowered bridge and enter the Furnace Choir.'}],
        'controls':{'gate_winch':{'requires':['brass'],'sets':['gate_winch']}},
        'keys':{'brass':{'requires':[],'sets':['brass','brass_key']}},
        'encounters':{},'exit_requires':['gate_winch','visited_inner_bridge']}
    out='[gd_resource type="Resource" script_class="StageObjectiveProfile" load_steps=2 format=3]\n[ext_resource type="Script" path="res://scripts/stage_objective_profile.gd" id="profile_script"]\n[resource]\nscript = ExtResource("profile_script")\n'
    for key,value in data.items():out+=key+' = '+('Array[Dictionary]('+json.dumps(value)+')' if key=='objectives' else arr(value) if key=='exit_requires' else json.dumps(value))+'\n'
    return out

def author():
    rooms_list=room_program();rooms={r['id']:r for r in rooms_list};assert len(rooms)==len(rooms_list)
    level={'id':LEVEL_ID,'title':'Ash Approach','theme':'ash_citadel','design_v15':True,'design_version':15,
           'objective':'Infiltrate the gatehouse, lower the inner bridge and enter Furnace Choir.',
           'rooms':rooms_list,'object_program':{r['id']:r['objects'] for r in rooms_list},
           'spawn_room':'siege_approach','keys':[{'kind':'brass_key','room':'lower_crypt'}],
           'controls':[{'id':'gate_winch','room':'winch','requires':['brass'],'sets':['gate_winch']}],
           'exit':{'room':'furnace_gate','requires':['gate_winch','visited_inner_bridge']},'secret_rooms':['tithe_vault'],
           'optional_rooms':['quartermaster','watch_post'],'next_level':'ash_citadel_02'}
    sc=base.Scene({'id':'ash_citadel','title':'Ash Approach'});sc.stage=level
    sc.ext.append('[ext_resource type="Script" path="res://scripts/stage_objective_profile.gd" id="profile_script"]')
    sc.ext.append('[ext_resource type="Resource" path="res://resources/campaign/v15/ash_citadel_01-objectives.tres" id="ash_profile"]')
    sc.ext.append('[ext_resource type="Script" path="res://scripts/ash_bridge_v15.gd" id="bridge"]')
    atlas='res://assets/materials/architecture-v2/ash_citadel-atlas.png'
    for index,name in enumerate(('wall','floor','ceiling','steel','grate','door_skin','panel','damaged','stairs','invasion','banner','pillar')):
        sc.board_material(name,atlas,[(index%4)*384,(index//4)*341,384,341])
    sc.mat('glow',(1,.3,.04,1),1.4);sc.mat('cloth',(.29,.04,.025,1));sc.mat('orange',(.85,.26,.03,1),.4)
    sc.sub.append('[sub_resource type="Environment" id="environment"]\nbackground_mode = 1\nbackground_color = Color(.035,.022,.018,1)\nambient_light_source = 2\nambient_light_color = Color(.47,.37,.31,1)\nambient_light_energy = .32\ntonemap_mode = 0\n')
    sc.node('WorldEnvironment','WorldEnvironment',props='environment = SubResource("environment")')
    cuts,routes=portal_geometry(sc,level,rooms)
    # Direct line from the player arrival (0, 1.55, 8) to the actual moving
    # bridge deck: the high east aperture is above an unjumpable masonry sill.
    # It exposes the gate mechanism before the trench route folds away.
    cuts['siege_approach']['E'].append((9.0,13.4,2.5,7.0))
    for r in rooms_list:
        room_box(sc,r,cuts[r['id']])
        functional_fittings(sc,r)
    sc.box('BridgeVistaSill',(13.77,2.57,11.2),(.16,.14,4.5),'steel',False)
    sc.box('BridgeVistaLintel',(13.77,6.95,11.2),(.16,.14,4.5),'steel',False)
    sc.label('BridgeVistaSign','INNER BRIDGE / GATEHOUSE WINCH',(13.68,3.1,10.9),rotation=(0,-90,0),size=24)
    art.decorate(sc,level)
    enemies,supplies,key_at,control_at,exit_at,spawn=populate(sc,level,rooms)
    level['spawn_position']=spawn;level['portals']=routes;level['enemy_total']=len(enemies)
    route=deepcopy(level);route['rooms']=rooms;route['enemy_spawns']=enemies
    route['keys'][0].update(node='Key_gatehouse',position=key_at)
    route['controls'][0].update(node='Control_gate_winch',position=control_at)
    route['exit'].update(node='ExitControl',position=exit_at)
    route['entry_weapon']='twin_shotgun';route['architecture_version']=15
    route['supplies']=supplies
    outputs={SCENE:append_root(sc,level),OUT/(LEVEL_ID+'-layout.json'):json.dumps(level,indent=2)+'\n',OUT/(LEVEL_ID+'-route.json'):json.dumps(route,indent=2)+'\n',V15/(LEVEL_ID+'-objectives.tres'):profile_text()}
    for path,body in outputs.items():path.parent.mkdir(parents=True,exist_ok=True);path.write_text(body)
    print(json.dumps({'level':LEVEL_ID,'rooms':len(rooms),'portals':len(routes),'enemies':len(enemies),'height_bands':sorted({r['center'][1] for r in rooms_list}),'outputs':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in outputs}},indent=2))

if __name__=='__main__':author()
