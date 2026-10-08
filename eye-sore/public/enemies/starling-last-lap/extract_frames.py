#!/usr/bin/env python3
"""Format authored sheets into grounded RGBA sprites; no inferred animation.

ImageMagick performs only import/crop, shared nearest scale and canvas placement.
The six authored rows stay six authored poses. No per-frame body enlargement.
"""
from pathlib import Path
import json
import subprocess

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
        'bbox': [min(p % width for p in solid), min(p // width for p in solid),
                 max(p % width for p in solid) + 1, max(p // width for p in solid) + 1],
        'opaque_near_black_pixels': sum(pixels[i + 3] >= 128 and max(pixels[i:i + 3]) < 12
                                        for i in range(0, len(pixels), 4)),
    }

manifest = {
    'title': "Starling's Last Lap", 'production': 'original authored sprite keys, built-in image_gen',
    'canvas_pixels': [384, 256], 'render_canvas_aspect': 1.5,
    'pivot_engine_bottom_origin': [0.5, 0.0], 'ground_pixel': 255,
    'direction_order': list(DIRS), 'pose_order': list(POSES),
    'filter': 'nearest', 'alpha': 'binary cutout from source alpha threshold 128; never RGB black-key',
    'frames': [],
}

for family in ('lap-counter', 'bumper-hound'):
    source = ROOT / 'sources' / (family + '-source.png')
    width, height = map(int, call('identify', '-format', '%w %h', source).split())
    assert width % 8 == 0 and height % 6 == 0, 'Source must have integer eight-by-six cells'
    cell_w, cell_h = width // 8, height // 6
    assert cell_w == cell_h, 'Shared square import cell required'
    folder = ROOT / family
    folder.mkdir(exist_ok=True)
    for pose_index, pose in enumerate(POSES):
        for direction, name in enumerate(DIRS):
            crop = f'{cell_w}x{cell_h}+{direction * cell_w}+{pose_index * cell_h}'
            pixels = call(source, '-crop', crop, '+repage', '-depth', '8', 'rgba:-')
            ys = [i // 4 // cell_w for i in range(0, len(pixels), 4) if pixels[i + 3] >= 128]
            assert ys, (family, pose, direction, 'Empty authored cell')
            shift = cell_h - 1 - max(ys)
            stem = f'{family}-dir-{direction}-{pose}'
            png = folder / (stem + '.png')
            bmp = folder / (stem + '.bmp')
            call(source, '-crop', crop, '+repage', '-channel', 'A', '-threshold', '50%', '+channel',
                 '-roll', f'+0+{shift}', '-filter', 'point', '-resize', '256x256!',
                 '-background', 'none', '-gravity', 'center', '-extent', '384x256',
                 '-background', 'black', '-alpha', 'background', '-strip',
                 '-define', 'png:color-type=6', png)
            call(png, '-define', 'bmp:format=bmp4', '-type', 'TrueColorAlpha', bmp)
            info = metrics(png)
            assert info['alpha_min'] == 0 and info['alpha_max'] == 255
            assert info['bbox'][3] == 256, (stem, 'Ground alignment')
            assert call(png, '-depth', '8', 'rgba:-') == call(bmp, '-depth', '8', 'rgba:-'), (stem, 'BMP alpha/color mismatch')
            manifest['frames'].append({
                'family': family, 'direction': direction, 'direction_name': name,
                'pose': pose, 'pose_index': pose_index,
                'png': str(png.relative_to(ROOT)), 'bmp': str(bmp.relative_to(ROOT)),
                'source_cell': [direction, pose_index], 'source_y_offset': shift,
                **info,
            })
    files = [folder / f'{family}-dir-{direction}-{pose}.png' for pose in POSES for direction in range(8)]
    call('montage', *files, '-filter', 'point', '-thumbnail', '128x86!',
         '-tile', '8x6', '-geometry', '128x86+3+3', '-background', '#393a45',
         ROOT / (family + '-contact-sheet.png'))

for background, color in (('dark', '#292536'), ('light', '#cebdad')):
    files = [ROOT / family / f'{family}-dir-{direction}-{pose}.png'
             for family in ('lap-counter', 'bumper-hound') for pose in POSES for direction in range(8)]
    call('montage', *files, '-filter', 'point', '-thumbnail', '48x32!',
         '-tile', '8x12', '-geometry', '48x32+4+4', '-background', color,
         ROOT / f'tactical-32-{background}.png')
    call('montage', *files, '-filter', 'point', '-thumbnail', '96x64!',
         '-tile', '8x12', '-geometry', '96x64+4+4', '-background', color,
         ROOT / f'tactical-64-{background}.png')

(ROOT / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
print(f"Wrote {len(manifest['frames'])} grounded RGBA PNG/BMP frame pairs and six contact sheets.")
