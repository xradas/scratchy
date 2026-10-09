#!/usr/bin/env python3
"""Check recording structure and decoded stereo audio; never modify media.

Requires ffprobe and ffmpeg on PATH, but no third-party Python packages.
Example: python3 tools/check_game_recording.py --video capture.mp4 \
    --original capture.avi --route-report playtest.json --report evidence.json
Numerical audio evidence cannot establish listening quality or scene coverage.
"""

import argparse
import array
import hashlib
import json
import math
from pathlib import Path
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from fractions import Fraction


SILENCE_RMS = 1e-7
STEREO_RELATIVE_RMS = 1e-5


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def numeric(value):
    try:
        number = float(value)
        return number if math.isfinite(number) else None
    except (TypeError, ValueError):
        return None


def rate(value):
    try:
        return float(Fraction(value))
    except (TypeError, ValueError, ZeroDivisionError):
        return None


def decode_audio(path, stream_index, channels, sample_rate, pcm_bits=0):
    # No -ac, -ar, filters, or gain: decode the native channels and native rate.
    command = ["ffmpeg", "-nostdin", "-v", "error", "-i", str(path),
               "-map", f"0:{stream_index}", "-vn", "-sn", "-dn",
               "-c:a", "pcm_f32le", "-f", "f32le", "pipe:1"]
    frames = nonfinite = over_full_scale = pcm_rail_samples = 0
    sums = [0.0] * channels
    squares = [0.0] * channels
    peaks = [0.0] * channels
    difference_square = cross = 0.0
    # Integer PCM rails are asymmetric; catching -1 and +32767/32768 matters.
    positive_rail = 1.0 - 2.0 ** (1 - pcm_bits) if pcm_bits else 1.0
    with tempfile.TemporaryFile() as errors:
        process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=errors)
        pending = b""
        try:
            while True:
                chunk = process.stdout.read(256 * 1024)
                if not chunk:
                    break
                pending += chunk
                usable = len(pending) // (4 * channels) * (4 * channels)
                samples = array.array("f")
                samples.frombytes(pending[:usable])
                pending = pending[usable:]
                if sys.byteorder != "little":
                    samples.byteswap()
                for offset in range(0, len(samples), channels):
                    frame = samples[offset:offset + channels]
                    frames += 1
                    finite = True
                    for channel, value in enumerate(frame):
                        if not math.isfinite(value):
                            nonfinite += 1
                            finite = False
                            continue
                        sums[channel] += value
                        squares[channel] += value * value
                        peaks[channel] = max(peaks[channel], abs(value))
                        if abs(value) > 1.0 + 1e-6:
                            over_full_scale += 1
                        if pcm_bits and (value <= -1.0 or value >= positive_rail):
                            pcm_rail_samples += 1
                    if channels == 2 and finite:
                        difference_square += (frame[0] - frame[1]) ** 2
                        cross += frame[0] * frame[1]
        finally:
            process.stdout.close()
            code = process.wait()
        errors.seek(0)
        error = errors.read().decode("utf-8", errors="replace")
    if code or pending:
        raise RuntimeError(f"Audio decode failed ({code}, trailing bytes {len(pending)}): {error}")
    rms = [math.sqrt(value / frames) if frames else 0.0 for value in squares]
    difference_rms = math.sqrt(difference_square / frames) if frames else 0.0
    correlation = None
    if channels == 2 and frames and not nonfinite:
        covariance = cross - sums[0] * sums[1] / frames
        variance_product = ((squares[0] - sums[0] ** 2 / frames)
                            * (squares[1] - sums[1] ** 2 / frames))
        if variance_product > 0:
            correlation = max(-1.0, min(1.0, covariance / math.sqrt(variance_product)))
    stereo_threshold = max(SILENCE_RMS, max(rms, default=0.0) * STEREO_RELATIVE_RMS)
    return {
        "decode_command": command,
        "decoded_frames": frames,
        "decoded_duration_seconds": frames / sample_rate,
        "peak_per_channel": peaks,
        "rms_per_channel": rms,
        "difference_rms": difference_rms,
        "difference_threshold": stereo_threshold,
        "stereo_difference_nonzero": channels == 2 and difference_rms > stereo_threshold,
        "correlation": correlation,
        "nonfinite_sample_count": nonfinite,
        "over_full_scale_sample_count": over_full_scale,
        "pcm_rail_sample_count": pcm_rail_samples,
        "pcm_positive_rail": positive_rail if pcm_bits else None,
        "nonzero_each_channel": bool(frames) and all(value > SILENCE_RMS for value in rms),
    }


