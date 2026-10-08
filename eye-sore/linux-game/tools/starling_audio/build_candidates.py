#!/usr/bin/env python3
"""Offline candidate production only. Requires pinned numpy/scipy and ffmpeg."""
from pathlib import Path
import hashlib,json,math,re,subprocess,wave
import numpy as np
from scipy.signal import butter,sosfilt,resample_poly
from scipy.io import wavfile
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'public/audio-prototypes/starling-last-lap'
SRC=ROOT/'public/audio-sources/free-firearm-library'
SR=44100
rng=np.random.default_rng(41791)
records=[]; sources={}

def hp(x,f): return sosfilt(butter(2,f,'highpass',fs=SR,output='sos'),x)
def lp(x,f): return sosfilt(butter(2,f,'lowpass',fs=SR,output='sos'),x)
def band(x,a,b): return lp(hp(x,a),b)
def noise(n): return rng.standard_normal(n)
def time(d): return np.arange(round(d*SR))/SR

def pulse(d,decay,low,high):
 t=time(d);return band(noise(len(t)),low,high)*(1-np.exp(-t*SR/14))*np.exp(-t/decay)
def modal(d,freqs,decays):
 # Broad wooden-shell modes, no pure sub-bass thump. Impulsively driven/damped.
 t=time(d);x=np.zeros(len(t))
 for f,tau in zip(freqs,decays):
  x+=np.sin(2*np.pi*f*t+0.04)*np.exp(-t/tau)/len(freqs)
 return x*(1-np.exp(-t/.00035))
def add(x,y,start=0,gain=1):
 i=round(start*SR); k=min(len(y),len(x)-i)
 if k>0:x[i:i+k]+=y[:k]*gain

