#!/usr/bin/env python3
"""Strict selected-audio source identity and actual Main event/voice QA.

No applier/packager import or production writes. Temporary settings protect the
real profile. Native Main test uses real combat cadence and selected imported OGG.
"""
from __future__ import annotations
import argparse,copy,hashlib,json,os,re,subprocess,tempfile
from pathlib import Path
import check_production_archive_v9 as source_audit
import verify_pale_ward_archive as portable
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'verification/production-v10/audio'
CHOSEN={'pistol':'dry','shotgun':'A','twin_shotgun':'B'}
CHANGED={'assets/audio/runtime-cues.json','resources/combat_audio.tres','assets/audio/CREDITS.md'}
CREDITS_APPEND_SHA256='bd8e84d3ba71673cb9b555b6efb074ce00cad92ed21ce065706734b3da80354a'
def sha(data):return hashlib.sha256(data).hexdigest()
def read(path):return json.loads(path.read_text(),object_pairs_hook=portable.unique_object)
def cue_block(text,identifier):
 blocks=list(re.finditer(r'^\[sub_resource[^\n]*\]\n.*?(?=^\[|\Z)',text,re.M|re.S))
 found=[m for m in blocks if 'identifier = &"'+identifier+'"\n' in m.group()]
 portable.require(len(found)==1,'Unique original selected cue block '+identifier)
 return found[0]
def expected_profile(original,selected):
 text=original
 for item in selected:
  rid=re.escape(item['profile_ext_resource_id'])
  pattern=r'(^\[ext_resource type="AudioStream" path=")'+re.escape(item['before']['file'])+r'(" id="'+rid+r'"\]$)'
  text,count=re.subn(pattern,lambda m:m[1]+item['runtime_file']+m[2],text,flags=re.M)
  portable.require(count==1,'Exact original selected stream registration '+item['cue'])
  block=cue_block(text,item['cue']);body=block.group()
  portable.require('gain_db =' not in body and 'bus = &"Weapons"\n' in body,'Expected unmodified default0dB selected cue '+item['cue'])
  body=body.replace('bus = &"Weapons"\n','bus = &"Weapons"\ngain_db = 4.0\n',1)
  text=text[:block.start()]+body+text[block.end():]
 return text

