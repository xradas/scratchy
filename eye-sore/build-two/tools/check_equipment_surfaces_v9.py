#!/usr/bin/env python3
"""Read-only source integrity + actual bound Main surface fixture orchestration.

The native comparison copy removes only v9 material overrides/components. Actual
state checks/captures use the production-bound Intake scene. No author/source edits.
"""
import argparse,json,os,re,subprocess,tempfile
from pathlib import Path
from types import SimpleNamespace
import equipment_surfaces_v9 as surfaces
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'verification/production-v9/surfaces'

def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--capture',action='store_true');args=parser.parse_args()
 OUT.mkdir(parents=True,exist_ok=True)
 _,bindings=surfaces.scene_fixture()
 assert bindings['changed_visuals']==0 and bindings['components_added']==0,'Actual author integration must be regenerated first'
 for theme in ('pale_ward','ash_citadel','occupied_line'):
  for number in (1,2,3):
   identity=f'{theme}_{number:02}'
   if identity=='pale_ward_01':continue
   sc=SimpleNamespace(stage={'campaign_level_id':identity},nodes=[],sub=[],ext=[])
   assert not surfaces.apply_equipment_surfaces(sc)['applied'] and not sc.nodes and not sc.sub and not sc.ext
 (OUT/'bindings.json').write_text(json.dumps(bindings,indent=2)+'\n')
 source=(ROOT/'scenes/campaign/pale_ward_01.tscn').read_text()
 chunks=re.split(r'(?=^\[(?:ext_resource|sub_resource|node) )',source,flags=re.M)
 stripped=[];removed_components=0
 for chunk in chunks:
  if chunk.startswith('[node ') and (re.match(r'^\[node name="ControlPresentationV9"',chunk) or re.match(r'^\[node name="SurfacePresentationV9_',chunk)):
   removed_components+=1;continue
  stripped.append(re.sub(r'^material_override = SubResource\("v9_[^"]+"\)\n','',chunk,flags=re.M))
 assert removed_components==5,'Exact three controls, exit and sibling prism binder required'
 with tempfile.TemporaryDirectory(prefix='eyesore-v9-surface-check-') as directory:
  temporary=Path(directory);baseline=temporary/'baseline.tscn';baseline.write_text(''.join(stripped))
  env=dict(os.environ,XDG_DATA_HOME=str(temporary/'profile'))
  command=[str(ROOT/'tools/godot.sh')]
  command+=['--no-focus','--position','20000,20000'] if args.capture else ['--headless']
  command+=['--script','res://tools/check_equipment_surfaces_v9.gd','--','--automated-input','--campaign-level=pale_ward_01','--surface-baseline='+str(baseline)]
  if args.capture: command+=['--capture-surfaces-v9']
  process=subprocess.run(command,cwd=ROOT,env=env,capture_output=True,text=True,timeout=120)
  log=process.stdout+process.stderr;(OUT/('native.log' if args.capture else 'headless.log')).write_text(log)
  print(log,end='')
  return process.returncode
if __name__=='__main__':raise SystemExit(main())
