#!/usr/bin/env python3
"""Independent v13 baseline/design/native checks; no production mutations."""
from __future__ import annotations
import argparse,collections,hashlib,json,os,re,subprocess,tempfile
from pathlib import Path
import check_production_archive_v9 as source_audit
import verify_pale_ward_archive as portable
ROOT=Path(__file__).resolve().parents[1]
DOCS=ROOT/'docs/level-redesign-v13'
OUT=ROOT/'verification/level-redesign-v13'
GODOT=source_audit.v7.GODOT
def sha(data):return hashlib.sha256(data).hexdigest()
def read(path):return json.loads(path.read_text(),object_pairs_hook=portable.unique_object)
def protected_baseline():
 baseline=read(DOCS/'qa-baseline.json')
 count=source_audit.git_fingerprints(baseline['baseline_commit'],baseline['all_runtime_fingerprints'])
 for path,digest in baseline['protected_fingerprints'].items():
  portable.require((ROOT/path).is_file() and sha((ROOT/path).read_bytes())==digest,'Protected non-Ward/combat asset changed '+path)
 allowed_resources={'resources/campaign/catalog.json'}|{f'resources/campaign/pale_ward_0{i}-{kind}.json' for i in range(1,4) for kind in ('layout','route')}
 supplemental={p:h for p,h in baseline['all_runtime_fingerprints'].items() if p.startswith('resources/') and p not in allowed_resources and p not in baseline['protected_fingerprints']}
 for path,digest in supplemental.items():portable.require((ROOT/path).is_file() and sha((ROOT/path).read_bytes())==digest,'Unchanged auxiliary resource differs '+path)
 for folder in ('assets','resources'):
  roster={p for p in baseline['all_runtime_fingerprints'] if p.startswith(folder+'/')}
  if folder=='resources':roster|={f'resources/campaign/v13/pale_ward_0{i}-{kind}' for i in range(1,4) for kind in ('objectives.tres','author-report.json')}|{'resources/campaign/v13/balance-budget.json'}
  portable.require({str(p.relative_to(ROOT)) for p in (ROOT/folder).rglob('*') if p.is_file()}==roster,'Exact '+folder+' roster; only three objective resources, three author receipts and v13 availability budget allowed')
 catalog_path='resources/campaign/catalog.json'
 catalog=json.loads(subprocess.check_output(['git','show',baseline['baseline_commit']+':./'+catalog_path],cwd=ROOT),object_pairs_hook=portable.unique_object)
 for entry,subtitle in zip(catalog['chapters'][0]['levels'],('Reception loop / surgical access','Reservoir isolation / lower discharge','Containment anchors / silo descent')):entry['subtitle']=subtitle
 portable.require(read(ROOT/catalog_path)==catalog,'Catalog differs beyond exact three approved Ward subtitles')
 return {'baseline_commit':baseline['baseline_commit'],'sealed_git_blobs':count,'protected_current_files':len(baseline['protected_fingerprints']),'supplemental_unchanged_resources':len(supplemental),'asset_resource_roster':'Exact baseline; new v13 resources limited to three Ward objective resources, three author receipts and availability budget.','catalog_policy':'Exact baseline JSON plus only three approved Ward subtitle substitutions; every other field and all six later entries identical.','six_legacy_scene_sha256':{path:baseline['protected_fingerprints'][path] for path in baseline['legacy_scenes']},'scope':'Baseline identity only. Six non-Ward scenes and their route/layout resources, all original art/audio/weapons/AI/player/gore/lighting components protected; no redesigned geometry, checkpoint, route or human-duration acceptance claim.'}
def design_contract():
 for name in ('contracts.json','levels.json'):portable.require((DOCS/name).is_file(),'Coordinator design contract not available yet: '+name)
 contract=read(DOCS/'contracts.json');data=read(DOCS/'levels.json')
 portable.require(contract['version']==data['version']==13,'Exact v13 design schema version')
 return {'contracts':contract,'levels':data['levels']}