def validate_sources(mapping=None):
 baseline=read(ROOT/'docs/production-v10/baseline.json');fingerprints=baseline['baseline_fingerprints']
 spec=read(ROOT/'docs/production-v10/audio-selection.json');manifest=read(ROOT/'concepts/audio-v9/manifest.json')
 portable.require(sha((ROOT/'concepts/audio-v9/manifest.json').read_bytes())==spec['audition_manifest_sha256'],'Exact selected audition manifest')
 selected=spec['selected'];portable.require(len(selected)==3 and {x['weapon']:x['selected_row'] for x in selected}==CHOSEN,'Exact explicit user selection dry/A/B')
 expected_ledger=copy.deepcopy(baseline['baseline_ledger'])
 old_ledger=source_audit.git_blob(baseline['baseline_runtime_source_commit'],'assets/audio/runtime-cues.json')
 portable.require(sha(old_ledger)==fingerprints['assets/audio/runtime-cues.json'] and json.loads(old_ledger)==expected_ledger,'Sealed v9 ledger/embedded baseline identity')
 portable.require(sha(baseline['baseline_profile_text'].encode())==fingerprints['resources/combat_audio.tres'],'Sealed exact v9 native profile text')
 wav_directory='assets/audio/selected-v10/source-wav';ignore_path=wav_directory+'/.gdignore'
 policy=spec['source_wav_policy']
 portable.require(policy['directory']==wav_directory and policy['godot_ignore_file']==ignore_path and (ROOT/ignore_path).read_bytes()==b'','Exact empty Godot ignore marker for archival WAV sources')
 relocations=policy['relocations']
 portable.require(len(relocations)==3 and {x['weapon'] for x in relocations}==set(CHOSEN),'Exactly3 archival WAV relocations')
 new_assets={ignore_path};records=[]
 for item in selected:
  weapon=item['weapon'];cue=item['cue']
  portable.require(cue==weapon+'_fire' and item['runtime_file']=='res://assets/audio/selected-v10/'+cue+'.ogg' and item['gain_db']==baseline['playback_gain_db']==4.0,'Exact selected path/common4dB '+weapon)
  portable.require(item['before']==expected_ledger['cues'][cue],'Exact selected original record '+weapon)
  row=next(r for r in manifest['rows'] if r['weapon']==weapon and r['kind']==CHOSEN[weapon])
  for fmt in ('ogg','wav'):
   path=item['selected_assets'][fmt]
   expected_path=('assets/audio/selected-v10/' if fmt=='ogg' else wav_directory+'/')+cue+'.'+fmt
   portable.require(path==expected_path,'Exact selected asset basename/directory '+weapon)
   digest=sha((ROOT/path).read_bytes())
   portable.require(digest==item['selected_sha256'][fmt]==row['individual'][fmt+'_sha256']==sha((ROOT/item['audition_files'][fmt]).read_bytes()),'Exact selected audition bytes '+path)
   new_assets.add(path)
   if fmt=='ogg':new_assets.add(path+'.import')
  relocation=next(x for x in relocations if x['weapon']==weapon)
  old_wav='assets/audio/selected-v10/'+cue+'.wav'
  portable.require(relocation['old_wav_path']==old_wav and relocation['new_wav_path']==item['selected_assets']['wav'] and relocation['wav_sha256_unchanged']==item['selected_sha256']['wav'] and relocation['old_import_sidecar_removed']==old_wav+'.import','Exact source-only WAV relocation record '+weapon)
  portable.require(not (ROOT/old_wav).exists() and not (ROOT/(old_wav+'.import')).exists() and not (ROOT/(item['selected_assets']['wav']+'.import')).exists(),'Unsupported WAV source cannot be imported '+weapon)
  portable.require(sha(Path(relocation['failed_import_sidecar_preserved_external']).read_bytes())==relocation['failed_import_sidecar_sha256'],'Failed WAV import sidecar evidence retained '+weapon)
  portable.require(sha((ROOT/item['source_original']).read_bytes())==item['source_original_sha256'] and sha((ROOT/item['license_evidence']).read_bytes())==item['license_evidence_sha256'],'Recorded original/license evidence identity '+weapon)
  after=dict(item['before'],file=item['runtime_file'],gain_db=4.0,source_manifest='concepts/audio-v9/manifest.json',source_ids=[weapon],selected_row=CHOSEN[weapon],selection_manifest='docs/production-v10/audio-selection.json')
  expected_ledger['cues'][cue]=after
  records.append({'weapon':weapon,'cue':cue,'runtime_file':item['runtime_file'],'gain_db':4.0,'selected_row':CHOSEN[weapon],'sha256':item['selected_sha256']})
 portable.require(read(ROOT/'assets/audio/runtime-cues.json')==expected_ledger,'Only exact selected3 stream/gain/provenance ledger patch permitted')
 portable.require((ROOT/'resources/combat_audio.tres').read_text()==expected_profile(baseline['baseline_profile_text'],selected),'Only exact3 selected stream/gain native profile changes permitted')
 untouched={k:v for k,v in expected_ledger['cues'].items() if k not in {x['cue'] for x in selected}}
 portable.require(len(untouched)==54 and untouched=={k:v for k,v in baseline['baseline_ledger']['cues'].items() if k in untouched},'All54 other cues exactly preserved')
 old_credits=source_audit.git_blob(baseline['baseline_runtime_source_commit'],'assets/audio/CREDITS.md')
 credits=(ROOT/'assets/audio/CREDITS.md').read_bytes()
 portable.require(sha(old_credits)==fingerprints['assets/audio/CREDITS.md'] and credits.startswith(old_credits) and sha(credits[len(old_credits):])==CREDITS_APPEND_SHA256,'Exact known selected-source attribution append; all old credits preserved')
 for path,digest in fingerprints.items():
  if path not in CHANGED:portable.require((ROOT/path).is_file() and sha((ROOT/path).read_bytes())==digest,'Unrelated v9 runtime input changed '+path)
 actual_assets={p.relative_to(ROOT).as_posix() for p in (ROOT/'assets').rglob('*') if p.is_file()}
 portable.require(actual_assets=={p for p in fingerprints if p.startswith('assets/')}|new_assets,'Only new3 runtime OGG/imports,3 archival WAV and empty ignore marker allowed')
 if mapping is not None:
  for path in new_assets-{ignore_path}:portable.require(path in mapping,'Selected asset absent from full source snapshot '+path)
  portable.require(ignore_path not in mapping,'Dotfile exclusion in source snapshot remains unchanged; ignore marker verified separately')
 music={p:hashval for p,hashval in fingerprints.items() if p.startswith('assets/audio/music/') and p.endswith('.ogg')}
 portable.require(len(music)==3,'Exactly3 preserved music streams')
 return {'selected':records,'baseline':baseline,'selection_spec':spec,'expected_ledger':expected_ledger,'new_assets':sorted(new_assets),'archival_wav_ignore_marker':{'path':ignore_path,'sha256':sha(b'')},'protected_runtime_files':len(fingerprints)-len(CHANGED),'other_cues_preserved':54,'music_sha256':music,'all_nine_campaign_scenes_preserved':True,'scope':'Exact three selected audition OGG/WAV copies; archival WAV retained in explicitly ignored source directory, only OGG imported. Exact3 cue stream/gain/provenance changes and exact known credits append. All other baseline assets/scripts/shaders/gameplay resources/scenes/buses/music protected; no new audio processing or source research.'}

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--native',action='store_true');p.add_argument('--main-pack',type=Path);p.add_argument('--source-only',action='store_true');p.add_argument('--report',type=Path,default=OUT/'main.json');a=p.parse_args()
 portable.require(a.report.resolve().is_relative_to(OUT.resolve()),'Evidence output restricted to production-v10/audio')
 a.report.parent.mkdir(parents=True,exist_ok=True)
 try:
  preservation=validate_sources();report={k:v for k,v in preservation.items() if k not in ('baseline','selection_spec','expected_ledger')}
  if a.source_only:report['status']='passed'
  else:
   with tempfile.TemporaryDirectory(prefix='eyesore-selected-v10-') as directory:
    temporary=Path(directory);baseline=temporary/'baseline-profile.tres';baseline.write_text(preservation['baseline']['baseline_profile_text'])
    expected=temporary/'expected.json';expected.write_text(json.dumps({'baseline_profile_path':str(baseline),'selected':preservation['selected']}))
    native_report=temporary/'main.json'
    command=[str(source_audit.v7.GODOT)]
    command+=['--no-focus','--position','20000,20000'] if a.native else ['--headless']
    command+=['--audio-driver','Dummy','--max-fps','60','--path',str(ROOT)]
    if a.main_pack:command+=['--main-pack',str(a.main_pack.resolve())]
    command+=['--script',str(ROOT/'tools/check_selected_audio_v10.gd'),'--','--automated-input','--campaign-level=pale_ward_01','--expected='+str(expected),'--report='+str(native_report)]
    process=subprocess.run(command,cwd=temporary,env=dict(os.environ,XDG_DATA_HOME=str(temporary/'profile')),capture_output=True,text=True,timeout=90)
    log=process.stdout+process.stderr;a.report.with_suffix('.log').write_text(log)
    portable.require(native_report.is_file(),'No actual Main report: '+log[-3000:])
    report['native']=read(native_report);a.report.with_suffix('.native.json').write_text(json.dumps(report['native'],indent=2)+'\n');report['status']=report['native']['status'];report['packed']=bool(a.main_pack);report['audio_driver']='Dummy';report['max_fps']=60;report['native_renderer']=a.native
    portable.require(process.returncode==0 and report['status']=='passed' and not re.search(r'(?:SCRIPT ERROR:|^ERROR:)',log,re.M),'Actual Main audio QA failed: '+log[-3000:])
 except (portable.AuditError,OSError,ValueError,KeyError,StopIteration,subprocess.SubprocessError) as error:report={'status':'failed','error':str(error),'scope':'Required selected-audio check failed; no acceptance claim.'}
 report['auditor_sha256']=sha(Path(__file__).read_bytes());a.report.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2));return 0 if report['status']=='passed' else 1
if __name__=='__main__':raise SystemExit(main())
