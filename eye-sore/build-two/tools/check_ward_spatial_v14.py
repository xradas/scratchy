#!/usr/bin/env python3
"""Independent v14 frozen-source, authored-policy and actual Main audit."""
from __future__ import annotations
import argparse, hashlib, json, os, re, subprocess, tempfile
from pathlib import Path
import check_levels_v13 as previous

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'verification/ward-spatial-v14'
BASE = '94c4f265371e5c21c9d4411e5897577799705bd7'
FOLDERS = ('assets/', 'resources/', 'scripts/', 'scenes/', 'shaders/')
sha = lambda data: hashlib.sha256(data).hexdigest()

def require(ok, message):
    if not ok:
        raise RuntimeError(message)

def git_files():
    repo = Path(subprocess.check_output(['git', 'rev-parse', '--show-toplevel'], cwd=ROOT, text=True).strip())
    prefix = ROOT.relative_to(repo).as_posix() + '/'
    names = subprocess.check_output(['git', 'ls-tree', '-rz', '--name-only', BASE, '--', prefix], cwd=repo)
    selected = {p.decode()[len(prefix):]: p.decode() for p in names.split(b'\0') if p and (p.decode()[len(prefix):].startswith(FOLDERS) or p.decode()[len(prefix):] in ('project.godot', 'export_presets.cfg'))}
    data = subprocess.check_output(['git', 'cat-file', '--batch'], cwd=repo, input=''.join(BASE+':'+p+'\n' for p in selected.values()).encode())
    cursor = 0
    result = {}
    for path in selected:
        end = data.index(b'\n', cursor); header = data[cursor:end].split(); cursor = end+1
        require(len(header) == 3 and header[1] == b'blob', 'Missing frozen Git blob '+path)
        size = int(header[2]); result[path] = data[cursor:cursor+size]; cursor += size+1
    require(cursor == len(data), 'Unexpected Git object batch tail')
    return result

def source_policy():
    frozen = git_files()
    allowed = {'scripts/stage_level.gd','scripts/ward_automap.gd','scripts/industrial_hud_v8.gd','scripts/stage_checkpoint_v13.gd'}
    for i in range(1, 4):
        id = f'pale_ward_0{i}'
        allowed |= {f'scenes/campaign/{id}.tscn', f'resources/campaign/{id}-layout.json', f'resources/campaign/{id}-route.json', f'resources/campaign/v13/{id}-objectives.tres', f'resources/campaign/v13/{id}-author-report.json'}
    for path, body in frozen.items():
        if path not in allowed:
            require((ROOT/path).is_file() and (ROOT/path).read_bytes() == body, 'Frozen v13 runtime changed '+path)
    # Only map geometry/drawing functions may differ in the two UI files.
    # Preserve all other declarations, styles, fields and function bytes.
    ui_scope={'scripts/industrial_hud_v8.gd':{'visible_map_rooms','minimap_geometry','minimap_polygons','_minimap'},'scripts/ward_automap.gd':{'_draw'},'scripts/stage_level.gd':{'update_player','is_pickup_arena','is_pickup_release_door','pickup_encounters_for_id','activate_pickup_encounters','nearest_mechanism','collect','room_at','get_level_state','try_use'},'scripts/stage_checkpoint_v13.gd':{'restore'}}
    def without_functions(text, names):
        lines=text.splitlines(keepends=True); result=[]; skip=False
        for line in lines:
            match=re.match(r'^(?:static )?func (\w+)\(',line)
            if match:
                name=match[1];skip=name in names
                if skip:continue
            elif skip and line.strip() and not line.startswith(('\t',' ', '#')):
                skip=False
            if not skip:result.append(line)
        # Function additions consume their own separating blank lines. Exact
        # substantive text remains sealed; no whitespace exemption within code.
        return ''.join(result).rstrip()+'\n'
    for path,names in ui_scope.items():
        require(without_functions((ROOT/path).read_text(),names)==without_functions(frozen[path].decode(),names),'Source changed outside explicitly approved functions '+path)
    actual = {str(p.relative_to(ROOT)) for folder in FOLDERS for p in (ROOT/folder).rglob('*') if p.is_file()}
    expected = {p for p in frozen if p.startswith(FOLDERS)}
    require(actual == expected, 'Exact runtime roster differs '+str({'added': sorted(actual-expected), 'missing': sorted(expected-actual)}))
    return {'baseline_commit': BASE, 'baseline_export_source': '1dfe7ae589154a841a56f5acaccb50f44b83c101', 'frozen_git_blobs': len(frozen), 'protected_files': len(set(frozen)-allowed), 'allowed_existing_runtime_changes': sorted(allowed), 'ui_changed_functions_only':{p:sorted(v) for p,v in ui_scope.items()}, 'runtime_roster': len(expected), 'protected_fingerprints': {p: sha(b) for p,b in frozen.items() if p not in allowed}}, frozen

