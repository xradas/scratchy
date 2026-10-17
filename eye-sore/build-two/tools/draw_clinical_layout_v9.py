#!/usr/bin/env python3
"""Measured vector review plan; not a game screenshot or shipped artwork."""
import html
import json
from pathlib import Path
import room_program_v6 as rooms
import clinical_layout_v9 as clinical

ROOT=Path(__file__).resolve().parents[1]
plan=clinical.load_layout()
out=ROOT/'verification/production-v9/clinical/layout-overview.svg'
svg=['<svg xmlns="http://www.w3.org/2000/svg" width="1440" height="1050" viewBox="0 0 1440 1050">',
     '<rect width="1440" height="1050" fill="#101b20"/>',
     '<g font-family="DejaVu Sans, sans-serif" fill="#e1e8df">',
     '<text x="30" y="34" font-size="24">INTAKE v9 · 23 existing clinical fittings · six-room measured placement plan</text>',
     '<text x="30" y="59" font-size="13">True dimensions; local X right / north (-Z) up. Green = capsule-proved passages. Architecture omitted here; native proof includes it.</text>']
index=0
for panel,room in enumerate(plan['rooms']):
    px=22+(panel%3)*475;py=82+(panel//3)*480
    svg.append(f'<rect x="{px}" y="{py}" width="462" height="464" rx="8" fill="#1a2a30" stroke="#43585c"/>')
    title=room['id'].replace('_',' ').upper()
    svg.append(f'<text x="{px+16}" y="{py+27}" font-size="18">{title} · {room["size"][0]}×{room["size"][2]} m</text>')
    sx,_,sz=room['size'];scale=min(400/sx,282/sz)
    ox=px+231-sx*scale/2;oz=py+54+(282-sz*scale)/2
    def point(x,z):return ox+(x+sx/2)*scale,oz+(z+sz/2)*scale
    svg.append(f'<rect x="{ox}" y="{oz}" width="{sx*scale}" height="{sz*scale}" fill="#27383e" stroke="#a5b7ac" stroke-width="2"/>')
    for path in room['passages']:
        points=' '.join(f'{point(x,z)[0]:.2f},{point(x,z)[1]:.2f}' for x,z in path['points_local_xz'])
        svg.append(f'<polyline points="{points}" fill="none" stroke="#52a582" stroke-opacity=".6" stroke-width="{path["minimum_clear_width_m"]*scale}" stroke-linejoin="round"/>')
    labels=[]
    for group in room['groups']:
        _,w,d,_=rooms.SHAPES[group['type']]
        for ordinal,(x,z,heading) in enumerate(group['authored_positions'],1):
            index+=1;rw,rd=(d,w) if abs(heading)==90 else (w,d);cx,cz=point(x,z)
            color='#dbba72' if group['type'] in ('medical_bed','surgical_table') else '#8cb5c3'
            svg.append(f'<rect x="{cx-rw*scale/2}" y="{cz-rd*scale/2}" width="{rw*scale}" height="{rd*scale}" fill="{color}" stroke="#0b1418" stroke-width="1"/>')
            # A numbered pin is readable at ordinary review scale; labels below
            # preserve identity without painting text into production assets.
            pin_x,pin_y=cx,cz
            if room['id']=='arena_one':
                pin_x=ox-22 if x<0 else ox+sx*scale+22
                order={-16.3:0,-14.6:1,-12.9:2,-11.75:3}
                pin_y=oz+14+order[z]*22
                svg.append(f'<path d="M {cx},{cz} L {pin_x},{pin_y}" stroke="{color}" fill="none"/>')
            svg.append(f'<circle cx="{pin_x}" cy="{pin_y}" r="9" fill="#101b20" stroke="{color}"/><text x="{pin_x}" y="{pin_y+3.5}" font-size="9" text-anchor="middle">{index:02}</text>')
            labels.append(f'{index:02} {group["type"].replace("_"," ")} #{ordinal}')
    for n,label in enumerate(labels):
        x=px+16+(n%2)*223;y=py+365+(n//2)*21
        svg.append(f'<text x="{x}" y="{y}" font-size="12">{html.escape(label)}</text>')
svg+=['<text x="30" y="1030" font-size="13">Triage: two mirrored banks at 3.4 m bed pitch; one monitor/screen station per pair. No inventory, pickup, enemy or progression additions.</text>','</g></svg>']
assert index==23
out.write_text('\n'.join(svg)+'\n')
print(out)
