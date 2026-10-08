#!/usr/bin/env python3
"""Rebuild Stage 1 auditions from retained, unmodified licensed originals."""
import pathlib, subprocess, json, re, hashlib, math
B = pathlib.Path(__file__).resolve().parent
C = B/'cues'; C.mkdir(exist_ok=True)
S = B/'stems'; S.mkdir(exist_ok=True)
L = B/'verification'; L.mkdir(exist_ok=True)
FF=['ffmpeg','-hide_banner','-nostdin','-y']
def run(args):
 p=subprocess.run(args,capture_output=True,text=True)
 if p.returncode: raise RuntimeError(p.stderr)
 return p.stderr

def ff(src,dst,af='',start=None,duration=None):
 args=FF.copy()
 if start is not None:args += ['-ss',str(start)]
 args += ['-i',str(src)]
 if duration is not None:args += ['-t',str(duration)]
 if af:args += ['-af',af]
 args += ['-ar','48000','-ac','2','-c:a','pcm_s16le',str(dst)]
 run(args)

def loudnorm(src,dst,target=-19):
 args=FF+['-i',str(src),'-af',f'loudnorm=I={target}:TP=-3:LRA=7:print_format=json','-f','null','-']
 txt=run(args);d=json.loads(re.findall(r'\{\s*"input_i".*?\}',txt,re.S)[-1])
 af=f'loudnorm=I={target}:TP=-3:LRA=7:measured_I={d["input_i"]}:measured_TP={d["input_tp"]}:measured_LRA={d["input_lra"]}:measured_thresh={d["input_thresh"]}:offset={d["target_offset"]}:linear=true'
 ff(src,dst,af)

def peaknorm(src,dst,target=-9):
 txt=run(FF+['-i',str(src),'-af','volumedetect','-f','null','-'])
 pk=float(re.search(r'max_volume: ([\-0-9.]+) dB',txt)[1])
 ff(src,dst,f'volume={target-pk}dB')

