#!/usr/bin/env python3
"""Add unchanged approved menu original and two licensed level music candidates."""
import pathlib,json,subprocess,re,hashlib,math,shutil
B=pathlib.Path(__file__).resolve().parent;F=['ffmpeg','-hide_banner','-nostdin','-y']
def run(a):
 p=subprocess.run(a,text=True,capture_output=True)
 if p.returncode:raise RuntimeError(p.stderr)
 return p.stderr
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def probe(p):return json.loads(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration:stream=channels,sample_rate,codec_name','-of','json',str(p)],text=True))
def measure(p):
 t=run(F+['-i',str(p),'-af','loudnorm=I=-19:TP=-3:LRA=7:print_format=json','-f','null','-']);d=json.loads(re.findall(r'\{\s*"input_i".*?\}',t,re.S)[-1]);(B/'verification'/f'music-{p.stem}.txt').write_text(t);return d

def normalize(src,out,start=None,dur=None):
 inp=['-i',str(src)]
 if start is not None:inp+=['-ss',str(start),'-t',str(dur)]
 d=json.loads(re.findall(r'\{\s*"input_i".*?\}',run(F+inp+['-af','loudnorm=I=-19:TP=-3:LRA=7:print_format=json','-f','null','-']),re.S)[-1])
 af=f'loudnorm=I=-19:TP=-3:LRA=7:measured_I={d["input_i"]}:measured_TP={d["input_tp"]}:measured_LRA={d["input_lra"]}:measured_thresh={d["input_thresh"]}:offset={d["target_offset"]}:linear=true'
 if dur:af+=f',afade=t=in:d=0.12,afade=t=out:st={dur-1}:d=1'
 run(F+inp+['-af',af,'-ar','48000','-ac','2','-c:a','pcm_s16le',str(out)])
 run(F+['-i',str(out),'-c:a','libvorbis','-q:a','6',str(out.with_suffix('.ogg'))])

m=json.loads((B/'manifest.json').read_text());m.pop('approved_music',None)
menu=B/'music'/'menu_music.wav';assert sha(menu)=='00a4089998c34fa1f5405c8ad652dd41107216e8bded92d28cb48805fb87c877'
(B/'music').mkdir(exist_ok=True)
d=measure(menu);level={'integrated_lufs':float(d['input_i']),'true_peak_dbtp':float(d['input_tp'])}
sourc={'id':'abelian-menu','title':'Abelian','creator':'Zander Noriega','creator_url':'https://soundcloud.com/zander-noriega','source_url':'https://opengameart.org/content/abelian','license':'CC BY 3.0','license_url':'https://creativecommons.org/licenses/by/3.0/','license_evidence':['provenance/abelian.html'],'original':'music/menu_music.wav','original_sha256':sha(menu),'technical':probe(menu)}
m['sources'].append(sourc)
normalized_menu=B/'music'/'menu_abelian.wav';normalize(menu,normalized_menu);nd=measure(normalized_menu)
m['cues']['menu_music']={'file':'music/menu_abelian.ogg','bus':'Music','gain_db':0,'source_ids':['abelian-menu'],'sha256':sha(normalized_menu.with_suffix('.ogg')),'reference_wav_file':'music/menu_abelian.wav','reference_wav_sha256':sha(normalized_menu),'original_unchanged_file':'music/menu_music.wav','original_unchanged_sha256':sha(menu),'technical':probe(normalized_menu.with_suffix('.ogg')),'levels':{'integrated_lufs':float(nd['input_i']),'true_peak_dbtp':float(nd['input_tp']),'measured_reference':'music/menu_abelian.wav'},'edits':'Playback derivative: full approved original normalized to -19LUFS with -3dBTP ceiling, resampled48kHz stereo and encoded OGG. No excerpt, rearrangement or composition changes. Original music/menu_music.wav retained byte-identical with original stereo/sample rate/hash.','role':'MAIN MENU ONLY. Separate always-process menu music player; stop when entering level.','loop':'Full-song repeat at runtime; no seamless loop edit or combat use.'}
levels=[]
for key,title,slug,p,lic,start,fit in [
 ('level_music_biotech_candidate','Bestial Paragon Interface','bestial-paragon-interface',B/'originals'/'music'/'Zander Noriega - Bestial Paragon Interface.wav','3.0',36,'Slower monstrous/cold heavy riffs suit bodily mass and compromised clinical spaces; strongest provisional biotech choice based on creator description. User listening decides.'),
 ('level_music_fortress_candidate','Dragged Through Hellfire (Abomination)','dragged-through-hellfire-abomination',B/'originals'/'music'/'zander_noriega_-_dragged_through_hellfire_abomination_0.wav','4.0',35,'Brutal death-metal direction with the creator\'s newer mix and real recorded bass suits siege force and occult hostility; separate fortress candidate, not the earlier Stage 1 cue.')]:
 sid=slug;url='https://opengameart.org/content/'+slug
 originalmeta={'id':sid,'title':title,'creator':'Zander Noriega','creator_url':'https://zandernoriega.com/','source_url':url,'license':'CC BY '+lic,'license_url':'https://creativecommons.org/licenses/by/'+lic+'/','license_evidence':['provenance/'+slug+'.html'],'original':str(p.relative_to(B)),'original_sha256':sha(p),'technical':probe(p)}
 if lic=='4.0':originalmeta['download_url']='https://opengameart.org/sites/default/files/zander_noriega_-_dragged_through_hellfire_abomination_0.wav'
 else:originalmeta['download_url']='https://opengameart.org/sites/default/files/Zander%20Noriega%20-%20Bestial%20Paragon%20Interface.zip'
 m['sources'].append(originalmeta)
 out=B/'music'/f'{key}.wav';normalize(p,out);aud=B/'auditions'/f'{key}-25s.wav';normalize(p,aud,start,25)
 d=measure(out);ls={'integrated_lufs':float(d['input_i']),'true_peak_dbtp':float(d['input_tp'])}
 m['cues'][key]={'file':str(out.relative_to(B)),'ogg_file':str(out.with_suffix('.ogg').relative_to(B)),'bus':'Music','gain_db':0,'source_ids':[sid],'sha256':sha(out),'ogg_sha256':sha(out.with_suffix('.ogg')),'technical':probe(out),'levels':ls,'edits':'Full original song retained in originals/music; playback copy normalized to -19 LUFS with -3 dBTP ceiling, resampled to48kHz stereo. No composition, beat splice or rearrangement.','role':'Candidate level music; one selected per level setting, pausable world LevelMusic player. Not main menu.','loop':'Full-track repeat; seamless transition not established. Fade/crossfade at runtime or audition musical boundary before asserting seamless looping.','audition_file':str(aud.relative_to(B)),'audition_sha256':sha(aud),'audition_edits':{'start_seconds':start,'duration_seconds':25,'fade_in_seconds':.12,'fade_out_seconds':1,'loudness_target_lufs':-19},'appeal_to_test':fit}
 levels.append({'cue_key':key,'file':str(aud.relative_to(B)),'ogg_file':str(aud.with_suffix('.ogg').relative_to(B)),'sha256':sha(aud),'fit':fit})
 print('Music built',title,ls,flush=True)

# Correct previous Abelian masking test: warning audition now uses a separate level candidate.
old=B/'auditions'/'warnings-with-approved-music.wav'
if old.exists():old.unlink()
# Level candidate at original normalized level minus3.9dB, warnings distinct at4/12 sec.
w=B/'auditions'/'warnings-with-level-music.wav';inputs=[B/levels[0]['file'],B/m['cues']['unsealed_attack_warning']['file'],B/m['cues']['unsealed_hurt']['file'],B/m['cues']['vessel_attack_warning']['file'],B/m['cues']['projectile_release']['file'],B/m['cues']['vessel_hurt']['file']]
a=F.copy();g=[]
for i,(p,t,gain) in enumerate(zip(inputs,[0,4,8,12,13.3,17],[.6,1,1,1,1,1])):
 a+=['-i',str(p)];g.append(f'[{i}:a]aresample=48000,aformat=channel_layouts=stereo,volume={gain},adelay={int(t*1000)}|{int(t*1000)}[e{i}]')
g.append(''.join(f'[e{i}]' for i in range(len(inputs)))+'amix=inputs=6:normalize=0,apad,atrim=duration=25[out]')
run(a+['-filter_complex',';'.join(g),'-map','[out]','-ar','48000','-ac','2','-c:a','pcm_s16le',str(w)])
m['auditions']=[x for x in m['auditions'] if 'warnings-with-approved-music' not in x['file']]+[{'file':str(w.relative_to(B)),'sha256':sha(w),'timeline':'Biotech level candidate at0.6gain; Unsealed warning4s/hurt8s; Vessel warning12s/release13.3s/hurt17s. No ducking.'}]
m['level_music_candidates']=levels
m['routing_rules']['music']='Abelian menu_music plays only on menu. Separate level candidate plays on pausable world LevelMusic. Same existing Music bus; stop/crossfade menu on scene transition. Each level selects matching licensed track; no automatic Abelian combat loop.'
m['routing_rules']['projectile_contact']='projectile_impact is organic player/flesh contact; use projectile_hard for hard materials. No hurt voice embedded; emit player_hurt separately after damage.'
m['routing_rules']['environment']='pistol_hard/shotgun_hard/melee_hard are low-level fallback cues only; no expanded architecture sound pack.'
m['archives']=[{'file':str(p.relative_to(B)),'sha256':sha(p)} for p in sorted((B/'archives').iterdir())]
(B/'manifest.json').write_text(json.dumps(m,indent=2,allow_nan=False)+'\n')
page=(B/'index.html').read_text().replace('Warnings against unchanged approved music','Warnings against separate level music').replace('warnings-with-approved-music.wav','warnings-with-level-music.wav').replace('unchanged music at gain0.6','level candidate at gain0.6')
extra='<section><h2>Main menu music</h2><p>Full Abelian menu playback derivative normalized to -19 LUFS. Unchanged original retained separately. Main menu only.</p><audio controls preload="none" src="music/menu_abelian.ogg"></audio></section><section><h2>Separate level music candidates</h2><p>Both 25-second auditions are level-matched at -19 LUFS. These are candidates, not selected gameplay loops.</p>'
for l in levels:extra+=f'<h3>{l["cue_key"]}</h3><p>{l["fit"]}</p><audio controls preload="none" src="{l["ogg_file"]}"></audio>'
extra+='</section>'
page=page.replace('</html>',extra+'</html>');(B/'index.html').write_text(page)
# Remove obsolete Stage2 copies of the Stage1 menu excerpt; Stage1 files remain unchanged.
for p in (B/'music').glob('approved_abelian_25s.*'):p.unlink()
print('Menu and level routing updated',flush=True)
