#!/usr/bin/env python3
"""Independent checks for the authored v17 soundtrack and its active routing.

Requires ffmpeg, ffprobe and numpy. Run after composing, and pass --exported
after Linux export to verify that licensed legacy cue names were not packed.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import subprocess
from pathlib import Path

import numpy as np


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "assets/audio/music/original-v17/manifest.json"
CAMPAIGN = ROOT / "resources/campaign/catalog.json"
STAGES = ROOT / "resources/stages/catalog.json"
MAIN = ROOT / "scripts/main.gd"
PROFILE = ROOT / "resources/combat_audio.tres"
EXPECTED_IDS = {
    "menu",
    "pale_ward_01", "pale_ward_02", "pale_ward_03",
    "ash_citadel_01", "ash_citadel_02", "ash_citadel_03",
    "occupied_line_01", "occupied_line_02", "occupied_line_03",
}
LEGACY_NAMES = (
    "menu_abelian.ogg",
    "level_music_biotech_candidate.ogg",
    "level_music_fortress_candidate.ogg",
)


def probe(path: Path) -> dict:
    completed = subprocess.run(
        ["ffprobe", "-v", "error", "-select_streams", "a:0",
         "-show_entries", "stream=codec_name,sample_rate,channels,duration",
         "-of", "json", str(path)],
        check=True, capture_output=True, text=True,
    )
    streams = json.loads(completed.stdout).get("streams", [])
    if len(streams) != 1:
        raise ValueError(f"expected one audio stream, found {len(streams)}")
    return streams[0]


def decode(path: Path) -> np.ndarray:
    completed = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", str(path), "-f", "f32le",
         "-acodec", "pcm_f32le", "-ac", "2", "-ar", "48000", "-"],
        check=True, capture_output=True,
    )
    samples = np.frombuffer(completed.stdout, dtype="<f4")
    if samples.size % 2:
        raise ValueError("decoded sample count is not stereo")
    return samples.reshape(-1, 2)


def measure_loudness(path: Path) -> dict:
    """Use FFmpeg's R128 analysis; no normalization is written to disk."""
    completed = subprocess.run(
        ["ffmpeg", "-hide_banner", "-nostats", "-i", str(path),
         "-af", "loudnorm=I=-18:TP=-2:LRA=11:print_format=json",
         "-f", "null", "-"],
        check=True, capture_output=True, text=True,
    )
    matches = re.findall(r"\{\s*\"input_i\".*?\}", completed.stderr, re.S)
    if not matches:
        raise ValueError("ffmpeg loudnorm did not return R128 values")
    values = json.loads(matches[-1])
    return {
        "integrated_lufs": float(values["input_i"]),
        "true_peak_dbtp": float(values["input_tp"]),
        "loudness_range_lu": float(values["input_lra"]),
    }


