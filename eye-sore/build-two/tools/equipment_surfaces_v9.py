"""Intake-only complete-face equipment/control/exit presentation.

Pure authoring API: register_materials(sc), then apply_equipment_surfaces(sc).
Original meshes/shapes/transforms/metadata/resources remain byte-identical.
Only visual material_override lines and new isolated visual children are added.
"""
from __future__ import annotations
import hashlib,json,re
from pathlib import Path
import room_materials_v8 as v8
ROOT=Path(__file__).resolve().parents[1]
LEVEL='pale_ward_01'
MODE={'equipment':0,'platform':1,'control':2,'exit':3}
ROOM_FAMILIES={'entry':'triage','arena_one':'triage','key_wing':'surgery','key_console':'surgery','service':'utility','return_store':'utility','spine':'utility','arena_two':'triage','red_wing':'surgery','red_console':'surgery','final_arena':'utility','exit_gallery':'utility','supplies':'utility','maintenance':'utility','pump_room':'utility','armory':'utility','secret_one':'utility','secret_two':'surgery','observation':'utility'}
METAL_SUPPORTS={'room_prop_0','room_prop_7','room_prop_0_cyl','room_prop_7_cyl'}
PLATFORM=re.compile(r'(RaisedAltar|Deck|Platform|Balcony|Gallery|Stairs|Step_)')
NODE=v8.NODE
OVERRIDE=v8.VISUAL_OVERRIDE

def applies(sc): return sc.stage.get('campaign_level_id')==LEVEL

def register_materials(sc,manifest=None):
 """Validate native sources first; add stable material IDs, never edit resources."""
 if not applies(sc): return {}
 data=v8._manifest(manifest); sources=v8._native_sources(data)
 v8._append_resource(sc.ext,'[ext_resource type="Shader" path="res://shaders/equipment_surface_v9.gdshader" id="equipment_surface_v9"]','equipment_surface_v9')
 v8._append_resource(sc.ext,'[ext_resource type="Script" path="res://scripts/control_presentation_v9.gd" id="equipment_control_v9"]','equipment_control_v9')
 result={}
 for family,source in sources.items():
  texture='v8_source_'+family
  v8._append_resource(sc.ext,'[ext_resource type="Texture2D" path="'+source['path']+'" id="'+texture+'"]',texture)
  result[family]={}
  for mode,index in MODE.items():
   ident='v9_'+family+'_'+mode
   region=lambda role:', '.join(map(str,source['regions'][role]))
   resource='[sub_resource type="ShaderMaterial" id="'+ident+'"]\nshader = ExtResource("equipment_surface_v9")\nshader_parameter/painted_surface = ExtResource("'+texture+'")\nshader_parameter/trim_region = Vector4('+region('trim')+')\nshader_parameter/face_region = Vector4('+region('door' if mode=='exit' else 'panel')+')\nshader_parameter/floor_region = Vector4('+region('floor')+')\nshader_parameter/pixels_per_metre = '+str(data['pixels_per_metre'])+'\nshader_parameter/surface_mode = '+str(index)+'\nshader_parameter/local_half_size = Vector3(0.75, 0.9, 0.25)\n'
   v8._append_resource(sc.sub,resource,ident);result[family][mode]=ident
 sc.equipment_surfaces_v9_ids=result
 sc.equipment_surfaces_v9_sources=sources
 return result

def _room(root,routes):
 for room in sorted(ROOM_FAMILIES,key=len,reverse=True):
  if root.startswith(room+'_'): return room
 match=re.match(r'(?:Step|Link)_(\d+)_',root)
 if match:
  index=int(match[1])
  if index<len(routes): return routes[index]['from']
 if root.startswith('ServiceBalcony'): return 'service'
 if root.startswith('TriageBed'): return 'arena_one'
 if root.startswith('CachePedestal_'): return root[len('CachePedestal_'):]
 return None

def _string(node,key):
 match=re.search(r'^metadata/'+re.escape(key)+r' = "([^"]*)"$',node,re.M)
 return match[1] if match else None

