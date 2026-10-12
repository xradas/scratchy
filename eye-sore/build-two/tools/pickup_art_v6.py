"""Scene child visuals only. Call after unchanged pickup root metadata creation.

if add_pickup_visuals(sc,name,kind): return

Unsupported weapon caches retain the existing author presentation. No root
position, grant, collection radius, collision or navigation changes occur here.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT/'resources/pickups/presentation-v6.json'

def vec(v):return 'Vector3('+', '.join(f'{x:.8g}' for x in v)+')'

def _material(sc,kind,face,record,manifest):
    name='pickup_v6_'+kind+'_'+face
    if any(s.startswith('[sub_resource type="StandardMaterial3D" id="'+name+'"]') for s in sc.sub):return name
    ext='pickup_v6_source'
    header='[ext_resource type="Texture2D" path="'+manifest['atlas']+'" id="'+ext+'"]'
    if header not in sc.ext:sc.ext.append(header)
    atlas=name+'_atlas';rect=record['regions'][face]
    x,y,w,h=rect;canvas_w,canvas_h=manifest['source_canvas']
    sc.sub.append('[sub_resource type="AtlasTexture" id="'+atlas+'"]\natlas = ExtResource("'+ext+'")\nregion = Rect2('+', '.join(map(str,rect))+')\nfilter_clip = true\n')
    # AtlasTexture metadata alone does not transform 3D material UVs. Map
    # native pixel centers explicitly so a neighboring cell cannot be sampled.
    sc.sub.append('[sub_resource type="StandardMaterial3D" id="'+name+'"]\nalbedo_texture = SubResource("'+atlas+'")\ntexture_filter = 0\ntexture_repeat = false\nuv1_scale = '+vec(((w-1)/canvas_w,(h-1)/canvas_h,1))+'\nuv1_offset = '+vec(((x+.5)/canvas_w,(y+.5)/canvas_h,0))+'\nmetallic = '+str(record['metallic'])+'\nroughness = '+str(record['roughness'])+'\n')
    return name

def _quad(sc,parent,name,pos,size,rotation,material):
    sc.i+=1;mesh='pickup_face_'+str(sc.i)
    sc.sub.append('[sub_resource type="QuadMesh" id="'+mesh+'"]\nsize = Vector2('+', '.join(map(str,size))+')\nmaterial = SubResource("'+material+'")\n')
    sc.node(name,'MeshInstance3D',parent,'position = '+vec(pos)+'\nrotation_degrees = '+vec(rotation)+'\nmesh = SubResource("'+mesh+'")')

def _box(sc,parent,name,pos,size,materials):
    # Six actual perpendicular faces form a physical-sized closed model; no
    # billboard, hitbox, floor marker or Label3D supplies the visual identity.
    sc.node(name,parent=parent,props='position = '+vec(pos))
    child=parent+'/'+name;w,h,d=size
    faces=[('Front',(0,0,d/2),(w,h),(0,0,0),'front'),('Back',(0,0,-d/2),(w,h),(0,180,0),'front'),('Right',(w/2,0,0),(d,h),(0,90,0),'side'),('Left',(-w/2,0,0),(d,h),(0,-90,0),'side'),('Top',(0,h/2,0),(w,d),(-90,0,0),'top'),('Bottom',(0,-h/2,0),(w,d),(90,0,0),'top')]
    for face,offset,dimensions,rotation,slot in faces:_quad(sc,child,face,offset,dimensions,rotation,materials[slot])

def add_pickup_visuals(sc,name,kind):
    if not MANIFEST.is_file():return False
    manifest=json.loads(MANIFEST.read_text());canonical=manifest['aliases'].get(kind,kind)
    record=manifest['items'].get(canonical)
    if record is None:return False
    materials={face:_material(sc,canonical,face,record,manifest) for face in record['regions']}
    sc.node('PresentationV6',parent=name,props='metadata/pickup_art_v6 = '+json.dumps(canonical)+'\nmetadata/atlas_source_sha256 = '+json.dumps(manifest['source_sha256'])+'\nmetadata/native_geometry = '+json.dumps(record['geometry']))
    parent=name+'/PresentationV6'
    if record['geometry']=='box':_box(sc,parent,'AmmoBox',(0,0,0),record['size'],materials)
    else:
        metal=materials['metal'];shared={'front':metal,'side':metal,'top':metal}
        # A real open bow plus extruded shaft and teeth, textured with the
        # native metallic swatch. Brass/red identity comes from atlas pixels.
        sc.i+=1;mesh='pickup_key_bow_'+str(sc.i)
        sc.sub.append('[sub_resource type="TorusMesh" id="'+mesh+'"]\ninner_radius = 0.105\nouter_radius = 0.20\nrings = 24\nring_segments = 12\nmaterial = SubResource("'+metal+'")\n')
        sc.node('OpenBow','MeshInstance3D',parent,'position = Vector3(-0.31,0,0)\nrotation_degrees = Vector3(90,0,0)\nmesh = SubResource("'+mesh+'")')
        _box(sc,parent,'Shaft',(.11,0,0),(.65,.09,.09),shared)
        for index,(x,h) in enumerate(((.26,.14),(.40,.21))):_box(sc,parent,'Tooth'+str(index),(x,-h/2-.035,0),(.09,h,.09),shared)
    return True
