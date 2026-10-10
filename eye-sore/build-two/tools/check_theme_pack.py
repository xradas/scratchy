#!/usr/bin/env python3
"""Independent three-theme Linux archive audit using a trusted Godot pack reader.

python3 tools/check_theme_pack.py ARCHIVE --expected-commit FULL_HASH --report OUT.json
python3 tools/check_theme_pack.py --source-preflight --report OUT.json

No Git commands, network requests, packager import, archive execution or asset writes.
The external Godot probe runs with --main-pack in an isolated temporary directory.
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
import struct
import subprocess
import sys
import tarfile
import tempfile
import zlib

from verify_pale_ward_archive import AuditError, COMMIT, checksums, require, unique_object, verify

ROOT = Path(__file__).resolve().parents[1]
GODOT = Path.home() / ".local/share/eyesore-tools/4.7.2/Godot_v4.7.2-stable_linux.x86_64"
KINDS = ("unsealed", "vessel", "ironbound", "censer", "reaver", "surveyor")
MUSIC = ("menu_abelian", "level_music_biotech_candidate", "level_music_fortress_candidate")
PROVENANCE = ("concepts/audio-v3/manifest.json", "concepts/audio-v4/manifest.json",
              "concepts/audio-v5/manifest.json", "concepts/expansion-v1/provenance.json")


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def read_json(path: Path) -> dict:
    value = json.loads(path.read_text(), object_pairs_hook=unique_object)
    require(isinstance(value, dict), f"JSON object required: {path}")
    return value


def png_rgba(data: bytes) -> tuple[int, int, bytes]:
    """Decode native noninterlaced RGBA8 PNGs with the standard library only."""
    require(data[:8] == b"\x89PNG\r\n\x1a\n", "Invalid PNG signature")
    cursor, compressed, header = 8, [], None
    while cursor < len(data):
        length, = struct.unpack_from(">I", data, cursor)
        kind = data[cursor + 4:cursor + 8]
        chunk = data[cursor + 8:cursor + 8 + length]
        crc, = struct.unpack_from(">I", data, cursor + 8 + length)
        require(zlib.crc32(kind + chunk) & 0xffffffff == crc, "PNG chunk CRC mismatch")
        cursor += length + 12
        if kind == b"IHDR": header = struct.unpack(">IIBBBBB", chunk)
        elif kind == b"IDAT": compressed.append(chunk)
        elif kind == b"IEND": break
    require(header is not None and header[2:] == (8, 6, 0, 0, 0), "Native RGBA8 noninterlaced PNG required")
    width, height = header[:2]
    require(0 < width <= 8192 and 0 < height <= 8192, "PNG dimensions outside bounded native audit")
    raw = zlib.decompress(b"".join(compressed))
    stride = width * 4
    require(len(raw) == height * (stride + 1), "PNG decoded scanline size mismatch")
    previous, output = bytearray(stride), bytearray()
    for y in range(height):
        start = y * (stride + 1)
        mode = raw[start]
        require(mode in range(5), "Unknown PNG row filter")
        row = bytearray(raw[start + 1:start + 1 + stride])
        if mode:
            for x in range(stride):
                left = row[x - 4] if x >= 4 else 0
                upper = previous[x]
                corner = previous[x - 4] if x >= 4 else 0
                if mode == 1: predictor = left
                elif mode == 2: predictor = upper
                elif mode == 3: predictor = (left + upper) // 2
                else:
                    p = left + upper - corner
                    distances = (abs(p - left), abs(p - upper), abs(p - corner))
                    predictor = (left, upper, corner)[distances.index(min(distances))]
                row[x] = (row[x] + predictor) & 255
        output.extend(row)
        previous = row
    return width, height, bytes(output)


def pixels(width: int, height: int, rgba: bytes) -> dict:
    alpha = rgba[3::4]
    visible = b"".join(rgba[i:i + 4] for i in range(0, len(rgba), 4) if rgba[i + 3] >= 128)
    return {"dimensions": [width, height], "alpha_sha256": digest(alpha),
            "opaque_rgba_sha256": digest(visible), "opaque_pixels": len(visible) // 4}


def crop_pixels(width: int, height: int, rgba: bytes, rect: list) -> dict:
    require(len(rect) == 4 and all(isinstance(v, (int, float)) and v == int(v) for v in rect), "Integer native source rectangle required")
    x, y, w, h = map(int, rect)
    require(0 <= x < x + w <= width and 0 <= y < y + h <= height, "Native source rectangle outside PNG")
    region = b"".join(rgba[(row * width + x) * 4:(row * width + x + w) * 4] for row in range(y, y + h))
    return pixels(w, h, region)


def ogg_identity(data: bytes) -> dict:
    cursor, current, packets, serial = 0, bytearray(), [], None
    while cursor < len(data):
        require(data[cursor:cursor + 4] == b"OggS" and data[cursor + 4] == 0, "Invalid Ogg page")
        page_serial, = struct.unpack_from("<I", data, cursor + 14)
        if serial is None: serial = page_serial
        require(serial == page_serial, "Chained/multiplexed Ogg outside single-stream audit")
        count = data[cursor + 26]
        lacing = data[cursor + 27:cursor + 27 + count]
        payload = cursor + 27 + count
        for size in lacing:
            current.extend(data[payload:payload + size]); payload += size
            if size < 255: packets.append(bytes(current)); current.clear()
        cursor = payload
    require(not current and len(packets) >= 3 and packets[0][:7] == b"\x01vorbis", "Incomplete Vorbis packets")
    header = packets[0]
    return {"packet_sha256": digest(b"".join(struct.pack("<Q", len(packet)) + packet for packet in packets)),
            "channels": header[11], "sample_rate": struct.unpack_from("<I", header, 12)[0], "packet_count": len(packets)}


def expectations(root: Path, source: dict[str, str] | None = None) -> dict:
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
    result = {"files": files, "enemies": {}, "stages": {}, "audio": {}, "music": {},
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
    require(len(ledger["cues"]) == 35, "Source runtime ledger must contain 35 cues")
    for name, cue in ledger["cues"].items():
        path = cue["file"].removeprefix("res://")
        result["audio"][name] = {"path": cue["file"], "bus": cue["bus"], "spatial": cue.get("spatial", cue["bus"] not in ("Weapons", "Music")), **ogg_identity(recorded(path))}
    for name in MUSIC:
        path = f"assets/audio/music/{name}.ogg"
        result["music"][name] = {"path": "res://" + path, **ogg_identity(recorded(path))}
        require(result["music"][name]["channels"] == 2, "Source music must remain stereo: " + name)
    return result


def provenance(root: Path, bundle: tarfile.TarFile, source: dict[str, str]) -> dict:
    verified, local_evidence, runtime_cues = [], {}, {}
    members = {member.name for member in bundle.getmembers()}
    for path in PROVENANCE:
        member = "provenance/" + path
        require(member in members, "Required themed provenance missing: " + member)
        data = bundle.extractfile(member).read()
        require(source.get(path) == digest(data) == digest((root / path).read_bytes()), "Provenance archive/source identity: " + path)
        doc = json.loads(data, object_pairs_hook=unique_object)
        verified.append(path)
        if path.endswith("provenance.json"):
            require({asset["kind"] for asset in doc["assets"]} == set(KINDS[2:]), "Four original-board art provenance records")
            for asset in doc["assets"]:
                require(source.get(asset["runtime"]) == asset["sha256"], "Native art runtime hash: " + asset["kind"])
                for key in ("prompt", "reference"):
                    p = root / asset[key]
                    require(digest(p.read_bytes()) == asset[key + "_sha256"], "Recorded art " + key + " hash: " + asset["kind"])
                prompt = "provenance/" + asset["prompt"]
                require(prompt in members and digest(bundle.extractfile(prompt).read()) == asset["prompt_sha256"], "Archived original art prompt: " + asset["kind"])
            continue
        licensed_ids = {record["id"] for record in doc.get("sources", [])}
        for name, cue in doc.get("cues", {}).items():
            source_ids = cue.get("source_ids", [cue["source_id"]] if "source_id" in cue else [])
            require(bool(source_ids) and set(source_ids) <= licensed_ids, "Cue has declared licensed source: " + name)
            if "runtime" in cue:
                require(source.get(cue["runtime"]) == cue["runtime_sha256"], "Designed audio runtime provenance: " + name)
                runtime_cues[name] = cue["runtime"]
            elif path == "concepts/audio-v3/manifest.json":
                runtime = "assets/audio/" + cue.get("ogg_file", cue["file"])
                require(source.get(runtime) == cue.get("ogg_sha256", cue.get("sha256")), "Provided audio/music runtime provenance: " + name)
        for record in doc.get("sources", []):
            require(bool(record.get("license")) and bool(record.get("license_url")) and bool(record.get("source_url")), "Incomplete audio license/source attribution")
            original = record.get("original")
            if original:
                p = Path(original)
                if not p.parts[:1] == ("concepts",): p = Path(path).parent / p
                require(digest((root / p).read_bytes()) == record["original_sha256"], "Licensed original local hash: " + str(p))
            for evidence, sha in record.get("license_evidence_sha256", {}).items():
                p = Path(evidence)
                if not p.parts[:1] == ("concepts",): p = Path(path).parent / p
                require(digest((root / p).read_bytes()) == sha, "Local recorded license evidence hash: " + str(p))
                local_evidence[str(p)] = {"sha256": sha, "archived": "provenance/" + str(p) in members}
    expected_creatures = {f"{kind}_{action}" for kind in KINDS for action in ("attack_warning", "hurt", "death")}
    require(expected_creatures <= set(runtime_cues), "All 18 creature streams have archived design provenance")
    return {"archived_manifests": verified, "creature_design_records": len(expected_creatures),
            "local_license_evidence": local_evidence,
            "scope": "Archived license declarations and provided original/evidence hashes verified locally; external license pages were not independently researched."}


def run_probe(args: argparse.Namespace, expected: dict, temporary: Path, pack: Path | None) -> dict:
    version = subprocess.run([str(args.godot), "--version"], capture_output=True, text=True, check=True).stdout.strip()
    require(version.startswith("4.7.2.stable.official."), "Trusted official pinned Godot 4.7.2 required")
    input_path, report_path = temporary / "expected.json", temporary / "pack-report.json"
    input_path.write_text(json.dumps(expected))
    (temporary / "project.godot").write_text('[application]\nconfig/name="Independent Theme Pack Audit"\n')
    command = [str(args.godot), "--headless", "--path", str(temporary if pack else args.source_root)]
    if pack: command += ["--main-pack", str(pack)]
    command += ["--script", str(Path(__file__).with_suffix(".gd")), "--", "--expected=" + str(input_path), "--report=" + str(report_path)]
    if pack: command.append("--packed")
    process = subprocess.run(command, cwd=temporary, capture_output=True, text=True, timeout=180)
    combined = process.stdout + process.stderr
    require(report_path.is_file(), "Godot pack probe produced no report: " + combined[-4000:])
    result = read_json(report_path)
    result["engine_version"] = version
    result["probe_exit_code"] = process.returncode
    result["script_errors"] = bool(re.search(r"(?:SCRIPT ERROR:|^ERROR:)", combined, re.M))
    result["probe_log_tail"] = combined[-4000:]
    require(not result["script_errors"], "Godot pack probe script/engine errors: " + combined[-4000:])
    return result


def audit(args: argparse.Namespace) -> dict:
    root = args.source_root.resolve()
    with tempfile.TemporaryDirectory(prefix="eyesore-independent-theme-") as td:
        temporary = Path(td)
        if args.source_preflight:
            expected = expectations(root)
            probe = run_probe(args, expected, temporary, None)
            return {"status": "passed" if probe["pass"] else "failed", "source_preflight": True, "embedded_pack": probe,
                    "scope": "Current source resource audit only; no fresh archive or release claim."}
        require(args.archive is not None and args.expected_commit is not None, "Archive and --expected-commit required")
        require(COMMIT.fullmatch(args.expected_commit) is not None, "Full expected commit hash required")
        base = verify(args.archive)
        require(base["source_commit"] == args.expected_commit, "Archive commit differs from explicitly expected source commit")
        record_path = args.archive_record or args.archive.parent / "ARCHIVE.json"
        record = read_json(record_path)
        require(record["path"] == args.archive.name and record["bytes"] == args.archive.stat().st_size and record["sha256"] == base["archive_sha256"], "External archive checksum record mismatch")
        with tarfile.open(args.archive, "r:gz") as bundle:
            source = checksums(bundle.extractfile("SOURCE_SHA256SUMS").read().decode(), "SOURCE_SHA256SUMS")
            for relative, sha in source.items():
                local = root / relative
                require(local.is_file() and not local.is_symlink() and local.resolve().is_relative_to(root), "Recorded local source missing/unsafe: " + relative)
                require(digest(local.read_bytes()) == sha, "Recorded current source mismatch: " + relative)
            evidence = provenance(root, bundle, source)
            expected = expectations(root, source)
            expected["engine_license_sha256"] = digest(bundle.extractfile("GODOT_LICENSE.txt").read())
            expected["engine_notices_sha256"] = digest(bundle.extractfile("GODOT_THIRD_PARTY_NOTICES.txt").read())
            build = json.loads(bundle.extractfile("BUILD.json").read(), object_pairs_hook=unique_object)
            require(digest(args.godot.read_bytes()) == build["engine_binary"]["sha256"], "Trusted Godot binary differs from build's pinned engine")
            executable = temporary / "archived-embedded-pack.x86_64"
            executable.write_bytes(bundle.extractfile(build["executable"]["path"]).read())
            executable.chmod(0o600)
            probe = run_probe(args, expected, temporary, executable)
        return {"status": "passed" if probe["pass"] else "failed", "archive": str(args.archive.resolve()),
                "archive_sha256": base["archive_sha256"], "archive_checksum_record_verified": True,
                "expected_source_commit": args.expected_commit, "recorded_source_files_verified": len(source),
                "structural_archive_audit": base, "provenance": evidence, "embedded_pack": probe,
                "scope": "Checksums, recorded source identity, provided provenance and actual embedded resources inspected by trusted Godot; no Git history authentication, human visual/listening acceptance or fresh human playthrough claim."}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("archive", nargs="?", type=Path)
    parser.add_argument("--expected-commit")
    parser.add_argument("--archive-record", type=Path)
    parser.add_argument("--source-root", type=Path, default=ROOT)
    parser.add_argument("--godot", type=Path, default=GODOT)
    parser.add_argument("--source-preflight", action="store_true")
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    require(args.archive is None or args.report.resolve() != args.archive.resolve(), "Report cannot overwrite archive")
    try:
        result = audit(args)
    except (AuditError, OSError, ValueError, KeyError, TypeError, IndexError, AttributeError,
            struct.error, zlib.error, tarfile.TarError, subprocess.SubprocessError) as error:
        result = {"status": "failed", "error": str(error), "archive": str(args.archive) if args.archive else None,
                  "scope": "Required independent audit checks failed; no release acceptance claim."}
    result["auditor_sha256"] = digest(Path(__file__).read_bytes())
    result["godot_probe_sha256"] = digest(Path(__file__).with_suffix(".gd").read_bytes())
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"status": result["status"], "report": str(args.report), "error": result.get("error"),
                      "pack_checks": result.get("embedded_pack", {}).get("checks"),
                      "pack_failures": result.get("embedded_pack", {}).get("failures", [])}, indent=2))
    return 0 if result["status"] == "passed" else 1


if __name__ == "__main__": sys.exit(main())
