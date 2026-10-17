#!/usr/bin/env python3
"""Apply only the reviewed Twin presentation section, with source drift checks.

Default is a dry run. Coordinator opts in with --apply after native idle review.
"""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--manifest', type=Path, default=ROOT / 'assets/combat_art.json')
    parser.add_argument('--spec', type=Path, default=ROOT / 'docs/production-v8/twin-presentation.json')
    args = parser.parse_args()
    spec = json.loads(args.spec.read_text())
    manifest = json.loads(args.manifest.read_text())
    assert digest(ROOT / spec['source_path']) == spec['source_sha256'], 'Twin bitmap source drift'
    assert digest(ROOT / 'resources/weapons/twin_shotgun.tres') == spec['weapon_resource_sha256'], 'Twin gameplay definition drift'
    before = manifest['weapon_atlases']['twin_shotgun']
    after = spec['patch']['weapon_atlases']['twin_shotgun']
    assert before in [spec['baseline_twin'], after], 'Twin metadata drift: inspect before applying'
    manifest['weapon_atlases']['twin_shotgun'] = after
    manifest['flash']['anchors']['twin_shotgun'] = spec['patch']['flash']['anchors']['twin_shotgun']
    if args.apply:
        args.manifest.write_text(json.dumps(manifest, indent=2) + '\n')
    print(json.dumps({'mode': 'applied' if args.apply else 'dry_run', 'manifest': str(args.manifest), 'source_sha256': spec['source_sha256'], 'status': spec['status'], 'changed_sections': ['weapon_atlases.twin_shotgun', 'flash.anchors.twin_shotgun']}, indent=2))

if __name__ == '__main__':
    main()
