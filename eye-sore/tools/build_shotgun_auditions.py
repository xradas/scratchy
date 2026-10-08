#!/usr/bin/env python3
"""Build reproducible, level-matched shotgun A/B/C audition one-shots.
Requires ffmpeg/ffprobe and Python standard library only.
Run from any directory: python3 eye-sore/tools/build_shotgun_auditions.py
"""
from __future__ import annotations
import hashlib, json, math, pathlib, random, shutil, struct, subprocess, wave

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "public/audio-prototypes/shotgun"
SR = 48000
CLIP_SECONDS = 0.80
TARGET_RMS_DB = -20.0
PEAK_CEILING_DB = -1.0
# Measured 10 ms downmixed RMS windows at a -35 dB relative / -50 dBFS floor.
# Region starts are the measured attack boundaries rounded to nearest millisecond.
TAKES = {
 "1": {"file":"mossberg-shotgun.wav", "attack_s":0.785, "region_s":[0.785,1.585]},
 "2": {"file":"mossberg-shotgun-b.wav", "attack_s":1.695, "region_s":[1.695,2.495]},
 "3": {"file":"mossberg-shotgun-c.wav", "attack_s":0.426, "region_s":[0.426,1.226]},
}
SRC = ROOT / "public/audio-sources/free-firearm-library"
FOLEY = ROOT / "public/audio-sources/cc0"
VARIANTS = {
 "A":"Dry immediate: source transient and natural recorded decay, with only level matching.",
 "B":"Blast plus mechanical recovery: dry source plus quiet steel/metal foley accents. Foley is a placeholder, not a finished weapon mechanism.",
 "C":"Compact abrasive industrial: mild saturation, softened low-pass body, restrained filtered metal grit. Treatment candidate, not a final mix.",
}

