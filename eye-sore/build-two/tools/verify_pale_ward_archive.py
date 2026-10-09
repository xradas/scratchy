#!/usr/bin/env python3
"""Independently audit a Pale Ward tar.gz without extraction or running its executable.

Usage: python3 tools/verify_pale_ward_archive.py ARCHIVE --report REPORT.json
Only archive integrity and recorded evidence are checked; human acceptance is not assessed.
Uses Python's standard library and deliberately does not import the packager.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import sys
import tarfile
import zlib

HASH = re.compile(r"[0-9a-f]{64}\Z")
COMMIT = re.compile(r"(?:[0-9a-f]{40}|[0-9a-f]{64})\Z")
BAD_LOG = re.compile(r"(?:^|\n)\s*(?:SCRIPT ERROR:|ERROR:|WARNING:)|SMOKE_FAILED:|PACKAGING_TIMEOUT", re.I)
MARKERS = ("GORE_EXPORT_SMOKE_OK:", "FOUNDATION_SMOKE_OK:")
BOARD = "assets/materials/pale-ward-approved-board.png"
MATERIAL = "assets/materials/approved-material-regions.json"
SIGN = "assets/materials/approved-sign-regions.json"


class AuditError(Exception):
    """An archive failed a required check."""


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AuditError(message)


def safe_path(name: str) -> bool:
    return (isinstance(name, str) and bool(name) and "\\" not in name
            and not any(ord(char) < 32 or ord(char) == 127 for char in name)
            and not name.startswith("/") and not re.match(r"^[A-Za-z]:", name)
            and all(part not in {"", ".", ".."} for part in name.split("/"))
            and PurePosixPath(name).as_posix() == name)


def checksums(text: str, label: str) -> dict[str, str]:
    result = {}
    for line in text.splitlines():
        match = re.fullmatch(r"([0-9a-f]{64})  (.+)", line)
        require(match is not None, f"Malformed checksum line in {label}")
        digest, name = match.groups()
        require(safe_path(name), f"Unsafe checksum path in {label}: {name!r}")
        require(name not in result, f"Duplicate checksum path in {label}: {name}")
        result[name] = digest
    require(bool(result), f"Empty checksum list: {label}")
    return result


def unique_object(pairs: list[tuple[str, object]]) -> dict:
    result = {}
    for key, value in pairs:
        require(key not in result, f"Duplicate JSON key: {key}")
        result[key] = value
    return result


def valid_record(record: object, label: str) -> dict:
    require(isinstance(record, dict), f"Missing file record: {label}")
    require(isinstance(record.get("sha256"), str) and bool(HASH.fullmatch(record["sha256"])),
            f"Invalid file hash: {label}")
    require(type(record.get("bytes")) is int and record["bytes"] > 0, f"Invalid file size: {label}")
    return record


def verify(archive: Path) -> dict:
    require(archive.is_file(), f"Archive missing or not a file: {archive}")
    archive_digest = hashlib.sha256()
    with archive.open("rb") as raw:
        for block in iter(lambda: raw.read(1024 * 1024), b""):
            archive_digest.update(block)
    with tarfile.open(archive, "r:gz") as bundle:
        members = {}
        for member in bundle.getmembers():
            require(safe_path(member.name) and member.isfile(), f"Unsafe archive member: {member.name!r}")
            require(member.name not in members, f"Duplicate archive member: {member.name}")
            require(member.mode in {0o644, 0o755}, f"Unexpected archive permissions: {member.name}")
            require(not member.sparse, f"Sparse archive member refused: {member.name}")
            members[member.name] = member
        require(bool(members), "Empty archive")
        for name in members:
            require(not any(parent.as_posix() in members for parent in PurePosixPath(name).parents
                            if parent.as_posix() != "."), f"File/directory path collision: {name}")

        def data(name: str) -> bytes:
            require(name in members, f"Required archive file missing: {name}")
            with bundle.extractfile(members[name]) as stream:
                return stream.read()

        def text(name: str) -> str:
            return data(name).decode("utf-8")

        def document(name: str) -> dict:
            value = json.loads(text(name), object_pairs_hook=unique_object)
            require(isinstance(value, dict), f"JSON object required: {name}")
            return value

        payload = checksums(text("SHA256SUMS"), "SHA256SUMS")
        expected = set(members) - {"SHA256SUMS"}
        require(set(payload) == expected,
                f"SHA256SUMS coverage mismatch: missing={sorted(expected - set(payload))}; extra={sorted(set(payload) - expected)}")
        actual_hashes = {}
        for name, expected_hash in payload.items():
            digest = hashlib.sha256()
            with bundle.extractfile(members[name]) as stream:
                for block in iter(lambda: stream.read(1024 * 1024), b""):
                    digest.update(block)
            actual_hashes[name] = digest.hexdigest()
            require(actual_hashes[name] == expected_hash, f"Payload checksum mismatch: {name}")

        build = document("BUILD.json")
        commit = build.get("source_commit")
        require(isinstance(commit, str) and bool(COMMIT.fullmatch(commit)) and set(commit) != {"0"},
                "BUILD source_commit must contain a full nonzero commit hash")
        require(build.get("source_head") == commit, "BUILD source_commit differs from source_head")
        executable = valid_record(build.get("executable"), "executable")
        executable_path = executable.get("path")
        require(safe_path(executable_path), "Unsafe BUILD executable path")
        require(executable_path in members, "BUILD executable missing from archive")
        require(members[executable_path].mode == 0o755 and executable.get("mode") == "0755",
                "Executable permission must be 0755 in archive and BUILD")
        require(executable.get("pck") == "embedded", "BUILD must record embedded PCK")
        require(executable["sha256"] == actual_hashes[executable_path], "BUILD executable hash mismatch")
        require(executable["bytes"] == members[executable_path].size, "BUILD executable size mismatch")
        valid_record(build.get("engine_binary"), "engine_binary")
        valid_record(build.get("linux_release_template"), "linux_release_template")

        source_path = build.get("source_checksums")
        require(source_path == "SOURCE_SHA256SUMS", "BUILD must reference SOURCE_SHA256SUMS")
        source = checksums(text(source_path), source_path)
        source_digest = hashlib.sha256(json.dumps(source, sort_keys=True).encode()).hexdigest()
        require(build.get("source_tree_sha256") == source_digest, "BUILD source_tree_sha256 mismatch")
        for name in members:
            if name.startswith("provenance/"):
                original = name.removeprefix("provenance/")
                require(source.get(original) == actual_hashes[name], f"Provenance/source hash mismatch: {name}")

        material = document("provenance/" + MATERIAL)
        sign = document("provenance/" + SIGN)
        board_hash = source.get(BOARD)
        require(board_hash is not None, f"Runtime board absent from source checksums: {BOARD}")
        require(material.get("source") == "concepts/visual-v2/corrupted-biotech/board.png",
                "Material manifest must identify the original approved board")
        require(material.get("runtime_copy") == BOARD, "Material manifest runtime board path mismatch")
        require(material.get("source_sha256") == board_hash and material.get("runtime_copy_sha256") == board_hash,
                "Material original/runtime board hashes differ from SOURCE_SHA256SUMS")
        require(sign.get("source") == "res://" + BOARD and sign.get("source_sha256") == board_hash,
                "Sign source path/hash differs from the runtime board source checksum")
        require(bool(material.get("regions_pixels")) and bool(sign.get("regions")), "Empty material/sign regions")

        for target, original in (("AUDIO_CREDITS.md", "assets/audio/CREDITS.md"),
                                 ("VISUAL_CREDITS.md", "assets/VISUAL_CREDITS.md")):
            require(bool(text(target).strip()), f"Empty credits: {target}")
            require(source.get(original) == actual_hashes[target], f"Credits/source hash mismatch: {target}")
        license_text = text("GODOT_LICENSE.txt")
        normalized_license = " ".join(license_text.split()).lower()
        for clause in ("Permission is hereby granted", "The above copyright notice and this permission notice",
                       "THE SOFTWARE IS PROVIDED", "IN NO EVENT SHALL THE AUTHORS", "copyright"):
            require(clause.lower() in normalized_license, f"Godot license missing clause: {clause}")
        notices = text("GODOT_THIRD_PARTY_NOTICES.txt")
        prefix = "Bundled Godot component copyright records\n\n"
        require(notices.startswith(prefix), "Missing full Godot component copyright records")
        components, offset = json.JSONDecoder(object_pairs_hook=unique_object).raw_decode(notices[len(prefix):])
        require(isinstance(components, list) and len(components) > 1, "Missing Godot third-party component copyright records")
        require(any(component.get("name") == "Godot Engine" for component in components if isinstance(component, dict)),
                "Godot Engine copyright record missing")
        license_blocks = notices[len(prefix) + offset:]
        license_positions = {}
        for component in components:
            require(isinstance(component, dict) and bool(component.get("name")) and bool(component.get("parts")),
                    "Incomplete Godot component copyright record")
            for part in component["parts"]:
                require(isinstance(part, dict) and bool(part.get("copyright")) and bool(part.get("files"))
                        and isinstance(part.get("license"), str) and bool(part["license"]),
                        "Incomplete Godot component attribution")
                # Components may use compound SPDX expressions; require every referenced license block.
                licenses = re.findall(r"[A-Za-z0-9][A-Za-z0-9.+_-]*", part["license"])
                for license_name in licenses:
                    if license_name.upper() not in {"AND", "OR", "WITH"}:
                        heading = re.search(r"(?:^|\n)" + re.escape(license_name) + r"\n", license_blocks)
                        require(heading is not None, f"Component license text missing: {license_name}")
                        license_positions[license_name] = heading.end()
        ordered_licenses = sorted(license_positions.items(), key=lambda item: item[1])
        for index, (license_name, start) in enumerate(ordered_licenses):
            end = ordered_licenses[index + 1][1] if index + 1 < len(ordered_licenses) else len(license_blocks)
            require(len(license_blocks[start:end].strip()) >= 100,
                    f"Component license body missing/truncated: {license_name}")
        license_log = text("licenses.log")
        require("ENGINE_LICENSES_OK:" in license_log and not BAD_LOG.search(license_log), "License export log failed")

        verification = build.get("verification")
        require(isinstance(verification, dict), "Missing BUILD verification record")
        require(verification.get("native_export_smoke") == "smoke.log", "Missing native release smoke reference")
        require(verification.get("working_directory") == "/tmp", "Native release smoke must record /tmp working directory")
        require(type(verification.get("exit_code")) is int and verification["exit_code"] == 0, "Native smoke did not record exit 0")
        require(set(verification.get("success_markers", [])) >= set(MARKERS), "BUILD native smoke markers missing")
        smoke = text("smoke.log")
        require(not BAD_LOG.search(smoke), "Native smoke log contains errors/warnings/failure")
        require(all(marker in smoke for marker in MARKERS), "Native smoke success marker missing")
        require(re.search(r"^OpenGL API .+Compatibility.+Using Device:", smoke, re.M) is not None,
                "Native smoke lacks actual Compatibility graphics-device evidence")
        require(not re.search(r"headless|dummy renderer", smoke, re.I), "Native smoke records a headless/dummy renderer")
        export_log = text("export.log")
        require(not BAD_LOG.search(export_log), "Export log contains errors/warnings/failure")
        require(bool(text("README.txt").strip()), "Empty portable README")
        limitations = build.get("known_issues")
        require(isinstance(limitations, list) and bool(limitations)
                and all(isinstance(issue, str) and issue.strip() for issue in limitations), "Missing explicit known limitations")
        return {"status": "passed", "archive": str(archive.resolve()), "archive_sha256": archive_digest.hexdigest(),
                "payload_files_verified": len(payload), "source_files_recorded": len(source),
                "source_commit": commit, "source_head": build["source_head"],
                "source_git_status": build.get("source_git_status"), "executable": executable,
                "original_material_and_sign_provenance_verified": True,
                "runtime_board_path": BOARD, "runtime_board_source_sha256": board_hash,
                "credits_verified": ["AUDIO_CREDITS.md", "VISUAL_CREDITS.md", "GODOT_LICENSE.txt",
                                     "GODOT_THIRD_PARTY_NOTICES.txt"],
                "engine_component_records": len(components), "engine_license_bodies": len(ordered_licenses),
                "smoke_evidence": {"markers": list(MARKERS), "recorded_working_directory": "/tmp",
                                   "graphics_device_log_present": True, "rerun_by_verifier": False},
                "known_issues": limitations,
                "scope": "Archive integrity and included recorded evidence only; no execution, independent source Git authentication, embedded-PCK inspection, visual approval or human release acceptance."}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("archive", type=Path)
    parser.add_argument("--report", type=Path, help="Write the audit result as JSON, including failed audits")
    args = parser.parse_args(argv)
    # Never allow the report itself to overwrite the artifact under audit.
    if args.report and args.report.resolve() == args.archive.resolve():
        parser.error("--report must differ from the archive path")
    try:
        report = verify(args.archive)
    except (AuditError, OSError, EOFError, ValueError, TypeError, KeyError, AttributeError,
            tarfile.TarError, zlib.error) as error:
        report = {"status": "failed", "archive": str(args.archive.absolute()), "error": str(error),
                  "scope": "No acceptance claim; required archive audit checks did not pass."}
    rendered = json.dumps(report, indent=2, ensure_ascii=False) + "\n"
    if args.report:
        try:
            args.report.parent.mkdir(parents=True, exist_ok=True)
            args.report.write_text(rendered, encoding="utf-8")
        except OSError as error:
            print(f"Cannot write audit report: {error}", file=sys.stderr)
            return 1
    print(rendered, end="")
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    sys.exit(main())