def source(name):
 p=SRC/name;rate,x=wavfile.read(p);sources[name]={'path':str(p.relative_to(ROOT)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'license':'CC0 as identified by local README and FPS Asset Kit / Free Firearm Sound Library; original source attribution retained','url':'https://opengameart.org/content/the-free-firearm-sound-library'}
 if x.ndim>1:x=x[:,0]
 if np.issubdtype(x.dtype,np.integer):x=x.astype(float)/max(abs(np.iinfo(x.dtype).min),np.iinfo(x.dtype).max)
 if rate!=SR:x=resample_poly(x,SR,rate)
 # strongest early blast-energy region, use 2ms pre-onset; record selected region.
 energy=np.convolve(x*x,np.ones(220)/220,'same')
 peak=int(np.argmax(energy[:min(len(x),3*SR)]));threshold=energy[peak]*.12
 start=peak
 while start>max(0,peak-int(.05*SR)) and energy[start]>threshold:start-=1
 start=max(0,start-int(.002*SR));sources[name]['selected_start_seconds']=round(start/SR,6)
 y=x[start:start+int(.42*SR)].copy();y=hp(y,65);y/=max(np.max(np.abs(y)),1e-9)
 return y

def metrics(x):
 peak=float(np.max(np.abs(x)));rms=float(np.sqrt(np.mean(x*x)))
 n=min(len(x),int(.25*SR));active=float(np.sqrt(np.mean(x[:n]**2)))
 inds=np.flatnonzero(abs(x)>max(peak*.025,1e-6));on=int(inds[0]) if len(inds) else None
 return {'sample_peak_dbfs':round(20*np.log10(max(peak,1e-12)),3),'rms_full_dbfs':round(20*np.log10(max(rms,1e-12)),3),'rms_first_250ms_dbfs':round(20*np.log10(max(active,1e-12)),3),'onset_frame_threshold_2_5_percent_peak':on,'onset_ms_threshold':round(on*1000/SR,3) if on is not None else None}

def save(name,x,event,notes,target=-19,window=.25,loop=False):
 x=hp(x,25);x[-min(180,len(x)):]*=np.linspace(1,0,min(180,len(x))) if not loop else 1
 active=x[:min(len(x),round(window*SR))];g=1. if target is None else 10**(target/20)/max(np.sqrt(np.mean(active**2)),1e-9)
 x*=g
 # All files preserve crest; normalization ceiling may lower RMS. Record actual.
 ceiling_trim=min(1.,10**(-1.5/20)/max(max(abs(x)),1e-12));x*=ceiling_trim
 p=OUT/(name+'.wav');wavfile.write(p,SR,np.round(x*32767).astype(np.int16))
 # Meter delivered PCM, not an unquantized pre-export signal.
 delivered=wavfile.read(p)[1].astype(float)/32768
 r={'file':p.name,'event':event,'duration_seconds':round(len(x)/SR,6),'format':'mono PCM_s16le 44100 Hz','loop':loop,'loop_start_frame':0 if loop else None,'loop_end_exclusive_frame':len(x) if loop else None,'seed':41791,'notes':notes,'requested_rms_dbfs':target,'uniform_source_normalization_gain_db':round(20*np.log10(g),6),'uniform_ceiling_trim_db':round(20*np.log10(ceiling_trim),6),'matching_window_seconds':window,**metrics(delivered),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
 proc=subprocess.run(['ffmpeg','-hide_banner','-i',str(p),'-af','ebur128=peak=true','-f','null','-'],capture_output=True,text=True)
 match=re.findall(r'I:\s*([\-\d.]+) LUFS',proc.stderr); true=re.findall(r'Peak:\s*([\-\d.]+) dBFS',proc.stderr)
 r['integrated_lufs_ffmpeg']=float(match[-1]) if match and len(x)>=round(.4*SR) and float(match[-1])>-69.9 else None;r['true_peak_dbfs_ffmpeg']=float(true[-1]) if true else None
 r['loudness_note']='EBU R128 gated integrated value on short cues is descriptive only; first-250ms RMS used for candidate matching, listening remains pending.'
 records.append(r);return delivered

def weapon(kind,v):
 names=['ppq-pistol.wav','ppq-pistol-b.wav','ppq-pistol-c.wav'] if kind=='pistol' else ['mossberg-shotgun.wav','mossberg-shotgun-b.wav','mossberg-shotgun-c.wav']
 dry=source(names[v]);d=.36 if kind=='pistol' else .52;x=np.zeros(round(d*SR))
 # Correctly selected broad recorded impulse, new wooden stock resonance and coarse granular contact.
 t=np.arange(len(dry))/SR;dry*=np.exp(-t/(.09 if kind=='pistol' else .15));add(x,dry,gain=.85)
 f=[163,271,437,713] if kind=='pistol' else [119,193,319,521,827]
 add(x,modal(d,[z*(1+.013*(v-1)) for z in f],[.035,.06,.045,.02]+([.018] if kind!='pistol' else [])),.002,.65 if kind=='pistol' else .95)
 add(x,pulse(d,.014 if kind=='pistol' else .035,420,6100),.0008,.13 if kind=='pistol' else .21)
 return x

# STARLING: independent compact crack and broad deck/body recipes; isolated return cues.
shots={}
for v in range(3):
 raw=source(['ppq-pistol.wav','ak47-rifle-b.wav','ppq-pistol-c.wav'][v])
 x=np.zeros(round(.27*SR));tt=np.arange(len(raw))/SR
 add(x,raw*np.exp(-tt/.040),0,.95)
 add(x,modal(.22,[187,347,613,1019],[.035,.027,.017,.011]),.001,.9)
 add(x,pulse(.055,.010,850,7200),0,.085)
 shots[('carbine',v)]=save(f'carbine_release_{v+1}',x,'ShotEmitted','CC0 firearm attack plus original tight wooden chassis modes. Source variety: PPQ, AK, PPQ; no sub oscillator, hiss or reverb.',-23.0)
 raw=source(['mossberg-shotgun.wav','mossberg-shotgun-b.wav','mossberg-shotgun-c.wav'][v]);x=np.zeros(round(.47*SR));tt=np.arange(len(raw))/SR
 add(x,raw*np.exp(-tt/.085),0,.80)
 # Two physical deck/stock facets fused into a single accepted release; no second damaging shot.
 add(x,pulse(.09,.023,550,6700),.0003,.19)
 add(x,modal(.32,[131,223,379,641,1091],[.065,.045,.039,.018,.010]),.002,1.0)
 add(x,modal(.19,[177,311,503],[.028,.023,.016]),.012,.42)
 shots[('deck_shotgun',v)]=save(f'deck_shotgun_release_{v+1}',x,'ShotEmitted','New CC0 shotgun take; independently designed broad deck impulse and offset stock body (12ms), one release. No return baked in.',-23.0)
 for k in ['carbine','deck_shotgun']:
  x=np.zeros(round(.18*SR));add(x,pulse(.045,.008,900,4000),0,.12);add(x,modal(.075,[410+v*9,817,1639],[.011,.008,.005]),.024,.17)
  if k=='deck_shotgun':add(x,pulse(.07,.014,230,2200),.074,.23)
  save(f'{k}_return_{v+1}',x,'WeaponActionReturn','Separate short spring/latch return; timing must follow actual art/action, not a promise of reload or ready.',-28)

for v in range(3):
 x=np.zeros(round(.72*SR))
 for j,at in enumerate([0,.082,.165,.235]):
  add(x,pulse(.04,.007,700,3800),at,.12)
  add(x,modal(.07,[327+v*8+j*17,683,1411],[.012,.009,.005]),at+.003,.26)
 add(x,pulse(.08,.014,160,1700),.38,.18);add(x,modal(.15,[221,481,911],[.028,.017,.008]),.40,.24)
 save(f'lap_counter_tell_{v+1}',x,'EnemyTellBegin','Original split-flap clacks 0/82/165/235ms, latch/aim 380–400ms. Mechanical warning, no beep. Procedural mockup, not recorded machine.',-23,window=.65)
 x=np.zeros(round(.22*SR));add(x,modal(.12,[467,997,1883],[.021,.015,.009]),0,.32);add(x,pulse(.07,.014,1300,6500),.004,.09)
 save(f'lap_counter_release_{v+1}',x,'EnemyReleaseCommitted','Short token/latch ejection, distinct from flap preparation; one actual projectile release.',-22)
 x=np.zeros(round(.8*SR))
 for at,g in [(0,.30),(.17,.17),(.39,.11)]:add(x,pulse(.17,.034,180,2600),at,g);add(x,modal(.19,[191,397,811],[.043,.027,.012]),at+.002,g)
 save(f'lap_counter_collapse_{v+1}',x,'DeathCommitted','Mechanical lost support; descending contact strength, no alarm/repeated release.',-25,window=.65)
 x=np.zeros(round(.75*SR));roller=band(noise(round(.27*SR)),160,1300);t=np.arange(len(roller))/SR;roller*=np.sin(np.pi*np.minimum(1,t/.27))**2*(.65+.35*np.sin(2*np.pi*(38+v*3)*t)**2)
 add(x,roller,0,.06);add(x,pulse(.22,.075,340,2100),.22,.15);add(x,modal(.17,[141,281,541],[.024,.018,.009]),.43,.15)
 save(f'bumper_hound_tell_{v+1}',x,'EnemyTellBegin','Wheel-brake scrub then foam compression/ground set; no shrill tire squeal or animal roar. Procedural.',-24,window=.65)
 x=np.zeros(round(.33*SR));add(x,pulse(.24,.055,120,1800),0,.19);add(x,pulse(.12,.04,600,3000),.055,.07)
 save(f'bumper_hound_rush_{v+1}',x,'EnemyReleaseCommitted','Compact grounded roller push/foam release; does not imply homing or a long charge.',-23)
 x=np.zeros(round(.68*SR));add(x,pulse(.24,.075,110,900),0,.25);add(x,modal(.22,[173,339,691],[.026,.014,.008]),.14,.11);add(x,pulse(.16,.03,400,1400),.37,.06)
 save(f'bumper_hound_collapse_{v+1}',x,'DeathCommitted','Foam body loses support, axle settles; terminal timbre distinct from mechanical Counter.',-26,window=.55)

# Periodic seam bridge. These are world sound only, never score stems.
def seamless(x,n=11025):
 a=np.linspace(0,1,n,endpoint=False);return np.concatenate([x[n:-n],x[-n:]*(1-a)+x[:n]*a])
t=time(8);x=band(noise(len(t)),110,650)*(.008+.003*np.sin(2*np.pi*t/4))
# Roller/rink cavity made from colored turbulent contact, not sustained pure tone.
save('world_distant_roller_loop',seamless(x),'WorldSourceLoop','Crowdless distant roller/cavity hum; original colored noise, no voices/music. 7.5s loop.',-37,window=7.5,loop=True)
x=np.zeros(len(t))
for at in [.8,.87,2.7,2.78,5.6,5.68]:add(x,modal(.065,[351,727,1433],[.011,.007,.004]),at,.014);add(x,pulse(.03,.004,1200,3600),at,.004)
for at in [1.8,4.5,6.5]:add(x,pulse(.05,.006,900,3200),at,.004)
save('world_splitflap_light_loop',seamless(x),'WorldSourceLoop','Sparse background flap/light-relay contacts; rhythm deliberately irregular and unlike enemy tell. No electric beep or score motif.',-38,window=7.5,loop=True)

# Separate original score audition: 8 bars at 140 BPM, mono-compatible plucks/drums.
bpm=140;beat=60/bpm;d=32*beat;x=np.zeros(round(d*SR))
def note(freq,d=.3):
 t=time(d);return (np.sin(2*np.pi*freq*t)+.28*np.sin(2*np.pi*freq*2*t)+.12*np.sin(2*np.pi*freq*3*t))*(1-np.exp(-t/.003))*np.exp(-t/.085)
# Newly authored contour, alternating syncopated question/answer with last-bar breathing space.
phrase=[(0,62),(.75,65),(1.5,69),(2.75,67),(4.0,60),(5.25,64),(6.0,67),(6.75,65)]
for block in range(4):
 base=block*8
 for pos,midi in phrase:
  if block==3 and pos>4:continue
  add(x,note(440*2**((midi-69)/12)),(base+pos)*beat,.12)
 for j in range(8):
  if block==3 and j>4:continue
  add(x,note(440*2**((38+(0 if block%2==0 else 3)-69)/12),.22),(base+j)*beat,.18)
  if j%2==0:add(x,pulse(.14,.035,70,480),(base+j)*beat,.09)
  else:add(x,pulse(.10,.02,1100,5300),(base+j)*beat,.028)
score=save('score_last_lap_140bpm_audition',x,'MusicCueAudition','Original 8-bar 140 BPM plucked retro propulsion; rendered mono synth mockup, no borrowed tune/sample. Separate from ambience, NOT adaptive game score.',-25,window=d)

# Bounded material contacts, separately owned from release/death.
for v in range(3):
 x=np.zeros(round(.25*SR));add(x,pulse(.07,.011,550,4200),0,.13)
 add(x,modal(.14,[293+v*17,617+v*13,1271],[.026,.013,.007]),.001,.3)
 add(x,pulse(.045,.008,1300,5800),.008,.035)
 save(f'lap_counter_contact_{v+1}',x,'ContactResolved','Token/contact against wood-enamel flap chassis. Compact hard attack, no death/tell. Original procedural contact.',-29,window=.25)
 x=np.zeros(round(.25*SR));add(x,pulse(.14,.033,160,1500),0,.22)
 add(x,modal(.09,[179+v*9,389,811],[.012,.009,.005]),.016,.095)
 add(x,pulse(.05,.009,600,2400),.025,.025)
 save(f'bumper_hound_contact_{v+1}',x,'ContactResolved','Soft foam/rubber thud plus short wheel housing contact, not a gun or pain promise. Original procedural contact.',-29,window=.25)

# Complete firing fixtures: already matched release at unity plus separate quiet return.
# Cosmetic delay is explicit and provisional, never a new ammo/projectile event.
for k,delay in [('carbine',.095),('deck_shotgun',.22)]:
 for v in range(3):
  ret=wavfile.read(OUT/f'{k}_return_{v+1}.wav')[1].astype(float)/32768
  x=np.zeros(max(len(shots[(k,v)]),round(delay*SR)+len(ret)))
  add(x,shots[(k,v)],0);add(x,ret,delay)
  save(f'{k}_complete_fire_{v+1}',x,'ShotEmitted_CompoundFixture',f'One matched release at unity plus existing return at unity delayed {delay*1000:.0f}ms. Provisional baked cosmetic timing for direct playback; never also dispatch separate return. Cosmetic timing not final art/mechanics agreement.',None,window=.25)

# Static music/world bus proof, no dynamic ducking or threats added.
# Score unity with a shallow broad tell-band carve; world loops deliberately quiet.
score_carve=sosfilt(butter(2,[1500,3400],'bandstop',fs=SR,output='sos'),score)
score_bus=.65*score+.35*score_carve
proof=score_bus.copy()
for filename,gain_db in [('world_distant_roller_loop.wav',-6),('world_splitflap_light_loop.wav',-8)]:
 y=wavfile.read(OUT/filename)[1].astype(float)/32768
 tiled=np.tile(y,math.ceil(len(proof)/len(y)))[:len(proof)]
 proof+=tiled*10**(gain_db/20)
save('gameplay_music_world_bus_proof',proof,'OfflineBusProof','Score at 0dB, static 65% dry+35% 1.5–3.4kHz bandstop (at most ~3.7dB center carve); roller loop -6dB, flap/light loop -8dB. No dynamic ducking, added gain normalization or threat cue. Existing source files unaffected. Music dominance and warning space await human listening.',None,window=len(proof)/SR)

listen=[]
for num,k,cad in [(1,'carbine',.20),(2,'deck_shotgun',.60)]:
 x=np.zeros(round(6*SR))
 for j in range(12 if k=='carbine' else 8):add(x,shots[(k,j%3)],.4+j*cad)
 peak=float(np.max(np.abs(x)));ceiling=10**(-1.5/20);trim=min(1.,ceiling/max(peak,1e-12));x*=trim
 name=f'{num:02d}_{k}_cadence.wav';wavfile.write(OUT/name,SR,np.round(x*32767).astype(np.int16));listen.append({'number':num,'file':name,'cadence_seconds':cad,'uniform_mix_trim_db':round(20*np.log10(trim),6),'shot_first_250ms_rms_target_dbfs':-23.0,'first_shot_start_seconds':.4,'variant_order':[j%3+1 for j in range(12 if k=='carbine' else 8)],'note':'Delivered shots genuinely first-250ms RMS matched at -23dBFS; uniform recorded mix trim only if summed peaks exceed -1.5dBFS. No clipping/compression/recovery/music/ambience. Cadence provisional.'})
for num,k,end in [(3,'lap_counter','collapse'),(4,'bumper_hound','collapse')]:
 x=np.zeros(round(5*SR));seq=[(f'{k}_tell_1',.3),(f'{k}_'+('release' if k=='lap_counter' else 'rush')+'_1',1.20),(f'{k}_{end}_1',2.7)]
 for name,at in seq:y=wavfile.read(OUT/(name+'.wav'))[1].astype(float)/32768;add(x,y,at)
 name=f'{num:02d}_{k}_sequence.wav';wavfile.write(OUT/name,SR,np.round(x*32767).astype(np.int16));listen.append({'number':num,'file':name,'events':seq,'note':'Offline warning/release/collapse sequence, not runtime AI playback.'})
for num,name in [(5,'world_distant_roller_loop.wav'),(6,'world_splitflap_light_loop.wav'),(7,'score_last_lap_140bpm_audition.wav')]:listen.append({'number':num,'file':name,'note':'Individually review; score and ambience never share a source.'})
for row in listen:
 p=OUT/row['file'];row['sha256']=hashlib.sha256(p.read_bytes()).hexdigest()
 delivered=wavfile.read(p)[1].astype(float)/32768;row.update(metrics(delivered))
 if 'cadence_seconds' in row:
  offset=round(.4*SR);window=delivered[offset:offset+round(.25*SR)]
  row['first_shot_plus_overlap_250ms_rms_dbfs']=round(20*np.log10(max(np.sqrt(np.mean(window**2)),1e-12)),6)
  row['window_note']='First250ms file RMS is silence due to 400ms lead-in. Event-aligned window includes next carbine shot at 200ms; source matching uses isolated shots, not overlapping reel window.'
 proc=subprocess.run(['ffmpeg','-hide_banner','-i',str(p),'-af','ebur128=peak=true','-f','null','-'],capture_output=True,text=True)
 match=re.findall(r'I:\s*([\-\d.]+) LUFS',proc.stderr); true=re.findall(r'Peak:\s*([\-\d.]+) dBFS',proc.stderr)
 row['integrated_lufs_ffmpeg']=float(match[-1]) if match else None;row['true_peak_dbfs_ffmpeg']=float(true[-1]) if true else None
manifest={'version':2,'direction':'STARLING’S LAST LAP','status':'Produced, unapproved, no agent ear validation/runtime integration.','sample_rate':SR,'seed':41791,'script':str(Path(__file__).relative_to(ROOT)),'script_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'dependencies':{'numpy':np.__version__,'scipy':__import__('scipy').__version__,'ffmpeg':subprocess.run(['ffmpeg','-version'],capture_output=True,text=True).stdout.splitlines()[0]},'sources':sources,'assets':records,'listening_order':listen,'rights':'New mathematical signal designs and original score contour. Firearm inputs local CC0 with retained provenance. No proprietary-game asset/tune.','limitations':['Mechanical/creature/world cues are procedural mockups, not field recordings or performed voices.','RMS matching is not perceived-loudness certification.','Short-cue LUFS estimates descriptive only.','No game build/test or engine mixer playback.','White Hunger output is separate and rejected/unintegrated.']}
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');print(f'Produced {len(records)} dry cue/loop/score files plus four numbered reels in {OUT}')