def characteristics(stereo: np.ndarray) -> tuple[dict, np.ndarray]:
    mono = stereo.mean(axis=1)
    abs_peak = float(np.max(np.abs(stereo)))
    rms = float(np.sqrt(np.mean(stereo.astype(np.float64) ** 2)))
    # This is an RMS-derived check level, not an EBU R128 LUFS measurement.
    rms_dbfs = 20 * math.log10(max(rms, 1e-12))
    left = stereo[:, 0].astype(np.float64)
    right = stereo[:, 1].astype(np.float64)
    stereo_difference = float(np.sqrt(np.mean((left - right) ** 2)))
    block = 24000  # half-second musical activity windows
    windows = [mono[i:i + block] for i in range(0, len(mono), block)]
    block_rms = np.array([
        float(np.sqrt(np.mean(w.astype(np.float64) ** 2))) for w in windows
    ])
    active = float(np.mean(block_rms > 0.015))
    dynamic_db = float(
        20 * math.log10(max(float(np.percentile(block_rms, 90)), 1e-12)
                        / max(float(np.percentile(block_rms, 10)), 1e-12))
    )
    # Downsample for a compact broad-band timbre fingerprint.
    down = mono[::8]
    freqs = np.fft.rfftfreq(4096, d=8 / 48000)
    low = mid = high = 0.0
    centroids = []
    for i in range(0, len(down) - 4096, 4096):
        spectrum = np.abs(np.fft.rfft(down[i:i + 4096] * np.hanning(4096)))
        power = spectrum ** 2
        total = float(power.sum())
        if total < 1e-12:
            continue
        low += float(power[freqs < 160].sum())
        mid += float(power[(freqs >= 160) & (freqs < 2500)].sum())
        high += float(power[freqs >= 2500].sum())
        centroids.append(float((freqs * power).sum() / total))
    total = low + mid + high
    metrics = {
        "decoded_seconds": round(len(stereo) / 48000, 3),
        "sample_peak": round(abs_peak, 5),
        "peak_dbfs": round(20 * math.log10(max(abs_peak, 1e-12)), 2),
        "rms": round(rms, 5),
        "rms_dbfs": round(rms_dbfs, 2),
        "crest_db": round(20 * math.log10(max(abs_peak, 1e-12) / max(rms, 1e-12)), 2),
        "stereo_difference_rms": round(stereo_difference, 5),
        "start_end_jump": round(float(np.max(np.abs(stereo[0] - stereo[-1]))), 5),
        "activity_fraction": round(active, 3),
        "half_second_dynamic_db": round(dynamic_db, 2),
        "spectral_centroid_hz": round(float(np.median(centroids)), 1),
        "low_band_fraction": round(low / total, 3),
        "mid_band_fraction": round(mid / total, 3),
        "high_band_fraction": round(high / total, 3),
    }
    # 0.5 s envelope shape can catch copies with a different EQ/transpose.
    envelope = block_rms / max(float(np.linalg.norm(block_rms)), 1e-12)
    return metrics, envelope


