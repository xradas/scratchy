#!/usr/bin/env python3
"""Register untouched native gun atlases into a separate review candidate.

python3 tools/register_arsenal_v2.py --layout LAYOUT.json --candidate CANDIDATE.json --report AUDIT.json
Layout: {"weapons": {"twin_shotgun": {"file": "res://...png", "regions":
{"idle":[x,y,w,h], ...}, "placement": {"idle":{"marker":[local_x,local_y],
"target":[normalized_x,normalized_y], "scale":1}, ...},
"muzzle_markers":{"idle":[local_x,local_y], ...}, "source_canvas_height":980}}}.
All four explicit native rectangles and local muzzle markers are required. No
pixels are rewritten. The baseline, its old entries, and source PNGs stay intact.
"""
from __future__ import annotations
import argparse
from copy import deepcopy
import hashlib
import json
import math
from pathlib import Path
import sys
import struct
import zlib
from native_png import decode_png

ROOT = Path(__file__).resolve().parents[1]
WEAPONS = ('twin_shotgun', 'rivet_cannon', 'siege_launcher')
PHASES = ('idle', 'fire', 'recover', 'switch')


def sha(data): return hashlib.sha256(data).hexdigest()
def document(path):
    def unique(pairs):
        result = {}
        for k, v in pairs:
            if k in result: raise ValueError('Duplicate JSON key: ' + k)
            result[k] = v
        return result
    return json.loads(path.read_text(), object_pairs_hook=unique)


def pair(value, label):
    if not isinstance(value, list) or len(value) != 2 or not all(type(x) in (int, float) and math.isfinite(x) for x in value):
        raise ValueError(label + ': finite coordinate pair required')
    return value


