#!/usr/bin/env python3
import pathlib,json,hashlib,subprocess,array,math
B=pathlib.Path(__file__).resolve().parent;m=json.loads((B/'manifest.json').read_text())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
required={'pistol_fire','shotgun_fire','melee_swing','empty','pistol_flesh','shotgun_flesh','melee_flesh','pistol_armor','shotgun_armor','melee_armor','pistol_hard','shotgun_hard','melee_hard','unsealed_hurt','unsealed_death','unsealed_attack_warning','vessel_hurt','vessel_death','vessel_attack_warning','projectile_release','projectile_impact','projectile_hard','player_hurt','menu_music','level_music_biotech_candidate','level_music_fortress_candidate'}
assert set(m['cues'])==required
checks=[]
for key,e in m['cues'].items():
 assert e['bus'] in ['Weapons','World','Creatures','Music']
 expected=2 if e['bus']=='Music' else 1
 for fk,hk in [('file','sha256'),('dry_file','dry_sha256'),('audition_file','audition_sha256'),('ogg_file','ogg_sha256'),('reference_wav_file','reference_wav_sha256')]:
  if fk not in e:continue
  p=B/e[fk];assert sha(p)==e[hk],(key,fk,'hash')
  d=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration:stream=channels','-of','json',str(p)],text=True))
  assert float(d['format']['duration'])>0,(key,fk,'empty')
  assert d['streams'][0]['channels']==expected,(key,fk,'channels')
  subprocess.run(['ffmpeg','-v','error','-i',str(p),'-f','null','-'],check=True,capture_output=True)
  checks.append({'file':e[fk],'sha256':'pass','decode':'pass','duration_seconds':float(d['format']['duration']),'channels':expected})
 if e['bus']!='Music':assert e['levels']['true_peak_dbtp'] < -5
for s in m['sources']:
 assert sha(B/s['original'])==s['original_sha256']
 for f in s['license_evidence']:assert (B/f).exists()
# Approved original menu music and Stage1 music excerpt retain their earlier hashes.
old=json.loads((B.parent/'audio'/'manifest.json').read_text());abelian=next(s for s in old['sources'] if s['id']=='abelian')
assert sha(B/'music'/'menu_music.wav')==abelian['sha256']
for e in old['exports']:
 p=B.parent/'audio'/e['file'];assert sha(p)==e['sha256']

onsets={}
for k in ['pistol_fire','shotgun_fire','pistol_flesh','shotgun_flesh','melee_flesh','pistol_armor','shotgun_armor','melee_armor','unsealed_attack_warning','vessel_attack_warning']:
 p=B/m['cues'][k]['file'];raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(p),'-ac','1','-ar','48000','-f','f32le','-']);a=array.array('f');a.frombytes(raw);pk=max(abs(x) for x in a);i=next(j for j,x in enumerate(a) if abs(x)>=pk*.1);onsets[k]=round(i/48,2)
assert onsets['pistol_fire']<15 and onsets['shotgun_fire']<15
mix_checks=[]
for e in m['auditions']:
 p=B/e['file'];assert sha(p)==e['sha256'];raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(p),'-f','f32le','-']);a=array.array('f');a.frombytes(raw);pk=max(abs(x) for x in a);assert pk<.999,(e['file'],'clipping')
 mix_checks.append({'file':e['file'],'sample_peak_dbfs':round(20*math.log10(pk),2),'near_full_scale_samples':sum(abs(x)>.999 for x in a),'sha256':'pass','decode':'pass'})
result={'cue_keys':len(required),'files_checked':len(checks),'sources_checked':len(m['sources']),'reference_files':checks,'mix_checks':mix_checks,'onset_milliseconds_at_minus20db_relative_peak':onsets,'approved_menu_original_sha256':sha(B/'music'/'menu_music.wav'),'menu_original_byte_identical_to_stage1_source':True,'stage1_reference_cues_hashes_unchanged':True,'peak_check':'All23 SFX reference WAV true peaks below-5dBTP. No clipping in aggregate matrix or warning/music review mix.','short_lufs_note':'Very short clips may have null integrated LUFS because the measurement window cannot establish integrated loudness. True peaks remain measured.','subjective_listening':'Not completed; user approval of new combat cues remains pending.'}
(B/'verification'/'checks.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:result[k] for k in ['cue_keys','files_checked','sources_checked','mix_checks','onset_milliseconds_at_minus20db_relative_peak','approved_menu_original_sha256']},indent=2))