def check_export(path: Path) -> dict:
    with path.open("rb") as file:
        data = file.read()
    # An archive provenance JSON may mention a retired cue by name. Godot's
    # packed import markers identify an actual audio resource in the export.
    packed = [name for name in LEGACY_NAMES if any(marker in data for marker in (
        (".godot/imported/" + name + "-").encode(),
        ("assets/audio/music/" + name + ".import").encode(),
    ))]
    mentions = [name for name in LEGACY_NAMES if name.encode() in data]
    return {"path": str(path), "legacy_packed_resources": packed,
            "archival_name_mentions": mentions, "bytes": len(data)}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--exported", type=Path, help="exported Linux ELF containing the PCK")
    parser.add_argument("--report", type=Path,
                        default=ROOT / "verification/music-v17/report.json")
    args = parser.parse_args()
    errors: list[str] = []
    warnings: list[str] = []
    result: dict = {"errors": errors, "warnings": warnings, "cues": {}, "pairs": []}
    manifest = json.loads(MANIFEST.read_text())
    campaign = json.loads(CAMPAIGN.read_text())
    stages = json.loads(STAGES.read_text())
    cues = manifest.get("cues", [])
    ids = [cue.get("id") for cue in cues]
    if len(cues) != 10 or set(ids) != EXPECTED_IDS or len(set(ids)) != len(ids):
        errors.append(f"expected 10 unique menu/campaign IDs; found {ids}")
    if manifest.get("sample_rate") != 48000 or manifest.get("channels") != 2:
        errors.append("manifest must declare 48 kHz stereo")
    provenance = " ".join(str(manifest.get(k, "")) for k in ("creator", "license", "source"))
    if not all(s in provenance.lower() for s in ("original", "no external")):
        errors.append("manifest lacks explicit original/no-external provenance")
    catalog_ids = {}
    for chapter in campaign.get("chapters", []):
        for level in chapter.get("levels", []):
            catalog_ids[level["id"]] = level.get("music")
    if set(catalog_ids) != EXPECTED_IDS - {"menu"}:
        errors.append("campaign catalog does not define exactly the nine expected levels")
    active_text = MAIN.read_text() + PROFILE.read_text() + STAGES.read_text() + CAMPAIGN.read_text()
    for legacy in LEGACY_NAMES:
        if legacy in active_text:
            errors.append(f"active runtime config still references licensed legacy cue {legacy}")
    paths_seen = []
    hashes_seen = []
    styles_seen = []
    envelopes = {}
    for cue in cues:
        cue_id = cue.get("id", "<missing>")
        path_string = cue.get("file", "")
        if not path_string.startswith("assets/audio/music/original-v17/"):
            errors.append(f"{cue_id}: unexpected soundtrack path {path_string}")
            continue
        path = ROOT / path_string
        paths_seen.append(path_string)
        styles_seen.append(cue.get("style"))
        if cue_id != "menu" and catalog_ids.get(cue_id) != "res://" + path_string:
            errors.append(f"{cue_id}: campaign catalog points elsewhere")
        if not path.is_file():
            errors.append(f"{cue_id}: missing {path}")
            continue
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        hashes_seen.append(digest)
        if digest != cue.get("sha256"):
            errors.append(f"{cue_id}: SHA-256 differs from manifest")
        try:
            stream = probe(path)
            if (stream.get("codec_name") != "vorbis" or
                    int(stream.get("sample_rate", 0)) != 48000 or
                    int(stream.get("channels", 0)) != 2):
                errors.append(f"{cue_id}: expected 48 kHz stereo Vorbis, got {stream}")
            audio = decode(path)
            metrics, envelope = characteristics(audio)
            metrics.update(measure_loudness(path))
            metrics["source_pcm_sample_peak_manifest"] = cue.get("sample_peak")
            envelopes[cue_id] = envelope
            metrics.update({"file": path_string, "sha256": digest,
                            "style": cue.get("style"), "title": cue.get("title")})
            result["cues"][cue_id] = metrics
            if not 40 <= metrics["decoded_seconds"] <= 90:
                errors.append(f"{cue_id}: duration outside 40–90 seconds")
            if abs(metrics["decoded_seconds"] - float(cue.get("seconds", 0))) > 0.12:
                errors.append(f"{cue_id}: duration disagrees with manifest")
            if metrics["sample_peak"] > 0.9:
                errors.append(f"{cue_id}: unsafe sample peak {metrics['sample_peak']}")
            if metrics["sample_peak"] < 0.15:
                warnings.append(f"{cue_id}: quiet peak; inspect playback level")
            if metrics["rms_dbfs"] < -32 or metrics["rms_dbfs"] > -12:
                warnings.append(f"{cue_id}: RMS level may be out of useful range")
            if metrics["integrated_lufs"] < -32 or metrics["integrated_lufs"] > -12:
                warnings.append(f"{cue_id}: R128 loudness may be out of useful range")
            if metrics["start_end_jump"] > 0.025:
                warnings.append(f"{cue_id}: loop boundary sample jump {metrics['start_end_jump']}")
            # The manifest records the source PCM sample peak. Vorbis may
            # overshoot during decoding; the decoded peak is checked above.
            if not 0 < float(cue.get("sample_peak", 0)) <= 0.9:
                errors.append(f"{cue_id}: unsafe or missing source PCM peak")
        except (subprocess.CalledProcessError, ValueError, KeyError) as exc:
            errors.append(f"{cue_id}: cannot inspect audio: {exc}")
    if len(set(paths_seen)) != 10 or len(set(hashes_seen)) != 10:
        errors.append("soundtrack paths or encoded contents are duplicated")
    if len(set(styles_seen)) < 8:
        warnings.append("fewer than eight declared style families")
    for left_id, left in envelopes.items():
        for right_id, right in envelopes.items():
            if left_id >= right_id:
                continue
            size = min(len(left), len(right))
            if size < 10:
                continue
            similarity = float(np.dot(left[:size], right[:size]) /
                               max(np.linalg.norm(left[:size]) * np.linalg.norm(right[:size]), 1e-12))
            if similarity > 0.975:
                warnings.append(f"{left_id} and {right_id}: similar energy envelopes ({similarity:.3f}); audition")
            result["pairs"].append({"a": left_id, "b": right_id,
                                    "energy_envelope_similarity": round(similarity, 3)})
    if args.exported:
        if not args.exported.is_file():
            errors.append(f"exported executable missing: {args.exported}")
        else:
            export_result = check_export(args.exported)
            result["export"] = export_result
            for legacy in export_result["legacy_packed_resources"]:
                errors.append(f"export still packs licensed legacy cue: {legacy}")
    result["status"] = "FAIL" if errors else "PASS"
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(result, indent=2) + "\n")
    print(f"music v17: {result['status']} — {len(result['cues'])} cues, "
          f"{len(errors)} errors, {len(warnings)} warnings")
    for issue in errors:
        print("ERROR:", issue)
    for issue in warnings:
        print("WARN:", issue)
    print(args.report)
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
