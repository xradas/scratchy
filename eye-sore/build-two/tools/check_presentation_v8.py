#!/usr/bin/env python3
"""Bounded v8 audit against committed v7; never generates production content.

Source: python tools/check_presentation_v8.py --native --v7-physics
Export data: add --executable /path/eyesore.x86_64. The pinned editor reads the
exact embedded PCK with --main-pack; release templates cannot run --script.
Genuine shipped-executable behavior requires separate campaign/movie receipts.
All receipts and baseline fixtures go in a NEW --output directory.
"""
from __future__ import annotations

import argparse
from collections import Counter
from copy import deepcopy
import hashlib
import json
import math
from pathlib import Path
import re
import struct
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
BASELINE = "14a6ec9bc01867c6229809f2bf325749500a51ba"
PREFIX = "eye-sore/build-two/"
INTAKE = "scenes/campaign/pale_ward_01.tscn"
ROOMS = {"entry": "triage", "arena_one": "triage", "key_wing": "surgery",
         "key_console": "surgery", "service": "utility", "return_store": "utility"}
ROLES = {"wall": "wall", "pillar": "wall", "damaged": "wall", "floor": "floor",
         "grate": "floor", "stairs": "floor", "ceiling": "ceiling", "steel": "trim",
         "trim": "trim", "recess": "trim", "door_skin": "door", "panel": "panel"}
ORDER = ("wall", "floor", "ceiling", "trim", "door", "panel")


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT)


def old(path):
    return git("show", BASELINE + ":" + PREFIX + path)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def blob(data):
    return hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()


def sections(text):
    resources, nodes = {}, {}
    for part in re.split(r"(?=^\[(?:ext_resource|sub_resource|node) )", text, flags=re.M):
        header = part.splitlines()[0] if part else ""
        if header.startswith(("[ext_resource", "[sub_resource")):
            identifier = re.search(r' id="([^"]+)"', header)[1]
            key = ("ext" if header.startswith("[ext_resource") else "sub", identifier)
            assert key not in resources, ("duplicate resource", key)
            resources[key] = part.rstrip()
        elif header.startswith("[node"):
            name = re.search(r'name="([^"]+)"', header)[1]
            parent = re.search(r'parent="([^"]+)"', header)
            path = name if parent is None else name if parent[1] == "." else parent[1] + "/" + name
            assert path not in nodes, ("duplicate node", path)
            nodes[path] = part.rstrip()
    return resources, nodes


def props(node):
    return dict(re.findall(r"^([^\n=]+) = (.*)$", node, re.M))


def reference(value):
    match = re.fullmatch(r'SubResource\("([^"]+)"\)', value or "")
    return match[1] if match else None


def room_for(path, routes):
    root = path.split("/")[0]
    for rid in ROOMS:
        if root.startswith(rid + "_") or root == "IntakePresentation_" + rid:
            return rid
    if root.startswith("Entry") and not root.startswith("EntryGate"):
        return "entry"
    for index, portal in enumerate(routes):
        if portal["from"] not in ROOMS:
            continue
        roots = ("Link_%d_" % index, "Step_%d_" % index)
        if root.startswith(roots) or (portal.get("gate") and root == "Door_" + portal["gate"]):
            return portal["from"]
        if root == portal.get("trap_entry"):
            return portal["from"]
        if portal.get("gate") == "entry_gate" and root.startswith("EntryGate"):
            return portal["from"]
    return None


class Audit:
    def __init__(self):
        self.checks = 0
        self.failures = []

    def check(self, ok, label):
        self.checks += 1
        if not ok:
            self.failures.append(label)


