"""Pale Ward environment pass, applied to the authored v13 scenes before serialization.

The playable floor, portal cuts and objective graph remain the v13 authority.
This module only adds supported architectural dressing, an open bridge vista,
and a small set of deliberately damaged light fixtures.
"""
from __future__ import annotations

import re


ANGLED_ROOMS = {
    "pale_ward_01": ("generator", "imaging", "decon", "processing"),
    "pale_ward_02": ("cultures", "waste_lab", "reservoir", "discharge"),
    "pale_ward_03": ("upper_gallery", "specimens", "cultivation", "rupture"),
}
DAMAGED_ROOMS = {
    "pale_ward_01": ("maintenance", "generator", "decon"),
    "pale_ward_02": ("filters", "reservoir", "outfall"),
    "pale_ward_03": ("service_descent", "crossfire", "rupture", "bridge"),
}


def _remove_roots(sc, names):
    """Remove complete generated nodes, including their visual/collision children."""
    names = set(names)
    sc.nodes = [block for block in sc.nodes if not any(
        re.match(r'^\[node name="[^"]+"[^\n]*parent="' + re.escape(name) + r'(?:/[^\"]*)?"\]', block)
        or re.match(r'^\[node name="' + re.escape(name) + r'"[^\n]*parent="\."\]', block)
        for name in names)]
    sc.geometry = [item for item in sc.geometry if item['name'] not in names]


def _outline_buttresses(sc, level, rooms):
    """Diagonal wall masses break the repeated rectangular room silhouette.

    They stay in the outer 2.2 m of each room, away from the central fight and
    the middle of every portal. The prism itself is the shared visual/collider.
    """
    for rid in ANGLED_ROOMS[level['id']]:
        room = rooms[rid]
        x, y, z = room['center']; sx, h, sz = room['size']
        for side in (-1, 1):
            # A short six-sided mass reads as a cut-back wall rather than a
            # square crate, while retaining a broad central path.
            at = (x + side * (sx / 2 - 1.15), y, z + sz * .21)
            shape = [(-side*1.0,-1.2), (side*.55,-1.2), (side*1.15,-.45),
                     (side*1.15,.45), (side*.55,1.2), (-side*1.0,1.2)]
            if side < 0: shape.reverse()
            sc.prism('V19AngularWall_'+rid+'_'+str(side), at, shape,
                     min(h,4.8), sc.materials['utility' if room['function'] in
                     {'utility','reservoir','specimen_silo','decontamination','security'}
                     else 'triage']['wall'])
            sc.box('V19AngleCrown_'+rid+'_'+str(side),
                   (at[0],y+min(h,4.8)+.10,at[2]),(2.3,.2,2.55),'steel',False)


def _ground_fittings(sc, level, rooms):
    # The shared fixture recipe starts at 1.25 m above its root. Ward 02
    # already has a bespoke cabinet/feed. Match that physical support here.
    if level['id']=='pale_ward_02': return
    for room in rooms.values():
        for obj in room['objects']:
            if obj['type'] not in ('filter_unit','pipe_manifold'): continue
            root='RoomProp_'+(level['id']+'.'+obj['id']).replace('.','_')
            if obj['type']=='filter_unit':
                sc.box('V19FloorCabinet',(0,.65,0),(1.1,1.3,.55),'steel',parent=root,
                       hit_material='armor')
                sc.box('V19ServicePlinth',(0,.08,0),(1.28,.16,.68),'panel',parent=root,
                       hit_material='armor')
            else:
                for side in (-1,1):
                    sc.cylinder('V19FloorFeed'+str(side),(side*.36,.64,0),.10,1.28,
                                'steel',True,root)
                    sc.box('V19FeedShoe'+str(side),(side*.36,.09,0),(.31,.18,.31),
                           'panel',parent=root,hit_material='armor')


