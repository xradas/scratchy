#!/usr/bin/env python3
"""Publish a source-verified weapon style comparison from native PNG captures."""

import hashlib
from html import escape
import json
from pathlib import Path
import shutil
import struct
from urllib.parse import quote


ROOT = Path(__file__).resolve().parents[1]
REFERENCE = ROOT / "concepts/visual-v2/corrupted-biotech/scene_pixel_preview.png"
OLDER = ROOT / "verification/style-v2/captures/containment-entry.png"
CURRENT = ROOT / "verification/weapon-style-v3/captures"
ASSETS = ROOT / "concepts/weapon-style-v3"
REVIEW = ROOT / "concepts/weapon-style-review.html"


def describe(path):
    data = path.read_bytes()
    if len(data) < 24 or data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        raise ValueError(f"Not a PNG with an IHDR header: {path}")
    width, height = struct.unpack(">II", data[16:24])
    if not width or not height:
        raise ValueError(f"Empty PNG dimensions: {path}")
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest(),
            "width": width, "height": height}


def label(path):
    return path.stem.replace("-", " ").replace("_", " ").capitalize()


def asset_url(group, path):
    return f"weapon-style-v3/{group}/{quote(path.name)}"


def render(captures):
    first = captures[0]
    first_url = escape(asset_url("current", first), quote=True)
    first_label = escape(label(first))
    options = "\n".join(
        f'          <option value="{escape(asset_url("current", path), quote=True)}">{escape(label(path))}</option>'
        for path in captures)
    links = "\n".join(
        f'        <li><a href="{escape(asset_url("current", path), quote=True)}">Actual new game: {escape(label(path))}</a></li>'
        for path in captures)
    return f'''<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>The Pale Ward — weapon style review</title>
  <link rel="stylesheet" href="grit-review.css">
  <style>
    .weapon-comparison {{ display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 20px; }}
    .weapon-comparison .image-frame {{ aspect-ratio: 16 / 9; }}
    @media (max-width: 1050px) {{ .weapon-comparison {{ grid-template-columns: 1fr; }} }}
  </style>
</head>
<body>
<main>
  <header>
    <p>EYESORE / BUILD TWO / WEAPON STYLE COMPARISON</p>
    <h1>The Pale Ward — weapon style review</h1>
    <p>Compare the unchanged approved concept preview with actual running-game captures from the previous style pass and the new weapon pass. The reference sets the requested painted, coarse-pixel treatment; it does not prescribe an identical camera or composition.</p>
    <p>All images are native PNGs copied byte for byte, shown uncropped with nearest-neighbour display scaling. Open an image to inspect its full source pixels. Visual acceptance remains pending.</p>
    <p>The new fire and switch views are full-window screenshots from the actual gameplay renderer. Capture paused the simulation at real shot and weapon-switch states; no weapon images or other overlays were composited into these screenshots. <a href="../verification/weapon-style-v3/captures/capture-state.json">Capture state evidence</a> records each phase and event.</p>
    <p>The HUD and audio are unchanged in this weapon pass.</p>
    <p><a href="style-review.html">Previous style review</a> · <a href="grit-review.html">Earlier grit review</a> · <a href="weapon-style-v3/manifest.json">Source SHA256 and byte checks</a></p>
  </header>
  <div class="weapon-comparison">
    <section aria-labelledby="reference-heading">
      <h2 id="reference-heading">Approved style reference — original concept</h2>
      <figure>
        <a class="image-frame" href="weapon-style-v3/reference/scene_pixel_preview.png" aria-label="Open unchanged approved concept preview PNG"><img src="weapon-style-v3/reference/scene_pixel_preview.png" alt="Original Pale Ward concept pixel preview"></a>
        <figcaption>Original scene_pixel_preview.png; approved art style reference.</figcaption>
      </figure>
      <p><a href="visual-v2/corrupted-biotech/scene_pixel_preview.png">Original source PNG</a></p>
    </section>
    <section aria-labelledby="previous-heading">
      <h2 id="previous-heading">Previous actual game — style v2</h2>
      <figure>
        <a class="image-frame" href="weapon-style-v3/previous/containment-entry.png" aria-label="Open unchanged previous actual game PNG"><img src="weapon-style-v3/previous/containment-entry.png" alt="Previous actual game, containment entry"></a>
        <figcaption>Previous running-game containment entry capture, before the weapon pass.</figcaption>
      </figure>
    </section>
    <section aria-labelledby="current-heading">
      <h2 id="current-heading">New actual game — weapon style v3</h2>
      <label for="current-view">New running-game capture</label>
      <select id="current-view">
{options}
      </select>
      <figure>
        <a id="current-link" class="image-frame" href="{first_url}" aria-label="Open unchanged new actual game PNG"><img id="current-image" src="{first_url}" alt="New actual game: {first_label}"></a>
        <figcaption id="current-caption">New running-game capture: {first_label}.</figcaption>
      </figure>
      <p>Review pending; no visual match or acceptance is claimed.</p>
    </section>
  </div>
  <section>
    <h2>New actual game captures</h2>
    <p>Direct links also work without JavaScript.</p>
    <ul>
{links}
    </ul>
  </section>
  <footer><p>The <a href="weapon-style-v3/manifest.json">manifest</a> names each original source and copied asset with dimensions, byte count, and SHA256. Source PNG pixels are preserved without editing, filtering, or compositing.</p></footer>
  <p id="view-status" role="status" aria-live="polite" class="sr-only"></p>
</main>
<script>
"use strict";
document.getElementById("current-view").addEventListener("change", (event) => {{
  const option = event.target.selectedOptions[0];
  const image = document.getElementById("current-image");
  image.src = option.value;
  image.alt = `New actual game: ${{option.textContent}}`;
  const link = document.getElementById("current-link");
  link.href = option.value;
  link.setAttribute("aria-label", `Open unchanged new actual game ${{option.textContent}} PNG`);
  document.getElementById("current-caption").textContent = `New running-game capture: ${{option.textContent}}.`;
  document.getElementById("view-status").textContent = `New actual game view changed to ${{option.textContent}}.`;
}});
</script>
</body>
</html>
'''