def register(layout, baseline, root):
    candidate = deepcopy(baseline)
    failures, records = [], {}
    def check(condition, message):
        if not condition: failures.append(message)
    check(set(layout.get('weapons', {})) == set(WEAPONS), 'Exactly three new weapon layouts required')
    for weapon, entry in layout.get('weapons', {}).items():
        if weapon not in WEAPONS: continue
        try:
            check(weapon not in baseline.get('weapons', {}) and weapon not in baseline.get('weapon_atlases', {}), weapon + ': baseline already contains new key; use preserved pre-registration baseline')
            path = entry['file']
            if not path.startswith('res://'): raise ValueError(weapon + ': runtime res:// PNG path required')
            file = (root / path.removeprefix('res://')).resolve()
            if not file.is_relative_to(root.resolve()): raise ValueError(weapon + ': source path escapes project')
            original = file.read_bytes()
            width, height, rgba, has_alpha = decode_png(original)
            check(has_alpha, weapon + ': source needs actual alpha channel')
            alpha = rgba[3::4]
            canvas_height = entry['source_canvas_height']
            check(type(canvas_height) in (int, float) and canvas_height > 0, weapon + ': positive source_canvas_height required')
            definition = {'columns': 2, 'rows': 2, 'cells': dict(zip(PHASES, range(4))),
                          'regions': {}, 'placement': {}, 'source_canvas_height': canvas_height,
                          'sha256': sha(original), 'source_dimensions': [width, height],
                          'presentation': entry.get('presentation', 'Byte-original generated PNG with explicit native source rectangles and authored local markers; visual acceptance pending.')}
            frames, rects, anchors = {}, [], {}
            for phase in PHASES:
                values = entry['regions'][phase]
                if len(values) != 4 or not all(type(v) in (int, float) and v == int(v) for v in values): raise ValueError(weapon + ' ' + phase + ': integer native rectangle required')
                x, y, w, h = map(int, values)
                if not (0 <= x < x+w <= width and 0 <= y < y+h <= height): raise ValueError(weapon + ' ' + phase + ': rectangle outside native PNG')
                rects.append((phase, (x, y, x+w, y+h)))
                pose = deepcopy(entry['placement'][phase])
                marker = pair(pose['marker'], weapon + ' ' + phase + ' pivot marker')
                muzzle = pair(entry['muzzle_markers'][phase], weapon + ' ' + phase + ' muzzle marker')
                target = pair(pose['target'], weapon + ' ' + phase + ' target')
                check(0 <= marker[0] < w and 0 <= marker[1] < h, weapon + ' ' + phase + ': pivot marker inside region')
                check(0 <= muzzle[0] < w and 0 <= muzzle[1] < h, weapon + ' ' + phase + ': muzzle marker inside region')
                check(all(0 <= v <= 1 for v in target), weapon + ' ' + phase + ': target normalized')
                check(type(pose['scale']) in (int, float) and math.isfinite(pose['scale']) and pose['scale'] > 0, weapon + ' ' + phase + ': positive finite scale')
                region = b''.join(alpha[row*width+x:row*width+x+w] for row in range(y,y+h))
                minimum_x, minimum_y, maximum_x, maximum_y, occupied_count = w,h,-1,-1,0
                for index,value in enumerate(region):
                    if value <= 5: continue
                    px,py = index%w,index//w
                    minimum_x,minimum_y = min(minimum_x,px),min(minimum_y,py)
                    maximum_x,maximum_y = max(maximum_x,px),max(maximum_y,py)
                    occupied_count += 1
                bounds = (minimum_x,minimum_y,maximum_x+1,maximum_y+1) if occupied_count else None
                check(bounds is not None, weapon + ' ' + phase + ': empty alpha region')
                edges = {'left':region[::w], 'right':region[w-1::w], 'top':region[:w], 'bottom':region[-w:]}
                exact = {side: sum(v > 0 for v in edge) for side, edge in edges.items()}
                visible = {side: sum(v > 5 for v in edge) for side, edge in edges.items()}
                internal = {'left': x > 0, 'right': x+w < width, 'top': y > 0, 'bottom': y+h < height}
                for side in edges:
                    if internal[side]: check(exact[side] == 0, weapon + ' ' + phase + ': nonzero alpha touches internal ' + side + ' separator (neighbor clipping risk)')
                    elif side != 'bottom': check(visible[side] == 0, weapon + ' ' + phase + ': visible alpha clipped on exterior ' + side)
                frames[phase] = {'native_region': [x,y,w,h], 'alpha_bounds_local': [bounds[0],bounds[1],bounds[2]-bounds[0],bounds[3]-bounds[1]] if bounds else [],
                    'alpha_bounds_source': [x+bounds[0],y+bounds[1],bounds[2]-bounds[0],bounds[3]-bounds[1]] if bounds else [],
                    'occupied_pixels_above_5': occupied_count, 'exact_nonzero_edge_pixels': exact,
                    'visible_edge_pixels_above_5': visible, 'internal_edges': internal, 'pivot_local': marker, 'muzzle_local': muzzle,
                    'exterior_bottom_contact': y+h == height and exact['bottom'] > 0,
                    'screen_projections': []}
                for sw, sh in ((1280,720),(1560,900),(800,600)):
                    factor = min(sw/640, sh/360)
                    if factor >= 1: factor = math.floor(factor)
                    view_size = (640*factor,360*factor)
                    view_pos = ((sw-view_size[0])/2,(sh-view_size[1])/2)
                    scale = view_size[1] / canvas_height * pose['scale']
                    origin = [view_pos[i]+view_size[i]*target[i]-marker[i]*scale for i in range(2)]
                    projected = [origin[i]+muzzle[i]*scale for i in range(2)]
                    crosshair = [view_pos[i]+view_size[i]*.5 for i in range(2)]
                    frames[phase]['screen_projections'].append({'window':[sw,sh], 'weapon_origin':origin,
                        'muzzle_screen':projected, 'crosshair_screen':crosshair, 'muzzle_minus_crosshair':[projected[i]-crosshair[i] for i in range(2)],
                        'scope':'Authored point projection only; does not authenticate illustrated bore direction or human visual acceptance.'})
                definition['regions'][phase] = [x,y,w,h]
                definition['placement'][phase] = pose
                anchors[phase] = [muzzle[0]*320/w, muzzle[1]*180/h]
            for i, (phase, a) in enumerate(rects):
                for other, b in rects[i+1:]: check(max(a[0],b[0]) >= min(a[2],b[2]) or max(a[1],b[1]) >= min(a[3],b[3]), weapon + ': overlapping native regions ' + phase + '/' + other)
            uncovered_visible = 0
            for sy in range(height):
                row = alpha[sy*width:(sy+1)*width]
                intervals = sorted((a[0],a[2]) for _,a in rects if a[1] <= sy < a[3])
                cursor = 0
                for start,end in intervals:
                    if start > cursor: uncovered_visible += sum(v > 5 for v in row[cursor:start])
                    cursor = max(cursor,end)
                uncovered_visible += sum(v > 5 for v in row[cursor:])
            check(uncovered_visible == 0, weapon + ': visible alpha outside all four authored regions')
            check(file.read_bytes() == original, weapon + ': PNG bytes changed during inspection')
            candidate.setdefault('weapons', {})[weapon] = dict.fromkeys(PHASES, path)
            candidate.setdefault('weapon_atlases', {})[weapon] = definition
            candidate.setdefault('flash', {}).setdefault('anchors', {})[weapon] = anchors
            records[weapon] = {'file':path, 'sha256':sha(original), 'source_dimensions':[width,height], 'uncovered_visible_alpha_pixels':uncovered_visible, 'frames':frames}
        except (OSError, ValueError, KeyError, TypeError, ZeroDivisionError, struct.error, zlib.error) as error: failures.append(str(error))
    restored = deepcopy(candidate)
    for weapon in WEAPONS:
        restored.get('weapons', {}).pop(weapon, None)
        restored.get('weapon_atlases', {}).pop(weapon, None)
        restored.get('flash', {}).get('anchors', {}).pop(weapon, None)
    check(restored == baseline, 'Old metadata changed outside new weapon entries')
    return candidate, {'passed': not failures, 'failures': failures, 'weapons': records,
        'old_metadata_identical': restored == baseline, 'source_pngs_rewritten': False,
        'scope':'Read-only source alpha/rectangle/marker audit and candidate metadata generation. External bottom contact is recorded for review; explicit internal seams must be alpha-zero. No raster transformation, native screenshot, illustrated aim authentication or human style acceptance claim.'}


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--layout', type=Path, required=True)
    parser.add_argument('--baseline', type=Path, default=ROOT/'assets/combat_art.json')
    parser.add_argument('--candidate', type=Path, required=True)
    parser.add_argument('--report', type=Path, required=True)
    parser.add_argument('--source-root', type=Path, default=ROOT)
    args = parser.parse_args()
    protected = {args.baseline.resolve(),args.layout.resolve()}
    if args.candidate.resolve() in protected or args.report.resolve() in protected or args.candidate.resolve() == args.report.resolve(): parser.error('Candidate/report must be separate from layout and baseline')
    baseline_bytes = args.baseline.read_bytes()
    try:
        candidate, report = register(document(args.layout), document(args.baseline), args.source_root)
        report['baseline_sha256'] = sha(baseline_bytes)
        report['baseline_bytes_preserved'] = args.baseline.read_bytes() == baseline_bytes
        if report['passed']:
            args.candidate.parent.mkdir(parents=True, exist_ok=True)
            args.candidate.write_text(json.dumps(candidate, indent=2)+'\n')
            report['candidate_sha256'] = sha(args.candidate.read_bytes())
    except (OSError, ValueError, KeyError, TypeError, struct.error, zlib.error) as error: report = {'passed':False,'failures':[str(error)]}
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps({'passed':report['passed'], 'failures':report['failures'], 'report':str(args.report), 'candidate_written':report['passed']}))
    return 0 if report['passed'] else 1

if __name__ == '__main__': sys.exit(main())
