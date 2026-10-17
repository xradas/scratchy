#!/usr/bin/env python3
"""Rebuild original Pale Ward door cues and CC0-derived creature calls.

Run from the Godot project root. Existing demonic-v1 voices are preserved.
No reverb, delay, or wet source is used.
"""

import hashlib
import json
import math
import random
import struct
import subprocess
import tempfile
import wave
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/audio/ward-v19"
OUT.mkdir(parents=True, exist_ok=True)
SAMPLE_RATE = 48000
SEED = 19017


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def encode(source: Path, output: Path, filters: str) -> None:
    subprocess.run(
        ["ffmpeg", "-y", "-hide_banner", "-loglevel", "error", "-i", str(source),
         "-af", filters, "-ac", "1", "-ar", str(SAMPLE_RATE), "-c:a", "libvorbis",
         "-q:a", "5", str(output)],
        check=True,
    )


def door_wave(path: Path, opening: bool) -> None:
    rng = random.Random(SEED + (0 if opening else 1))
    duration = 0.78 if opening else 0.69
    count = int(duration * SAMPLE_RATE)
    samples = []
    filtered_noise = 0.0
    for i in range(count):
        t = i / SAMPLE_RATE
        phase = t / duration
        fade = min(1.0, t / 0.02, (duration - t) / 0.065)
        # Actuator motor rises or falls in pitch as the heavy shutter travels.
        motor_hz = (74 + 46 * phase) if opening else (126 - 54 * phase)
        motor = math.sin(2 * math.pi * (motor_hz * t + 5 * phase * phase))
        motor += 0.43 * math.sin(2 * math.pi * (2.06 * motor_hz * t))
        filtered_noise = 0.81 * filtered_noise + 0.19 * rng.uniform(-1, 1)
        grind = filtered_noise * (0.30 + 0.24 * math.sin(2 * math.pi * 24 * t) ** 2)
        clang_time = 0.06 if opening else duration - 0.14
        clang_age = t - clang_time
        clang = 0.0
        if clang_age >= 0:
            clang = math.exp(-clang_age * 23) * (
                math.sin(2 * math.pi * 418 * clang_age) +
                0.6 * math.sin(2 * math.pi * 735 * clang_age)
            )
        samples.append(max(-1, min(1, fade * (0.27 * motor + 0.18 * grind + 0.19 * clang))))
    with wave.open(str(path), "wb") as file:
        file.setnchannels(1)
        file.setsampwidth(2)
        file.setframerate(SAMPLE_RATE)
        file.writeframes(struct.pack("<" + "h" * count, *(int(s * 32767) for s in samples)))


def main() -> None:
    sources = {
        "unsealed": ROOT / "assets/audio/demonic-v1/unsealed_attack_warning.ogg",
        "vessel": ROOT / "assets/audio/demonic-v1/vessel_attack_warning.ogg",
    }
    commands = {}
    with tempfile.TemporaryDirectory() as temp:
        for motion in ("open", "close"):
            source = Path(temp) / f"door_{motion}.wav"
            door_wave(source, motion == "open")
            output = OUT / f"door_{motion}.ogg"
            encode(source, output, "highpass=f=55,lowpass=f=7500,alimiter=limit=0.78")
            commands[output.name] = {"source": "original deterministic synthesis", "seed": SEED, "sha256": sha(output)}
    # Alert calls use their own short contours rather than the attack warning.
    variants = {
        "unsealed_detect": ("unsealed", "atrim=0:0.34,asetrate=48000*0.86,aresample=48000,atempo=1.13,highpass=f=72,lowpass=f=4400,afade=t=in:st=0:d=0.012,afade=t=out:st=0.31:d=0.07"),
        "vessel_detect": ("vessel", "atrim=0:0.42,asetrate=48000*0.74,aresample=48000,atempo=1.23,highpass=f=65,lowpass=f=2900,afade=t=in:st=0:d=0.012,afade=t=out:st=0.37:d=0.08"),
        "infected_scientist_detect": ("unsealed", "atrim=0:0.30,asetrate=48000*1.12,aresample=48000,atempo=0.90,highpass=f=170,lowpass=f=5500,afade=t=in:st=0:d=0.012,afade=t=out:st=0.25:d=0.07"),
        "infected_security_detect": ("vessel", "atrim=0:0.34,asetrate=48000*0.92,aresample=48000,atempo=1.09,highpass=f=100,lowpass=f=3500,afade=t=in:st=0:d=0.012,afade=t=out:st=0.30:d=0.07"),
    }
    for kind, donor, shift, cutoff in (
        ("infected_scientist", "unsealed", 1.15, 5100),
        ("infected_security", "vessel", 0.83, 3100),
    ):
        for action in ("attack_warning", "hurt", "death"):
            source = ROOT / f"assets/audio/demonic-v1/{donor}_{action}.ogg"
            output = OUT / f"{kind}_{action}.ogg"
            filters = f"asetrate=48000*{shift},aresample=48000,atempo={1/shift:.6f},highpass=f=75,lowpass=f={cutoff},alimiter=limit=0.76"
            encode(source, output, filters)
            commands[output.name] = {"source": source.relative_to(ROOT).as_posix(), "source_sha256": sha(source), "filters": filters, "sha256": sha(output)}
    for name, (donor, filters) in variants.items():
        source = sources[donor]
        output = OUT / f"{name}.ogg"
        encode(source, output, filters + ",alimiter=limit=0.76")
        commands[output.name] = {"source": source.relative_to(ROOT).as_posix(), "source_sha256": sha(source), "filters": filters + ",alimiter=limit=0.76", "sha256": sha(output)}
    for kind, shift in (("health", 1.30), ("armor", 0.82)):
        source = ROOT / f"assets/audio/pickups-v6/pickup_{kind}.ogg"
        output = OUT / f"overdrive_{kind}.ogg"
        filters = f"asetrate=48000*{shift},aresample=48000,atempo={1/shift:.6f},highpass=f=130,alimiter=limit=0.76"
        encode(source, output, filters)
        commands[output.name] = {"source": source.relative_to(ROOT).as_posix(), "source_sha256": sha(source), "filters": filters, "sha256": sha(output)}
    ledger = {
        "purpose": "Pale Ward distinct dry enemy calls and heavy shutter movement",
        "license": "Door cues: original procedural synthesis. Creature derivatives: CC0 HaelDB performances documented in concepts/audio-v4/manifest.json; demonic-v1 intermediary unchanged.",
        "creative_notes": "No reverberation or wet layers. Scientist calls are tense and wiry; guard calls are lower and more constricted; Unsealed and Vessel retain their original attack, hurt and death identity.",
        "outputs": commands,
    }
    (OUT / "provenance.json").write_text(json.dumps(ledger, indent=2) + "\n")


if __name__ == "__main__":
    main()
