#!/usr/bin/env python3
"""Strict v9 source/archive audit with unchanged v7 native object/audio reader.

No shipped ELF execution, packager import, production/provenance writes or relaxed
asset exceptions. Source preflight is explicitly not an archive acceptance claim.
"""
from __future__ import annotations
import argparse,ast,hashlib,json,os,re,subprocess,tarfile,tempfile
from pathlib import Path
import check_intake_archive_v7 as v7
import check_theme_pack
import verify_pale_ward_archive as portable
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'verification/production-v9/archive'
CHANGED={'scripts/main.gd','scripts/player.gd','scenes/campaign/pale_ward_01.tscn','resources/campaign/room-fittings-v6.json'}
TABLE={
 'TBaseSpine':([0,.07,0],[1.7,.14,.32]),
 'TBaseFoot-1':([-.65,.06,0],[.20,.12,1.0]),
 'TBaseFoot1':([.65,.06,0],[.20,.12,1.0]),
 'CentralPedestal':([0,.39,0],[.42,.66,.52]),
 'TopSupport':([0,.67,0],[2.4,.10,1.1]),
 'EnamelSegment0':([-.8,.81,0],[.76,.18,1.02]),
 'EnamelSegment1':([0,.81,0],[.76,.18,1.02]),
 'EnamelSegment2':([.8,.81,0],[.76,.18,1.02]),
}
def sha(data):return hashlib.sha256(data).hexdigest()
def read(path):return json.loads(path.read_text(),object_pairs_hook=portable.unique_object)
def git_bytes(*args):return subprocess.check_output(['git',*args],cwd=ROOT)
def git_blob(commit,path):return git_bytes('show',commit+':'+git_bytes('rev-parse','--show-prefix').decode().strip()+path)

def snapshot_policy():
 """Read literal collection policy via AST; never import/execute the packager."""
 path=ROOT/'tools/package_pale_ward.py';tree=ast.parse(path.read_text())
 excluded=next(ast.literal_eval(n.value) for n in tree.body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='EXCLUDED' for t in n.targets))
 provenance=next(n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='provenance_files')
 roots=ast.literal_eval(provenance.body[0].value)
 direct=provenance.body[1].value
 portable.require(isinstance(direct,ast.List),'Expected declarative provenance direct-file list')
 extras=[]
 for item in direct.elts:
  portable.require(isinstance(item,ast.BinOp) and isinstance(item.op,ast.Div) and isinstance(item.left,ast.Name) and item.left.id=='PROJECT' and isinstance(item.right,ast.Constant) and isinstance(item.right.value,str),'Unexpected provenance path policy expression')
  extras.append(item.right.value)
 snapshot=next(n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='source_snapshot')
 policy=ast.get_source_segment(path.read_text(),snapshot)
 portable.require('source_snapshot(extra: list[Path])' in policy and 'EXCLUDED' in policy and 'paths += extra +' in policy,'Snapshot collector policy changed; explicit auditor update needed')
 paths={p for p in ROOT.rglob('*') if p.is_file() and not set(p.relative_to(ROOT).parts[:-1])&set(excluded) and '__pycache__' not in p.parts and not p.name.startswith('.')}
 for root in roots:
  paths.update(p for p in (ROOT/root).rglob('*') if p.is_file() and p.suffix in {'.json','.txt','.md'} and not(root in {'concepts/arsenal-architecture-v2','concepts/campaign-v3'} and 'review' in p.relative_to(ROOT/root).parts))
 paths.update(ROOT/p for p in extras)
 paths.update(ROOT/p for p in ['assets/audio/CREDITS.md','assets/VISUAL_CREDITS.md','tools/godot.sh','tools/package_engine_licenses.gd','tools/package_pale_ward.py'])
 result={}
 for p in sorted(paths):
  relative=p.relative_to(ROOT).as_posix()
  portable.require(portable.safe_path(relative) and p.is_file() and not p.is_symlink(),'Unsafe/missing source input '+relative)
  result[relative]=sha(p.read_bytes())
 return result,{'collector':'Restricted AST literal policy read from tools/package_pale_ward.py; no packager import/execution','collector_sha256':sha(policy.encode()),'packager_sha256':sha(path.read_bytes()),'provenance_roots':list(roots),'excluded_directories':sorted(excluded)}

