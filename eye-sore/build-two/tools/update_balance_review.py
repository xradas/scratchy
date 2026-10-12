#!/usr/bin/env python3
"""Refresh the local budget/native-picture review. PNGs are referenced unchanged."""
import hashlib
import html
import json
from pathlib import Path
import re
import subprocess
import shutil
ROOT=Path(__file__).resolve().parents[1]
COMMIT='6d3dc8b5b984ec3acb9809bbf32e8c65afbbedb5'
POOLS={'pistol':'pistol','shells':'shells','rivets':'rivets','rockets':'rockets','twin_shotgun':'shells','rivet_cannon':'rivets','siege_launcher':'rockets'}
GUNS=['pistol','shotgun','melee','twin_shotgun','rivet_cannon','siege_launcher']

def main():
    budget=json.loads((ROOT/'resources/campaign/balance-budget.json').read_text())
    captures=json.loads((ROOT/'verification/combat-balance-v4/art/captures.json').read_text())
    rows=[];oldtotals={}
    current_budget_sha256=hashlib.sha256((ROOT/'resources/campaign/balance-budget.json').read_bytes()).hexdigest()
    cohort_matches=captures['budget_sha256']==current_budget_sha256 and all(hashlib.sha256((ROOT/c['scene'].removeprefix('res://')).read_bytes()).hexdigest()==c['scene_sha256'] for c in captures['captures'])
    cohort_label='Current-budget controlled HUD/presentation fixture: native budget and captured scene hashes match the frozen source.' if cohort_matches else 'Before-final-budget HUD/presentation fixture: captured scene or budget hashes differ from current source.'
    for level in budget['levels']:
        path='eye-sore/build-two/scenes/campaign/'+level['id']+'.tscn'
        old=subprocess.check_output(['git','show',COMMIT+':'+path],cwd=ROOT).decode()
        amounts={k:0 for k in ['pistol','shells','rivets','rockets']}
        for name,body in re.findall(r'^\[node name="([^"]+)"[^\n]*\]\n(.*?)(?=^\[node|\Z)',old,re.M|re.S):
            if not(name.startswith(('Supply_','Bait_')) or name=='FirstGunCache'):continue
            if name.startswith('Supply_') and name.endswith('_return_store'):continue
            kind=re.search(r'^metadata/stage_pickup = "([^"]+)"$',body,re.M);amount=re.search(r'^metadata/amount = (\d+)$',body,re.M)
            if kind and amount and kind[1] in POOLS:amounts[POOLS[kind[1]]]+=int(amount[1])
        oldtotals[level['id']]=amounts
        cells=''.join('<td><span class="before">'+str(amounts[k])+'</span> → <strong>'+str(level['main_route_actual'][k])+'</strong></td>' for k in amounts)
        rows.append('<tr><th>'+html.escape(level['id'].replace('_',' ').title())+'</th>'+cells+'</tr>')
    image_choices=[]
    review_root=ROOT/'concepts/combat-balance-v4/review'
    review_root.mkdir(parents=True,exist_ok=True)
    copied=[]
    for c in captures['captures']:
        path=ROOT/c['window_png'].removeprefix('res://')
        assert hashlib.sha256(path.read_bytes()).hexdigest()==c['window_sha256']
        target=review_root/path.name
        shutil.copyfile(path,target)
        assert hashlib.sha256(target.read_bytes()).hexdigest()==c['window_sha256']
        copied.append({'file':target.name,'source':c['window_png'],'sha256':c['window_sha256'],'processing':'Byte-identical copy; no resizing or image edits.'})
        image_choices.append({'label':c['level'].replace('_',' ').title()+' · '+c['label'].replace('_',' '),'src':'combat-balance-v4/review/'+path.name,'fixture':c['fixture'],'hud':c['hud_text'],'sha256':c['window_sha256']})
    page='''<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Eyesore · Campaign balance review</title>
<style>body{background:#111517;color:#dde0db;font:16px/1.5 system-ui;margin:0 auto;padding:32px;max-width:1150px}h1{color:#e5c98a}p{max-width:90ch}table{border-collapse:collapse;width:100%;margin:24px 0}td,th{padding:10px;border-bottom:1px solid #394141;text-align:left}.before{color:#99a3a1}strong{color:#e5c98a}select{background:#21282a;color:#eef1ed;padding:10px;max-width:100%;margin:16px 0}img{width:100%;height:auto;image-rendering:pixelated;border:1px solid #394141}.scope{border-left:3px solid #e5c98a;padding-left:16px}.hash{font-size:12px;overflow-wrap:anywhere;color:#929e98}</style>
<h1>Campaign ammunition balance</h1><p>Carrying limits: <strong>96 pistol · 40 shells · 160 rivets · 12 rockets.</strong> Ordinary full-ammo cases remain available. A full, owned weapon bait still triggers its arena. Partial pickups report the ammunition actually accepted.</p>
<p class="scope">COHORT_LABEL These images show actual Main with controlled cameras, frozen actors, and a declared owned carry fixture. Shots use the accepted native event path. They are HUD/pickup presentation evidence, not ordinary combat, route completion or human pacing/listening approval. The current table and final source/archive audit receipts remain separate from this controlled image cohort and genuine exported gameplay evidence.</p>
<h2>Main-route placed ammunition</h2><p>Previous scene-source totals at preserved release 6d3dc8b → current authored totals. Optional and secret supplies, return-store supplies, and starting inventory are excluded in both columns. Actual loaded-scene totals are checked independently by Godot.</p>
<table><thead><tr><th>Level</th><th>Pistol</th><th>Shells</th><th>Rivets</th><th>Rockets</th></tr></thead><tbody>ROWS</tbody></table>
<h2>Native HUD and pickup views</h2><select id="view" aria-label="Choose native capture"></select><p id="fixture"></p><img id="picture" alt="Actual controlled Main screenshot"><p id="hud"></p><p class="hash" id="hash"></p>
<script>const captures=IMAGES;const sel=document.getElementById('view');captures.forEach((c,i)=>{let o=document.createElement('option');o.value=i;o.textContent=c.label;sel.append(o)});function show(){let c=captures[Number(sel.value)];document.getElementById('picture').src=c.src;document.getElementById('fixture').textContent=c.fixture;document.getElementById('hud').textContent=c.hud;document.getElementById('hash').textContent='Byte-original captured PNG · SHA-256 '+c.sha256}sel.onchange=show;show();</script>'''
    page=page.replace('COHORT_LABEL',html.escape(cohort_label)).replace('ROWS',''.join(rows)).replace('IMAGES',json.dumps(image_choices).replace('</','<\\/'))
    (ROOT/'concepts/balance-review.html').write_text(page)
    (review_root/'manifest.json').write_text(json.dumps({'scope':cohort_label+' Controlled fixtures, no native combat claim. Current table and final audits are separate. Outside package provenance roots.','files':copied},indent=2)+'\n')
    out=ROOT/'verification/combat-balance-v4/art/budget-comparison.json';out.write_text(json.dumps({'prior_commit':COMMIT,'prior_main_source_totals':oldtotals,'current_budget_sha256':hashlib.sha256((ROOT/'resources/campaign/balance-budget.json').read_bytes()).hexdigest(),'scope':'Prior source-text sums exclude return_store and optional/secret bonuses consistently with the current budget; current actual native-node totals validated by independent Godot balance audit. PNGs referenced without editing.'},indent=2)+'\n')
    print('BALANCE_REVIEW_OK',len(rows),'budget rows',len(image_choices),'native views')

if __name__=='__main__':main()
