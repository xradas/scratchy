#!/usr/bin/env python3
"""Publish unchanged demonic-voice auditions and native aim captures for review."""

import hashlib
from html import escape
import json
from pathlib import Path
import shutil
import struct
from urllib.parse import quote


ROOT = Path(__file__).resolve().parents[1]
AUDIO_MANIFEST = ROOT / "concepts/audio-v4/manifest.json"
CAPTURES = ROOT / "verification/demonic-aim-v1"
ASSETS = ROOT / "concepts/demonic-aim-v1"
REVIEW = ROOT / "concepts/demonic-aim-review.html"
CUE_ORDER = (
    "unsealed_hurt", "vessel_hurt", "unsealed_attack_warning",
    "vessel_attack_warning", "unsealed_death", "vessel_death",
)
CAPTURE_ORDER = (
    "containment-entry", "pistol-idle", "pistol-fire", "pistol-recover",
    "pistol-switch", "shotgun-idle", "shotgun-fire", "shotgun-recover",
    "shotgun-switch",
)


def describe(path):
    data = path.read_bytes()
    record = {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}
    if path.suffix == ".png":
        if len(data) < 24 or data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
            raise ValueError(f"Not a PNG with an IHDR header: {path}")
        record["width"], record["height"] = struct.unpack(">II", data[16:24])
        if not record["width"] or not record["height"]:
            raise ValueError(f"Empty PNG dimensions: {path}")
    elif path.suffix == ".wav":
        if len(data) < 44 or data[:4] != b"RIFF" or data[8:12] != b"WAVE":
            raise ValueError(f"Not a RIFF/WAVE file: {path}")
    else:
        raise ValueError(f"Unexpected review media type: {path}")
    return record


def label(key):
    return key.replace("-", " ").replace("_", " ").capitalize()


def url(group, filename):
    return f"demonic-aim-v1/{group}/{quote(filename)}"


def render(cues, names):
    first = names[0]
    opts = "\n".join(f'        <option value="{escape(name, quote=True)}">{escape(label(name))}</option>'
                     for name in names)
    audio = "\n".join(
        f'''      <article>
        <h3>{escape(label(cue))}</h3>
        <p>Previous cue, brief pause, then new demonic cue.</p>
        <audio controls preload="none" aria-label="{escape(label(cue), quote=True)} before and after" src="{escape(url("auditions", Path(cues[cue]["before_after"]).name), quote=True)}"></audio>
        <p><a href="{escape(url("auditions", Path(cues[cue]["before_after"]).name), quote=True)}">Unchanged audition WAV</a> · <a href="{escape('../' + cues[cue]["before_after"], quote=True)}">Original audition source</a></p>
      </article>'''
        for cue in CUE_ORDER)
    links = "\n".join(
        f'      <li>{escape(label(name))}: <a href="{escape(url("before", name + ".png"), quote=True)}">before PNG</a> · <a href="{escape(url("after", name + ".png"), quote=True)}">after PNG</a></li>'
        for name in names)
    before = escape(url("before", first + ".png"), quote=True)
    after = escape(url("after", first + ".png"), quote=True)
    return f'''<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>The Pale Ward — demonic voices and aim review</title>
  <link rel="stylesheet" href="grit-review.css">
  <style>
    .audio-grid {{ display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 16px; }}
    .audio-grid article {{ border: 1px solid #555; padding: 12px 16px; }}
    .audio-grid h3 {{ margin: 0; }}
    .audio-grid audio {{ width: 100%; }}
    @media (max-width: 760px) {{ .audio-grid {{ grid-template-columns: 1fr; }} }}
  </style>
</head>
<body>
<main>
  <header>
    <p>EYESORE / BUILD TWO / VOICE AND AIM COMPARISON</p>
    <h1>The Pale Ward — demonic voices and aim review</h1>
    <p>Six creature cues have been revised toward lower, layered demonic voices. Each audition plays the preceding runtime cue, a short pause, then the revised cue. These are listening comparisons, not recorded gameplay audio. Music and player, weapon, and material-contact sounds remain unchanged.</p>
    <p>The images compare native full-window captures of the actual game before and after the gun bore and crosshair alignment change. The fire and switch views freeze the simulation at real gameplay events; no weapon overlays were added to the PNGs. Open any image for its unchanged pixels. Human listening and visual acceptance remain pending.</p>
    <p><a href="weapon-style-review.html">Previous weapon review</a> · <a href="demonic-aim-v1/manifest.json">Source SHA256 and byte checks</a> · <a href="audio-v4/manifest.json">Audio processing provenance</a> · <a href="../verification/demonic-aim-v1/aim/aim-balance.json">Aim balance evidence</a></p>
  </header>
  <section aria-labelledby="voice-heading">
    <h2 id="voice-heading">Creature voices — before, then after</h2>
    <div class="audio-grid">
{audio}
    </div>
  </section>
  <section aria-labelledby="aim-heading">
    <h2 id="aim-heading">Gun bore and crosshair — actual game</h2>
    <label for="view">Gameplay phase</label>
    <select id="view">
{opts}
    </select>
    <div class="comparison">
      <section aria-labelledby="before-heading">
        <h3 id="before-heading">Before alignment</h3>
        <figure><a id="before-link" class="image-frame" href="{before}"><img id="before-image" src="{before}" alt="Before alignment: {escape(label(first))}"></a><figcaption id="before-caption">Before: {escape(label(first))}. Native running-game capture.</figcaption></figure>
      </section>
      <section aria-labelledby="after-heading">
        <h3 id="after-heading">After alignment</h3>
        <figure><a id="after-link" class="image-frame" href="{after}"><img id="after-image" src="{after}" alt="After alignment: {escape(label(first))}"></a><figcaption id="after-caption">After: {escape(label(first))}. Native running-game capture.</figcaption></figure>
      </section>
    </div>
    <p>Both images use equal display dimensions, preserve aspect ratio without cropping, and use nearest-neighbour display scaling.</p>
    <ul>
{links}
    </ul>
  </section>
  <footer><p>Review media are byte-for-byte copies. The <a href="demonic-aim-v1/manifest.json">manifest</a> records every source and copy SHA256. No review image or audio file was edited.</p></footer>
  <p id="view-status" role="status" aria-live="polite" class="sr-only"></p>
</main>
<script>
"use strict";
document.getElementById("view").addEventListener("change", (event) => {{
  const name = event.target.value;
  const text = event.target.selectedOptions[0].textContent;
  for (const state of ["before", "after"]) {{
    const value = `demonic-aim-v1/${{state}}/${{name}}.png`;
    document.getElementById(`${{state}}-link`).href = value;
    const image = document.getElementById(`${{state}}-image`);
    image.src = value;
    image.alt = `${{state === "before" ? "Before" : "After"}} alignment: ${{text}}`;
    document.getElementById(`${{state}}-caption`).textContent = `${{state === "before" ? "Before" : "After"}}: ${{text}}. Native running-game capture.`;
  }}
  document.getElementById("view-status").textContent = `Gameplay phase changed to ${{text}}.`;
}});
</script>
</body>
</html>
'''


