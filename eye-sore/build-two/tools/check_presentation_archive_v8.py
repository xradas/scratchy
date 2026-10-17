#!/usr/bin/env python3
"""Bounded v8 archive audit, preserving v7 native reader and strict baseline checks.

The archived ELF is read as an embedded PCK by external pinned Godot, never executed.
Only declared Twin/flash metadata and appended visual credit prose may differ among
baseline assets. New v8 texture assets are covered by all579 source fingerprints.
"""
import argparse,copy,hashlib,json,re,subprocess,tarfile,tempfile
from pathlib import Path
import check_intake_archive_v7 as v7
import check_theme_pack
import verify_pale_ward_archive as portable
ROOT=Path(__file__).resolve().parents[1]
EVIDENCE=ROOT/'verification/production-v8/archive'
COMMIT='1d576648e2ef0083d0be0be1df2450afed2a5a69'
def digest(data): return hashlib.sha256(data).hexdigest()
def read(path): return json.loads(path.read_text(),object_pairs_hook=portable.unique_object)
def audit(a):
 portable.require(a.expected_commit==COMMIT,'This bounded checker is sealed to v8 source checkpoint')
 original=read(EVIDENCE/'frozen-theme-pack-failure.json')
 portable.require(original['status']=='failed' and original['error']=='Source runtime ledger must contain 35 cues','Preserve original frozen35-cue fixture incompatibility')
 structural=portable.verify(a.archive)
 portable.require(structural['source_commit']==a.expected_commit,'Archive commit mismatch')
 archive_record=read(a.archive.parent/'ARCHIVE.json')
 portable.require(archive_record['sha256']==structural['archive_sha256'] and archive_record['bytes']==a.archive.stat().st_size and archive_record['path']==a.archive.name,'External archive metadata mismatch')
 baseline=read(ROOT/'docs/intake-v7/baseline.json')['source_fingerprints']
 baseline_art=(EVIDENCE/'baseline-combat-art-v7.json').read_bytes()
 baseline_credits=(EVIDENCE/'baseline-visual-credits-v7.md').read_bytes()
 portable.require(digest(baseline_art)==baseline['assets/combat_art.json'],'Sealed original combat manifest')
 portable.require(digest(baseline_credits)==baseline['assets/VISUAL_CREDITS.md'],'Sealed original visual credits')
 art=json.loads(baseline_art,object_pairs_hook=portable.unique_object)
 contract=read(ROOT/'docs/production-v8/twin-presentation.json')
 portable.require(contract['baseline_manifest_sha256']==digest(baseline_art) and art['weapon_atlases']['twin_shotgun']==contract['baseline_twin'],'Declared Twin baseline exact identity')
 expected_art=copy.deepcopy(art)
 expected_art['weapon_atlases']['twin_shotgun']=contract['patch']['weapon_atlases']['twin_shotgun']
 expected_art['flash']['anchors']['twin_shotgun']=contract['patch']['flash']['anchors']['twin_shotgun']
 portable.require(read(ROOT/'assets/combat_art.json')==expected_art,'Only exact declared Twin/flash JSON differences permitted')
 credits=(ROOT/'assets/VISUAL_CREDITS.md').read_bytes()
 portable.require(credits.startswith(baseline_credits) and len(credits)>len(baseline_credits),'Visual credits preserve all baseline prose and append attribution')
 preserved=[p for p in baseline if p.startswith(('assets/','resources/weapons/')) or p in ('resources/combat_audio.tres','resources/campaign/balance-budget.json') or (p.startswith('scenes/campaign/') and not p.endswith('pale_ward_01.tscn'))]
 exceptions={'assets/combat_art.json','assets/VISUAL_CREDITS.md'}
 with tempfile.TemporaryDirectory(prefix='eyesore-v8-archive-reader-') as td:
  tmp=Path(td)
  with tarfile.open(a.archive,'r:gz') as bundle:
   sums=portable.checksums(bundle.extractfile('SOURCE_SHA256SUMS').read().decode(),'SOURCE_SHA256SUMS')
   portable.require(len(sums)==579,'Exact v8 source fingerprint roster579')
   for path,sha in sums.items():
    local=ROOT/path
    portable.require(local.is_file() and not local.is_symlink() and local.resolve().is_relative_to(ROOT) and digest(local.read_bytes())==sha,'Source fingerprint mismatch '+path)
   provenance=check_theme_pack.provenance(ROOT,bundle,sums)
   for path in preserved:
    if path not in exceptions: portable.require(sums.get(path)==baseline[path],'Preserved baseline asset/map '+path)
   portable.require(sum(p.startswith('scenes/campaign/') for p in preserved)==8,'Eight other campaign maps exactly preserved')
   build=json.loads(bundle.extractfile('BUILD.json').read(),object_pairs_hook=portable.unique_object)
   portable.require(build.get('source_git_status')=='' and build['source_commit']==COMMIT,'Unclean/wrong source checkpoint')
   portable.require(digest(v7.GODOT.read_bytes())==build['engine_binary']['sha256'],'Pinned trusted reader engine mismatch')
   portable.require(bundle.extractfile('VISUAL_CREDITS.md').read()==credits,'Packaged visual credits match validated attribution')
   pack=tmp/'archive-pck-data';pack.write_bytes(bundle.extractfile(build['executable']['path']).read());pack.chmod(0o600)
  inp=tmp/'expected.json';out=tmp/'native.json'
  inp.write_text(json.dumps(v7.expected()))
  (tmp/'project.godot').write_text('[application]\nconfig/name="Independent Presentation v8 Audit"\n')
  command=[str(v7.GODOT),'--headless','--path',str(tmp),'--main-pack',str(pack),'--script',str(ROOT/'tools/check_intake_archive_v7.gd'),'--','--expected='+str(inp),'--report='+str(out)]
  proc=subprocess.run(command,cwd=tmp,capture_output=True,text=True,timeout=180)
  log=proc.stdout+proc.stderr;a.report.with_suffix('.log').write_text(log)
  portable.require(out.is_file(),'No external native report: '+log[-2000:])
  native=read(out)
  portable.require(proc.returncode==0 and native['status']=='passed' and not re.search(r'(?:SCRIPT ERROR:|^ERROR:)',log,re.M),'External trusted native reader failed: '+log[-2000:])
  # A second tiny trusted script proves the actual embedded raw JSON identity.
  meta=tmp/'metadata.gd'
  meta.write_text('extends SceneTree\nfunc _initialize():\n var ok := FileAccess.get_sha256("res://assets/combat_art.json") == "'+sums['assets/combat_art.json']+'"\n print("V8_PACKED_ART_JSON_IDENTITY ", ok)\n quit(0 if ok else 1)\n')
  cmd=[str(v7.GODOT),'--headless','--path',str(tmp),'--main-pack',str(pack),'--script',str(meta)]
  metadata=subprocess.run(cmd,cwd=tmp,capture_output=True,text=True,timeout=30)
  meta_log=metadata.stdout+metadata.stderr;a.report.with_suffix('.metadata.log').write_text(meta_log)
  portable.require(metadata.returncode==0 and 'V8_PACKED_ART_JSON_IDENTITY true' in meta_log,'Embedded combat JSON identity failed: '+meta_log[-1000:])
 return {'status':'passed','archive':str(a.archive.resolve()),'archive_sha256':structural['archive_sha256'],'source_commit':COMMIT,'source_fingerprints_verified':len(sums),'preserved_baseline_files':len(preserved)-len(exceptions),'preserved_other_campaign_maps':8,'explicit_asset_exceptions':sorted(exceptions),'exception_validation':'Full manifest structural equality after applying only exact documented Twin+flash anchors; credits append-only preserving original text. Embedded manifest SHA256 independently read.','provenance':provenance,'native':native,'frozen_checker_incompatibility':original,'native_reader_sha256':digest((ROOT/'tools/check_intake_archive_v7.gd').read_bytes()),'scope':'Independent archive integrity/source579 identity, preserved baseline assets/eight maps, recorded provenance and trusted external Godot --main-pack native object/audio resources. Archived ELF never executed. Native reader checks508 typed furnishings, matching visual/collision dimensions, all authored pickup metadata and57decoded cues. This does not authenticate Git history, prove all scene collider topology unchanged, run a player route, or provide human visual/listening acceptance. Fresh v8 art authoring provenance remains coordinator evidence; unchanged v7 provenance routine verifies its existing ledger without relaxing cue counts.'}
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('archive',type=Path);p.add_argument('--expected-commit',required=True);p.add_argument('--report',type=Path,required=True);a=p.parse_args()
 portable.require(a.report.resolve().is_relative_to(EVIDENCE.resolve()),'Evidence output restricted to verification/production-v8/archive')
 a.report.parent.mkdir(parents=True,exist_ok=True)
 try: result=audit(a)
 except (portable.AuditError,OSError,ValueError,KeyError,TypeError,subprocess.SubprocessError,tarfile.TarError) as error: result={'status':'failed','error':str(error),'scope':'Required v8 archive check failed; no acceptance claim.'}
 result['auditor_sha256']=digest(Path(__file__).read_bytes());a.report.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2));return 0 if result['status']=='passed' else 1
if __name__=='__main__':raise SystemExit(main())
