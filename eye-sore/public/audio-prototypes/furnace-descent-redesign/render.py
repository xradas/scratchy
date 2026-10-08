#!/usr/bin/env python3
"""Offline candidate production only. Requires pinned numpy/scipy and ffmpeg."""
from pathlib import Path
import hashlib,json,math,re,subprocess,wave
import numpy as np
from scipy.signal import butter,sosfilt,resample_poly
from scipy.io import wavfile
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'public/audio-prototypes/furnace-descent-redesign'
SRC=ROOT/'public/audio-sources/free-firearm-library'
SR=44100
rng=np.random.default_rng(60427)
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
 ceiling_trim=min(1.,10**(-3.0/20)/max(max(abs(x)),1e-12));x*=ceiling_trim
 p=OUT/(name+'.wav');wavfile.write(p,SR,np.round(x*32767).astype(np.int16))
 # Meter delivered PCM, not an unquantized pre-export signal.
 delivered=wavfile.read(p)[1].astype(float)/32768
 r={'file':p.name,'event':event,'duration_seconds':round(len(x)/SR,6),'format':'mono PCM_s16le 44100 Hz','loop':loop,'loop_start_frame':0 if loop else None,'loop_end_exclusive_frame':len(x) if loop else None,'seed':60427,'notes':notes,'requested_rms_dbfs':target,'uniform_source_normalization_gain_db':round(20*np.log10(g),6),'uniform_ceiling_trim_db':round(20*np.log10(ceiling_trim),6),'matching_window_seconds':window,**metrics(delivered),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
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

# Infernal descent: dry physical release bodies, not the old sine+metal+hiss recipe.
weapons={}
for v in range(3):
 for name,source_name,d,freqs,decays,core in [
  ('ember_pistol',['ppq-pistol.wav','ppq-pistol-b.wav','ppq-pistol-c.wav'][v],.31,[211,389,733],[.043,.024,.009],.82),
  ('rivet_shotgun',['mossberg-shotgun.wav','mossberg-shotgun-b.wav','mossberg-shotgun-c.wav'][v],.48,[137,251,463,881],[.061,.049,.024,.011],1.1),
  ('arc_cannon',None,.55,[173,317,577,1087],[.065,.049,.039,.013],.9)]:
  x=np.zeros(round(d*SR))
  if source_name:
   raw=source(source_name);t=np.arange(len(raw))/SR;add(x,raw*np.exp(-t/(.07 if name=='rivet_shotgun' else .045)),0,.70)
  else:
   # Arc impulse has nonperiodic stepped discharge and resonant cage, not slowed rifle.
   add(x,pulse(.12,.028,350,6800),0,.24)
   add(x,pulse(.045,.009,1800,7400),.010,.10)
  add(x,modal(d,[f*(1+.009*(v-1)) for f in freqs],decays),.001,core)
  add(x,pulse(.12,.025 if name=='rivet_shotgun' else .01,650,4900),.003,.13 if name=='rivet_shotgun' else .05)
  weapons[(name,v)]=save(f'{name}_release_{v+1}',x,'ShotEmitted','Correctly selected CC0 crack only for pistol/spread; original damped cage/stock modes, coarse impulse. Arc uses new nonperiodic discharge, no rifle sample, sine sub or reverb.',-25,window=.25)
  y=np.zeros(round(.18*SR));add(y,pulse(.06,.012,220,2300),0,.12);add(y,modal(.10,[337,701,1499],[.019,.011,.004]),.029,.12)
  save(f'{name}_return_{v+1}',y,'WeaponActionReturn','Separate physical latch/counterload return; no invented reload/ready state.',-32,window=.18)

# Creature identities: four distinct excitation/time grammars; type IDs match engine.
for type_id in range(4):
 for v in range(2):
  d=.24;x=np.zeros(round(d*SR));t=time(d)
  if type_id==0: # coarse dry throat/crawl; localized no universal roar
   x=band(noise(len(t)),190,1000)*(1-np.exp(-t/.008))*np.exp(-t/.21)*(.7+.3*np.sin(2*np.pi*(29+v*2)*t)**2)*.20
   add(x,pulse(.08,.019,800,3500),.19,.10)
  elif type_id==1: # caster hand/clothing scrape then held breath, not falling warning tone
   add(x,pulse(.12,.039,1100,3900),0,.09)
   tt=time(.43);y=(band(noise(len(tt)),350,850)+.3*band(noise(len(tt)),1400,2300))*(1-np.exp(-tt/.016))*np.minimum(1,(.43-tt)/.08)*.15
   add(x,y,.055)
  elif type_id==2: # wraith disrupted flutter, short absence between phrases, no musical alarm
   for at,g in [(0,.11),(.07,.13),(.14,.085)]:add(x,pulse(.18,.065,740,3000),at,g)
  else: # brute loaded hide/stone contact, broad mid body
   add(x,pulse(.30,.105,100,680),0,.22);add(x,modal(.2,[139,263,487],[.056,.039,.014]),.12,.16)
  tell=save(f'enemy_{type_id}_tell_{v+1}',x,'EnemyTellBegin','Original procedural creature effort/contact, not a recorded voice. Preparing state only; 240ms source fits current ~260ms attack release marker if dispatched at state entry. Must not be started at release. Type0 throat;1 caster brace;2 flutter;3 grounded load.',-28,window=.24)
  x=np.zeros(round(.26*SR))
  add(x,pulse(.15,.029,[220,550,1100,120][type_id],[2000,4500,6100,1400][type_id]),0,.20)
  add(x,modal(.13,[[239,521],[433,917],[719,1493],[157,311]][type_id],[.025,.012]),.005,.16)
  save(f'enemy_{type_id}_attack_{v+1}',x,'EnemyReleaseCommitted','Compact type-specific actual attack accent. Not a preparing warning or damage guarantee.',-27,window=.25)
  x=np.zeros(round(.25*SR));add(x,pulse(.14,.031,120+type_id*90,1700+type_id*470),0,.20)
  if type_id in [1,3]:add(x,modal(.12,[281+type_id*47,651,1207],[.024,.011,.005]),.005,.12)
  save(f'enemy_{type_id}_hit_{v+1}',x,'ContactResolved','Type-specific contact/short pain texture; never promises attack canceled. Terminal hit must use death response instead.',-32,window=.25)
  x=np.zeros(round(.77*SR))
  add(x,pulse(.38,.105,100+type_id*70,1000+type_id*400),0,.12)
  if type_id==2:
   add(x,pulse(.28,.10,1300,4600),.19,.07) # wraith dispersal, not ground body
  else:
   add(x,pulse(.18,.048,90,1200),.23,.15 if type_id!=3 else .24)
   add(x,modal(.19,[171,337,727],[.041,.027,.009]),.41,.09)
  save(f'enemy_{type_id}_death_{v+1}',x,'DeathCommitted','Terminal loss of support/air, distinct from repeated hit; type2 disperses. Procedural, no actual vocal performer.',-30,window=.65)

# Sparse room layers; furnace itself is not a continuous loud hiss or tonal drone.
def seam(x,n=11025):
 a=np.linspace(0,1,n,endpoint=False);return np.concatenate([x[n:-n],x[-n:]*(1-a)+x[:n]*a])
t=time(9);room=np.zeros(len(t))
for at in [.43,1.97,4.62,7.81]:add(room,pulse(.085,.025,450,4600),at,.012);add(room,modal(.14,[503,1097],[.022,.009]),at,.006)
room+=band(noise(len(t)),280,1200)*.0007
save('room_hot_masonry_loop',seam(room),'WorldSourceLoop','Sparse cooled/heat-stressed masonry/ember contacts; almost quiet between events. Local room layer, not global infernal drone.',-42,window=8.5,loop=True)
room=np.zeros(len(t))
for at in [.73,3.6,6.81]:
 add(room,pulse(.16,.055,120,850),at,.012);add(room,modal(.12,[241,509,1103],[.022,.014,.007]),at+.04,.008)
save('room_chain_shaft_loop',seam(room),'WorldSourceLoop','Distant loaded chain/shaft impulses separated by silence, original procedural approximation; no motors/rollers/arcade sound.',-41,window=8.5,loop=True)

# Original infernal industrial score: measured groove, not foley masquerading as music.
bpm=112;beat=60/bpm;d=32*beat;score=np.zeros(round(d*SR))
def pluck(midi,d=.45):
 t=time(d);f=440*2**((midi-69)/12);y=sum(np.sin(2*np.pi*f*h*t)/h for h in [1,2,3,4,5]);y=np.tanh(y*.65)
 return y*(1-np.exp(-t/.003))*np.exp(-t/.16)
# Original riff structure, not any reference tune. Rests preserve dry cue space.
for b in range(8):
 root=[38,38,41,36,38,43,41,36][b]
 for at,n in [(0,root),(.75,root+7),(1.5,root+3),(2.75,root+12)]:
  if b==7 and at>1.5:continue
  add(score,pluck(n),(4*b+at)*beat,.055)
 for at in [0,2]:add(score,pulse(.17,.051,70,350),(4*b+at)*beat,.042)
 for at in [1,3]:add(score,pulse(.09,.021,550,3300),(4*b+at)*beat,.020)
 if b in [3,6]:add(score,pluck(root+19,.9),(4*b+2)*beat,.018)
score=save('score_furnace_descent_112bpm',score,'MusicCueAudition','Original 8-bar112 BPM driven distorted/plucked bass figure and broad dry percussion. Actual pitched score, not old furnace foley bed. Synth mockup, human listening pending.',-29,window=d)

# Cadence audition and one conservative whole-bus proof, recorded unity source gains.
for name,cad in [('ember_pistol',.50),('rivet_shotgun',.60),('arc_cannon',.85)]:
 x=np.zeros(round(6*SR))
 for j in range(6):add(x,weapons[(name,j%3)],.3+j*cad)
 save(name+'_six_shots',x,'OfflineCadenceAudition',f'Delivered dry shots unity, source variants1/2/3 twice, cadence {cad}s. No normalize-up or return/music concealment.',None,window=6)
proof=score.copy()
for fname,gain in [('room_hot_masonry_loop',-4),('room_chain_shaft_loop',-6)]:
 y=wavfile.read(OUT/(fname+'.wav'))[1].astype(float)/32768
 proof+=np.tile(y,math.ceil(len(proof)/len(y)))[:len(proof)]*10**(gain/20)
# Playback recipe evidence only; level at unity per-role file settings, no pump/limiter.
save('score_room_bus_proof',proof,'OfflineBusProof','Score0dB, masonry-4dB, chain shaft-6dB; static mix, no ducking or threat events. No assertion of audible quality.',None,window=d)
# Extension: two new families (IDs 4/5) without changing prior render order/sources.
for v in range(2):
 # Hookrunner: leather tension/contact and lifted hook load, then hard rake release.
 x=np.zeros(round(.24*SR));scrape=pulse(.16,.057,620,2300)
 tt=np.arange(len(scrape))/SR;scrape*=.55+.45*np.sin(2*np.pi*(36+v*4)*tt)**2
 add(x,scrape,0,.11)
 add(x,modal(.115,[237+v*11,517,1093],[.027,.013,.006]),.104,.28)
 add(x,pulse(.06,.012,150,1000),.151,.12)
 save(f'enemy_4_tell_{v+1}',x,'EnemyTellBegin','Hookrunner: taut overhead strap/hook loading, two grounded contact landmarks104/151ms. 240ms windup, not rake hit or vocal roar. Procedural.',-28,window=.24)
 x=np.zeros(round(.26*SR));add(x,pulse(.14,.034,600,3900),0,.20)
 add(x,modal(.17,[271,571+v*9,1237],[.038,.023,.011]),.001,.40)
 add(x,pulse(.065,.015,1600,6900),.014,.055)
 save(f'enemy_4_attack_{v+1}',x,'EnemyReleaseCommitted','Hookrunner: short gritty rake/release against physical hook body. Not confirmed player damage; actual contact owns hit.',-27,window=.25)
 x=np.zeros(round(.25*SR));add(x,pulse(.11,.032,160,1300),0,.24)
 add(x,modal(.10,[193,419,871],[.021,.010,.004]),.013,.13)
 save(f'enemy_4_hit_{v+1}',x,'ContactResolved','Hookrunner: damp leather/body contact plus hard harness edge; hurt does not promise interrupt.',-32,window=.25)
 x=np.zeros(round(.71*SR));add(x,pulse(.20,.073,120,840),0,.13)
 add(x,pulse(.18,.047,100,1450),.18,.23)
 add(x,modal(.24,[229,487,1043],[.043,.025,.009]),.20,.22)
 add(x,pulse(.12,.027,650,2800),.46,.065)
 save(f'enemy_4_death_{v+1}',x,'DeathCommitted','Hookrunner: support collapses then hook drops/scrapes once. No long roar, no duplicate rake attack.',-30,window=.65)
 # Bellower: uneven fan loading/contact pulses then compact hollow throat release.
 x=np.zeros(round(.24*SR));t=time(.24)
 fan=band(noise(len(t)),220,950)*(.3+.7*np.sin(2*np.pi*(23+v*2)*t)**2)*(1-np.exp(-t/.007))*np.exp(-t/.20)
 add(x,fan,0,.14)
 for at,g in [(.025,.13),(.087,.10),(.154,.075)]:add(x,modal(.06,[181,379,797],[.012,.008,.004]),at,g)
 save(f'enemy_5_tell_{v+1}',x,'EnemyTellBegin','Soot Bellower: uneven fan/hide loading plus brace contacts25/87/154ms, no steady motor or electronic alarm. 240ms prepared state.',-28,window=.24)
 x=np.zeros(round(.31*SR));t=time(.31)
 throat=(band(noise(len(t)),180,570)+.45*band(noise(len(t)),820,1500))*(1-np.exp(-t/.0015))*np.exp(-t/.074)
 add(x,throat,0,.28);add(x,modal(.15,[163,349,733],[.025,.016,.005]),.012,.15)
 save(f'enemy_5_attack_{v+1}',x,'EnemyReleaseCommitted','Soot Bellower: hollow short throat expulsion with loaded chest contact, distinct from fan tell. Procedural breath approximation, not performed vocal.',-27,window=.25)
 x=np.zeros(round(.25*SR));add(x,pulse(.16,.041,100,760),0,.21)
 add(x,pulse(.07,.017,700,2200),.016,.05)
 save(f'enemy_5_hit_{v+1}',x,'ContactResolved','Soot Bellower: broad damp soot-hide contact, no hook/enamel resonance. Hurt is not attack cancellation.',-32,window=.25)
 x=np.zeros(round(.78*SR));t=time(.44)
 empty=band(noise(len(t)),140,640)*(1-np.exp(-t/.004))*np.exp(-t/.14)
 add(x,empty,0,.16);add(x,pulse(.26,.072,90,970),.24,.23)
 add(x,modal(.20,[147,293,601],[.040,.023,.009]),.32,.095)
 save(f'enemy_5_death_{v+1}',x,'DeathCommitted','Soot Bellower: hollow air/support loss into heavy soft floor settle. No ringing hook fall or fan restart.',-30,window=.65)

# Root runtime now references IDs4/5 explicitly; export only these additions.
runtime=ROOT/'linux-game/assets/sounds/furnace-descent-redesign'
runtime.mkdir(parents=True,exist_ok=True)
import shutil
for type_id in [4,5]:
 for event in ['tell','attack','hit','death']:
  for v in range(2):
   filename=f'enemy_{type_id}_{event}_{v+1}.wav'
   shutil.copyfile(OUT/filename,runtime/filename)

manifest={'version':2,'direction':'Eye Sore infernal industrial descent','status':'Fresh produced candidate files; unapproved and not human-ear validated; no runtime integration','sample_rate':SR,'seed':60427,'script_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'source_provenance':sources,'assets':records,'rights':'New procedural signals/composition; pistol/spread crack from retained local CC0 firearm source provenance. No proprietary game sample/music.','dependencies':{'numpy':np.__version__,'scipy':__import__('scipy').__version__,'ffmpeg':subprocess.run(['ffmpeg','-version'],capture_output=True,text=True).stdout.splitlines()[0]},'limitations':['Creature efforts/room layers are original procedural approximations, not performed voices or recordings.','Headroom/source metrics do not prove perceived weight.','Current engine event integration and mixer transient handling still require separate implementation.','No builds/playback tests performed.']}
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');print(f'Rendered {len(records)} new candidate WAVs to {OUT}')
