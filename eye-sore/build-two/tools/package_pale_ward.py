#!/usr/bin/env python3
"""Export, exercise, and package the pinned Pale Ward Linux release.

Run --help or read tools/PACKAGE_PALE_WARD.md. No network or Git mutations.
"""
from __future__ import annotations

import argparse
import configparser
import gzip
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
import tarfile
import tempfile

PROJECT = Path(__file__).resolve().parents[1]
PRESET = "Linux Portable"
MARKERS = ("GORE_EXPORT_SMOKE_OK:", "FOUNDATION_SMOKE_OK:")
RESERVED_NAMES = {"BUILD.json", "README.txt", "SHA256SUMS", "SOURCE_SHA256SUMS", "ARCHIVE.json",
                  "export.log", "smoke.log", "licenses.log", "GODOT_LICENSE.txt",
                  "GODOT_THIRD_PARTY_NOTICES.txt", "AUDIO_CREDITS.md", "VISUAL_CREDITS.md",
                  "export-gore.png", "export-gameplay.png", "export-menu.png", "provenance"}
BAD_OUTPUT = re.compile(r"(?:^|\n)\s*(?:SCRIPT ERROR:|ERROR:|WARNING:)|SMOKE_FAILED:", re.I)
EXCLUDED = {".godot", ".git", "build", "concepts", "docs", "tools", "verification"}
DEFAULT_LIMITATIONS = [
    "Playable reference-based art/layout pass; full production and human release acceptance pending.",
    "Materials and signs sample the original approved board; source-byte preservation does not establish whole-scene visual acceptance.",
    "Creature art remains generated, with eight frontal poses; complete directional animation and generated detail/perspective drift remain work.",
    "Human-paced encounters toward the original 5–8 minute duration remain work.",
    "Sustained human combat, interaction audio, and final mix review remain pending.",
]


class PackagingError(Exception):
    pass


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def file_record(path: Path) -> dict:
    return {"bytes": path.stat().st_size, "sha256": sha256(path)}


def checked(command: list[str], *, cwd: Path, timeout: int = 120,
            log: Path | None = None, markers: tuple[str, ...] = (),
            env: dict | None = None) -> str:
    try:
        result = subprocess.run(command, cwd=cwd, env=env, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, text=True, errors="replace",
                                timeout=timeout, check=False)
    except subprocess.TimeoutExpired as error:
        output = error.stdout or b""
        if isinstance(output, bytes):
            output = output.decode("utf-8", errors="replace")
        if log:
            log.write_text(output + "\nPACKAGING_TIMEOUT\n", encoding="utf-8")
        raise PackagingError(f"Command timed out after {timeout}s: {command[0]}") from error
    if log:
        log.write_text(result.stdout, encoding="utf-8")
    if result.returncode or BAD_OUTPUT.search(result.stdout):
        raise PackagingError(f"Command failed (exit {result.returncode}): {command!r}\n{result.stdout[-4000:]}")
    missing = [marker for marker in markers if marker not in result.stdout]
    if missing:
        raise PackagingError(f"Missing success markers: {missing}\n{result.stdout[-4000:]}")
    return result.stdout.strip()


def git(*arguments: str) -> str:
    return checked(["git", *arguments], cwd=PROJECT)


def provenance_files() -> list[Path]:
    roots = ("concepts/environment-art-v1", "concepts/gore-art-v1",
             "concepts/sprite-art-v1", "concepts/visual-v2/corrupted-biotech")
    paths = [PROJECT / "concepts/visual-v2/manifest.json",
             PROJECT / "concepts/audio-v3/manifest.json",
             PROJECT / "concepts/audio-v2/manifest.json",
             PROJECT / "verification/download_manifest.json",
             PROJECT / "assets/materials/approved-material-regions.json",
             PROJECT / "assets/materials/approved-sign-regions.json"]
    for root in roots:
        paths.extend(p for p in (PROJECT / root).rglob("*")
                     if p.is_file() and p.suffix in {".json", ".txt", ".md"})
    return sorted(set(paths))