def _requires(node):
 match=re.search(r'^metadata/requires = Array\[String\]\((.*)\)$',node,re.M)
 return json.loads(match[1]) if match else []

def _append_node(sc,name,parent,props):
 header='[node name="'+name+'" type="Node3D" parent="'+parent+'"]'
 text=header+'\n'+props+'\n'
 existing=[n for n in sc.nodes if n.startswith(header)]
 if existing:
  assert len(existing)==1 and existing[0].rstrip()==text.rstrip(), (parent,name,'component collision')
  return False
 sc.nodes.append(text);return True

def apply_equipment_surfaces(sc,routes=None,manifest=None):
 """Bind after final furnishing/v8 materials. In-memory only; no scene writes.

 Sources identify props by room_program_object metadata, controls by stage_button,
 exit by stage_exit, and platforms by authored semantic root names. Positions are
 never used for binding; moving/reordering complete furnishing groups is safe.
 """
 if not applies(sc): return {'applied':False,'reason':'Intake only','version':9}
 materials=register_materials(sc,manifest)
 routes=routes if routes is not None else getattr(sc,'room_program_routes',None)
 assert routes is not None,'pass authored routes or sc.room_program_routes'
 before_nodes=list(sc.nodes);before_sub=list(sc.sub);before_ext=list(sc.ext)
 before_stage=json.dumps(sc.stage,sort_keys=True)
 roots={}
 for node in before_nodes:
  head=NODE.match(node)
  if head and head[3]=='.': roots[head[1]]=node
 meshes={}
 for resource in sc.sub:
  head=v8.SUB_ID.match(resource);mat=re.search(r'^material = SubResource\("([^"]+)"\)',resource,re.M)
  if head and head[1].endswith('Mesh') and mat: meshes[head[2]]={'type':head[1],'material':mat[1]}
 button_rooms={b['id']:b['room'] for b in sc.stage.get('buttons',[])}
 bindings=[];changed=0;components=[];added=0
 for index,node in enumerate(before_nodes):
  head=NODE.match(node)
  if not head: continue
  name,typ,parent=head.groups();path=name if parent=='.' else parent+'/'+name;root=path.split('/')[0]
  original=roots.get(root,'');flag=_string(original,'stage_button');exit_node=bool(re.search(r'^metadata/stage_exit = true$',original,re.M))
  prop=_string(original,'room_program_object');room=prop.split('.')[1] if prop else _room(root,routes)
  mode=None
  if flag is not None:
   room=button_rooms.get(root.removeprefix('Button_'),None);mode='control'
  elif exit_node:
   room=sc.stage['exit']['room'];mode='exit'
  elif PLATFORM.search(root): mode='platform'
  elif prop or root.startswith(('TriageBed','CachePedestal_')): mode='equipment'
  if room not in ROOM_FAMILIES or mode is None: continue
  family=ROOM_FAMILIES[room];material=materials[family][mode]
  if typ=='MeshInstance3D':
   mesh=re.search(r'^mesh = SubResource\("([^"]+)"\)',node,re.M)
   if not mesh or mesh[1] not in meshes: continue
   source=meshes[mesh[1]]
   if mode=='equipment' and prop and source['material'] not in METAL_SUPPORTS: continue
   if mode=='control' and parent not in (root,root+'/Face'): continue
   if mode=='exit' and parent!=root: continue
   updated=OVERRIDE.sub('',node);newline=updated.index('\n')+1
   updated=updated[:newline]+'material_override = SubResource("'+material+'")\n'+updated[newline:]
   sc.nodes[index]=updated;changed+=updated!=node
   bindings.append({'path':path,'root':root,'room':room,'family':family,'mode':mode,'source_material':source['material'],'material':material,'mesh_type':source['type']})
  if parent=='.' and (flag is not None or exit_node or (mode=='platform' and 'metadata/stage_polygon =' in node)):
   binding_parent = '.' if mode == 'platform' else root
   target_path = '../' + root if mode == 'platform' else '..'
   props='script = ExtResource("equipment_control_v9")\ntarget_path = NodePath('+json.dumps(target_path)+')\n'
   if flag is not None: props+='flag_key = &'+json.dumps(flag)+'\n'
   if flag is not None or exit_node: props+='required_flags = PackedStringArray('+', '.join(map(json.dumps,_requires(original)))+')\n'
   if exit_node: props+='is_exit = true\n'
   if exit_node or mode=='platform': props+='surface_material = SubResource("'+material+'")\n'
   child='ControlPresentationV9' if flag is not None or exit_node else 'SurfacePresentationV9_'+root
   added+=_append_node(sc,child,binding_parent,props)
   component_path = root+'/'+child if binding_parent != '.' else child
   components.append({'path':component_path,'mode':mode,'flag':flag,'room':room,'family':family,'required_flags':_requires(original) if flag is not None or exit_node else [],'material':material if exit_node or mode=='platform' else None})
 assert before_sub==sc.sub and before_ext==sc.ext,'resource edited during binding'
 for before,after in zip(before_nodes,sc.nodes): assert OVERRIDE.sub('',before)==OVERRIDE.sub('',after),'original non-material node bytes changed'
 assert before_stage==json.dumps(sc.stage,sort_keys=True),'stage data changed'
 report={'schema_version':1,'version':9,'applied':True,'campaign_level_id':LEVEL,'binding_count':len(bindings),'changed_visuals':changed,'components_added':added,'bindings':bindings,'components':components,'sources':sc.equipment_surfaces_v9_sources,'integrity':{'original_mesh_shape_resources_unchanged':True,'original_transform_metadata_bytes_unchanged':True,'stage_data_unchanged':True,'no_added_colliders':True},'acceptance':'Pending coordinator native review; material-only binding is not gameplay approval.'}
 sc.equipment_surfaces_v9_report=report
 return report