def _bridge_vista(sc, level, rooms):
    if level['id']!='pale_ward_03': return
    bridge=rooms['bridge']; x,y,z=bridge['center']; sx,h,sz=bridge['size']
    # Keep the real floor and the original mouth cuts. Replace only the room's
    # enclosing roof and wall spans with collidable waist-high parapets.
    old=[item for item in sc.geometry if item['name'].startswith('bridge_Wall_')]
    roof=[item['name'] for item in sc.geometry if item['name']=='bridge_Roof'
          or item['name'].startswith('bridge_LoweredCeiling')]
    _remove_roots(sc,[item['name'] for item in old]+roof)
    for index,item in enumerate(old):
        bottom=item['position'][1]-item['size'][1]/2
        if bottom>y+.05: continue  # lintel above a portal; leave its mouth open
        pos=list(item['position']);pos[1]=y+.72
        size=list(item['size']);size[1]=1.44
        guard='V19BridgeParapet'+str(index)
        sc.box(guard,pos,size,'v13_vista_glass',hit_material='armor')
        for label,height in (('Foot',-.66),('Handrail',.66)):
            rail=list(size);rail[1]=.10
            sc.box(label,(0,height,0),rail,'steel',False,guard)
    # Roof-mounted services would otherwise appear to float against the sky.
    overhead=[item['name'] for item in sc.geometry if item['name'].startswith(
        ('bridge_Duct','bridge_CeilingRib'))]
    _remove_roots(sc,overhead)
    # The catching slab covers only the open bridge footprint. A non-solid
    # detection volume covers the basin; reaching it inflicts damage and
    # restores the player to the safe bridge deck.
    sc.box('V19WasteCatch',(x,y-7.7,z),(sx-.5,.6,sz-.5),'damaged',hit_material='hard')
    sc.ext.append('[ext_resource type="Shader" path="res://shaders/ward_toxic_v19.gdshader" id="v19_toxic_shader"]')
    sc.sub.append('[sub_resource type="ShaderMaterial" id="v19_toxic"]\n'
                  'shader = ExtResource("v19_toxic_shader")\n')
    sc.box('V19ToxicSurface',(x,y-4.2,z),(147.4,.025,93.4),'v19_toxic',False)
    sc.ext.append('[ext_resource type="Script" path="res://scripts/bridge_waste_v19.gd" id="v19_waste_script"]')
    sc.sub.append('[sub_resource type="BoxShape3D" id="v19_waste_shape"]\n'
                  'size = Vector3(147,0.8,93)\n')
    sc.node('V19WasteHazard','Area3D',props='position = '+
            'Vector3('+', '.join(map(str,(x,y-5.8,z)))+')\n'
            'script = ExtResource("v19_waste_script")\n'
            'safe_position = Vector3('+', '.join(map(str,(x,y+.87,z)))+')\n'
            'collision_layer = 0\ncollision_mask = 2\n')
    sc.node('Collision','CollisionShape3D','V19WasteHazard',
            'shape = SubResource("v19_waste_shape")')
    for side in (-1,1):
        for end in (-1,1):
            px=x+side*46; pz=z+end*29
            sc.box('V19WasteTower'+str(side)+str(end),(px,y-2.4,pz),
                   (6.4,10.6,6.4),'steel')
            sc.box('V19TowerCap'+str(side)+str(end),(px,y+3,pz),
                   (8,.28,8),'damaged')
    for end in (-1,1):
        pz=z+end*sz*.29
        for side in (-1,1):
            px=x+side*(sx/2-.7)
            sc.box('V19BridgeGantryPost'+str(end)+str(side),(px,y+2.8,pz),
                   (.38,5.6,.38),'steel')
        sc.box('V19BridgeGantry'+str(end),(x,y+5.6,pz),(sx-.6,.36,.42),'steel')
        for side in (-1,1):
            lx=x+side*4.5
            # These actual visible heads cast overlapping pools over the
            # deck and rail, so the exterior stays dim without going black.
            sc.lamp('V19BridgeDeckLamp'+str(end)+str(side),
                    (lx,y+5.48,pz),bridge,'surgical',energy=3.6,reach=13)
            sc.box('V19BridgeLampBrace'+str(end)+str(side),
                   (lx,y+5.54,pz),(.62,.18,.62),'steel',False)
        for side in (-1,1):
            marker_x=x+side*(sx/2-.12)
            sc.box('V19BridgeRailMarker'+str(end)+str(side),
                   (marker_x,y+1.41,pz),(.10,.08,.48),'glow',False)
            sc.box('V19BridgeFloodMount'+str(end)+str(side),
                   (x+side*(sx/2-.38),y+1.75,pz),(.42,.42,.30),'steel')
            sc.lamp('V19BridgeFlood'+str(end)+str(side),
                    (x+side*(sx/2-.60),y+1.75,pz),bridge,'warning',
                    rotation=(0,90*side,0),energy=2.8,reach=13)
    # Godot's procedural sky gives the opening an actual horizon rather than
    # the former flat black environment colour.
    sky_material='[sub_resource type="ProceduralSkyMaterial" id="v19_sky_material"]\n' \
                 'sky_top_color = Color(0.035,0.055,0.068,1)\n' \
                 'sky_horizon_color = Color(0.17,0.22,0.18,1)\n' \
                 'ground_bottom_color = Color(0.018,0.027,0.025,1)\n' \
                 'ground_horizon_color = Color(0.08,0.105,0.08,1)\n' \
                 'use_debanding = true\n'
    sky='[sub_resource type="Sky" id="v19_sky"]\nsky_material = SubResource("v19_sky_material")\n'
    for index,resource in enumerate(sc.sub):
        if resource.startswith('[sub_resource type="Environment" id="environment"]'):
            sc.sub[index:index]=[sky_material,sky]
            index+=2
            sc.sub[index]=resource.replace('background_mode = 1','background_mode = 2\nsky = SubResource("v19_sky")')
            break


def _lights(sc, level):
    # Lower ambient so the fixture pools and damaged light cycles are legible.
    ambient={'pale_ward_01':.23,'pale_ward_02':.20,'pale_ward_03':.17}[level['id']]
    for index,resource in enumerate(sc.sub):
        if resource.startswith('[sub_resource type="Environment" id="environment"]'):
            sc.sub[index]=re.sub(r'ambient_light_energy = [0-9.]+',
                                 'ambient_light_energy = '+str(ambient),resource)
            break
    damaged=set(DAMAGED_ROOMS[level['id']])
    for index,block in enumerate(sc.nodes):
        if 'instance=ExtResource("v13_fixture")' not in block: continue
        match=re.search(r'metadata/room_id = "([^"]+)"',block)
        if not match or match.group(1) not in damaged: continue
        # Only one lamp per room fails. Others preserve minimum navigation light.
        if 'name="Fixture_'+match.group(1)+'_0"' not in block: continue
        block=block.replace('damaged = false','damaged = true')
        block+='flicker_period = 6.7\nflicker_offset = '+str(len(match.group(1))*.37)+'\nflicker_depth = 0.62\n'
        sc.nodes[index]=block
        for record in sc.lights:
            if record['id']=='Fixture_'+match.group(1)+'_0':record['damaged']=True


def apply(sc, level, rooms):
    _outline_buttresses(sc,level,rooms)
    _ground_fittings(sc,level,rooms)
    _bridge_vista(sc,level,rooms)
    _lights(sc,level)
