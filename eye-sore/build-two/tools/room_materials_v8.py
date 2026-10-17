"""ART-01: native room-family materials with strictly visual Intake bindings.

The coordinator owns source PNG selection and generator integration. Call after
furnishing/presentation; no files are written, no existing resources are edited.
"""
from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path
import re
import struct

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "resources/materials/v8/room-families.json"
LEVEL_ID = "pale_ward_01"
ROLES = ("wall", "floor", "ceiling", "trim", "door", "panel")
ROOM_FAMILIES = {"entry": "triage", "arena_one": "triage", "key_wing": "surgery",
                 "key_console": "surgery", "service": "utility", "return_store": "utility"}
SOURCE_ROLES = {"wall": "wall", "pillar": "wall", "damaged": "wall",
                "floor": "floor", "grate": "floor", "stairs": "floor",
                "ceiling": "ceiling", "steel": "trim", "trim": "trim",
                "recess": "trim", "door_skin": "door", "panel": "panel"}
NODE = re.compile(r'^\[node name="([^"]+)" type="([^"]+)" parent="([^"]+)"\]')
SUB_ID = re.compile(r'^\[sub_resource type="([^"]+)" id="([^"]+)"\]')
VISUAL_OVERRIDE = re.compile(r'^material_override = SubResource\("[^"]+"\)\n', re.M)
POLYGON_MATERIAL = re.compile(r'^metadata/polygon_material = SubResource\("([^"]+)"\)', re.M)


def applies(sc) -> bool:
    return sc.stage.get("campaign_level_id") == LEVEL_ID


def _manifest(value=None) -> dict:
    if isinstance(value, dict):
        return value
    return json.loads(Path(value or MANIFEST).read_text())


def _native_sources(manifest: dict) -> dict:
    """Validate every input before adding any resource to the scene."""
    assert manifest["campaign_level_id"] == LEVEL_ID
    density = manifest["pixels_per_metre"]
    assert isinstance(density, (int, float)) and math.isfinite(density) and density > 0
    sources = {}
    for family in dict.fromkeys(ROOM_FAMILIES.values()):
        entry = manifest["families"][family]
        assert entry["path"].startswith("res://"), (family, "expected project resource path")
        path = ROOT / entry["path"][6:]
        assert path.is_file(), (family, "coordinator atlas not yet available", str(path))
        data = path.read_bytes()
        assert data[:8] == b"\x89PNG\r\n\x1a\n", (family, "expected native PNG")
        dimensions = list(struct.unpack(">II", data[16:24]))
        digest = hashlib.sha256(data).hexdigest()
        assert entry["dimensions"] == dimensions, (family, "native dimension mismatch", dimensions)
        assert entry["sha256"] == digest, (family, "native SHA-256 mismatch", digest)
        assert set(entry["regions"]) == set(ROLES), (family, "record all six reviewed native regions")
        regions = entry["regions"]
        for role, rect in regions.items():
            assert len(rect) == 4 and all(type(n) is int for n in rect), (family, role, rect)
            x, y, w, h = rect
            assert x >= 0 and y >= 0 and w > 0 and h > 0
            assert x + w <= dimensions[0] and y + h <= dimensions[1], (family, role, "outside source")
        for index, role in enumerate(ROLES):
            x, y, w, h = regions[role]
            for other in ROLES[index + 1:]:
                a, b, c, d = regions[other]
                assert min(x + w, a + c) <= max(x, a) or min(y + h, b + d) <= max(y, b), (family, role, other, "overlap")
        sources[family] = dict(path=entry["path"], dimensions=dimensions, sha256=digest,
                               regions=regions, identity=entry.get("identity", ""))
    return sources


def _append_resource(items: list, resource: str, identifier: str) -> None:
    candidates = [item for item in items if item.splitlines()[0].endswith('id="' + identifier + '"]')]
    if candidates:
        # Serialized TSCN sections carry separator newlines which are not part
        # of the resource definition. Keep strict property comparison while
        # accepting those separators when checking an already saved scene.
        assert len(candidates) == 1 and candidates[0].rstrip() == resource.rstrip(), (identifier, "resource ID collision or changed manifest on existing scene")
    else:
        items.append(resource)


