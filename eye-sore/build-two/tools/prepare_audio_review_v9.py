#!/usr/bin/env python3
"""Build three licensed firearm listening comparisons; never register runtime audio."""
import array, concurrent.futures, hashlib, html, json, math, re, shutil, subprocess, sys, time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'concepts/audio-v9'
SR=48000
TARGET=-26.0
CEILING=-9.0
COMMANDS=[]
START=time.monotonic()
def sha(p):
 h=hashlib.sha256()
 with Path(p).open('rb') as f:
  for b in iter(lambda:f.read(1024*1024),b''):h.update(b)
 return h.hexdigest()
def run(args):
 COMMANDS.append([str(x) for x in args])
 return subprocess.run([str(x) for x in args],check=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE).stdout
def ff(args):return run(['ffmpeg','-v','error','-nostdin',*args])
def decode(p):
 a=array.array('f');a.frombytes(ff(['-i',p,'-ac','1','-ar',SR,'-f','f32le','pipe:1']))
 if sys.byteorder!='little':a.byteswap()
 return a
def db(x):return 20*math.log10(max(x,1e-20))
def stats(a):
 n=min(len(a),int(.15*SR));peak=max(abs(x) for x in a)
 return {'samples':len(a),'seconds':len(a)/SR,'rms_first_150ms_dbfs':db(math.sqrt(sum(x*x for x in a[:n])/n)),'peak_dbfs':db(peak),'peak_linear':peak,'nonzero_samples':sum(x!=0 for x in a),'clipped_samples':sum(abs(x)>=1 for x in a)}
def first_onset(a):
 threshold=max(abs(x) for x in a)*.05
 return next(i for i,x in enumerate(a) if abs(x)>=threshold)
def write_float(p,a):
 b=array.array('f',a)
 if sys.byteorder!='little':b.byteswap()
 p.write_bytes(b.tobytes())
def save_pair(stem,a):
 raw=OUT/'work'/f'{stem}.f32';write_float(raw,a)
 wav=OUT/f'{stem}.wav';ogg=OUT/f'{stem}.ogg';wav.parent.mkdir(parents=True,exist_ok=True)
 ff(['-f','f32le','-ar',SR,'-ac','1','-i',raw,'-c:a','pcm_s24le',wav])
 ff(['-i',wav,'-c:a','libvorbis','-q:a','7',ogg])
 return {'wav':str(wav.relative_to(OUT)),'ogg':str(ogg.relative_to(OUT)),'wav_sha256':sha(wav),'ogg_sha256':sha(ogg),'wav_measurement':stats(decode(wav)),'ogg_measurement':stats(decode(ogg))}
def repeated(a,cadence,count=5):
 out=array.array('f',[0.0])*(round((count-1)*cadence*SR)+len(a))
 for shot in range(count):
  offset=round(shot*cadence*SR)
  for i,x in enumerate(a):out[offset+i]+=x
 return out
def safe_copy(src,dst):
 dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,dst);assert sha(src)==sha(dst)
