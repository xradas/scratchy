import json,subprocess,struct,shutil,hashlib,statistics
from pathlib import Path
root=Path('/home/rikki/Projects/eyesore-build-two/eye-sore/build-two');out=root/'assets/enemies/staff-v11';out.mkdir(parents=True,exist_ok=True)
base=Path('/home/rikki/.codex/generated_images/01a11d9f-4fdc-7f71-99a7-53b3d07a454d')
manifest=json.loads((root/'assets/combat_art.json').read_text());records={}
for kind,name,desired in [('infected_scientist','exec-3d593fd6-9a81-4c2c-a761-7cc4ed5412da.png',1.78),('infected_security','exec-bd8176b1-43cd-44ec-819a-ce3759d9283a.png',1.82)]:
 source=base/name;dest=out/(kind+'-atlas.png');shutil.copyfile(source,dest);raw=dest.read_bytes();w,h=struct.unpack('>II',raw[16:24]);pixels=subprocess.check_output(['ffmpeg','-v','error','-i',str(dest),'-f','rawvideo','-pix_fmt','rgba','-'])
 opaque=lambda x,y:pixels[(y*w+x)*4+3]>=128
 ys=[0]+[min(range(round(r*h/8)-6,round(r*h/8)+7),key=lambda y:(sum(opaque(x,y)for x in range(w)),abs(y-round(r*h/8))))for r in range(1,8)]+[h]
 xs=[0]+[min(range(round(c*w/8)-32,round(c*w/8)+33),key=lambda x:(sum(opaque(x,y)for y in range(h)),abs(x-round(c*w/8))))for c in range(1,8)]+[w]
 regions={};pivots={};bounds={};material={};muzzles={};heights=[]
 for r in range(8):
  for c in range(8):
   f=r*8+c;x,y=xs[c],ys[r];fw,fh=xs[c+1]-x,ys[r+1]-y
   points=[(xx,yy)for yy in range(fh)for xx in range(fw)if opaque(x+xx,y+yy)];assert points
   bx,by=min(p[0]for p in points),min(p[1]for p in points);ex,ey=max(p[0]for p in points),max(p[1]for p in points)
   regions[str(f)]=[x,y,fw,fh];bounds[str(f)]=[bx,by,ex-bx+1,ey-by+1]
   # Authored source cells have ground contact at their bottom; measured opaque foot line.
   # Fixed cell centre preserves heading/pose root; dead frame centre preserves full horizontal corpse.
   pivots[str(f)]=[round((bx+ex)/2,3) if c==7 else round(fw/2,3),ey+1]
   if c==0:heights.append(ey-by+1)
   if kind=='infected_security':
    # Chest/back plate and helmet are armor; exposed jaw/throat and joints remain flesh.
    material[str(f)]=[{'material':'armor','rect':[.28,.08,.43,.20]},{'material':'armor','polygon':[[.25,.30],[.70,.30],[.77,.61],[.25,.65]]},{'material':'armor','rect':[.20,.65,.16,.20]},{'material':'armor','rect':[.59,.65,.16,.20]}] if c<6 else [{'material':'armor','rect':[.20,.48,.55,.47]}]
    if c==4:material[str(f)].append({'material':'','rect':[.78,0,.22,.56]})
    muzzles[str(f)]=[.74,.31] if r not in [5,6] else [.12,.34]
 size=desired/statistics.median(heights)
 options={'rows':8,'direction_count':8,'source_regions':regions,'frame_pivots':pivots,'hurt_resolution':[96,128],'alpha_threshold':.5,'hurt_material_default':'flesh','precache_frames':True}
 if material:
  options['material_regions']=material;options['frame_projectile_origins_uv']=muzzles
  options['release_pose_seconds']=.075;options['recovery_rest_column']=3
 entry={'file':'res://'+str(dest.relative_to(root)),'columns':8,'directions':8,'clips':{'chase':[0,3],'windup':[3,1],'recovery':[4,1],'pain':[5,1],'dead':[6,2]},'pixel_size':size,'foot_pivot':pivots['0'],'sprite_options':options,'presentation':'Original generated painted pixel staff atlas; eight view rows and eight state columns. Native PNG retained byte-for-byte with explicit integer source regions and measured ground pivots. First pass: some attack views are approximate.','sha256':hashlib.sha256(raw).hexdigest(),'source_dimensions':[w,h]}
 manifest['enemies'][kind]=entry;records[kind]={'source':str(source),'runtime':entry['file'],'sha256':entry['sha256'],'source_dimensions':[w,h],'desired_idle_height_m':desired,'median_idle_source_height_px':statistics.median(heights),'pixel_size':size,'regions':regions,'measured_alpha_bounds':bounds,'frame_pivots':pivots,'pixel_processing':'No resizing, repainting, padding, masking, alpha editing or PNG re-encoding. Only byte-for-byte copy. Source rectangle registration samples original pixels.','limits':'Generated directional attack poses are approximate. Source columns crowd a few sprite edges; native rectangle boundaries chosen at lowest opacity near intended gutters. No claim of final animation acceptance.'}
(root/'assets/combat_art.json').write_text(json.dumps(manifest,indent=2)+'\n');docs=root/'docs/production-v11';docs.mkdir(parents=True,exist_ok=True);(docs/'staff-art.json').write_text(json.dumps({'tool':'built-in image_gen','reference':'concepts/visual-v2/corrupted-biotech/scene.png','scope':'Pale Ward infected facility staff only','assets':records},indent=2)+'\n')
print({k:v['sha256'] for k,v in records.items()})
