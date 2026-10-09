#!/usr/bin/env python3
"""Check the approved-board material contract without authoring or editing assets.

Uses Python's standard library only. Authoring source is inspected with AST and
only its restricted, side-effect-free material loop is evaluated; the level
generator (which runs Godot and writes files) is never imported or executed.
"""
import argparse
import ast
import hashlib
import json
from pathlib import Path
import re
import struct
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
SOURCE = "concepts/visual-v2/corrupted-biotech/board.png"
RUNTIME = "assets/materials/pale-ward-approved-board.png"
SHADER = "shaders/ward_surface.gdshader"
REGIONS = {
    "ceramic": [1216, 625, 111, 102],
    "steel": [1362, 625, 111, 102],
    "grate": [1216, 761, 111, 106],
}
MATERIALS = {**REGIONS, "floor": REGIONS["steel"]}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def strip_comments(source):
    return re.sub(r"/\*.*?\*/|//[^\n]*", "", source, flags=re.S)


def blocks(source, resource_type):
    result = {}
    for match in re.finditer(r"^\[([^\n]+)\]\n([^\[]*)", source, re.M):
        header, body = match.groups()
        if not re.search(r'\btype="' + resource_type + '"', header):
            continue
        ident = re.search(r'\bid="([^"]+)"', header)
        if not ident:
            continue
        if ident[1] in result:
            raise ValueError(f"duplicate {resource_type} id {ident[1]}")
        result[ident[1]] = (header, body)
    return result


def author_materials(source):
    """Evaluate only the declarative material loop, with no IO or imports."""
    tree = ast.parse(source)
    candidates = [node for node in tree.body if isinstance(node, ast.For)
                  and any(isinstance(n, ast.Constant) and isinstance(n.value, str)
                          and 'type="ShaderMaterial"' in n.value
                          for n in ast.walk(node))]
    if len(candidates) != 1:
        raise ValueError("author must contain exactly one ShaderMaterial authoring loop")
    loop = candidates[0]
    allowed_names = {"kind", "uv", "ext", "subs", "metal", "rough", "relief",
                     "region", "color", "str", "v"}
    forbidden = (ast.Import, ast.ImportFrom, ast.FunctionDef, ast.ClassDef,
                 ast.While, ast.With, ast.Try, ast.Raise, ast.Lambda,
                 ast.Delete, ast.Global, ast.Nonlocal)
    for node in ast.walk(loop):
        if isinstance(node, forbidden):
            raise ValueError("author material loop contains executable non-material logic")
        if isinstance(node, ast.Name) and node.id not in allowed_names:
            raise ValueError(f"unsupported name in author material loop: {node.id}")
        if isinstance(node, ast.Attribute) and node.attr not in {"append", "join"}:
            raise ValueError(f"unsupported attribute in author material loop: {node.attr}")
        if isinstance(node, ast.Call):
            name = node.func.id if isinstance(node.func, ast.Name) else None
            if name not in {"str", "color"} and not isinstance(node.func, ast.Attribute):
                raise ValueError("unsupported call in author material loop")
    scope = {"ext": [], "subs": [], "str": str,
             "color": lambda values: "Color(" + ", ".join(str(v) for v in values) + ")"}
    scope["__builtins__"] = {}
    exec(compile(ast.Module(body=[loop], type_ignores=[]), "<material-loop>", "exec"), scope)
    # Find the actual shader ext_resource authoring declaration, not a comment.
    shader_declarations = []
    for node in tree.body:
        if (isinstance(node, ast.Expr) and isinstance(node.value, ast.Call)
                and isinstance(node.value.func, ast.Attribute)
                and isinstance(node.value.func.value, ast.Name)
                and node.value.func.value.id == "ext" and node.value.func.attr == "append"
                and len(node.value.args) == 1
                and isinstance(node.value.args[0], ast.Constant)
                and isinstance(node.value.args[0].value, str)
                and 'type="Shader"' in node.value.args[0].value):
            shader_declarations.append(node.value.args[0].value)
    return "\n".join(shader_declarations + scope["ext"] + scope["subs"])


