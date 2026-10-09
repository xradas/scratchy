from PIL import Image
from pathlib import Path
import json,hashlib
ROOT=Path(__file__).resolve().parent
STATES=['idle','walk_left','walk_right','windup','recovery','pain','death','corpse']
for kind in ['unsealed','vessel']:
    p=ROOT/kind/'atlas.png';im=Image.open(p);a=im.getchannel('A');w,h=im.size;cw,ch=w//4,h//2;hist=a.histogram();cells=[]
    for i in range(8):
        tile=a.crop(((i%4)*cw,(i//4)*ch,(i%4+1)*cw,(i//4+1)*ch))
        b=tile.point(lambda x:255 if x>=32 else 0).getbbox();opaque=tile.point(lambda x:255 if x>=128 else 0).getbbox()
        edge=[sum(1 for v in tile.crop(rect).get_flattened_data() if v>=32) for rect in [(0,0,2,ch),(cw-2,0,cw,ch),(0,0,cw,2),(0,ch-2,cw,ch)]]
        cells.append({'index':i,'state':STATES[i],'region':[i%4*cw,i//4*ch,cw,ch],'alpha_bounds_threshold32':b,'alpha_bounds_threshold128':opaque,'foot_pivot':[cw//2,opaque[3]-1],'offset_to_anchor_192_471':[0,471-(opaque[3]-1)],'edge_alpha_counts_lr_tb':edge})
    report={'width':w,'height':h,'mode':im.mode,'columns':4,'rows':2,'cell_size':[cw,ch],'alpha_range':a.getextrema(),'alpha_zero_pixels':hist[0],'alpha_ge200_pixels':sum(hist[200:]),'total_pixels':w*h,'cells':cells,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'no_bitmap_transform':True}
    (ROOT/kind/'inspection-final.json').write_text(json.dumps(report,indent=2)+'\n');print(kind,json.dumps(report))
