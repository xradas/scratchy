from audio_tools import *
import shutil,copy
OLD=B.parent/'combat-audio'
for d in ['cues','auditions','music']: (B/d).mkdir(exist_ok=True)
p=lambda n:B/'originals'/n
spec={
'pistol_flesh':(-9,'World',[(p('qubodupPunch/qubodupPunch02.flac'),0,.21,1.12,'highpass=f=85,equalizer=f=190:t=q:w=0.8:g=2,lowpass=f=6000',1,0)],'Brief recorded punching-bag tick and compact dry body thunk.'),
'shotgun_flesh':(-7,'World',[(p('qubodupPunch/qubodupPunch01.flac'),0,.29,.9,'highpass=f=65,equalizer=f=160:t=q:w=0.8:g=3,lowpass=f=6500',1,0),(p('rubberduck/wood_cracking_01.ogg'),0,.16,.95,'highpass=f=160,lowpass=f=5200',.22,.005)],'Weighted punching-bag impact with restrained dry wooden crack; one aggregate contact per target.'),
'melee_flesh':(-8,'World',[(p('qubodupPunch/qubodupPunch03.flac'),0,.24,.98,'highpass=f=75,equalizer=f=210:t=q:w=0.8:g=2,lowpass=f=5500',1,0)],'Solid short punching-bag strike; contact is separate from hurt voice.'),
'pistol_armor':(-10,'World',[(p('rubberduck/metal_hit_01.ogg'),0,.18,1.08,'highpass=f=130,equalizer=f=3000:t=q:w=1:g=-3,lowpass=f=6500',1,0)],'Compact recorded metal tick with short ring.'),
'shotgun_armor':(-8,'World',[(p('rubberduck/metal_hit_03.ogg'),0,.27,.9,'highpass=f=70,equalizer=f=220:t=q:w=.8:g=3,lowpass=f=6000',1,0),(p('rubberduck/wood_hammer_01.ogg'),0,.2,.92,'highpass=f=70,lowpass=f=4000',.35,.004)],'Lower weighted metal strike with short hammer body.'),
'melee_armor':(-9,'World',[(p('rubberduck/metal_hit_05.ogg'),0,.26,.98,'highpass=f=90,equalizer=f=350:t=q:w=.8:g=2,lowpass=f=6000',1,0)],'Distinct dry metal clonk with restrained decay.'),
'pistol_hard':(-14,'World',[(p('rubberduck/wood_hit_01.ogg'),0,.17,1.1,'highpass=f=130,lowpass=f=5500',1,0)],'Quiet short solid-object fallback.'),
'shotgun_hard':(-12,'World',[(p('rubberduck/wood_hammer_01.ogg'),0,.23,.92,'highpass=f=80,lowpass=f=5200',1,0)],'Weighted solid-object fallback.'),
'melee_hard':(-13,'World',[(p('rubberduck/wood_hit_03.ogg'),0,.23,.98,'highpass=f=85,lowpass=f=5200',1,0)],'Dry knock fallback.'),
'projectile_impact':(-11,'World',[(p('qubodupPunch/qubodupPunch04.flac'),0,.22,.96,'highpass=f=80,lowpass=f=5300',1,0)],'Dry target contact for projectile; contains no voice.'),
'projectile_hard':(-14,'World',[(p('rubberduck/wood_hit_01.ogg'),0,.19,.94,'highpass=f=100,lowpass=f=5200',1,0)],'Quiet solid projectile fallback.'),
'projectile_release':(-14,'Creatures',[(OLD/'originals/swosh-13.flac',.045,.24,1.15,'highpass=f=120,lowpass=f=6500',1,0)],'Short recorded bamboo air swing; separate committed projectile launch cue.'),
}
voices=[('unsealed_hurt','3grunt3.wav',.34,.96,-12,'Clipped low human pain grunt.'),('vessel_hurt','3grunt1.wav',.35,.85,-11,'Distinct human grunt take with modest lower pitch and coarse low-mid body.'),('unsealed_death','3grunt5.wav',.42,.96,-12,'Brief dry human terminal grunt, separate take from hurt.'),('vessel_death','3grunt6.wav',.42,.86,-11,'Lower brief human effort/death grunt, no long groan.'),('unsealed_attack_warning','1yell6.wav',.30,.98,-12,'Short human attack effort cue before commitment.'),('vessel_attack_warning','2yell1.wav',.32,.86,-11,'Distinct lower human attack effort cue.'),('player_hurt','1yell10.wav',.29,1,-12,'Brief human player pain response.')]
for key,fn,dur,pitch,target,desc in voices:
 src=p('haelDB/'+fn);spec[key]=(target,'Creatures',[(src,active_start(src),dur,pitch,'highpass=f=95,lowpass=f=6800',1,0)],desc)