def main():
 if OUT.exists() and any(OUT.iterdir()):raise SystemExit('Refusing existing audio-v9 output')
 for folder in ['originals','provenance','snapshot','dry','cues','auditions','work']:(OUT/folder).mkdir(parents=True,exist_ok=True)
 brief=json.loads((ROOT/'docs/production-v9/audio-brief.json').read_text())
 survey=json.loads((ROOT/'docs/production-v9/firearm-source-survey.json').read_text())
 ledger=ROOT/'assets/audio/runtime-cues.json';runtime=json.loads(ledger.read_text());assert len(runtime['cues'])==57
 paths={v['file'] for v in runtime['cues'].values()}
 paths|={'res://'+str(p.relative_to(ROOT)) for p in (ROOT/'assets/audio/music').glob('*.ogg')}
 preserved={s:sha(ROOT/s.removeprefix('res://')) for s in sorted(paths)}
 contracts={str(p.relative_to(ROOT)):sha(p) for p in [ledger,ROOT/'resources/combat_audio.tres',ROOT/'assets/audio/CREDITS.md']}
 archive=Path(survey['download_path']);assert sha(archive)==brief['archive_sha256']==survey['archive_sha256']
 evidence=ROOT/'concepts/audio-v3/provenance/the-free-firearm-sound-library.html'
 safe_copy(evidence,OUT/'provenance'/evidence.name)
 for name in ['audio-brief.json','firearm-source-survey.json']:
  safe_copy(ROOT/'docs/production-v9'/name,OUT/'provenance'/name)
 # Private reference audio is never opened/copied; paths and hashes only.
 private=json.loads((ROOT/'docs/production-v9/audio-reference-analysis.json').read_text())
 private=[{'path':x['path'],'sha256':x['sha256']} for x in private['files'] if x['path'].endswith('.mp3')]
 sources=[];rows=[]
 for selected in brief['selected']:
  weapon=selected['weapon'];source=Path(selected['source']);assert sha(source)==selected['source_sha256']
  original=OUT/'originals'/weapon/source.name;safe_copy(source,original)
  current_path=ROOT/runtime['cues'][weapon+'_fire']['file'].removeprefix('res://')
  snapshot=OUT/'snapshot'/f'{weapon}-runtime-original.ogg';safe_copy(current_path,snapshot)
  cooldown=float(re.search(r'^cooldown_seconds = ([0-9.]+)',(ROOT/f'resources/weapons/{weapon}.tres').read_text(),re.M)[1])
  sources.append({'weapon':weapon,'original':str(original.relative_to(OUT)),'original_sha256':sha(original),'source_path':str(source),'source_url':brief['source_url'],'download_url':survey['download_url'],'creator':brief['creator'],'license':'CC0 1.0','license_url':'https://creativecommons.org/publicdomain/zero/1.0/','cached_evidence':'provenance/'+evidence.name,'cached_evidence_sha256':sha(evidence),'runtime_snapshot':str(snapshot.relative_to(OUT)),'runtime_snapshot_sha256':sha(snapshot),'cooldown_seconds':cooldown})
  for kind in ['current','dry','A','B']:
   src=snapshot if kind=='current' else original
   if kind=='current':
    a=decode(src);onset=first_onset(a);start=max(0,(onset-round(.002*SR))/SR);duration=len(a)/SR-start
   else:start=selected['start_seconds'];duration=selected['duration_seconds']
   filters=['aformat=sample_fmts=flt:sample_rates=48000:channel_layouts=mono',f'atrim=start={start:.12f}:duration={duration:.12f}','asetpts=PTS-STARTPTS']
   if kind in ['A','B']:
    filters+=['highpass=f=45']
    if kind=='B':filters+=['equalizer=f=140:t=q:w=0.8:g=1.5','acompressor=threshold=0.10:ratio=3:attack=0.2:release=65:makeup=1']
    filters+=['lowpass=f=15000']
   filters +=['afade=t=in:st=0:d=0.0005',f'afade=t=out:st={max(0,duration-.04):.12f}:d=0.04']
   graph=','.join(filters);a=array.array('f');a.frombytes(ff(['-i',src,'-af',graph,'-ac','1','-ar',SR,'-f','f32le','pipe:1']))
   onset=first_onset(a);shift=onset-round(.002*SR)
   # Retain the same source excerpts; align filtered/current rendered onset by
   # trimming only leading quiet, or padding when a peak occurs before2ms.
   if shift>0:a=a[shift:]
   elif shift<0:a=array.array('f',[0.0])*(-shift)+a
   original_measure=stats(a);gain_db=TARGET-original_measure['rms_first_150ms_dbfs'];gain=10**(gain_db/20)
   matched=array.array('f',(x*gain for x in a))
   rows.append({'weapon':weapon,'kind':kind,'source_input':str(src.relative_to(OUT)),'source_start_seconds':start,'source_duration_seconds':duration,'ffmpeg_filtergraph':graph,'post_filter_alignment_samples':shift,'alignment_description':'First5% of each rendered row peak aligned to2ms; negative shift means leading zero pad. No signal layers.','pre_match_measurement':original_measure,'rms_match_gain_db':gain_db,'cadence':cooldown,'matched':matched})
 # One global gain protects all twelve rows AND every real-cadence repeat.
 provisional=[]
 for row in rows:provisional.extend([stats(row['matched'])['peak_dbfs'],stats(repeated(row['matched'],row['cadence']))['peak_dbfs']])
 attenuation=min(0.0,CEILING-.3-max(provisional)) #0.3dB guard for Vorbis reconstruction
 gain=10**(attenuation/20)
 for row in rows:
  row['final']=array.array('f',(x*gain for x in row['matched']))
  row['total_gain_db']=row['rms_match_gain_db']+attenuation
  row['total_gain_linear']=10**(row['total_gain_db']/20)
  row['gain_application']='After FFmpeg graph and exact leading-sample alignment: multiply by10**(rms_match_gain_db/20), storefloat32; multiply by10**(global_final_attenuation_db/20), storefloat32; encodePCM24 withoutdither, then Vorbisquality7. No limiter.'
 def export(row):
  folder='dry' if row['kind']=='dry' else 'cues';stem=f'{folder}/{row["weapon"]}-{row["kind"]}'
  # Scratch filenames cannot contain nestedfolders.
  (OUT/'work'/folder).mkdir(exist_ok=True)
  (OUT/'work'/'auditions').mkdir(exist_ok=True)
  row['individual']=save_pair(stem,row['final'])
  row['repeat']=save_pair(f'auditions/{row["weapon"]}-{row["kind"]}-five-shots',repeated(row['final'],row['cadence']))
  return row
 with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:rows=list(pool.map(export,rows))
 sequences=[]
 for weapon in [x['weapon'] for x in brief['selected']]:
  group=[x for x in rows if x['weapon']==weapon];sequence=array.array('f')
  for row in group:sequence.extend(row['final']);sequence.extend(array.array('f',[0.0])*round(.7*SR))
  sequences.append({'weapon':weapon,'order':['current','dry','A','B'],'gap_seconds':.7,**save_pair(f'auditions/{weapon}-current-dry-A-B-sequence',sequence)})
 for row in rows:
  for kind in ['individual','repeat']:
   for fmt in ['wav','ogg']:
    m=row[kind][fmt+'_measurement'];assert m['samples']>0 and m['nonzero_samples']>0 and m['clipped_samples']==0
    assert m['peak_dbfs']<=CEILING+.01,(row['weapon'],row['kind'],fmt,m)
 for weapon in [x['weapon'] for x in brief['selected']]:
  levels=[r['individual']['wav_measurement']['rms_first_150ms_dbfs'] for r in rows if r['weapon']==weapon]
  assert max(levels)-min(levels)<.2
 assert preserved=={s:sha(ROOT/s.removeprefix('res://')) for s in preserved}
 assert contracts=={p:sha(ROOT/p) for p in contracts}
 for row in rows:row.pop('matched');row.pop('final')
 manifest={'schema_version':9,'status':'Listening candidates only. Not approved, shipped or registered in runtime.','source_url':brief['source_url'],'download_url':survey['download_url'],'creator':brief['creator'],'license':'CC0 1.0','archive_path':str(archive),'archive_sha256':sha(archive),'sources':sources,'private_references_paths_hashes_only':private,'comparison':{'target_first_150ms_rms_dbfs':TARGET,'global_final_attenuation_db':attenuation,'actual_common_target_dbfs':TARGET+attenuation,'peak_ceiling_dbfs':CEILING,'codec_guard_db':.3,'normalization':'Every aligned row matched to target first, then ONE common attenuation for all12 rows and their cadence repeats. No row-specific peak limiting or post-encoding normalization.','sample_rate':SR,'channels':1,'wav_codec':'pcm_s24le','ogg_codec':'libvorbis quality7','repeat_shots':5,'sequence_order':['current','dry','A','B'],'pitch_ratio':1.0,'no_added_layers':['delay','wet/slosh','synthesized bass','reverb','convolution'],'prepared_source_note':'Archive contains prepared original recordings, not claims of raw microphone audio.'},'rows':rows,'sequences':sequences,'preservation':{'runtime_cue_records':57,'runtime_audio_files_including_music':len(preserved),'runtime_audio_sha256_unchanged':preserved,'profile_ledger_credits_sha256_unchanged':contracts,'assertions_passed':True},'commands':COMMANDS,'ffmpeg_version':run(['ffmpeg','-version']).decode().splitlines()[0],'elapsed_seconds':time.monotonic()-START}
 (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
 render_html(manifest)
 validate_outputs(manifest)
 manifest['generator']='tools/prepare_audio_review_v9.py'
 manifest['generator_sha256']=sha(Path(__file__))
 manifest['validation']='validation.json'
 manifest['validation_sha256']=sha(OUT/'validation.json')
 (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
 shutil.rmtree(OUT/'work')
 print(json.dumps({'rows':len(rows),'common_attenuation_db':attenuation,'actual_rms_dbfs':TARGET+attenuation,'runtime_audio_unchanged':len(preserved),'elapsed_seconds':time.monotonic()-START,'index':str(OUT/'index.html')}))
def validate_outputs(m):
 from html.parser import HTMLParser
 class AudioParser(HTMLParser):
  def __init__(self):super().__init__();self.audio=[]
  def handle_starttag(self,tag,attrs):
   if tag=='audio':self.audio.append(dict(attrs))
 files=[]
 for row in m['rows']:
  files.extend(row[k][fmt] for k in ['individual','repeat'] for fmt in ['wav','ogg'])
 files.extend(s[fmt] for s in m['sequences'] for fmt in ['wav','ogg'])
 def inspect(name):
  path=OUT/name
  probe=json.loads(run(['ffprobe','-v','error','-show_entries','stream=codec_name,sample_rate,channels,bits_per_sample','-show_entries','format=duration','-of','json',path]))
  stream=probe['streams'][0];measure=stats(decode(path))
  assert stream['sample_rate']=='48000' and stream['channels']==1
  if path.suffix=='.wav':assert stream['codec_name']=='pcm_s24le' and stream['bits_per_sample']==24
  else:assert stream['codec_name']=='vorbis'
  assert measure['samples']>0 and measure['nonzero_samples']>0 and measure['clipped_samples']==0 and measure['peak_dbfs']<=-9+.01
  return {'file':name,'sha256':sha(path),'format':probe,'measurement':measure}
 with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:outputs=list(pool.map(inspect,files))
 levels=[r['measurement']['rms_first_150ms_dbfs'] for r in outputs if r['file'] in [x['individual']['ogg'] for x in m['rows']]]
 assert max(levels)-min(levels)<.2
 parser=AudioParser();parser.feed((OUT/'index.html').read_text());assert len(parser.audio)==27
 assert all('autoplay' not in a and 'controls' in a and a.get('preload')=='none' and (OUT/a['src']).exists() for a in parser.audio)
 assert not list(OUT.rglob('*.mp3'))
 for path,digest in m['preservation']['runtime_audio_sha256_unchanged'].items():assert sha(ROOT/path.removeprefix('res://'))==digest
 for path,digest in m['preservation']['profile_ledger_credits_sha256_unchanged'].items():assert sha(ROOT/path)==digest
 result={'passed':True,'audio_outputs':len(outputs),'individual_rows':12,'audio_controls':27,'ogg_first150ms_rms_spread_db':max(levels)-min(levels),'runtime_cue_records_unchanged':57,'runtime_audio_files_including_music_unchanged':60,'private_mp3_copies':0,'outputs':outputs}
 (OUT/'validation.json').write_text(json.dumps(result,indent=2)+'\n')

def render_html(m):
 labels={'current':'Current runtime cue · aligned, level matched audition','dry':'New original take · dry excerpt','A':'Candidate A · natural / gentle HP + LP','B':'Candidate B · controlled body / ratio3 compression +1.5dB at140Hz'}
 def player(p):return f'<audio controls preload="none" src="{html.escape(p)}"></audio>'
 s=['<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Firearm listening candidates · v9</title><style>body{background:#111810;color:#e3e7d6;font:16px system-ui;max-width:1160px;margin:35px auto;padding:0 20px}h1,h2{color:#e7cf79}p{line-height:1.55}table{border-collapse:collapse;width:100%;margin:20px 0}th,td{padding:13px;border:1px solid #45503c;text-align:left}audio{width:240px;max-width:100%}small{color:#b2bda6}a{color:#d8c578}code{font-size:13px}td:first-child{max-width:300px}</style><h1>Firearm listening candidates · v9</h1><p>Review packet only. These sounds are <b>not approved or installed in the game</b>. Current runtime files remain unchanged. Use the same listening volume for all four rows. There is no autoplay.</p>',f'<p>All twelve aligned tracks share first150ms RMS {m["comparison"]["actual_common_target_dbfs"]:.2f} dBFS after one common {m["comparison"]["global_final_attenuation_db"]:.2f} dB attenuation. Peak ceiling−9 dBFS. Matching is technical; it does not establish perceived punch or realism.</p><p>A:45Hz high-pass +15kHz low-pass. B:the same, plus1.5dB at140Hz and ratio3 compression. No pitch, delay, wet/impact layers or reverb. Dry means the selected prepared recording excerpt, with format conversion, onset alignment, edge fades and level matching only.</p>']
 for source in m['sources']:
  weapon=source['weapon'];s.append(f'<h2>{html.escape(weapon.replace("_"," ").title())}</h2><p>Five-shot controls use the actual {source["cooldown_seconds"]:.2f}s cooldown. Each press plays one selected row. Compare without changing player volume.</p><table><tr><th>Track</th><th>One shot</th><th>Five shots at real cadence</th><th>Measured PCM24</th></tr>')
  for row in [r for r in m['rows'] if r['weapon']==weapon]:
   measure=row['individual']['wav_measurement'];s.append(f'<tr><td>{labels[row["kind"]]}<br><small><a href="{row["individual"]["wav"]}">24-bit WAV</a> · <a href="{row["individual"]["ogg"]}">OGG</a></small></td><td>{player(row["individual"]["ogg"])}</td><td>{player(row["repeat"]["ogg"])}</td><td><small>150ms RMS {measure["rms_first_150ms_dbfs"]:.2f} dBFS<br>peak {measure["peak_dbfs"]:.2f} dBFS</small></td></tr>')
  seq=next(r for r in m['sequences'] if r['weapon']==weapon);s.append(f'</table><p>Sequence: current → dry → A → B,0.7s gap. {player(seq["ogg"])} <a href="{seq["wav"]}">Sequence WAV</a></p>')
 s.append(f'<p>Licensed source: <a href="{m["source_url"]}">The Free Firearm Sound Library</a> by {html.escape(m["creator"])} · CC0 1.0. <a href="provenance/the-free-firearm-sound-library.html">Cached license evidence</a>. Private user MP3 references are not copied or redistributed.</p><p><a href="manifest.json">Exact source/archive hashes, source offsets, FFmpeg graphs, measurements and preservation checks</a></p></html>')
 (OUT/'index.html').write_text(''.join(s))
if __name__=='__main__':main()