def run(args):
    return subprocess.run(args, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

def sha(path):
    h=hashlib.sha256()
    with open(path,'rb') as f:
        for b in iter(lambda:f.read(1<<20),b''):h.update(b)
    return h.hexdigest()

def decode_mono(path, start=0.0, duration=None):
    args=['ffmpeg','-v','error','-ss',f'{start:.6f}','-i',str(path)]
    if duration is not None: args += ['-t',f'{duration:.6f}']
    args += ['-af','pan=mono|c0=0.5*c0+0.5*c1','-ac','1','-ar',str(SR),'-f','f32le','-acodec','pcm_f32le','pipe:1']
    raw=run(args).stdout
    return list(struct.unpack('<%df'%(len(raw)//4),raw))

def filtered(x, cutoff, high=False):
    # One-pole low pass; high-pass is input minus matched low-pass.
    a=1.0-math.exp(-2.0*math.pi*cutoff/SR); y=0.0; out=[]
    for v in x:
        y += a*(v-y); out.append(v-y if high else y)
    return out

def add(dst, src, offset_s, gain):
    off=round(offset_s*SR)
    for i,v in enumerate(src):
        j=i+off
        if j>=len(dst): break
        # fade foley ends to avoid sample discontinuities
        fade=min(1.0,(i+1)/(SR*.008),max(0.0,(len(src)-i)/(SR*.025)))
        dst[j]+=v*gain*fade

def process_unmatched(variant, shot, steel, metal):
    n=round(CLIP_SECONDS*SR); dry=(shot+[0.0]*n)[:n]
    if variant=='A': x=dry[:]
    elif variant=='B':
        x=dry[:]
        # Tiny physical recovery ticks, audible but intentionally subordinate.
        add(x,filtered(steel,2400,True),.105,.24)
        add(x,filtered(metal,1500,True),.205,.16)
    else:
        # Rounded body with controlled edge. Soft saturation is deterministic.
        body=filtered(dry,7200)
        x=[math.tanh(v*1.45)/math.tanh(1.45) for v in body]
        grit=filtered(metal,2600,True)
        add(x,grit,.028,.10)
    return x

def write_wav(path,x):
    path.parent.mkdir(parents=True,exist_ok=True)
    ints=[]
    for v in x:
        v=max(-1.0,min(1.0,v)); ints.append(round(v*32767))
    with wave.open(str(path),'wb') as w:
        w.setnchannels(1);w.setsampwidth(2);w.setframerate(SR);w.writeframes(struct.pack('<%dh'%len(ints),*ints))

def write_float_wav(path,x):
    # IEEE float PCM avoids peak clipping when the game-level shot and room bed add.
    data=struct.pack('<%df'%len(x),*x); byte_rate=SR*4; block_align=4
    fmt=struct.pack('<HHIIHH',3,1,SR,byte_rate,block_align,32)
    body=b'fmt '+struct.pack('<I',len(fmt))+fmt+b'data'+struct.pack('<I',len(data))+data
    header=b'RIFF'+struct.pack('<I',len(body)+4)+b'WAVE'+body
    path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(header)

def read_pcm16(path):
    with wave.open(str(path),'rb') as w:
        raw=w.readframes(w.getnframes())
        return [v/32768.0 for v in struct.unpack('<%dh'%(len(raw)//2),raw)]

def measure(path):
    with wave.open(str(path),'rb') as w:
        data=w.readframes(w.getnframes()); xs=struct.unpack('<%dh'%(len(data)//2),data)
    peak=max(map(abs,xs),default=0)/32768
    rms=math.sqrt(sum((s/32768)**2 for s in xs)/max(1,len(xs)))
    return {"duration_seconds":round(len(xs)/SR,6),"sample_rate_hz":SR,"channels":1,"format":"PCM signed 16-bit little-endian","rms_dbfs":round(20*math.log10(max(rms,1e-12)),3),"sample_peak_dbfs":round(20*math.log10(max(peak,1e-12)),3)}

def main():
    if not shutil.which('ffmpeg'): raise SystemExit('ffmpeg is required')
    OUT.mkdir(parents=True,exist_ok=True)
    steel=decode_mono(FOLEY/'steel1.wav',0,.55); metal=decode_mono(FOLEY/'metal1.wav',0,.55)
    outputs=[]
    # A short comparison reel gives direct A/B/C evaluation without music or game code.
    reel=[]
    gap=[0.0]*round(.42*SR)
    for tid,t in TAKES.items():
        source=SRC/t['file']; start,duration=t['region_s']
        raw=decode_mono(source,start,duration)
        if len(raw)<round(.65*SR): raise RuntimeError(f"Unexpectedly short region {t['file']}")
        variants={v:process_unmatched(v,raw,steel,metal) for v in ('A','B','C')}
        ceiling=10**(PEAK_CEILING_DB/20); desired=10**(TARGET_RMS_DB/20)
        # Pick one attainable RMS target for all three treatments of this take.
        allowed=[]
        for candidate in variants.values():
            rms=math.sqrt(sum(v*v for v in candidate)/len(candidate)); peak=max(map(abs,candidate),default=0.0)
            allowed.append(min(desired,rms*min(1.0,ceiling/max(peak,1e-12))))
        matched_rms=min(allowed)
        for vid,x in variants.items():
            rms=math.sqrt(sum(v*v for v in x)/len(x)); x=[v*(matched_rms/max(rms,1e-12)) for v in x]
            name=f"shotgun_{vid.lower()}_take{tid}.wav"; path=OUT/name;write_wav(path,x)
            outputs.append({"id":vid,"take":tid,"file":name,**measure(path),"sha256":sha(path)})
            if tid=='1': reel.append(x+gap)
    reelpath=OUT/'comparison_take1_A-B-C.wav';write_wav(reelpath,[s for x in reel for s in x])

    # Six trigger events at the game's 1.5 s shotgun cadence, rotating through
    # all three recording takes in the same order for every candidate.
    cadence=1.5; repetitions=6; sequence_seconds=(repetitions-1)*cadence+CLIP_SECONDS
    nseq=round(sequence_seconds*SR); gapseq=[0.0]*round(.8*SR)
    ambience=ROOT/'linux-game/assets/music/furnace-descent-loop.wav'
    bed=decode_mono(ambience,0,sequence_seconds)
    seq_cases=[]
    sequence_key={}
    for variant in ('A','B','C'):
        shots=[read_pcm16(OUT/f"shotgun_{variant.lower()}_take{tid}.wav") for tid in ('1','2','3','1','2','3')]
        for condition in ('off','on'):
            # Match the current engine's shotgun gain and music-device gain.
            # Music is the exact checked-in game room bed at unity; no other
            # game layers (hits, voices, pickups) are synthesized into this reel.
            mix=[0.0]*nseq
            if condition=='on':
                for i in range(nseq): mix[i]=bed[i] if i<len(bed) else 0.0
            for shot_index,shot in enumerate(shots):
                offset=round(shot_index*cadence*SR)
                for i,sample in enumerate(shot):
                    if offset+i<nseq: mix[offset+i] += sample*.82
            seq_cases.append((variant,condition,mix))
    rng=random.Random(8315);rng.shuffle(seq_cases)
    blind=[]; sequence_outputs=[]; montage=[]
    for index,(variant,condition,mix) in enumerate(seq_cases,1):
        filename=f"sequence_{index:02d}.wav"; path=OUT/filename
        write_float_wav(path,mix)
        order_item={"order":index,"file":filename,"sha256":sha(path),"description":"Six shots at 1.5-second intervals; candidate and ambience condition withheld from filename."}
        blind.append(order_item); sequence_key[filename]={"candidate":variant,"ambience":"exact current game room bed on at unity gain" if condition=='on' else "off (silence; no replacement ambience)"}
        sequence_outputs.append({"file":filename,"candidate":variant,"ambience":condition,"shots":repetitions,"cadence_seconds":cadence,"take_rotation":["1","2","3","1","2","3"],"duration_seconds":round(len(mix)/SR,6),"sample_rate_hz":SR,"channels":1,"format":"IEEE float32 mono WAV","sha256":sha(path)})
        montage.extend(mix);montage.extend(gapseq)
    listenpath=OUT/'six_shot_listening_order.wav';write_float_wav(listenpath,montage)
    manifest={
      "title":"Shotgun sound A/B/C prototype pack","status":"audition candidates; none approved as production audio",
      "neutral_variant_labels":{"A":VARIANTS['A'],"B":VARIANTS['B'],"C":VARIANTS['C']},
      "processing":{"sample_rate_hz":SR,"channels":1,"format":"PCM signed 16-bit little-endian","clip_duration_seconds":CLIP_SECONDS,"target_rms_dbfs":TARGET_RMS_DB,"sample_peak_ceiling_dbfs":PEAK_CEILING_DB,"level_matching":"A/B/C have identical measured RMS within each source take; common target is constrained by the cleanest headroom candidate, and may fall below target_rms_dbfs.","downmix":"ffmpeg pan filter c0=0.5*c0+0.5*c1 stereo average to mono, followed by linear resampling to 48 kHz","source_region_policy":"First measured onset region shared across A/B/C for each of three source takes; no variant changes the shot start."},
      "sources":[
       {"file":str(p.relative_to(ROOT)),"sha256":sha(p),"license":"CC0/public domain per bundled source README","reference":"https://opengameart.org/content/the-free-firearm-sound-library; https://github.com/petroulacl/fps-asset-kit"} for p in [SRC/t['file'] for t in TAKES.values()]
      ] + [
       {"file":str((FOLEY/f).relative_to(ROOT)),"sha256":sha(FOLEY/f),"license":"CC0/Unlicense; see public/audio-sources/cc0/LICENSE","reference":"https://github.com/code4fukui/sound-cc0"} for f in ('steel1.wav','metal1.wav')],
      "take_regions":{k:{"source":t['file'],"measured_attack_start_seconds":t['attack_s'],"source_region_seconds":t['region_s']} for k,t in TAKES.items()},
      "outputs":outputs,
      "six_shot_sequences":{"description":"Each clip has six trigger events spaced exactly 1.5 seconds apart (the current shotgun cadence), with source takes rotating 1,2,3 twice. Shot gain is the current engine shotgun gain 0.82 in both ambience conditions. Ambience-on uses the exact current checked-in 24-second room bed at unity gain, beginning at its first sample; ambience-off contains silence under shots. No enemies, impacts, or synthesized replacement cues are added. IEEE float32 preserves additive peaks without clipping.","cadence_seconds":cadence,"shots_per_clip":repetitions,"sequence_duration_seconds":round(sequence_seconds,6),"ambience_source":{"file":str(ambience.relative_to(ROOT)),"sha256":sha(ambience),"format":"44.1 kHz mono PCM16, 24 s","generation_script":"linux-game/tools/build_furnace_music.sh","playback_gain":1.0},"blind_listening_order_seed":8315,"blind_listening_order":blind,"key":sequence_key,"files":sequence_outputs,"combined_file":{"file":listenpath.name,"sha256":sha(listenpath),"layout":"The six files in blind_listening_order, separated by 800 ms silence."}},
      "comparison_reel":{"file":reelpath.name,"sha256":sha(reelpath),"layout":"Take 1; A then B then C, separated by 420 ms silence."},
      "reproducibility":"Run python3 eye-sore/tools/build_shotgun_auditions.py with ffmpeg available. Output WAV hashes are recorded here."
    }
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(f"Wrote {len(outputs)} one-shots, comparison reel, and {len(sequence_outputs)} six-shot sequences to {OUT}")
    for o in outputs: print(o['file'],o['rms_dbfs'],o['sample_peak_dbfs'],o['sha256'])

if __name__=='__main__': main()
