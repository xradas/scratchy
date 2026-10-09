from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
ROOT=Path(__file__).resolve().parent
OUT=ROOT/'review'; OUT.mkdir(exist_ok=True)
try:
    FONT=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',16)
    TITLE=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',21)
except OSError:
    FONT=TITLE=ImageFont.load_default()
def sheet(filename,labels,title):
    board=Image.new('RGB',(1600,464),(15,21,26));d=ImageDraw.Draw(board)
    d.text((16,10),title,font=TITLE,fill=(211,220,217))
    for row,kind in enumerate(['unsealed','vessel']):
        for col,(suffix,label) in enumerate(labels):
            im=Image.open(ROOT/'renders'/f'{kind}_{suffix}.png').convert('RGB')
            im=im.resize((320,180),Image.Resampling.LANCZOS)
            x,y=col*320,48+row*208
            board.paste(im,(x,y));d.text((x+10,y+183),f'{kind.title()} · {label}',font=FONT,fill=(180,197,191))
    board.save(OUT/filename)
sheet('poses.png',[(x,x.title()) for x in ['chase','windup','recovery','pain','dead']], 'Original live 3D mesh study · state poses · source frames 640×360')
sheet('angles.png',[(f'angle_{x}',f'{x}°') for x in [0,45,90,135,180]], 'Original live 3D mesh study · five views · forward −Z')
board=Image.new('RGB',(1280,408),(15,21,26));d=ImageDraw.Draw(board);d.text((16,10),'Gameplay distance check · 6m · each capture 640×360',font=TITLE,fill=(211,220,217))
for i,kind in enumerate(['unsealed','vessel']):
    board.paste(Image.open(ROOT/'renders'/f'{kind}_game_scale_6m.png').convert('RGB'),(640*i,48))
board.save(OUT/'distance.png')