def check_file(path, original=False):
    initial_stat = path.stat()
    command = ["ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", str(path)]
    probe = json.loads(subprocess.check_output(command, text=True))
    streams = probe.get("streams", [])
    audio_streams = [stream for stream in streams if stream.get("codec_type") == "audio"]
    video_streams = [stream for stream in streams if stream.get("codec_type") == "video"]
    failures = []
    if len(audio_streams) != 1 or len(video_streams) != 1:
        failures.append("Expected exactly one audio and one video stream")
    audio = audio_streams[0] if audio_streams else {}
    video = video_streams[0] if video_streams else {}
    audio_info = {key: audio.get(key) for key in ("index", "codec_name", "sample_fmt", "sample_rate", "channels", "channel_layout", "bit_rate", "bits_per_sample", "duration", "start_time")}
    video_info = {key: video.get(key) for key in ("index", "codec_name", "width", "height", "pix_fmt", "r_frame_rate", "avg_frame_rate", "bit_rate", "duration", "nb_frames", "start_time")}
    fps = rate(video.get("avg_frame_rate")) or rate(video.get("r_frame_rate"))
    if not fps or fps <= 0:
        failures.append("Missing valid video frame rate")
    if audio.get("channels") != 2:
        failures.append("Audio is not two-channel stereo")
    if audio.get("channel_layout") not in (None, "unknown", "stereo"):
        failures.append("Audio declares a non-stereo channel layout")
    sample_rate = numeric(audio.get("sample_rate"))
    if sample_rate != 48000:
        failures.append("Audio sample rate is not 48000 Hz")
    codec = audio.get("codec_name", "")
    if original and not codec.startswith("pcm_"):
        failures.append("Original recording audio is not PCM")
    if original and probe.get("format", {}).get("format_name") != "avi":
        failures.append("Original MovieMaker recording is not an AVI container")
    result = {
        "path": str(path), "sha256": sha256(path), "size_bytes": path.stat().st_size,
        "mtime_utc": datetime.fromtimestamp(initial_stat.st_mtime, timezone.utc).isoformat(),
        "format": probe.get("format", {}).get("format_name"),
        "duration_seconds": numeric(probe.get("format", {}).get("duration")),
        "frame_rate": fps, "video": video_info, "audio": audio_info,
        "failures": failures,
    }
    if sample_rate and audio.get("channels", 0) > 0:
        bits = int(audio.get("bits_per_sample") or 0) if codec.startswith(("pcm_s", "pcm_u")) else 0
        decoded = decode_audio(path, audio["index"], audio["channels"], sample_rate, bits)
        result["decoded_audio"] = decoded
        if not decoded["nonzero_each_channel"]:
            failures.append("Decoded stream contains silence in one or both complete channels")
        if not decoded["stereo_difference_nonzero"]:
            failures.append("Decoded channels have no meaningful stereo difference (possible summed/dual mono)")
        if decoded["nonfinite_sample_count"]:
            failures.append("Decoded audio contains NaN or infinity")
        if decoded["over_full_scale_sample_count"] or decoded["pcm_rail_sample_count"]:
            failures.append("Decoded audio reaches PCM digital rails or exceeds full scale")
        video_duration = numeric(video.get("duration")) or result["duration_seconds"]
        tolerance = (1 / fps if fps else 0) + (2048 / sample_rate if codec == "aac" else 0) + 1e-6
        result["audio_video_duration_tolerance_seconds"] = tolerance
        if video_duration is None or abs(decoded["decoded_duration_seconds"] - video_duration) > tolerance:
            failures.append("Decoded audio/video durations differ beyond one frame plus codec tolerance")
        video_start = numeric(video.get("start_time")) or 0.0
        audio_start = numeric(audio.get("start_time")) or 0.0
        result["audio_video_start_delta_seconds"] = abs(audio_start - video_start)
        if abs(audio_start - video_start) > tolerance:
            failures.append("Audio/video start times differ beyond one frame plus codec tolerance")
    final_stat = path.stat()
    if (initial_stat.st_size, initial_stat.st_mtime_ns) != (final_stat.st_size, final_stat.st_mtime_ns):
        failures.append("Recording changed while validation was running; rerun after capture/encoding finishes")
    result["passed"] = not failures
    return result


