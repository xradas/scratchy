from audio_tools import *
for n in ['stems','dry','preview','verification']: (B/n).mkdir(exist_ok=True)
p=lambda n:B/'originals'/n
specs={
'pistol_flesh':(-9,[(p('qubodupPunch/qubodupPunch02.flac'),0,.21,1.12,'highpass=f=85,equalizer=f=190:t=q:w=1:g=2,lowpass=f=6000',1,0)]),
'shotgun_flesh':(-7,[(p('qubodupPunch/qubodupPunch01.flac'),0,.29,.9,'highpass=f=65,equalizer=f=160:t=q:w=1:g=3,lowpass=f=6500',1,0),(p('rubberduck/wood_cracking_01.ogg'),0,.16,.95,'highpass=f=160,lowpass=f=5200',.22,.005)]),
'melee_flesh':(-8,[(p('qubodupPunch/qubodupPunch03.flac'),0,.24,.98,'highpass=f=75,equalizer=f=210:t=q:w=1:g=2,lowpass=f=5500',1,0)]),
'unsealed_hurt':(-12,[(p('haelDB/3grunt3.wav'),active_start(p('haelDB/3grunt3.wav')),.34,.96,'highpass=f=100,lowpass=f=6800',1,0)])}
ledger={}
for key,(pk,layers) in specs.items():
 out=B/'preview'/f'{key}.wav';dr,ed=build(layers,out,pk,key);ledger[key]={'file':str(out.relative_to(B)),'sha256':sha(out),'edits':ed};print('Preview',key,probe(out)['format']['duration'],flush=True)
ref=B/'preview'/'human_reference_unpitched.wav';peak(p('haelDB/3grunt3.wav'),ref,-12);ogg(ref)
sample=B/'preview'/'dry_direction_10s.wav';mix([(B/'preview'/'pistol_flesh.wav',.5,1),(B/'preview'/'unsealed_hurt.wav',.57,1),(B/'preview'/'shotgun_flesh.wav',3.5,1),(B/'preview'/'unsealed_hurt.wav',3.57,1),(B/'preview'/'melee_flesh.wav',6.5,1),(B/'preview'/'unsealed_hurt.wav',6.57,1),(ref,8.5,1)],sample,10);ogg(sample)
(B/'preview'/'ledger.json').write_text(json.dumps({'cues':ledger,'preview_file':'preview/dry_direction_10s.wav','sha256':sha(sample),'reference_file':'preview/human_reference_unpitched.wav','sources':'CC0 qubodup Punch (recorded punching bag), rubberduck wood cracking, HaelDB human male grunt. No wet source or animal layer.','status':'Technical rendering only; coordinator listening review pending.'},indent=2)+'\n')