def register_material(sc, family: str, role: str, source: dict, pixels_per_metre=64) -> str:
    """Register a native AtlasTexture plus shader material; stable IDs, no replacement."""
    assert family in ROOM_FAMILIES.values() and role in ROLES
    name = "v8_" + family + "_" + role
    texture_id = "v8_source_" + family
    _append_resource(sc.ext, '[ext_resource type="Shader" path="res://shaders/room_surface_v8.gdshader" id="v8_room_surface"]', "v8_room_surface")
    _append_resource(sc.ext, '[ext_resource type="Texture2D" path="' + source["path"] + '" id="' + texture_id + '"]', texture_id)
    region = ", ".join(map(str, source["regions"][role]))
    _append_resource(sc.sub, '[sub_resource type="AtlasTexture" id="' + name + '_native"]\n'
                     'atlas = ExtResource("' + texture_id + '")\nregion = Rect2(' + region + ')\nfilter_clip = true\n', name + "_native")
    # Surface treatment changes through the selected artwork; restrained material
    # properties distinguish enamel and service steel without tinting source RGB.
    metal = .72 if role in ("trim", "door", "panel") else {"triage": .02, "surgery": .24, "utility": .48}[family]
    roughness = {"triage": .90, "surgery": .73, "utility": .86}[family]
    _append_resource(sc.sub, '[sub_resource type="ShaderMaterial" id="' + name + '"]\n'
                     'shader = ExtResource("v8_room_surface")\n'
                     'shader_parameter/painted_surface = ExtResource("' + texture_id + '")\n'
                     'shader_parameter/source_region_pixels = Vector4(' + region + ')\n'
                     'shader_parameter/pixels_per_metre = ' + str(pixels_per_metre) + '\n'
                     'shader_parameter/metal = ' + str(metal) + '\n'
                     'shader_parameter/base_roughness = ' + str(roughness) + '\n', name)
    return name


def register_materials(sc, manifest=None) -> dict:
    """Return family/role -> stable material IDs; no-op outside Intake."""
    if not applies(sc):
        return {}
    data = _manifest(manifest)
    sources = _native_sources(data)
    materials = {family: {role: register_material(sc, family, role, source, data["pixels_per_metre"])
                          for role in ROLES} for family, source in sources.items()}
    sc.room_materials_v8_sources = sources
    sc.room_materials_v8_ids = materials
    return materials


def _root_room(root: str, routes: list[dict]) -> tuple[str | None, str]:
    for rid in ROOM_FAMILIES:
        if root.startswith(rid + "_") or root == "IntakePresentation_" + rid:
            return rid, "room"
    if root.startswith("Entry") and not root.startswith("EntryGate"):
        return "entry", "room"
    for index, portal in enumerate(routes):
        if portal["from"] not in ROOM_FAMILIES:
            continue
        matched = root.startswith("Link_" + str(index) + "_") or root.startswith("Step_" + str(index) + "_")
        matched |= bool(portal.get("gate")) and root == "Door_" + portal["gate"]
        matched |= root == portal.get("trap_entry")
        matched |= portal.get("gate") == "entry_gate" and root.startswith("EntryGate")
        if matched:
            return portal["from"], "corridor_from"
    return None, "excluded"


def _role(material: str) -> str | None:
    if material.startswith("v8_"):
        return next((role for role in ROLES if material.endswith("_" + role)), None)
    return SOURCE_ROLES.get(material)


def _protected_nodes(nodes: list[str]) -> list[str]:
    return [POLYGON_MATERIAL.sub('metadata/polygon_material = VISUAL_ONLY', VISUAL_OVERRIDE.sub("", node)) for node in nodes]


