#!/usr/bin/env python3
"""V7 adapter for the frozen native movie verifier's runtime-cwd assumption.

The ELF is launched from /tmp. Godot changes its process cwd to the exported
package before the live /proc observation. Preserve that truthful observation
and require the exact package directory; every other original launch condition
remains. No launch evidence is rewritten.
"""
import hashlib,json
from pathlib import Path
import verify_map_recording as prior

def validate_launch(path,executable,avi,native_log,route_path,source_commit,elf_sha):
 data=json.loads(path.read_text());command=data.get('command');require=prior.media.require
 require(isinstance(command,list) and all(isinstance(x,str) for x in command) and command and Path(command[0]).resolve()==executable,'Observed launch executable mismatch')
 require(prior.finite_integer(data.get('pid'),1) and '/proc' in str(data.get('source','')) and data.get('observed_proc_cmdline')==command and data.get('cwd')=='/tmp' and data.get('observed_proc_cwd')==str(executable.parent) and data.get('exit_code')==0 and data.get('source_commit')==source_commit and data.get('executable_sha256')==elf_sha,'Launch lacks actual PID/command/launch cwd/exact package runtime cwd/exit/source/ELF identity')
 require(prior.command_value(command,'--fixed-fps')=='30' and command.count('--disable-vsync')==1,'Capture must be fixed30 without VSync')
 require(Path(prior.command_value(command,'--write-movie')).resolve()==avi and Path(prior.command_value(command,'--log-file')).resolve()==native_log,'AVI/native log mismatch')
 require(command.count('--')==1,'Missing game argument separator')
 args=command[command.index('--')+1:]
 expected={'--campaign-route-test','--campaign-level='+prior.LEVEL,'--use-heavy-weapons','--check-lift-route','--automated-input','--force-offscreen-draw'}
 require(expected.issubset(args) and '--release-report-dir='+str(route_path.parent) in args and '--campaign-all-levels' not in args and not any(v.startswith('--stage=') for v in args),'Capture was not isolated finite Intake heavy lift route')
 return {**prior.media.record(path),'pid':data['pid'],'source':data['source'],'command':command,'observed_proc_cmdline':data['observed_proc_cmdline'],'cwd':data['cwd'],'observed_proc_cwd':data['observed_proc_cwd'],'exit_code':data['exit_code'],'note':'Actual /tmp launch; Godot changes native process runtime cwd to exact exported package before /proc observation. No evidence rewritten.','v7_launch_adapter':{'path':str(Path(__file__).resolve()),'sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}}

if __name__=='__main__':
 prior.validate_launch=validate_launch
 raise SystemExit(prior.main())
