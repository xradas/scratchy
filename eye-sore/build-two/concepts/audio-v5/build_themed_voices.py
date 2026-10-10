"""Twelve original dry monster derivatives of preserved CC0 HaelDB sources.
Coordinator selection/design; no new downloads, wet layers or copied game audio.
"""
from pathlib import Path
import importlib.util,json,tempfile,math
BASE=Path(__file__).resolve().parent
PROJECT=BASE.parents[1]
spec=importlib.util.spec_from_file_location('demonic',BASE.parent/'audio-v4/build_demonic.py')
a=importlib.util.module_from_spec(spec);spec.loader.exec_module(a)
previous=json.loads((BASE.parent/'audio-v4/manifest.json').read_text())
profiles={'ironbound':('unsealed',.50,2600,27),'censer':('vessel',.35,1900,19),'reaver':('unsealed',.69,5700,61),'surveyor':('vessel',.82,6900,79)}
manifest={'design':'Dry duration-preserving lowered vocal formants, layered throat/rasp with distinct species pitches and amplitude modulation. No reverb, echo or wet foley. Existing two voices and all weapon contacts remain byte unchanged. Human listening review pending.','sources':previous['sources'],'cues':{}}
runtime=PROJECT/'assets/audio/demonic-v2';runtime.mkdir(parents=True,exist_ok=True)
(BASE/'cues').mkdir(exist_ok=True)
ledger_path=PROJECT/'assets/audio/runtime-cues.json';ledger=json.loads(ledger_path.read_text())
with tempfile.TemporaryDirectory(prefix='eyesore-theme-voices-') as d:
 temp=Path(d)
 for kind,(source_kind,ratio,cutoff,rate) in profiles.items():
  for role in ['attack_warning','hurt','death']:
   key=kind+'_'+role;old=previous['cues'][source_kind+'_'+role]
   source=PROJECT/next(s['original'] for s in previous['sources'] if s['id']==old['source_id'])
   assert a.sha(source)==old['original_sha256']
   raw=temp/'raw.wav';duration=old['new_technical']['seconds']
   a.ff(['-i',str(source),'-ss',str(old['excerpt_start_seconds']),'-t',str(old['excerpt_duration_seconds']),'-ar','48000','-ac','1','-c:a','pcm_f32le',str(raw)])
   input_gain=.75/max(a.stats(raw)['peak'],1e-8)
   layers=[];graph=[f'[0:a]volume={input_gain},asplit=3[a][b][c]']
   for i,(r,gain,c,rhythm) in enumerate([(ratio,1.0,cutoff,rate),(ratio*.74,.37,950,rate*.73),(min(.98,ratio*1.25),.23,cutoff*1.15,rate*1.17)]):
    tempo=1/r;stages=[]
    while tempo>2:stages.append('atempo=2');tempo/=2
    stages.append('atempo='+str(tempo))
    filters=f'asetrate=48000*{r},aresample=48000,'+','.join(stages)+f',highpass=f=65,lowpass=f={c},volume=4,asoftclip=type=tanh:threshold=0.65:oversample=4,tremolo=f={rhythm}:d=0.22,volume={gain},apad,atrim=duration={duration}'
    graph.append(f'[{"abc"[i]}]{filters}[l{i}]');layers.append(filters)
   graph.append(f'[l0][l1][l2]amix=inputs=3:normalize=0,highpass=f=60,afade=t=in:d=0.003,afade=t=out:st={duration-.035}:d=0.035[out]')
   mixed=temp/'mixed.wav';a.ff(['-i',str(raw),'-filter_complex',';'.join(graph),'-map','[out]','-c:a','pcm_f32le',str(mixed)])
   measured=a.stats(mixed);reference=old['new_technical'];gain=min(reference['rms']/max(measured['rms'],1e-8),.36/max(measured['peak'],1e-8))
   wav=BASE/'cues'/f'{key}.wav';a.ff(['-i',str(mixed),'-af',f'volume={gain}','-c:a','pcm_s24le',str(wav)])
   ogg=runtime/f'{key}.ogg';a.ff(['-i',str(wav),'-c:a','libvorbis','-q:a','6',str(ogg)])
   stats=a.stats(ogg);assert stats['rail_samples']==0 and abs(stats['seconds']-duration)<.001
   manifest['cues'][key]={'source_id':old['source_id'],'original':str(source.relative_to(PROJECT)),'original_sha256':a.sha(source),'excerpt_start_seconds':old['excerpt_start_seconds'],'excerpt_duration_seconds':old['excerpt_duration_seconds'],'filter_graph':';'.join(graph),'input_gain':input_gain,'final_gain':gain,'runtime':str(ogg.relative_to(PROJECT)),'runtime_sha256':a.sha(ogg),'wav':str(wav.relative_to(PROJECT)),'wav_sha256':a.sha(wav),'technical':stats}
   ledger['cues'][key]={'file':'res://'+str(ogg.relative_to(PROJECT)),'bus':'Creatures','gain_db':0,'source_manifest':'concepts/audio-v5/manifest.json','source_id':old['source_id']}
   print(key,round(stats['seconds'],3),'peak',round(stats['peak'],3),'rails',stats['rail_samples'])
(BASE/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
ledger_path.write_text(json.dumps(ledger,indent=2)+'\n')
