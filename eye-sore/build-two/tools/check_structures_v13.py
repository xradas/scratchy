#!/usr/bin/env python3
"""Independent structural candidate protection and actual Main physics fixture."""
from __future__ import annotations
import argparse,hashlib,json,os,re,subprocess,tempfile
from pathlib import Path
import check_levels_v13 as prior
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'verification/level-redesign-v13/structural'
BASE='0032b97513ce97cafc5284b3fae9531f2f2b2d8f'
GODOT=prior.GODOT
sha=lambda data:hashlib.sha256(data).hexdigest()
def require(ok,message):
 if not ok:raise RuntimeError(message)
def protected_candidate():
 repo=Path(subprocess.check_output(['git','rev-parse','--show-toplevel'],cwd=ROOT,text=True).strip());prefix=ROOT.relative_to(repo).as_posix()+'/'
 raw=subprocess.check_output(['git','ls-tree','-rz','--name-only',BASE,'--',prefix],cwd=repo)
 full=[p.decode() for p in raw.split(b'\0') if p]
 selected={p[len(prefix):]:p for p in full if p[len(prefix):].startswith(('assets/','resources/','scripts/','scenes/','shaders/'))}
 query=''.join(BASE+':'+full+'\n' for full in selected.values()).encode()
 data=subprocess.check_output(['git','cat-file','--batch'],cwd=ROOT,input=query);cursor=0;mapping={};adapter=''
 for path in selected:
  end=data.index(b'\n',cursor);header=data[cursor:end].split();cursor=end+1;require(len(header)==3 and header[1]==b'blob','Missing candidate blob '+path)
  size=int(header[2]);body=data[cursor:cursor+size];cursor+=size+1;mapping[path]=sha(body)
  if path=='scripts/level_route_playtest_v13.gd':adapter=body.decode()
 require(cursor==len(data),'Unexpected candidate Git batch tail')
 allowed={'scripts/stage_level.gd','scripts/reservoir_effect_v13.gd'}
 for index in range(1,4):
  level=f'pale_ward_0{index}';allowed|={f'scenes/campaign/{level}.tscn',f'resources/campaign/{level}-layout.json',f'resources/campaign/{level}-route.json',f'resources/campaign/v13/{level}-author-report.json'}
 protected={p:h for p,h in mapping.items() if p not in allowed}
 # Coordinator approved this exact opt-in report guard after the preserved
 # candidate. Keep the rest of the shipped route adapter byte-identical.
 anchor='\trequire(branch_order in ["AB","BA"],"Containment branch order must be AB or BA")'
 guard='\tif not require(report_dir.is_absolute_path() and not report_dir.begins_with("res://") and report_dir.length()>1 and package_dir.is_absolute_path() and package_dir.length()>1 and report_dir!=package_dir and not report_dir.begins_with(package_dir+"/"),"Report directory must be absolute and outside the source/package directory"):\n\t\treport_dir=OS.get_user_data_dir().path_join("levels-v13-route")\n'
 require(adapter.count(anchor)==1 and adapter.count('\tconfigure_v13()\n')==1,'Frozen adapter patch anchors')
 adapter=adapter.replace(anchor,guard+anchor).replace('\tconfigure_v13()\n','\tconfigure_v13()\n\tif not failures.is_empty():await finish_v13();return\n')
 require(adapter.count('\treport.capture_policy=')==1,'Frozen adapter receipt anchor')
 adapter=adapter.replace('\treport.capture_policy=','\treport.user_arguments=OS.get_cmdline_user_args()\n\treport.capture_policy=')
 protected['scripts/level_route_playtest_v13.gd']=sha(adapter.encode())
 for p,h in protected.items():require((ROOT/p).is_file() and sha((ROOT/p).read_bytes())==h,'Frozen passing-candidate runtime file changed '+p)
 actual={str(p.relative_to(ROOT)) for folder in ('assets','resources','scripts','scenes','shaders') for p in (ROOT/folder).rglob('*') if p.is_file()}
 require(actual==set(mapping),'Runtime file roster differs from passing candidate: '+str({'added':sorted(actual-set(mapping)),'missing':sorted(set(mapping)-actual)}))
 return {'candidate_commit':BASE,'candidate_runtime_blobs':len(mapping),'protected_runtime_files':len(protected),'explicit_allowed_changed_existing_runtime_files':sorted(allowed),'prior_baseline':prior.protected_baseline()}
def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--level',choices=['pale_ward_01','pale_ward_02','pale_ward_03'],default='pale_ward_01');parser.add_argument('--native',action='store_true');parser.add_argument('--main-pack',type=Path);parser.add_argument('--source-only',action='store_true');parser.add_argument('--report',type=Path,required=True);args=parser.parse_args()
 require(args.report.resolve().is_relative_to(OUT.resolve()),'New evidence belongs under structural/');args.report.parent.mkdir(parents=True,exist_ok=True)
 result={'status':'failed','level':args.level}
 try:
  result['protected_candidate']=protected_candidate()
  scene=ROOT/'scenes/campaign'/f'{args.level}.tscn';before=sha(scene.read_bytes());result['scene_sha256']=before
  if not args.source_only:
   with tempfile.TemporaryDirectory(prefix='eyesore-structural-v13-') as directory:
    temp=Path(directory);target=temp/'native.json';command=[str(GODOT)]+(['--position','20000,20000'] if args.native else ['--headless'])+['--audio-driver','Dummy','--max-fps','60','--path',str(ROOT),'--script',str(ROOT/'tools/check_structures_v13.gd'),'--','--automated-input','--level='+args.level,'--report='+str(target)]
    if args.main_pack:command[command.index('--script'):command.index('--script')]=['--main-pack',str(args.main_pack.resolve())]
    result['packed']=bool(args.main_pack)
    log_path=args.report.with_suffix('.log')
    with log_path.open('w') as log:process=subprocess.run(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,env=dict(os.environ,XDG_DATA_HOME=str(temp/'profile')),timeout=240)
    if target.exists():result['actual_main']=json.loads(target.read_text());args.report.with_suffix('.native.json').write_text(json.dumps(result['actual_main'],indent=2)+'\n')
    text=log_path.read_text();require(process.returncode==0 and result.get('actual_main',{}).get('status')=='passed','Actual Main construction fixture failed: '+text[-4000:]);require(not re.search(r'^(?:SCRIPT ERROR:|ERROR:|WARNING:)',text,re.M),'Engine warning/error in strict structural fixture log')
  require(sha(scene.read_bytes())==before,'Scene changed during structural fixture');result['protected_after']=protected_candidate();result['status']='passed'
 except (RuntimeError,OSError,ValueError,KeyError,TypeError,subprocess.SubprocessError) as error:result['error']=str(error)
 result['auditor_sha256']=sha(Path(__file__).read_bytes());args.report.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'status':result['status'],'level':args.level,'checks':len(result.get('actual_main',{}).get('checks',[])),'error':result.get('error')}));return 0 if result['status']=='passed' else 1
if __name__=='__main__':raise SystemExit(main())
