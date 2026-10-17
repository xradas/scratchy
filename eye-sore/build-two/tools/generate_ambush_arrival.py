#!/usr/bin/env python3
"""Rebuild the original dry Pale Ward ambush-arrival cue (no external samples)."""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 48000
DURATION = 0.65
SEED = 211024
OUT = Path(__file__).resolve().parents[1] / "assets/audio/ambush-v20/source-wav/arrival.wav"


def main() -> None:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    rng = random.Random(SEED)
    samples = []
    low_noise = 0.0
    phase = 0.0
    for index in range(int(RATE * DURATION)):
        t = index / RATE
        # Three dry, abrupt electrical tears behind a falling, inharmonic growl.
        noise = rng.uniform(-1.0, 1.0)
        low_noise = 0.83 * low_noise + 0.17 * noise
        pulse = 0.0
        for onset, weight in ((0.0, 1.0), (0.125, 0.7), (0.26, 0.48)):
            if onset <= t < onset + 0.075:
                pulse += weight * math.exp(-40.0 * (t - onset))
        freq = 150.0 - 100.0 * t / DURATION
        phase += 2.0 * math.pi * freq / RATE
        growl = (math.sin(phase) + 0.35 * math.sin(phase * 2.37)) * (1.0 - t / DURATION) ** 1.7
        rasp = (noise - low_noise) * pulse * 0.66
        body = low_noise * (0.32 + pulse * 0.30) * (1.0 - t / DURATION) ** 1.35
        value = (growl * 0.37 + rasp + body) * min(1.0, t / 0.008)
        samples.append(max(-1.0, min(1.0, value)))
    peak = max(abs(value) for value in samples)
    with wave.open(str(OUT), "wb") as audio:
        audio.setnchannels(1)
        audio.setsampwidth(2)
        audio.setframerate(RATE)
        audio.writeframes(b"".join(struct.pack("<h", round(value / peak * 23500)) for value in samples))


if __name__ == "__main__":
    main()
