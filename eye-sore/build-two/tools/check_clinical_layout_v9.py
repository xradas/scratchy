#!/usr/bin/env python3
"""Read actual v8 geometry; furnish a private v9 candidate without shared edits."""
from copy import deepcopy
import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import subprocess

import author_themed_stages as base
import clinical_layout_v9 as clinical
import intake_section_v7 as intake
import room_program_v6 as rooms
from check_presentation_v8 import sections, props, reference

ROOT = Path(__file__).resolve().parents[1]


def numbers(value):
    return [float(number) for number in re.findall(r'-?\d+(?:\.\d+)?(?:e[+-]?\d+)?', value.split("(",1)[1],re.I)]


def obstacles(resources, nodes):
    result = []
    for path, node in nodes.items():
        header = node.splitlines()[0]
        if 'parent="."' not in header or path.startswith(("RoomProp_", "IntakePresentation_")):
            continue
        p = props(node)
        position = numbers(p.get("position", "Vector3(0,0,0)"))
        if "metadata/stage_polygon" in p:
            outline = numbers(p["metadata/stage_polygon"])
            xs, zs = outline[::2], outline[1::2]
            result.append(dict(name=path,x=position[0]+(min(xs)+max(xs))/2,z=position[2]+(min(zs)+max(zs))/2,
                               w=max(xs)-min(xs),d=max(zs)-min(zs),min_y=position[1],max_y=position[1]+float(p["metadata/polygon_height"])))
            continue
        if 'type="StaticBody3D"' not in header:
            continue
        collision = nodes.get(path + "/Collision")
        if collision is None:
            continue
        shape = resources["sub",reference(props(collision)["shape"])]
        s = props(shape)
        if "BoxShape3D" in shape.splitlines()[0]: size = numbers(s["size"])
        elif "CylinderShape3D" in shape.splitlines()[0]: size = [2*float(s["radius"]),float(s["height"]),2*float(s["radius"])]
        else: raise AssertionError((path, "unhandled existing physical shape"))
        rotation = numbers(p.get("rotation_degrees", "Vector3(0,0,0)"))
        # Existing horizontal pipe rotations exchange vertical/depth axes.
        if abs(rotation[0]) == 90: size[1],size[2] = size[2],size[1]
        yaw = math.radians(rotation[1]); w=abs(size[0]*math.cos(yaw))+abs(size[2]*math.sin(yaw));d=abs(size[0]*math.sin(yaw))+abs(size[2]*math.cos(yaw))
        result.append(dict(name=path,x=position[0],z=position[2],w=w,d=d,min_y=position[1]-size[1]/2,max_y=position[1]+size[1]/2))
    return result


def build(output):
    source = (ROOT/"scenes/campaign/pale_ward_01.tscn").read_text()
    resources, nodes = sections(source)
    stage = json.loads((ROOT/"resources/campaign/pale_ward_01-layout.json").read_text());stage["id"]=stage["theme"]
    route = json.loads((ROOT/"resources/campaign/pale_ward_01-route.json").read_text())
    programmes = rooms.load_program(); before = intake.prepare_programme(stage,programmes[clinical.LEVEL_ID]); frozen=deepcopy(before);stage_frozen=deepcopy(stage)
    programme = clinical.prepare_programme(stage,before)
    assert before == frozen and stage == stage_frozen and clinical.prepare_programme(stage,programme) == programme
    original_inventory = [(r["id"],o["id"],o["type"],o["count"]) for r in before["rooms"] for o in r["objects"]]
    assert original_inventory == [(r["id"],o["id"],o["type"],o["count"]) for r in programme["rooms"] for o in r["objects"]]
    for level, other in programmes.items():
        if level != clinical.LEVEL_ID: assert clinical.prepare_programme({"campaign_level_id":level},other)==other
    assert sum(o["count"] for p in programmes.values() for r in p["rooms"] for o in r["objects"]) == 508
    rooms.validate_level_program(stage,programme)
    prebuild = clinical.placement_report(stage,programme)
    (output/"prebuild-objects.json").write_text(json.dumps(prebuild,indent=2)+"\n")
    # Keep actual architecture/resources and remove only previously emitted
    # furnishing roots/bay lights. Production furnish validates against its real
    # reservations plus parsed physical source obstacles; no author monkeypatch.
    sc = base.Scene(stage)
    sc.ext = [v for (kind,_),v in resources.items() if kind=="ext"]
    sc.sub = [v+"\n" for (kind,name),v in resources.items() if kind=="sub"]
    sc.nodes = [v+"\n" for path,v in nodes.items() if not path.startswith(("RoomProp_","RoomBayLight_"))]
    sc.i = max(int(name[1:]) for kind,name in resources if kind=="sub" and re.fullmatch(r'm\d+',name))
    report = rooms.furnish(sc,stage,programme,route["portals"],route["vertical_routes"],obstacles(resources,nodes),emitter=clinical.emit_prop)
    (output/"actual-furnishing.json").write_text(json.dumps(report,indent=2)+"\n")
    assert report["rejected"] == [], report["rejected"]
    expected = {obj["id"]:obj for obj in prebuild["objects"]}
    for placement in report["placements"]:
        if placement["id"] in expected:
            item=expected[placement["id"]]
            assert [placement["x"],placement["z"],placement["heading"]]==[item["position_world"][0],item["position_world"][2],item["position_local"][2]]
    candidate=output/"candidate.tscn"
    # Retain existing material definitions before old mesh references. Furnish
    # registers the same IDs again; verify equality and serialize each once.
    unique=[]; seen={}
    def normalized(text): return re.sub(r'(?<![\w])(-?)\.(\d+)',r'\g<1>0.\2',text).rstrip()
    for resource in sc.sub:
        identifier=re.search(r' id="([^"]+)"',resource.splitlines()[0])[1]
        if identifier in seen:
            assert normalized(resource)==normalized(seen[identifier]),identifier
        else:seen[identifier]=resource;unique.append(resource)
    sc.sub=unique
    candidate.write_text(normalized('[gd_scene load_steps='+str(len(sc.ext)+len(sc.sub)+1)+' format=3]\n\n'+'\n'.join(sc.ext+sc.sub+sc.nodes))+'\n')
    (output/"source.json").write_text(json.dumps({"passed":True,"baseline_scene_sha256":hashlib.sha256(source.encode()).hexdigest(),"candidate_scene_sha256":hashlib.sha256(candidate.read_bytes()).hexdigest(),"placed":report["placed_count"],"rejected":0,"explicit_target_instances":23,"campaign_instances":508,"other_eight_programmes_identical":True,"inputs_unchanged":True,"candidate":str(candidate)},indent=2)+"\n")
    return candidate


if __name__ == "__main__":
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument("--output",type=Path,required=True);parser.add_argument("--native",action="store_true");args=parser.parse_args()
    out=args.output.resolve();assert not out.exists() or not any(out.iterdir()),"refuse to overwrite evidence";out.mkdir(parents=True,exist_ok=True)
    candidate=build(out)
    if args.native:
        command=[str(ROOT/'tools/godot.sh'),'--headless','--fixed-fps','60','--script','res://tools/check_clinical_layout_v9.gd','--','--candidate='+str(candidate),'--report='+str(out/'native.json')]
        with (out/'native.log').open('w') as log:result=subprocess.run(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,timeout=120)
        raw=json.loads((out/'native.json').read_text()) if (out/'native.json').exists() else {}
        assert result.returncode==0 and raw.get('passed'),(raw.get('failures'),out/'native.log')
    print(json.dumps({'passed':True,'output':str(out)},indent=2))
