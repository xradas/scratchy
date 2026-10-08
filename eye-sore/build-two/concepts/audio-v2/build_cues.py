#!/usr/bin/env python3
"""Reproducible Stage 2 recorded-source combat cue treatments; no synthesized source."""
import pathlib,subprocess,json,re,hashlib,html,shutil,math
B=pathlib.Path(__file__).resolve().parent
for n in ['cues','dry','auditions','stems','verification']: (B/n).mkdir(exist_ok=True)
F=['ffmpeg','-hide_banner','-nostdin','-y']
def run(a):
 p=subprocess.run(a,capture_output=True,text=True)
 if p.returncode:raise RuntimeError(p.stderr)
 return p.stderr

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def probe(p):return json.loads(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration:stream=sample_rate,channels,codec_name','-of','json',str(p)],text=True))
def render(src,dst,start=0,dur=None,af='',mono=True):
 a=F+['-i',str(src),'-ss',str(start)]
 if dur is not None:a+=['-t',str(dur)]
 if af:a+=['-af',af]
 a+=['-ar','48000','-ac','1' if mono else '2','-c:a','pcm_s24le',str(dst)];run(a)
def peaknorm(src,dst,target):
 t=run(F+['-i',str(src),'-af','volumedetect','-f','null','-']);pk=float(re.search(r'max_volume: ([\-0-9.]+) dB',t)[1]);render(src,dst,af=f'volume={target-pk}dB')
def measure(p):
 t=run(F+['-i',str(p),'-af','loudnorm=I=-19:TP=-3:LRA=7:print_format=json','-f','null','-']);d=json.loads(re.findall(r'\{\s*"input_i".*?\}',t,re.S)[-1]);(B/'verification'/f'{p.parent.name}-{p.stem}.txt').write_text(t)
 return {'integrated_lufs':float(d['input_i']) if math.isfinite(float(d['input_i'])) else None,'true_peak_dbtp':float(d['input_tp']),'measurement':'FFmpeg input loudnorm measurements; no subjective validation'}
def mix(ev,dst,duration=None,mono=True):
 a=F.copy();g=[];labs=[]
 for i,(p,time,gain) in enumerate(ev):
  a+=['-i',str(p)];lab=f'e{i}';labs.append(f'[{lab}]');layout='mono' if mono else 'stereo';delay=str(round(time*1000))
  if not mono:delay+='|'+delay
  g.append(f'[{i}:a]aresample=48000,aformat=channel_layouts={layout},volume={gain},adelay={delay}[{lab}]')
 tail=f',apad,atrim=duration={duration}' if duration else ''
 g.append(''.join(labs)+f'amix=inputs={len(ev)}:duration=longest:normalize=0'+tail+'[out]')
 a+=['-filter_complex',';'.join(g),'-map','[out]','-ar','48000','-ac','1' if mono else '2','-c:a','pcm_s24le',str(dst)];run(a)

packs={
'firearms':('The Free Firearm Sound Library','Ben Jaszczak, Brian Nelson, Kevin Heras, Matthew Nanney','the-free-firearm-sound-library','https://opengameart.org/sites/default/files/Prepared%20SFX%20Library.7z','Recorded firearms; downloaded prepared-library originals, not raw microphone takes.'),
'body':('40 wet towel club/pound/hit/attack sounds',"Iwan 'qubodup' Gabovitch",'40-wet-towel-clubpoundhitattack-sounds','https://opengameart.org/sites/default/files/wet_towel_on_body.7z','Recorded wet towel on human back. Source page explicitly supersedes older archive info license with CC0.'),
'impact':('Impact',"Iwan 'qubodup' Gabovitch",'impact','https://opengameart.org/sites/default/files/qubodupImpact.7z','Downloaded library treatments of creator\'s recorded physical source sounds.'),
'metal':('Metal Interactions',"Iwan 'qubodup' Gabovitch",'metal-interactions','https://opengameart.org/sites/default/files/metal_interactions.7z','Metal object interaction library; adapted as armor/trigger foley, not an authentic gun dry-fire claim.'),
'swish':('Swish bamboo stick weapon swishes',"Iwan 'qubodup' Gabovitch",'swish-bamboo-stick-weapon-swhoshes','https://opengameart.org/sites/default/files/swoshes.7z','Creator-recorded bamboo stick swung in front of microphone.'),
'human':('Female Hurt Grunts and Groans','AuraVoice / Nocturnal_Vanguard','female-hurt-grunts-groans','https://opengameart.org/sites/default/files/female_hurt_grunts_groans_1.ogg','Recorded human voice-over performance, seven separate vocal gestures in one downloaded OGG.'),
'camel':('Camel Groan','AntumDeluge (extraction), craigsmith (source digitization)','camel-groan','https://opengameart.org/sites/default/files/camel.zip','Recorded animal vocalization excerpt. Upstream vintage recording: https://freesound.org/people/craigsmith/sounds/437937/; CC0 verified on both pages.')}
paths={
'pistol':('firearms','firearms/Prepared SFX Library/1911/A_42P.wav'),
'shotgun':('firearms','firearms/Prepared SFX Library/Model 12/K_22P.wav'),
'body01':('body','wet_towel_on_body/wet_towel_on_body-01.flac'),
'body07':('body','wet_towel_on_body/wet_towel_on_body-07.flac'),
'body14':('body','wet_towel_on_body/wet_towel_on_body-14.flac'),
'meat01':('impact','qubodupImpact/qubodupImpactMeat01.flac'),
'meat02':('impact','qubodupImpact/qubodupImpactMeat02.flac'),
'metalimpact':('impact','qubodupImpact/qubodupImpactMetal.flac'),
'stone':('impact','qubodupImpact/qubodupImpactStone.flac'),
'metal01':('metal','metal_interactions/metal_interaction1.wav'),
'metal02':('metal','metal_interactions/metal_interaction2.wav'),
'metalswing':('metal','metal_interactions/metal_swing1.wav'),
'click':('metal','metal_interactions/metal_button_press2.wav'),
'swish06':('swish','swosh-06.flac'),
'swish13':('swish','swosh-13.flac'),
'human':('human','female_hurt_grunts_groans_1.ogg'),
'camel01':('camel','camel/flac/camel_01.flac'),
'camel02':('camel','camel/flac/camel_02.flac')}
sources=[]
for sid,(pack,path) in paths.items():
 title,creator,slug,url,note=packs[pack];p=B/'originals'/path
 sources.append({'id':sid,'title':title,'creator':creator,'source_url':'https://opengameart.org/content/'+slug,'download_url':url,'license':'CC0 1.0','license_url':'https://creativecommons.org/publicdomain/zero/1.0/','license_evidence':['provenance/'+slug+'.html'],'original':str(p.relative_to(B)),'original_sha256':sha(p),'technical':probe(p),'recording_description':note})
 if pack=='camel':sources[-1]['license_evidence']+=['originals/camel/README.txt','provenance/craigsmith-camel-437937.html']

# Layer tuples: original source id, excerpt start, duration, pitch ratio, filter chain, relative gain, delay.
# Pitch changes use resampling (physical recording preserved, slower/faster playback), not an oscillator.
def layer(sid,start,dur,pitch=1,af='',gain=1,delay=0):return(sid,start,dur,pitch,af,gain,delay)
bodyeq='highpass=f=65,equalizer=f=150:t=q:w=0.8:g=4,lowpass=f=7500'
metaleq='highpass=f=160,equalizer=f=2100:t=q:w=1:g=2,lowpass=f=9000'
voiceeq='highpass=f=110,lowpass=f=6500,acompressor=threshold=0.08:ratio=2:attack=5:release=90'
specs={
'pistol_fire':('Weapons',-6,[layer('pistol',.934,1.15,1,'highpass=f=60,equalizer=f=150:t=q:w=0.8:g=2,equalizer=f=3500:t=q:w=1:g=-2')],'Tight recorded .45 crack with restrained body; no long room echo.'),
'shotgun_fire':('Weapons',-6,[layer('shotgun',.835,1.55,.93,'highpass=f=45,equalizer=f=120:t=q:w=0.8:g=4,equalizer=f=3000:t=q:w=1:g=-1')],'Broader lower recorded 12-gauge discharge; one fire per shot.'),
'melee_swing':('Weapons',-14,[layer('swish13',.045,.43,.92,'highpass=f=100,lowpass=f=7500')],'Recorded bamboo swing; attack motion without a contact sound.'),
'empty':('Weapons',-16,[layer('click',0,.15,1,'highpass=f=180,lowpass=f=6000')],'Short recorded metal-object click adapted to empty trigger feedback.'),
'pistol_flesh':('World',-9,[layer('body07',.012,.42,1.05,bodyeq),layer('meat01',0,.3,1.05,'highpass=f=180,lowpass=f=5500',.4,.008)],'Focused body slap and short organic texture; no hurt vocal embedded.'),
'shotgun_flesh':('World',-7,[layer('body01',0,.47,.78,bodyeq),layer('meat02',0,.42,.72,'highpass=f=55,equalizer=f=100:t=q:w=1:g=3,lowpass=f=4500',.65,.01)],'One broad aggregate body strike per target per shotgun shot, regardless of pellet count.'),
'melee_flesh':('World',-8,[layer('body14',0,.33,.86,bodyeq),layer('meat02',0,.34,1.12,'highpass=f=130,lowpass=f=5200',.32,.025)],'Heavy hand/club body strike with a slower wet tail; not a firearm hit.'),
'pistol_armor':('World',-10,[layer('metal02',0,.35,1.2,metaleq)],'Short high metal tick; distinct original from the shotgun and melee main layers.'),
'shotgun_armor':('World',-8,[layer('metal01',0,.48,.78,metaleq),layer('metalimpact',0,.46,.82,'highpass=f=100,lowpass=f=7000',.65,.012)],'Broad heavy plate rattle and ring; one aggregate strike per target per shot.'),
'melee_armor':('World',-9,[layer('metalswing',.07,.57,.95,metaleq),layer('metalimpact',0,.36,1.1,'highpass=f=250,lowpass=f=8500',.4,0)],'Dense metallic clonk with a separate scrape tail, not the pistol ricochet.'),
'pistol_hard':('World',-17,[layer('stone',0,.25,1.25,'highpass=f=300,lowpass=f=6000')],'Low-priority short hard-surface tick fallback.'),
'shotgun_hard':('World',-15,[layer('stone',0,.45,.8,'highpass=f=150,lowpass=f=6000')],'Low-priority broader hard-surface strike fallback; one per shot group.'),
'melee_hard':('World',-16,[layer('stone',0,.35,.95,'highpass=f=170,lowpass=f=4500')],'Low-priority hard-surface clunk fallback.'),
'unsealed_hurt':('Creatures',-12,[layer('human',3.70,.52,.82,voiceeq)],'Brief strained human-origin pain gesture; separate from weapon/material contact.'),
'unsealed_death':('Creatures',-12,[layer('human',4.88,1.35,.69,voiceeq)],'Longer falling human-origin groan; exclusive terminal voice.'),
'unsealed_attack_warning':('Creatures',-10,[layer('human',9.39,.92,.88,'highpass=f=120,equalizer=f=1800:t=q:w=1:g=3,lowpass=f=7000,acompressor=threshold=0.015:ratio=4:attack=1:release=80:makeup=2')],'Sharper human-origin strain before the strike; threat identity distinct from Vessel.'),
'vessel_hurt':('Creatures',-12,[layer('camel01',.10,.8,.82,'highpass=f=80,equalizer=f=240:t=q:w=1:g=3,lowpass=f=5000')],'Short guttural animal-origin response; not a repitched Unsealed voice.'),
'vessel_death':('Creatures',-12,[layer('camel02',2.6,2.1,.66,'highpass=f=65,equalizer=f=180:t=q:w=1:g=3,lowpass=f=4500')],'Longer animal-origin collapse groan; no impact embedded.'),
'vessel_attack_warning':('Creatures',-10,[layer('camel01',1.78,1.12,1.03,'highpass=f=180,equalizer=f=1200:t=q:w=1:g=4,lowpass=f=6000')],'Higher rasping animal-origin pre-release warning.'),
'projectile_release':('Creatures',-13,[layer('swish06',.045,.23,1.18,'highpass=f=220,lowpass=f=7000'),layer('meat01',0,.24,1.25,'highpass=f=200,lowpass=f=5000',.45,0)],'Brief air/organic launch motion from recordings; distinct from warning voice.'),
'projectile_impact':('World',-13,[layer('meat01',0,.4,.75,'highpass=f=100,lowpass=f=4200'),layer('body01',0,.4,.85,'highpass=f=160,lowpass=f=5200',.4,.01)],'Organic projectile body/player contact; use projectile_hard for a hard material.'),
'projectile_hard':('World',-17,[layer('stone',0,.36,.7,'highpass=f=200,lowpass=f=4000'),layer('meat01',0,.24,.8,'highpass=f=300,lowpass=f=3000',.3,0)],'Quiet hard-material projectile fallback; separate from body/player contact.'),
'player_hurt':('Creatures',-13,[layer('human',2.08,.67,1,'highpass=f=90,lowpass=f=7500')],'Unpitched separate human performance excerpt for player feedback.')}

cues={}
for key,(bus,pk,layers,description) in specs.items():
 dryev=[];designedevents=[];ledger=[]
 for i,(sid,start,dur,pitch,af,gain,delay) in enumerate(layers):
  src=B/'originals'/paths[sid][1];dr=B/'stems'/f'{key}-{i}-dry.wav';render(src,dr,start,dur);dn=B/'stems'/f'{key}-{i}-dry-level.wav';peaknorm(dr,dn,-12)
  # All clips receive only boundary fades in dry; design additionally receives pitch/EQ.
  effects=f'asetrate=48000*{pitch},aresample=48000'+(','+af if af else '')
  treatment=B/'stems'/f'{key}-{i}-treat.wav';render(dr,treatment,af=effects)
  duration=float(probe(treatment)['format']['duration']);faded=B/'stems'/f'{key}-{i}-faded.wav';render(treatment,faded,af=f'afade=t=in:d=0.003,afade=t=out:st={max(.004,duration-.06):.6f}:d=0.06')
  normalized=B/'stems'/f'{key}-{i}-design-level.wav';peaknorm(faded,normalized,-12)
  dryev.append((dn,delay,gain));designedevents.append((normalized,delay,gain));ledger.append({'source_id':sid,'excerpt_start_seconds':start,'excerpt_duration_seconds':dur,'pitch_playback_ratio':pitch,'filter_chain':effects,'layer_gain':gain,'layer_delay_seconds':delay,'layer_pre_mix_peak_dbfs':-12,'edge_fades_seconds':{'in':.003,'out':.06}})
 raw=B/'stems'/f'{key}-dry-mix.wav';mix(dryev,raw);dry=B/'dry'/f'{key}.wav';peaknorm(raw,dry,pk)
 raw=B/'stems'/f'{key}-designed-mix.wav';mix(designedevents,raw);out=B/'cues'/f'{key}.wav';peaknorm(raw,out,pk)
 # Prevent a long sourced file's leading floor from delaying tactile contact. Exact onsets inspected technically below.
 pair=B/'auditions'/f'{key}-dry-then-designed.wav';mix([(dry,.2,1),(out,4.2,1)],pair,8)
 ogg=out.with_suffix('.ogg');run(F+['-i',str(out),'-c:a','libvorbis','-q:a','6',str(ogg)])
 cues[key]={'file':str(out.relative_to(B)),'bus':bus,'gain_db':0,'source_ids':list(dict.fromkeys(x[0] for x in layers)),'description':description,'edits':ledger,'export_peak_target_dbfs':pk,'sha256':sha(out),'technical':probe(out),'levels':measure(out),'dry_file':str(dry.relative_to(B)),'dry_sha256':sha(dry),'dry_edits':'same selected original excerpts, mono downmix/resample, per-layer gain match and relative placement only; no pitch/EQ. Composite cue dry is a layer mix, not a new source original.','audition_file':str(pair.relative_to(B)),'audition_sha256':sha(pair),'ogg_file':str(ogg.relative_to(B)),'ogg_sha256':sha(ogg)}
 print('Built',key,cues[key]['levels'],flush=True)

# Six weapon/material comparisons in context, still keeping contact and hurt as separate events.
mat=B/'auditions'/'weapon-material-matrix.wav';events=[]
for i,(weapon,material) in enumerate([(w,m) for w in ['pistol','shotgun','melee'] for m in ['flesh','armor']]):
 t=.4+i*4;fire='melee_swing' if weapon=='melee' else weapon+'_fire';events += [(B/cues[fire]['file'],t,1),(B/cues[weapon+'_'+material]['file'],t+.2,1)]
 voice='unsealed_hurt' if material=='flesh' else 'vessel_hurt';events.append((B/cues[voice]['file'],t+.26,.85))
mix(events,mat,25)
manifest={'schema_version':2,'stage':'Stage 2 weapon and material contacts with separate voices','setting':'Pale Ward provisional voice labels; material system remains generic','created_date':'2026-10-09','approval_status':'New combat cues are candidates for user listening; rejected earlier impacts are not treated as approved. Approved music unchanged.','cues':cues,'sources':sources,'routing_rules':{'weapon_material_contacts':'select pistol_flesh/shotgun_flesh/melee_flesh or corresponding armor by weapon AND target material','shotgun_aggregation':'7 pellet ray hits -> aggregate damage per unique target; play exactly ONE shotgun material contact per target per shot, then at most one hurt/death voice for that target','vocal_separation':'Material contact contains no hurt voice. Enemy actor plays identity-specific hurt after actual damage; lethal damage replaces hurt with death, not both.','attack_warning':'Play distinct identity warning before committed attack; projectile_release only when projectile actually spawns.','environment':'No wall/floor/ceiling pack; unknown material falls back only if coordinator explicitly defines behavior.'},'auditions':[{'file':str(mat.relative_to(B)),'sha256':sha(mat),'timeline':'Every 4 seconds starting 0.4: pistol flesh, pistol armor, shotgun flesh, shotgun armor, melee flesh, melee armor. Contact +0.2s, separate hurt +0.26s.'}],'listening_status':'Technical FFmpeg decode/duration/channel/hash/loudness verification only. No agent or human subjective listening validation completed.','archives':[{'file':str(p.relative_to(B)),'sha256':sha(p)} for p in sorted((B/'archives').iterdir())]}
(B/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')

rows=[]
for key,d in cues.items():
 rows.append(f'<section><h2>{html.escape(key)}</h2><p>{html.escape(d["description"])} <small>Bus: {d["bus"]}</small></p><div class="players"><label>Dry excerpt <audio controls preload="none" src="{d["dry_file"]}"></audio></label><label>Designed <audio controls preload="none" src="{d["file"]}"></audio></label><label>A/B: dry at 0.2 s, designed at 4.2 s <audio controls preload="none" src="{d["audition_file"]}"></audio></label></div></section>')
page='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Combat audio audition</title><style>body{font:17px system-ui;background:#172023;color:#e2e9d8;max-width:1200px;margin:40px auto;padding:0 20px}h1,h2{color:#c9e889}section{border-top:1px solid #506164;padding:20px 0}.players{display:flex;flex-wrap:wrap;gap:22px}label{display:flex;flex-direction:column;gap:10px}small{color:#9ab0ae}a{color:#c9e889}audio{max-width:100%}</style><h1>Combat audio audition</h1><p>Weapon and hit material contacts are separate from creature voices. New cues await your listening review. Audio controls do not autoplay; begin at a low device volume.</p><p><a href="manifest.json">Source and edit ledger</a> · <a href="README.md">Credits and mixing guidance</a></p><h2>Six weapon and material cases</h2><p>Pistol flesh, pistol armor, shotgun flesh, shotgun armor, melee flesh, melee armor; one case every four seconds. Each hurt voice is a separate event.</p><audio controls src="auditions/weapon-material-matrix.wav"></audio><h2>Warnings against unchanged approved music</h2><p>Unsealed warning 4 s, hurt 8 s; Vessel warning 12 s, release 13.3 s, hurt 17 s. This review mix has no ducking.</p><audio controls src="auditions/warnings-with-approved-music.wav"></audio>'''+''.join(rows)+'</html>'
(B/'index.html').write_text(page)
print('Manifest and audition page complete',flush=True)