def route_evidence(path):
    data = json.loads(path.read_text())
    completed = data.get("completed") is True or any(
        isinstance(record, dict) and record.get("completed") is True
        for record in data.get("records", []))
    return {"path": str(path), "sha256": sha256(path), "completed": completed,
            "failures": data.get("failures", []), "scope": data.get("scope"),
            "association": "Caller supplied this route report; media-to-route provenance is not inferred from filenames."}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--video", type=Path, help="MP4 or AVI to validate (optional for --self-test)")
    parser.add_argument("--original", type=Path, help="Original MovieMaker PCM AVI to validate and compare")
    parser.add_argument("--route-report", type=Path, help="Matching playtest/route JSON; must report completed with no failures")
    parser.add_argument("--report", type=Path, help="Write JSON here; default is stdout")
    parser.add_argument("--source-status", choices=("unverified", "old-source", "fresh-capture"), default="unverified")
    parser.add_argument("--self-test", action="store_true", help="Run numerical detector tests without media assets")
    args = parser.parse_args(argv)
    if args.self_test:
        return self_test(args.report)
    if not args.video:
        parser.error("--video is required unless --self-test is used")
    report = {
        "schema": "eyesore-recording-validation-v1",
        "checked_utc": datetime.now(timezone.utc).isoformat(),
        "source_status": args.source_status,
        "scope": "Structural and decoded numerical evidence only; no listening-quality or visual route-coverage claim.",
        "thresholds": {"silence_rms": SILENCE_RMS, "stereo_relative_rms": STEREO_RELATIVE_RMS,
                       "over_full_scale_epsilon": 1e-6, "aac_duration_allowance_samples": 2048},
        "failures": [],
    }
    try:
        report["video"] = check_file(args.video.resolve())
        report["failures"].extend("video: " + failure for failure in report["video"]["failures"])
        if args.original:
            report["original"] = check_file(args.original.resolve(), original=True)
            report["failures"].extend("original: " + failure for failure in report["original"]["failures"])
            first, second = report["video"], report["original"]
            if "mp4" not in (first["format"] or "").split(","):
                report["failures"].append("Encoded output is not an MP4 container")
            if first["video"]["codec_name"] != "h264" or first["audio"]["codec_name"] != "aac":
                report["failures"].append("Encoded output is not H.264 video with AAC audio")
            tolerance = max(1 / item["frame_rate"] for item in (first, second) if item["frame_rate"]) + 2048 / 48000 + 1e-6
            deltas = {"container": abs(first["duration_seconds"] - second["duration_seconds"]),
                      "decoded_audio": abs(first["decoded_audio"]["decoded_duration_seconds"] - second["decoded_audio"]["decoded_duration_seconds"])}
            if numeric(first["video"]["duration"]) is not None and numeric(second["video"]["duration"]) is not None:
                deltas["video_stream"] = abs(float(first["video"]["duration"]) - float(second["video"]["duration"]))
            report["duration_comparison"] = {"tolerance_seconds": tolerance, "deltas_seconds": deltas}
            if any(delta > tolerance for delta in deltas.values()):
                report["failures"].append("Original/output duration differs beyond one frame plus codec tolerance")
        if args.route_report:
            report["route_report"] = route_evidence(args.route_report.resolve())
            if not report["route_report"]["completed"] or report["route_report"]["failures"]:
                report["failures"].append("Linked route report does not establish a completed, failure-free route")
    except (OSError, subprocess.SubprocessError, ValueError, KeyError, TypeError, RuntimeError) as error:
        report["failures"].append(str(error))
    report["passed"] = not report["failures"]
    payload = json.dumps(report, indent=2, allow_nan=False) + "\n"
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(payload)
        print(f"{'PASS' if report['passed'] else 'FAIL'}: {args.report}")
    else:
        print(payload, end="")
    return 0 if report["passed"] else 1


def self_test(report_path=None):
    # Temporary raw fixtures exercise the actual ffmpeg decode and detector path.
    # They do not transcode or change any project audio/video assets.
    import wave
    import struct
    with tempfile.TemporaryDirectory(prefix="recording-validator-") as directory:
        results = []
        cases = {
            "stereo": (lambda i: (int(10000 * math.sin(i / 11)), int(9000 * math.sin(i / 13))), True, True, False),
            "dual_mono": (lambda i: (int(10000 * math.sin(i / 11)),) * 2, True, False, False),
            "silent": (lambda i: (0, 0), False, False, False),
            "silent_channel": (lambda i: (int(10000 * math.sin(i / 11)), 0), False, True, False),
            "clipped": (lambda i: (32767, -32768), True, True, True),
        }
        for name, (sample, nonzero, stereo, clipped) in cases.items():
            path = Path(directory) / (name + ".wav")
            with wave.open(str(path), "wb") as handle:
                handle.setparams((2, 2, 48000, 0, "NONE", "not compressed"))
                handle.writeframes(b"".join(struct.pack("<hh", *sample(i)) for i in range(4800)))
            result = decode_audio(path, 0, 2, 48000, 16)
            assert result["nonzero_each_channel"] == nonzero, name
            assert result["stereo_difference_nonzero"] == stereo, name
            assert bool(result["pcm_rail_sample_count"]) == clipped, name
            assert result["decoded_frames"] == 4800, name
            results.append(name)
        float_path = Path(directory) / "nonfinite.wav"
        data = struct.pack("<ffff", float("nan"), 0.25, float("inf"), -0.25)
        # WAVE_FORMAT_IEEE_FLOAT, two channels, native 48 kHz.
        fmt = struct.pack("<HHIIHH", 3, 2, 48000, 384000, 8, 32)
        float_path.write_bytes(b"RIFF" + struct.pack("<I", 36 + len(data)) + b"WAVEfmt "
                              + struct.pack("<I", 16) + fmt + b"data" + struct.pack("<I", len(data)) + data)
        result = decode_audio(float_path, 0, 2, 48000)
        assert result["nonfinite_sample_count"] == 2
        results.append("nonfinite")
    payload = json.dumps({"passed": True, "self_tests": results,
                          "scope": "Temporary synthetic numerical detector fixtures, not gameplay evidence."}, indent=2) + "\n"
    if report_path:
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report_path.write_text(payload)
    print(payload, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
