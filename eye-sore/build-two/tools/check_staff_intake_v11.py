#!/usr/bin/env python3
"""Independent staff roster/protected-source audit and controlled actual Main QA."""
from __future__ import annotations
import argparse,hashlib,json,os,re,struct,subprocess,tempfile
from pathlib import Path
import apply_staff_placements_v11 as placement
ROOT=placement.ROOT
OUT=ROOT/'verification/production-v11/staff'
GODOT=Path('/home/rikki/.local/share/eyesore-tools/4.7.2/Godot_v4.7.2-stable_linux.x86_64')
def sha(data):return hashlib.sha256(data).hexdigest()
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--native',action='store_true');p.add_argument('--main-pack',type=Path);p.add_argument('--verbose',action='store_true');p.add_argument('--source-only',action='store_true');p.add_argument('--allow-protected-change',action='append',default=[]);p.add_argument('--report',type=Path,default=OUT/'main.json');a=p.parse_args()
 assert a.report.resolve().is_relative_to(OUT.resolve());a.report.parent.mkdir(parents=True,exist_ok=True)
 report={}
 try:
  c=json.loads(placement.CONTRACT.read_text());text=(ROOT/c['scene']).read_text();after,records=placement.patch(text,c)
  assert after==text,'Six authored staff placements are not applied'
  changed=[path for path,digest in c['protected_baseline_fingerprints'].items() if not (ROOT/path).is_file() or sha((ROOT/path).read_bytes())!=digest]
  assert set(changed)==set(a.allow_protected_change),'Explicit protected-change allowlist must exactly match actual changes: '+str(changed)
  assert all(x.startswith(('scripts/','shaders/')) for x in changed),'Audio or other campaign scene cannot be excepted'
  before=c['baseline_audio_ledger'];actual=json.loads((ROOT/'assets/audio/runtime-cues.json').read_text());expected=json.loads(json.dumps(before))
  aliases={}
  for kind,old in [('infected_scientist','unsealed'),('infected_security','vessel')]:
   for role in ('attack_warning','hurt','death'):
    key=kind+'_'+role;aliases[key]=old+'_'+role;expected['cues'][key]=dict(before['cues'][aliases[key]],source_alias=aliases[key],source_manifest='concepts/audio-v4/manifest.json')
  assert actual==expected,'Only exact six existing-voice cue aliases allowed'
  assert len(before['cues'])==57 and len(actual['cues'])==63
  art=json.loads((ROOT/'assets/combat_art.json').read_text());art_spec=json.loads((ROOT/'docs/production-v11/staff-art.json').read_text());art_sources={}
  for kind in ('infected_scientist','infected_security'):
   registration=art['enemies'][kind];source=art_spec['assets'][kind];data=(ROOT/registration['file'].removeprefix('res://')).read_bytes()
   assert registration['file']==source['runtime'] and sha(data)==registration['sha256']==source['sha256']==sha(Path(source['source']).read_bytes()),'Exact original generated PNG bytes '+kind
   dimensions=struct.unpack('>II',data[16:24]);assert list(dimensions)==registration['source_dimensions']==source['source_dimensions']==[1254,1254]
   options=registration['sprite_options'];regions=options['source_regions'];assert regions==source['regions'] and options['frame_pivots']==source['frame_pivots'] and len(regions)==64
   rectangles=[]
   for frame in range(64):
    x,y,w,h=regions[str(frame)];assert all(isinstance(v,int) for v in (x,y,w,h)) and w>0 and h>0 and x>=0 and y>=0 and x+w<=dimensions[0] and y+h<=dimensions[1]
    assert all(x+w<=a or a+c<=x or y+h<=b or b+d<=y for a,b,c,d in rectangles),'Overlapping explicit native source regions '+kind
    rectangles.append((x,y,w,h));px,py=options['frame_pivots'][str(frame)];assert 0<=px<=w and 0<=py<=h
   assert sum(w*h for x,y,w,h in rectangles)==dimensions[0]*dimensions[1],'Native source regions must partition full untouched atlas'
   assert registration['columns']==registration['directions']==options['direction_count']==options['rows']==8
   art_sources[kind]={'sha256':sha(data),'source_dimensions':list(dimensions),'explicit_native_regions':64,'pixel_processing':source['pixel_processing']}
  report={'status':'passed','protected_files':len(c['protected_baseline_fingerprints']),'explicit_existing_code_changes':changed,'old_cues_preserved':57,'exact_voice_aliases':aliases,'native_art_sources':art_sources,'placements':records,'actor_total':36,'arena_counts':c['arena_counts']}
  if not a.source_only:
   with tempfile.TemporaryDirectory(prefix='eyesore-staff-v11-') as directory:
    temp=Path(directory);expected_path=temp/'expected.json';base=temp/'baseline-profile.tres';base.write_text(c['baseline_audio_profile_text']);expected_path.write_text(json.dumps(dict(c,baseline_profile_path=str(base),aliases=aliases)))
    output=temp/'native.json';command=[str(GODOT)]+(['--verbose'] if a.verbose else [])+(['--no-focus','--position','20000,20000'] if a.native else ['--headless'])+['--audio-driver','Dummy','--max-fps','60','--path',str(ROOT)]
    if a.main_pack:command+=['--main-pack',str(a.main_pack.resolve())]
    command+=['--script',str(ROOT/'tools/check_staff_intake_v11.gd'),'--','--automated-input','--campaign-level=pale_ward_01','--expected='+str(expected_path),'--report='+str(output)]
    process=subprocess.run(command,capture_output=True,text=True,env=dict(os.environ,XDG_DATA_HOME=str(temp/'profile')),timeout=120)
    log=process.stdout+process.stderr;a.report.with_suffix('.log').write_text(log)
    if output.is_file():report['native']=json.loads(output.read_text());a.report.with_suffix('.native.json').write_text(json.dumps(report['native'],indent=2)+'\n')
    assert process.returncode==0 and report.get('native',{}).get('status')=='passed' and not re.search(r'(?:SCRIPT ERROR:|^ERROR:)',log,re.M),'Actual Main failed: '+log[-3000:]
 except (AssertionError,OSError,ValueError,KeyError,subprocess.SubprocessError) as error:report.update(status='failed',error=str(error))
 report['fixture_sha256']=sha(Path(__file__).read_bytes());report['packed']=bool(a.main_pack);report['native_renderer']=a.native;report['fixture_mode']='Pinned trusted editor reads packaged resources via --main-pack; shipped ELF never executed.' if a.main_pack else 'Source resources; temporary user profile.';a.report.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2));return 0 if report['status']=='passed' else 1
if __name__=='__main__':raise SystemExit(main())
