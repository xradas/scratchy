#!/usr/bin/env python3
"""Launch the actual v13 exported ELF from /tmp with observed process receipts.
Godot may switch its working directory to the exported package; record the real
/proc cwd rather than claiming the requested launch cwd is retained.
"""
import argparse,hashlib,json,os,pathlib,subprocess,time
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--executable',type=pathlib.Path,required=True);p.add_argument('--source-commit',required=True);p.add_argument('--report-dir',type=pathlib.Path,required=True);p.add_argument('--movie',type=pathlib.Path);p.add_argument('--heavy',action='store_true');p.add_argument('--level',default='pale_ward_01');p.add_argument('--levels',type=int,default=9);p.add_argument('--order',choices=['AB','BA'],default='AB')
project=pathlib.Path(__file__).resolve().parents[1]
a=p.parse_args();exe=a.executable.resolve();out=a.report_dir.resolve();assert exe.is_file() and len(a.source_commit)==40 and 1<=a.levels<=9
for candidate in [out]+([a.movie.resolve()] if a.movie else []):
 if candidate.is_relative_to(project) or candidate.is_relative_to(exe.parent):raise SystemExit('Evidence/media must be outside the source project and exported package')
if a.movie and a.movie.resolve().is_relative_to(out):raise SystemExit('Movie must be outside the launch-evidence directory')
if out.exists() and any(out.iterdir()):raise SystemExit('Refusing to overwrite existing launch evidence')
out.mkdir(parents=True,exist_ok=True);cmd=[str(exe)]
if a.movie:
 movie=a.movie.resolve();movie.parent.mkdir(parents=True,exist_ok=True)
 if movie.exists():raise SystemExit('Refusing to overwrite original movie')
 cmd+=['--position','20000,20000','--fixed-fps','30','--disable-vsync','--write-movie',str(movie)]
else:cmd+=['--headless','--fixed-fps','60']
cmd+=['--log-file',str(out/'engine.log'),'--','--v13-route-test','--campaign-level='+a.level,'--v13-level-count='+str(a.levels),'--containment-order='+a.order,'--release-report-dir='+str(out),'--automated-input']
if a.movie:cmd+=['--force-offscreen-draw']
if a.heavy:cmd+=['--use-heavy-weapons']
sha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest();before_sha=sha(exe);started=time.time()
with (out/'console.log').open('w') as log:
 proc=subprocess.Popen(cmd,cwd='/tmp',stdout=log,stderr=subprocess.STDOUT)
 time.sleep(.15)
 try:
  observed=pathlib.Path(f'/proc/{proc.pid}/cmdline').read_bytes().split(b'\0')[:-1]
  receipt={'pid':proc.pid,'command':cmd,'observed_proc_cmdline':[v.decode() for v in observed],'cwd':'/tmp','observed_proc_cwd':os.readlink(f'/proc/{proc.pid}/cwd'),'observed_proc_exe':os.readlink(f'/proc/{proc.pid}/exe'),'observed_proc_exe_sha256':sha(pathlib.Path(f'/proc/{proc.pid}/exe')),'source':'live /proc cmdline/cwd and subprocess wait exit','source_commit':a.source_commit,'executable_sha256':before_sha,'started_epoch':started,'XDG':{k:os.environ.get(k,'') for k in ['XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME']}}
 except FileNotFoundError:
  receipt={'command':cmd,'source_commit':a.source_commit,'error':'Process exited before /proc receipt','executable_sha256':before_sha}
 (out/'launch.json').write_text(json.dumps(receipt,indent=2)+'\n')
 receipt['exit_code']=proc.wait();receipt['executable_unchanged_after']=sha(exe)==before_sha
 if receipt.get('observed_proc_exe')!=str(exe) or receipt.get('observed_proc_exe_sha256')!=before_sha or not receipt['executable_unchanged_after']:receipt['error']='Observed process executable/source bytes mismatch'
 receipt['elapsed_seconds']=time.time()-started;(out/'launch.json').write_text(json.dumps(receipt,indent=2)+'\n')
 print(json.dumps({'report_dir':str(out),'exit_code':receipt['exit_code'],'elapsed_seconds':receipt['elapsed_seconds']}))
 raise SystemExit(receipt['exit_code'] or (1 if 'error' in receipt else 0))