def symbolic_route(level,order=()):
 """Room+monotonic-flag state search; optional/secret supplies excluded."""
 rooms={r['id']:r for r in level['rooms']};profile=level['objective_profile'];initial=frozenset({k for k,v in profile['initial_flags'].items() if v}|{'visited_'+level['spawn_room']})
 start=(level['spawn_room'],initial);queue=collections.deque([start]);parents={start:None};steps={}
 def insert(before,room,flags,step):
  state=(room,frozenset(flags))
  if state not in parents:parents[state]=before;steps[state]=step;queue.append(state)
 finish=None
 while queue:
  state=queue.popleft();room,flags=state
  if room==level['exit']['room'] and set(profile['exit_requires'])<=flags:finish=state;break
  for portal in level['portals']:
   if portal['secret'] or not set(portal['requires'])<=flags:continue
   if portal.get('first_open_from') and room!=portal['first_open_from'] and '_opened_'+portal['id'] not in flags:continue
   other=portal['to'] if portal['from']==room else portal['from'] if portal['to']==room else None
   if other is None or rooms[other]['optional'] or rooms[other]['secret']:continue
   grants={'visited_'+other}
   if portal.get('first_open_from'):grants.add('_opened_'+portal['id'])
   insert(state,other,flags|grants,{'action':'travel','portal':portal['id'],'from':room,'to':other})
  actions=[]
  for control in level['controls']:
   if control['room']==room:
    rule=profile['controls'][control['id']]
    if order and control['id'] in order and any(earlier not in flags for earlier in order[:order.index(control['id'])]):continue
    actions.append(('use',control['id'],rule['requires'],rule['sets']))
  for key in level['keys']:
   if key['room']==room:
    rule=profile['keys'][key['kind']];actions.append(('collect',key['kind'],rule['requires'],rule['sets']))
  for anchor in level['anchors']:
   if anchor['room']==room:actions.append(('shoot',anchor['id'],anchor['requires'],[anchor['id']]))
  for encounter,rule in level['encounters'].items():
   if room==encounter:actions.append(('survive',encounter,rule.get('requires',[]),[rule['completion_flag']]))
  for action,id,requires,sets in actions:
   if set(requires)<=flags and not set(sets)<=flags:insert(state,room,flags|set(sets),{'action':action,'id':id,'room':room,'sets':sets})
 portable.require(finish is not None,'No nonsecret/nonoptional objective route '+level['id']+' order'+str(order))
 plan=[];cursor=finish
 while parents[cursor] is not None:plan.append(steps[cursor]);cursor=parents[cursor]
 return {'state_count':len(parents),'steps':list(reversed(plan)),'exit_flags':sorted(finish[1]),'scope':'Symbolic precondition/reachability proof only; encounters abstracted as survival actions, no physical traversal or resource/balance claim.'}
def check_design(expected):
 levels=expected['levels'];portable.require([l['id'] for l in levels[:3]]==['pale_ward_01','pale_ward_02','pale_ward_03'],'Ordered Ward design packets')
 results={};ward=[l for l in levels if l['id'].startswith('pale_ward_')]
 portable.require(len(ward)==3,'Exactly3 redesigned Ward designs')
 for level,total in zip(ward,(64,76,84)):
  rooms={r['id']:r for r in level['rooms']};portable.require(len(rooms)==len(level['rooms']),'Unique authored rooms '+level['id'])
  portable.require(len({r['district'] for r in rooms.values()})==4 and len({r['center'][1] for r in rooms.values()})>=3,'Four districts/three usable declared elevation bands '+level['id'])
  portable.require(len(level['optional_rooms'])>=4 and len(level['secret_rooms'])>=2 and all(rooms[x]['optional'] for x in level['optional_rooms']) and all(rooms[x]['secret'] for x in level['secret_rooms']),'Declared optional and secret rooms '+level['id'])
  portable.require(sum(bool(p['shortcut']) for p in level['portals'])>=2,'At least2 authored shortcuts '+level['id'])
  portable.require(sum(r['enemies'] for r in rooms.values())==level['enemy_total']==total,'Explicit actor budget '+level['id'])
  portable.require(len(level['checkpoints'])==2 and len({c['id'] for c in level['checkpoints']})==2,'Exactly2 distinct checkpoint milestones '+level['id'])
  portable.require(level['target_human_minutes']==[20,25],'Declared human pacing target only '+level['id'])
  for portal in level['portals']:portable.require(portal['from'] in rooms and portal['to'] in rooms and portal['width']>=3,'Valid physical portal endpoints/width '+level['id'])
  plans={'default':symbolic_route(level)}
  if level['id']=='pale_ward_02':
   portable.require(level['encounters']=={} and not any('clear' in x for x in level['objective_profile']['exit_requires']),'Containment has no mandatory all-clear objective')
   plans={'A_then_B':symbolic_route(level,('isolation_a','isolation_b')),'B_then_A':symbolic_route(level,('isolation_b','isolation_a'))}
  if level['id']=='pale_ward_03':portable.require(len(level['anchors'])==3 and all(a['health']==60 for a in level['anchors']),'Three60HP shootable anchors')
  results[level['id']]={'rooms':len(rooms),'enemies':total,'districts':sorted({r['district'] for r in rooms.values()}),'elevations':sorted({r['center'][1] for r in rooms.values()}),'shortcuts':sum(bool(p['shortcut']) for p in level['portals']),'plans':plans}
 return {'ward':results,'scope':'Declared design contracts and symbolic nonsecret/nonoptional objective reachability, both Containment orders; no human-duration or native-geometry acceptance.'}
