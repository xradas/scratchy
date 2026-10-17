import sys,json,hashlib,subprocess,contextlib,io
from pathlib import Path
from unittest.mock import patch
root=Path.cwd();sys.path.insert(0,str(root/'tools'));import author_levels_v13 as a
prefix=subprocess.check_output(['git','rev-parse','--show-prefix'],text=True).strip()
def old(path):return subprocess.check_output(['git','show','0032b975:'+prefix+path])
captured={}
def capture(path,text,*args,**kwargs):captured[path]=text;return len(text)
with patch.object(Path,'write_text',capture),contextlib.redirect_stdout(io.StringIO()):
 for level in a.WARD:a.author_selected(level)
outputs={str(p.relative_to(root)):p.read_text()==text for p,text in captured.items()}
base=json.load(open('/tmp/eyesore-v13-preserved-files.json'));changed=[p for p,d in base.items() if hashlib.sha256((root/p).read_bytes()).hexdigest()!=d]
levels=json.load(open('docs/level-redesign-v13/levels.json'))['levels'];profiles={};rosters={};copies={}
for l in levels:
 path='resources/campaign/v13/'+l['id']+'-objectives.tres';profiles[path]=old(path)==(root/path).read_bytes()
 prior=json.loads(old('resources/campaign/'+l['id']+'-route.json'));new=json.load(open('resources/campaign/'+l['id']+'-route.json'))
 rosters[l['id']]={'same_ids_and_types':[(e['stable_id'],e['kind']) for e in prior['enemy_spawns']]==[(e['stable_id'],e['kind']) for e in new['enemy_spawns']], 'old_count':len(prior['enemy_spawns']),'new_count':len(new['enemy_spawns']),'moved':[{'id':e['stable_id'],'before':b['position'],'after':e['position']} for b,e in zip(prior['enemy_spawns'],new['enemy_spawns']) if b['position']!=e['position']]}
 copies[l['id']]=json.load(open('docs/level-redesign-v13/'+l['id']+'.json'))==l
report={'passed':all(outputs.values()) and not changed and all(profiles.values()) and all(r['same_ids_and_types'] for r in rosters.values()) and all(copies.values()),'generated_outputs_byte_identical_without_writing':outputs,'protected_baseline_files':len(base),'protected_changed':changed,'objective_resources_byte_identical_to_0032b975':profiles,'rosters':rosters,'authoritative_json_copies_equal':copies,'scene_sha256':{l['id']:hashlib.sha256(Path('scenes/campaign/'+l['id']+'.tscn').read_bytes()).hexdigest() for l in levels},'scope':'Reproducibility, protected content and identity checks. Does not claim physical/combat/order acceptance.'}
Path('/tmp/eyesore-v13-structural-author-final.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
