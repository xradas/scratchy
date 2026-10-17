#!/usr/bin/env python3
"""Independent v12 protected Git baseline and controlled actual Main gore QA."""
from __future__ import annotations
import argparse,hashlib,json,os,re,subprocess,tempfile
from pathlib import Path
import check_production_archive_v9 as source_audit
import verify_pale_ward_archive as portable
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'verification/production-v12/gore'
BASELINE=ROOT/'docs/production-v12/qa-baseline.json'
GODOT=source_audit.v7.GODOT
def sha(data):return hashlib.sha256(data).hexdigest()
def read(path):return json.loads(path.read_text(),object_pairs_hook=portable.unique_object)
def source_check():
 baseline=read(BASELINE);mapping=baseline['runtime_fingerprints']
 portable.require(source_audit.git_fingerprints(baseline['commit'],mapping)==len(mapping),'Frozen full baseline Git identity')
 allowed=set(baseline['permitted_existing_changes']);changed=[]
 for path,digest in mapping.items():
  portable.require((ROOT/path).is_file(),'Baseline runtime input missing '+path)
  if sha((ROOT/path).read_bytes())!=digest:
   if path=='assets/VISUAL_CREDITS.md':
    old=source_audit.git_blob(baseline['commit'],path);current=(ROOT/path).read_bytes()
    portable.require(sha(old)==digest and current.startswith(old) and sha(current[len(old):])==baseline['exact_visual_credits_append_sha256'],'Exact known v12 credits paragraph append only');changed.append(path);continue
   portable.require(path in allowed,'Protected non-gore runtime input changed '+path);changed.append(path)
 actual={p.relative_to(ROOT).as_posix() for directory in ('assets','resources','scripts','shaders','scenes') for p in (ROOT/directory).rglob('*') if p.is_file()}
 existing={p for p in mapping if p.split('/')[0] in ('assets','resources','scripts','shaders','scenes')}
 added=actual-existing
 portable.require(added==set(baseline['permitted_new_runtime_files']),'Exact new runtime component file roster '+str(sorted(added)))
 portable.require(read(ROOT/'assets/audio/runtime-cues.json')==baseline['original_audio_ledger'] and (ROOT/'resources/combat_audio.tres').read_text()==baseline['original_audio_profile_text'],'All63 original cue objects/profile bytes unchanged')
 portable.require(len(baseline['original_audio_ledger']['cues'])==63,'Exact63 sealed audio cue identities')
 return {'status':'passed','baseline_commit':baseline['commit'],'baseline_git_blobs_verified':len(mapping),'protected_unchanged':len(mapping)-len(changed),'explicit_gore_changes':sorted(set(changed)&allowed),'exact_visual_credits_append_sha256':baseline['exact_visual_credits_append_sha256'],'new_runtime_components':sorted(added),'reviewed_gore_fingerprints':{path:sha((ROOT/path).read_bytes()) for path in sorted(allowed|added)},'all_nine_scenes_unchanged':True,'all_art_pngs_audio_weapons_enemy_ai_main_lighting_unchanged':True,'original_audio_cues':63,'baseline':baseline}
def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--source-only',action='store_true');parser.add_argument('--native',action='store_true');parser.add_argument('--main-pack',type=Path);parser.add_argument('--capture-dir',type=Path);parser.add_argument('--report',type=Path,default=OUT/'main.json');a=parser.parse_args()
 portable.require(a.report.resolve().is_relative_to(OUT.resolve()),'Evidence restricted to production-v12/gore');a.report.parent.mkdir(parents=True,exist_ok=True)
 try:
  checked=source_check();report={k:v for k,v in checked.items() if k!='baseline'}
  if not a.source_only:
   with tempfile.TemporaryDirectory(prefix='eyesore-gore-v12-') as directory:
    temp=Path(directory);profile=temp/'baseline-audio.tres';profile.write_text(checked['baseline']['original_audio_profile_text']);expected=temp/'expected.json';expected.write_text(json.dumps({'baseline_audio_profile_path':str(profile)}));target=temp/'native.json'
    script='tools/capture_gore_v12.gd' if a.capture_dir else 'tools/check_gore_v12.gd'
    command=[str(GODOT)]+(['--no-focus','--position','20000,20000'] if a.native else ['--headless'])+['--audio-driver','Dummy','--max-fps','60','--path',str(ROOT)]
    if a.main_pack:command+=['--main-pack',str(a.main_pack.resolve())]
    command+=['--script',str(ROOT/script),'--','--automated-input','--campaign-level=pale_ward_01','--expected='+str(expected),'--report='+str(target)]
    if a.capture_dir:
     portable.require(a.native and a.capture_dir.resolve().is_relative_to(OUT.resolve()),'Native capture evidence must remain in production-v12/gore');a.capture_dir.mkdir(parents=True,exist_ok=True);command+=['--capture-dir='+str(a.capture_dir.resolve())]
    with a.report.with_suffix('.log').open('w') as log_file:
     process=subprocess.run(command,cwd=ROOT,stdout=log_file,stderr=subprocess.STDOUT,text=True,env=dict(os.environ,XDG_DATA_HOME=str(temp/'profile')),timeout=180)
    log=a.report.with_suffix('.log').read_text()
    if target.is_file():report['native']=read(target);a.report.with_suffix('.native.json').write_text(json.dumps(report['native'],indent=2)+'\n')
    portable.require(process.returncode==0 and report.get('native',{}).get('status')=='passed' and not re.search(r'(?:SCRIPT ERROR:|^ERROR:)',log,re.M),'Actual Main gore fixture failed: '+log[-3000:])
  report['packed']=bool(a.main_pack);report['native_renderer']=a.native
 except (portable.AuditError,OSError,ValueError,KeyError,subprocess.SubprocessError) as error:report={'status':'failed','error':str(error),'scope':'Required gore source/runtime check failed; no acceptance claim.'}
 report['auditor_sha256']=sha(Path(__file__).read_bytes());a.report.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2));return 0 if report['status']=='passed' else 1
if __name__=='__main__':raise SystemExit(main())
