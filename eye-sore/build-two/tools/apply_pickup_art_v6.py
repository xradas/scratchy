#!/usr/bin/env python3
"""Register explicit native pickup atlas regions; never changes source pixels/scenes."""
import argparse
import hashlib
import json
import struct
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REQUIRED = {'pistol', 'shells', 'rivets', 'rockets', 'brass', 'red'}
SIZES = {'pistol':[.68,.38,.48], 'shells':[.72,.42,.48], 'rivets':[.74,.44,.52], 'rockets':[.86,.44,.50], 'health':[.64,.4,.48], 'armor':[.66,.42,.48]}

def register(layout_path, destination):
    layout = json.loads(layout_path.read_text())
    atlas = layout['atlas']
    assert atlas.startswith('res://assets/pickups/'), 'Pickup source must be a project pickup asset'
    source = ROOT / atlas.removeprefix('res://')
    data = source.read_bytes()
    assert data[:8] == b'\x89PNG\r\n\x1a\n', 'Byte-original PNG required'
    width, height = struct.unpack('>II', data[16:24])
    # Use the pinned native decoder, so no optional Python image library and
    # no raster transformations are involved in registration.
    with tempfile.TemporaryDirectory(prefix='pickup-v6-pixels-') as temporary:
        receipt=Path(temporary)/'pixels.json'
        subprocess.run([str(ROOT/'tools/godot.sh'),'--headless','--script',str(ROOT/'tools/check_pickup_art_v6.gd'),'--','--fingerprint-only='+str(source),'--report='+str(receipt)],cwd=ROOT,check=True,capture_output=True,text=True)
        native=json.loads(receipt.read_text())
        assert native['status']=='passed' and native['dimensions']==[width,height]
        rgba8_sha256=native['native_rgba8_sha256']
    assert REQUIRED <= set(layout['items']), 'All four ammo families and both keys required'
    items = {}
    for kind, record in layout['items'].items():
        assert kind in REQUIRED | {'health','armor'}, 'Unknown pickup '+kind
        fields = ['metal'] if kind in {'brass','red'} else ['front','side','top']
        item = {'geometry':'key' if kind in {'brass','red'} else 'box', 'regions':{}}
        for face in fields:
            rect = record[face]
            assert len(rect)==4 and all(type(v) is int for v in rect), 'Integer native rectangle required'
            x,y,w,h = rect
            assert x>=0 and y>=0 and w>0 and h>0 and x+w<=width and y+h<=height, 'Region outside source: '+kind+'/'+face
            item['regions'][face] = rect
        if item['geometry']=='box':
            default_size=list(SIZES[kind])
            front=item['regions']['front']
            default_size[1]=default_size[0]*front[3]/front[2]
            item['size'] = record.get('size', default_size)
            assert len(item['size'])==3 and all(0<v<=1.2 for v in item['size']), 'Bounded physical box size'
        item['metallic'] = record.get('metallic', .85 if item['geometry']=='key' else .18)
        item['roughness'] = record.get('roughness', .32 if item['geometry']=='key' else .86)
        assert 0<=item['metallic']<=1 and 0<=item['roughness']<=1, 'Physical material range'
        items[kind] = item
    result = {'version':6,'atlas':atlas,'source_sha256':hashlib.sha256(data).hexdigest(),'native_rgba8_sha256':rgba8_sha256,'source_canvas':[width,height], 'source_layout_sha256':hashlib.sha256(layout_path.read_bytes()).hexdigest(), 'sampling':'native AtlasTexture rectangles, nearest, filter_clip; no source image edits', 'aliases':{'brass_key':'brass','red_key':'red'},'items':items}
    destination.parent.mkdir(parents=True,exist_ok=True)
    destination.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'status':'registered','manifest':str(destination),'atlas_sha256':result['source_sha256'],'canvas':[width,height],'kinds':sorted(items)}))

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('layout',type=Path)
    parser.add_argument('--manifest',type=Path,default=ROOT/'resources/pickups/presentation-v6.json')
    args=parser.parse_args()
    register(args.layout,args.manifest)

if __name__=='__main__':main()
