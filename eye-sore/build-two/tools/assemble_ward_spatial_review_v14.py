#!/usr/bin/env python3
"""Copy exact fresh Main captures into a v14 review; preserve v13 evidence."""
from pathlib import Path
import argparse, hashlib, html, json, shutil
P=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 a=argparse.ArgumentParser();a.add_argument('captures',type=Path);args=a.parse_args()
 out=P/'concepts/ward-spatial-v14';out.mkdir(parents=True,exist_ok=True)
 sections=[];manifest=[]
 names={'pale_ward_01':'Intake','pale_ward_02':'Containment','pale_ward_03':'Breach'}
 for level,title in names.items():
  source=args.captures/level;receipt=json.loads((source/'capture.json').read_text())
  assert receipt['level']==level
  assert receipt['scene_sha256']==sha(P/f'scenes/campaign/{level}.tscn')
  for field,path in [('stage_script_sha256','scripts/stage_level.gd'),('checkpoint_script_sha256','scripts/stage_checkpoint_v13.gd'),('hud_script_sha256','scripts/industrial_hud_v8.gd')]:assert receipt[field]==sha(P/path)
  target=out/level;target.mkdir(exist_ok=True)
  cards=[]
  for item in receipt['captures']:
   filename=item['name']+'.png';assert sha(source/filename)==item['png_sha256']
   shutil.copy2(source/filename,target/filename)
   cards.append(f'<figure><a href="{level}/{filename}"><img src="{level}/{filename}" alt="{html.escape(item["name"])}"></a><figcaption>{html.escape(item["name"].replace("-"," "))}</figcaption></figure>')
  shutil.copy2(source/'capture.json',target/'capture.json');manifest.append(receipt)
  sections.append(f'<section><h2>{title}</h2><p><a href="{level}.svg">Authored footprint plan</a> · <a href="{level}/capture.json">Exact capture receipt</a></p><div class="grid">'+''.join(cards)+'</div></section>')
 document='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Eyesore · Ward spatial pass v14</title><style>body{max-width:1400px;margin:32px auto;padding:0 20px;background:#0c1213;color:#e0e6df;font:17px/1.5 system-ui}a{color:#c3df83}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(420px,1fr));gap:16px}figure{margin:0;background:#182022;border:1px solid #38463d}img{display:block;width:100%;image-rendering:pixelated}figcaption{padding:10px;text-transform:capitalize}section{margin-top:42px}p{max-width:1050px}</style><h1>The Pale Ward · spatial pass v14</h1><p>Nine shaped rooms, three broader shared connections and three optional shell-reserve ambushes. Existing objectives, main-route supplies, enemy totals, weapons and music stay steady.</p><p>These are unedited pixels from the actual game with fixed cameras and frozen actors. Reserve-open views accept the real pickup through its normal collection method and await the physical door. They are controlled previews, not played routes or approval of the concept match. Separate checks cover movement, collision, combat and campaign progression.</p>'''+''.join(sections)+'</html>\n'
 (out/'index.html').write_text(document);(out/'manifest.json').write_text(json.dumps({'captures':manifest,'scope':'Unedited actual Main controlled views, not concept art or played completion.'},indent=2)+'\n')
 print(out/'index.html')
if __name__=='__main__':main()