def git_fingerprints(commit,mapping):
 portable.require(portable.COMMIT.fullmatch(commit) is not None,'Full expected commit hash required')
 prefix=git_bytes('rev-parse','--show-prefix').decode().strip()
 queries=''.join(commit+':'+prefix+p+'\n' for p in mapping).encode()
 process=subprocess.run(['git','cat-file','--batch'],cwd=ROOT,input=queries,capture_output=True,check=True)
 data=process.stdout;cursor=0
 for path,expected in mapping.items():
  end=data.index(b'\n',cursor);header=data[cursor:end].split();cursor=end+1
  portable.require(len(header)==3 and header[1]==b'blob','Expected checkpoint blob missing '+path)
  size=int(header[2]);body=data[cursor:cursor+size];cursor+=size
  portable.require(data[cursor:cursor+1]==b'\n' and sha(body)==expected,'Source differs from explicit checkpoint blob '+path);cursor+=1
 portable.require(cursor==len(data),'Unexpected Git batch response tail')
 return len(mapping)

def clinical_expected(batch):
 plan=read(ROOT/'docs/production-v9/clinical-layout.json');placements={}
 for room in plan['rooms']:
  for group in room['groups']:
   for index,at in enumerate(group['authored_positions'],1):
    ident=group['id']+'.'+str(index)
    placements[ident]={'type':group['type'],'position':[room['center'][0]+at[0],room['center'][1],room['center'][2]+at[1]],'heading':at[2]}
 portable.require(len(placements)==23,'Exact approved23 clinical target instances')
 raw=git_blob(batch['baseline_runtime_source_commit'],'resources/campaign/room-fittings-v6.json')
 portable.require(sha(raw)==batch['baseline_fingerprints']['resources/campaign/room-fittings-v6.json'],'Frozen v8 furnishing report identity')
 previous=json.loads(raw,object_pairs_hook=portable.unique_object);current=read(ROOT/'resources/campaign/room-fittings-v6.json')
 for level in previous['levels']:
  if level['id']!='pale_ward_01':continue
  found=set()
  for p in level['placements']:
   if p['id'] not in placements:continue
   target=placements[p['id']];found.add(p['id'])
   portable.require(p['type']==target['type'],'Clinical target inventory identity drift '+p['id'])
   if (abs(p['heading'])%180==90) != (abs(target['heading'])%180==90):p['w'],p['d']=p['d'],p['w']
   p['x'],p['z'],p['heading']=target['position'][0],target['position'][2],target['heading']
  portable.require(found==set(placements),'Approved clinical placement coverage')
  # Existing luminaires follow occupied perimeter bays; recompute ONLY the six
  # rooms affected by approved placements, without importing the author/emitter.
  changed_rooms={room['id']:room for room in plan['rooms']}
  old_lights=level['bay_lights'];new_lights=[]
  for room_record in level['rooms']:
   rid=room_record['room']
   if rid not in changed_rooms:
    new_lights.extend(light for light in old_lights if light['room']==rid);continue
   room=changed_rooms[rid];x,y,z=room['center'];sx,_,sz=room['size']
   groups={side:[] for side in 'NSEW'}
   for item in level['placements']:
    if item['room']!=rid:continue
    dx=item['x']-x;dz=item['z']-z
    side=('E' if dx>0 else 'W') if abs(dx)/sx>=abs(dz)/sz else ('S' if dz>0 else 'N')
    groups[side].append(item)
   families={light['family'] for light in old_lights if light['room']==rid}
   portable.require(len(families)==1,'Unchanged bay-light family '+rid)
   candidates=sorted(((len(items),side,items) for side,items in groups.items() if items),reverse=True)
   for _,side,items in candidates[:4 if rid in ('arena_one','arena_two','final_arena') else 2]:
    mx=sum(item['x'] for item in items)/len(items);mz=sum(item['z'] for item in items)/len(items)
    new_lights.append({'room':rid,'name':'RoomBayLight_'+rid+'_'+side,'position':[mx+(.7 if side=='W' else -.7 if side=='E' else 0),y+3.4,mz+(.7 if side=='N' else -.7 if side=='S' else 0)],'family':next(iter(families))})
  level['bay_lights']=new_lights
 portable.require(current==previous,'Only exact23 approved poses/oriented footprints and existing derived bay-light report changes allowed')
 return {'placements':placements,'bay_lights':next(level['bay_lights'] for level in current['levels'] if level['id']=='pale_ward_01'),'table':{name:{'position':p,'size':s} for name,(p,s) in TABLE.items()},'embedded_json':{'res://assets/combat_art.json':batch['baseline_fingerprints']['assets/combat_art.json'],'res://assets/audio/runtime-cues.json':batch['baseline_fingerprints']['assets/audio/runtime-cues.json']}}

