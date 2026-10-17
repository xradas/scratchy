#!/usr/bin/env python3
"""Bounded source preservation and independently parsed Intake route audit."""
from pathlib import Path
import hashlib, json, re, subprocess
ROOT=Path(__file__).resolve().parents[1]
BASE='694a5050205575cfc436b2118b295bd45acbc773'
CHANGED_ROOMS={'entry','service','arena_one','key_wing','key_console','return_store'}
ALLOWED={'scenes/campaign/pale_ward_01.tscn','resources/campaign/pale_ward_01-layout.json','resources/campaign/pale_ward_01-route.json','resources/campaign/room-program-inventory.json','resources/campaign/room-fittings-v6.json','scripts/stage_level.gd','scripts/campaign_route_playtest.gd','tools/package_pale_ward.py'}
def old(path):return subprocess.check_output(['git','show',BASE+':eye-sore/build-two/'+path],cwd=ROOT)
def digest(data):return hashlib.sha256(data).hexdigest()
def nodes(text):
 result={}
 for m in re.finditer(r'^\[node name="([^"]+)"([^\n]*)\]\n(.*?)(?=^\[node |\Z)',text,re.M|re.S):
  name,header,body=m.groups();parent=re.search(r'parent="([^"]+)"',header)
  if parent is None or parent.group(1)!='.':continue
  result[name]={'body':body,'metadata':dict(re.findall(r'^metadata/([^=\n]+) = (.*)$',body,re.M)),'position':re.search(r'^position = (.*)$',body,re.M).group(1) if re.search(r'^position = (.*)$',body,re.M) else None}
 return result

def audit():
 failures=[];checks=0
 def check(ok,label):
  nonlocal checks
  checks+=1
  if not ok:failures.append(label)
 baseline=json.loads((ROOT/'docs/intake-v7/baseline.json').read_text())
 changed=[]
 for path,expected in baseline['source_fingerprints'].items():
  file=ROOT/path;actual=digest(file.read_bytes()) if file.is_file() else None
  if actual!=expected:changed.append(path)
  check(actual==expected or path in ALLOWED,'Unexpected baseline change: '+path)
 check(set(changed)<=ALLOWED,'Only enumerated source deltas')
 # The campaign balance document is independently pinned, including health,
 # armor, main/optional/secret budgets and cache grants across all nine maps.
 check((ROOT/'resources/campaign/balance-budget.json').read_bytes()==old('resources/campaign/balance-budget.json'),'All campaign budgets byte-identical')
 scene='scenes/campaign/pale_ward_01.tscn';before=nodes(old(scene).decode());after=nodes((ROOT/scene).read_text())
 bp={n:v for n,v in before.items() if 'stage_pickup' in v['metadata']};ap={n:v for n,v in after.items() if 'stage_pickup' in v['metadata']}
 check(set(bp)==set(ap),'Exact pickup root roster')
 moves=[]
 for name,prior in bp.items():
  if name not in ap:continue
  current=ap[name];check(current['metadata']==prior['metadata'],'Pickup metadata preserved '+name)
  if current['position']!=prior['position']:
   moves.append(name)
   check(any(name.endswith('_'+r) for r in CHANGED_ROOMS) or name in {'FirstGunCache','Key_brass_key'},'Pickup move confined to first section '+name)
 route=json.loads((ROOT/'resources/campaign/pale_ward_01-route.json').read_text());prior_route=json.loads(old('resources/campaign/pale_ward_01-route.json'))
 for name in moves:
  if name=='Key_brass_key':
   room=route['rooms']['key_console'];x,y,z=room['center'];expected=[x,y+.6,z-3]
  elif name.startswith('Supply_'):
   kind,rid=name.removeprefix('Supply_').split('_',1);room=route['rooms'][rid];x,y,z=room['center']
   slot={'pistol':0,'shells':1,'health':2,'armor':3}[kind]
   expected=[x+(-.8 if slot%2==0 else .8),y+.5,z+room['size'][2]/2-3-(slot//2)*1.2]
  else:check(False,'Unspecified moved pickup '+name);continue
  actual=[float(x.strip()) for x in ap[name]['position'].removeprefix('Vector3(').removesuffix(')').split(',')]
  check(all(abs(a-b)<.00002 for a,b in zip(actual,expected)),'Independent authored position '+name)
 check(set(route['rooms'])==set(prior_route['rooms']),'No unrelated rooms added/removed')
 for rid,r in prior_route['rooms'].items():
  if rid not in CHANGED_ROOMS:check(route['rooms'][rid]==r,'Later/optional room unchanged '+rid)
 edges=route['portals']
 check(any(e['from']=='key_console' and e['to']=='return_store' for e in edges),'Direct theatre-to-store return')
 check(not any({e['from'],e['to']}=={'key_wing','return_store'} for e in edges),'Old diagnostics backtrack removed')
 shortcut=[e for e in edges if e.get('gate')=='shortcut_one'];check(len(shortcut)==1,'Single return shortcut')
 if shortcut:check('brass_key' in shortcut[0].get('requires',[]),'Shortcut brass requirement')
 door=after.get('Door_shortcut_one',{})
 check('first_open_normal' in door.get('metadata',{}),'Shortcut first-opening physical side restriction')
 # Solve undirected reachability with declared door requirements, never
 # counting secret portals. Dynamic encounters are checked in native fixtures.
 def reachable(flags):
  seen={'entry'}
  while True:
   now=set(seen)
   for e in edges:
    if e.get('secret') or any(x not in flags for x in e.get('requires',[])):continue
    if e['from'] in seen:now.add(e['to'])
    if e['to'] in seen:now.add(e['from'])
   if now==seen:return seen
   seen=now
 check('key_console' not in reachable(set()),'No unpowered brass-key bypass')
 check('spine' not in reachable({'breaker','power'}),'No brass gate bypass without key')
 check('key_console' in reachable({'breaker','power'}),'Powered theatre reachable')
 check('spine' in reachable({'breaker','power','brass_key','brass'}),'Brass gate main route reachable without secrets')
 report={'status':'passed' if not failures else 'failed','checks':checks,'baseline_commit':BASE,'scene_sha256':digest((ROOT/scene).read_bytes()),'changed_baseline_files':changed,'moved_pickups':moves,'failures':failures,'scope':'Source preservation, exact campaign budgets and pickup metadata, explicit first-section deltas and no-secret route solver. Native geometry, interactions, AI and exported run checked separately.'}
 out=ROOT/'verification/intake-v7/source-audit.json';out.parent.mkdir(parents=True,exist_ok=True);out.write_text(json.dumps(report,indent=2)+'\n')
 print(json.dumps(report,indent=2));return not failures
if __name__=='__main__':raise SystemExit(0 if audit() else 1)
