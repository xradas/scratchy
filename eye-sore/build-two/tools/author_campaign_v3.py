"""Author nine campaign maps from the proven physical stage primitives.

The expansion-v1 author and its source layouts stay untouched.  Each map is
generated in a private temporary project tree, then published with its own
catalog, layout and route.  The old stage id remains the art/enemy theme.
"""
from __future__ import annotations

from copy import deepcopy
import json
import math
from pathlib import Path
import tempfile

import author_themed_stages as base

ROOT = Path(__file__).resolve().parents[1]
SOURCE = {stage["id"]: stage for stage in json.loads((ROOT / "docs/expansion-v1/layouts.json").read_text())["stages"]}
CONTRACT = {stage["id"]: stage for stage in json.loads((ROOT / "docs/expansion-v1/contract.json").read_text())["stages"]}
OUT = ROOT / "resources/campaign"
SCENES = ROOT / "scenes/campaign"

# The first acquisition in each weapon chapter is visible on the arrival axis.
# Arena caches remain as explicit ambush lures and ammunition refreshes.
LEVELS = [
    ("pale_ward_01", "Intake", "Ward arrival / sunken triage", 1.00, 1.00, False, "twin_shotgun", ("ARRIVALS", "TRIAGE SUMP", "ISOLATION", "C3 EXIT")),
    ("pale_ward_02", "Containment", "Reservoir loop / surgical galleries", 1.16, 1.07, True, "rivet_cannon", ("RESERVOIR", "SURGICAL GALLERY", "RIVET CACHE", "WET TRANSFER")),
    ("pale_ward_03", "Breach", "Specimen silo / occult fissure", 1.05, 1.18, False, "siege_launcher", ("SILO ACCESS", "CULTURE SHAFT", "SPECIMEN BREACH", "FISSURE EXIT")),
    ("ash_citadel_01", "Ash Approach", "Rampart / cloister courtyard", 1.13, .96, True, "twin_shotgun", ("RAMPART", "CLOISTER COURT", "CHAIN HOUSE", "ASH GATE")),
    ("ash_citadel_02", "Furnace Choir", "Altar / furnace rings", .96, 1.12, False, "rivet_cannon", ("CHOIR ENTRY", "FURNACE RING", "EMBER ALTAR", "VESPER DOOR")),
    ("ash_citadel_03", "Black Reliquary", "Upper vault / civil conduit", 1.09, 1.18, True, "siege_launcher", ("LOWER CRYPT", "RELIQUARY", "UPPER VAULT", "CIVIL CONDUIT")),
    ("occupied_line_01", "Dead Platform", "Track beds / platform crossings", 1.17, .97, False, "twin_shotgun", ("TRACK ARRIVAL", "DEAD PLATFORM", "SIGNAL HOUSE", "CIVIC EXIT")),
    ("occupied_line_02", "Civic Lockdown", "Admin hub / mezzanine returns", .96, 1.16, True, "rivet_cannon", ("CIVIC ENTRY", "ADMIN HUB", "LOCKDOWN MEZZANINE", "TRANSIT SEAL")),
    ("occupied_line_03", "Occupation Engine", "Reactor / turbine courts / riser", 1.11, 1.11, False, "siege_launcher", ("ENGINE ACCESS", "TURBINE COURT", "REACTOR RISER", "FINAL PLATFORM")),
]

# Different route graphs, not a single stage copied nine times. Required
# arena/key/exit roles persist, while the links and optional detours change.
OMIT = {
    "pale_ward_01": set(),
    "pale_ward_02": {"key_wing", "maintenance", "armory", "pump_room", "secret_two", "observation"},
    "pale_ward_03": {"service", "return_store", "armory", "pump_room", "observation", "secret_one"},
    "ash_citadel_01": {"maintenance", "pump_room", "secret_two"},
    "ash_citadel_02": {"return_store", "supplies", "maintenance", "armory", "observation", "secret_one"},
    "ash_citadel_03": {"key_wing", "red_wing", "secret_two"},
    "occupied_line_01": {"service", "return_store", "pump_room", "secret_two"},
    "occupied_line_02": {"red_wing", "armory", "maintenance", "secret_one", "secret_two"},
    "occupied_line_03": {"key_wing", "return_store", "red_wing", "armory", "supplies", "maintenance", "secret_two", "observation"},
}
EXIT_SIGNS = {
    "pale_ward_01": "TO RESERVOIR / CONTAINMENT",
    "pale_ward_02": "TO SPECIMEN SILO / BREACH",
    "pale_ward_03": "BURIED OCCULT GATE / ASH APPROACH",
    "ash_citadel_01": "TO FURNACE CHOIR",
    "ash_citadel_02": "TO BLACK RELIQUARY",
    "ash_citadel_03": "CIVIL CONDUIT / DEAD PLATFORM",
    "occupied_line_01": "TO CIVIC LOCKDOWN",
    "occupied_line_02": "TO OCCUPATION ENGINE",
    "occupied_line_03": "ENGINE SHUTDOWN / CAMPAIGN END",
}