SUPPLEMENTAL=r'''extends SceneTree
var expected: Dictionary
var output := ""
var failures: Array[String] = []
var checks := 0
func _initialize():
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--expected="): expected=JSON.parse_string(FileAccess.get_file_as_string(arg.trim_prefix("--expected=")))
  if arg.begins_with("--report="): output=arg.trim_prefix("--report=")
 call_deferred("run")
func check(ok: bool,label: String):
 checks+=1
 if not ok:failures.append(label)
func vec(a: Array) -> Vector3:return Vector3(a[0],a[1],a[2])
func run():
 var world: Node3D=load("res://scenes/campaign/pale_ward_01.tscn").instantiate();root.add_child(world)
 for id in expected.placements:
  var spec: Dictionary=expected.placements[id]
  var prop: Node3D=world.get_node("RoomProp_"+String(id).replace(".","_"))
  check(prop.position.is_equal_approx(vec(spec.position)),"Exact clinical root position "+id)
  check(is_equal_approx(prop.rotation_degrees.y,float(spec.heading)),"Exact clinical root heading "+id)
  check(String(prop.get_meta("prop_type"))==spec.type,"Exact clinical inventory type "+id)
 for light in expected.bay_lights:
  var node: OmniLight3D=world.get_node(light.name)
  check(node.position.is_equal_approx(vec(light.position)),"Exact existing derived bay-light position "+String(light.name))
 check(world.find_children("RoomBayLight_*", "OmniLight3D", false, false).size()==expected.bay_lights.size(),"Exact derived bay-light count; no new unrelated luminaires")
 var table: Node3D=world.get_node("RoomProp_pale_ward_01_key_console_surgical_table_01_1")
 check(table.get_child_count()==expected.table.size(),"Exact8 surgical table solids, no ward headboard/mattress")
 for name in expected.table:
  var body: StaticBody3D=table.get_node(name)
  var spec: Dictionary=expected.table[name]
  var visual: MeshInstance3D=body.get_node("Visual")
  var collision: CollisionShape3D=body.get_node("Collision")
  check(body.position.is_equal_approx(vec(spec.position)),"Approved table piece position "+name)
  check(visual.mesh is BoxMesh and visual.mesh.size.is_equal_approx(vec(spec.size)),"Approved table piece native full-face mesh "+name)
  check(collision.shape is BoxShape3D and collision.shape.size.is_equal_approx(vec(spec.size)) and visual.transform==collision.transform,"Approved table piece matched physical shape "+name)
  check(String(body.get_meta("hit_material"))=="armor" and body.collision_layer==1 and body.collision_mask==3,"Approved table piece hit/layer/mask "+name)
  var half:=vec(spec.size)*.5
  check(absf(body.position.x)+half.x<=1.20001 and absf(body.position.z)+half.z<=.55001 and body.position.y-half.y>=-.00001 and body.position.y+half.y<=.90001,"Table piece inside2.4x1.1x.9 envelope "+name)
 for path in expected.embedded_json:check(FileAccess.get_sha256(path)==expected.embedded_json[path],"Exact unchanged embedded JSON "+path)
 var report={"status":"passed" if failures.is_empty() else "failed","checks":checks,"failures":failures,"clinical_placements":expected.placements.size(),"surgical_table_parts":expected.table.size(),"scope":"Supplemental trusted source/PCK structural reader: actual23 root transforms/types, exact8 approved table-piece geometry/collision/envelope and unchanged raw embedded combat/audio JSON. No shipped ELF execution."}
 FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
 print("V9_ARCHIVE_CLINICAL ",report.status," ",checks)
 world.free();quit(0 if failures.is_empty() else 1)
'''
def native_probe(tmp,pack,supplemental,a):
 spec=tmp/'expected.json';out=tmp/'native.json';spec.write_text(json.dumps(v7.expected()))
 (tmp/'project.godot').write_text('[application]\nconfig/name="Independent Production v9 Archive Audit"\n')
 base=[str(v7.GODOT),'--headless','--path',str(tmp if pack else ROOT)]
 if pack:base+=['--main-pack',str(pack)]
 command=base+['--script',str(ROOT/'tools/check_intake_archive_v7.gd'),'--','--expected='+str(spec),'--report='+str(out)]
 process=subprocess.run(command,cwd=tmp,capture_output=True,text=True,timeout=180);log=process.stdout+process.stderr
 a.report.with_suffix('.log').write_text(log)
 portable.require(out.is_file(),'No trusted native report: '+log[-2000:]);native=read(out)
 portable.require(process.returncode==0 and native['status']=='passed' and not re.search(r'(?:SCRIPT ERROR:|^ERROR:)',log,re.M),'Native v7 reader failed: '+log[-2000:])
 portable.require(native['props']==508 and native['pickups']==711 and native['cue_count']==57,'Exact existing508props/711pickups/57cues')
 script=tmp/'clinical_v9.gd';script.write_text(SUPPLEMENTAL);spec.write_text(json.dumps(supplemental));clinical_out=tmp/'clinical.json'
 command=base+['--script',str(script),'--','--expected='+str(spec),'--report='+str(clinical_out)]
 process=subprocess.run(command,cwd=tmp,capture_output=True,text=True,timeout=60);log=process.stdout+process.stderr;a.report.with_suffix('.clinical.log').write_text(log)
 portable.require(clinical_out.is_file(),'No supplemental table/placement report: '+log[-2000:]);clinical=read(clinical_out)
 portable.require(process.returncode==0 and clinical['status']=='passed' and not re.search(r'(?:SCRIPT ERROR:|^ERROR:)',log,re.M),'Supplemental table/placement failed: '+log[-2000:])
 return native,clinical