def mix(events,dst,duration):
 args=FF.copy(); graph=[];labels=[]
 for i,(src,time,gain) in enumerate(events):
  args+=['-i',str(src)];label=f'e{i}';labels.append(f'[{label}]')
  graph.append(f'[{i}:a]aresample=48000,aformat=channel_layouts=stereo,volume={gain},adelay={int(time*1000)}|{int(time*1000)}[{label}]')
 graph.append(''.join(labels)+f'amix=inputs={len(events)}:duration=longest:normalize=0,apad,atrim=duration={duration}[out]')
 args+=['-filter_complex',';'.join(graph),'-map','[out]','-ar','48000','-ac','2','-c:a','pcm_s16le',str(dst)]
 run(args)

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def probe(p):return json.loads(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration:stream=sample_rate,channels,codec_name','-of','json',str(p)],text=True))

def measure(p):
 txt=run(FF+['-i',str(p),'-af','loudnorm=I=-19:TP=-3:LRA=7:print_format=json','-f','null','-'])
 d=json.loads(re.findall(r'\{\s*"input_i".*?\}',txt,re.S)[-1]);(L/(p.stem+'.txt')).write_text(txt)
 return {'integrated_lufs':float(d['input_i']),'true_peak_dbtp':float(d['input_tp']),'loudness_range_lu':float(d['input_lra']),'measurement':'FFmpeg loudnorm; input measurements, not playback validation'}

music_specs=[
 ('biotech','Corrupted biotech facility','Abelian',18, 'Synths with heavy guitar: test a cold engineered threat against living corruption.'),
 ('fortress','War-torn occult fortress','Dragged Through Hellfire',35,'Brutal riff-driven guitar: test siege force and a hostile ritual mood.'),
 ('civic','Invaded civic megastructure','The Recon Mission',22,'Cold guitar-driven pressure: test militant invasion in a vast public structure.')]
tracks={};sources=[];exports=[]
for cid,title,track,start,appeal in music_specs:
 slug={'Abelian':'abelian','Dragged Through Hellfire':'dragged-through-hellfire','The Recon Mission':'the-recon-mission'}[track]
 p=B/'originals'/f'Zander Noriega - {track}.wav'
 sources.append({'id':slug,'type':'music','title':track,'creator':'Zander Noriega','creator_url':'https://opengameart.org/users/zander-noriega','source_url':f'https://opengameart.org/content/{slug}','download_url':f'https://opengameart.org/sites/default/files/Zander%20Noriega%20-%20{track.replace(" ","%20")}.zip','license':'CC BY 3.0','license_url':'https://creativecommons.org/licenses/by/3.0/','license_evidence':f'provenance/{slug}.html','original':str(p.relative_to(B)),'sha256':sha(p),'technical':probe(p)})
 tmp=S/f'{cid}_music_trim.wav';out=C/f'{cid}_music_25s.wav'
 ff(p,tmp,'afade=t=in:d=0.12,afade=t=out:st=24:d=1',start,25);loudnorm(tmp,out)
 tracks[cid]=out
 exports.append({'id':f'{cid}_music','concept':title,'file':str(out.relative_to(B)),'source_ids':[slug],'edits':{'excerpt_start_seconds':start,'excerpt_duration_seconds':25,'fade_in_seconds':.12,'fade_out_seconds':1,'loudness_target_lufs':-19,'true_peak_ceiling_dbtp':-3,'stereo':'original two channels preserved; no mono downmix'},'appeal_to_test':appeal})
 print('Rendered',out.name,flush=True)

firebase=B/'originals'/'firearms'/'Prepared SFX Library'
physical_specs=[
 ('pistol',firebase/'1911'/'A_42P.wav',.84,1.8,''),
 ('carbine',firebase/'AR-15'/'D_32P.wav',.64,1.8,''),
 ('shotgun',firebase/'Model 12'/'K_22P.wav',.74,2.1,''),
 ('burst',firebase/'AK-47'/'C_29P.wav',.99,1.8,''),
 ('metal_clash',B/'originals'/'medieval'/'Axe Katana Blade on Blade.wav',5.88,1.1,'highpass=f=100,lowpass=f=7000'),
 ('wood_metal',B/'originals'/'medieval'/'Dagger Axe Blade on Haft.wav',0,1,'highpass=f=100,lowpass=f=7000'),
 ('heavy_impact',B/'originals'/'medieval'/'Mace Axe Blade and Haft.wav',4.34,.7,'highpass=f=100,lowpass=f=7000')]
stems={};edits={}
for sid,p,start,dur,filters in physical_specs:
 firearm=sid in ['pistol','carbine','shotgun','burst'];slug='the-free-firearm-sound-library' if firearm else 'medieval-sound-effects-weapon-impacts'
 sources.append({'id':sid,'type':'recorded_firearm' if firearm else 'recorded_weapon_impact','title':p.name,'creator':'Ben Jaszczak, Brian Nelson, Kevin Heras, Matthew Nanney' if firearm else 'Ben Jaszczak and Brian Nelson','source_url':f'https://opengameart.org/content/{slug}','download_url':'https://opengameart.org/sites/default/files/Prepared%20SFX%20Library.7z' if firearm else 'https://opengameart.org/sites/default/files/medieval_sfx_weapon_on_weapon_1_of_2.7z','license':'CC0 1.0','license_url':'https://creativecommons.org/publicdomain/zero/1.0/','license_evidence':f'provenance/{slug}.html','original':str(p.relative_to(B)),'sha256':sha(p),'technical':probe(p)})
 tmp=S/f'{sid}_trim.wav';out=S/f'{sid}_dry.wav'
 af=','.join(x for x in [filters,f'afade=t=out:st={dur-.12}:d=0.12'] if x)
 ff(p,tmp,af,start,dur);peaknorm(tmp,out,-9 if firearm else -14);stems[sid]=out
 edits[sid]={'excerpt_start_seconds':start,'excerpt_duration_seconds':dur,'filters':af,'peak_target_dbfs':-9 if firearm else -14}

warning=B/'originals'/'kenney'/'error_006.ogg'
sources.append({'id':'warning','type':'library_interface_warning','title':'error_006.ogg','creator':'Kenney','creator_url':'https://kenney.nl/','source_url':'https://kenney.nl/assets/interface-sounds','download_url':'https://kenney.nl/media/pages/assets/interface-sounds/fa43c1dd4d-1677589452/kenney_interface-sounds.zip','license':'CC0 1.0','license_url':'https://creativecommons.org/publicdomain/zero/1.0/','license_evidence':['provenance/kenney-interface-sounds.html','originals/kenney/License.txt'],'original':str(warning.relative_to(B)),'sha256':sha(warning),'technical':probe(warning)})
peaknorm(warning,S/'warning.wav',-12);stems['warning']=S/'warning.wav'

rooms={
 'biotech':('carbine','wood_metal','highpass=f=65,equalizer=f=160:t=q:w=1:g=2,aecho=0.9:0.8:35|70:0.13|0.07','Short hard-room reflections; crisp carbine and light metal/haft contact.'),
 'fortress':('shotgun','metal_clash','highpass=f=50,equalizer=f=120:t=q:w=1:g=3,equalizer=f=3500:t=q:w=1:g=-2,aecho=0.9:0.8:115|230|410:0.22|0.13|0.06','Longer stone-like echoes; shotgun weight and blade clash.'),
 'civic':('burst','heavy_impact','highpass=f=65,equalizer=f=250:t=q:w=1:g=-2,aecho=0.9:0.8:80|165|285:0.17|0.10|0.05','Medium public-hall reflections; automatic burst and structural metal hit.')}
for cid,title,track,start,appeal in music_specs:
 gun,impact,filters,design=rooms[cid];raw=S/f'{cid}_gun_edit_raw.wav';gs=S/f'{cid}_gun.wav'
 ff(stems[gun],raw,filters);peaknorm(raw,gs,-9)
 events=[(gs,.35,1),(gs,2.65,1),(stems[impact],5.0,1),(gs,6.1,.9),(stems['warning'],8.2,1),(stems['warning'],8.9,1)]
 out=C/f'{cid}_sfx_10s.wav';mix(events,out,10)
 exports.append({'id':f'{cid}_sfx','concept':title,'file':str(out.relative_to(B)),'source_ids':[gun,impact,'warning'],'edits':{'source_excerpt_edits':{k:edits[k] for k in [gun,impact]},'gun_room_filters':filters,'edited_gun_peak_target_dbfs':-9,'warning_peak_target_dbfs':-12,'timeline_seconds':{'gun':[.35,2.65,6.1],'impact':[5.0],'warning':[8.2,8.9]}},'design_to_test':design})
 out=C/f'{cid}_masking_check_25s.wav';mix([(tracks[cid],0,.64),(C/f'{cid}_sfx_10s.wav',8,1)],out,25)
 exports.append({'id':f'{cid}_masking_check','concept':title,'file':str(out.relative_to(B)),'source_ids':[exports[-1]['id'],f'{cid}_music'],'edits':{'music_gain':.64,'sfx_start_seconds':8,'warning_seconds':[16.2,16.9],'ducking':'none; intended warning masking comparison'},'listening_question':'Can both warnings be identified clearly during this aggressive music passage?'})
 print('Rendered',cid,'SFX and masking check',flush=True)

# Same pistol recording in two halves. Both peak-matched; source recording retains outdoor ambience.
raw=S/'shared_pistol_edited_raw.wav';edited=S/'shared_pistol_edited.wav'
filters='highpass=f=60,equalizer=f=150:t=q:w=1:g=3,equalizer=f=3500:t=q:w=1:g=-3,aecho=0.9:0.8:55|105:0.13|0.07'
ff(stems['pistol'],raw,filters);peaknorm(raw,edited,-9)
out=C/'shared_guns_dry_vs_edited_12s.wav'
mix([(stems['pistol'],t,1) for t in [.35,2.35,4.35]]+[(edited,t,1) for t in [6.35,8.35,10.35]],out,12)
exports.append({'id':'shared_guns_dry_vs_edited','file':str(out.relative_to(B)),'source_ids':['pistol'],'edits':{'dry':'source excerpt, resampled, end fade and peak matched; no EQ or room effect','source_excerpt_edits':edits['pistol'],'edited':filters,'both_peak_target_dbfs':-9,'dry_shot_seconds':[.35,2.35,4.35],'edited_shot_seconds':[6.35,8.35,10.35]},'listening_question':'Which treatment better communicates punch and physical weight without a brittle top end?'})
for e in exports:
 p=B/e['file'];e['sha256']=sha(p);e['technical']=probe(p);e['levels']=measure(p)
 # Convenient browser/Godot audition format; PCM WAV remains the reference.
 ogg=p.with_suffix('.ogg');run(FF+['-i',str(p),'-c:a','libvorbis','-q:a','6',str(ogg)])
 e['ogg_file']=str(ogg.relative_to(B));e['ogg_sha256']=sha(ogg)
 print('Verified',p.name,e['levels'],flush=True)
manifest={'schema_version':1,'stage':'Stage 1 concept auditions','created_date':'2026-10-08','scope':'Three equally scoped identities; no concept chosen; no game production audio claimed.','listening_status':'Technical decode, stereo, duration, loudness and peak verification completed. No human or agent subjective listening validation completed.','sources':sources,'exports':exports,'source_archives':[{'file':str(p.relative_to(B)),'size_bytes':p.stat().st_size,'sha256':sha(p)} for p in sorted((B/'archives').glob('*'))],'mix_policy':'Music excerpts -19 LUFS and <= -3 dBTP; gun excerpt peaks -9 dBFS; warning peak -12 dBFS; masking mixes music reduced ~3.9 dB. No overall normalization that pumps sparse effects.'}
(B/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('Manifest complete',flush=True)
