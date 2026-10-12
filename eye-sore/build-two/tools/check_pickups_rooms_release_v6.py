#!/usr/bin/env python3
"""V6 bounded extension of frozen balance/campaign/archive readers.

Only additive 48+9 cue manifests and independently derived side-room supply Z
changes are authorized. Source or external pinned Godot --main-pack; no ELF run.
"""
import argparse,copy,hashlib,json,re,subprocess,tarfile,tempfile
from pathlib import Path
import check_balance_release as balance
from pickup_positions_v6 import derive,PRIOR_SHA,authored
from verify_pale_ward_archive import AuditError,require
ROOT=Path(__file__).resolve().parents[1]
PROBE=Path(__file__).with_suffix('.gd')
ADDED=['pickup_'+x for x in ['pistol','shells','rivets','rockets','health','armor','brass_key','red_key','weapon']]
AUTHORIZED={'assets/audio/runtime-cues.json','resources/combat_audio.tres'}
BASELINE_SHA='8266ad1f91d1425e7eaa3590bfcd2152cfbe80fd196d32af4c4897c8ad010fda'
native_probe=balance.probe
base_expected=balance.balance_expected

def v6_expected(root,expected,source):
    original=json.loads((ROOT/'tools/balance_v4_preserved.json').read_text())
    require(balance.campaign.digest((ROOT/'tools/balance_v4_preserved.json').read_bytes())==balance.PRESERVED_SHA256,'Original balance baseline remains sealed')
    prior_path=ROOT/'tools/pickups_rooms_prior_v6.json'
    require(balance.campaign.digest(prior_path.read_bytes())==PRIOR_SHA,'Verified previous PCK snapshot remains sealed')
    prior=json.loads(prior_path.read_text())
    ledger=json.loads((root/'assets/audio/runtime-cues.json').read_text())
    require(len(ledger['cues'])==57 and set(ledger['cues'])-set(prior['cue_ledger']['cues'])==set(ADDED),'Exactly nine specified additive receipt cues')
    stripped=copy.deepcopy(ledger)
    for key in ADDED:
        require(stripped['cues'][key]['bus']=='UI' and stripped['cues'][key].get('spatial') is False,'Receipt cue UI/nonspatial '+key)
        del stripped['cues'][key]
    require(stripped==prior['cue_ledger'],'All48 original structured ledger entries and top-level values unchanged')
    require(balance.campaign.digest((json.dumps(stripped,indent=2)+'\n').encode())==original['files']['assets/audio/runtime-cues.json'],'Removed additions reconstruct byte-identical prior ledger')
    require(balance.campaign.digest((root/'concepts/pickups-rooms-v6/audio/preservation/profile-before.tres').read_bytes())==original['files']['resources/combat_audio.tres'],'Prior48 profile source bytes match original pin')
    baseline_path=root/'verification/pickup-art-v6/pickup-baseline.json'
    require(balance.campaign.digest(baseline_path.read_bytes())==BASELINE_SHA,'Original711 pickup root snapshot unchanged')
    positions=derive(root)
    require(json.loads((root/'docs/pickup-art-v6/authorized-positions.json').read_text())==positions,'Authorized positions reproduce independent original-PCK/depth-delta derivation')
    adjusted=copy.deepcopy(original)
    for path in AUTHORIZED:del adjusted['files'][path]
    require(len(adjusted['files'])==77,'Exactly77 other original asset pins retained')
    for scene,moves in positions['scenes'].items():
        level=Path(scene).stem
        for name,move in moves.items():
            if name in adjusted['vital_pickups'][level]:
                previous=adjusted['vital_pickups'][level][name]
                require(previous['kind']==move['kind'] and previous['amount']==move['amount'],'Original vital grant unchanged')
                previous['position']=move['expected_position']
    with tempfile.TemporaryDirectory(prefix='v6-authorized-baseline-') as d:
        path=Path(d)/'authorized.json';path.write_text(json.dumps(adjusted,indent=2)+'\n')
        saved_path,saved_sha=balance.PRESERVED,balance.PRESERVED_SHA256
        balance.PRESERVED=path;balance.PRESERVED_SHA256=balance.campaign.digest(path.read_bytes())
        try:result=base_expected(root,expected,source)
        finally:balance.PRESERVED,balance.PRESERVED_SHA256=saved_path,saved_sha
    def recorded(path):
        data=(root/path).read_bytes();sha=balance.campaign.digest(data)
        if source is not None:require(source.get(path)==sha,'V6 source ledger missing/different '+path)
        expected['files'][path]=sha
        return data
    paths=['resources/pickups/presentation-v6.json','docs/pickup-art-v6/authorized-positions.json','docs/room-program-v6/levels.json','resources/campaign/room-program-freeze-v6.json','resources/campaign/room-fittings-v6.json','resources/campaign/room-program-inventory.json','shaders/room_prop_local_uv.gdshader','tools/pickups_rooms_prior_v6.json','verification/pickup-art-v6/pickup-baseline.json','concepts/pickups-rooms-v6/audio/manifest.json','concepts/pickups-rooms-v6/props-generation.json']
    for path in paths:recorded(path)
    art=json.loads(recorded('resources/pickups/presentation-v6.json'))
    require(balance.campaign.digest(recorded(art['atlas'].removeprefix('res://')))==art['source_sha256'],'Native selected pickup PNG matches registered hash')
    programmes=json.loads((root/'docs/room-program-v6/levels.json').read_text())
    rooms={};props={};progression={}
    for plan in programmes['levels']:
        scene='res://scenes/campaign/'+plan['id']+'.tscn'
        layout=json.loads(recorded('resources/campaign/'+plan['id']+'-layout.json'))
        room_map={x['id']:x for x in layout['rooms']}
        rooms[scene]={};props[scene]={}
        progression[scene]=plan['progression_objects']
        gates={p['gate']:p for p in layout['portals'] if p.get('gate')}
        buttons={b['id']:b for b in layout['buttons']}
        keys={k['id']:k for k in layout['keys']}
        for obj in plan['progression_objects']:
            if obj['type']=='gate':require(gates[obj['id']]['to']==obj['leads_to'] and gates[obj['id']]['requires']==obj['requires'],'Frozen planned gate progression '+plan['id']+'/'+obj['id'])
            elif obj['type']=='switch':require(buttons[obj['id']]['room']==obj['room'] and buttons[obj['id']]['sets'] in obj['sets'],'Frozen planned switch progression')
            elif obj['type']=='key':require(keys[obj['id']]['room']==obj['room'],'Frozen planned key chamber')
            elif obj['type']=='exit':require(layout['exit']['room']==obj['room'] and layout['exit']['requires']==obj['requires'],'Frozen planned exit progression')
        for item in plan['rooms']:
            room=room_map[item['id']];x,y,z=room['center'];w,h,d=room['size']
            rooms[scene][item['id']]={'position':[authored(x),authored(y+h/2),authored(z)],'bounds':[authored(w/2),authored(h/2+1),authored(d/2)],'function':item['function'],'layout_mode':item['layout_mode']}
            for obj in item['objects']:
                for n in range(1,obj['count']+1):props[scene][obj['id']+'.'+str(n)]={'type':obj['type'],'function':item['function'],'layout_mode':item['layout_mode']}
    require(sum(map(len,props.values()))==508,'Exactly508 planned typed fitting instances')
    atlas_records={}
    for rec in json.loads((root/'concepts/pickups-rooms-v6/props-generation.json').read_text())['atlases']:
        path=rec['saved'];data=recorded(path)
        require(balance.campaign.digest(data)==rec['sha256'],'Byte-original prop PNG '+rec['theme'])
        # New byte-original RGB sheets differ from the historical RGBA-only
        # gun decoder. Use native raw-file decoding for a separate fingerprint.
        with tempfile.TemporaryDirectory(prefix='v6-prop-pixels-') as d:
            receipt=Path(d)/'pixels.json'
            subprocess.run([str(ROOT/'tools/godot.sh'),'--headless','--script',str(ROOT/'tools/check_pickup_art_v6.gd'),'--','--fingerprint-only='+str(root/path),'--report='+str(receipt)],cwd=root,check=True,capture_output=True,text=True)
            pixels=json.loads(receipt.read_text())
        require(pixels['source_sha256']==rec['sha256'] and pixels['dimensions']==rec['dimensions'],'Native raw prop decoder identity')
        atlas_records[rec['theme']]={'path':'res://'+path,'dimensions':pixels['dimensions'],'rgba8_sha256':pixels['native_rgba8_sha256'],'regions':[x['region'] for x in rec['regions']]}
    snapshot=json.loads(baseline_path.read_text())
    for scene in snapshot['scenes']:
        recorded(scene.removeprefix('res://'))
    expected['v6']={'prior_cues':prior['profile_cues'],'profile_properties':prior['profile_properties'],'added_cues':ADDED,'pickup_manifest':art,'pickup_baseline':snapshot,'positions':positions,'rooms':rooms,'props':props,'progression':progression,'prop_atlases':atlas_records,'shader_sha256':expected['files']['shaders/room_prop_local_uv.gdshader'],'new_audio_manifest':json.loads((root/'concepts/pickups-rooms-v6/audio/manifest.json').read_text())}
    return result