def audit(a):
 batch=read(ROOT/'docs/production-v9/batch.json');baseline=batch['baseline_fingerprints']
 mapping,policy=snapshot_policy()
 for path,expected in baseline.items():
  if path not in CHANGED:portable.require(path in mapping and mapping[path]==expected,'Protected v8 baseline input differs '+path)
 protected_assets={p for p in baseline if p.startswith('assets/')}
 portable.require({p for p in mapping if p.startswith('assets/')}==protected_assets,'No unreviewed new/removed runtime assets permitted')
 for path in CHANGED:portable.require(path in baseline and path in mapping,'Explicit changed-input identity missing '+path)
 supplemental=clinical_expected(batch)
 git_count=git_fingerprints(a.expected_commit,mapping) if a.expected_commit else None
 report={'source_preflight':a.source_preflight,'source_fingerprints_verified':len(mapping),'source_tree_sha256':sha(json.dumps(mapping,sort_keys=True).encode()),'source_snapshot_policy':policy,'git_checkpoint_blobs_verified':git_count,'protected_v8_baseline_files':len(baseline)-len(CHANGED),'protected_assets':len(protected_assets),'protected_other_campaign_maps':8,'explicit_changed_existing_inputs':sorted(CHANGED),'unreviewed_runtime_asset_exceptions':[]}
 with tempfile.TemporaryDirectory(prefix='eyesore-v9-archive-') as directory:
  tmp=Path(directory);pack=None
  if not a.source_preflight:
   portable.require(a.archive is not None and a.expected_commit is not None,'Archive and full --expected-commit required')
   structural=portable.verify(a.archive);portable.require(structural['source_commit']==a.expected_commit,'Packaged commit mismatch')
   record=read(a.archive.parent/'ARCHIVE.json')
   portable.require(record['sha256']==structural['archive_sha256'] and record['bytes']==a.archive.stat().st_size and record['path']==a.archive.name,'External archive checksum record mismatch')
   with tarfile.open(a.archive,'r:gz') as bundle:
    sums=portable.checksums(bundle.extractfile('SOURCE_SHA256SUMS').read().decode(),'SOURCE_SHA256SUMS')
    portable.require(sums==mapping,'Exact package/source snapshot roster or fingerprint mismatch')
    build=json.loads(bundle.extractfile('BUILD.json').read(),object_pairs_hook=portable.unique_object)
    portable.require(build.get('source_git_status')=='' and build['source_commit']==a.expected_commit and build['source_head']==a.expected_commit,'Clean exact supplied checkpoint required')
    portable.require(build['source_tree_sha256']==report['source_tree_sha256'],'Build complete source-tree digest mismatch')
    portable.require(sha(v7.GODOT.read_bytes())==build['engine_binary']['sha256'],'Pinned trusted editor mismatch')
    report['provenance']=check_theme_pack.provenance(ROOT,bundle,sums)
    pack=tmp/'archive-pck-data';pack.write_bytes(bundle.extractfile(build['executable']['path']).read());pack.chmod(0o600)
   report.update({'archive':str(a.archive.resolve()),'archive_sha256':structural['archive_sha256'],'source_commit':a.expected_commit,'portable_archive_pass':True})
  native,clinical=native_probe(tmp,pack,supplemental,a)
  report.update({'status':'passed','native':native,'clinical_native':clinical,'trusted_native_reader_sha256':sha((ROOT/'tools/check_intake_archive_v7.gd').read_bytes()),'supplemental_native_reader_sha256':sha(SUPPLEMENTAL.encode()),'frozen_theme_checker':'Known frozen35cue incompatibility retained in verification/production-v8/archive/frozen-theme-pack-failure.json; not rerun or relaxed.','related_surface_proof':'verification/production-v9/surfaces/checks.json','scope':'Source preflight only; no packaged release claim.' if a.source_preflight else 'Archive checksums, exact dynamic source snapshot roster/current fingerprints and supplied Git checkpoint blobs; all protected v8 baseline assets/profiles/budgets/eight maps exact. Unchanged trusted v7 native reader plus explicit23 placements/8-piece table supplement. Archived ELF never executed. Not full collider-topology proof, player-route or human visual/listening acceptance. External source/license webpages and remote Git history are not authenticated.'})
 return report

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('archive',nargs='?',type=Path);p.add_argument('--source-preflight',action='store_true');p.add_argument('--expected-commit');p.add_argument('--report',type=Path,required=True);a=p.parse_args()
 portable.require(a.report.resolve().is_relative_to(OUT.resolve()),'Evidence output must stay in verification/production-v9/archive')
 a.report.parent.mkdir(parents=True,exist_ok=True)
 try:result=audit(a)
 except (portable.AuditError,OSError,ValueError,KeyError,TypeError,StopIteration,subprocess.SubprocessError,tarfile.TarError) as error:result={'status':'failed','source_preflight':a.source_preflight,'error':str(error),'scope':'Required v9 check failed; no acceptance claim.'}
 result['auditor_sha256']=sha(Path(__file__).read_bytes());a.report.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2));return 0 if result['status']=='passed' else 1
if __name__=='__main__':raise SystemExit(main())