def main():
    captures = sorted(CURRENT.glob("*.png"), key=lambda p: (p.stem != "containment-entry", p.name))
    required = (REFERENCE, OLDER)
    missing = [str(path.relative_to(ROOT)) for path in required if not path.is_file()]
    if missing:
        raise SystemExit("Missing required review images: " + ", ".join(missing))
    if not captures:
        raise SystemExit(f"No new actual game PNGs found in {CURRENT}")
    sources = [(REFERENCE, "reference", "approved concept style reference"),
               (OLDER, "previous", "previous actual game")]
    sources.extend((path, "current", "new actual game") for path in captures)
    records = {path: describe(path) for path, _, _ in sources}
    html = render(captures)
    copied = []
    for source, group, status in sources:
        target = ASSETS / group / source.name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        copy_record = describe(target)
        if copy_record != records[source] or describe(source) != records[source]:
            raise RuntimeError(f"Source changed or byte-copy verification failed: {source}")
        copied.append({"source": str(source.relative_to(ROOT)),
                       "copy": str(target.relative_to(ROOT)),
                       "status": status, "label": label(source),
                       "byte_identical": True, "source_sha256": records[source]["sha256"],
                       "copy_sha256": copy_record["sha256"], **records[source]})
    manifest = {"note": "Unchanged native PNG copies; weapon style review pending, with no match or acceptance claim.",
                "unchanged": ["HUD", "audio"], "reference": copied[0],
                "previous_actual_game": copied[1], "new_actual_game": copied[2:]}
    (ASSETS / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    REVIEW.write_text(html, encoding="utf-8")
    print(f"WEAPON_REVIEW_OK: reference, previous game, and {len(captures)} new actual game captures copied and SHA256-verified.")
    print("Review: concepts/weapon-style-review.html")


if __name__ == "__main__":
    main()