def source_snapshot(extra: list[Path]) -> dict[str, str]:
    paths = [p for p in PROJECT.rglob("*") if p.is_file()
             and not set(p.relative_to(PROJECT).parts[:-1]) & EXCLUDED
             and "__pycache__" not in p.parts and not p.name.startswith(".")]
    paths += extra + [PROJECT / "tools/godot.sh", PROJECT / "tools/package_engine_licenses.gd",
                      Path(__file__).resolve()]
    result = {}
    for path in sorted(set(paths)):
        if path.is_symlink():
            raise PackagingError(f"Source symlinks are not supported: {path}")
        result[path.relative_to(PROJECT).as_posix()] = sha256(path)
    return result


def write_json(path: Path, data: dict) -> None:
    path.write_text(json.dumps(data, indent=2, sort_keys=True, ensure_ascii=False) + "\n", encoding="utf-8")


def create_archive(stage: Path, archive: Path, epoch: int) -> None:
    # Stable ordering, timestamps, ownership, modes and gzip header. Never add the archive to itself.
    with archive.open("wb") as raw:
        with gzip.GzipFile(fileobj=raw, mode="wb", filename="", mtime=epoch) as compressed:
            with tarfile.open(fileobj=compressed, mode="w", format=tarfile.PAX_FORMAT) as bundle:
                for path in sorted(stage.rglob("*")):
                    if not path.is_file() or path == archive:
                        continue
                    if path.is_symlink():
                        raise PackagingError(f"Package symlink refused: {path}")
                    info = bundle.gettarinfo(str(path), arcname=path.relative_to(stage).as_posix())
                    info.uid = info.gid = 0
                    info.uname = info.gname = ""
                    info.mtime = epoch
                    info.mode = 0o755 if path.stat().st_mode & stat.S_IXUSR else 0o644
                    with path.open("rb") as source:
                        bundle.addfile(info, source)


def verify_archive(archive: Path, executable: str, executable_hash: str) -> None:
    with tarfile.open(archive, "r:gz") as bundle:
        members = bundle.getmembers()
        names = [member.name for member in members]
        if len(names) != len(set(names)):
            raise PackagingError("Duplicate archive members")
        for member in members:
            if not member.isfile() or member.name.startswith("/") or ".." in Path(member.name).parts:
                raise PackagingError(f"Unsafe archive member: {member.name}")
        member = bundle.getmember(executable)
        if member.mode != 0o755:
            raise PackagingError("Archived executable permission is not 0755")
        checksums = bundle.extractfile("SHA256SUMS").read().decode("utf-8")
        for line in checksums.splitlines():
            expected, name = line.split("  ", 1)
            stream = bundle.extractfile(name)
            digest = hashlib.sha256()
            for block in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(block)
            if digest.hexdigest() != expected:
                raise PackagingError(f"Archived checksum mismatch: {name}")
        stream = bundle.extractfile(executable)
        digest = hashlib.sha256()
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
        if digest.hexdigest() != executable_hash:
            raise PackagingError("Archived executable hash differs from exported executable")


