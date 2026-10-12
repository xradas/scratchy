#!/usr/bin/env python3
"""Reproducible local-only CC0 foley rendering; no source downloading or audition approval."""
import pathlib,subprocess,json,hashlib,array,math,shutil,re,html
B=pathlib.Path(__file__).resolve().parents[1];D=B/'concepts/pickups-rooms-v6/audio';A=B/'assets/audio/pickups-v6'
for x in [D,D/'originals',D/'provenance',D/'dry',D/'stems',D/'auditions',D/'preservation',A]:x.mkdir(parents=True,exist_ok=True)
F=['ffmpeg','-hide_banner','-nostdin','-y']
def run(a):
 p=subprocess.run(a,capture_output=True,text=True)
 if p.returncode:raise RuntimeError(p.stderr)
 return p.stderr
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def probe(p):return json.loads(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration:stream=channels,sample_rate,codec_name','-of','json',str(p)]))
def ff(src,dst,start=0,dur=None,filters=''):
 a=F+['-i',str(src),'-ss',str(start)]
 if dur:a+=['-t',str(dur)]
 if filters:a+=['-af',filters]
 run(a+['-ar','48000','-ac','1','-c:a','pcm_s16le',str(dst)])
def normalize(src,dst,target):
 t=run(F+['-i',str(src),'-af','volumedetect','-f','null','-']);pk=float(re.search(r'max_volume: ([\-0-9.]+) dB',t)[1]);ff(src,dst,filters=f'volume={target-pk}dB')
def mix(events,out,duration=None):
 a=F.copy();g=[]
 for i,(p,t,v) in enumerate(events):
  a+=['-i',str(p)];g.append(f'[{i}:a]aformat=channel_layouts=mono,volume={v},adelay={round(t*1000)}[e{i}]')
 tail=f',apad,atrim=duration={duration}' if duration else ''
 g.append(''.join(f'[e{i}]' for i in range(len(events)))+f'amix=inputs={len(events)}:normalize=0{tail}[out]');run(a+['-filter_complex',';'.join(g),'-map','[out]','-ar','48000','-ac','1','-c:a','pcm_s16le',str(out)])
def ogg(p,dst=None):run(F+['-i',str(p),'-c:a','libvorbis','-q:a','6',str(dst or p.with_suffix('.ogg'))])
def onset(p):
 a=array.array('f');a.frombytes(subprocess.check_output(['ffmpeg','-v','error','-i',str(p),'-ar','48000','-ac','1','-f','f32le','-']));pk=max(abs(x) for x in a);return max(0,next(i for i,x in enumerate(a) if abs(x)>pk*.1)/48000-.004)
# Preserve original 48 cue resources and source bytes before additive registration.
pres=D/'preservation'
if not (pres/'profile-before.tres').exists():
 shutil.copy2(B/'resources/combat_audio.tres',pres/'profile-before.tres')
 hashes={str(p.relative_to(B)):sha(p) for p in (B/'assets/audio').rglob('*') if p.is_file() and p.suffix in ['.ogg','.wav','.flac','.mp3']}
 (pres/'runtime-before.json').write_text(json.dumps(hashes,indent=2)+'\n')
# Each source is an untouched local archive extraction already accompanied by CC0 evidence.
meta=json.loads((B/'concepts/audio-v3/manifest.json').read_text());sources=[]
for fn in ['metal_button_press1.wav','metal_button_press2.wav','metal_interaction1.wav','metal_interaction2.wav','metal_swing1.wav','wood_hit_01.ogg','metal_hit_03.ogg']:
 metal=fn.endswith('.wav');original=B/('concepts/audio-v2/originals/metal_interactions/' if metal else 'concepts/audio-v3/originals/rubberduck/')/fn
 dst=D/'originals'/fn;shutil.copy2(original,dst)
 template=next(s for s in meta['sources'] if s['id']==('click' if metal else 'dry-'+pathlib.Path(fn).stem))
 evidence=[]
 for rel in template['license_evidence']:
  ep=B/'concepts/audio-v3'/rel;target=D/'provenance'/ep.name;shutil.copy2(ep,target);evidence.append({'file':str(target.relative_to(D)),'sha256':sha(target)})
 sources.append({'id':pathlib.Path(fn).stem,'title':template['title'],'creator':template['creator'],'source_url':template['source_url'],'license':'CC0 1.0','license_url':template['license_url'],'existing_local_original':str(original.relative_to(B)),'original':str(dst.relative_to(D)),'sha256':sha(dst),'license_evidence':evidence,'technical':probe(dst)})
# Layer source, excerpt duration, playback ratio, delay, relative gain.
spec={
 'pistol':(-17,[('metal_button_press2',.08,1.1,0,1),('metal_button_press2',.07,1.16,.065,.62)],'Light paired cartridge clicks.'),
 'shells':(-17,[('metal_interaction1',.115,.88,0,1),('metal_interaction1',.085,.94,.085,.7)],'Lower paired shell-like object clunks.'),
 'rivets':(-18,[('metal_button_press1',.06,1.22,0,1),('metal_button_press1',.055,1.3,.04,.68),('metal_button_press1',.055,1.35,.08,.5)],'Tight three-click fastener receipt.'),
 'rockets':(-16,[('metal_interaction2',.24,.78,0,1)],'Single weighty short metal latch.'),
 'health':(-18,[('wood_hit_01',.11,1.08,0,1),('wood_hit_01',.09,1.23,.08,.42)],'Soft dry object taps, without wet or medical beep layers.'),
 'armor':(-17,[('metal_hit_03',.22,1.10,0,1)],'Short plate-like metal acknowledgment.'),
 'brass_key':(-17,[('metal_swing1',.13,1.22,0,1)],'High short physical metal key chink.'),
 'red_key':(-17,[('metal_swing1',.13,.94,0,1),('metal_button_press1',.10,1.08,.10,.58)],'Lower key chink followed by a compact latch click.'),
 'weapon':(-16,[('metal_interaction2',.19,.95,0,1),('metal_button_press2',.12,.88,.125,.52)],'Distinct weighty mechanism-and-latch acquisition receipt.')}
source_by_id={s['id']:s for s in sources};cues={}
for kind,(target,layers,desc) in spec.items():
 key='pickup_'+kind;ev=[];dry_ev=[];edits=[]
 for i,(sid,dur,pitch,delay,gain) in enumerate(layers):
  src=D/source_by_id[sid]['original'];start=onset(src);raw=D/'stems'/f'{key}-{i}-raw.wav';ff(src,raw,start,dur)
  dry=D/'stems'/f'{key}-{i}-dry.wav';normalize(raw,dry,-12);dry_ev.append((dry,delay,gain))
  fx=D/'stems'/f'{key}-{i}-fx.wav';filters=f'asetrate=48000*{pitch},aresample=48000,highpass=f=100,lowpass=f=7200';ff(raw,fx,filters=filters)
  d=float(probe(fx)['format']['duration']);tail=D/'stems'/f'{key}-{i}-tail.wav';fade=min(.025,d*.25);ff(fx,tail,filters=f'afade=t=in:d=0.002,afade=t=out:st={d-fade}:d={fade}')
  norm=D/'stems'/f'{key}-{i}-norm.wav';normalize(tail,norm,-12);ev.append((norm,delay,gain))
  edits.append({'source_id':sid,'excerpt_start_seconds':start,'excerpt_duration_seconds':dur,'playback_ratio':pitch,'filter_chain':filters,'edge_fades_seconds':[.002,fade],'delay_seconds':delay,'layer_gain':gain})
 tmp=D/'stems'/f'{key}-mix.wav';mix(ev,tmp);out=A/f'{key}.wav';normalize(tmp,out,target);ogg(out)
 dry=D/'dry'/f'{key}.wav';mix(dry_ev,tmp);normalize(tmp,dry,target)
 length=max(float(probe(dry)['format']['duration']),float(probe(out)['format']['duration']));ab=D/'auditions'/f'{key}-dry-designed.wav';mix([(dry,.2,1),(out,.65+length,1)],ab,2*length+1);ogg(ab)
 t=run(F+['-i',str(out.with_suffix('.ogg')),'-af','loudnorm=I=-19:TP=-3:LRA=11:print_format=json','-f','null','-']);j=json.loads(t[t.rfind('{'):t.rfind('}')+1]);lv={}
 for k,label in [('input_i','integrated_lufs'),('input_tp','true_peak_dbtp')]:
  v=float(j[k]);lv[label]=v if math.isfinite(v) else None
 cues[key]={'item_kind':kind,'runtime':'res://'+str(out.with_suffix('.ogg').relative_to(B)),'runtime_sha256':sha(out.with_suffix('.ogg')),'wav':str(out.relative_to(B)),'wav_sha256':sha(out),'bus':'UI','spatial':False,'gain_db':0,'description':desc,'edits':edits,'technical':probe(out),'levels_ogg':lv,'dry':str(dry.relative_to(D)),'dry_sha256':sha(dry),'audition':str(ab.relative_to(D)),'audition_sha256':sha(ab),'audition_ogg':str(ab.with_suffix('.ogg').relative_to(D)),'audition_ogg_sha256':sha(ab.with_suffix('.ogg'))}
 print('Rendered',key,probe(out)['format']['duration'],flush=True)
a=D/'auditions/pickup-types-10s.wav';mix([(A/(key+'.wav'),.35+i,1) for i,key in enumerate(cues)],a,10);ogg(a)
m={'date':'2026-10-12','status':'Designed local CC0 candidates; technical validation only, no listening approval','sources':sources,'cues':cues,'audition_order':list(cues),'audition':{'file':str(a.relative_to(D)),'sha256':sha(a),'ogg_file':str(a.with_suffix('.ogg').relative_to(D)),'ogg_sha256':sha(a.with_suffix('.ogg'))},'event_contract':'Stage.collect emits exactly one item_collected AFTER accepted state mutation. item_kind is canonical pistol/shells/rivets/rockets/health/armor/brass_key/red_key/weapon; pickup_id is the collected node instance ID; amount is actual accepted ammo/health/armor delta (key=1; ownership-only weapon=0); new_weapon records an ownership grant. Saturated owned weapon bait can trigger its trap/consume the lure but produces no receipt. ammo_added and weapon_granted are NOT audio triggers.','preservation':'All previous runtime source bytes remain untouched; 48 prior profile cues retain values and stream registrations.','listening_status':'No subjective listening or in-game stereo capture claimed.'}
(D/'manifest.json').write_text(json.dumps(m,indent=2)+'\n')
(D/'README.md').write_text('''# Dry pickup receipts\n\nNine short physical receipt cues, UI bus, nonspatial and pausable. Open index.html for the 10-second type sequence and source-excerpt/designed A/Bs. No synthetic or wet layers, no music changes. These are listening candidates.\n\nCC0 sources: Iwan “qubodup” Gabovitch, [Metal Interactions](https://opengameart.org/content/metal-interactions), and rubberduck, [100 CC0 metal and wood SFX](https://opengameart.org/content/100-cc0-metal-and-wood-sfx). Selected originals and existing downloaded license HTML are copied unchanged here; hashes, source paths, creator, excerpts, filters and exported files are in manifest.json. No sourcing or downloads performed for this pass.\n\nOnly item_collected produces a receipt after accepted gameplay change. Low-level ammo_added/weapon_granted events remain inventory events. Full, duplicate, paused and dead collection attempts are silent; full owned saturated bait retains trap behavior without a receipt. Aliases brass/red canonicalize to brass_key/red_key.\n\n48 prior cues remain registered unchanged. New cues are mono48kHz PCM/Vorbis, approximately -16 to -18dBFS peak, with no added reverb. UI presentation stays under the same gameplay pause/mute/restart ownership contract. Short LUFS are not a listening judgment.\n''')
page='<meta charset="utf-8"><title>Dry pickup receipts</title><style>body{background:#151919;color:#dde6e0;font:16px system-ui;margin:30px auto;max-width:850px}audio{display:block;width:100%;margin:12px 0}section{border-top:1px solid #566;padding:18px 0}a{color:#bbddcf}</style><h1>Dry pickup receipts</h1><p>New local recording candidates. Existing combat cues and music remain unchanged. Technical checks do not constitute listening approval.</p><p>Sequence: pistol · shells · rivets · rockets · health · armor · brass key · red key · weapon.</p><audio controls src="auditions/pickup-types-10s.ogg"></audio><p><a href="manifest.json">Source and edit ledger</a> · <a href="README.md">Credits and event contract</a></p>'
for key,c in cues.items():page+=f'<section><h2>{html.escape(key)}</h2><p>{html.escape(c["description"])}</p><p>A/B: source excerpt then designed</p><audio controls preload="none" src="{c["audition_ogg"]}"></audio></section>'
(D/'index.html').write_text(page)
# Add profile resources using stable IDs, preserving all previous text/values.
p=B/'resources/combat_audio.tres';txt=p.read_text()
if 'identifier = &"pickup_pistol"' not in txt:
 ext=''.join(f'[ext_resource type="AudioStream" path="{c["runtime"]}" id="pickup_{kind}"]\n' for kind,c in ((c['item_kind'],c) for c in cues.values()))
 pos=txt.index('[sub_resource');txt=txt[:pos]+ext+'\n'+txt[pos:]
 sub=''.join(f'[sub_resource type="Resource" id="Pickup_{c["item_kind"]}"]\nscript = ExtResource("1_ch4yb")\nidentifier = &"{key}"\nbus = &"UI"\nvariations = Array[AudioStream]([ExtResource("pickup_{c["item_kind"]}")])\nspatial = false\n\n' for key,c in cues.items())
 txt=txt.replace('[resource]\n',sub+'[resource]\n')
 txt=re.sub(r'^(cues = .*?)\]\)$',lambda match:match[1]+', '+', '.join(f'SubResource("Pickup_{c["item_kind"]}")' for c in cues.values())+'])',txt,flags=re.M)
 p.write_text(txt)
