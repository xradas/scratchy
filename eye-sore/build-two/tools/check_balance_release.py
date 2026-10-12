#!/usr/bin/env python3
"""Independent campaign balance audit; preserves and extends the campaign reader.

--source-preflight audits current source. ARCHIVE --expected-commit FULL_HASH mounts
its embedded PCK with pinned external Godot; it never runs that shipped binary.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import re
import subprocess
import sys
import tarfile
import check_campaign_release as campaign
from verify_pale_ward_archive import AuditError, require

ROOT=Path(__file__).resolve().parents[1]
PROBE=Path(__file__).with_suffix('.gd')
CAPS={'pistol':96,'shells':40,'rivets':160,'rockets':12}
PRESERVED=Path(__file__).with_name('balance_v4_preserved.json')
PRESERVED_SHA256='e150da64a9f0a711475d8a5b72764cd79b38a825a9ea8281079a068d11364878'
original_campaign_expected=campaign.campaign_expected


def balance_expected(root,prior,source):
    result=original_campaign_expected(root,prior,source)
    require(campaign.digest(PRESERVED.read_bytes())==PRESERVED_SHA256,'Trusted prior-release preservation baseline hash')
    preserved=campaign.read_json(PRESERVED)
    for path,sha in preserved['files'].items():
        require(campaign.digest((root/path).read_bytes())==sha,'Preserved art/weapon/clip bytes changed: '+path)
        if source is not None:require(source.get(path)==sha,'Preserved resource absent/different in archive source ledger: '+path)
    def recorded(path):
        data=(root/path).read_bytes();sha=campaign.digest(data)
        if source is not None:require(source.get(path)==sha,'Balance source checksum absent/different: '+path)
        prior['files'][path]=sha
        return data
    budget=json.loads(recorded('resources/campaign/balance-budget.json'))
    require(budget['ammo_caps']==CAPS,'Normative campaign carrying caps differ')
    records={level['id']:level for level in budget['levels']}
    require(len(records)==9 and set(records)==set(result['levels']),'Nine unique budget levels match campaign catalog')
    for key,entry in records.items():
        require(entry['main_route_actual']==entry['main_route_target'],'Budget declared target/actual mismatch: '+key)
        require(set(entry['main_route_actual'])==set(CAPS),'Four explicit ammo families in budget: '+key)
        require(all(type(v) is int and v>=0 for v in entry['main_route_actual'].values()),'Finite nonnegative main supplies: '+key)
        require(len(entry['sources']['arena_baits'])==3,'Three budgeted bait grants: '+key)
    for path in ['resources/campaign/supply_policy.tres','scripts/supply_policy.gd','scripts/combat.gd','scripts/stage_level.gd','scripts/campaign_state.gd']:
        recorded(path)
    prior['balance']={'caps':CAPS,'budget_path':'res://resources/campaign/balance-budget.json','policy_path':'res://resources/campaign/supply_policy.tres',
        'levels':records,'vital_pickups':preserved['vital_pickups'],'preserved_source_commit':preserved['source_commit'],'preserved_file_count':len(preserved['files'])}
    return result


def probe(args,expected,temporary,pack):
    version=subprocess.run([str(args.godot),'--version'],capture_output=True,text=True,check=True).stdout.strip()
    require(version.startswith('4.7.2.stable.official.'),'Pinned Godot4.7.2 reader required')
    input_path=temporary/'expected.json';output=temporary/'probe-report.json'
    input_path.write_text(json.dumps(expected))
    (temporary/'project.godot').write_text('[application]\nconfig/name="Independent Balance Audit"\n')
    command=[str(args.godot),'--headless','--path',str(temporary if pack else args.source_root)]
    if pack:command+=['--main-pack',str(pack)]
    command+=['--script',str(PROBE),'--','--expected='+str(input_path),'--report='+str(output)]
    if pack:command.append('--packed')
    process=subprocess.run(command,cwd=temporary,capture_output=True,text=True,timeout=360)
    log=process.stdout+process.stderr
    require(output.is_file(),'Balance probe produced no report: '+log[-5000:])
    result=campaign.read_json(output)
    require(not re.search(r'(?:SCRIPT ERROR:|^ERROR:)',log,re.M),'Balance probe engine/script errors: '+log[-5000:])
    require(process.returncode==0 or not result.get('pass'),'Probe exit/report contradiction')
    return {'pass':result.get('pass',False),'checks':result.get('checks',0),'failures':result.get('failures',[]),
        'balance':result.get('balance',{}),'campaign':result.get('campaign',{}),'weapon_count':len(result.get('weapons',{})),
        'engine_version':version,'exit_code':process.returncode,'packed':bool(pack),'probe_log_tail':log[-1500:]}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive',nargs='?',type=Path);parser.add_argument('--source-preflight',action='store_true')
    parser.add_argument('--expected-commit');parser.add_argument('--archive-record',type=Path)
    parser.add_argument('--source-root',type=Path,default=ROOT);parser.add_argument('--godot',type=Path,default=campaign.arsenal.base.GODOT)
    parser.add_argument('--report',type=Path,required=True);args=parser.parse_args()
    if args.archive and args.archive.resolve()==args.report.resolve():parser.error('Report cannot overwrite archive')
    # Only Python process-local extension points are replaced. Both preserved
    # campaign auditor files remain byte-identical and are still executed/read.
    campaign.campaign_expected=balance_expected;campaign.probe=probe
    try:result=campaign.audit(args)
    except (AuditError,OSError,ValueError,KeyError,TypeError,IndexError,AttributeError,tarfile.TarError,subprocess.SubprocessError) as error:
        result={'status':'failed','error':str(error),'scope':'Required independent balance audit failed; no release acceptance claim.'}
    result['balance_auditor_sha256']=campaign.digest(Path(__file__).read_bytes());result['balance_probe_sha256']=campaign.digest(PROBE.read_bytes())
    result['preserved_campaign_auditor_sha256']=campaign.digest(Path(campaign.__file__).read_bytes())
    result['preserved_campaign_probe_sha256']=campaign.digest(Path(campaign.__file__).with_suffix('.gd').read_bytes())
    result['preservation_baseline_sha256']=PRESERVED_SHA256
    args.report.parent.mkdir(parents=True,exist_ok=True);args.report.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'status':result['status'],'error':result.get('error'),'checks':result.get('probe',{}).get('checks'),'failures':result.get('probe',{}).get('failures',[]),'report':str(args.report)}))
    return 0 if result['status']=='passed' else 1

if __name__=='__main__':sys.exit(main())