def check_route_receipt(path,expected,require_clean_logs=False):
 receipt=read(path);levels=receipt.get('levels',[]);designs={x['id']:x for x in expected['levels']}
 portable.require(receipt['status']=='passed' and not receipt['failures'],'Route receipt explicitly failed '+str(path))
 portable.require(len(levels)==receipt['expected_levels']==receipt['levels_completed'] and 1<=len(levels)<=9,'Exact requested/completed route count')
 catalog=[level['id'] for chapter in read(ROOT/'resources/campaign/catalog.json')['chapters'] for level in chapter['levels']]
 ids=[level['level'] for level in levels]
 portable.require(ids[0] in catalog and ids==catalog[catalog.index(ids[0]):catalog.index(ids[0])+len(ids)],'Exact consecutive campaign level order')
 previous=None
 for index,level in enumerate(levels):
  id=level['level'];portable.require(level['completed'] and level['health']>0 and not level['secret_used'],'Live no-secret completion '+id)
  portable.require(level['segments'] and level['shots']>0 and level['kills']>0 and level['physics_seconds']>0,'Actual movement/live combat receipts '+id)
  for kind,value in level['peak_ammo'].items():portable.require(0<=value<=level['ammo_caps'][kind],'Finite ammo within actual capacities '+id+'/'+kind)
  if previous is not None:portable.require(level['entry_loadout']==previous,'Exact whole inventory Continue carry '+id)
  if index==0 and id=='pale_ward_01':
   entry=level['entry_loadout'];portable.require(entry['health']==100 and entry['armor']==50 and entry['ammo_pistol']==36 and entry['ammo_shotgun']==12 and len(entry['owned_weapons'])==3,'Normal unseeded campaign entry')
  if receipt['use_heavy_weapons']:portable.require(level['siege_self_hits']==0,'No unsafe heavy-policy self damage '+id)
  if id.startswith('pale_ward_') and id in designs:
   design=designs[id];portable.require(level['total_enemies']==design['enemy_total'],'Actual authored actor total '+id)
   for flag in design['objective_profile']['exit_requires']:portable.require(level['flags'].get(flag,False),'Authored exit precondition '+id+'/'+flag)
   secured={x['checkpoint'] for x in level['interactions'] if x.get('checkpoint') and x.get('accepted')}
   portable.require(secured=={x['id'] for x in design['checkpoints']},'Both physically secured milestone checkpoints '+id)
   if id=='pale_ward_02':
    controls=[x['mechanism'] for x in level['interactions'] if x.get('accepted') and x.get('mechanism','').startswith('Control_isolation_')]
    portable.require(controls==['Control_isolation_'+x.lower() for x in receipt['containment_order']],'Actual accepted Containment control order matches declared branch order')
   if id=='pale_ward_03':portable.require({r['id'] for r in design['rooms'] if not r['optional'] and not r['secret']}<=set(level['visited_rooms']),'Full first descent before shortcuts '+id)
   if any(p['lift'] for p in design['portals']):portable.require(bool(level['lift_traversals']),'Actual lift passenger receipt '+id)
  elif id=='ash_citadel_01' and level.get('authored_ash_approach'):
   portable.require(level['total_enemies']==42,'Ash Approach authored enemy roster')
   for flag in ('brass','brass_key','gate_winch','visited_inner_bridge','finished'):
    portable.require(level['flags'].get(flag,False),'Ash Approach physical objective '+flag)
   secured={x['checkpoint'] for x in level['interactions'] if x.get('checkpoint') and x.get('accepted')}
   portable.require(secured=={'crypt_credential','bridge_winch'},'Ash Approach live checkpoint milestones')
   portable.require({'siege_approach','trench','lower_crypt','stair_tower','battlement','gatehouse','winch','inner_bridge','cloister','furnace_gate'}<=set(level['visited_rooms']),'Ash Approach real route districts and bridge crossing')
  else:
   for flag in ('breaker','power','brass_key','release','red_key','exit_control','exit'):portable.require(level['flags'].get(flag,False),'Unchanged legacy progression '+id+'/'+flag)
   portable.require(all(level['arena_remaining'].get(a)==0 for a in ('arena_one','arena_two','final_arena')),'Legacy mandatory arenas '+id)
  previous=level['exit_loadout']
 console=next((p for p in (path.with_suffix('.console.log'),path.parent/'console.log') if p.is_file()),None)
 if require_clean_logs:portable.require(console is not None,'Clean console log required for route acceptance '+str(path))
 if console:portable.require(not re.search(r'^(?:SCRIPT ERROR:|ERROR:|WARNING:)',console.read_text(),re.M),'Route console contains engine error/warning '+str(console))
 if 'teardown' in receipt:
  teardown=receipt['teardown'];portable.require(teardown['complete'] and teardown['stopped_audio_wall_ms']>=300 and teardown['freed_main_drain_wall_ms']>=250,'Measured actual audio/free wall-time retirement boundary')
 return {'path':str(path),'sha256':sha(path.read_bytes()),'levels':len(levels),'containment_order':receipt['containment_order'],'editor_feature':receipt['editor_feature'],'executable':receipt['executable'],'clean_console':str(console) if console else None,'scope':'Independent semantic audit of driver receipts. Launcher /proc and ELF identity proof are separate; bot times never prove human pacing.'}
