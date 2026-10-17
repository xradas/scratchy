#!/usr/bin/env python3
"""Audit genuine Main campaign route receipts, including the Intake return loop."""
import argparse, collections, hashlib, json, shutil
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--input',type=Path,required=True)
p.add_argument('--output',type=Path,required=True)
p.add_argument('--source-commit',required=True)
p.add_argument('--export',action='store_true')
a=p.parse_args();root=Path(__file__).resolve().parents[1]; a.output.mkdir(parents=True,exist_ok=True)
read=lambda f:json.loads(f.read_text())
catalog=read(root/'resources/campaign/catalog.json'); expected=[l['id'] for c in catalog['chapters'] for l in c['levels']]; caps=read(root/'resources/campaign/balance-budget.json')['ammo_caps'];profiles={}
for name in ('normal','heavy'):
 d=a.input/name; route=read(d/'campaign-all-route.json');launch=read(d/'launch.json');levels=route['levels']
 assert route['failures']==[] and route['levels_completed']==9 and route['finale']=='CAMPAIGN COMPLETE',route
 assert [l['level'] for l in levels]==expected
 assert route['use_heavy_weapons']==(name=='heavy')
 assert launch['exit_code']==0 and launch['cwd']=='/tmp'
 assert launch['observed_proc_cwd']==('/tmp' if a.export else str(root))
 assert launch['command']==launch['observed_proc_cmdline'] and launch['source_commit']==a.source_commit
 assert route['editor_feature'] is (not a.export)
 initial=levels[0]['entry_loadout'];assert [initial[k] for k in ('health','armor','ammo_pistol','ammo_shotgun','ammo_rivets','ammo_rockets')]==[100,50,36,12,0,0]
 assert len(initial['owned_weapons'])==3
 shots=collections.Counter();kills=collections.Counter();peak={k:0 for k in caps}
 for i,l in enumerate(levels):
  assert l['completed'] and l['health']>0 and l['kills']>0 and l['shots']>0 and l['secret_used'] is False and l['siege_self_hits']==0
  assert l['ammo_caps']==caps
  if i: assert l['entry_loadout']==levels[i-1]['exit_loadout']
  for key in ('entry_ammo','peak_ammo','exit_ammo'):
   assert set(l[key])==set(caps)
   assert all(isinstance(l[key][k],int) and 0<=l[key][k]<=caps[k] for k in caps)
  for k in caps: peak[k]=max(peak[k],l['peak_ammo'][k])
  assert all(l['flags'].get(k) for k in ('breaker','power','brass_key','release','red_key','clear_arena_one','clear_arena_two','clear_final_arena','exit_control','exit'))
  assert any(e['mechanism']=='ExitControl' and e['input']=='E' and e['accepted'] for e in l['interactions'])
  shots.update(l['weapon_shots']);kills.update(l['weapon_kills'])
 intake=levels[0];labels=[s['segment'] for s in intake['segments']]
 assert 'Portal key_console→return_store' in labels and 'Portal return_store→service' in labels
 shortcut=[e for e in intake['interactions'] if e['mechanism']=='Door_shortcut_one' and e['input']=='E' and e['accepted']]
 assert shortcut, 'No actual shortcut release E'
 for f in d.iterdir():
  if f.is_file():shutil.copyfile(f,a.output/f'{name}-{f.name}')
 profiles[name]={'passed':True,'levels_completed':9,'kills':sum(l['kills'] for l in levels),'exact_carry_transitions':8,'peak_ammo':peak,'weapon_shots':dict(shots),'weapon_kills':dict(kills),'secret_levels':0,'siege_self_hits':0,'intake_loop_segments':['Portal key_console→return_store','Portal return_store→service'],'accepted_shortcut_interactions':shortcut,'launch':f'{name}-launch.json','raw_receipt':f'{name}-campaign-all-route.json'}
result={'passed':True,'source_commit':a.source_commit,'ordered_levels':expected,'profiles':profiles,'mode':'actual exported ELF' if a.export else 'actual source Main','scope':'Automated physical finite-ammo live-combat Main, explicit new Intake store loop and E shortcut, full nine-level continuation. Headless fixed60; not human art/pacing/listening acceptance.'}
(a.output/'campaign-audit.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
