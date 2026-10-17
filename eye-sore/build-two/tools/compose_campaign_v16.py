#!/usr/bin/env python3
"""Render nine original, deterministic campaign cues from written note/drum patterns.

All sound is synthesized here.  The licensed Abelian menu cue is untouched.
Requires numpy and ffmpeg; no samples or previous level recordings are inputs.
"""
from __future__ import annotations

import hashlib
import json
import math
import pathlib
import subprocess
import tempfile
import wave

import numpy as np


ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/audio/music/original-v16"
RATE = 48000
STEPS = 16
BARS = 24

# Relative semitones at sixteenth-note positions.  The motifs, bass answers,
# drum accents, modes, tempos and harmonic beds are authored for each setting.
SCORES = [
    ("pale_ward_01", "Intake / cold triage", 136, 40, [0, -1, 0, 3, 0, -1, 5, 3, 0, -1, 0, -5, 3, 0, -1, -4], "1010101010101010", "0000100000001000"),
    ("pale_ward_02", "Containment / pressure pulse", 150, 42, [0, 0, -2, 0, 6, 0, -2, 3, 0, 0, -2, 0, 5, 3, -2, -5], "1001001010011010", "0000100010001000"),
    ("pale_ward_03", "Breach / failing anchors", 164, 37, [0, -1, 0, 7, -1, 0, 5, 3, 0, -1, -5, 0, 7, 5, 3, -1], "1011101010111010", "0000100000001010"),
    ("ash_citadel_01", "Ash Approach / siege march", 144, 38, [0, 0, 3, 0, 5, 0, 3, -2, 0, 0, 7, 5, 3, 0, -2, -5], "1000100010101000", "0000100000001000"),
    ("ash_citadel_02", "Furnace Choir / iron litany", 158, 36, [0, 1, 0, 4, 0, 1, 7, 4, 0, -2, 1, 0, 8, 7, 4, 1], "1010100010101010", "0000100000101000"),
    ("ash_citadel_03", "Black Reliquary / vault procession", 132, 43, [0, -2, 3, 0, 5, 3, -2, -5, 0, -2, 7, 5, 3, 0, -2, -7], "1000101010001010", "0000100000001000"),
    ("occupied_line_01", "Dead Platform / broken signal", 152, 35, [0, 0, 6, 0, -2, 3, 0, 6, 0, -5, 0, 3, 6, 0, -2, 3], "1001010010100101", "0000100000101000"),
    ("occupied_line_02", "Civic Lockdown / alarm grid", 160, 42, [0, -1, 0, 6, 0, -1, 3, 0, 8, 6, 0, -1, 3, 0, -5, -1], "1010010110100101", "0000100010001010"),
    ("occupied_line_03", "Occupation Engine / turbine drive", 174, 40, [0, 0, 1, 0, 6, 0, 1, 8, 0, -2, 1, 0, 6, 8, 1, -2], "1011101110111011", "0000101000001010"),
]


def note(midi: int) -> float:
    return 440.0 * 2.0 ** ((midi - 69) / 12.0)