# Copy only unchanged attack/empty outputs and their selected originals/evidence.
om=json.loads((OLD/'manifest.json').read_text());cues={};sources=[]
def cp(rel):
 dest=B/rel;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(OLD/rel,dest)
for key in ['pistol_fire','shotgun_fire','melee_swing','empty']:
 c=copy.deepcopy(om['cues'][key]);c['preservation']='Byte-identical to prior pack; damage revision does not alter this attack cue.'
 for fld in ['file','ogg_file','dry_file','audition_file']:cp(c[fld])
 cues[key]=c
for sid in ['pistol','shotgun','swish13','click']:
 s=copy.deepcopy(next(x for x in om['sources'] if x['id']==sid));cp(s['original'])
 for rel in s['license_evidence']:cp(rel)
 sources.append(s)
# Bring launch source inside this portable SFX folder.
for key,(target,bus,layers,desc) in list(spec.items()):
 layers2=[]
 for src,*rest in layers:
  if src.is_relative_to(OLD):src=B/src.relative_to(OLD)
  layers2.append((src,*rest))
 spec[key]=(target,bus,layers2,desc)
for key,(target,bus,layers,desc) in spec.items():
 out=B/'cues'/f'{key}.wav';dry,edits=build(layers,out,target,key)
 ab=B/'auditions'/f'{key}-dry-then-designed.wav'
 d=max(float(probe(dry)['format']['duration']),float(probe(out)['format']['duration']))
 mix([(dry,.2,1),(out,.2+d+.45,1)],ab,duration=2*d+1);ogg(ab)
 cues[key]={'file':str(out.relative_to(B)),'ogg_file':str(out.with_suffix('.ogg').relative_to(B)),'bus':bus,'gain_db':0,'description':desc,'edits':edits,'export_peak_target_dbfs':target,'sha256':sha(out),'ogg_sha256':sha(out.with_suffix('.ogg')),'dry_file':str(dry.relative_to(B)),'dry_sha256':sha(dry),'dry_edits':'Same source excerpts and gain/placement only; no pitch or EQ. Composite dry reference is not a source original.','audition_file':str(ab.relative_to(B)),'audition_sha256':sha(ab),'technical':probe(out),'source_ids':[]}
 print('Built',key,probe(out)['format']['duration'],flush=True)
# Source records for each selected recording.
used={e['original'] for c in cues.values() for e in c.get('edits',[]) if 'original' in e}
for rel in sorted(used):
 if not rel.startswith(('originals/qubodupPunch/','originals/rubberduck/','originals/haelDB/')):continue
 src=B/rel
 if 'qubodupPunch/' in rel:creator="Iwan 'qubodup' Gabovitch";title='Punch — recorded punching bag';url='https://opengameart.org/content/punch';dl='https://opengameart.org/sites/default/files/qubodupPunch.7z';ev=['provenance/punch.html','provenance/qubodup-punch-source-53985.html'];rec='Real punching bag recorded with Zoom H2; no meat or wet body source.'
 elif 'rubberduck/' in rel:creator='rubberduck';title='100 CC0 metal and wood SFX';url='https://opengameart.org/content/100-cc0-metal-and-wood-sfx';dl='https://opengameart.org/sites/default/files/100-CC0-wood-metal-SFX.zip';ev=['provenance/100-cc0-metal-and-wood-sfx.html'];rec='Recorded metal/wood foley; solid physical percussive source.'
 else:creator='HaelDB (four male performers, not individually named on source page)';title='Male Grunt/Yelling sounds';url='https://opengameart.org/content/male-gruntyelling-sounds';dl='https://opengameart.org/sites/default/files/yelling%20sounds.zip';ev=['provenance/male-gruntyelling-sounds.html'];rec='Real male voice performances; Neumann microphone and Avalon2022 preamp. CC0 alternative selected from offered licenses.'
 sid='dry-'+src.stem;sources.append({'id':sid,'title':title,'creator':creator,'source_url':url,'download_url':dl,'license':'CC0 1.0','license_url':'https://creativecommons.org/publicdomain/zero/1.0/','license_evidence':ev,'original':rel,'original_sha256':sha(src),'technical':probe(src),'recording_description':rec})
