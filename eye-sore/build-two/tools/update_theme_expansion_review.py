#!/usr/bin/env python3
"""Copy unchanged review media and produce a source/reference/native review page."""
from pathlib import Path
import json,hashlib,html,shutil
P=Path(__file__).resolve().parents[1]
C=P/'concepts';D=C/'expansion-v1/media';D.mkdir(parents=True,exist_ok=True)
records=[]
def copy(source,name):
 target=D/name;shutil.copyfile(source,target)
 digest=hashlib.sha256(source.read_bytes()).hexdigest();assert digest==hashlib.sha256(target.read_bytes()).hexdigest()
 records.append({'source':str(source.relative_to(P)),'review':'concepts/expansion-v1/media/'+name,'sha256':digest,'byte_original':True})
 return 'expansion-v1/media/'+name
def image(source,name,caption):
 url=copy(source,name)
 return '<figure><a href="'+url+'"><img loading="lazy" src="'+url+'" alt="'+html.escape(caption)+'"></a><figcaption>'+html.escape(caption)+'</figcaption></figure>'
stages=json.loads((P/'resources/stages/catalog.json').read_text())['stages']
refids=dict(pale_ward='corrupted-biotech',ash_citadel='occult-fortress',occupied_line='civic-invasion')
parts=['<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Eyesore — themed stages</title><style>body{background:#0d1213;color:#dce3df;font:16px system-ui;max-width:1180px;margin:30px auto;padding:0 18px}a{color:#bbdc8b}h1{font-size:27px}h2{margin-top:48px}figure{margin:0 0 18px}img{width:100%;height:auto;image-rendering:pixelated;background:#182021;border:1px solid #3a4842}figcaption{color:#b8c4bd;padding:8px 0}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(290px,1fr));gap:18px}.atlas img{max-height:580px;object-fit:contain}audio{width:100%}.note{color:#b6c1bc}nav{display:flex;gap:20px;flex-wrap:wrap}</style><h1>Eyesore — three separate themed stages</h1><p>Original concept references and actual native game renders. Choose each stage independently from the menu; chapter placement is deferred.</p><p class="note">Each stage has 19 rooms, three arena controls, two key returns, two shortcuts, four side rooms and two optional secrets. Normal-ammo automated routes complete without secrets. Human pacing, full directional animation and visual/listening acceptance remain open.</p><nav>']
parts.extend('<a href="#'+s['id']+'">'+html.escape(s['title'])+'</a>' for s in stages);parts.append('</nav>')
for s in stages:
 k=s['id'];parts.append('<section id="'+k+'"><h2>'+html.escape(s['title'])+'</h2><p>'+html.escape(', '.join(x.title() for x in s['enemy_kinds']))+'</p><div class="grid">')
 parts.append(image(C/'visual-v2'/refids[k]/'scene_pixel_preview.png',k+'-reference.png','Original approved concept composition — static artwork'))
 native=P/'verification/expansion-v1/stages/native'/f'{k}-entry.png'
 if native.exists():parts.append(image(native,k+'-entry.png','Actual main game — entry, normal route recording'))
 elif k=='pale_ward':parts.append(image(P/'verification/expansion-v1/main/ward-stair-gameplay.png',k+'-entry.png','Actual main game — entry smoke capture'))
 parts.append('</div><div class="grid">')
 for f in sorted((P/'verification/expansion-v1/stages/native').glob(k+'-*.png')):
  if f==native:continue
  parts.append(image(f,f.name,'Actual main game — '+f.stem.removeprefix(k+'-')))
 parts.append('</div><p class="note">Controlled art views below use the actual game renderer and assets. Camera placement is scripted and AI/player physics are frozen for comparison; these are separate from the ordinary route captures above.</p><div class="grid">')
 for f in sorted((P/'verification/expansion-v1/art').glob(k+'-*.png')):
  if 'world' in f.stem: continue
  parts.append(image(f,k+'-controlled-'+f.name.removeprefix(k+'-'),'Controlled native art view — '+f.stem.removeprefix(k+'-')+'; frozen AI and player physics'))
 parts.append('</div><div class="grid atlas">')
 for enemy in s['enemy_kinds']:
  source=P/'assets/enemies/expansion-v1'/f'{enemy}-atlas.png'
  if source.exists():parts.append(image(source,enemy+'-atlas.png',enemy.title()+' — unchanged generated source, reviewed native pose regions'))
 parts.append(image(P/'verification/expansion-v1/gore/full-art/gallery'/f'{k}-settled-native.png',k+'-gore-native.png','Native settled fragment gallery — isolated verification scene'))
 parts.append('</div><div class="grid">')
 for enemy in s['enemy_kinds']:
  for role in ['attack_warning','hurt','death']:
   source=P/'assets/audio'/('demonic-v1' if enemy in ['unsealed','vessel'] else 'demonic-v2')/f'{enemy}_{role}.ogg'
   url=copy(source,source.name)
   parts.append('<div><p>'+html.escape(enemy.title()+' '+role.replace('_',' '))+'</p><audio controls preload="none" src="'+url+'"></audio></div>')
 parts.append('</div></section>')
parts.append('<p><a href="index.html">Original concept packets</a> · <a href="demonic-aim-review.html">Preserved aiming/voice review</a></p><script>document.addEventListener("play",e=>{if(e.target.tagName==="AUDIO")document.querySelectorAll("audio").forEach(a=>{if(a!==e.target)a.pause()})},true)</script></html>')
(C/'theme-expansion-review.html').write_text(''.join(parts))
(C/'expansion-v1/review-media.json').write_text(json.dumps({'mode':'Byte-copy only; native render and original source/ref PNGs stay unmodified. No raster edits.','files':records},indent=2)+'\n')
print('THEME_REVIEW_BUILT',len(records),'unchanged media files')
