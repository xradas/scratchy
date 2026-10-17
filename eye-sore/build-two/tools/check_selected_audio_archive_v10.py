#!/usr/bin/env python3
"""Independent audio-only v10 PCK/source audit; archived ELF is never executed."""
from __future__ import annotations
import argparse,json,re,subprocess,tarfile,tempfile
from pathlib import Path
import check_selected_audio_v10 as selected_audit
import check_production_archive_v9 as source_audit
import check_intake_archive_v7 as v7
import check_theme_pack
import verify_pale_ward_archive as portable
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'verification/production-v10/audio'
sha=selected_audit.sha
read=selected_audit.read

NATIVE_SELECTED=r'''extends SceneTree
var expected: Dictionary
var output := ""
var failures: Array[String] = []
var checks := 0
func _initialize():
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--expected="):expected=JSON.parse_string(FileAccess.get_file_as_string(arg.trim_prefix("--expected=")))
  if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
 call_deferred("run")
func check(ok: bool,label: String):
 checks+=1
 if not ok:failures.append(label)
func paths(cue: Resource) -> Array:
 var result:=[]
 for stream in cue.variations:result.append(stream.resource_path)
 return result
func run():
 var current: Resource=load("res://resources/combat_audio.tres")
 var before: Resource=load(expected.baseline_profile_path)
 var old:={}
 for cue in before.cues:old[String(cue.identifier)]=cue
 check(current.cues.size()==57 and before.cues.size()==57,"Exact57 native cues, no additions/removals")
 var preserved:=0;var chosen:=0
 for cue in current.cues:
  var id:=String(cue.identifier)
  check(old.has(id),"Original cue identity "+id)
  if not old.has(id):continue
  var original:Resource=old[id]
  check(cue.bus==original.bus and cue.spatial==original.spatial,"Native bus/spatial preserved "+id)
  if expected.selected.has(id):
   var record:Dictionary=expected.selected[id]
   check(paths(cue)==[record.runtime_file],"Exact selected native variation "+id)
   check(is_equal_approx(cue.gain_db,float(record.gain_db)),"Exact common4dB native playback gain "+id)
   check(cue.variations[0] is AudioStreamOggVorbis and cue.variations[0].get_length()>.1,"Selected OGG decoded "+id)
   chosen+=1
  else:
   check(cue.gain_db==original.gain_db and paths(cue)==paths(original),"Unselected native gain/variations preserved "+id)
   preserved+=1
 check(chosen==3 and preserved==54,"Exactly3 selected changes and54 unchanged native cues")
 check(current.music.resource_path==before.music.resource_path and current.music_gain_db==before.music_gain_db,"Native Ward music path/gain unchanged")
 for path in expected.json_hashes:check(FileAccess.get_sha256(path)==expected.json_hashes[path],"Validated actual embedded JSON identity "+path)
 var report={"status":"passed" if failures.is_empty() else "failed","checks":checks,"failures":failures,"selected_cues":chosen,"other_cues_preserved":preserved,"scope":"External trusted editor reads actual source/PCK profile versus sealed v9 profile. All57 cue identities/buses/spatial, selected3 exactpaths/+4dB/decodedOGG, other54 gain/streams, music registration and embedded validated JSON. Archived ELF never executed; no listening claim."}
 FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
 print("SELECTED_AUDIO_ARCHIVE_V10 ",report.status," ",checks," ",failures)
 quit(0 if failures.is_empty() else 1)
'''
def native_probe(temporary,pack,preservation,a):
 base=[str(v7.GODOT),'--headless','--audio-driver','Dummy','--path',str(temporary if pack else ROOT)]
 if pack:base+=['--main-pack',str(pack)]
 (temporary/'project.godot').write_text('[application]\nconfig/name="Independent selected-audio v10 audit"\n')
 spec=v7.expected();chosen={x['cue']:x for x in preservation['selection_spec']['selected']}
 changed=0
 # The frozen v7 reader preserves48 early cue objects. Replace expectations
 # ONLY for the three explicitly approved stream/gain changes; all its other
 # bus/spatial/object/geometry/pickup checks remain unchanged.
 for record in spec['prior_cues'][:48]:
  if record['identifier'] not in chosen:continue
  item=chosen[record['identifier']]
  portable.require(record['variations']==[item['before']['file']] and record['gain_db']==item['before']['gain_db'],'Exact original frozen selected native cue identity')
  record['variations']=[item['runtime_file']];record['gain_db']=4.0;changed+=1
 portable.require(changed==3,'Exact3 explicit native expected patch records')
 expected=temporary/'expected.json';expected.write_text(json.dumps(spec));native_report=temporary/'native.json'
 process=subprocess.run(base+['--script',str(ROOT/'tools/check_intake_archive_v7.gd'),'--','--expected='+str(expected),'--report='+str(native_report)],cwd=temporary,capture_output=True,text=True,timeout=180)
 log=process.stdout+process.stderr;a.report.with_suffix('.log').write_text(log)
 portable.require(native_report.is_file(),'No full trusted v7 native report: '+log[-3000:]);native=read(native_report)
 portable.require(process.returncode==0 and native['status']=='passed' and not re.search(r'(?:SCRIPT ERROR:|^ERROR:)',log,re.M),'Full native read failed: '+log[-3000:])
 portable.require(native['props']==508 and native['pickups']==711 and native['cue_count']==57,'Exact existing508props/711pickups/57cues')
 baseline=temporary/'v9-profile.tres';baseline.write_text(preservation['baseline']['baseline_profile_text'])
 expected.write_text(json.dumps({'baseline_profile_path':str(baseline),'selected':{x['cue']:x for x in preservation['selected']},'json_hashes':{'res://assets/combat_art.json':preservation['baseline']['baseline_fingerprints']['assets/combat_art.json'],'res://assets/audio/runtime-cues.json':sha((ROOT/'assets/audio/runtime-cues.json').read_bytes())}}))
 script=temporary/'selected_v10.gd';script.write_text(NATIVE_SELECTED);output=temporary/'selected.json'
 process=subprocess.run(base+['--script',str(script),'--','--expected='+str(expected),'--report='+str(output)],cwd=temporary,capture_output=True,text=True,timeout=60)
 log=process.stdout+process.stderr;a.report.with_suffix('.selected.log').write_text(log)
 portable.require(output.is_file(),'No explicit native selected-cue report: '+log[-3000:]);selected=read(output)
 a.report.with_suffix('.selected.json').write_text(json.dumps(selected,indent=2)+'\n')
 portable.require(process.returncode==0 and selected['status']=='passed' and not re.search(r'(?:SCRIPT ERROR:|^ERROR:)',log,re.M),'Explicit selected native read failed: '+log[-3000:])
 return native,selected

