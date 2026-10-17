#!/usr/bin/env python3
"""Audit the Ward 02 floor-supported props in the authored scene."""
from __future__ import annotations

import json
import re
from pathlib import Path

import author_levels_v13 as author
import ward_shell_v14 as shell


ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    level = author.load_level('pale_ward_02')
    scene = (ROOT / 'scenes/campaign/pale_ward_02.tscn').read_text()
    nodes = re.findall(
        r'(?ms)^\[node name="([^"]+)"([^\n]*)\]\n(.*?)(?=^\[node |\Z)', scene
    )
    children: dict[str, dict[str, tuple[str, str]]] = {}
    for name, header, body in nodes:
        parent = re.search(r'parent="([^"]+)"', header)
        if parent:
            children.setdefault(parent.group(1), {})[name] = (header, body)

    outlined = supported = 0
    for room in level['rooms']:
        x, y, z = room['center']
        for obj in room['objects']:
            typ = obj['type']
            root = 'RoomProp_pale_ward_02_' + room['id'] + '_prop_' + obj['id'].split('.')[-1]
            assert root in children['.'], root
            lx, ly, lz = obj['position_local']
            width, depth = author.props.SHAPES[typ][1:3]
            if abs(obj['heading']) == 90:
                width, depth = depth, width
            if room.get('outline_xz'):
                assert shell.rectangle_fits(room, (x+lx, y+ly, z+lz), (width, 1, depth)), obj['id']
                outlined += 1

            if typ not in {'filter_unit', 'pipe_manifold'}:
                continue
            assert ly == 0, (obj['id'], 'fixture root must be on room floor')
            parts = children[root]
            expected = {'FloorCabinet': (.64, 1.28)} if typ == 'filter_unit' else {
                'FloorFeed-1': (.68, 1.36), 'FloorFeed1': (.68, 1.36)
            }
            for name, (center_y, height) in expected.items():
                header, body = parts[name]
                assert 'type="StaticBody3D"' in header, (obj['id'], name, 'missing collider')
                at = re.search(r'position = Vector3\([^,]+,\s*([^,]+),', body)
                assert at and abs(float(at.group(1)) - center_y) < .001, (obj['id'], name)
                assert abs(center_y - height/2) < .001, (obj['id'], name, 'not floor touching')
            assert 'EquipmentLabel' in parts, (obj['id'], 'missing identity label')
            supported += 1

    assert supported == 17 and outlined == 26, (supported, outlined)
    print(json.dumps({'level': level['id'], 'floor_supported_fixture_count': supported,
                      'outlined_floor_props_checked': outlined, 'status': 'passed'}, indent=2))


if __name__ == '__main__':
    main()
