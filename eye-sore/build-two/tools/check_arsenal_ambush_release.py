#!/usr/bin/env python3
"""Independent source and embedded-PCK audit of six guns and authored ambush stages.

--source-preflight checks current source; ARCHIVE --expected-commit FULL_HASH checks
an explicit release. Reuses the independent old archive/audio/enemy/gore audit,
then reads new weapon and architecture resources with trusted pinned Godot.
"""
from __future__ import annotations
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import struct
import zlib
import tarfile
import tempfile
from native_png import decode_png
import check_theme_pack as base
from check_theme_pack import KINDS, MUSIC, read_json, digest, png_rgba, pixels, crop_pixels, ogg_identity
from verify_pale_ward_archive import AuditError, COMMIT, checksums, require, unique_object

ROOT = Path(__file__).resolve().parents[1]
WEAPONS = ('pistol','shotgun','melee','twin_shotgun','rivet_cannon','siege_launcher')
NEW = WEAPONS[3:]
PHASES = ('idle','fire','recover','switch')
PROBE = Path(__file__).with_suffix('.gd')


def raster(data):
    width,height,rgba,_ = decode_png(data)
    return width,height,rgba


def legacy_expectations(root: Path, source: dict[str, str] | None = None) -> dict:
    art = read_json(root / "assets/combat_art.json")
    catalog = read_json(root / "resources/stages/catalog.json")
    ledger = read_json(root / "assets/audio/runtime-cues.json")
    files = source or {}

    def recorded(path: str) -> bytes:
        data = (root / path).read_bytes()
        if source is not None: require(source.get(path) == digest(data), "Runtime source absent/mismatched from checksum ledger: " + path)
        else: files[path] = digest(data)
        return data

    for path in ("assets/combat_art.json", "resources/stages/catalog.json", "assets/audio/runtime-cues.json"):
        recorded(path)
    result = {"files": files, "enemies": {}, "stages": {}, "audio": {}, "music": {}, "gore": {},
              "creature_cues": [f"{kind}_{action}" for kind in KINDS for action in ("attack_warning", "hurt", "death")]}
    require(set(art["enemies"]) == set(KINDS), "Source manifest must have exactly six species")
    for kind in KINDS:
        entry = art["enemies"][kind]
        path = entry["file"].removeprefix("res://")
        native = recorded(path)
        width, height, rgba = png_rgba(native)
        options = entry["sprite_options"]
        columns, rows = int(entry["columns"]), int(options["rows"])
        frame_records = []
        for frame in range(columns * rows):
            region = options.get("source_regions", {}).get(str(frame),
                [(frame % columns) * (width // columns), (frame // columns) * (height // rows), width // columns, height // rows])
            frame_records.append(crop_pixels(width, height, rgba, region))
        text = recorded(f"resources/enemies/{kind}.tres").decode()
        definition = {}
        for key in ("health", "speed", "ranged", "damage", "attack_range", "windup_seconds", "recovery_seconds", "pain_seconds", "projectile_speed"):
            match = re.search(r"^" + key + r" = (.+)$", text, re.M)
            if match: definition[key] = json.loads(match[1])
        result["enemies"][kind] = {"path": entry["file"], "sha256": digest(native), "image": pixels(width, height, rgba), "frames": frame_records, "definition": definition}
    for stage in catalog["stages"]:
        scene = recorded(stage["scene"].removeprefix("res://")).decode()
        roster = dict(Counter(re.findall(r'^metadata/kind = "([^"]+)"$', scene, re.M)))
        result["stages"][stage["id"]] = {"roster": roster}
    require(len(ledger["cues"]) >= 48, "Source runtime ledger must preserve original 35 cues plus 13 arsenal cues")
    for name, cue in ledger["cues"].items():
        path = cue["file"].removeprefix("res://")
        result["audio"][name] = {"path": cue["file"], "bus": cue["bus"], "spatial": cue.get("spatial", cue["bus"] not in ("Weapons", "Music")), **ogg_identity(recorded(path))}
    for name in MUSIC:
        path = f"assets/audio/music/{name}.ogg"
        result["music"][name] = {"path": "res://" + path, **ogg_identity(recorded(path))}
        require(result["music"][name]["channels"] == 2, "Source music must remain stereo: " + name)
    profile = recorded("resources/gore_profile.tres").decode()
    external = {identifier: path for path, identifier in re.findall(r'^\[ext_resource type="Texture2D" path="([^"]+)" id="([^"]+)"\]', profile, re.M)}
    scalar = {}
    for key in ("spray_counts", "death_counts", "max_stains", "max_remains", "max_particles", "corpse_integrity_fraction", "corpse_integrity_minimum", "gib_counts"):
        match = re.search(r"^" + key + r" = (.+)$", profile, re.M)
        require(match is not None, "Explicit runtime gore profile property: " + key)
        scalar[key] = json.loads(match[1])
    species = {}
    for kind, header, body in re.findall(r'^"([^"]+)": \{("texture".*?)"parts": \[\n(.*?)\n\]\}', profile, re.M | re.S):
        encoded = '{' + header + '"parts":[' + body + ']}'
        encoded = re.sub(r'ExtResource\("([^"]+)"\)', lambda match: json.dumps(external[match[1]]), encoded)
        encoded = re.sub(r'(?:Rect2|Vector2|Color)\(([^)]+)\)', r'[\1]', encoded)
        species[kind] = json.loads(encoded)
    require(set(species) == set(KINDS), "Six species runtime gore atlas registrations")
    atlases = {}
    for path in set(external.values()):
        native = recorded(path.removeprefix("res://"))
        width, height, rgba = png_rgba(native)
        atlases[path] = {"sha256": digest(native), "image": pixels(width, height, rgba)}
    require(len([path for path in atlases if "/gore-v2/" in path]) == 3, "Three native gore-v2 theme atlases")
    result["gore"] = {"profile_properties": scalar, "species": species, "atlases": atlases,
                      "pools": external[re.search(r'^pools = ExtResource\("([^"]+)"\)', profile, re.M)[1]],
                      "remains": external[re.search(r'^remains = ExtResource\("([^"]+)"\)', profile, re.M)[1]]}
    return result

def expectations(root, source=None, architecture_manifest='assets/materials/architecture-v2/architecture.json'):
    expected = legacy_expectations(root, source)
    legacy_path = Path(__file__).with_name('arsenal_ambush_legacy_audio.json')
    require(base.digest(legacy_path.read_bytes()) == '1d7d7141cc010e5b4be8f4169cce725d77e58999840caf813710ea15f27f1936', 'Trusted original audio baseline bytes')
    legacy = base.read_json(legacy_path)
    current_ledger = base.read_json(root/'assets/audio/runtime-cues.json')
    require(len(legacy['cues']) == 35 and set(legacy['cues']) <= set(current_ledger['cues']), 'All original35 cue identifiers retained')
    for cue_id,entry in legacy['cues'].items(): require(current_ledger['cues'][cue_id] == entry, 'Original cue ledger entry unchanged: '+cue_id)
    for path,sha in legacy['files'].items(): require(base.digest((root/path).read_bytes()) == sha, 'Original cue/music bytes unchanged: '+path)
    expected['legacy_audio'] = legacy
    expected['audio_cue_count'] = len(current_ledger['cues'])
    files = expected['files']
    def recorded(path):
        data = (root/path).read_bytes()
        if source is not None: require(source.get(path) == base.digest(data), 'Recorded source mismatch: '+path)
        else: files[path] = base.digest(data)
        return data
    art = base.read_json(root/'assets/combat_art.json')
    require(set(art['weapons']) == set(WEAPONS), 'Exactly six registered source weapons')
    require(set(art['weapon_atlases']) == set(WEAPONS), 'Exactly six native atlas registrations')
    expected['weapons'] = {}
    for weapon in WEAPONS:
        paths = art['weapons'][weapon]
        require(set(paths) == set(PHASES), 'Four phase paths: '+weapon)
        path = paths['idle']
        require(all(paths[p] == path for p in PHASES), 'Single source atlas per gun: '+weapon)
        data = recorded(path.removeprefix('res://'))
        w,h,rgba = raster(data)
        entry = art['weapon_atlases'][weapon]
        require(entry.get('sha256') == base.digest(data), 'Original PNG hash: '+weapon)
        require(entry.get('columns') == 2 and entry.get('rows') == 2, 'Native 2x2 gun sheet: '+weapon)
        frames = {}
        for phase in PHASES:
            rect = entry['regions'][phase]
            frames[phase] = base.crop_pixels(w,h,rgba,rect)
            pose = entry['placement'][phase]
            require(set(('marker','target','scale')) <= set(pose), 'Authored marker/target/scale: '+weapon+' '+phase)
            if weapon != 'melee': require(len(art['flash']['anchors'][weapon][phase]) == 2, 'Authored muzzle flash marker: '+weapon+' '+phase)
        resource = recorded('resources/weapons/'+weapon+'.tres').decode()
        properties = {}
        for key,value in re.findall(r'^(\w+) = (.+)$', resource,re.M):
            if key in ('script','resource_name'): continue
            if value.startswith('&"'): value=value[1:]
            if value in ('true','false'): properties[key]= value=='true'
            else:
                try: properties[key] = json.loads(value)
                except json.JSONDecodeError: pass
        if weapon in NEW:
            require(properties.get('identifier') == weapon, 'Native resource identifier: '+weapon)
            require(type(properties.get('ammo_cost')) is int and properties['ammo_cost'] > 0, 'Explicit positive ammo_cost: '+weapon)
        expected['weapons'][weapon] = {'path':path,'sha256':base.digest(data),'image':base.pixels(w,h,rgba),
            'frames':frames,'definition':properties,'atlas':entry,'anchors':art['flash']['anchors'].get(weapon,{})}
    expected['ownership'] = {'starts_owned':['pistol','shotgun','melee'], 'starts_unowned':list(NEW)}
    # Runtime architecture manifest deliberately remains a small explicit contract.
    arch_data = recorded(architecture_manifest)
    arch = json.loads(arch_data,object_pairs_hook=unique_object)
    stages = arch.get('stages',arch.get('themes',{}))
    if isinstance(stages,list): stages={entry.get('stage',entry.get('id')):entry for entry in stages}
    require(set(stages)==set(base.read_json(root/'resources/stages/catalog.json')['stages'][i]['id'] for i in range(3)), 'Three architecture theme registrations')
    expected['architecture']={'manifest':'res://'+architecture_manifest,'stages':{}}
    for stage,entry in stages.items():
        path=entry.get('file',entry.get('atlas'))
        require(isinstance(path,str) and path.startswith('res://'),'Native architecture atlas path: '+stage)
        data=recorded(path.removeprefix('res://'));w,h,rgba=raster(data)
        require(entry.get('sha256')==base.digest(data),'Architecture original PNG hash: '+stage)
        regions=entry.get('regions',entry.get('cells',{}))
        require(set(('floor','wall','ceiling')) <= set(regions),'Explicit floor/wall/ceiling native rectangles: '+stage)
        cells={name:base.crop_pixels(w,h,rgba,regions[name]) for name in ('floor','wall','ceiling')}
        require(len({tuple(regions[name]) for name in cells})==3,'Distinct architecture cells: '+stage)
        require(len({cells[name]['opaque_rgba_sha256'] for name in cells})==3,'Floor/wall/ceiling contain distinct pixel art: '+stage)
        expected['architecture']['stages'][stage]={'path':path,'sha256':base.digest(data),'image':base.pixels(w,h,rgba),'regions':regions,'cells':cells}
        route_path='resources/stages/'+stage+'-route.json'
        route=json.loads(recorded(route_path),object_pairs_hook=unique_object)
        expected['stages'][stage]['route']=route
    require(len({v['path'] for v in expected['architecture']['stages'].values()})==3,'Three distinct architecture PNG atlases')
    return expected


def run_probe(args, expected, temporary, pack):
    version=subprocess.run([str(args.godot),'--version'],capture_output=True,text=True,check=True).stdout.strip()
    require(version.startswith('4.7.2.stable.official.'),'Trusted pinned Godot 4.7.2 required')
    input_path,output=temporary/'expected.json',temporary/'pack-report.json'
    input_path.write_text(json.dumps(expected))
    (temporary/'project.godot').write_text('[application]\nconfig/name="Independent Arsenal Ambush Audit"\n')
    command=[str(args.godot),'--headless','--path',str(temporary if pack else args.source_root)]
    if pack: command+=['--main-pack',str(pack)]
    command+=['--script',str(PROBE),'--','--expected='+str(input_path),'--report='+str(output)]
    if pack: command.append('--packed')
    process=subprocess.run(command,cwd=temporary,capture_output=True,text=True,timeout=240)
    combined=process.stdout+process.stderr
    require(output.is_file(),'Probe produced no report: '+combined[-5000:])
    result=base.read_json(output)
    result.update(engine_version=version,probe_exit_code=process.returncode,probe_log_tail=combined[-5000:])
    require(not re.search(r'(?:SCRIPT ERROR:|^ERROR:)',combined,re.M),'Probe script/engine errors: '+combined[-5000:])
    require(process.returncode==0 or not result.get('pass'),'Probe exit contradicts reported pass')
    return result


def audit(args):
    root=args.source_root.resolve()
    with tempfile.TemporaryDirectory(prefix='eyesore-independent-arsenal-') as td:
        temporary=Path(td)
        if args.source_preflight:
            expected=expectations(root,architecture_manifest=args.architecture_manifest)
            probe=run_probe(args,expected,temporary,None)
            return {'status':'passed' if probe['pass'] else 'failed','source_preflight':True,'embedded_pack':probe,
                'scope':'Current source resources and controlled trap fixtures only; no archive or native photograph claim.'}
        require(args.archive is not None and args.expected_commit is not None,'Archive and --expected-commit required')
        require(COMMIT.fullmatch(args.expected_commit) is not None,'Full expected commit hash required')
        structural=base.verify(args.archive)
        require(structural['source_commit']==args.expected_commit,'Archive differs from explicitly expected source commit')
        archive_record=args.archive_record or args.archive.parent/'ARCHIVE.json'
        rec=base.read_json(archive_record)
        require(rec['path']==args.archive.name and rec['bytes']==args.archive.stat().st_size and rec['sha256']==structural['archive_sha256'],'External archive checksum record mismatch')
        with tarfile.open(args.archive,'r:gz') as bundle:
            source=checksums(bundle.extractfile('SOURCE_SHA256SUMS').read().decode(),'SOURCE_SHA256SUMS')
            for relative,sha in source.items():
                local=root/relative
                require(local.is_file() and not local.is_symlink() and local.resolve().is_relative_to(root),'Recorded local source unsafe/missing: '+relative)
                require(base.digest(local.read_bytes())==sha,'Current source mismatch: '+relative)
            provenance=base.provenance(root,bundle,source)
            expected=expectations(root,source,args.architecture_manifest)
            expected['engine_license_sha256']=base.digest(bundle.extractfile('GODOT_LICENSE.txt').read())
            expected['engine_notices_sha256']=base.digest(bundle.extractfile('GODOT_THIRD_PARTY_NOTICES.txt').read())
            build=json.loads(bundle.extractfile('BUILD.json').read(),object_pairs_hook=unique_object)
            require(base.digest(args.godot.read_bytes())==build['engine_binary']['sha256'],'Pinned reader differs from build engine')
            executable=temporary/'archived-embedded-pack.x86_64'
            executable.write_bytes(bundle.extractfile(build['executable']['path']).read()); executable.chmod(0o600)
            probe=run_probe(args,expected,temporary,executable)
        return {'status':'passed' if probe['pass'] else 'failed','archive':str(args.archive.resolve()),
            'expected_source_commit':args.expected_commit,'structural_archive_audit':structural,'provenance':provenance,
            'recorded_source_files_verified':len(source),'embedded_pack':probe,
            'scope':'Independent checksums, provided provenance, packed resources and controlled trap state fixtures. No archive executable run, Git authentication, native screenshots, normal gameplay or human style acceptance claim.'}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive',nargs='?',type=Path)
    parser.add_argument('--expected-commit')
    parser.add_argument('--archive-record',type=Path)
    parser.add_argument('--source-root',type=Path,default=ROOT)
    parser.add_argument('--godot',type=Path,default=base.GODOT)
    parser.add_argument('--architecture-manifest',default='assets/materials/architecture-v2/architecture.json')
    parser.add_argument('--source-preflight',action='store_true')
    parser.add_argument('--report',type=Path,required=True)
    args=parser.parse_args()
    if args.archive and args.report.resolve()==args.archive.resolve(): parser.error('Report cannot overwrite archive')
    try: result=audit(args)
    except (AuditError,OSError,ValueError,KeyError,TypeError,IndexError,AttributeError,tarfile.TarError,subprocess.SubprocessError,struct.error,zlib.error) as error:
        result={'status':'failed','error':str(error),'scope':'Required audit checks failed; no acceptance claim.'}
    result['auditor_sha256']=base.digest(Path(__file__).read_bytes());result['godot_probe_sha256']=base.digest(PROBE.read_bytes())
    args.report.parent.mkdir(parents=True,exist_ok=True);args.report.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'status':result['status'],'error':result.get('error'),'pack_failures':result.get('embedded_pack',{}).get('failures',[]),'report':str(args.report)},indent=2))
    return 0 if result['status']=='passed' else 1

if __name__=='__main__':sys.exit(main())