def check(root):
    errors, checks, evidence = [], [], {}

    def require(condition, message):
        if not condition:
            errors.append(message)

    def stage(name, operation):
        previous = len(errors)
        try:
            operation()
        except Exception as exc:
            errors.append(f"{name}: {exc}")
        checks.append({"name": name, "passed": len(errors) == previous})

    def originals():
        source, runtime = (root / SOURCE).read_bytes(), (root / RUNTIME).read_bytes()
        require(source == runtime, "runtime board differs byte-for-byte from approved original")
        require(source[:8] == b"\x89PNG\r\n\x1a\n" and source[12:16] == b"IHDR",
                "approved board must be a PNG with IHDR")
        size = list(struct.unpack(">II", source[16:24]))
        require(size == [1536, 1024], f"unexpected approved board size: {size}")
        evidence["board_size_pixels"] = size
        evidence["source_sha256"] = digest(source)
        evidence["runtime_copy_sha256"] = digest(runtime)
        originals = [SOURCE, "concepts/visual-v2/corrupted-biotech/scene.png",
                     "concepts/visual-v2/corrupted-biotech/scene_pixel_preview.png"]
        git_prefix = subprocess.run(["git", "rev-parse", "--show-prefix"], cwd=root,
                                    capture_output=True, check=True, text=True).stdout.strip()
        evidence["unchanged_originals"] = {}
        for filename in originals:
            baseline = subprocess.run(["git", "show", "HEAD:" + git_prefix + filename], cwd=root,
                                      capture_output=True, check=True).stdout
            current = (root / filename).read_bytes()
            require(current == baseline, f"approved original changed from git HEAD: {filename}")
            evidence["unchanged_originals"][filename] = {
                "current_sha256": digest(current), "head_sha256": digest(baseline)}

    def metadata():
        manifest = json.loads((root / "assets/materials/approved-material-regions.json").read_text())
        require(manifest["source"] == SOURCE, "manifest source does not name approved original")
        require(manifest["runtime_copy"] == RUNTIME, "manifest runtime_copy path is incorrect")
        require(manifest["source_sha256"] == digest((root / SOURCE).read_bytes()),
                "manifest source hash does not match original")
        require(manifest["runtime_copy_sha256"] == digest((root / RUNTIME).read_bytes()),
                "manifest runtime hash does not match copy")
        require(manifest["board_size_pixels"] == [1536, 1024], "manifest dimensions incorrect")
        require(manifest["regions_pixels"] == REGIONS, "manifest approved rectangles changed")
        require(set(manifest["materials"]) == set(MATERIALS), "manifest must define four materials")
        for name, rect in MATERIALS.items():
            actual = manifest["materials"][name]
            require(actual["source_region_pixels"] == rect, f"manifest {name} rectangle incorrect")
            require(actual["region"] == ("steel" if name == "floor" else name),
                    f"manifest {name} source region incorrect")
            require(actual["tint"] == [1, 1, 1, 1], f"manifest {name} tint is not neutral")
            x, y, width, height = rect
            require(x >= 0 and y >= 0 and width > 0 and height > 0
                    and x + width <= 1536 and y + height <= 1024,
                    f"{name} approved rectangle lies outside board")

    def materials(source, label):
        textures, shaders, mats = blocks(source, "Texture2D"), blocks(source, "Shader"), blocks(source, "ShaderMaterial")
        require(set(mats) == set(MATERIALS), f"{label}: expected exactly ceramic, steel, floor, grate ShaderMaterials")
        evidence[label + "_materials"] = {}
        for name, rect in MATERIALS.items():
            if name not in mats:
                errors.append(f"{label}: missing ShaderMaterial {name}")
                continue
            body = mats[name][1]
            shader_ref = re.search(r'^shader\s*=\s*ExtResource\("([^"]+)"\)', body, re.M)
            require(bool(shader_ref and shader_ref[1] in shaders
                         and f'path="res://{SHADER}"' in shaders[shader_ref[1]][0]),
                    f"{label}: {name} does not bind approved shader")
            texture_ref = re.search(r'^shader_parameter/painted_surface\s*=\s*ExtResource\("([^"]+)"\)', body, re.M)
            require(bool(texture_ref and texture_ref[1] in textures
                         and f'path="res://{RUNTIME}"' in textures[texture_ref[1]][0]),
                    f"{label}: {name} does not bind byte-identical original board ext_resource")
            values = {}
            for parameter, constructor in [("source_region_pixels", "Vector4"), ("tint", "Color")]:
                matches = re.findall(r'^shader_parameter/' + parameter + r'\s*=\s*' + constructor + r'\(([^)]*)\)\s*$', body, re.M)
                require(len(matches) == 1, f"{label}: {name} needs exactly one {parameter}")
                values[parameter] = [float(v.strip()) for v in matches[0].split(",")] if matches else None
            require(values["source_region_pixels"] == rect, f"{label}: {name} rectangle must be {rect}")
            require(values["tint"] == [1, 1, 1, 1], f"{label}: {name} tint must be neutral Color(1,1,1,1)")
            evidence[label + "_materials"][name] = values

    def shader():
        text = strip_comments((root / SHADER).read_text())
        compact = re.sub(r"\s+", "", text)
        require("uniformsampler2Dpainted_surface:source_color,filter_nearest,repeat_disable;" in compact,
                "shader sampler must use nearest filtering, no mipmap filter, and repeat_disable")
        region = re.search(r"vec3\s+region_paint\(vec2\s+local_uv\)\s*\{([^}]*)\}", text, re.S)
        expected = [
            "vec2region_size=source_region_pixels.zw;",
            "vec2half_pixel=vec2(0.5)/region_size;",
            "vec2wrapped=clamp(fract(local_uv),half_pixel,vec2(1.0)-half_pixel);",
            "vec2board_size=vec2(textureSize(painted_surface,0));",
            "vec2atlas_uv=(source_region_pixels.xy+wrapped*region_size)/board_size;",
            "returntexture(painted_surface,atlas_uv).rgb;",
        ]
        # Validate executable sampling arithmetic, including its order and absence
        # of extra statements; comments or matching metadata cannot satisfy this.
        require(bool(region and re.sub(r"\s+", "", region[1]) == "".join(expected)),
                "shader region sampler must wrap locally and clamp to selected pixel centers before atlas lookup")
        calls = re.findall(r"\b(texture(?:Lod|Grad|Proj|Gather|Offset|ProjLod|ProjGrad)?|texelFetch)\s*\(", text)
        require(calls == ["texture"], "shader must sample board only once through region_paint; no alternate/mipmap/neighbor fetches")
        require("ALBEDO=paint*tint.rgb;" in compact, "shader albedo must use approved region paint and neutral material tint")
        require("returnregion_paint(point.zy*world_scale)*weights.x+region_paint(point.xz*world_scale)*weights.y+region_paint(point.xy*world_scale)*weights.z;" in compact,
                "shader triplanar projections must all use region_paint")
        require("returndot(painted(point,weights),vec3(0.299,0.587,0.114));" in compact,
                "shader relief must sample through the same confined region path")
        imported = (root / (RUNTIME + ".import")).read_text()
        require(re.search(r"^mipmaps/generate=false$", imported, re.M) is not None,
                "runtime board import must disable mipmap generation")
        require(re.search(r"^compress/mode=0$", imported, re.M) is not None,
                "runtime board import must remain lossless")
        require(re.search(r"^process/size_limit=0$", imported, re.M) is not None,
                "runtime board import must retain original resolution")

    stage("original bytes and git HEAD preservation", originals)
    stage("approved region metadata", metadata)
    stage("generated scene materials", lambda: materials((root / "scenes/pale_ward.tscn").read_text(), "scene"))
    stage("actual author material block", lambda: materials(author_materials((root / "tools/author_pale_ward.py").read_text()), "author"))
    stage("confined nearest shader sampling and lossless import", shader)
    return {"passed": not errors, "checks": checks, "errors": errors, "evidence": evidence}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT, help="project root (defaults to script's parent project)")
    parser.add_argument("--output", type=Path, help="optional JSON report path; relative paths resolve from project root")
    args = parser.parse_args()
    result = check(args.root.resolve())
    if args.output:
        output = args.output if args.output.is_absolute() else args.root / args.output
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(result, indent=2) + "\n")
    for item in result["checks"]:
        print(("PASS" if item["passed"] else "FAIL") + ": " + item["name"])
    for error in result["errors"]:
        print("  " + error, file=sys.stderr)
    return 0 if result["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
