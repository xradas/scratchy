#!/usr/bin/env python3
"""Strict v12 gore archive/source audit and actual Main PCK fixture; never executes ELF."""
from __future__ import annotations
import argparse,json,re,subprocess,sys,tarfile,tempfile
from pathlib import Path
import check_gore_v12 as staff
import check_production_archive_v9 as source_audit
import check_theme_pack
import verify_pale_ward_archive as portable
ROOT=staff.ROOT
OUT=ROOT/'verification/production-v12/archive'
ALLOWED=()
sha=staff.sha
def read(path):return json.loads(path.read_text(),object_pairs_hook=portable.unique_object)
def fixture(a,pack=None):
 target=staff.OUT/('archive-packed-main.json' if pack else 'archive-source-protected.json')
 command=[sys.executable,str(ROOT/'tools/check_gore_v12.py'),'--report',str(target)]
 for path in ALLOWED:command+=['--allow-protected-change',path]
 if pack:
  command+=['--main-pack',str(pack)]
  if a.native:command+=['--native']
 else:command+=['--source-only']
 process=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=150)
 portable.require(target.is_file(),'No protected-source/actual Main fixture report: '+process.stderr[-2000:])
 result=read(target)
 portable.require(process.returncode==0 and result['status']=='passed','Protected source/actual Main fixture failed: '+json.dumps(result)[-2500:])
 return result
def audit(a):
 protected=fixture(a)
 mapping,policy=source_audit.snapshot_policy()
 git_count=source_audit.git_fingerprints(a.expected_commit,mapping) if a.expected_commit else None
 marker='assets/audio/selected-v10/source-wav/.gdignore'
 portable.require((ROOT/marker).read_bytes()==b'','Exact ignored archival WAV marker')
 marker_git=source_audit.git_fingerprints(a.expected_commit,{marker:sha(b'')}) if a.expected_commit else None
 report={'status':'passed','source_preflight':a.source_preflight,'source_fingerprints_verified':len(mapping),'source_tree_sha256':sha(json.dumps(mapping,sort_keys=True).encode()),'source_snapshot_policy':policy,'git_checkpoint_blobs_verified':git_count,'archival_wav_ignore_git_blob_verified':marker_git,'protected_source':protected,'frozen_prior_gore_readers':'Not run or changed: previous flat-remains/normal-death fragments assumptions are obsolete. New actual-shot fixture requires intact normal corpses and closed-volume rupture parts.','geometry_proof':'All nine scene bytes protected against frozen v11b Git baseline. New native gore fixture independently inspects cosmetic closed volume/support/noncollision; no route or aggregate navigation proof claim.'}
 if a.source_preflight:
  report['scope']='Protected source/provenance dynamic snapshot preflight; no export or packed-runtime acceptance claim.'
  return report
 portable.require(a.archive is not None and a.expected_commit is not None,'Archive and full --expected-commit required')
 structural=portable.verify(a.archive)
 portable.require(structural['source_commit']==a.expected_commit,'Exact provided packaged source commit')
 record=read(a.archive.parent/'ARCHIVE.json')
 portable.require(record['sha256']==structural['archive_sha256'] and record['bytes']==a.archive.stat().st_size and record['path']==a.archive.name,'External archive record identity')
 with tempfile.TemporaryDirectory(prefix='eyesore-gore-v12-archive-') as directory:
  with tarfile.open(a.archive,'r:gz') as bundle:
   sums=portable.checksums(bundle.extractfile('SOURCE_SHA256SUMS').read().decode(),'SOURCE_SHA256SUMS')
   portable.require(sums==mapping,'Exact full packaged/current source/provenance fingerprint roster')
   build=json.loads(bundle.extractfile('BUILD.json').read(),object_pairs_hook=portable.unique_object)
   portable.require(build.get('source_git_status')=='' and build['source_commit']==a.expected_commit and build['source_head']==a.expected_commit,'Exact clean BUILD commit identity')
   portable.require(build['source_tree_sha256']==report['source_tree_sha256'],'Exact full source tree digest')
   portable.require(sha(staff.GODOT.read_bytes())==build['engine_binary']['sha256'],'Pinned trusted editor identity')
   for archive_path,source_path in [('AUDIO_CREDITS.md','assets/audio/CREDITS.md'),('VISUAL_CREDITS.md','assets/VISUAL_CREDITS.md')]:
    portable.require(bundle.extractfile(archive_path).read()==(ROOT/source_path).read_bytes(),'Exact archived current credits '+archive_path)
   report['provenance']=check_theme_pack.provenance(ROOT,bundle,sums)
   for path in ('docs/production-v12/qa-baseline.json',):
    portable.require(sha(bundle.extractfile('provenance/'+path).read())==mapping[path],'Exact explicit archived v12 QA baseline '+path)
   exe=build['executable'];data=bundle.extractfile(exe['path']).read()
   portable.require(sha(data)==exe['sha256'] and len(data)==exe['bytes'],'Actual archived ELF bytes')
   portable.require((a.archive.parent/exe['path']).read_bytes()==data,'Archived ELF matches loose exported executable bytes')
   pack=Path(directory)/'pack-data';pack.write_bytes(data);pack.chmod(0o600)
  report['packed_main']=fixture(a,pack)
  # Snapshot again after native checks to detect concurrent protected source edits.
  portable.require(source_audit.snapshot_policy()[0]==mapping,'Source snapshot changed during archive audit')
  report.update(archive=str(a.archive.resolve()),archive_sha256=structural['archive_sha256'],executable_sha256=exe['sha256'],source_commit=a.expected_commit,portable_archive_pass=True)
 report['scope']='Independent archive integrity, dynamic packaged/current/Git source+provenance identity, exact credits and ELF bytes. Trusted editor --main-pack actual Main validates63 unchanged cues, actual living/corpse contacts/rupture ownership, closed-volume remains, bounded real-shot heavy bursts, pause/mute/Retry. Shipped ELF never executed; no human listening, route, visual approval or aggregate geometry proof claim.'
 return report
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('archive',nargs='?',type=Path);p.add_argument('--source-preflight',action='store_true');p.add_argument('--expected-commit');p.add_argument('--native',action='store_true');p.add_argument('--report',type=Path,required=True);a=p.parse_args()
 portable.require(a.report.resolve().is_relative_to(OUT.resolve()),'Archive evidence restricted to production-v12/archive');a.report.parent.mkdir(parents=True,exist_ok=True)
 try:result=audit(a)
 except (portable.AuditError,AssertionError,OSError,ValueError,KeyError,TypeError,subprocess.SubprocessError,tarfile.TarError) as error:result={'status':'failed','source_preflight':a.source_preflight,'error':str(error),'scope':'Required archive/source check failed; no acceptance claim.'}
 result['auditor_sha256']=sha(Path(__file__).read_bytes());a.report.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2));return 0 if result['status']=='passed' else 1
if __name__=='__main__':raise SystemExit(main())