def scene_fixture(scene_path=None,route_path=None):
 """Return an in-memory exact current scene with isolated presentation additions."""
 from types import SimpleNamespace
 scene_path=Path(scene_path or ROOT/'scenes/campaign/pale_ward_01.tscn');route_path=Path(route_path or ROOT/'resources/campaign/pale_ward_01-route.json')
 text=scene_path.read_text();chunks=re.split(r'(?=^\[(?:ext_resource|sub_resource|node) )',text,flags=re.M);route=json.loads(route_path.read_text())
 sc=SimpleNamespace(stage=dict(route,campaign_level_id=LEVEL),ext=[c.rstrip('\n') for c in chunks if c.startswith('[ext_resource')],sub=[c for c in chunks if c.startswith('[sub_resource')],nodes=[c for c in chunks if c.startswith('[node')],room_program_routes=route['portals'])
 report=apply_equipment_surfaces(sc);once=(list(sc.ext),list(sc.sub),list(sc.nodes));repeat=apply_equipment_surfaces(sc)
 assert once==(sc.ext,sc.sub,sc.nodes) and repeat['changed_visuals']==0 and repeat['components_added']==0,'not idempotent'
 header=chunks[0];header=re.sub(r'load_steps=\d+','load_steps='+str(1+len(sc.ext)+len(sc.sub)),header)
 return header+'\n\n'.join(sc.ext+sc.sub+sc.nodes),report

if __name__=='__main__':
 import argparse
 p=argparse.ArgumentParser(description='Create isolated in-memory Intake surface fixture; production scene is never edited.');p.add_argument('--fixture',type=Path);p.add_argument('--report',type=Path);a=p.parse_args()
 text,report=scene_fixture()
 if a.fixture:
  assert a.fixture.resolve().is_relative_to(Path('/tmp')) or a.fixture.resolve().is_relative_to(ROOT/'verification/production-v9'),'fixture output must stay temporary or in v9 evidence'
  a.fixture.parent.mkdir(parents=True,exist_ok=True);a.fixture.write_text(text)
 if a.report:a.report.parent.mkdir(parents=True,exist_ok=True);a.report.write_text(json.dumps(report,indent=2)+'\n')
 print(json.dumps({k:v for k,v in report.items() if k not in ('bindings','sources')},indent=2))