def arguments(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--build-dir", required=True, type=Path, help="Portable package destination")
    parser.add_argument("--executable-name", required=True, help="Executable basename, e.g. eyesore-pale-ward.x86_64")
    parser.add_argument("--source-commit", help="Source commit (default: Git HEAD); working-tree hashes are always recorded")
    parser.add_argument("--replace", action="store_true", help="Explicitly allow replacement of package files; unrelated files are retained")
    parser.add_argument("--dry-run", action="store_true", help="Validate inputs and print the plan; no export or destination writes")
    parser.add_argument("--video", type=Path, help="Optional existing MP4; copy/hash it and its paired AVI without transcoding")
    parser.add_argument("--smoke-timeout", type=int, default=120, help="Native release smoke timeout in seconds (default: 120)")
    return parser.parse_args(argv)


def package(args: argparse.Namespace) -> dict:
    destination = args.build_dir.expanduser().absolute()
    name = args.executable_name
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*", name) or name in RESERVED_NAMES:
        raise PackagingError("Executable name must be a safe basename, with letters/digits/dot/dash/underscore")
    if args.smoke_timeout <= 0:
        raise PackagingError("Smoke timeout must be positive")
    if any(parent.is_symlink() for parent in [destination, *destination.parents]) or (destination.exists() and not destination.is_dir()):
        raise PackagingError("Build destination must be a directory, not a symlink")
    if destination == PROJECT or PROJECT in destination.parents:
        raise PackagingError("Portable builds must be outside the source project")
    if ((destination / name).exists() or (destination / name).is_symlink()) and not args.replace:
        raise PackagingError(f"Refusing to overwrite existing executable: {destination / name}; use --replace explicitly")
    preset = configparser.ConfigParser(interpolation=None)
    preset.read(PROJECT / "export_presets.cfg")
    if preset.get("preset.0", "name") != f'"{PRESET}"' or not preset.getboolean("preset.0.options", "binary_format/embed_pck"):
        raise PackagingError("Expected Linux Portable embedded-PCK export preset")
    if preset.get("preset.0.options", "custom_template/release") != '""':
        raise PackagingError("Custom release templates are unsupported by this pinned workflow")
    commit = git("rev-parse", "--verify", f"{args.source_commit or 'HEAD'}^{{commit}}")
    head = git("rev-parse", "HEAD")
    if commit != head:
        raise PackagingError("Source commit must identify current HEAD; packaging exports the current working tree")
    epoch = int(os.environ.get("SOURCE_DATE_EPOCH", git("show", "-s", "--format=%ct", commit)))
    if epoch < 0 or epoch > 4294967295:
        raise PackagingError("SOURCE_DATE_EPOCH must be a valid unsigned gzip timestamp")
    engine = Path(os.environ.get("GODOT_BIN", str(Path(os.environ.get("EYESORE_TOOL_ROOT", str(Path.home() / ".local/share/eyesore-tools/4.7.2"))) / "Godot_v4.7.2-stable_linux.x86_64")))
    engine = engine.expanduser().absolute()
    data_home = Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share")))
    template = data_home / "godot/export_templates/4.7.2.stable/linux_release.x86_64"
    provenance = provenance_files()
    credits = [PROJECT / "assets/audio/CREDITS.md", PROJECT / "assets/VISUAL_CREDITS.md"]
    for path in [engine, template, PROJECT / "tools/godot.sh", PROJECT / "tools/package_engine_licenses.gd", *credits, *provenance]:
        if not path.is_file():
            raise PackagingError(f"Missing input: {path}")
    if not os.access(engine, os.X_OK):
        raise PackagingError(f"Pinned editor is not executable: {engine}")
    # Calling the binary directly keeps dry-run free of the wrapper's mkdir side effect.
    version = checked([str(engine), "--version"], cwd=PROJECT)
    if not version.startswith("4.7.2.stable."):
        raise PackagingError(f"Unexpected engine: {version}")
    engine_record, template_record = file_record(engine), file_record(template)
    video = args.video.expanduser().resolve() if args.video else None
    if video is None and destination.exists():
        candidates = sorted(destination.glob("*.mp4"))
        if len(candidates) > 1:
            raise PackagingError("Multiple existing MP4s; select one with --video")
        video = candidates[0] if candidates else None
    if video and (not video.is_file() or video.suffix.lower() != ".mp4"):
        raise PackagingError("--video must point to an existing MP4")
    if video and video.name in RESERVED_NAMES | {name, name.removesuffix(".x86_64") + "-linux.tar.gz"}:
        raise PackagingError("Video basename collides with a package output")
    source = source_snapshot([*credits, *provenance])
    plan = {"destination": str(destination), "executable": name, "source_commit": commit,
            "source_files": len(source), "source_tree_sha256": hashlib.sha256(json.dumps(source, sort_keys=True).encode()).hexdigest(),
            "source_date_epoch": epoch, "native_smoke_cwd": "/tmp",
            "native_smoke_flags": ["--automated-input", "--force-offscreen-draw"], "video": str(video) if video else None,
            "dry_run": args.dry_run}
    if args.dry_run:
        return plan
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".pale-ward-package-", dir=destination.parent) as temporary:
        stage = Path(temporary)
        wrapper = str(PROJECT / "tools/godot.sh")
        if checked([wrapper, "--version"], cwd=PROJECT) != version:
            raise PackagingError("Pinned wrapper engine changed after validation")
        print("Exporting pinned Linux release…", flush=True)
        checked([wrapper, "--headless", "--export-release", PRESET, str(stage / name)],
                cwd=PROJECT, timeout=900, log=stage / "export.log")
        executable = stage / name
        if not executable.is_file() or (stage / (name + ".pck")).exists():
            raise PackagingError("Export did not produce an embedded-assets executable")
        executable.chmod(0o755)
        print("Running native release gore and foundation smoke from /tmp…", flush=True)
        with tempfile.TemporaryDirectory(prefix="pale-ward-smoke-", dir="/tmp") as smoke_home:
            smoke_env = os.environ.copy()
            smoke_env.update(XDG_CONFIG_HOME=str(Path(smoke_home) / "config"), XDG_DATA_HOME=str(Path(smoke_home) / "data"))
            smoke_output = checked([str(executable), "--", "--smoke-test", "--gore-smoke",
                     "--automated-input", "--force-offscreen-draw",
                     f"--capture-prefix={stage / 'export'}"], cwd=Path("/tmp"), env=smoke_env,
                    timeout=args.smoke_timeout, log=stage / "smoke.log", markers=MARKERS)
        checked([wrapper, "--headless", "--script", "res://tools/package_engine_licenses.gd", "--", str(stage)],
                cwd=PROJECT, log=stage / "licenses.log", markers=("ENGINE_LICENSES_OK:",))
        for filename in ("GODOT_LICENSE.txt", "GODOT_THIRD_PARTY_NOTICES.txt"):
            if not (stage / filename).is_file() or (stage / filename).stat().st_size == 0:
                raise PackagingError(f"Missing/empty license output: {filename}")
        shutil.copyfile(credits[0], stage / "AUDIO_CREDITS.md")
        shutil.copyfile(credits[1], stage / "VISUAL_CREDITS.md")
        for path in provenance:
            target = stage / "provenance" / path.relative_to(PROJECT)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(path, target)
        if source != source_snapshot([*credits, *provenance]) or engine_record != file_record(engine) or template_record != file_record(template):
            raise PackagingError("Source inputs changed during export/smoke; stabilize source and retry")
        integration_path = PROJECT / "verification/INTEGRATION.json"
        integration = json.loads(integration_path.read_text()) if integration_path.is_file() else {}
        limitations = integration.get("known_issues", DEFAULT_LIMITATIONS)
        record = {"project": "Eyesore / The Pale Ward", "engine": version, "renderer": "Compatibility",
                  "source_commit": commit, "source_branch": git("branch", "--show-current"),
                  "source_head": head, "source_git_status": git("status", "--porcelain=v1", "--untracked-files=all"),
                  "source_date_epoch": epoch, "source_tree_sha256": plan["source_tree_sha256"],
                  "source_checksums": "SOURCE_SHA256SUMS", "engine_binary": engine_record,
                  "linux_release_template": template_record,
                  "executable": {"path": name, **file_record(executable), "pck": "embedded", "mode": "0755"},
                  "verification": {"native_export_smoke": "smoke.log", "working_directory": "/tmp",
                                   "success_markers": list(MARKERS), "exit_code": 0,
                                   "render_mode": "Forced offscreen native rendering; actual viewport PNGs, not visible-window presentation",
                                   "input_mode": "Automated programmatic combat; mouse visible; physical pointer input unverified",
                                   "captures": [{"label": label, "forced_offscreen": forced == "true",
                                                 "offscreen_required": required == "true"}
                                                for label, forced, required in re.findall(
                                                    r"SMOKE_CAPTURE_OK: label=(\w+) forced_offscreen=(true|false) offscreen_required=(true|false)",
                                                    smoke_output)],
                                   "scope": "Actual release programmatic shotgun kill, settled gore/reset, pause/resume, viewport/settings/audio buses. Human release acceptance pending."},
                  "known_issues": limitations}
        if integration_path.is_file():
            record["known_issues_source"] = {"path": "verification/INTEGRATION.json", **file_record(integration_path)}
        if video:
            shutil.copyfile(video, stage / video.name)
            if file_record(video) != file_record(stage / video.name):
                raise PackagingError("Video changed while copying")
            record["video"] = {"path": video.name, **file_record(stage / video.name), "processing": "Existing MP4 copied unchanged; no transcoding or new capture"}
            original = video.with_suffix(".avi")
            if original.is_file():
                shutil.copyfile(original, stage / original.name)
                if file_record(original) != file_record(stage / original.name):
                    raise PackagingError("Original AVI changed while copying")
                record["video"]["original_recording"] = {"path": original.name, **file_record(stage / original.name)}
        write_json(stage / "BUILD.json", record)
        (stage / "SOURCE_SHA256SUMS").write_text("".join(f"{digest}  {path}\n" for path, digest in sorted(source.items())), encoding="utf-8")
        (stage / "README.txt").write_text(
            f"EYESORE / THE PALE WARD\n\nRun ./{name} and click Play.\n"
            "WASD move, mouse look, left click fire; 1 pistol, 2 shotgun, 3 melee.\n"
            "E uses doors/lift/exit; walk over pickups; Tab shows visited areas.\n"
            "Escape pauses/settings; Retry restores the level. No jump/dash/reload.\n\n"
            "Find the Bio Wing / Operating Room key, return through the shortcut,\n"
            "open the raised C3 rear door, ride the lab lift and use the exit.\n\n"
            "Linux x86_64 graphics/audio/system libraries required. Assets are embedded.\n"
            "Native release smoke passed from /tmp; see smoke.log and BUILD.json.\n"
            "Audio/visual credits, unchanged provenance, engine/component notices and\n"
            "exact working-tree/build hashes are included. Human acceptance is pending.\n\n"
            "Known limitations:\n" + "".join(f"- {issue}\n" for issue in limitations), encoding="utf-8")
        payload = sorted(p for p in stage.rglob("*") if p.is_file())
        (stage / "SHA256SUMS").write_text("".join(f"{sha256(path)}  {path.relative_to(stage).as_posix()}\n" for path in payload), encoding="utf-8")
        archive = stage / (name.removesuffix(".x86_64") + "-linux.tar.gz")
        create_archive(stage, archive, epoch)
        verify_archive(archive, name, record["executable"]["sha256"])
        archive_record = {"path": archive.name, **file_record(archive), "archived_executable_hash_and_mode_verified": True}
        # Outside the archive to avoid a circular BUILD/archive checksum dependency.
        write_json(stage / "ARCHIVE.json", archive_record)
        files = sorted(p for p in stage.rglob("*") if p.is_file())
        for path in files:
            target = destination / path.relative_to(stage)
            if target.is_symlink() or any(parent.is_symlink() for parent in target.parents) or (target.exists() and not target.is_file()):
                raise PackagingError(f"Unsafe destination for package file: {target}")
        if not args.replace:
            for path in files:
                target = destination / path.relative_to(stage)
                if target.exists() and not (video and target == destination / video.name and sha256(target) == sha256(path)) and not (video and target == destination / video.with_suffix(".avi").name and sha256(target) == sha256(path)):
                    raise PackagingError(f"Refusing to replace package file: {target}; use --replace explicitly")
        destination.mkdir(parents=True, exist_ok=True)
        for path in files:
            target = destination / path.relative_to(stage)
            target.parent.mkdir(parents=True, exist_ok=True)
            os.replace(path, target)
        return {**plan, "dry_run": False, "executable_record": record["executable"], "archive": archive_record}


def main(argv: list[str] | None = None) -> int:
    try:
        print(json.dumps(package(arguments(argv)), indent=2, ensure_ascii=False))
        return 0
    except (PackagingError, OSError, ValueError, configparser.Error, tarfile.TarError) as error:
        print(f"Packaging failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