def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--require-clean-route-logs',action='store_true');parser.add_argument('--route-report',action='append',type=Path,default=[]);parser.add_argument('--levels',default='pale_ward_01,pale_ward_02,pale_ward_03');parser.add_argument('--baseline-only',action='store_true');parser.add_argument('--design-only',action='store_true');parser.add_argument('--native',action='store_true');parser.add_argument('--main-pack',type=Path);parser.add_argument('--report',type=Path,default=OUT/'source-preflight.json');a=parser.parse_args()
 portable.require(a.report.resolve().is_relative_to(OUT.resolve()),'Evidence restricted to level-redesign-v13');a.report.parent.mkdir(parents=True,exist_ok=True)
 try:
  result=protected_baseline();result['status']='passed';result['baseline_only']=a.baseline_only
  if not a.baseline_only:
   expected=design_contract();result['design']=check_design(expected);expected['selected_levels']=a.levels.split(',');portable.require(bool(expected['selected_levels']) and set(expected['selected_levels'])<=set(l['id'] for l in expected['levels'][:3]),'Selected authored Ward levels');result['selected_levels']=expected['selected_levels']
   if a.route_report:result['route_receipts']=[check_route_receipt(path,expected,a.require_clean_route_logs) for path in a.route_report]
   if not a.design_only and not a.route_report:
    with tempfile.TemporaryDirectory(prefix='eyesore-levels-v13-') as directory:
     temp=Path(directory);input_path=temp/'expected.json';input_path.write_text(json.dumps(expected));target=temp/'native.json'
     command=[str(GODOT)]+(['--no-focus','--position','20000,20000'] if a.native else ['--headless'])+['--audio-driver','Dummy','--max-fps','60','--path',str(ROOT)]
     if a.main_pack:command+=['--main-pack',str(a.main_pack.resolve())]
     command+=['--script',str(ROOT/'tools/check_levels_v13.gd'),'--','--automated-input','--campaign-level=pale_ward_01','--expected='+str(input_path),'--report='+str(target)]
     with a.report.with_suffix('.log').open('w') as log:process=subprocess.run(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,env=dict(os.environ,XDG_DATA_HOME=str(temp/'profile')),timeout=180)
     text=a.report.with_suffix('.log').read_text()
     if target.is_file():result['native']=read(target);a.report.with_suffix('.native.json').write_text(json.dumps(result['native'],indent=2)+'\n')
     portable.require(process.returncode==0 and result.get('native',{}).get('status')=='passed' and not re.search(r'(?:SCRIPT ERROR:|^ERROR:)',text,re.M),'Native level check failed: '+text[-3000:])
   result['packed']=bool(a.main_pack)
 except (portable.AuditError,OSError,ValueError,KeyError,subprocess.SubprocessError) as error:result={'status':'failed','error':str(error),'scope':'Required v13 check incomplete/failed; no acceptance claim.'}
 result['auditor_sha256']=sha(Path(__file__).read_bytes());a.report.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2));return 0 if result['status']=='passed' else 1
if __name__=='__main__':raise SystemExit(main())
