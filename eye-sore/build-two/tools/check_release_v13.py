#!/usr/bin/env python3
"""Check the exact v13 portable archive against its committed source and baseline.

Scope: the v13 package without optional --video media; movie delivery is verified separately.
Read-only except the requested JSON receipt. Does not execute the archived ELF;
actual-game route/capture receipts are separate evidence.
"""
from __future__ import annotations
import argparse, hashlib, io, json, pathlib, subprocess, tarfile
import package_pale_ward as package
P=pathlib.Path(__file__).resolve().parents[1]
def sha(data):return hashlib.sha256(data).hexdigest()
def require(value,message):
 if not value:raise RuntimeError(message)
def main():
 a=argparse.ArgumentParser();a.add_argument('archive',type=pathlib.Path);a.add_argument('--expected-commit',required=True);a.add_argument('--report',type=pathlib.Path,required=True);args=a.parse_args()
 result={'status':'failed','scope':'Archive and exact committed-source identity only; native/editor and actual exported execution are separate receipts.'}
 try:
  with tarfile.open(args.archive,'r:gz') as tar:
   entries=tar.getmembers();members={m.name:m for m in entries};require(len(members)==len(entries),'Duplicate archive member');prefix='';require('BUILD.json' in members and 'SOURCE_SHA256SUMS' in members,'Expected flat portable archive');repo=pathlib.Path(subprocess.check_output(['git','rev-parse','--show-toplevel'],cwd=P,text=True).strip());project_prefix=P.relative_to(repo).as_posix()+'/'
   for n,m in members.items():require(not n.startswith('/') and '..' not in pathlib.PurePosixPath(n).parts and m.isfile(),'Unsafe archive member: '+n)
   def read(n):
    f=tar.extractfile(prefix+n);require(f is not None,'Missing archive file '+n);return f.read()
   build=json.loads(read('BUILD.json'));require(build['source_commit']==args.expected_commit and build['source_head']==args.expected_commit and build['source_git_status']=='','Build lacks exact clean source checkpoint')
   fingerprints={}
   for line in read('SOURCE_SHA256SUMS').decode().splitlines():
    h,n=line.split('  ',1);require(n not in fingerprints,'Duplicate source entry');fingerprints[n]=h
   expected=package.source_snapshot([P/'assets/audio/CREDITS.md',P/'assets/VISUAL_CREDITS.md',*package.provenance_files()]);require(set(fingerprints)==set(expected),'Source fingerprint coverage differs from actual source/provenance collector');tree=sha(json.dumps(fingerprints,sort_keys=True).encode());require(tree==build['source_tree_sha256'],'Source tree digest mismatch')
   for n,h in fingerprints.items():
    require(sha((P/n).read_bytes())==h,'Current source differs: '+n)
    data=subprocess.check_output(['git','show',args.expected_commit+':'+project_prefix+n],cwd=P)
    require(sha(data)==h,'Git source differs: '+n)
    if n.startswith(('docs/','concepts/')):require(sha(read('provenance/'+n))==h,'Archived provenance differs: '+n)
   elf=build['executable'];require(sha(read(elf['path']))==elf['sha256'],'ELF hash mismatch');require(members[prefix+elf['path']].mode & 0o111,'ELF is not executable')
   required={'BUILD.json','README.txt','SOURCE_SHA256SUMS','export.log','smoke.log','licenses.log','GODOT_LICENSE.txt','GODOT_THIRD_PARTY_NOTICES.txt','AUDIO_CREDITS.md','VISUAL_CREDITS.md','export-gore.png','export-gameplay.png','export-menu.png','export-diagnostic.json',elf['path'],'SHA256SUMS'}|{'provenance/'+p.relative_to(P).as_posix() for p in package.provenance_files()}
   require(set(members)==required,'Archive payload coverage differs from required v13 package')
   sums=read('SHA256SUMS').decode().splitlines();names=[line.split('  ',1)[1] for line in sums];require(len(names)==len(set(names)) and set(names)==set(members)-{'SHA256SUMS'},'Package checksum coverage differs from exact archive members')
   for line in sums:
    h,n=line.split('  ',1);require(sha(read(n))==h,'Package file differs: '+n)
   require(build['engine'].startswith('4.7.2.'),'Wrong engine');require(build['renderer']=='Compatibility','Wrong renderer')
   result.update(status='passed',source_commit=args.expected_commit,archive=str(args.archive.resolve()),archive_sha256=sha(args.archive.read_bytes()),executable_sha256=elf['sha256'],source_fingerprints_verified=len(fingerprints),package_files_verified=len(sums),source_tree_sha256=tree,source_git_status=build['source_git_status'],engine=build['engine'])
 except Exception as e:result['error']=str(e)
 args.report.parent.mkdir(parents=True,exist_ok=True);args.report.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2));return 0 if result['status']=='passed' else 1
if __name__=='__main__':raise SystemExit(main())
