#!/usr/bin/env python3
"""Format authored sheets into grounded RGBA sprites; no inferred animation.

ImageMagick performs only import/crop, shared nearest scale and canvas placement.
The six authored rows stay six authored poses. No per-frame body enlargement.
"""
from pathlib import Path
import json
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent
POSES = ('approach-a', 'approach-b', 'tell', 'release', 'recovery', 'corpse')
DIRS = ('front', 'front-right', 'right', 'back-right', 'back', 'back-left', 'left', 'front-left')

def call(*args):
    return subprocess.check_output(['magick', *map(str, args)])

def metrics(path):
    width, height = map(int, call('identify', '-format', '%w %h', path).split())
    pixels = call(path, '-depth', '8', 'rgba:-')
    solid = [i // 4 for i in range(0, len(pixels), 4) if pixels[i + 3] >= 128]
    return {
        'width': width, 'height': height,
        'alpha_min': min(pixels[3::4]), 'alpha_max': max(pixels[3::4]),
        'opaque_pixels': len(solid),
        'opaque_mean_rgb': round(sum(sum(pixels[p * 4:p * 4 + 3]) for p in solid) / (3 * len(solid)), 3),
        'bbox': [min(p % width for p in solid), min(p // width for p in solid),
                 max(p % width for p in solid) + 1, max(p // width for p in solid) + 1],
        'opaque_near_black_pixels': sum(pixels[i + 3] >= 128 and max(pixels[i:i + 3]) < 12
                                        for i in range(0, len(pixels), 4)),
    }

manifest = {
    'title': "Eye Sore — Furnace Descent redesign", 'production': 'original authored sprite keys, built-in image_gen',
    'canvas_pixels': [384, 256], 'render_canvas_aspect': 1.5,
    'pivot_engine_bottom_origin': [0.5, 0.0], 'ground_pixel': 255,
    'direction_order': list(DIRS), 'pose_order': list(POSES),
    'filter': 'nearest', 'alpha': 'binary cutout from source alpha threshold 128; never RGB black-key',
    'frames': [],
}

for family in ('hookrunner', 'soot-bellower'):
    source = ROOT / 'sources' / (family + '-source.png')
    width, height = map(int, call('identify', '-format', '%w %h', source).split())
    assert width % 8 == 0 and height % 6 == 0, 'Source must have integer eight-by-six cells'
    cell_w, cell_h = width // 8, height // 6
    assert cell_w == cell_h, 'Shared square import cell required'
    folder = ROOT / family
    folder.mkdir(exist_ok=True)
    work = tempfile.TemporaryDirectory(prefix='import-', dir=ROOT)
    work_path = Path(work.name)
    padded = work_path / 'padded.png'
    cell = work_path / 'cell.png'
    mask = work_path / 'body-mask.png'
    # Some generated toe tips cross a nominal row boundary. Twelve-pixel
    # vertical overscan recovers those tips; the largest real body component
    # excludes neighboring-row fragments, without inventing missing anatomy.
    overscan = 12
    call(source, '-background', 'none', '-gravity', 'center',
         '-extent', f'{width}x{height + overscan * 2}', padded)
    for pose_index, pose in enumerate(POSES):
        for direction, name in enumerate(DIRS):
            crop = f'{cell_w}x{cell_h + overscan * 2}+{direction * cell_w}+{pose_index * cell_h}'
            call(padded, '-gravity', 'northwest', '-crop', crop, '+repage', cell)
            components = call(cell, '-alpha', 'extract', '-threshold', '50%',
                              '-define', 'connected-components:verbose=true',
                              '-define', 'connected-components:mean-color=true',
                              '-connected-components', '8', 'null:').decode()
            whites = []
            for line in components.splitlines():
                match = re.match(r'\s*(\d+): .*? ([\d.]+) srgb\(255,255,255\)$', line)
                if match:
                    whites.append((float(match.group(2)), int(match.group(1))))
            assert whites, (family, pose, direction, 'No opaque body component')
            body_area, body_id = max(whites)
            call(cell, '-alpha', 'extract', '-threshold', '50%',
                 '-connected-components', '8', '-channel', 'R',
                 '-fx', f'round(u*quantumrange)=={body_id}?1:0', '-separate', '+channel', mask)
            pixels = call(mask, '-filter', 'point', '-resize', '256x', '-depth', '8', 'gray:-')
            ys = [i // 256 for i, value in enumerate(pixels) if value >= 128]
            assert ys, (family, pose, direction, 'Empty authored cell')
            assert max(ys) - min(ys) + 1 <= 256, (family, pose, direction, 'Body exceeds fixed canvas')
            shift = 255 - max(ys)
            stem = f'{family}-dir-{direction}-{pose}'
            png = folder / (stem + '.png')
            bmp = folder / (stem + '.bmp')
            call(cell, mask, '-alpha', 'off', '-compose', 'CopyOpacity', '-composite',
                 '-compose', 'Over', '-filter', 'point', '-resize', '256x', '-roll', f'+0{shift:+d}',
                 '-gravity', 'northwest', '-crop', '256x256+0+0', '+repage',
                 '-background', 'none', '-gravity', 'center', '-extent', '384x256',
                 '-background', 'black', '-alpha', 'background', '-strip',
                 '-define', 'png:color-type=6', png)
            call(png, '-define', 'bmp:format=bmp4', '-type', 'TrueColorAlpha', bmp)
            info = metrics(png)
            assert info['alpha_min'] == 0 and info['alpha_max'] == 255
            assert info['bbox'][3] == 256, (stem, 'Ground alignment')
            assert info['opaque_mean_rgb'] > 12, (stem, 'Color lost during alpha compositing')
            assert call(png, '-depth', '8', 'rgba:-') == call(bmp, '-depth', '8', 'rgba:-'), (stem, 'BMP alpha/color mismatch')
            manifest['frames'].append({
                'family': family, 'direction': direction, 'direction_name': name,
                'pose': pose, 'pose_index': pose_index,
                'png': str(png.relative_to(ROOT)), 'bmp': str(bmp.relative_to(ROOT)),
                'source_cell': [direction, pose_index], 'vertical_overscan': overscan,
                'kept_body_component': body_id, 'source_body_area': body_area,
                'render_y_offset_pixels': shift,
                **info,
            })
    work.cleanup()
    files = [folder / f'{family}-dir-{direction}-{pose}.png' for pose in POSES for direction in range(8)]
    call('montage', *files, '-filter', 'point', '-thumbnail', '128x86!',
         '-tile', '8x6', '-geometry', '128x86+3+3', '-background', '#383238',
         ROOT / (family + '-contact-sheet.png'))

for background, color in (('dark', '#241b21'), ('light', '#b89a77')):
    files = [ROOT / family / f'{family}-dir-{direction}-{pose}.png'
             for family in ('hookrunner', 'soot-bellower') for pose in POSES for direction in range(8)]
    call('montage', *files, '-filter', 'point', '-thumbnail', '48x32!',
         '-tile', '8x12', '-geometry', '48x32+4+4', '-background', color,
         ROOT / f'tactical-32-{background}.png')
    call('montage', *files, '-filter', 'point', '-thumbnail', '72x48!',
         '-tile', '8x12', '-geometry', '72x48+4+4', '-background', color,
         ROOT / f'tactical-48-{background}.png')
    call('montage', *files, '-filter', 'point', '-thumbnail', '96x64!',
         '-tile', '8x12', '-geometry', '96x64+4+4', '-background', color,
         ROOT / f'tactical-64-{background}.png')

(ROOT / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
print(f"Wrote {len(manifest['frames'])} grounded RGBA PNG/BMP frame pairs and eight contact sheets.")