for c in cues.values():
 if not c.get('source_ids'):
  for e in c['edits']:
   sid=next(x['id'] for x in sources if x['original']==e['original']);c['source_ids'].append(sid);e['source_id']=sid
# Music: compact new delivery copies ONLY unchanged runtime OGG. Full originals explicitly retained in sibling pack.
for key in ['menu_music','level_music_biotech_candidate','level_music_fortress_candidate']:
 old=om['cues'][key];rel=old.get('ogg_file',old['file']);cp(rel);c=copy.deepcopy(old)
 c['file']=rel;c['sha256']=sha(B/rel);c['preservation']='Runtime OGG copied byte-identically; original and prior PCM reference explicitly retained in sibling combat-audio.'
 for field in ['reference_wav_file','original_unchanged_file','audition_file']:
  if field in c:c[field]='../combat-audio/'+c[field]
 if key!='menu_music':c['prior_reference_wav_file']='../combat-audio/'+old['file'];c['prior_reference_wav_sha256']=old['sha256'];c['technical']=probe(B/rel)
 cues[key]=c
 for sid in c['source_ids']:
  s=copy.deepcopy(next(x for x in om['sources'] if x['id']==sid));s['original']='../combat-audio/'+s['original']
  for rel2 in s['license_evidence']:cp(rel2)
  sources.append(s)
# Clean 10s primary preview preserved from first direction; fuller matrix uses only damage, no music/fire masking.
for ext in ['wav','ogg']:shutil.copy2(B/'preview'/('dry_direction_10s.'+ext),B/'auditions'/('primary-dry-10s.'+ext))
events=[]
for i,key in enumerate(['pistol_flesh','pistol_armor','shotgun_flesh','shotgun_armor','melee_flesh','melee_armor']):
 t=.4+i*1.8;events.append((B/cues[key]['file'],t,1));vk='unsealed_hurt' if key.endswith('flesh') else 'vessel_hurt';events.append((B/cues[vk]['file'],t+.08,1))
matrix=B/'auditions'/'dry-material-matrix-12s.wav';mix(events,matrix,duration=12);ogg(matrix)
m={'schema_version':3,'stage':'Dry damage revision after explicit wet pack rejection','approval_status':'New damage cues are candidates for user listening; previous wet damage pack is rejected research. Existing attack and music outputs are unchanged.','cues':cues,'sources':sources,'routing_rules':om['routing_rules'],'listening_status':'Technical decode, duration, channels, peaks and hashes checked only. No subjective agent listening is claimed.','references':[{'url':'https://github.com/id-Software/DOOM/blob/master/linuxdoom-1.10/p_enemy.c','file':'provenance/doom-p_enemy.c','lesson':'A_Pain selects actor-specific painsound; pain is separate from contact.'},{'url':'https://github.com/id-Software/Quake/blob/master/qw-qc/player.qc','file':'provenance/quake-player.qc','lesson':'PainSound uses voice channel and a 0.5 second pain cooldown. Code establishes event cadence, not waveform timbre or duration.'}],'auditions':[{'file':'auditions/primary-dry-10s.wav','description':'Pistol/shotgun/melee body contacts with brief human grunt; last event unpitched voice reference.'},{'file':'auditions/dry-material-matrix-12s.wav','description':'Pistol body/armor, shotgun body/armor, melee body/armor; separate brief identity hurt response.'}],'music_portability':'Original full music WAVs remain in ../combat-audio with hashes. Include that originals/music directory plus menu_music.wav and these referenced license pages when archiving the complete project; no duplicate large WAVs made here.'}
m['routing_rules']['projectile_contact']='Dry punching-bag contact for projectile_impact; quiet solid object projectile_hard. Player pain is a separate human voice.'
for r in m['references']:r['sha256']=sha(B/r['file'])
for a in m['auditions']:a['sha256']=sha(B/a['file'])
(B/'manifest.json').write_text(json.dumps(m,indent=2)+'\n')
