#!/usr/bin/env python3
"""Independent source or portable archive audit for the nine-level campaign.

Source preflight:
  python3 tools/check_campaign_release.py --source-preflight --report /tmp/campaign-audit.json
Archive:
  python3 tools/check_campaign_release.py BUILD.tar.gz --expected-commit FULL_HASH \
    --report verification/campaign-v3/release/archive-audit.json
The pinned external Godot editor mounts an archived executable as --main-pack;
this never executes that shipped binary and is not a native gameplay route.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import tarfile
import tempfile
import check_arsenal_ambush_release as arsenal
from verify_pale_ward_archive import AuditError, COMMIT, checksums, require, unique_object

ROOT = Path(__file__).resolve().parents[1]
PROBE = Path(__file__).with_suffix('.gd')
CHAPTERS = ('pale_ward', 'ash_citadel', 'occupied_line')
ROSTERS = {'pale_ward': {'unsealed','vessel'}, 'ash_citadel': {'ironbound','censer'}, 'occupied_line': {'reaver','surveyor'}}
GUNS = {'twin_shotgun','rivet_cannon','siege_launcher'}

def digest(data: bytes) -> str: return hashlib.sha256(data).hexdigest()

def read_json(path: Path) -> dict:
    return json.loads(path.read_text(), object_pairs_hook=unique_object)

def campaign_expected(root: Path, prior: dict, source: dict[str,str] | None) -> dict:
    files = prior['files']
    def recorded(relative: str) -> bytes:
        data = (root/relative).read_bytes()
        sha = digest(data)
        if source is not None: require(source.get(relative) == sha, 'Missing/mismatched campaign source checksum: '+relative)
        files[relative] = sha
        return data
    catalog = json.loads(recorded('resources/campaign/catalog.json'),object_pairs_hook=unique_object)
    seeds = json.loads(recorded('resources/campaign/route-seeds.json'),object_pairs_hook=unique_object)
    require([chapter['id'] for chapter in catalog['chapters']] == list(CHAPTERS),'Three ordered campaign chapters')
    levels = [level for chapter in catalog['chapters'] for level in chapter['levels']]
    require(all(len(chapter['levels']) == 3 for chapter in catalog['chapters']) and len(levels)==9,'Three levels per chapter, nine total')
    ids = [level['id'] for level in levels]
    require(len(set(ids))==9 and set(seeds['seeds'])==set(ids),'Distinct nine level IDs and seed records')
    result = {'chapters':list(CHAPTERS),'levels':{},'seed_sha256':files['resources/campaign/route-seeds.json']}
    for chapter in catalog['chapters']:
        theme = chapter['id']
        for level in chapter['levels']:
            level_id = level['id']
            require(level_id.startswith(theme+'_') and level['theme']==theme,'Level theme/chapter agrees: '+level_id)
            scene_path = level['scene'].removeprefix('res://')
            require(level['scene']=='res://scenes/campaign/'+level_id+'.tscn','Dedicated authored campaign scene: '+level_id)
            scene = recorded(scene_path).decode()
            route_path='resources/campaign/'+level_id+'-route.json'
            layout_path='resources/campaign/'+level_id+'-layout.json'
            route=json.loads(recorded(route_path),object_pairs_hook=unique_object)
            layout=json.loads(recorded(layout_path),object_pairs_hook=unique_object)
            require(route['id']==layout['id']==layout['campaign_level_id']==level_id,'Route/layout IDs: '+level_id)
            require(route['theme']==layout['theme']==theme,'Route/layout theme: '+level_id)
            require(len(route['rooms'])>=10 and len(route['portals'])>=10,'Authored route complexity: '+level_id)
            require(route['exit']['room'] in route['rooms'] and layout['spawn_room'] in route['rooms'],'Entry/exit rooms: '+level_id)
            require(len(route['vertical_routes'])>=1 and len(route['combat_paths'])>=1,'Elevation and combat route: '+level_id)
            require({cache['weapon'] for cache in route['weapon_cache'].values()} <= GUNS and bool(route['weapon_cache']),'Physical heavy weapon cache registration: '+level_id)
            require(set(route['rooms'])=={room['id'] for room in layout['rooms']},'Route/layout room identity: '+level_id)
            for portal in route['portals']:
                require(portal['from'] in route['rooms'] and portal['to'] in route['rooms'],'Route portal endpoint: '+level_id)
            neighbors={room:set() for room in route['rooms']}
            for portal in route['portals']:
                neighbors[portal['from']].add(portal['to'])
                neighbors[portal['to']].add(portal['from'])
            reached={layout['spawn_room']};frontier=[layout['spawn_room']]
            while frontier:
                for adjacent in neighbors[frontier.pop()]-reached:
                    reached.add(adjacent);frontier.append(adjacent)
            require(reached==set(route['rooms']),'All authored rooms connect to spawn through portal graph: '+level_id)
            kinds=set(re.findall(r'^metadata/kind = "([^"]+)"$',scene,re.M))
            require(bool(kinds) and kinds<=ROSTERS[theme],'Source scene theme-exclusive enemies: '+level_id)
            require(seeds['seeds'][level_id]['health']>0 and set(seeds['seeds'][level_id]['owned_weapons']) >= {'pistol','shotgun','melee'},'Finite route seed: '+level_id)
            board=layout['board'].removeprefix('res://')
            recorded(board)
            result['levels'][level_id]={'theme':theme,'scene':level['scene'],'route':'res://'+route_path,'layout':'res://'+layout_path,
                'rooms':len(route['rooms']),'portals':len(route['portals']),'enemy_kinds':sorted(kinds),'board':'res://'+board}
    for relative in ('resources/campaign/structure-check.json','resources/campaign/route-check.json',
                     'scripts/campaign_state.gd','scripts/main.gd','scripts/weapon_presentation.gd'):
        recorded(relative)
    art = read_json(root/'assets/combat_art.json')
    rivet = art['weapon_atlases']['rivet_cannon']
    require(art['weapons']['rivet_cannon']['idle']=='res://assets/weapons/campaign-v3/rivet_cannon-atlas.png','New Rivet source registered')
    require(rivet['sha256']==files['assets/weapons/campaign-v3/rivet_cannon-atlas.png'],'Rivet source bytes match registered hash')
    for gun in ('pistol','shotgun','twin_shotgun','rivet_cannon','siege_launcher'):
        for phase in ('idle','fire','recover','switch'):
            bore=art['weapon_atlases'][gun]['placement'][phase].get('bore',{})
            require(set(bore)=={'breech','muzzle'},'Two authored bore points: '+gun+'/'+phase)
    return result

def probe(args, expected: dict, temporary: Path, pack: Path | None) -> dict:
    version=subprocess.run([str(args.godot),'--version'],capture_output=True,text=True,check=True).stdout.strip()
    require(version.startswith('4.7.2.stable.official.'),'Pinned Godot 4.7.2 reader required')
    input_path=temporary/'expected.json'; output_path=temporary/'probe-report.json'
    input_path.write_text(json.dumps(expected))
    (temporary/'project.godot').write_text('[application]\nconfig/name="Independent Campaign Audit"\n')
    cmd=[str(args.godot),'--headless','--path',str(temporary if pack else args.source_root)]
    if pack: cmd+=['--main-pack',str(pack)]
    cmd+=['--script',str(PROBE),'--','--expected='+str(input_path),'--report='+str(output_path)]
    if pack:cmd.append('--packed')
    process=subprocess.run(cmd,cwd=temporary,capture_output=True,text=True,timeout=300)
    log=process.stdout+process.stderr
    require(output_path.is_file(),'Campaign Godot probe produced no report: '+log[-3500:])
    result=read_json(output_path)
    require(not re.search(r'(?:SCRIPT ERROR:|^ERROR:)',log,re.M),'Campaign Godot probe errors: '+log[-3500:])
    require(process.returncode==0 or not result.get('pass'),'Probe exit/report contradiction')
    return {'pass':result.get('pass',False),'checks':result.get('checks',0),'failures':result.get('failures',[]),
            'campaign':result.get('campaign',{}),'weapon_count':len(result.get('weapons',{})),
            'engine_version':version,'exit_code':process.returncode,'packed':bool(pack)}

def audit(args) -> dict:
    root=args.source_root.resolve()
    with tempfile.TemporaryDirectory(prefix='eyesore-campaign-audit-') as directory:
        temporary=Path(directory)
        if args.source_preflight:
            expected=arsenal.expectations(root)
            expected['campaign']=campaign_expected(root,expected,None)
            packed=probe(args,expected,temporary,None)
            return {'status':'passed' if packed['pass'] else 'failed','source_preflight':True,'probe':packed,
                    'scope':'Current source and external pinned Godot resource/controlled Main checks; no archive or native route claim.'}
        require(args.archive is not None and args.expected_commit is not None,'Archive and full --expected-commit required')
        require(COMMIT.fullmatch(args.expected_commit) is not None,'Full expected commit hash required')
        structural=arsenal.base.verify(args.archive)
        require(structural['source_commit']==args.expected_commit,'Archive source commit mismatch')
        archive_record=args.archive_record or args.archive.parent/'ARCHIVE.json'
        rec=read_json(archive_record)
        require(rec['path']==args.archive.name and rec['bytes']==args.archive.stat().st_size and rec['sha256']==structural['archive_sha256'],'External archive record mismatch')
        with tarfile.open(args.archive,'r:gz') as bundle:
            source=checksums(bundle.extractfile('SOURCE_SHA256SUMS').read().decode(),'SOURCE_SHA256SUMS')
            for relative,sha in source.items():
                local=root/relative
                require(local.is_file() and not local.is_symlink() and local.resolve().is_relative_to(root),'Unsafe/missing recorded source: '+relative)
                require(digest(local.read_bytes())==sha,'Current source differs from release: '+relative)
            provenance=arsenal.base.provenance(root,bundle,source)
            expected=arsenal.expectations(root,source)
            expected['campaign']=campaign_expected(root,expected,source)
            expected['engine_license_sha256']=digest(bundle.extractfile('GODOT_LICENSE.txt').read())
            expected['engine_notices_sha256']=digest(bundle.extractfile('GODOT_THIRD_PARTY_NOTICES.txt').read())
            build=json.loads(bundle.extractfile('BUILD.json').read(),object_pairs_hook=unique_object)
            require(digest(args.godot.read_bytes())==build['engine_binary']['sha256'],'Pinned reader/build engine mismatch')
            executable=temporary/'archived-campaign-pack.x86_64'
            executable.write_bytes(bundle.extractfile(build['executable']['path']).read());executable.chmod(0o600)
            packed=probe(args,expected,temporary,executable)
        return {'status':'passed' if packed['pass'] else 'failed','archive':str(args.archive.resolve()),'archive_sha256':structural['archive_sha256'],
                'source_commit':args.expected_commit,'recorded_source_files_verified':len(source),'portable_archive_pass':True,
                'provenance_records_verified':len(provenance) if isinstance(provenance,(list,dict)) else True,'probe':packed,
                'scope':'Portable archive/source checks and pinned external Godot --main-pack probe. The archived executable was not run; native full routes remain separate.'}

def main() -> int:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive',nargs='?',type=Path)
    parser.add_argument('--source-preflight',action='store_true')
    parser.add_argument('--expected-commit')
    parser.add_argument('--archive-record',type=Path)
    parser.add_argument('--source-root',type=Path,default=ROOT)
    parser.add_argument('--godot',type=Path,default=arsenal.base.GODOT)
    parser.add_argument('--report',type=Path,required=True)
    args=parser.parse_args()
    try: result=audit(args)
    except (AuditError,OSError,ValueError,KeyError,TypeError,IndexError,AttributeError,tarfile.TarError,subprocess.SubprocessError) as error:
        result={'status':'failed','error':str(error),'scope':'Audit did not establish release acceptance.'}
    result['auditor_sha256']=digest(Path(__file__).read_bytes())
    result['godot_probe_sha256']=digest(PROBE.read_bytes())
    args.report.parent.mkdir(parents=True,exist_ok=True)
    args.report.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'status':result['status'],'error':result.get('error'),'probe_failures':result.get('probe',{}).get('failures',[]),'report':str(args.report)}))
    return 0 if result['status']=='passed' else 1

if __name__=='__main__':sys.exit(main())
