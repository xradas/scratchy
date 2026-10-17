#!/usr/bin/env python3
"""Prepared release verification job. Run only after coordinator authorization."""
import argparse,hashlib,json,subprocess,time
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--mode',choices=['source','export'],required=True);p.add_argument('--source-commit',required=True);p.add_argument('--executable',type=Path,required=True);a=p.parse_args()
root=Path('/home/rikki/Projects/eyesore-build-two/eye-sore/build-two')
base=Path('/tmp/eyesore-v9-'+a.mode+'-campaign');audit=Path(str(base)+'-audit')
assert not base.exists() and not audit.exists(),'Refuse to overwrite release evidence'
base.mkdir()
receipt={'mode':a.mode,'source_commit':a.source_commit,'executable':str(a.executable.resolve()),'executable_sha256':hashlib.sha256(a.executable.read_bytes()).hexdigest(),'raw_root':str(base),'started_epoch':time.time(),'runs':[]}
for name in ('normal','heavy'):
 command=['python',str(root/'tools/run_intake_release_v7.py'),'--executable',str(a.executable.resolve()),'--source-commit',a.source_commit,'--report-dir',str(base/name)]
 if a.mode=='source':command+=['--project',str(root)]
 if name=='heavy':command+=['--heavy']
 start=time.time()
 with (base/(name+'-runner.log')).open('w') as log:result=subprocess.run(command,cwd=root,stdout=log,stderr=subprocess.STDOUT,timeout=600)
 receipt['runs'].append({'profile':name,'command':command,'exit_code':result.returncode,'wall_seconds':time.time()-start})
 (base/'job.json').write_text(json.dumps(receipt,indent=2)+'\n')
 assert result.returncode==0,(name,base/(name+'-runner.log'))
command=['python',str(root/'tools/check_intake_campaign_v7.py'),'--input',str(base),'--output',str(audit),'--source-commit',a.source_commit]
if a.mode=='export':command+=['--export']
with (base/'auditor.log').open('w') as log:result=subprocess.run(command,cwd=root,stdout=log,stderr=subprocess.STDOUT,timeout=120)
receipt['audit_command']=command;receipt['audit_exit_code']=result.returncode;receipt['finished_epoch']=time.time();(base/'job.json').write_text(json.dumps(receipt,indent=2)+'\n')
assert result.returncode==0,base/'auditor.log'
print(json.dumps({'passed':True,'mode':a.mode,'raw':str(base),'audit':str(audit/'campaign-audit.json')},indent=2))