def source_audit(audit, output):
    tree = {}
    for record in git("ls-tree", "-r", "-z", "--full-tree", BASELINE + ":" + PREFIX.rstrip("/")).split(b"\0"):
        if record:
            fields, path = record.split(b"\t", 1)
            tree[path.decode()] = fields.decode().split()[2]
    protected = []
    for path, expected in tree.items():
        scoped = path.startswith(("resources/", "assets/", "scripts/", "shaders/", "audio/", "music/", "scenes/"))
        exception = path in (INTAKE, "assets/combat_art.json", "scripts/main.gd", "scripts/weapon_presentation.gd")
        # Credits are coordinator-owned prose; shipped media remain pinned.
        if not scoped or exception or path.endswith(".md"):
            continue
        file = ROOT / path
        audit.check(file.is_file() and blob(file.read_bytes()) == expected, "baseline data unchanged: " + path)
        protected.append(path)
    other_scenes = sorted(path for path in protected if path.startswith("scenes/campaign/"))
    audit.check(len(other_scenes) == 8, "exact other eight campaign scenes pinned")
    before_art = json.loads(old("assets/combat_art.json"))
    after_art = json.loads((ROOT / "assets/combat_art.json").read_text())
    spec = json.loads((ROOT / "docs/production-v8/twin-presentation.json").read_text())
    expected_art = deepcopy(before_art)
    expected_art["weapon_atlases"]["twin_shotgun"] = spec["patch"]["weapon_atlases"]["twin_shotgun"]
    expected_art["flash"]["anchors"]["twin_shotgun"] = spec["patch"]["flash"]["anchors"]["twin_shotgun"]
    audit.check(after_art == expected_art, "combat_art exact intentional delta: Twin registration + Twin flash anchors only")
    audit.check(sha((ROOT / spec["source_path"]).read_bytes()) == spec["source_sha256"], "untouched Twin bitmap source")
    # Every unrelated Main function remains verbatim. Allowed functions own UI,
    # display projections and persisted UI settings; native checks cover behavior.
    def functions(text):
        return {match[1]: match[0] for match in re.finditer(r'^func (\w+)\([^\n]*\n(?:.*\n)*?(?=^func |\Z)', text + "\n", re.M)}
    old_main = functions(old("scripts/main.gd").decode())
    new_main = functions((ROOT / "scripts/main.gd").read_text())
    allowed_main = {"_ready", "layout_view", "build_menu", "_process", "load_settings", "save_settings"}
    audit.check(set(old_main) == set(new_main), "Main function roster unchanged")
    changed_functions = []
    for name, value in old_main.items():
        if new_main.get(name) != value:
            changed_functions.append(name)
            audit.check(name in allowed_main, "Main change confined to UI/presentation function: " + name)
    prior_scene = old(INTAKE).decode()
    current_scene = (ROOT / INTAKE).read_text()
    baseline_scene = output / "baseline-intake.tscn"
    baseline_scene.write_text(prior_scene)
    old_resources, old_nodes = sections(prior_scene)
    new_resources, new_nodes = sections(current_scene)
    audit.check(old_nodes.keys() == new_nodes.keys(), "Intake exact node roster/paths")
    for key, value in old_resources.items():
        audit.check(new_resources.get(key) == value, "existing Intake mesh/collision/material/script resource unchanged: " + str(key))
    added_resources = set(new_resources) - set(old_resources)
    wanted = {("ext", "v8_room_surface")} | {("ext", "v8_source_" + family) for family in set(ROOMS.values())}
    for family in set(ROOMS.values()):
        for role in ORDER:
            wanted.update({("sub", "v8_" + family + "_" + role), ("sub", "v8_" + family + "_" + role + "_native")})
    audit.check(added_resources == wanted, "only expected four external +36 native/material resources added")
    route = json.loads(old("resources/campaign/pale_ward_01-route.json"))
    bindings = []
    expected_count = 0
    for path, previous in old_nodes.items():
        current = new_nodes.get(path, "")
        before, after = props(previous), props(current)
        rid = room_for(path, route["portals"])
        header = previous.splitlines()[0]
        parent = re.search(r'parent="([^"]+)"', header)
        parent = parent[1] if parent else None
        material = reference(before.get("metadata/polygon_material"))
        polygon = material is not None
        if not polygon and 'type="MeshInstance3D"' in header and parent and (parent == path.split("/")[0] or path.startswith("IntakePresentation_")):
            mesh = reference(before.get("mesh"))
            material = reference(props(old_resources.get(("sub", mesh), "")).get("material"))
        eligible = rid is not None and material in ROLES
        if eligible:
            expected_count += 1
            role = ROLES[material]
            target = "v8_" + ROOMS[rid] + "_" + role
            prop = "metadata/polygon_material" if polygon else "material_override"
            audit.check(reference(after.get(prop)) == target, "room-family visual binding: " + path)
            permitted = dict(before)
            permitted[prop] = 'SubResource("' + target + '")'
            audit.check(after == permitted and current.splitlines()[0] == header, "only visual property changed: " + path)
            # Byte comparison after removing just the approved visual property.
            stripped = re.sub(r'^material_override = .*\n', "", current + "\n", flags=re.M)
            if polygon:
                stripped = re.sub(r'^metadata/polygon_material = .*$', "metadata/polygon_material = " + before["metadata/polygon_material"], stripped, flags=re.M)
            audit.check(stripped.rstrip() == previous.rstrip(), "protected Intake node bytes: " + path)
            bindings.append(dict(path=path, room=rid, family=ROOMS[rid], role=role, polygon=polygon))
        else:
            audit.check(current == previous, "outside material scope exact node bytes: " + path)
    audit.check(expected_count == 427, "baseline six-room architecture expects427 visual bindings")
    manifest = json.loads((ROOT / "resources/materials/v8/room-families.json").read_text())
    atlas_records = {}
    for family in set(ROOMS.values()):
        source = manifest["families"][family]
        data = (ROOT / source["path"].removeprefix("res://")).read_bytes()
        dims = list(struct.unpack(">II", data[16:24]))
        audit.check(data[:8] == b"\x89PNG\r\n\x1a\n" and dims == source["dimensions"] == [1536, 1024], family + " native PNG dimensions")
        audit.check(sha(data) == source["sha256"], family + " exact original source SHA256")
        for index, role in enumerate(ORDER):
            rect = [(index % 3) * 512, (index // 3) * 512, 512, 512]
            audit.check(source["regions"][role] == rect, family + "/" + role + " exact native cell")
            resource = new_resources.get(("sub", "v8_" + family + "_" + role), "")
            p = props(resource)
            expected_rect = "Vector4(" + ", ".join(map(str, rect)) + ")"
            audit.check(p.get("shader_parameter/source_region_pixels") == expected_rect, family + "/" + role + " bound native shader rectangle")
            audit.check(p.get("shader_parameter/pixels_per_metre") == str(manifest["pixels_per_metre"]), family + "/" + role + " consistent native density")
        atlas_records[family] = source
    shader = (ROOT / "shaders/room_surface_v8.gdshader").read_text()
    audit.check("filter_nearest" in shader and "repeat_disable" in shader and "textureSize(painted_surface, 0)" in shader, "nearest native atlas sampler")
    audit.check("floor(fract(" in shader and "vec2(0.5)" in shader and "source_region_pixels.xy" in shader, "native region-local integer pixel-centre wrap")
    expected = dict(baseline_commit=BASELINE, baseline_scene=str(baseline_scene.resolve()),
                    baseline_scene_sha256=sha(prior_scene.encode()), scene_sha256=sha(current_scene.encode()),
                    bindings=bindings, atlas_sources=atlas_records, pixels_per_metre=manifest["pixels_per_metre"])
    (output / "native-expected.json").write_text(json.dumps(expected, indent=2) + "\n")
    return dict(protected_files=len(protected), protected_file_groups=dict(Counter(path.split("/")[0] for path in protected)),
                other_campaign_scenes=other_scenes, main_changed_functions=changed_functions,
                material_bindings=len(bindings), room_bindings=dict(Counter(binding["room"] for binding in bindings)),
                scene_sha256=expected["scene_sha256"], baseline_scene_sha256=expected["baseline_scene_sha256"],
                intentional_combat_art_delta=["weapon_atlases.twin_shotgun", "flash.anchors.twin_shotgun"],
                atlas_sources=atlas_records)


def run_native(audit, args, output, script, name, extra=None):
    engine = Path.home() / ".local/share/eyesore-tools/4.7.2/Godot_v4.7.2-stable_linux.x86_64"
    pack = args.main_pack or args.executable
    report = output / (name + ".json")
    command = [str(engine.resolve())]
    if not pack:
        command += ["--path", str(ROOT)]
    if pack:
        command += ["--main-pack", str(pack.resolve())]
    if args.render:
        command += ["--rendering-method", "gl_compatibility", "--no-focus", "--position", "20000,20000", "--resolution", "1280x720", "--audio-driver", "Dummy"]
    else:
        command += ["--headless", "--fixed-fps", "60"]
    command += ["--script", str((ROOT / script).resolve()), "--", "--automated-input", "--campaign-level=pale_ward_01", "--report=" + str(report.resolve())]
    if extra:
        command += extra
    start = time.time()
    with (output / (name + ".log")).open("w") as log:
        try:
            result = subprocess.run(command, cwd="/tmp", stdout=log, stderr=subprocess.STDOUT, timeout=300)
            code = result.returncode
        except subprocess.TimeoutExpired:
            code = -999
    raw = json.loads(report.read_text()) if report.exists() else {}
    log_text = (output / (name + ".log")).read_text()
    # Preserve the exact shutdown diagnostic already retained by v7 fixtures.
    # It is a limitation, not an assertion/shader failure or a claim of leak-free
    # behavior; every other native ERROR remains a failed audit.
    shutdown = [line for line in log_text.splitlines() if line.startswith("WARNING:") or line == "ERROR: 1 resources still in use at exit (run with --verbose for details)."]
    errors = [line for line in log_text.splitlines() if "SCRIPT ERROR" in line or "SHADER ERROR" in line or (line.startswith("ERROR:") and line not in shutdown)]
    launch = dict(command=command, cwd="/tmp", executable_sha256=sha(engine.read_bytes()), exit_code=code,
                  wall_seconds=time.time() - start, report_sha256=sha(report.read_bytes()) if report.exists() else None,
                  script_sha256=sha((ROOT / script).read_bytes()), native_errors=errors, shutdown_diagnostics=shutdown,
                  mode="independent pinned-editor native reader of exported embedded data; shipped ELF not executed" if pack else "source project",
                  main_pack=str(pack.resolve()) if pack else None,
                  main_pack_sha256=sha(pack.read_bytes()) if pack else None)
    (output / (name + "-launch.json")).write_text(json.dumps(launch, indent=2) + "\n")
    audit.check(code == 0 and raw.get("passed") is True and not errors, name + " native runtime checks pass")
    return dict(passed=raw.get("passed", False), checks=raw.get("checks", 0), failures=raw.get("failures", []), launch=launch)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True, help="new evidence directory; existing nonempty directory refused")
    parser.add_argument("--native", action="store_true")
    parser.add_argument("--render", action="store_true", help="actual Compatibility rendering instead of headless")
    parser.add_argument("--v7-physics", action="store_true", help="reuse unchanged v7 isolated motion/floor test, new report path")
    parser.add_argument("--executable", type=Path, help="read this exact exported ELF's embedded PCK with the pinned editor; does not execute the ELF or add source --path")
    parser.add_argument("--main-pack", type=Path, help="optional exported PCK override; external verification script is not embedded")
    args = parser.parse_args()
    output = args.output.resolve()
    assert not output.exists() or not any(output.iterdir()), "refusing to overwrite existing evidence"
    output.mkdir(parents=True, exist_ok=True)
    audit = Audit()
    source = source_audit(audit, output)
    runtime = {}
    if args.native:
        runtime["presentation"] = run_native(audit, args, output, "tools/check_presentation_v8.gd", "native",
                                            ["--expected=" + str(output / "native-expected.json")])
    if args.v7_physics:
        runtime["physics"] = run_native(audit, args, output, "tools/check_intake_physics_v7.gd", "v7-physics")
    summary = dict(schema_version=1, passed=not audit.failures, checks=audit.checks, failures=audit.failures,
                   baseline_commit=BASELINE, source=source, runtime=runtime,
                   runner_sha256=sha(Path(__file__).read_bytes()),
                   limits=["Controlled native display/shot and static collider probes; not human visual, listening or pacing acceptance.",
                           "Native shutdown warnings, if present, remain in each launch receipt/raw log; pass is not a leak-free claim.",
                           "Source byte preservation is independent of export inclusion; --executable tests embedded exported data with the pinned editor, not execution of the shipped ELF.",
                           "Full live nine-level finite-ammo route is not repeated by this bounded audit; route/resource/other-scene bytes are pinned to v7."])
    (output / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(json.dumps({"passed": summary["passed"], "checks": audit.checks, "failures": audit.failures,
                      "report": str(output / "summary.json")}, indent=2))
    raise SystemExit(0 if summary["passed"] else 1)


if __name__ == "__main__":
    main()
