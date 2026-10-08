#!/usr/bin/env python3
"""Presentation-only crop and nearest resize of retained original generated boards.
No compositing, repainting, alpha extraction, color reduction, or AI generation.
Requires Pillow. Run after all three board.png files exist.
"""
from pathlib import Path
from PIL import Image
import json,hashlib
ROOT=Path(__file__).resolve().parent
CONCEPTS=[
 {'slug':'corrupted-biotech','title':'01 / THE PALE WARD','subtitle':'Corrupted biotech facility','tag':'Sterile geometry. Flesh without permission.',
  'crop':[320,40,1280,580],'palette_points':[[1190+44*k,933] for k in range(8)],
  'palette_names':['Ceramic bone','Dark steel','Steel gray','Deep teal','Bruised red','Culture shadow','Culture yellow','Clotted brown'],
  'read':'The Unsealed has a substantial pursuing body, long gripping forearms and a reaching stride. The Vessel has a much broader grounded mass and an exposed spore sac/nozzle that identifies ranged pressure. Raised central stairs and a side branch establish distinct depth planes.',
  'cost':'High. Sculpted anatomy and containment hardware would need original models or deeply shaded hand-painted sprites, followed by deliberate animation and game-scale cleanup. Modular ceramic/steel architecture can share a restrained texture set.',
  'limitation':'This board leans toward detailed contemporary rendered horror more than the classic digitized finish. The 16:9 scene crop preserves both threats and forward gun but shifts the original crosshair slightly left. The scene creature representation and close-up study are approximate rather than locked model geometry.',
  'melee':'Unsealed','ranged':'Vessel','default_image':'/home/rikki/.codex/generated_images/01a11da1-7243-7f12-baa9-dbf4f20b7017/exec-4d3dc1d3-64f9-4371-80e8-05c2c1cf5d4f.png'},
 {'slug':'occult-fortress','title':'02 / THE ASH CITADEL','subtitle':'War-torn occult fortress','tag':'A siege that became a sacrament.',
  'crop':[208,56,1328,686],'palette_points':[[1270,951],[1308,951],[1341,951],[1374,951],[1406,951],[1438,951],[1470,951],[1502,951]],
  'palette_names':['Coal','Slate purple','Stone gray','Dust mortar','Chalk bone','Oxblood','Ember','Ritual gold'],
  'read':'Ironbound is tall, heavily armored and carries a clearly readable cleaver for close-range pressure. Censer spreads a low four-legged mass under an ossuary shell, with an ember mouth identifying ranged fire. Stair fronts, parapets and the descending side gate make the room three-dimensional.',
  'cost':'Medium-high. Armor and masonry can be modular, but the large cleaver attack and four-legged creature need planned weight transfer and consistent shaded poses. A modeled render-to-sprite pipeline would need careful low-resolution cleanup.',
  'limitation':'The generator added a few static alternate-view creature studies rather than only one pose; these are not a complete animation or rotation set. Small details and exact limb geometry vary between the scene and studies. Material samples are illustrative and not proven seamless.',
  'melee':'Ironbound','ranged':'Censer','default_image':'/home/rikki/.codex/generated_images/01a11da1-7243-7f12-baa9-dbf4f20b7017/exec-8e1346e1-2b76-489e-bf39-c40a4d91cc48.png'},
 {'slug':'civic-invasion','title':'03 / THE OCCUPIED LINE','subtitle':'Invaded civic megastructure','tag':'Public space. Private extinction.',
  'crop':[316,76,1276,616],'palette_points':[[1197,950],[1240,950],[1283,950],[1327,950],[1372,950],[1416,950],[1458,950],[1500,950]],
  'palette_names':['Transit night','Service blue','Concrete shadow','Weathered concrete','Wayfinding ivory','Alien violet','Caution orange','Scanner cyan'],
  'read':'Reaver uses powerful legs, low skull and a fused cutting arm for close pursuit. Surveyor raises a sensor crown above a weighted three-point stance; cyan organs convey ranged aiming. Thick concrete members, ticket gates and level changes establish the public-space scale.',
  'cost':'Medium-high. Concrete and transit materials are reusable. Reaver attack articulation and Surveyor’s tripod locomotion require deliberate original production assets and shaded animation studies.',
  'limitation':'This generated concept is not an importable sprite set or a runtime scene. Creature anatomy and gun construction must be locked in a later model/paint pass. Surface swatches have not been tested for tiling. The central16:9 export omits the left-positioned HUD and crops the near blade at the left boundary; the untouched board preserves both. The original crosshair shifts slightly left in this export.',
  'melee':'Reaver','ranged':'Surveyor','default_image':'/home/rikki/.codex/generated_images/01a11da1-7243-7f12-baa9-dbf4f20b7017/exec-82b16ce6-4990-4e20-9767-cdf630c34f8d.png'}
]
def hexval(rgb): return '#'+''.join(f'{x:02X}' for x in rgb[:3])
def main():
 manifest={'project':'Eyesore — rebuilt visual directions','stage':'Identity selection; no identity selected','revision':'visual-v2','art_provenance':{'method':'Built-in image_gen.imagegen generated 3D-volume concept studies. Prompt-directed original designs; no old concept or Doom asset image inputs.','hand_authored_pixel_art':False,'production_pixel_art_animation':'Pending identity selection; none created in this revision.','tool':'image_gen.imagegen','input_image_count':0,'prompt_source':'Each concept directory/prompt.txt','export_source':'export_review.py','export_transform':'Documented board crop; nearest resample to 640x360. Separate 320x180 nearest then 2x preview. Original board retained byte-for-byte. No recoloring or repainting.','structural_reference':'https://store.steampowered.com/app/2280/DOOM__DOOM_II/','structural_reference_use':'Room depth, riser faces, digitized sprite volume and threat mass; no copied assets.','audio':'Unchanged; this directory contains no audio edits.'},'concepts':[]}
 verification=[]
 for c in CONCEPTS:
  folder=ROOT/c['slug']; board=Image.open(folder/'board.png').convert('RGB'); assert board.size==(1536,1024)
  crop=board.crop(tuple(c['crop'])); crop.resize((640,360),Image.Resampling.NEAREST).save(folder/'scene.png')
  native=crop.resize((320,180),Image.Resampling.NEAREST); native.save(folder/'scene_preview_native.png'); native.resize((640,360),Image.Resampling.NEAREST).save(folder/'scene_pixel_preview.png')
  colors=[{'name':name,'hex':hexval(board.getpixel(tuple(pt))),'sampling_point':pt} for name,pt in zip(c['palette_names'],c['palette_points'])]
  (folder/'palette.json').write_text(json.dumps(colors,indent=2)+'\n')
  out={k:c[k] for k in ['slug','title','subtitle','tag','read','cost','limitation']}
  out.update({'palette':colors,'board':f"{c['slug']}/board.png",'scene':f"{c['slug']}/scene.png",'scene_pixel_preview':f"{c['slug']}/scene_pixel_preview.png",'scene_native':f"{c['slug']}/scene_preview_native.png",'scene_crop_rectangle':c['crop'],'prompt':f"{c['slug']}/prompt.txt",'threats':{'melee':c['melee'],'ranged':c['ranged']},'production_sprites':False,'tileable_materials':False,'palette_is_reference_not_ink_limit':True})
  manifest['concepts'].append(out)
  meta={'tool':'image_gen.imagegen','mode':'built-in generation','transparent_background':False,'referenced_images':[],'requested_board_size':[1536,1024],'actual_board_size':list(board.size),'default_output_path':c['default_image'],'saved_board':out['board'],'prompt_file':out['prompt'],'sha256_original_board':hashlib.sha256((folder/'board.png').read_bytes()).hexdigest(),'export_crop':c['crop'],'not_hand_authored':True,'production_ready':False}
  (folder/'generation.json').write_text(json.dumps(meta,indent=2)+'\n')
  verification.append({'slug':c['slug'],'board_size':list(board.size),'scene_size':list(Image.open(folder/'scene.png').size),'preview_size':list(Image.open(folder/'scene_pixel_preview.png').size),'native_preview_size':list(native.size),'original_board_retained':True,'scene_mode':'RGB','scene_alpha':'None; concept illustration, not transparent sprite','export_only':True,'scene_colors':len(Image.open(folder/'scene.png').getcolors(maxcolors=640*360) or []),'crop_rectangle':c['crop']})
 (ROOT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n'); (ROOT/'verification.json').write_text(json.dumps(verification,indent=2)+'\n')
 print('Exported 3 untouched boards, 3 scene640 exports, 3 pixel previews and 3 native previews. Manifest and provenance recorded.')
if __name__=='__main__': main()