def apply_room_materials(sc, room_id=None, routes=None, manifest=None) -> dict:
    """Bind only visual material properties and return an idempotent audit report.

    Existing mesh material IDs, colliders and semantic hit_material stay intact.
    Runtime prisms receive a different polygon_material only; their outline and
    runtime hard-hit collider remain unchanged. Repeated calls add no resources
    or nodes. room_id can limit a call to one of the six accepted room roles.
    """
    if not applies(sc):
        return {"applied": False, "reason": "Intake only", "version": 8}
    assert room_id is None or room_id in ROOM_FAMILIES, (room_id, "outside six-room rollout")
    materials = register_materials(sc, manifest)
    routes = routes if routes is not None else getattr(sc, "room_program_routes", None)
    assert routes is not None, "pass authored routes or set sc.room_program_routes"
    before_nodes = list(sc.nodes)
    before_sub = list(sc.sub)
    before_ext = list(sc.ext)
    stage_digest = hashlib.sha256(json.dumps(sc.stage, sort_keys=True).encode()).hexdigest()
    meshes = {}
    for resource in sc.sub:
        header = SUB_ID.match(resource)
        material = re.search(r'^material = SubResource\("([^"]+)"\)', resource, re.M)
        if header and header[1].endswith("Mesh") and material:
            meshes[header[2]] = material[1]
    previous_polygons = sc.__dict__.setdefault("_room_materials_v8_polygon_sources", {})
    bindings = []
    changed = 0
    for index, node in enumerate(sc.nodes):
        header = NODE.match(node)
        if not header:
            continue
        name, typ, parent = header.groups()
        path = name if parent == "." else parent + "/" + name
        root = path.split("/")[0]
        rid, scope = _root_room(root, routes)
        if rid is None or (room_id is not None and rid != room_id):
            continue
        old_material = None
        polygon = POLYGON_MATERIAL.search(node)
        if polygon and parent == ".":
            old_material = previous_polygons.setdefault(path, polygon[1])
        elif typ == "MeshInstance3D" and (parent == root or root.startswith("IntakePresentation_")):
            mesh = re.search(r'^mesh = SubResource\("([^"]+)"\)', node, re.M)
            if mesh:
                old_material = meshes.get(mesh[1])
        role = _role(old_material or "")
        if role is None:
            continue
        family = ROOM_FAMILIES[rid]
        material = materials[family][role]
        if polygon:
            updated = POLYGON_MATERIAL.sub('metadata/polygon_material = SubResource("' + material + '")', node)
        else:
            override = 'material_override = SubResource("' + material + '")\n'
            # Insert directly after header without changing any existing bytes.
            updated = VISUAL_OVERRIDE.sub("", node)
            newline = updated.index("\n") + 1
            updated = updated[:newline] + override + updated[newline:]
        changed += updated != node
        sc.nodes[index] = updated
        bindings.append(dict(path=path, room=rid, scope=scope, family=family, role=role,
                             source_material=old_material, material=material,
                             property="metadata/polygon_material" if polygon else "material_override"))
    assert _protected_nodes(before_nodes) == _protected_nodes(sc.nodes), "non-visual node data changed"
    assert before_sub == sc.sub and before_ext == sc.ext, "resource data changed during binding"
    assert stage_digest == hashlib.sha256(json.dumps(sc.stage, sort_keys=True).encode()).hexdigest(), "gameplay stage data changed"
    rooms = {}
    for rid, family in ROOM_FAMILIES.items():
        if room_id is not None and rid != room_id:
            continue
        count = sum(binding["room"] == rid for binding in bindings)
        rooms[rid] = dict(family=family, source=sc.room_materials_v8_sources[family]["path"], bindings=count,
                          roles={role: {"material": materials[family][role], "region": sc.room_materials_v8_sources[family]["regions"][role]} for role in ROLES})
    report = dict(schema_version=1, version=8, task="ART-01", applied=True, campaign_level_id=LEVEL_ID,
                  room_families=rooms, sources=sc.room_materials_v8_sources,
                  binding_count=len(bindings), changed_visuals=changed, bindings=bindings,
                  pixels_per_metre=_manifest(manifest)["pixels_per_metre"],
                  corridor_policy="portal from-room family; source rooms outside six-room rollout retain v7",
                  integrity={"protected_node_bytes_unchanged": True, "existing_resources_unchanged": True,
                             "stage_data_unchanged": True, "stage_sha256": stage_digest},
                  acceptance="Pending ordinary gameplay-distance coordinator review")
    sc.room_materials_v8_report = report
    return report


