#!/usr/bin/env python3
"""Run an actual exported ELF and retain observed /proc launch/exit evidence."""
import argparse, hashlib, json, os, subprocess, time
from pathlib import Path

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--executable',type=Path,required=True)
p.add_argument('--source-commit',required=True)
p.add_argument('--project',type=Path,help='Source-only run; adds --path, retaining /tmp launch cwd.')
p.add_argument('--report-dir',type=Path,required=True)
p.add_argument('--movie',type=Path)
p.add_argument('--heavy',action='store_true')
a=p.parse_args(); exe=a.executable.resolve(); d=a.report_dir.resolve()
if d.exists() and any(d.iterdir()): raise SystemExit('Refusing to overwrite existing evidence')
d.mkdir(parents=True,exist_ok=True)
cmd=[str(exe)]
if a.project: cmd+=['--path',str(a.project.resolve())]
if a.movie:
 a.movie=a.movie.resolve(); a.movie.parent.mkdir(parents=True,exist_ok=True)
 cmd+=['--fixed-fps','30','--disable-vsync','--write-movie',str(a.movie)]
else: cmd+=['--headless','--fixed-fps','60']
cmd+=['--log-file',str(d/'engine.log'),'--','--campaign-route-test','--campaign-level=pale_ward_01',f'--release-report-dir={d}','--automated-input']
if a.movie: cmd+=['--check-lift-route','--force-offscreen-draw']
else: cmd+=['--campaign-all-levels']
if a.heavy: cmd+=['--use-heavy-weapons']
sha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest()
started=time.time()
with (d/'console.log').open('w') as log:
 proc=subprocess.Popen(cmd,cwd='/tmp',stdout=log,stderr=subprocess.STDOUT)
 time.sleep(.15)
 observed=Path(f'/proc/{proc.pid}/cmdline').read_bytes().split(b'\0')[:-1]
 receipt={'pid':proc.pid,'command':cmd,'observed_proc_cmdline':[x.decode() for x in observed], 'cwd':'/tmp','observed_proc_cwd':os.readlink(f'/proc/{proc.pid}/cwd'),'source':'live /proc cmdline and cwd; subprocess wait exit status','source_commit':a.source_commit,'executable_sha256':sha(exe),'started_epoch':started}
 if a.project:
  receipt['source_files']={str(f.relative_to(a.project)):sha(f) for f in (a.project/'scenes/campaign/pale_ward_01.tscn',a.project/'scripts/campaign_route_playtest.gd')}
 (d/'launch.json').write_text(json.dumps(receipt,indent=2)+'\n')
 receipt['exit_code']=proc.wait(); receipt['elapsed_seconds']=time.time()-started
 (d/'launch.json').write_text(json.dumps(receipt,indent=2)+'\n')
 print(json.dumps({'report_dir':str(d),'exit_code':receipt['exit_code'],'elapsed_seconds':receipt['elapsed_seconds']}),flush=True)
 raise SystemExit(receipt['exit_code'])
