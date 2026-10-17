#!/usr/bin/env python3
"""Exact Light3D-only Intake patch; default dry run, preserves unrelated edits.

Preview: python tools/apply_lighting_v11.py --output /tmp/intake-lighting-v11.tscn
Root apply: python tools/apply_lighting_v11.py --apply --report /tmp/lighting-v11-apply.json
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import re

ROOT=Path(__file__).resolve().parents[1]
PLAN=ROOT/'docs/production-v11/lighting-plan.json'
SCENE=ROOT/'scenes/campaign/pale_ward_01.tscn'
NODE=re.compile(r'^\[node [^\n]*\]\n.*?(?=^\[node |\Z)',re.M|re.S)


def node_path(block):
    header=block.splitlines()[0];name=re.search(r'name="([^"]+)"',header)[1];parent=re.search(r'parent="([^"]+)"',header)
    return name if parent is None or parent[1]=='.' else parent[1]+'/'+name


def vec(values):return ', '.join(str(v) for v in values)


def patch_scene(text,plan=None):
    plan=plan or json.loads(PLAN.read_text())
    assert 'metadata/campaign_level_id = "pale_ward_01"' in text,'Intake only; campaign identity required'
    assert plan['level_id']=='pale_ward_01'
    owned=[];legacy=[];protected=[];seen=set()
    for match in NODE.finditer(text):
        block=match[0];path=node_path(block)
        if path=='LightingV11' or path.startswith('LightingV11/'):
            owned.append(match.span());continue
        if path in plan['legacy_emitters']:
            assert re.search(r'type="(?:Omni|Spot|Directional)Light3D"',block.splitlines()[0]),(path,'target is not a light')
            assert 'script = ' not in block and 'metadata/' not in block,(path,'unexpected light gameplay/script ownership')
            legacy.append(match.span());seen.add(path)
        else:protected.append(block.rstrip())
    assert seen==set(plan['legacy_emitters']) or (not seen and owned),'Partial or changed legacy emitter inventory; inspect before patching'
    spans=sorted(owned+legacy)
    for start,end in reversed(spans):text=text[:start]+text[end:]
    resource='[ext_resource type="PackedScene" path="res://scenes/fixtures/intake_light_v11.tscn" id="lighting_v11_prefab"]'
    existing=re.findall(r'^\[ext_resource [^\n]*id="lighting_v11_prefab"\]',text,re.M)
    if existing:assert existing==[resource],'Lighting resource ID collision'
    else:
        index=text.index('[sub_resource ');text=text[:index]+resource+'\n\n'+text[index:]
    environment=re.search(r'^\[sub_resource type="Environment" id="environment"\]\n.*?(?=^\[|\Z)',text,re.M|re.S)
    assert environment,'Expected shared Intake environment resource'
    updated,count=re.subn(r'^ambient_light_energy = [^\n]+',f'ambient_light_energy = {plan["ambient_energy"]}',environment[0],flags=re.M)
    assert count==1
    text=text[:environment.start()]+updated+text[environment.end():]
    nodes=['[node name="LightingV11" type="Node3D" parent="."]\nmetadata/lighting_version = 11\nmetadata/flicker_fixture_count = 2\n']
    for i,item in enumerate(plan['fixtures']):
        lines=[f'[node name="{item["id"]}" parent="LightingV11" instance=ExtResource("lighting_v11_prefab")]',
               'position = Vector3('+vec(item['position'])+')','rotation_degrees = Vector3('+vec(item['rotation_degrees'])+')',
               'fixture_kind = '+json.dumps(item['kind']),'energy = '+str(item['energy']),'reach = '+str(item['reach']),
               'cone_angle = '+str(item['cone_angle']),'lamp_color = Color('+vec(item['color'])+')',
               'cast_shadow = '+str(item['shadow']).lower(),'damaged = '+str(item['damaged']).lower(),
               'flicker_period = '+str(19.0+4.0*(i%2)),'flicker_offset = '+str(0.0 if i%2==0 else 3.7),
               'metadata/room_id = '+json.dumps(item['room'])]
        if item['existing_lens']:lines.append('existing_lens_path = NodePath('+json.dumps('../../'+item['existing_lens'])+')')
        nodes.append('\n'.join(lines)+'\n')
    text=(text.rstrip()+'\n\n'+'\n'.join(nodes)).rstrip()+'\n'
    steps=len(re.findall(r'^\[(?:ext|sub)_resource ',text,re.M))+1
    text=re.sub(r'^\[gd_scene load_steps=\d+',f'[gd_scene load_steps={steps}',text,count=1)
    after=[m[0].rstrip() for m in NODE.finditer(text) if not (node_path(m[0])=='LightingV11' or node_path(m[0]).startswith('LightingV11/'))]
    assert protected==after,'Non-light scene node data changed'
    return text,{'version':11,'applied':True,'removed_legacy_emitters':len(legacy),'mounted_emitters':len(plan['fixtures']),
                 'reused_lenses':sum(bool(f['existing_lens']) for f in plan['fixtures']),
                 'damaged_fixtures':[f['id'] for f in plan['fixtures'] if f['damaged']],
                 'protected_node_bytes_unchanged':True,'colliders_added':0,'physics_geometry_changed':False,
                 'group':'intake_lighting_v11','ambient_energy':plan['ambient_energy']}


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--scene',type=Path,default=SCENE);parser.add_argument('--output',type=Path);parser.add_argument('--report',type=Path);parser.add_argument('--apply',action='store_true');args=parser.parse_args()
    assert args.scene.resolve()==SCENE.resolve(),'Exact target is the Intake scene only'
    assert not(args.apply and args.output),'Choose --apply or a private --output'
    before=args.scene.read_text();after,report=patch_scene(before)
    again,_=patch_scene(after);assert again==after,'Patcher is not idempotent'
    report.update(source_scene_sha256=hashlib.sha256(before.encode()).hexdigest(),result_scene_sha256=hashlib.sha256(after.encode()).hexdigest(),changed=before!=after,mode='apply' if args.apply else 'private candidate' if args.output else 'dry run')
    if args.apply:args.scene.write_text(after)
    elif args.output:
        assert args.output.resolve()!=SCENE.resolve(),'Use --apply for production target'
        args.output.write_text(after)
    if args.report:args.report.write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2))
if __name__=='__main__':main()
