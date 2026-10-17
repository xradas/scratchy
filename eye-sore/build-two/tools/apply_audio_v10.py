#!/usr/bin/env python3
"""Dry-run by default. Register only the three explicitly selected v9 audio rows."""
import argparse, hashlib, json, os, re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def canonical(x):return hashlib.sha256(json.dumps(x,sort_keys=True,separators=(',',':')).encode()).hexdigest()
def blocks(text):
 return list(re.finditer(r'^\[sub_resource[^\n]*\]\n.*?(?=^\[|\Z)',text,re.M|re.S))
def cue_block(text,cue):
 found=[m for m in blocks(text) if f'identifier = &"{cue}"\n' in m.group()]
 assert len(found)==1,f'Profile cue block missing/duplicated: {cue}'
 return found[0]
def normalized_profile(text,selected):
 for item in selected:
  cue=item['cue'];rid=item['profile_ext_resource_id']
  pattern=r'(^\[ext_resource type="AudioStream" path=")[^"]+(" id="'+re.escape(rid)+r'"\]$)'
  text,count=re.subn(pattern,lambda m:m[1]+'<SELECTED_STREAM>'+m[2],text,flags=re.M);assert count==1
  b=cue_block(text,cue);body=re.sub(r'^gain_db = [^\n]+\n','',b.group(),flags=re.M)
  text=text[:b.start()]+body+text[b.end():]
 return hashlib.sha256(text.encode()).hexdigest()
def patch_profile(text,selected):
 for item in selected:
  rid=item['profile_ext_resource_id'];cue=item['cue']
  pattern=r'(^\[ext_resource type="AudioStream" path=")([^"]+)(" id="'+re.escape(rid)+r'"\]$)'
  match=re.search(pattern,text,re.M);assert match and match[2] in [item['before']['file'],item['runtime_file']],f'Profile stream drift: {cue}'
  text=text[:match.start(2)]+item['runtime_file']+text[match.end(2):]
  b=cue_block(text,cue);body=b.group()
  gains=re.findall(r'^gain_db = (.+)$',body,re.M);assert len(gains)<=1
  if gains:
   assert float(gains[0]) in [item['before']['gain_db'],4.0],f'Profile gain drift: {cue}'
   body=re.sub(r'^gain_db = [^\n]+$','gain_db = 4.0',body,flags=re.M)
  else:
   assert item['profile_gain_line_before'] is None,f'Unexpected missing gain: {cue}'
   assert 'bus = &"Weapons"\n' in body
   body=body.replace('bus = &"Weapons"\n','bus = &"Weapons"\ngain_db = 4.0\n',1)
  text=text[:b.start()]+body+text[b.end():]
 return text

def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--apply',action='store_true')
 parser.add_argument('--ledger',type=Path,default=ROOT/'assets/audio/runtime-cues.json')
 parser.add_argument('--profile',type=Path,default=ROOT/'resources/combat_audio.tres')
 parser.add_argument('--selection',type=Path,default=ROOT/'docs/production-v10/audio-selection.json')
 args=parser.parse_args();spec=json.loads(args.selection.read_text());selected=spec['selected']
 manifest=json.loads((ROOT/'concepts/audio-v9/manifest.json').read_text())
 assert sha(ROOT/'concepts/audio-v9/manifest.json')==spec['audition_manifest_sha256'],'Audition manifest drift'
 for item in selected:
  row=next(r for r in manifest['rows'] if r['weapon']==item['weapon'] and r['kind']==item['selected_row'])
  for fmt in ['ogg','wav']:
   assert sha(ROOT/item['audition_files'][fmt])==row['individual'][fmt+'_sha256']==item['selected_sha256'][fmt]
   assert sha(ROOT/item['selected_assets'][fmt])==item['selected_sha256'][fmt],'Selected stream bytes drift'
  assert sha(ROOT/item['source_original'])==item['source_original_sha256'],'Original recording drift'
  assert sha(ROOT/item['license_evidence'])==item['license_evidence_sha256'],'License evidence drift'
 old_ledger=args.ledger.read_text();data=json.loads(old_ledger);cues=data['cues']
 chosen={i['cue'] for i in selected};untouched={k:v for k,v in cues.items() if k not in chosen}
 assert len(untouched)==54 and canonical(untouched)==spec['preservation']['other_54_cues_sha256'],'Unselected cue drift'
 assert canonical({k:v for k,v in data.items() if k!='cues'})==spec['preservation']['ledger_other_fields_sha256'],'Music/status metadata drift'
 proposed=old_ledger
 for item in selected:
  intermediate=dict(item['before']);intermediate['file']=item['runtime_file'];intermediate['gain_db']=4.0
  expected=dict(intermediate)
  expected.update({'source_manifest':'concepts/audio-v9/manifest.json','source_ids':[item['weapon']],'selected_row':item['selected_row'],'selection_manifest':'docs/production-v10/audio-selection.json'})
  assert expected==item['after'],'Selection provenance specification drift'
  assert cues[item['cue']] in [item['before'],intermediate,expected],f'Selected cue drift: {item["cue"]}'
  match=re.search(r'^    '+re.escape(json.dumps(item['cue']))+r':\s*',proposed,re.M);assert match,'Unexpected ledger formatting'
  _,length=json.JSONDecoder().raw_decode(proposed[match.end():])
  replacement=json.dumps(expected,indent=2).replace('\n','\n    ')
  proposed=proposed[:match.end()]+replacement+proposed[match.end()+length:]
 assert {k:v for k,v in json.loads(proposed)['cues'].items() if k not in chosen}==untouched
 old_profile=args.profile.read_text()
 assert normalized_profile(old_profile,selected)==spec['preservation']['profile_outside_allowed_fields_sha256'],'Profile outside allowed fields drift'
 profile=patch_profile(old_profile,selected)
 assert normalized_profile(profile,selected)==spec['preservation']['profile_outside_allowed_fields_sha256'],'Unexpected profile mutation'
 assert patch_profile(profile,selected)==profile,'Profile patch not idempotent'
 if args.apply:
  for path,content in [(args.ledger,proposed),(args.profile,profile)]:
   if path.read_text()==content:continue
   temp=path.with_name(path.name+'.audio-v10.tmp');temp.write_text(content);os.replace(temp,path)
 print(json.dumps({'mode':'applied' if args.apply else 'dry_run','changed_cues':sorted(chosen),'playback_gain_db':4.0,'stream_bytes':'unchanged from user-selected v9 auditions','selected_provenance':'v9 source weapon + selected row + v10 selection ledger','other_cues_preserved':54,'profile_music_buses_definitions_preserved':True,'ledger_changed':proposed!=old_ledger,'profile_changed':profile!=old_profile},indent=2))
if __name__=='__main__':main()