def audit(a):
 mapping,policy=source_audit.snapshot_policy()
 preservation=selected_audit.validate_sources(mapping)
 git_count=source_audit.git_fingerprints(a.expected_commit,mapping) if a.expected_commit else None
 report={k:v for k,v in preservation.items() if k not in ('baseline','selection_spec','expected_ledger')}
 report.update({'source_preflight':a.source_preflight,'source_fingerprints_verified':len(mapping),'source_tree_sha256':sha(json.dumps(mapping,sort_keys=True).encode()),'source_snapshot_policy':policy,'git_checkpoint_blobs_verified':git_count,'explicit_changed_existing_inputs':sorted(selected_audit.CHANGED),'native_expected_changes':'Only selected pistol_fire/shotgun_fire/twin_shotgun_fire variations/gain replace matching3 frozen expected objects; no other old cue/property/pickup/geometry check removed.'})
 with tempfile.TemporaryDirectory(prefix='eyesore-selected-v10-archive-') as directory:
  temporary=Path(directory);pack=None
  if not a.source_preflight:
   portable.require(a.archive is not None and a.expected_commit is not None,'Archive and full --expected-commit required')
   structural=portable.verify(a.archive);portable.require(structural['source_commit']==a.expected_commit,'Packaged source commit mismatch')
   record=read(a.archive.parent/'ARCHIVE.json')
   portable.require(record['sha256']==structural['archive_sha256'] and record['bytes']==a.archive.stat().st_size and record['path']==a.archive.name,'External archive checksum identity')
   with tarfile.open(a.archive,'r:gz') as bundle:
    sums=portable.checksums(bundle.extractfile('SOURCE_SHA256SUMS').read().decode(),'SOURCE_SHA256SUMS')
    portable.require(sums==mapping,'Exact archive/current full source fingerprint roster')
    build=json.loads(bundle.extractfile('BUILD.json').read(),object_pairs_hook=portable.unique_object)
    portable.require(build.get('source_git_status')=='' and build['source_commit']==a.expected_commit and build['source_head']==a.expected_commit,'Exact clean provided source commit')
    portable.require(build['source_tree_sha256']==report['source_tree_sha256'],'Exact full source tree digest')
    portable.require(sha(v7.GODOT.read_bytes())==build['engine_binary']['sha256'],'Pinned trusted editor identity')
    portable.require(bundle.extractfile('AUDIO_CREDITS.md').read()==(ROOT/'assets/audio/CREDITS.md').read_bytes(),'Archived exact validated credits appendix')
    report['provenance']=check_theme_pack.provenance(ROOT,bundle,sums)
    # Selected source/license attribution and v9 audition mapping must also be
    # present in the release provenance payload with the exact approved bytes.
    selected_provenance=['docs/production-v10/baseline.json','docs/production-v10/audio-selection.json','concepts/audio-v9/manifest.json']
    for path in selected_provenance:
     portable.require(sha(bundle.extractfile('provenance/'+path).read())==mapping[path],'Exact selected-audio archived provenance '+path)
    report['selected_provenance']=selected_provenance
    pack=temporary/'archive-pck-data';pack.write_bytes(bundle.extractfile(build['executable']['path']).read());pack.chmod(0o600)
   report.update({'archive':str(a.archive.resolve()),'archive_sha256':structural['archive_sha256'],'source_commit':a.expected_commit,'portable_archive_pass':True})
  native,selected=native_probe(temporary,pack,preservation,a)
  report.update({'status':'passed','native':native,'selected_native':selected,'trusted_v7_reader_sha256':sha((ROOT/'tools/check_intake_archive_v7.gd').read_bytes()),'explicit_selected_reader_sha256':sha(NATIVE_SELECTED.encode()),'frozen_theme_checker':'Known old35cue fixture incompatibility retained in v8 evidence; not rerun or relaxed.','related_main_qa':'verification/production-v10/audio/main.json','scope':'Source preflight only; no archive/release acceptance claim.' if a.source_preflight else 'Independent archive integrity, exact full source fingerprint/current/Git-object identity; exact selected3 audition bytes/registration/+4dB/provenance, exact54 other cues/3music/scripts/buses/gameplay resources/all9scenes. Trusted editor --main-pack native resources inspected, shipped ELF never executed. No subjective listening/stereo recording, route or remote history authentication claim.'})
 return report

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('archive',nargs='?',type=Path);p.add_argument('--source-preflight',action='store_true');p.add_argument('--expected-commit');p.add_argument('--report',type=Path,required=True);a=p.parse_args()
 portable.require(a.report.resolve().is_relative_to(OUT.resolve()),'Evidence output restricted to production-v10/audio')
 a.report.parent.mkdir(parents=True,exist_ok=True)
 try:result=audit(a)
 except (portable.AuditError,OSError,ValueError,KeyError,StopIteration,TypeError,subprocess.SubprocessError,tarfile.TarError) as error:result={'status':'failed','source_preflight':a.source_preflight,'error':str(error),'scope':'Required selected-audio archive check failed; no acceptance claim.'}
 result['auditor_sha256']=sha(Path(__file__).read_bytes());a.report.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2));return 0 if result['status']=='passed' else 1
if __name__=='__main__':raise SystemExit(main())