def authored_policy(plan, frozen, selected):
    observations = []
    for spec in plan['levels']:
        id = spec['id']
        if id not in selected:
            continue
        rel = f'resources/campaign/{id}-route.json'
        before = json.loads(frozen[rel]); current = json.loads((ROOT/rel).read_text())
        require(current.get('layout_revision') == 14, 'Authored v14 handoff not ready '+id)
        require(current['version'] == before['version'] == 13 and current['design_version'] == 13, 'Historical v13 schema compatibility '+id)
        for key in ('id', 'enemy_total', 'spawn_room', 'spawn_local', 'spawn_position', 'exit', 'keys', 'anchors', 'checkpoints', 'weapon', 'main_route_ammo', 'main_route_health', 'main_route_armor', 'optional_rooms', 'secret_rooms'):
            require(current[key] == before[key], 'Protected authored gameplay field '+id+'/'+key)
        # Geometry may enrich the same graph edges, never introduce shortcuts.
        strip = lambda p: {k:p.get(k) for k in ('id','from','to','requires','shortcut','secret','lift','first_open_from')}
        require([strip(p) for p in current['portals']] == [strip(p) for p in before['portals']], 'Exact existing graph/prerequisites '+id)
        require(current['supplies'] == before['supplies'], 'Main-route supply bytes/positions '+id)
        require(current['structural_connections'][:len(before['structural_connections'])] == before['structural_connections'], 'Existing v13 structural contracts preserved '+id)
        ids = lambda r: {x.get('stable_id',x.get('id')):x.get('kind',x.get('type')) for x in r}
        require(ids(current['enemy_spawns']) == ids(before['enemy_spawns']), 'Exact actor IDs/types '+id)
        require(len(current['enemy_spawns']) == current['enemy_total'], 'Exact enemy budget '+id)
        approved_actors={x['stable_id']:x for x in spec['reserve_actor_overrides']+[spec['new_shared_connection']['actor_override']]}
        old_actors={x['stable_id']:x for x in before['enemy_spawns']}
        for actor in current['enemy_spawns']:
            stable=actor['stable_id'];old=old_actors[stable];override=approved_actors.get(stable)
            require(actor['position']==(override['position'] if override else old['position']), 'Unexpected actor relocation '+stable)
            require(actor.get('source_room',old['room'])==old['room'], 'Actor source identity '+stable)
            if override and 'arena_id' in override:
                require(actor.get('arena_id')==override['arena_id'] and actor.get('activation_room')==override['activation_room'], 'Exact two optional actor groups '+stable)
        def pickups(text):
            result={}
            for block in re.split(r'(?m)^\[node ',text)[1:]:
                if 'metadata/stage_pickup = ' not in block:continue
                key=re.search(r'(?m)^metadata/stable_id = (".*")$',block)
                kind=re.search(r'(?m)^metadata/stage_pickup = (".*")$',block)
                amount=re.search(r'(?m)^metadata/amount = (.*)$',block)
                position=re.search(r'(?m)^position = (.*)$',block)
                require(key is not None and kind is not None,'Pickup missing stable identity '+id)
                result[json.loads(key[1])]=(json.loads(kind[1]),amount[1] if amount else None,position[1] if position else None)
            return result
        scene=f'scenes/campaign/{id}.tscn'
        require(pickups((ROOT/scene).read_text())==pickups(frozen[scene].decode()),'Exact all pickup IDs/kinds/amounts/positions including optional health and shells '+id)
        old_profile = before['objective_profile']; profile = current['objective_profile']
        require(profile['exit_requires'] == old_profile['exit_requires'] and profile['keys'] == old_profile['keys'] and profile['initial_flags'] == old_profile['initial_flags'], 'No new objective/exit prerequisite '+id)
        require([{k:v for k,v in o.items() if k!='text'} for o in profile['objectives']] == [{k:v for k,v in o.items() if k!='text'} for o in old_profile['objectives']], 'Exact objective ownership/order '+id)
        require({k:{a:b for a,b in v.items() if a not in ('message','completion_message')} for k,v in profile['controls'].items()} == {k:{a:b for a,b in v.items() if a not in ('message','completion_message')} for k,v in old_profile['controls'].items()}, 'Exact control mutations '+id)
        for key, value in old_profile['encounters'].items():
            require(profile['encounters'].get(key) == value, 'Existing mandatory encounter unchanged '+id+'/'+key)
        added = [e for k,e in profile['encounters'].items() if k not in old_profile['encounters']]
        reward = spec['optional_reserve']
        require(len(added) == 1, 'Exactly one optional reserve encounter '+id)
        e = added[0]
        for k,value in {'activation':'pickup','pickup_id':reward['reward_stable_id'],'requires':[],'arena_id':reward['arena_id'],'release_doors':[reward['release_door_stable_id']]}.items():
            require(e.get(k) == value, 'Exact optional encounter '+id+'/'+k)
        require(not e.get('seal',False) and not any('clear_'+reward['arena_id'] in v for v in [profile['exit_requires']]), 'Optional group never seals or gates main exit '+id)
        old_rooms = before['rooms']; rooms = current['rooms']
        require(set(rooms) == set(old_rooms), 'Exact room IDs '+id)
        outlines = {x['room']:x for x in spec['outlines']}
        allowed_moves = {key:value for s in spec['outlines'] for key,value in s['prop_moves'].items()} | reward.get('north_prop_moves',{}) | reward.get('south_prop_moves',{})
        for room_id, room in rooms.items():
            old = old_rooms[room_id]
            for k in ('center','size','district','optional','secret','function'):
                require(room[k] == old[k], 'Protected room field '+id+'/'+room_id+'/'+k)
            if room_id in outlines:
                require(room['outline_xz'] == outlines[room_id]['outline_xz'], 'Exact approved footprint '+id+'/'+room_id)
            require([(o['id'],o['type']) for o in room['objects']] == [(o['id'],o['type']) for o in old['objects']], 'Exact fitting IDs/types/count '+id+'/'+room_id)
            for a,b in zip(room['objects'],old['objects']):
                want = dict(b)
                if a['id'] in allowed_moves: want['position_local'] = allowed_moves[a['id']]
                require(a == want, 'Unexpected prop relocation '+id+'/'+a['id'])
        observations.append({'level':id,'actors':current['enemy_total'],'outlines':len(outlines),'optional_arena':reward['arena_id'],'main_graph':'exact v13 edges and prerequisites'})
    return observations

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--level', choices=['pale_ward_01','pale_ward_02','pale_ward_03','all'], default='all')
    p.add_argument('--source-only', action='store_true'); p.add_argument('--baseline-only',action='store_true')
    p.add_argument('--native',action='store_true'); p.add_argument('--main-pack',type=Path)
    p.add_argument('--mode',choices=['all','controlled','live','connections'],default='all')
    p.add_argument('--route-report',type=Path,action='append',default=[])
    p.add_argument('--report',type=Path,required=True)
    a = p.parse_args(); require(a.report.resolve().is_relative_to(OUT.resolve()), 'Evidence belongs under ward-spatial-v14/')
    a.report.parent.mkdir(parents=True,exist_ok=True); result={'status':'failed'}
    try:
        result['source_policy'], frozen = source_policy()
        plan = json.loads((ROOT/'docs/ward-spatial-v14/plan.json').read_text())
        selected = [s['id'] for s in plan['levels']] if a.level == 'all' else [a.level]
        if not a.baseline_only:
            result['authored_policy'] = authored_policy(plan,frozen,selected)
            if a.route_report:
                expected=previous.design_contract()
                result['campaign_audits']=[previous.check_route_receipt(f,expected,True) for f in a.route_report]
            elif not a.source_only:
                loaded_paths={f'scenes/campaign/{id}.tscn' for id in selected}|{f'resources/campaign/{id}-route.json' for id in selected}|{f'resources/campaign/v13/{id}-objectives.tres' for id in selected}|{'scripts/stage_level.gd','scripts/industrial_hud_v8.gd','scripts/ward_automap.gd','scripts/stage_checkpoint_v13.gd'}
                result['loaded_source_before']={path:sha((ROOT/path).read_bytes()) for path in sorted(loaded_paths)}
                with tempfile.TemporaryDirectory(prefix='eyesore-spatial-v14-') as directory:
                    temp=Path(directory); spec=temp/'expected.json';spec.write_text(json.dumps({'plan':plan,'selected':selected,'mode':a.mode})); target=temp/'native.json'
                    cmd=[str(previous.GODOT)]+(['--position','20000,20000'] if a.native else ['--headless'])+['--audio-driver','Dummy','--max-fps','60','--path',str(ROOT)]
                    if a.main_pack: cmd+=['--main-pack',str(a.main_pack.resolve())]
                    cmd+=['--script',str(ROOT/'tools/check_ward_spatial_v14.gd'),'--','--automated-input','--expected='+str(spec),'--report='+str(target)]
                    result['command']=cmd
                    with a.report.with_suffix('.log').open('w') as log:
                        proc=subprocess.run(cmd,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,env=dict(os.environ,XDG_DATA_HOME=str(temp/'data'),XDG_CONFIG_HOME=str(temp/'config')),timeout=600)
                    if target.exists():
                        result['actual_main']=json.loads(target.read_text());a.report.with_suffix('.native.json').write_bytes(target.read_bytes())
                    require(proc.returncode == 0 and result.get('actual_main',{}).get('status')=='passed','Actual Main v14 fixture failed; preserve log/native diagnostics')
                    require(not re.search(r'(^|\n)\s*(?:SCRIPT ERROR:|ERROR:|WARNING:|Unicode parsing error)',a.report.with_suffix('.log').read_text()),'Strict v14 fixture engine diagnostic')
                result['loaded_source_after']={path:sha((ROOT/path).read_bytes()) for path in sorted(loaded_paths)}
                require(result['loaded_source_before']==result['loaded_source_after'],'Loaded production files changed during native fixture; diagnostic run only')
        result['source_after'],_ = source_policy(); result['status']='passed'
    except (RuntimeError,OSError,ValueError,KeyError,TypeError,subprocess.SubprocessError) as error:
        result['error']=str(error)
    result['auditor_sha256']=sha(Path(__file__).read_bytes());a.report.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'status':result['status'],'error':result.get('error'),'actual_checks':len(result.get('actual_main',{}).get('checks',[]))}))
    return 0 if result['status']=='passed' else 1
if __name__=='__main__':raise SystemExit(main())