def native_pixel_at(plane: tuple[float, float], region: list[int], pixels_per_metre=64) -> tuple[int, int]:
    """CPU counterpart of the shader's region-local wrapping, for integrity checks."""
    x, y, w, h = region
    return (x + math.floor((plane[0] * pixels_per_metre / w % 1) * w),
            y + math.floor((plane[1] * pixels_per_metre / h % 1) * h))


def verify_scene(scene_path, route_path, manifest=None) -> dict:
    """Read-only check against an actual authored scene, not mirrored geometry."""
    from types import SimpleNamespace

    text = Path(scene_path).read_text()
    chunks = re.split(r'(?=^\[(?:ext_resource|sub_resource|node) )', text, flags=re.M)
    route = json.loads(Path(route_path).read_text())
    assert route["id"] == LEVEL_ID
    sc = SimpleNamespace(stage=dict(route, campaign_level_id=LEVEL_ID),
                         ext=[chunk.rstrip("\n") for chunk in chunks if chunk.startswith("[ext_resource")],
                         sub=[chunk for chunk in chunks if chunk.startswith("[sub_resource")],
                         nodes=[chunk for chunk in chunks if chunk.startswith("[node")],
                         room_program_routes=route["portals"])
    prior_nodes, prior_sub, prior_ext = list(sc.nodes), list(sc.sub), list(sc.ext)
    first = apply_room_materials(sc, manifest=manifest)
    assert first["binding_count"] > 0, "no authored architecture was bound"
    assert prior_sub == sc.sub[:len(prior_sub)] and prior_ext == sc.ext[:len(prior_ext)]
    assert _protected_nodes(prior_nodes) == _protected_nodes(sc.nodes)
    once = (list(sc.ext), list(sc.sub), list(sc.nodes))
    repeated = apply_room_materials(sc, manifest=manifest)
    assert once == (sc.ext, sc.sub, sc.nodes) and repeated["changed_visuals"] == 0
    assert first["bindings"] == repeated["bindings"]
    data = _manifest(manifest)
    cases = 0
    for source in first["sources"].values():
        for rect in source["regions"].values():
            x, y, w, h = rect
            for a in (-10000, -1.001, -.001, 0, .001, 1.001, 10000):
                for b in (-999, -.001, 0, .001, 999):
                    px, py = native_pixel_at((a, b), rect, data["pixels_per_metre"])
                    assert x <= px < x + w and y <= py < y + h, (rect, a, b, px, py)
                    cases += 1
            for axis in (0, 1):
                at = [.123, .234]
                expected = native_pixel_at(tuple(at), rect, data["pixels_per_metre"])
                at[axis] += rect[axis + 2] / data["pixels_per_metre"]
                assert expected == native_pixel_at(tuple(at), rect, data["pixels_per_metre"])
    other = SimpleNamespace(stage={"campaign_level_id": "ash_citadel_01"}, ext=[], sub=[], nodes=[])
    assert not apply_room_materials(other)["applied"] and not other.ext and not other.sub
    # All failures above raise; a report cannot silently certify partial success.
    return dict(scene=str(scene_path), source_scene_sha256=hashlib.sha256(text.encode()).hexdigest(),
                binding_count=first["binding_count"],
                room_bindings={rid: value["bindings"] for rid, value in first["room_families"].items()},
                polygon_bindings=sum(binding["property"] == "metadata/polygon_material" for binding in first["bindings"]),
                native_pixel_cases=cases, native_repeat_periods=True, repeated_application_noop=True,
                other_campaign_noop=True, integrity=first["integrity"], sources=first["sources"])


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Read-only native atlas and authored Intake material integrity check")
    parser.add_argument("--scene", type=Path, default=ROOT / "scenes/campaign/pale_ward_01.tscn")
    parser.add_argument("--route", type=Path, default=ROOT / "resources/campaign/pale_ward_01-route.json")
    parser.add_argument("--manifest", type=Path, default=MANIFEST)
    args = parser.parse_args()
    print(json.dumps(verify_scene(args.scene, args.route, args.manifest), indent=2))
