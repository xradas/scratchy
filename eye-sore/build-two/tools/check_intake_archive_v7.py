#!/usr/bin/env python3
"""Independent v7 portable archive/source reader; archived ELF is never executed."""
import argparse,hashlib,json,re,subprocess,tarfile,tempfile
from pathlib import Path
import verify_pale_ward_archive as portable
import check_theme_pack
ROOT=Path(__file__).resolve().parents[1]
GODOT=Path('/home/rikki/.local/share/eyesore-tools/4.7.2/Godot_v4.7.2-stable_linux.x86_64')
BASE='694a5050205575cfc436b2118b295bd45acbc773'
def sha(data):return hashlib.sha256(data).hexdigest()
def read(path):return json.loads(path.read_text(),object_pairs_hook=portable.unique_object)
def native(text):
 if text.startswith('Vector3('):return [float(x) for x in text[8:-1].split(',')]
 if text.startswith('Array[String]('):return json.loads(text[14:-1])
 return json.loads(text)
def scene_nodes(text):
 result={}
 for m in re.finditer(r'^\[node name="([^"]+)"[^\n]*parent="\."[^\n]*\]\n(.*?)(?=^\[node |\Z)',text,re.M|re.S):
  name,body=m.groups()
  if 'metadata/stage_pickup =' not in body and name!='Door_shortcut_one':continue
  meta={k:native(v) for k,v in re.findall(r'^metadata/([^=\n]+) = (.*)$',body,re.M)}
  position=re.search(r'^position = (.*)$',body,re.M)
  result[name]={'metadata':meta,'position':native(position.group(1)) if position else [0,0,0]}
 return result