def probe(args,expected,temporary,pack):
    old=balance.PROBE;balance.PROBE=PROBE
    try:return native_probe(args,expected,temporary,pack)
    finally:balance.PROBE=old

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive',nargs='?',type=Path);parser.add_argument('--source-preflight',action='store_true');parser.add_argument('--expected-commit');parser.add_argument('--archive-record',type=Path);parser.add_argument('--source-root',type=Path,default=ROOT);parser.add_argument('--godot',type=Path,default=balance.campaign.arsenal.base.GODOT);parser.add_argument('--report',type=Path,required=True)
    args=parser.parse_args();balance.campaign.campaign_expected=v6_expected;balance.campaign.probe=probe
    try:result=balance.campaign.audit(args)
    except (AuditError,OSError,ValueError,KeyError,TypeError,AssertionError,IndexError,AttributeError,tarfile.TarError,subprocess.SubprocessError) as error:result={'status':'failed','error':str(error),'scope':'V6 independent audit did not establish release acceptance.'}
    result['authorized_v6_changes']={'byte_pins':sorted(AUTHORIZED),'preserved_other_asset_pins':77,'prior_cues':48,'added_cues':9,'derived_supply_moves':158,'explicitly_resized_rooms':55,'intent_before_creation':'docs/room-program-v6/levels.json','scope':'No other byte pin, root metadata/grant, core/unresized/standalone position exceptions. Original auditors/baselines remain unchanged.'}
    result['v6_auditor_sha256']=balance.campaign.digest(Path(__file__).read_bytes());result['v6_probe_sha256']=balance.campaign.digest(PROBE.read_bytes());result['frozen_balance_auditor_sha256']=balance.campaign.digest(Path(balance.__file__).read_bytes());result['frozen_balance_probe_sha256']=balance.campaign.digest(Path(balance.__file__).with_suffix('.gd').read_bytes());result['prior_pck_snapshot_sha256']=PRIOR_SHA
    args.report.parent.mkdir(parents=True,exist_ok=True);args.report.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'status':result['status'],'error':result.get('error'),'checks':result.get('probe',{}).get('checks'),'failures':result.get('probe',{}).get('failures',[]),'report':str(args.report)}));return 0 if result['status']=='passed' else 1
if __name__=='__main__':raise SystemExit(main())