def augment(sc: base.Scene, level_id: str, name: str, weapon: str) -> None:
    """A few large, navigable silhouettes make each campaign space identifiable."""
    rooms = {r["id"]: r for r in sc.stage["rooms"]}
    entry = rooms["entry"]; ex, ey, ez = entry["center"]
    # Clearly signed, guaranteed pickup directly on the initial corridor.
    if level_id.startswith("pale_ward"):
        index = int(level_id[-2:])
        words = {1: "TWIN SHOTGUN", 2: "RIVET CANNON", 3: "SIEGE LAUNCHER"}
        sc.cylinder("FirstGunCachePlinth", (ex, ey + .12, ez + 4), 1.15, .24, "panel", False)
        sc.pickup("FirstGunCache", weapon, (ex, ey + .65, ez + 4), 18 if index == 1 else 96 if index == 2 else 8)
        sc.downlight("FirstGunCacheLight", (ex, ey + entry["size"][1] - .5, ez + 4), 8, 12)
        sc.label("FirstGunCacheSign", "%02d  %s  [%d] TAKE WEAPON" % (index, words[index], index + 3), (ex, ey + 2.6, ez + 4), size=45)
    for rid, text in [("entry", name.upper()), ("key_console", "BRASS KEY / RETURN LOOP"), ("red_console", "RED KEY / RETURN LOOP"), ("exit_gallery", EXIT_SIGNS[level_id])]:
        r = rooms[rid]; x, y, z = r["center"]
        sc.label("CampaignSign_" + rid, text, (x, y + 3.8, z + r["size"][2] / 2 - 1.2), size=39)
    arena = rooms["arena_one"]; x, y, z = arena["center"]
    second = rooms["arena_two"]; x2, y2, z2 = second["center"]
    finale = rooms["final_arena"]; xf, yf, zf = finale["center"]
    chapter, number = level_id.rsplit("_", 1); number = int(number)
    if chapter == "pale_ward":
        if number == 1:
            for side in (-1, 1):
                sc.box("TriageBed" + str(side), (x + side * 12, y + .55, z + 16), (2.6, 1.1, 5), "steel")
                sc.box("TriageCurtain" + str(side), (x + side * 12, y + 3.3, z + 16), (.09, 3, 5), "cloth", False)
        elif number == 2:
            for side in (-1, 1):
                sc.cylinder("ReservoirTank" + str(side), (x + side * 13, y + 1.1, z + 16), 2.1, 2.2, "glass")
        else:
            for side in (-1, 1):
                sc.cylinder("SiloVessel" + str(side), (x + side * 13, y + 3, z + 16), 2.3, 6, "glass")
            sc.box("FissureMouth", (xf + 10, yf + .6, zf), (2, 1.2, 10), "invasion", False)
    elif chapter == "ash_citadel":
        if number == 1:
            for side in (-1, 1): sc.box("Rampart" + str(side), (x + side * 14, y + 1, z + 16), (2, 2, 5), "wall")
        elif number == 2:
            for side in (-1, 1):
                sc.cylinder("Furnace" + str(side), (x + side * 13, y + 1.8, z + 16), 2.2, 3.6, "damaged")
                sc.light("FurnaceFire" + str(side), (x + side * 13, y + 3, z + 16), (1, .22, .02, 1), 4, 12)
        else:
            for side in (-1, 1): sc.box("VaultReliquary" + str(side), (xf + side * 12, yf + 1.6, zf + 16), (2.5, 3.2, 4), "pillar")
    else:
        if number == 1:
            for side in (-1, 1): sc.box("TrackBed" + str(side), (x + side * 12, y + .04, z), (2, .08, 22), "recess", False)
        elif number == 2:
            for side in (-1, 1): sc.box("AdminKiosk" + str(side), (x + side * 13, y + 1.2, z + 16), (2.5, 2.4, 4), "steel")
        else:
            for side in (-1, 1):
                sc.cylinder("Turbine" + str(side), (xf + side * 12, yf + 1.6, zf + 16), 2.1, 3.2, "steel")
                sc.light("TurbineCharge" + str(side), (xf + side * 12, yf + 3, zf + 16), (.1, .8, 1, 1), 3, 12)


