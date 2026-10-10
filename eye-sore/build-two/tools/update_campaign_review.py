#!/usr/bin/env python3
"""Publish byte-original native campaign pictures and authored graph diagrams locally."""
import hashlib
import html
import json
from pathlib import Path
import shutil

PROJECT = Path(__file__).resolve().parents[1]
DEST = PROJECT / 'concepts/campaign-v3/review'
DEST.mkdir(parents=True, exist_ok=True)
records = []

def copy(source):
    destination = DEST / source.name
    shutil.copyfile(source, destination)
    digest = hashlib.sha256(source.read_bytes()).hexdigest()
    assert hashlib.sha256(destination.read_bytes()).hexdigest() == digest
    records.append({'source':str(source.relative_to(PROJECT)), 'file':destination.name, 'sha256':digest})
    return 'campaign-v3/review/' + destination.name

def map_svg(layout):
    rooms = layout['rooms']
    xs = [r['center'][0]+sign*r['size'][0]/2 for r in rooms for sign in (-1,1)]
    zs = [r['center'][2]+sign*r['size'][2]/2 for r in rooms for sign in (-1,1)]
    xmin,zmin = min(xs)-5,min(zs)-5
    drawing = []
    for room in rooms:
        x,_,z=room['center'];w,_,d=room['size']
        color='#45582c' if room['secret'] else ('#82422a' if room.get('arena_id') else '#334953')
        drawing.append(f'<rect x="{x-w/2}" y="{z-d/2}" width="{w}" height="{d}" fill="{color}" stroke="#b4bfad" stroke-width=".6"/><text x="{x}" y="{z}" text-anchor="middle" font-size="2.7" fill="white">{html.escape(room["id"])}</text>')
    return f'<svg role="img" aria-label="Authored room footprints" viewBox="{xmin} {zmin} {max(xs)-xmin+5} {max(zs)-zmin+5}">' + ''.join(drawing)+'</svg>'

chunks=['<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Eyesore — connected campaign</title><style>body{background:#0c1113;color:#e2e4df;font:16px system-ui;margin:24px auto;max-width:1280px;padding:0 16px}a{color:#bdd987}h1,h2{font-weight:600}section{margin:32px 0}article{border:1px solid #3c484a;padding:16px;margin:20px 0;background:#151c20}img{width:100%;image-rendering:pixelated}svg{width:100%;height:260px;background:#0c1113}.grid{display:grid;grid-template-columns:repeat(3,1fr);gap:12px}small{color:#a8b3b3}@media(max-width:720px){.grid{grid-template-columns:1fr}}</style><h1>Eyesore — nine connected levels</h1><p>Three levels each: Pale Ward → Ash Citadel → Occupied Line. Continue carries your loadout; Retry restores the level entry. The original concept compositions remain the art target.</p><p>These are actual native Main views with frozen player/AI and controlled cameras. They show geometry and presentation; they are separate from the continuous real-combat route proof and human playtest.</p><p><a href="index.html#corrupted-biotech">Original concept packets</a> · <a href="campaign-v3/provenance.json">New Rivet provenance and exact prompt</a></p>']
catalog=json.loads((PROJECT/'resources/campaign/catalog.json').read_text())
for chapter in catalog['chapters']:
    chunks.append('<section><h2>'+html.escape(chapter['title'])+'</h2>')
    for level in chapter['levels']:
        layout=json.loads((PROJECT/f'resources/campaign/{level["id"]}-layout.json').read_text())
        chunks.append(f'<article><h3>{html.escape(level["title"])}</h3><p>{html.escape(level["subtitle"])} · {len(layout["rooms"])} rooms</p><div class="grid">')
        for view in ('arrival','arena_one','arena_two'):
            path=copy(PROJECT/f'verification/campaign-v3/captures/{level["id"]}-{view}.png')
            chunks.append(f'<div><a href="{path}"><img loading="lazy" src="{path}" alt="{html.escape(level["title"])} {view}"></a><small>{view.replace("_"," ")}: controlled native view</small></div>')
        chunks.append('</div>'+map_svg(layout)+'<small>Authored room footprints: orange arenas, green secret rooms. This diagram includes unvisited rooms.</small></article>')
    chunks.append('</section>')
chunks.append('<h2>Heavy weapons</h2><p>Signed arrival caches: [4] Twin at Intake, [5] Rivet at Containment, [6] Siege at Breach. Native Main accepted-shot studies below show idle, fire and recovery. The HUD crosshair follows the camera ray; flashes originate at the authored muzzle.</p>')
for gun in ('twin_shotgun','rivet_cannon','siege_launcher'):
    chunks.append(f'<article><h3>{gun.replace("_"," ").title()}</h3><div class="grid">')
    for pose in ('idle','fire','recover'):
        path=copy(PROJECT/f'verification/weapon-alignment-v3/captures/{gun}-{pose}-1280x720.png')
        chunks.append(f'<div><a href="{path}"><img loading="lazy" src="{path}" alt="{gun} {pose}"></a><small>{pose}</small></div>')
    chunks.append('</div></article>')
chunks.append('<p>Music and dry creature/contact cues are preserved. Whole-scene concept fidelity, complete directional animation, human mouse feel, pacing and listening acceptance remain open.</p></html>')
(PROJECT/'concepts/campaign-review.html').write_text('\n'.join(chunks))
(DEST/'manifest.json').write_text(json.dumps({'scope':'Unmodified native PNG copies; authored SVG room diagrams.', 'files':records},indent=2)+'\n')
print('CAMPAIGN_REVIEW_OK',len(records))
