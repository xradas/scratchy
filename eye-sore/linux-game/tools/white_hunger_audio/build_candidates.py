#!/usr/bin/env python3
"""Offline candidate production only. Requires pinned numpy/scipy and ffmpeg."""
from pathlib import Path
import hashlib,json,math,re,subprocess,wave
import numpy as np
from scipy.signal import butter,sosfilt,resample_poly
from scipy.io import wavfile
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'public/audio-prototypes/white-hunger'
SRC=ROOT/'public/audio-sources/free-firearm-library'
SR=44100
rng=np.random.default_rng(91327)
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
 active=x[:min(len(x),round(window*SR))];g=10**(target/20)/max(np.sqrt(np.mean(active**2)),1e-9)
 x*=g
 # All files preserve crest; normalization ceiling may lower RMS. Record actual.
 if max(abs(x))>10**(-1.5/20):x*=10**(-1.5/20)/max(abs(x))
 p=OUT/(name+'.wav');wavfile.write(p,SR,np.round(x*32767).astype(np.int16))
 # Meter delivered PCM, not an unquantized pre-export signal.
 delivered=wavfile.read(p)[1].astype(float)/32768
 r={'file':p.name,'event':event,'duration_seconds':round(len(x)/SR,6),'format':'mono PCM_s16le 44100 Hz','loop':loop,'loop_start_frame':0 if loop else None,'loop_end_exclusive_frame':len(x) if loop else None,'seed':91327,'notes':notes,'requested_rms_dbfs':target,'matching_window_seconds':window,**metrics(delivered),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
 proc=subprocess.run(['ffmpeg','-hide_banner','-i',str(p),'-af','ebur128=peak=true','-f','null','-'],capture_output=True,text=True)
 match=re.findall(r'I:\s*([\-\d.]+) LUFS',proc.stderr); true=re.findall(r'Peak:\s*([\-\d.]+) dBFS',proc.stderr)
 r['integrated_lufs_ffmpeg']=float(match[-1]) if match else None;r['true_peak_dbfs_ffmpeg']=float(true[-1]) if true else None
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

weapons={}
for k in ['pistol','spread']:
 for v in range(3): weapons[(k,v)]=save(f'{k}_dry_{v+1}',weapon(k,v),'ShotEmitted',f'New onset selection of CC0 firearm take {v+1}; original damped wood/cavity modes and short coarse texture. No recovery baked in.',target=-17.5)
 # Separate restrained mechanism: broadband wooden stop and spring chatter, no implied reload.
 x=np.zeros(round(.21*SR));add(x,pulse(.06,.012,500,3300),0,.6);add(x,modal(.13,[234,491,983],[.024,.014,.009]),.043,.3)
 save(k+'_counterweight',x,'WeaponActionReturn','Separate candidate return marker; does not imply readiness/ammo/reload.',-29)

# Two distinct breath/contact timbres, made from nonperiodic excitation and cavity filters.
def cavity(d,centers,env):
 t=time(d);n=noise(len(t));x=sum(band(n,max(80,c*.75),c*1.35)*g for c,g in centers)
 return x*env(t)
for v in range(3):
 # Spoutback scrape starts immediately, inhale/held exhale builds after set; future marker uses same onset.
 x=np.zeros(round(.74*SR));scrape=pulse(.18,.09,1300,4700);scrape*=.45+.55*np.sin(np.arange(len(scrape))/SR*2*np.pi*31)**2;add(x,scrape,0,.17)
 y=cavity(.61,[(360,1),(910,.5)],lambda t:(1-np.exp(-t/.035))*np.minimum(1,(.61-t)/.10)*( .68+.15*np.sin(2*np.pi*(17+v)*t)))
 add(x,y,.12,.19);save(f'spoutback_tell_{v+1}',x,'EnemyTellBegin','Procedural scrape then held hollow exhale; not a performed animal voice. Windup marker must precede release; interrupt stops active tell.',-23,window=.74)
 x=cavity(.29,[(430,.8),(1240,.35)],lambda t:(1-np.exp(-t/.001))*np.exp(-t/.06));add(x,pulse(.1,.025,1700,5400),0,.055)
 save(f'spoutback_release_{v+1}',x,'EnemyReleaseCommitted','Short expulsion, different from pre-release held warning; projectile spawn accent only.',-22)
 x=np.zeros(round(.82*SR));add(x,cavity(.5,[(270,.8),(720,.3)],lambda t:(1-np.exp(-t/.008))*np.exp(-t/.14)),0,.16);add(x,pulse(.2,.055,180,1800),.28,.13);add(x,modal(.24,[184,329,677],[.06,.04,.018]),.47,.17)
 save(f'spoutback_death_{v+1}',x,'DeathCommitted','Terminal cavity emptying then two support contacts; not pain or repeated roar.',-24,window=.65)
 # Grazer warning has broad low-mid effort; grounded joint set distinct from Spoutback scratch.
 x=np.zeros(round(.71*SR));add(x,cavity(.45,[(180,1),(470,.75),(1500,.18)],lambda t:(1-np.exp(-t/.015))*np.exp(-t/.22)*( .8+.15*np.sin(2*np.pi*(24+v)*t))),0,.25)
 add(x,pulse(.17,.028,180,1800),.32,.12);add(x,modal(.24,[149,277,509],[.06,.027,.019]),.35,.17)
 save(f'knuckle_grazer_tell_{v+1}',x,'EnemyTellBegin','Broad effort then grounded joint set; procedural candidate, no real vocal performance. Bounded rush remains AI authority.',-23,window=.6)
 x=np.zeros(round(.31*SR));add(x,cavity(.23,[(225,1),(680,.3)],lambda t:(1-np.exp(-t/.003))*np.exp(-t/.068)),0,.3);add(x,pulse(.12,.035,180,2500),.016,.16)
 save(f'knuckle_grazer_release_{v+1}',x,'EnemyReleaseCommitted','Brief exertion/ground push; not sustained homing-rush roar.',-22)
 x=np.zeros(round(.95*SR));add(x,cavity(.42,[(140,1),(410,.4)],lambda t:(1-np.exp(-t/.006))*np.exp(-t/.15)),0,.2)
 add(x,pulse(.28,.07,120,1700),.23,.24);add(x,modal(.29,[125,246,403],[.08,.035,.026]),.28,.2);add(x,pulse(.17,.028,450,2700),.63,.08)
 save(f'knuckle_grazer_death_{v+1}',x,'DeathCommitted','Heavy lost support, broad floor contact then small settling. No inference of actual collision from this sound.',-24,window=.7)

# Seamless localized loops use periodic time/noise and bridge endpoint with a bounded periodic crossfade.
def seamless(x,seconds=.25):
 n=round(seconds*SR);y=x.copy();a=np.linspace(0,1,n,endpoint=False);blend=y[-n:]*(1-a)+y[:n]*a
 return np.concatenate([y[n:-n],blend])
d=8;t=time(d)
cloth=band(noise(len(t)),250,2800)*(.012+.025*np.sin(2*np.pi*t/4.0)**8)
for at in [1.2,3.1,5.4]:add(cloth,pulse(.27,.09,400,1900),at,.009)
save('world_shade_cloth_loop',seamless(cloth),'WorldSourceLoop','Localized cloth opening/flutter, no global wind bed; loop seam crossfaded. 7.5s derived loop.',-37,window=7.5,loop=True)
harness=np.zeros(round(.62*SR));add(harness,pulse(.26,.08,600,2600),0,.03);add(harness,modal(.14,[319,603,1280],[.04,.02,.012]),.14,.04);add(harness,pulse(.2,.05,300,1500),.34,.018)
save('world_harness_shift',harness,'WorldSourceOneShot','Strap friction plus restrained fastening contacts. Positional prop gesture, not enemy tell.',-34,window=.6)
basin=np.zeros(len(t));
for at in [.75,2.85,5.62]:add(basin,modal(.28,[423,713,1199],[.075,.044,.025]),at,.009)
basin+=band(noise(len(t)),350,1700)*.00065
save('world_dry_basin_loop',seamless(basin),'WorldSourceLoop','Sparse grit/cavity contact, almost quiet; no implied water flow or musical drone.',-40,window=7.5,loop=True)
water=band(noise(len(t)),1800,6100)*(.0015+.001*np.sin(2*np.pi*t/2.0)**2)
for at in np.linspace(.3,7.7,37)+rng.uniform(-.09,.09,37):
 y=modal(.07,list(rng.uniform([900,1800,2900],[1400,2400,3900])),[.016,.011,.006]);add(water,y,float(at),.018)
save('world_spring_trickle_loop',seamless(water),'WorldSourceLoop','Sparse discrete cavity droplets plus thin stream; localized known spring. Synthetic water candidate, not field recording.',-35,window=7.5,loop=True)

# Numbered reels: exact cadence and variant order, no score/ambience to hide weak sources.
listen=[]
for idx,k in enumerate(['pistol','spread'],1):
 duration=5 if k=='pistol' else 6;cad=.28 if k=='pistol' else .60
 x=np.zeros(round(duration*SR))
 for j in range(8):add(x,weapons[(k,j%3)],.4+j*cad)
 # Do not re-normalize sequence to defeat the per-shot matched levels.
 p=OUT/f'{idx:02d}_{k}_eight_shots.wav';wavfile.write(p,SR,np.round(np.clip(x,-.98,.98)*32767).astype(np.int16));listen.append({'number':idx,'file':p.name,'cadence_seconds':cad,'variant_order':[1,2,3,1,2,3,1,2],'note':'Uses delivered matched shots at unity. Pistol .28s / spread .60s are listening hypotheses, not current/final mechanics.'})
for number,name in [(3,'spoutback'),(4,'knuckle_grazer')]:
 x=np.zeros(round(5*SR));cueorder=[(f'{name}_tell_1',.3),(f'{name}_release_1',1.18),(f'{name}_death_1',2.6)]
 for file,at in cueorder:rate,y=wavfile.read(OUT/(file+'.wav'));add(x,y.astype(float)/32768,at)
 p=OUT/f'{number:02d}_{name}_tell_release_death.wav';wavfile.write(p,SR,np.round(x*32767).astype(np.int16));listen.append({'number':number,'file':p.name,'sequence':cueorder,'note':'Offline semantic sequence only; does not demonstrate AI/event playback.'})
for number,name in enumerate(['world_shade_cloth_loop','world_harness_shift','world_dry_basin_loop','world_spring_trickle_loop'],5):listen.append({'number':number,'file':name+'.wav','note':'World level intentionally quieter than shots; do not normalize every world loop to gunfire.'})
for r in listen:
 p=OUT/r['file'];r['sha256']=hashlib.sha256(p.read_bytes()).hexdigest()
manifest={'version':1,'status':'Produced procedural/CC0 candidates; unapproved and not listener-validated. No runtime integration.','sample_rate':SR,'seed':91327,'script':str(Path(__file__).relative_to(ROOT)),'script_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'dependencies':{'numpy':np.__version__,'scipy':__import__('scipy').__version__,'ffmpeg':subprocess.run(['ffmpeg','-version'],capture_output=True,text=True).stdout.splitlines()[0]},'rights':'New procedural signal designs authored for Eyesore. Recorded firearm inputs are local CC0 takes with retained original provenance; no commercial-game audio used.','sources':sources,'assets':records,'listening_order':listen,'limitations':['No perceived listening judgment by this agent.','Creature effort/world water are procedural approximations, not expert human performance/field recording.','Offline PCM does not exercise existing mixer onset ramp, voice stealing, spatialization or device latency.','Integrated short-cue LUFS and threshold onset are diagnostics, not perceptual validation.','True peak uses ffmpeg ebur128 oversampling; meter version captured.','Sample peaks and first 250ms RMS measured after PCM quantization; no claim that matching RMS matches perceived loudness.']}
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(f'Produced {len(records)} cue files and 4 numbered comparison reels; manifest written to {OUT}')