Scene = base.Scene
P = ROOT
vec, quote, arr = base.vec, base.quote, base.arr
decorate, architecture, closet = base.decorate, base.architecture, base.closet

def author_campaign(stage, contract):
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
    optional=stage.get('optional_rooms', ['supplies','maintenance','pump_room','armory'])
    for rid,r in rooms.items():
        x,y,z=r['center'];sx,h,sz=r['size'];sc.marker('Room_'+rid,(x,y+h/2,z),'metadata/stage_room = '+quote(rid)+'\nmetadata/stage_label = '+quote(r['label'])+'\nmetadata/room_bounds = '+vec((sx/2,h/2+1,sz/2))+'\nmetadata/optional = '+str(rid in optional).lower()+(('\nmetadata/arena_id = '+quote(r['arena_id'])) if r['arena_id'] else ''))
        if stage['id']=='pale_ward' and rid=='arena_one':
            # Real recessed wet sump: four rim slabs and a lower, solid basin.
            # Campaign rooms vary in width. Both full-length rims reach their
            # authored walls, and basin rims overlap them by 2 m so moving
            # CharacterBody enemies cannot drop through a four-centimetre seam.
            for suffix,px,pz,wx,wz in [('West',x+3-sx/4,z,sx/2+6,sz),('East',x+5+sx/4,z,sx/2-10,sz),('North',x+8,z-(sz/2+8.5)/2,8,sz/2-8.5),('South',x+8,z+(sz/2-3.5)/2,8,sz/2+3.5)]:
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
    for rid,kind,amount in [(rid,kind,amount) for rid,kind,amount in [('spine','rockets',2),('key_wing','rivets',48)] if rid in rooms]:
        r=rooms[rid];x,y,z=r['center'];sc.pickup('V2Supply_'+rid,kind,(x,y+.5,z),amount)
    for b in stage['buttons']:
        r=rooms[b['room']];x,y,z=r['center'];pp=(x+4.5,y+1.05,z-r['size'][2]/2+3)
        sc.box('Button_'+b['id'],pp,(1.1,1.5,.5),'steel',extra='metadata/stage_button = '+quote(b['sets'])+'\nmetadata/requires = '+arr(['clear_'+b['arena']])+'\nmetadata/locked_message = "Clear this arena to enable its control"\nmetadata/label = '+quote(b['label'])+'\nmetadata/activated_message = '+quote(b['label']+' · engaged'))
        sc.box('Face',(0,.12,.29),(.55,.48,.08),'brass' if b['id']=='breaker' else 'red' if b['id']=='release' else 'glow',False,'Button_'+b['id'])
        sc.label('Mark',b['label'],(0,1.1,.28),'Button_'+b['id'],size=30)
    for k in stage['keys']:
        r=rooms[k['room']];x,y,z=r['center'];sc.pickup('Key_'+k['id'],k['id'],(x,y+.6,z-3))
    # Required-route supplies match coordinator totals, independent of secrets.
    supply_rooms=stage.get('supply_rooms', ['entry','service','arena_one','key_wing','key_console','return_store','spine','arena_two','red_wing','red_console','final_arena'])
    budgets={'shells':stage['supplies']['main_route_shells'],'pistol':stage['supplies']['main_route_pistol'],'health':stage['supplies']['main_route_health'],'armor':stage['supplies']['main_route_armor']}
    for kind,total in budgets.items():
        for index,rid in enumerate(supply_rooms):
            amount=total//len(supply_rooms)+(1 if index<total%len(supply_rooms) else 0);r=rooms[rid];x,y,z=r['center'];k=list(budgets).index(kind)
            sc.pickup('Supply_'+kind+'_'+rid,kind,(x+(-.8 if k%2==0 else .8),y+.5,z+r['size'][2]/2-3-k//2*1.2),amount)
    for rid in optional+stage.get('secret_rooms', ['secret_one','secret_two']):
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


def make_stage(level):
    level_id, title, subtitle, width, depth, mirror, weapon, signs = level
    theme = level_id.rsplit("_", 1)[0]
    stage = deepcopy(SOURCE[theme]); contract = deepcopy(CONTRACT[theme])
    for room in stage["rooms"]:
        room["center"][0] *= width * (-1 if mirror else 1)
        room["center"][2] *= depth
        room["size"][0] *= width
        room["size"][2] *= depth
    stage["spawn_local"][2] *= depth
    omitted = OMIT[level_id]
    # Move the actual key chamber into the vacated wing to create a direct
    # arena-to-key spoke. Its return link then becomes a different physical loop.
    by_id = {r["id"]: r for r in stage["rooms"]}
    if "key_wing" in omitted:
        by_id["key_console"]["center"][2] = by_id["arena_one"]["center"][2]
    if level_id == "pale_ward_03":
        by_id["key_wing"]["center"][0] += 5
        by_id["key_console"]["center"][0] += 5
    if "red_wing" in omitted:
        by_id["red_console"]["center"][2] = by_id["arena_two"]["center"][2]
    if level_id in ("pale_ward_02", "ash_citadel_02", "occupied_line_02"):
        # L-shaped main route: the first arena leads down the spine, turns
        # sideways into court two, then runs south again to the finale.
        spine = by_id["spine"]; court = by_id["arena_two"]
        east = level_id != "ash_citadel_02"
        bend = (1 if east else -1) * (spine["size"][0] / 2 + court["size"][0] / 2 + 7)
        court["center"][0] = spine["center"][0] + bend
        court["center"][2] = spine["center"][2]
        final = by_id["final_arena"]
        final["center"][0] = court["center"][0]
        final["center"][2] = court["center"][2] - court["size"][2] / 2 - final["size"][2] / 2 - 13
        ending = by_id["exit_gallery"]
        ending["center"][0] = final["center"][0]
        ending["center"][2] = final["center"][2] - final["size"][2] / 2 - ending["size"][2] / 2 - 9
        if "observation" not in omitted:
            lookout = by_id["observation"]
            lookout["center"][0] = final["center"][0] + final["size"][0] / 2 + lookout["size"][0] / 2 + 6
            lookout["center"][2] = final["center"][2]
        if "red_wing" not in omitted:
            wing = by_id["red_wing"]
            wing["center"][0] = court["center"][0] + (1 if east else -1) * (court["size"][0] / 2 + wing["size"][0] / 2 + 7)
            wing["center"][2] = court["center"][2]
            red = by_id["red_console"]
            red["center"][0] = wing["center"][0]
            red["center"][2] = wing["center"][2] - wing["size"][2] / 2 - red["size"][2] / 2 - 9
        else:
            red = by_id["red_console"]
            red["center"][0] = court["center"][0] + court["size"][0] / 2 + red["size"][0] / 2 + 7
            red["center"][2] = court["center"][2]
    stage["rooms"] = [r for r in stage["rooms"] if r["id"] not in omitted]
    stage["portals"] = [p for p in stage["portals"] if p["from"] not in omitted and p["to"] not in omitted]
    def link(a, b, gate="", requires=(), shortcut=False, secret=False):
        stage["portals"].append({"from": a, "to": b, "width": 5.2, "gate": gate, "requires": list(requires), "secret": secret, "shortcut": shortcut, "lift": False})
    if "service" in omitted: link("entry", "arena_one", "entry_gate" if theme == "pale_ward" else "")
    if "key_wing" in omitted:
        link("arena_one", "key_console", "breaker", ["breaker"])
        if "return_store" not in omitted: link("key_console", "return_store")
    if "spine" in omitted: link("arena_one", "arena_two", "brass_gate", ["breaker", "brass_key"])
    if "red_wing" in omitted:
        link("arena_two", "red_console", "release", ["release"])
        if "armory" not in omitted: link("red_console", "armory", "shortcut_two", [], True)
    if level_id == "occupied_line_03": link("entry", "secret_one", "secret_one", [], secret=True)
    stage["enemy_counts"] = {rid: count for rid, count in stage["enemy_counts"].items() if rid not in omitted}
    chapter_index = int(level_id[-2:])
    for arena, base_count in (("arena_one", 4), ("arena_two", 4), ("final_arena", 5)):
        stage["enemy_counts"][arena] = min(8, base_count + chapter_index + (1 if theme == "occupied_line" else 0))
    stage["enemy_counts"]["entry"] = 1 + chapter_index
    stage["optional_rooms"] = [rid for rid in ("supplies", "maintenance", "pump_room", "armory") if rid not in omitted]
    stage["secret_rooms"] = [rid for rid in ("secret_one", "secret_two") if rid not in omitted]
    stage["supply_rooms"] = [rid for rid in ("entry", "service", "arena_one", "key_wing", "key_console", "return_store", "spine", "arena_two", "red_wing", "red_console", "final_arena") if rid not in omitted]
    # Three bait traps remain active on each map. The chapter's first owned gun
    # is refreshed with ammo; acquisition of new guns follows the Ward arc.
    stage["weapon_cache"] = {rid: {"weapon": weapon, "ammo": 18 if weapon == "twin_shotgun" else 96 if weapon == "rivet_cannon" else 8} for rid in ("arena_one", "arena_two", "final_arena")}
    stage["rooms"][0]["label"] = signs[0]
    for rid, label in zip(("arena_one", "arena_two", "final_arena"), signs[1:]):
        next(r for r in stage["rooms"] if r["id"] == rid)["label"] = label
    next(r for r in stage["rooms"] if r["id"] == "exit_gallery")["label"] = EXIT_SIGNS[level_id]
    # Key and route names remain globally clear regardless of local fiction.
    stage["buttons"][0]["label"] = "ENABLE BRASS ACCESS"
    stage["buttons"][1]["label"] = "RELEASE RED ACCESS"
    stage["buttons"][2]["label"] = "OPEN SECTOR EXIT"
    stage["campaign_level_id"] = level_id
    return stage, contract


def main():
    OUT.mkdir(parents=True, exist_ok=True); SCENES.mkdir(parents=True, exist_ok=True)
    catalog = {"chapters": []}
    for theme, heading in (("pale_ward", "Pale Ward"), ("ash_citadel", "Ash Citadel"), ("occupied_line", "Occupied Line")):
        catalog["chapters"].append({"id": theme, "title": heading, "levels": []})
    original_scene = Scene
    original_root = P
    original_base_root = base.P
    try:
        with tempfile.TemporaryDirectory(prefix="campaign-author-") as temp:
            staging = Path(temp)
            (staging / "assets").symlink_to(ROOT / "assets", target_is_directory=True)
            (staging / "resources/stages").mkdir(parents=True)
            (staging / "scenes/campaign").mkdir(parents=True)
            globals()["P"] = staging
            base.P = staging
            for level in LEVELS:
                level_id, title, subtitle, *_ = level
                theme = level_id.rsplit("_", 1)[0]
                stage, contract = make_stage(level)
                contract["scene"] = "res://scenes/campaign/" + level_id + ".tscn"
                contract["title"] = title
                class CampaignScene(original_scene):
                    def box(self, name, pos, size, mat='wall', solid=True, parent='.', extra='', typ=None, rot=None, hit_material=None):
                        # Painted track lines are cues, not knee-high barriers.
                        if self.stage['id'] == 'occupied_line' and '_Track' in name:
                            solid = False
                        return super().box(name, pos, size, mat, solid, parent, extra, typ, rot, hit_material)
                    def save(self, path):
                        augment(self, level_id, title, level[6])
                        super().save(path)
                globals()["Scene"] = CampaignScene
                author_campaign(stage, contract)
                scene_text = (staging / contract["scene"].removeprefix("res://")).read_text()
                scene_text = scene_text.replace('metadata/stage_title = ' + json.dumps(title), 'metadata/stage_title = ' + json.dumps(title) + '\nmetadata/campaign_level_id = ' + json.dumps(level_id) + '\nmetadata/campaign_chapter = ' + json.dumps(theme), 1)
                (SCENES / (level_id + ".tscn")).write_text(scene_text)
                route = json.loads((staging / "resources/stages" / (theme + "-route.json")).read_text())
                route["id"] = level_id; route["theme"] = theme
                route["title"] = title; route["subtitle"] = subtitle
                route["entry_weapon"] = level[6] if level_id.startswith("pale_ward") else None
                route["combat_flanks"] = {
                    rid: [
                        [r["center"][0] + side * lane, r["center"][1], r["center"][2] + offset]
                        for side in (-1, 1)
                        for lane, offset in [(4.3, 0), (r["size"][0] / 2 - (5 if theme == 'pale_ward' and rid == 'final_arena' and r["size"][0] < 36 else 7), 0)]
                        + [(r["size"][0] / 2 - (5 if theme == 'pale_ward' and rid == 'final_arena' and r["size"][0] < 36 else 7), slot) for slot in (-9, -3, 3, 9)]
                    ]
                    for rid, r in route["rooms"].items() if r["arena_id"]
                }
                (OUT / (level_id + "-route.json")).write_text(json.dumps(route, indent=2) + "\n")
                stage["id"] = level_id; stage["theme"] = theme; stage["title"] = title; stage["subtitle"] = subtitle
                (OUT / (level_id + "-layout.json")).write_text(json.dumps(stage, indent=2) + "\n")
                chapter = next(c for c in catalog["chapters"] if c["id"] == theme)
                chapter["levels"].append({"id": level_id, "title": title, "scene": contract["scene"], "theme": theme, "subtitle": subtitle})
                print(level_id, len(stage["rooms"]), len(stage["portals"]))
    finally:
        globals()["Scene"] = original_scene; globals()["P"] = original_root; base.P = original_base_root
    (OUT / "catalog.json").write_text(json.dumps(catalog, indent=2) + "\n")


if __name__ == "__main__": main()