def main():
    if not AUDIO_MANIFEST.is_file():
        raise SystemExit(f"Missing audio provenance: {AUDIO_MANIFEST}")
    document = json.loads(AUDIO_MANIFEST.read_text(encoding="utf-8"))
    cues = document["cues"]
    if set(cues) != set(CUE_ORDER):
        raise SystemExit("Expected exactly six creature voice auditions")
    before = {p.stem: p for p in (CAPTURES / "before").glob("*.png")}
    after = {p.stem: p for p in (CAPTURES / "after").glob("*.png")}
    if set(before) != set(after) or set(before) != set(CAPTURE_ORDER):
        raise SystemExit("Before/after native captures must have matching nine-phase PNG sets")
    names = list(CAPTURE_ORDER)
    media = []
    for cue in CUE_ORDER:
        source = ROOT / cues[cue]["before_after"]
        media.append((source, "auditions", "previous cue, then revised demonic cue",
                      cues[cue]["before_after_sha256"]))
    for state, paths in (("before", before), ("after", after)):
        media.extend((paths[name], state, f"actual game {state} alignment", None) for name in names)
    for source, _, _, expected in media:
        if not source.is_file():
            raise SystemExit(f"Missing review media: {source}")
        if expected and describe(source)["sha256"] != expected:
            raise SystemExit(f"Audio provenance hash mismatch: {source}")
    records = {source: describe(source) for source, _, _, _ in media}
    html = render(cues, names)
    copied = []
    for source, group, status, _ in media:
        target = ASSETS / group / source.name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        actual = describe(target)
        if actual != records[source] or describe(source) != records[source]:
            raise RuntimeError(f"Byte-copy check failed: {source}")
        copied.append({"source": str(source.relative_to(ROOT)),
                       "copy": str(target.relative_to(ROOT)), "status": status,
                       "byte_identical": True, "source_sha256": records[source]["sha256"],
                       "copy_sha256": actual["sha256"], **records[source]})
    manifest = {"note": "Unchanged audition WAVs and native gameplay PNGs; human review pending.",
                "audio_source_manifest": str(AUDIO_MANIFEST.relative_to(ROOT)),
                "auditions": copied[:len(CUE_ORDER)],
                "before_actual_game": copied[len(CUE_ORDER):len(CUE_ORDER) + len(names)],
                "after_actual_game": copied[len(CUE_ORDER) + len(names):]}
    (ASSETS / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    REVIEW.write_text(html, encoding="utf-8")
    print(f"DEMONIC_AIM_REVIEW_OK: {len(CUE_ORDER)} auditions and {len(names)} before/after gameplay pairs byte-verified.")
    print("Review: concepts/demonic-aim-review.html")


if __name__ == "__main__":
    main()
