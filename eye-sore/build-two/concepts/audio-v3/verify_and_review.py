from audio_tools import *
import html
m=json.loads((B/'manifest.json').read_text());records=[];errors=[]
def levels(p):
 t=run(F+['-i',str(p),'-af','loudnorm=I=-19:TP=-3:LRA=11:print_format=json','-f','null','-']);j=json.loads(t[t.rfind('{'):t.rfind('}')+1]);out={}
 for k,new in [('input_i','integrated_lufs'),('input_tp','true_peak_dbtp')]:
  v=float(j[k]);out[new]=v if math.isfinite(v) else None
 out['measurement']='FFmpeg loudnorm input analysis; short-event integrated LUFS may be unavailable or unrepresentative.'
 return out
for key,c in m['cues'].items():
 p=B/c['file'];r={'key':key,'file':c['file'],'sha256':sha(p),'technical':probe(p)}
 if r['sha256']!=c['sha256']:errors.append(key+' main hash mismatch')
 c['levels']=levels(p);r['levels']=c['levels']
 run(F+['-i',str(p),'-f','null','-'])
 for filefield,hashfield in [('ogg_file','ogg_sha256'),('dry_file','dry_sha256'),('audition_file','audition_sha256')]:
  if filefield in c:
   q=B/c[filefield]
   if sha(q)!=c[hashfield]:errors.append(key+' '+filefield+' mismatch')
   run(F+['-i',str(q),'-f','null','-'])
 if c['bus'] not in ['Weapons','World','Creatures','Music']:errors.append(key+' bus')
 if c['bus']!='Music':
  if r['technical']['streams'][0]['channels']!=1:errors.append(key+' spatial mono')
  raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(p),'-ac','1','-ar','48000','-f','f32le','-']);a=array.array('f');a.frombytes(raw);pk=max(abs(x) for x in a);r['onset_20db_below_peak_ms']=round(next(i for i,x in enumerate(a) if abs(x)>=pk*.1)/48,2)
  r['sample_peak_dbfs']=round(20*math.log10(pk),2)
  if pk>=.99:errors.append(key+' clipping risk')
  if key not in ['pistol_fire','shotgun_fire','melee_swing','empty'] and float(r['technical']['format']['duration'])>.51:errors.append(key+' too long')
 records.append(r);print('Verified',key,flush=True)
for s in m['sources']:
 if sha(B/s['original'])!=s['original_sha256']:errors.append(s['id']+' original hash mismatch')
 for rel in s['license_evidence']:
  if not (B/rel).is_file():errors.append(s['id']+' missing license')
  s.setdefault('license_evidence_sha256',{})[rel]=sha(B/rel)
# Confirm all preserved attack and music outputs match the prior pack bytes.
om=json.loads((B.parent/'combat-audio'/'manifest.json').read_text())
for key in ['pistol_fire','shotgun_fire','melee_swing','empty','menu_music','level_music_biotech_candidate','level_music_fortress_candidate']:
 c=m['cues'][key];oc=om['cues'][key];orel=oc.get('ogg_file',oc['file']) if c['bus']=='Music' else oc['file']
 if sha(B/c['file'])!=sha(B.parent/'combat-audio'/orel):errors.append(key+' preservation mismatch')
(B/'verification'/'checks.json').write_text(json.dumps({'errors':errors,'runtime_cues_checked':len(records),'original_sources_checked':len(m['sources']),'checks':'Decode every runtime WAV/OGG and AB sample; manifest hashes, original hashes and license presence; spatial mono; new dry cue durations <=0.51s; sample headroom; unchanged attacks/music byte comparison.','records':records},indent=2)+'\n')
(B/'manifest.json').write_text(json.dumps(m,indent=2)+'\n')
primary=['pistol_flesh','shotgun_flesh','melee_flesh','pistol_armor','shotgun_armor','melee_armor','unsealed_hurt','vessel_hurt','unsealed_death','vessel_death','unsealed_attack_warning','vessel_attack_warning','player_hurt']
sec=[k for k in m['cues'] if k not in primary and m['cues'][k]['bus']!='Music']
def block(k):
 c=m['cues'][k];return f'<article><h3>{html.escape(k)}</h3><p>{html.escape(c["description"])}</p><label>Designed</label><audio controls preload="none" src="{c.get("ogg_file",c["file"])}"></audio><label>A/B: selected source excerpt, pause, designed</label><audio controls preload="none" src="{c["audition_file"]}"></audio></article>'
page='''<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Dry damage listening check</title><style>body{font:16px system-ui;background:#151718;color:#eee;margin:auto;padding:28px;max-width:1100px}h1{font-size:28px}p{color:#bfc9c8;line-height:1.5}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(290px,1fr));gap:16px}article{border:1px solid #424b4b;padding:16px;border-radius:8px}h3{margin-top:0}audio{width:100%;display:block;margin:7px 0 16px}label{font-size:13px;color:#aebaba}a{color:#a6d6c3}summary{cursor:pointer;margin:24px 0}</style><h1>Dry damage direction check</h1><p>New candidates: compact punching-bag / solid-object contacts and short real human grunts. Existing gunfire and music remain unchanged. Prior wet damage cues remain rejected research. Source code references inform separate contact/pain events and short cadence; no Doom or Quake sound assets are copied.</p><h2>Start here · 10 seconds</h2><p>Pistol body, shotgun body, melee body, each followed by the separate brief grunt. Final event: unpitched human source reference.</p><audio controls preload="none" src="auditions/primary-dry-10s.ogg"></audio><h2>Six contacts · 12 seconds</h2><p>Pistol body / armor → shotgun body / armor → melee body / armor. Human hurt responses are separate events.</p><audio controls preload="none" src="auditions/dry-material-matrix-12s.ogg"></audio><p>Technical verification is complete; sound quality and in-game masking still require user listening. <a href="README.md">Credits and mixing notes</a> · <a href="manifest.json">Source and edit ledger</a></p><main>'''
page+=''.join(block(k) for k in primary)+'</main><details><summary>Fallback contacts, projectile cues and unchanged weapons</summary><main>'+''.join(block(k) for k in sec)+'</main></details>'
(B/'index.html').write_text(page)
print('RESULT',errors)
if errors:raise RuntimeError(errors)
