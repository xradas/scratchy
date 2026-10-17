import sys,json,hashlib,subprocess,contextlib,io
from pathlib import Path
from unittest.mock import patch
root=Path.cwd();sys.path.insert(0,str(root/'tools'));import author_levels_v13 as author
prefix=subprocess.check_output(['git','rev-parse','--show-prefix'],text=True).strip();baseline='94c4f265371e5c21c9d4411e5897577799705bd7'
def old(path):return subprocess.check_output(['git','show',baseline+':'+prefix+path])
captured={}
def capture(path,text,*args,**kwargs):captured[path]=text;return len(text)
with patch.object(Path,'write_text',capture),contextlib.redirect_stdout(io.StringIO()):
 for level in author.WARD:author.author_selected(level)
outputs={str(p.relative_to(root)):p.read_text()==text for p,text in captured.items()}
base=json.load(open('/tmp/eyesore-v13-preserved-files.json'));changed=[p for p,d in base.items() if hashlib.sha256((root/p).read_bytes()).hexdigest()!=d]
levels=json.load(open('docs/level-redesign-v13/levels.json'))['levels'];rosters={};dependencies={};copies={};structures={}
for l in levels:
 before=json.loads(old('resources/campaign/'+l['id']+'-route.json'));now=json.load(open('resources/campaign/'+l['id']+'-route.json'))
 rosters[l['id']]={'same_ids_and_types':[(e['stable_id'],e['kind']) for e in before['enemy_spawns']]==[(e['stable_id'],e['kind']) for e in now['enemy_spawns']],'before_count':len(before['enemy_spawns']),'after_count':len(now['enemy_spawns']),'relocated':[{'id':e['stable_id'],'before':b['position'],'after':e['position'],'actual_room':e['actual_room'],'activation_room':e['activation_room'],'arena_id':e['arena_id']} for b,e in zip(before['enemy_spawns'],now['enemy_spawns']) if b['position']!=e['position']]}
 oldprofile=before['objective_profile'];newprofile=l['objective_profile'];dependencies[l['id']]={'objectives_ids_requires_completion_exact':[{k:o[k] for k in ['id','requires','complete_flag']} for o in oldprofile['objectives']]==[{k:o[k] for k in ['id','requires','complete_flag']} for o in newprofile['objectives']],'controls_keys_exit_initial_exact':all(oldprofile[k]==newprofile[k] for k in ['controls','keys','exit_requires','initial_flags']),'existing_encounters_exact':all(newprofile['encounters'][k]==v for k,v in oldprofile['encounters'].items()),'supplies_exact':before['supplies']==now['supplies']}
 structures[l['id']]=all(next(c for c in now['structural_connections'] if c['id']==b['id'])==b for b in before['structural_connections'])
 copies[l['id']]=json.load(open('docs/level-redesign-v13/'+l['id']+'.json'))==l
report={'passed':all(outputs.values()) and not changed and all(r['same_ids_and_types'] for r in rosters.values()) and all(all(x.values()) for x in dependencies.values()) and all(copies.values()) and all(structures.values()),'baseline':baseline,'generated_outputs_byte_identical_without_writing':outputs,'protected_baseline_files':len(base),'protected_changed':changed,'rosters':rosters,'required_dependencies_and_supply_preservation':dependencies,'existing_v13_structural_contracts_unchanged':structures,'matching_source_copies':copies,'scene_sha256':{l['id']:hashlib.sha256(Path('scenes/campaign/'+l['id']+'.tscn').read_bytes()).hexdigest() for l in levels},'scope':'Generator reproducibility/source identity only. New objective text and optional accepted-pickup groups intentional. No physical/combat/human acceptance inferred.'}
Path('/tmp/eyesore-v14-author-repro.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({k:v for k,v in report.items() if k not in ['rosters']},indent=2))
