#!/usr/bin/env python3
"""Run the final headless Ward integration gate with isolated evidence.

Uses the pinned engine wrapper. Bot traversal time is not human play duration.
Each invocation owns a fresh directory beneath --output-dir, including on failure.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shlex
import signal
import subprocess
import sys
import time
import uuid


PROJECT = Path(__file__).resolve().parents[1]
CHECKS = (
    ("route", "check_pale_ward_route.gd", "PALE_WARD_ROUTE_OK"),
    ("integrated", "playtest_pale_ward.gd", "INTEGRATED_WARD_PLAYTEST "),
    ("session", "check_ward_session.gd", "WARD_SESSION_OK:"),
)
DIAGNOSTIC = re.compile(r"\b(?:SCRIPT ERROR|ERROR|WARNING)\b")


def command(script: str, evidence: Path) -> list[str]:
    return [str(PROJECT / "tools/godot.sh"), "--headless", "--path", str(PROJECT),
            "--script", f"res://tools/{script}", "--", f"--evidence-dir={evidence}"]


def number(value: object) -> bool:
    return type(value) in (int, float) and math.isfinite(value)


def validate_json(name: str, evidence: Path) -> list[str]:
    if name == "session":
        return []  # Session assertions are checked through exit, marker and diagnostics.
    filename = "pale-ward-route.json" if name == "route" else "integrated-playtest.json"
    try:
        report = json.loads((evidence / filename).read_text())
    except (OSError, ValueError) as error:
        return [f"Cannot read {filename}: {error}"]
    if not isinstance(report, dict):
        return [f"{filename} must contain an object"]
    errors = []
    if report.get("failures") != []:
        errors.append(f"{filename}: failures must be an empty array")
    if name == "route":
        records = report.get("records")
        complete = [record for record in records if isinstance(record, dict) and record.get("completed") is True] if isinstance(records, list) else []
        if not complete:
            errors.append("Route has no completed record")
        elif complete[-1].get("shortcut_open") is not True:
            errors.append("Route completion did not preserve the open shortcut")
        return errors
    if report.get("completed") is not True:
        errors.append("Integrated playtest did not complete")
    if not number(report.get("health")) or report["health"] <= 0:
        errors.append("Integrated playtest did not survive with positive health")
    if report.get("secret_used") is not False:
        errors.append("Integrated playtest used secret supplies or lacks secret evidence")
    for field in ("shots", "kills"):
        if type(report.get(field)) is not int or report[field] <= 0:
            errors.append(f"Integrated playtest lacks positive {field} evidence")
    scope = report.get("scope", "")
    if not isinstance(scope, str) or "normal AI/health/ammo" not in scope or "no secret supplies or cheats" not in scope:
        errors.append("Integrated playtest lacks normal AI/health/ammo scope")
    segments = report.get("segments")
    if not isinstance(segments, list) or not segments:
        errors.append("Integrated playtest has no traversal segments")
        return errors
    labels = set()
    for index, segment in enumerate(segments):
        if not isinstance(segment, dict):
            errors.append(f"Segment {index} is not an object")
            continue
        labels.add(segment.get("segment") if isinstance(segment.get("segment"), str) else "")
        for field in ("shells", "pistol"):
            if type(segment.get(field)) is not int or segment[field] < 0:
                errors.append(f"Segment {index} has invalid normal {field} ammunition")
        if not number(segment.get("health")) or segment["health"] <= 0:
            errors.append(f"Segment {index} lacks positive health")
    required = {"Shortcut approach", "Shortcut control", "Shortcut return", "Containment stairs", "Rear lab", "Lift boarding", "Discharge exit"}
    missing = required - labels
    if missing:
        errors.append(f"Integrated playtest missing required segments: {', '.join(sorted(missing))}")
    if not any(label.startswith("Bio route ") for label in labels):
        errors.append("Integrated playtest missing physical Bio/key route")
    return errors


def run_check(name: str, script: str, marker: str, run_dir: Path, timeout: float) -> dict:
    evidence = run_dir / name
    evidence.mkdir()  # The integrated script assumes its evidence directory exists.
    argv = command(script, evidence)
    log = evidence / "engine.log"
    started = time.monotonic()
    errors = []
    returncode = None
    timed_out = False
    with log.open("wb") as stream:
        try:
            process = subprocess.Popen(argv, cwd=PROJECT, stdout=stream,
                                       stderr=subprocess.STDOUT, start_new_session=True)
            try:
                returncode = process.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                timed_out = True
                os.killpg(process.pid, signal.SIGKILL)
                returncode = process.wait()
                errors.append(f"Timed out after {timeout:g} seconds")
        except OSError as error:
            errors.append(f"Could not launch engine: {error}")
    contents = log.read_text(errors="replace")
    if returncode != 0:
        errors.append(f"Engine exit code: {returncode}")
    if not any(line.startswith(marker) for line in contents.splitlines()):
        errors.append(f"Missing explicit success marker: {marker.strip()}")
    diagnostics = [line for line in contents.splitlines() if DIAGNOSTIC.search(line)]
    if diagnostics:
        errors.append("Engine emitted SCRIPT ERROR/ERROR/WARNING; see engine.log")
    errors.extend(validate_json(name, evidence))
    return {"check": name, "command": argv, "evidence_dir": str(evidence),
            "log": str(log), "returncode": returncode, "timed_out": timed_out,
            "wall_seconds": round(time.monotonic() - started, 3),
            "diagnostics": diagnostics, "failures": errors, "passed": not errors}


def source_hashes() -> dict[str, str]:
    paths = {PROJECT / "project.godot", PROJECT / "tools/godot.sh", Path(__file__).resolve()}
    paths.update(PROJECT / "tools" / script for _, script, _ in CHECKS)
    for folder, suffix in (("scenes", ".tscn"), ("scripts", ".gd"), ("resources", ".tres")):
        paths.update((PROJECT / folder).rglob(f"*{suffix}"))
    return {str(path.relative_to(PROJECT)): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in sorted(paths)}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, default=PROJECT / "verification/grit/p19",
                        help="Parent directory for a fresh isolated run")
    parser.add_argument("--timeout", type=float, default=240,
                        help="Wall-clock timeout in seconds per check (default: 240)")
    parser.add_argument("--dry-run", action="store_true", help="Print commands without writing or launching")
    args = parser.parse_args()
    if not math.isfinite(args.timeout) or args.timeout <= 0:
        parser.error("--timeout must be finite and positive")
    run_id = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ") + "-" + uuid.uuid4().hex[:8]
    run_dir = args.output_dir.expanduser().resolve() / run_id
    if args.dry_run:
        for name, script, _ in CHECKS:
            print(shlex.join(command(script, run_dir / name)))
        return 0
    run_dir.mkdir(parents=True)
    before = source_hashes()
    results = []
    for name, script, marker in CHECKS:
        print(f"Running {name} (headless)...", flush=True)
        result = run_check(name, script, marker, run_dir, args.timeout)
        results.append(result)
        print(f"{name}: {'PASS' if result['passed'] else 'FAIL'}", flush=True)
        for error in result["failures"]:
            print(f"  {error}", flush=True)
    after = source_hashes()
    failures = [f"{result['check']}: {error}" for result in results for error in result["failures"]]
    if before != after:
        failures.append("Checked source changed during integration gate; rerun final source")
    report = {"passed": not failures, "failures": failures, "checks": results,
              "source_sha256": before, "source_unchanged": before == after,
              "scope": "Headless automated route, normal combat/navigation and session integration. Bot traversal is not human level-duration acceptance."}
    summary = run_dir / "summary.json"
    summary.write_text(json.dumps(report, indent=2) + "\n")
    print(f"Evidence: {summary}")
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
