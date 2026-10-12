"""Independent authorized geometry deltas, using a sealed previous PCK snapshot."""
import hashlib,json,math,struct
from pathlib import Path
PRIOR_SHA='7d2246c2ff82e67c4aa50cc433fce88c18ff2c414513dd0bf2089e105fbf9e4b'
SLOTS={'pistol':0,'shells':1,'rivets':2,'rockets':3,'health':2,'armor':3}
def digest(data):return hashlib.sha256(data).hexdigest()
def native(v):return struct.unpack('f',struct.pack('f',float(v)))[0]
def authored(v):return native(float(format(v,'.6g')))
def derive(root):
    root=Path(root);prior_path=root/'tools/pickups_rooms_prior_v6.json'
    assert digest(prior_path.read_bytes())==PRIOR_SHA,'Trusted previous PCK snapshot changed'
    prior=json.loads(prior_path.read_text());baseline=json.loads((root/'verification/pickup-art-v6/pickup-baseline.json').read_text())
    plans=json.loads((root/'docs/room-program-v6/levels.json').read_text())
    result={'intent':'docs/room-program-v6/levels.json authored_size_xz was revised before scene creation; only supply Z changes by half depth delta. Native 6-significant-digit author serialization is explicitly reproduced.','scenes':{},'rooms':{},'count':0,'room_count':0}
    for plan in plans['levels']:
        level=plan['id'];scene='res://scenes/campaign/'+level+'.tscn'
        old_rooms={r['id']:r for r in prior['levels'][level]['rooms']}
        layout=json.loads((root/'resources/campaign'/f'{level}-layout.json').read_text());new_rooms={r['id']:r for r in layout['rooms']}
        changed={r['id']:r['authored_size_xz'] for r in plan['rooms'] if 'authored_size_xz' in r}
        assert not set(changed)&{'entry','service','spine','arena_one','arena_two','final_arena','exit_gallery','observation'}
        result['rooms'][scene]={};result['scenes'][scene]={}
        for rid,r in new_rooms.items():
            before=old_rooms[rid]
            assert all(math.isclose(a,b,rel_tol=0,abs_tol=1e-9) for a,b in zip(r['center'],before['center'])),'Original centre changed: '+level+'/'+rid
            assert r['size'][1]==before['size'][1],'Original height changed'
            if rid not in changed:assert all(math.isclose(a,b,rel_tol=0,abs_tol=1e-9) for a,b in zip(r['size'],before['size'])),'Unresized footprint changed'
            else:
                assert [r['size'][0],r['size'][2]]==changed[rid],'Native contract does not match prior explicit plan'
                result['room_count']+=1
                result['rooms'][scene][rid]={'center':before['center'],'old_size':before['size'],'new_size':r['size']}
        for name,item in baseline['scenes'][scene]['pickups'].items():
            kind=item['metadata']['stage_pickup'];prefix='Supply_'+kind+'_'
            if not name.startswith(prefix):continue
            rid=name.removeprefix(prefix)
            if rid not in changed:continue
            before=old_rooms[rid];after=new_rooms[rid];slot=SLOTS[kind]
            old_logical_z=before['center'][2]+before['size'][2]/2-3-(slot//2)*1.2
            position=item['position']
            assert native(position[2])==authored(old_logical_z),'Prior native slot not reproduced: '+level+'/'+name
            assert native(position[0])==authored(before['center'][0]+(-.8 if slot%2==0 else .8)) and native(position[1])==authored(before['center'][1]+.5),'Prior XY not reproduced'
            delta=(after['size'][2]-before['size'][2])/2
            expected=[native(position[0]),native(position[1]),authored(old_logical_z+delta)]
            result['scenes'][scene][name]={'room':rid,'original_position':position,'expected_position':expected,'logical_old_z':old_logical_z,'logical_new_z':old_logical_z+delta,'delta_z':delta,'kind':kind,'amount':item['metadata']['amount']}
            result['count']+=1
    assert result['room_count']==55 and result['count']==158,(result['room_count'],result['count'])
    return result
if __name__=='__main__':
    root=Path(__file__).resolve().parents[1];result=derive(root);out=root/'docs/pickup-art-v6/authorized-positions.json';out.write_text(json.dumps(result,indent=2)+'\n');print('Derived',result['count'],'supply positions in',result['room_count'],'explicitly resized rooms')