def expected():
 specs={};fittings={x['id']:x for x in read(ROOT/'resources/campaign/room-fittings-v6.json')['levels']}
 for chapter in read(ROOT/'resources/campaign/catalog.json')['chapters']:
  for level in chapter['levels']:
   ident=level['id'];path=level['scene'];nodes=scene_nodes((ROOT/path.removeprefix('res://')).read_text());layout=read(ROOT/f'resources/campaign/{ident}-layout.json');rooms={}
   for room in layout['rooms']:
    x,y,z=room['center'];w,h,d=room['size'];rooms[room['id']]={'position':[x,y+h/2,z],'bounds':[w/2,h/2+1,d/2],'function':room['function'],'layout_mode':room['layout_mode']}
   specs[path]={'rooms':rooms,'pickups':{n:r for n,r in nodes.items() if 'stage_pickup' in r['metadata']},'props':{x['id']:x for x in fittings[ident]['placements']}}
   if ident=='pale_ward_01':shortcut={k:v for k,v in nodes['Door_shortcut_one']['metadata'].items() if k in ('first_open_normal','requires')}
 # Standalone pickups remain part of the all711 roster.
 for path in ('res://scenes/stages/pale_ward_expanded.tscn','res://scenes/stages/ash_citadel.tscn','res://scenes/stages/occupied_line.tscn'):
  if not (ROOT/path.removeprefix('res://')).is_file():continue
  nodes=scene_nodes((ROOT/path.removeprefix('res://')).read_text());specs[path]={'rooms':{},'props':{},'pickups':{n:r for n,r in nodes.items() if 'stage_pickup' in r['metadata']}}
 portable.require(sha((ROOT/'tools/pickups_rooms_prior_v6.json').read_bytes())=='7d2246c2ff82e67c4aa50cc433fce88c18ff2c414513dd0bf2089e105fbf9e4b','Sealed previous PCK native cue snapshot')
 prior=read(ROOT/'tools/pickups_rooms_prior_v6.json')
 return {'scenes':specs,'shortcut':shortcut,'cues':read(ROOT/'assets/audio/runtime-cues.json')['cues'],'profile_properties':prior['profile_properties'],'prior_cues':prior['profile_cues']}

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('archive',nargs='?',type=Path);p.add_argument('--source-preflight',action='store_true');p.add_argument('--expected-commit');p.add_argument('--report',type=Path,required=True);a=p.parse_args()
 spec=expected();report={'source_preflight':a.source_preflight}
 with tempfile.TemporaryDirectory(prefix='eyesore-intake-archive-v7-') as tmp:
  tmp=Path(tmp);pack=None
  if not a.source_preflight:
   portable.require(a.archive is not None and a.expected_commit is not None,'Archive and full expected commit required')
   structural=portable.verify(a.archive);portable.require(structural['source_commit']==a.expected_commit,'Archive commit mismatch')
   archive_record=read(a.archive.parent/'ARCHIVE.json');portable.require(archive_record['sha256']==structural['archive_sha256'] and archive_record['bytes']==a.archive.stat().st_size and archive_record['path']==a.archive.name,'External archive metadata mismatch')
   with tarfile.open(a.archive,'r:gz') as bundle:
    sums=portable.checksums(bundle.extractfile('SOURCE_SHA256SUMS').read().decode(),'SOURCE_SHA256SUMS')
    for path,digest in sums.items():
     local=ROOT/path;portable.require(local.is_file() and not local.is_symlink() and local.resolve().is_relative_to(ROOT) and sha(local.read_bytes())==digest,'Source fingerprint mismatch '+path)
    provenance=check_theme_pack.provenance(ROOT,bundle,sums)
    baseline=read(ROOT/'docs/intake-v7/baseline.json')['source_fingerprints']
    preserved=[path for path in baseline if path.startswith(('assets/','resources/weapons/')) or path in ('resources/combat_audio.tres','resources/campaign/balance-budget.json') or (path.startswith('scenes/campaign/') and not path.endswith('pale_ward_01.tscn'))]
    for path in preserved:portable.require(sums.get(path)==baseline[path],'Preserved original asset/level '+path)
    build=json.loads(bundle.extractfile('BUILD.json').read());portable.require(build.get('source_git_status')=='' and build['source_commit']==a.expected_commit,'Unclean/wrong source checkpoint')
    portable.require(sha(GODOT.read_bytes())==build['engine_binary']['sha256'],'Pinned reader engine mismatch')
    pack=tmp/'archive.x86_64';pack.write_bytes(bundle.extractfile(build['executable']['path']).read());pack.chmod(0o600)
    report.update({'archive':str(a.archive.resolve()),'archive_sha256':structural['archive_sha256'],'source_commit':a.expected_commit,'source_fingerprints_verified':len(sums),'preserved_baseline_files':len(preserved),'provenance_records_verified':len(provenance),'portable_archive_pass':True})
  inp=tmp/'expected.json';out=tmp/'native.json';inp.write_text(json.dumps(spec));(tmp/'project.godot').write_text('[application]\nconfig/name="Independent Intake Audit"\n')
  cmd=[str(GODOT),'--headless','--path',str(tmp if pack else ROOT)]
  if pack:cmd+=['--main-pack',str(pack)]
  cmd+=['--script',str(Path(__file__).with_suffix('.gd')),'--','--expected='+str(inp),'--report='+str(out)]
  proc=subprocess.run(cmd,cwd=tmp,capture_output=True,text=True,timeout=300);log=proc.stdout+proc.stderr
  a.report.parent.mkdir(parents=True,exist_ok=True);a.report.with_suffix('.log').write_text(log)
  portable.require(out.is_file(),'No native report: '+log[-3000:]);native_report=read(out)
  portable.require(proc.returncode==0 and native_report['status']=='passed' and not re.search(r'(?:SCRIPT ERROR:|^ERROR:)',log,re.M),'Native probe failed: '+log[-3000:])
  report.update({'status':'passed','native':native_report,'scope':'Independent archive checksums, exact source fingerprints, provenance payload, unchanged baseline assets/eight maps and external pinned Godot --main-pack native object/audio audit. This probe does not execute the shipped ELF; actual campaign runs are separate.'})
  a.report.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
if __name__=='__main__':main()
