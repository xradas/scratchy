#!/usr/bin/env python3
"""Author and render the original v17 menu and campaign score.

Every voice is synthesized from mathematical oscillators or seeded noise here.
No external music, samples, recordings, or previous Eyesore cues are inputs.
Run with: /tmp/eyesore-music-venv/bin/python tools/compose_campaign_v17.py
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
OUT = ROOT / "assets/audio/music/original-v17"
RATE = 48_000

# Each stage has its own rhythmic vocabulary, signature voice and emotional role.
# Ambient cues intentionally leave long spaces for movement and creature warnings.
SCORES = [
    dict(id="menu", title="Threshold", style="menu", bpm=64, bars=16,
         description="Unsteady glass harmonics, low air and a distant two-note warning."),
    dict(id="pale_ward_01", title="Cold Intake", style="clinical", bpm=72, bars=16,
         description="Clinical dark ambient: heart monitor, glass and ventilation; no kit."),
    dict(id="pale_ward_02", title="Containment Pressure", style="pressure", bpm=106, bars=24,
         description="Minimal industrial pressure with an uneven mechanical heartbeat."),
    dict(id="pale_ward_03", title="Breach Circuit", style="breakbeat", bpm=150, bars=32,
         description="Distorted bass and fractured breakbeat for the Ward climax."),
    dict(id="ash_citadel_01", title="Cinder March", style="march", bpm=82, bars=20,
         description="Low ritual drums, brass calls and stone-space echoes."),
    dict(id="ash_citadel_02", title="Furnace Litany", style="furnace", bpm=68, bars=16,
         description="Furnace drone, metallic tolls and wordless synthetic choir."),
    dict(id="ash_citadel_03", title="Reliquary", style="vault", bpm=60, bars=16,
         description="Near-silent vault ambience with bells and an uneasy organ."),
    dict(id="occupied_line_01", title="Last Platform", style="transit", bpm=88, bars=20,
         description="Abandoned transit dub: distant rail clacks, sub and tape-like echoes."),
    dict(id="occupied_line_02", title="Civic Lockdown", style="electro", bpm=122, bars=24,
         description="Syncopated sequencer, security-grid pulses and sharp electronics."),
    dict(id="occupied_line_03", title="Occupation Engine", style="climax", bpm=142, bars=28,
         description="Aggressive industrial engine: double-time machinery and pitched steel."),
]


def hz(midi: float) -> float:
    return 440.0 * 2.0 ** ((midi - 69.0) / 12.0)


def put(mix: np.ndarray, at: float, source: np.ndarray, gain: float, pan: float = 0) -> None:
    start = round(at * RATE)
    if start >= len(mix) or start + len(source) <= 0:
        return
    offset = max(0, -start)
    start = max(0, start)
    end = min(len(mix), start + len(source) - offset)
    if end <= start:
        return
    data = source[offset:offset + end - start] * gain
    mix[start:end, 0] += data * math.sqrt((1 - pan) * .5)
    mix[start:end, 1] += data * math.sqrt((1 + pan) * .5)


def voice(midi: float, seconds: float, kind: str) -> np.ndarray:
    n = round(seconds * RATE)
    t = np.arange(n, dtype=np.float32) / RATE
    f = hz(midi)
    phase = 2 * np.pi * f * t
    if kind == "glass":
        x = np.sin(phase) + .36 * np.sin(phase * 2.01) + .18 * np.sin(phase * 3.91)
        decay, attack = 1.5, .015
    elif kind == "choir":
        x = (np.sin(phase * .997) + np.sin(phase * 1.003 + .8) +
             .22 * np.sin(phase * 2.0 + .4)) * .55
        decay, attack = .18, .9
    elif kind == "organ":
        x = .7 * np.sin(phase) + .28 * np.sin(2 * phase) + .16 * np.sin(3 * phase)
        decay, attack = .14, .22
    elif kind == "brass":
        x = np.tanh(1.45 * (np.sin(phase) + .36 * np.sin(2 * phase) + .23 * np.sin(3 * phase)))
        decay, attack = 1.15, .045
    elif kind == "distorted":
        x = np.tanh(3.2 * (np.sin(phase) + .27 * np.sin(2 * phase) + .12 * np.sin(4 * phase)))
        decay, attack = 3.5, .006
    elif kind == "sequence":
        x = np.tanh(2.1 * (np.sin(phase) + .24 * np.sin(3 * phase)))
        decay, attack = 5.5, .006
    elif kind == "bell":
        x = np.sin(phase) + .42 * np.sin(phase * 2.38) + .24 * np.sin(phase * 4.71)
        decay, attack = 1.7, .004
    elif kind == "sub":
        x = np.tanh(1.8 * (np.sin(phase) + .17 * np.sin(phase * 2)))
        decay, attack = 2.0, .009
    else:
        raise ValueError(kind)
    envelope = (1 - np.exp(-t / attack)) * np.exp(-t * decay)
    envelope *= np.minimum(1, np.maximum(0, (seconds - t) * 25))
    return (x * envelope).astype(np.float32)


def drone(midi: float, seconds: float, color: str, seed: int) -> np.ndarray:
    n = round(seconds * RATE)
    t = np.arange(n, dtype=np.float32) / RATE
    f = hz(midi)
    if color == "air":
        rng = np.random.default_rng(seed)
        noise = rng.standard_normal(n).astype(np.float32)
        # 3 moving comb-like slow partials create a ventilator quality.
        x = .47 * np.sin(2 * np.pi * f * t) + .2 * np.sin(2 * np.pi * f * 1.009 * t)
        x += .075 * noise * (1 + np.sin(2 * np.pi * .31 * t))
    elif color == "furnace":
        x = np.sin(2 * np.pi * f * t) + .24 * np.sin(2 * np.pi * f * 1.005 * t)
        x += .11 * np.sin(2 * np.pi * f * 3.01 * t)
    elif color == "electric":
        x = np.tanh(1.4 * (np.sin(2 * np.pi * f * t) + .2 * np.sin(2 * np.pi * f * 2.02 * t)))
        x *= .73 + .27 * np.sin(2 * np.pi * 2.5 * t)
    elif color == "stone":
        x = .75 * np.sin(2 * np.pi * f * t) + .25 * np.sin(2 * np.pi * f * 1.004 * t)
        x += .13 * np.sin(2 * np.pi * f * 1.5 * t)
    else:
        raise ValueError(color)
    fade = np.minimum(1, np.minimum(t / 1.2, (seconds - t) / 1.2))
    return (x * fade * (.75 + .25 * np.sin(2 * np.pi * .073 * t))).astype(np.float32)


def noise_hit(kind: str, rng: np.random.Generator) -> np.ndarray:
    lengths = {"tick": .075, "hat": .13, "snare": .23, "clang": .85,
               "rail": .31, "tom": .43, "kick": .42, "sweep": 1.4}
    seconds = lengths[kind]
    n = round(seconds * RATE)
    t = np.arange(n, dtype=np.float32) / RATE
    noise = rng.standard_normal(n).astype(np.float32)
    if kind in ("tick", "hat", "snare", "rail", "clang"):
        diff = noise - np.roll(noise, 5 if kind in ("tick", "hat") else 20)
        decay = {"tick": 105, "hat": 48, "snare": 19, "rail": 15, "clang": 6}[kind]
        pitched = 0 if kind in ("tick", "hat") else np.sin(2 * np.pi * (183 if kind == "snare" else 365) * t)
        return ((diff * (.19 if kind == "clang" else .43) + .4 * pitched) * np.exp(-decay * t)).astype(np.float32)
    if kind == "kick":
        phase = 2 * np.pi * (49 * t + 77 * (1 - np.exp(-25 * t)) / 25)
        return (np.sin(phase) * np.exp(-15 * t) + noise * .05 * np.exp(-37 * t)).astype(np.float32)
    if kind == "tom":
        phase = 2 * np.pi * (76 * t + 75 * (1 - np.exp(-10 * t)) / 10)
        return (np.sin(phase) * np.exp(-9 * t) + noise * .035 * np.exp(-22 * t)).astype(np.float32)
    # a bowed machinery wash used only at section transitions
    return (noise * np.sin(np.pi * np.clip(t / seconds, 0, 1)) ** 2 * .2).astype(np.float32)


def render(score: dict, index: int) -> dict:
    ident, style, bpm, bars = score["id"], score["style"], score["bpm"], score["bars"]
    beat = 60 / bpm
    bar_len = 4 * beat
    duration = bars * bar_len
    mix = np.zeros((round(duration * RATE), 2), dtype=np.float32)
    rng = np.random.default_rng(17000 + index)
    hits = {name: noise_hit(name, rng) for name in ("tick", "hat", "snare", "clang", "rail", "tom", "kick", "sweep")}

    def sound(kind: str, at: float, gain: float, pan: float = 0, echo: bool = False) -> None:
        put(mix, at, hits[kind], gain, pan)
        if echo:
            put(mix, at + beat * .75, hits[kind], gain * .27, -pan)

    def pitch(midi: float, at: float, length: float, kind: str, gain: float, pan: float = 0, echo: bool = False) -> None:
        sample = voice(midi, length, kind)
        put(mix, at, sample, gain, pan)
        if echo:
            put(mix, at + beat * .75, sample, gain * .29, -pan)

    def bed(midi: float, at: float, length: float, color: str, gain: float, pan: float = 0) -> None:
        put(mix, at, drone(midi, length, color, 4400 + index), gain, pan)

    # Harmonic beds have differing spacing, voicing and density by setting.
    if style in ("menu", "clinical"):
        for b in range(0, bars, 4):
            root = [33, 34, 29, 31][(b // 4) % 4]
            bed(root, b * bar_len, 4 * bar_len, "air", .18 if style == "menu" else .16, -.42)
            bed(root + (7 if style == "menu" else 6), b * bar_len, 4 * bar_len, "stone", .10, .38)
    elif style in ("furnace", "vault", "march"):
        for b in range(0, bars, 4):
            root = [31, 29, 26, 28, 31][(b // 4) % 5]
            bed(root, b * bar_len, 4 * bar_len, "furnace" if style == "furnace" else "stone", .17, -.28)
            bed(root + 12, b * bar_len, 4 * bar_len, "stone", .055, .27)
    elif style in ("transit", "electro", "climax"):
        for b in range(0, bars, 4):
            root = [31, 29, 34, 26, 31, 36, 29][(b // 4) % 7]
            bed(root, b * bar_len, 4 * bar_len, "electric", .085 if style != "transit" else .055, -.18)
    elif style == "pressure":
        for b in range(0, bars, 6):
            bed([30, 31, 28, 26][(b // 6) % 4], b * bar_len, min(6, bars - b) * bar_len,
                "air", .09, -.2)

    for bar in range(bars):
        t0 = bar * bar_len
        section = bar // max(1, bars // 4)
        if style == "menu":
            root = [57, 56, 52, 54][(bar // 4) % 4]
            if bar % 2 == 0:
                pitch(root, t0 + .25 * beat, 3.2 * beat, "glass", .19, -.53, True)
                pitch(root + 7, t0 + 1.7 * beat, 2.2 * beat, "glass", .12, .52, True)
            if bar >= 4 and bar % 4 == 3:
                pitch(root - 17, t0 + 2 * beat, 1.6 * beat, "organ", .085)
            if bar in (7, 15):
                sound("clang", t0 + 3 * beat, .12, .54, True)
        elif style == "clinical":
            root = [65, 63, 60, 62][(bar // 4) % 4]
            # Sparse diagnostic ticks and a single disquieting glass phrase.
            for step in (0, 3):
                sound("tick", t0 + step * beat, .035, -.65 if step else .62)
            if bar % 4 in (1, 3):
                pitch(root, t0 + 1.3 * beat, 2.2 * beat, "glass", .14, .52, True)
            if bar % 4 == 3:
                pitch(root - 6, t0 + 3.0 * beat, .9 * beat, "glass", .095, -.48)
        elif style == "pressure":
            root = [38, 36, 33, 35][(bar // 6) % 4]
            for step in (0, 1.5, 2.75):
                sound("kick", t0 + step * beat, .19 if step == 0 else .12)
            for step in (1, 3.5):
                sound("rail", t0 + step * beat, .095, .47 if step == 1 else -.47)
            if bar % 2 == 0:
                pitch(root, t0, 1.15 * beat, "sub", .18)
            if bar % 3 == 2:
                sound("sweep", t0 + 2.1 * beat, .065, .6)
            if section >= 2 and bar % 2:
                pitch(root + 18, t0 + 2 * beat, .5 * beat, "sequence", .055, -.5)
        elif style == "breakbeat":
            root = [39, 37, 34, 41][(bar // 8) % 4]
            break_bar = bar % 8 == 7
            if not break_bar:
                # A broken backbeat, with a different kick turn on alternating bars.
                kicks = (0, .75, 2.25, 3.5) if bar % 2 else (0, 1.5, 2, 3.25)
                for step in kicks:
                    sound("kick", t0 + step * beat, .21)
                for step in (1.25, 3.0 if bar % 2 else 2.75):
                    sound("snare", t0 + step * beat, .27, -.25)
                for step in (0, 1, 2, 3, 4, 6, 7):
                    sound("hat", t0 + step * beat / 2, .11, -.5 if step % 2 else .48)
                for step, interval in ((0, 0), (.75, 0), (1.5, 6), (2.25, 0), (2.75, -2), (3.5, 5)):
                    pitch(root + interval, t0 + step * beat, .31 * beat, "distorted", .125, -.43 if bar % 2 else .38)
                if bar % 4 == 3:
                    sound("clang", t0 + 3 * beat, .12, .55)
            else:
                # The sudden empty bar gives the return of the riff a clear edge.
                sound("snare", t0 + 3.5 * beat, .25, -.5)
                sound("clang", t0 + 3.75 * beat, .13, .54)
        elif style == "march":
            root = [38, 36, 33, 35, 38][(bar // 4) % 5]
            for step in (0, 2, 2.75):
                sound("tom", t0 + step * beat, .26 if step == 0 else .14, -.2 if step == 2 else .15)
            for step in (0, 2):
                sound("hat", t0 + step * beat, .075, .5 if step else -.5)
            if bar % 2 == 0:
                pitch(root + 12, t0 + 1 * beat, 2.4 * beat, "brass", .125, .38, True)
            if bar % 4 == 3:
                pitch(root + 17, t0 + 2 * beat, 1.8 * beat, "brass", .11, -.42, True)
                sound("clang", t0 + 3.4 * beat, .18, .5)
        elif style == "furnace":
            root = [44, 41, 39, 46][(bar // 4) % 4]
            if bar % 2 == 0:
                pitch(root, t0 + .4 * beat, 3.8 * beat, "choir", .12, -.42)
                pitch(root + 7, t0 + .7 * beat, 3.5 * beat, "choir", .075, .45)
            if bar % 2 == 1:
                sound("clang", t0 + .2 * beat, .22, .52, True)
                sound("tom", t0 + 2.3 * beat, .11, -.3)
            if bar % 4 == 3:
                sound("sweep", t0 + 3 * beat, .062, -.3)
        elif style == "vault":
            root = [48, 45, 46, 41][(bar // 4) % 4]
            if bar % 4 == 0:
                pitch(root, t0 + .5 * beat, 6 * beat, "organ", .08, -.38)
            if bar % 3 == 1:
                pitch(root + 19, t0 + 1.5 * beat, 2.8 * beat, "bell", .085, .51, True)
            if bar in (6, 14):
                sound("clang", t0 + 3.2 * beat, .04, -.57, True)
        elif style == "transit":
            root = [38, 36, 41, 34, 38][(bar // 4) % 5]
            sound("rail", t0, .085, -.61, True)
            if bar % 2 == 0:
                sound("kick", t0 + 2.5 * beat, .10)
                pitch(root, t0 + .5 * beat, 1.1 * beat, "sub", .14, 0, True)
            if bar % 4 == 3:
                pitch(root + 24, t0 + 3 * beat, 1.7 * beat, "glass", .075, .5, True)
            if bar % 5 == 4:
                sound("sweep", t0 + beat, .035, -.52)
        elif style == "electro":
            root = [43, 41, 46, 38, 43, 48][(bar // 4) % 6]
            # A quantized, sparse security-grid pulse rather than another backbeat.
            for step in ((.5, 3.0) if bar % 3 else (0, 2.75)):
                sound("kick", t0 + step * beat, .13)
            for step in (.25, 1.25, 2.25, 3.25):
                sound("tick", t0 + step * beat, .16, -.6 if bar % 2 else .6)
            if bar % 2 == 0:
                sound("snare", t0 + 3.5 * beat, .13, .35)
            for step, interval in ((.25, 0), (1.0, 12), (1.75, 7), (2.5, 3), (3.25, 10)):
                pitch(root + interval, t0 + step * beat, .30 * beat, "sequence", .09, -.4 if step % 1 else .4)
            if bar % 4 == 3:
                sound("rail", t0 + 3.75 * beat, .16, .6, True)
        elif style == "climax":
            root = [38, 40, 35, 33, 38, 42, 35][(bar // 4) % 7]
            # Continuous machine sixteenths, with a two-bar shutdown before
            # the final climb; the rhythm is intentionally unlike the Ward riff.
            shutdown = bar in (20, 21)
            if not shutdown:
                for step in (0, .5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5):
                    sound("kick", t0 + step * beat, .11 if step % 1 else .16)
                for step in (1, 3):
                    sound("snare", t0 + step * beat, .20, -.15)
                for step in range(16):
                    sound("hat", t0 + step * beat / 4, .09 if step % 4 else .13,
                          .48 if step % 2 else -.45)
                for step, interval in ((0, 0), (.5, 0), (1, 7), (1.75, 8), (2, 0), (2.75, 12), (3.25, 7)):
                    pitch(root + interval, t0 + step * beat, .34 * beat, "distorted", .11, -.4 if bar % 2 else .42)
                if bar % 4 == 3:
                    sound("clang", t0 + 3.25 * beat, .15, -.45, True)
            else:
                sound("rail", t0 + 3.5 * beat, .2, -.5, True)

    # Arrangement dynamics supply different long-form shapes. Smooth control
    # points avoid clicks while retaining the authored empty bars and drops.
    shapes = {
        "breakbeat": [(0, .45), (7, .70), (8, 1), (15, 1), (16, .38),
                      (20, .47), (24, 1), (32, 1)],
        "electro": [(0, .85), (7, .85), (8, .45), (12, .55),
                    (16, .9), (20, .65), (24, .85)],
        "climax": [(0, .42), (6, .55), (12, .7), (19, .85),
                   (20, .30), (22, .65), (26, 1), (28, .95)],
    }
    if style in shapes:
        points = shapes[style]
        times = np.arange(len(mix), dtype=np.float32) / RATE / bar_len
        gain = np.interp(times, [p[0] for p in points], [p[1] for p in points]).astype(np.float32)
        mix *= gain[:, None]
    if style in ("breakbeat", "electro", "climax"):
        # Control spiky machine percussion before setting final peak. The dry
        # drive increases body while retaining transient and section dynamics.
        mix = np.tanh(mix * 5.5).astype(np.float32)

    # Fade both ends to silence: Vorbis packets can then loop without a click.
    fade = round(.18 * RATE)
    ramp = np.linspace(0, 1, fade, dtype=np.float32)[:, None]
    mix[:fade] *= ramp
    mix[-fade:] *= ramp[::-1]
    raw_peak = float(np.max(np.abs(mix)))
    target = .37 if style in ("clinical", "vault", "menu") else (.48 if style in ("furnace", "transit") else .56)
    mix *= target / max(raw_peak, .0001)
    # Long drones have higher average energy than percussion. Leave headroom for
    # pickups, warnings and dialogue at the game's unchanged Music bus setting.
    rms_cap = {"menu": .055, "clinical": .055, "furnace": .08,
               "vault": .06, "transit": .055}.get(style, .105)
    actual_rms = float(np.sqrt(np.mean(mix ** 2)))
    mix *= min(1.0, rms_cap / max(actual_rms, .0001))
    peak = float(np.max(np.abs(mix)))
    rms = float(np.sqrt(np.mean(mix ** 2)))
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / f"{ident}.ogg"
    with tempfile.TemporaryDirectory(prefix="eyesore-v17-") as tmp:
        wav = pathlib.Path(tmp) / "cue.wav"
        with wave.open(str(wav), "wb") as file:
            file.setnchannels(2)
            file.setsampwidth(2)
            file.setframerate(RATE)
            file.writeframes((np.clip(mix, -1, 1) * 32767).astype("<i2").tobytes())
        subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(wav),
                        "-c:a", "libvorbis", "-q:a", "5", str(path)], check=True)
    return dict(id=ident, title=score["title"], style=style, description=score["description"],
                file=str(path.relative_to(ROOT)), sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                seconds=round(duration, 3), bpm=bpm, sample_peak=round(peak, 4), rms=round(rms, 4))


def main() -> None:
    cues = [render(score, index) for index, score in enumerate(SCORES)]
    manifest = dict(project="Eyesore", version=17, creator="Eyesore project / Codex composition",
                    license="original project composition", sample_rate=RATE, channels=2,
                    source="Every cue synthesized from written patterns, oscillators and seeded noise in tools/compose_campaign_v17.py; no external music, samples, recordings or previous cues are inputs.",
                    render_tools=dict(numpy=np.__version__, ffmpeg=subprocess.check_output(["ffmpeg", "-version"], text=True).splitlines()[0]),
                    cues=cues)
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps({"rendered": len(cues), "minutes": round(sum(c["seconds"] for c in cues) / 60, 2),
                      "styles": [c["style"] for c in cues]}, indent=2))


if __name__ == "__main__":
    main()