def sha(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def add(buf: np.ndarray, start: int, signal: np.ndarray, gain: float, pan: float = 0.0) -> None:
    end = min(start + len(signal), len(buf))
    if start >= end:
        return
    chunk = signal[:end-start] * gain
    buf[start:end, 0] += chunk * math.sqrt((1.0 - pan) * 0.5)
    buf[start:end, 1] += chunk * math.sqrt((1.0 + pan) * 0.5)


def guitar(freq: float, seconds: float, variant: int) -> np.ndarray:
    n = int(seconds * RATE)
    t = np.arange(n, dtype=np.float32) / RATE
    # Two detuned, harmonically band-limited oscillators through a dry drive.
    x = np.zeros(n, np.float32)
    for harmonic, weight in ((1, 1.0), (2, .52), (3, .34), (4, .20), (5, .12), (6, .08)):
        x += weight * np.sin(2 * np.pi * freq * harmonic * t)
        x += weight * .42 * np.sin(2 * np.pi * freq * 1.004 * harmonic * t + variant * .37)
    x = np.tanh(x * 1.6)
    envelope = (1 - np.exp(-t * 180)) * np.exp(-t * (2.1 if variant else 3.3))
    envelope *= np.minimum(1.0, (seconds-t) * 35)
    return x * envelope


def bass(freq: float, seconds: float) -> np.ndarray:
    n = int(seconds * RATE)
    t = np.arange(n, dtype=np.float32) / RATE
    phase = 2 * np.pi * freq * t
    x = np.sin(phase) + .26 * np.sin(2 * phase) + .13 * np.sin(3 * phase)
    return np.tanh(x * 1.7) * (1 - np.exp(-t * 100)) * np.exp(-t * 2.5) * np.minimum(1.0, (seconds-t) * 30)


def kick(rng: np.random.Generator) -> np.ndarray:
    n = int(.40 * RATE)
    t = np.arange(n, dtype=np.float32) / RATE
    phase = 2 * np.pi * (54*t + 74*(1-np.exp(-t*32))/32)
    return (np.sin(phase) + .12 * rng.standard_normal(n)) * np.exp(-t*16)


def snare(rng: np.random.Generator) -> np.ndarray:
    n = int(.29 * RATE)
    t = np.arange(n, dtype=np.float32) / RATE
    noise = rng.standard_normal(n).astype(np.float32)
    high = noise - np.convolve(noise, np.ones(11, np.float32)/11, "same")
    return (high*.62 + np.sin(2*np.pi*188*t)*.22) * np.exp(-t*19)


def hat(rng: np.random.Generator) -> np.ndarray:
    n = int(.095 * RATE)
    t = np.arange(n, dtype=np.float32) / RATE
    noise = rng.standard_normal(n).astype(np.float32)
    return (noise - np.convolve(noise, np.ones(7, np.float32)/7, "same")) * np.exp(-t*65)


def render(score: tuple, index: int) -> dict:
    name, description, bpm, root, motif, kicks, snares = score
    beat = 60.0 / bpm
    step = beat / 4
    duration = BARS * 4 * beat
    length = int(duration * RATE)
    mix = np.zeros((length, 2), dtype=np.float32)
    rng = np.random.default_rng(1616 + index)
    k, s, h = kick(rng), snare(rng), hat(rng)
    # A separately written eight-bar arc repeats with instrumentation changes,
    # so the 24-bar loop has sparse, full and breakdown sections.
    for bar in range(BARS):
        section = bar // 8
        chord = [0, -2, -5, -7, 0, 3, -2, -5][bar % 8]
        density = .67 if section == 0 else (1.0 if section == 1 else .85)
        for pos in range(STEPS):
            time = (bar * STEPS + pos) * step
            at = round(time * RATE)
            if kicks[pos] == "1" or (section == 1 and pos in (2, 10)):
                add(mix, at, k, .28 * density)
            if snares[pos] == "1":
                add(mix, at, s, .18 * density, -.07)
            if pos % (2 if section != 2 else 4) == 0:
                add(mix, at, h, .055 * density, .28 if pos % 4 else -.28)
            pitch = motif[(pos + (bar % 4) * 4) % STEPS]
            if pos % 2 == 0 or (section == 1 and pos in (3, 7, 11, 15)):
                freq = note(root + chord + pitch)
                part = guitar(freq, min(step * 1.55, .31), section % 2)
                add(mix, at, part, .13 * density, -.55)
                add(mix, at + int(.010 * RATE), part, .11 * density, .55)
            if pos % 4 == 0:
                lower = note(root - 12 + chord + (pitch if pos == 12 else 0))
                add(mix, at, bass(lower, min(beat*.9, .42)), .24 * density)
        # Dissonant industrial warning bed, changing chords per room.
        if bar % 2 == 0:
            n = min(int(beat * 7.6 * RATE), length - round(bar * 4 * beat * RATE))
            t = np.arange(n, dtype=np.float32) / RATE
            f = note(root + chord + 12)
            pad = (np.sin(2*np.pi*f*t) + .47*np.sin(2*np.pi*f*1.009*t) + .32*np.sin(2*np.pi*note(root+chord+18)*t))
            pad *= (1-np.exp(-t*1.7))*np.minimum(1, (n/RATE-t)*.8) * .036
            add(mix, round(bar*4*beat*RATE), pad, .55, -.22 if bar % 4 else .22)
    # Gentle boundary crossfade removes digital clicks without reordering beats.
    fade = int(.12 * RATE)
    ramp = np.linspace(0, 1, fade, dtype=np.float32)[:, None]
    mix[:fade] *= ramp
    mix[-fade:] *= ramp[::-1]
    peak = float(np.max(np.abs(mix)))
    mix *= .72 / max(peak, .72)
    OUT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="eyesore-composition-") as temp:
        wav = pathlib.Path(temp) / "mix.wav"
        with wave.open(str(wav), "wb") as output:
            output.setnchannels(2)
            output.setsampwidth(2)
            output.setframerate(RATE)
            output.writeframes((np.clip(mix, -1, 1)*32767).astype("<i2").tobytes())
        ogg = OUT / (name + ".ogg")
        subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(wav), "-c:a", "libvorbis", "-q:a", "5", str(ogg)], check=True)
    return {"level": name, "title": description, "file": str(ogg.relative_to(ROOT)), "sha256": sha(ogg), "seconds": round(duration, 3), "bpm": bpm, "root_midi": root, "motif_semitones": motif, "kick_pattern": kicks, "snare_pattern": snares, "peak_sample": round(float(np.max(np.abs(mix))), 4)}


def main() -> None:
    cues = [render(score, n) for n, score in enumerate(SCORES)]
    manifest = {"project": "Eyesore", "version": 16, "creator": "Eyesore project / Codex composition", "license": "original project composition", "sources": "No external samples, recordings or previous music are inputs; deterministic oscillator/noise synthesis and written patterns in tools/compose_campaign_v16.py.", "render_tools": {"python": "3.14", "numpy": np.__version__, "ffmpeg": subprocess.check_output(["ffmpeg", "-version"], text=True).splitlines()[0]}, "scope": "Nine provisional campaign cues, each mapped to one stage. Abelian remains menu-only. Listening approval pending.", "sample_rate": RATE, "channels": 2, "cues": cues}
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps({"status":"rendered", "count":len(cues), "minutes":round(sum(x["seconds"] for x in cues)/60,2)},indent=2))


if __name__ == "__main__":
    main()
