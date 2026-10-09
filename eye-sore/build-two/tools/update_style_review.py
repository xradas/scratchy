#!/usr/bin/env python3
"""Sync the style review from actual capture PNGs, preserving source bytes."""

import hashlib
from html import escape
import json
from pathlib import Path
import shutil
import struct
from urllib.parse import quote

ROOT = Path(__file__).resolve().parents[1]
REFERENCE = ROOT / "concepts/visual-v2/corrupted-biotech/scene_pixel_preview.png"
CAPTURES = ROOT / "verification/style-v2/captures"
ASSETS = ROOT / "concepts/style-review-assets"
REVIEW = ROOT / "concepts/style-review.html"
LOCATION_ORDER = (
    "containment-entry", "containment-stairs", "bio-wing",
    "operating-room", "rear-lab", "exit-gallery",
)


def describe(path):
    data = path.read_bytes()
    if len(data) < 24 or data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        raise ValueError(f"Not a PNG with an IHDR header: {path}")
    width, height = struct.unpack(">II", data[16:24])
    if not width or not height:
        raise ValueError(f"Empty PNG dimensions: {path}")
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest(),
            "width": width, "height": height}


def capture_key(path):
    if path.stem in LOCATION_ORDER:
        return (0, LOCATION_ORDER.index(path.stem), path.name)
    return (1, 0, path.name)


def label(path):
    return path.stem.replace("-", " ").replace("_", " ").capitalize()


def asset_url(path):
    return "style-review-assets/" + quote(path.name)


def render_review(sources):
    initial = sources[0]
    current_url = escape(asset_url(initial), quote=True)
    current_label = escape(label(initial))
    options = "\n".join(
        f'        <option value="{escape(asset_url(path), quote=True)}">{escape(label(path))}</option>'
        for path in sources
    )
    links = "\n".join(
        f'      <li><a href="{escape(asset_url(path), quote=True)}">Actual gameplay: {escape(label(path))}</a></li>'
        for path in sources
    )
    return f'''<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>The Pale Ward — art style review</title>
  <link rel="stylesheet" href="grit-review.css">
</head>
<body>
<main>
  <header>
    <p>EYESORE / BUILD TWO / ART STYLE COMPARISON</p>
    <h1>The Pale Ward — art style review</h1>
    <p>The latest requested treatment is the approved artwork's style: shared coarse pixels, painted grey-brown shading, dark metal, and restrained yellow-green light. The current HUD and music are retained.</p>
    <p>The original concept preview and actual gameplay captures are paired for review of that treatment. The target concerns art style across the game; it does not prescribe the exact opening camera. These captures do not establish a match or acceptance.</p>
    <p>Both comparison frames have equal displayed dimensions. Images keep their aspect ratio with no crop and use nearest-neighbour display scaling. Click either image for the full unchanged PNG.</p>
    <p><a href="index.html">Original concept review</a> · <a href="grit-review.html">Preserved earlier comparison</a> · <a href="style-review-assets/manifest.json">Source SHA256 and byte checks</a></p>
  </header>
  <div class="comparison">
    <section aria-labelledby="target-heading">
      <h2 id="target-heading">Approved style reference — original concept preview</h2>
      <label for="target-view">Original concept source</label>
      <select id="target-view">
        <option>Original scene_pixel_preview.png</option>
      </select>
      <figure>
        <a class="image-frame" href="style-review-assets/scene_pixel_preview.png" aria-label="Open unchanged approved concept preview PNG"><img src="style-review-assets/scene_pixel_preview.png" alt="Original approved Pale Ward concept preview, preserved byte for byte"></a>
        <figcaption>Approved concept artwork. This image is the style reference.</figcaption>
      </figure>
      <p><a href="visual-v2/corrupted-biotech/scene_pixel_preview.png">Original concept source PNG</a></p>
    </section>
    <section aria-labelledby="current-heading">
      <h2 id="current-heading">Actual gameplay — current implementation</h2>
      <label for="current-view">Actual gameplay capture</label>
      <select id="current-view">
{options}
      </select>
      <figure>
        <a id="current-link" class="image-frame" href="{current_url}" aria-label="Open actual gameplay {current_label} unchanged PNG"><img id="current-image" src="{current_url}" alt="Actual gameplay capture: {current_label}"></a>
        <figcaption id="current-caption">Actual gameplay: {current_label}. Running-game capture copied byte for byte.</figcaption>
      </figure>
      <p>Review pending. No visual match or acceptance is claimed.</p>
    </section>
  </div>
  <section>
    <h2>Actual gameplay captures — full unchanged PNGs</h2>
    <p>All current captures remain available here when JavaScript is disabled.</p>
    <ul>
{links}
    </ul>
  </section>
  <footer><p>PNG sources are preserved. Review assets are byte-for-byte copies from the original concept preview and verification/style-v2/captures. The provenance manifest records both paths, source dimensions, and SHA256. No image edits, filtering or compositing are applied to the files.</p></footer>
  <p id="view-status" role="status" aria-live="polite" class="sr-only"></p>
</main>
<script>
"use strict";
document.getElementById("current-view").addEventListener("change", (event) => {{
  const option = event.target.selectedOptions[0];
  const image = document.getElementById("current-image");
  image.src = option.value;
  image.alt = `Actual gameplay capture: ${{option.textContent}}`;
  const link = document.getElementById("current-link");
  link.href = option.value;
  link.setAttribute("aria-label", `Open actual gameplay ${{option.textContent}} unchanged PNG`);
  document.getElementById("current-caption").textContent = `Actual gameplay: ${{option.textContent}}. Running-game capture copied byte for byte.`;
  document.getElementById("view-status").textContent = `Actual gameplay view changed to ${{option.textContent}}.`;
}});
</script>
</body>
</html>
'''


def main():
    sources = sorted(CAPTURES.glob("*.png"), key=capture_key)
    if not REFERENCE.is_file():
        raise SystemExit(f"Missing original concept reference: {REFERENCE}")
    if not sources:
        raise SystemExit(f"No actual gameplay PNGs found in {CAPTURES}")
    if any(source.name == REFERENCE.name for source in sources):
        raise SystemExit("A gameplay filename collides with the concept reference filename.")
    # Validate every source before changing any review output. Source PNGs are read only.
    records = {path: describe(path) for path in [REFERENCE, *sources]}
    html = render_review(sources)
    ASSETS.mkdir(exist_ok=True)
    copied = []
    for source in [REFERENCE, *sources]:
        target = ASSETS / source.name
        shutil.copyfile(source, target)
        copy_record = describe(target)
        if copy_record != records[source] or describe(source) != records[source]:
            raise RuntimeError(f"Source changed or byte-copy verification failed: {source}")
        copied.append({"source": str(source.relative_to(ROOT)),
                       "copy": str(target.relative_to(ROOT)),
                       "status": "approved concept style reference" if source == REFERENCE else "actual gameplay capture",
                       "label": "Original concept pixel preview" if source == REFERENCE else label(source),
                       "byte_identical": True, "source_sha256": records[source]["sha256"],
                       "copy_sha256": copy_record["sha256"], **records[source]})
    manifest = {"note": "Unchanged PNG copies; art style comparison only, with no match or acceptance claim.",
                "requested_treatment": "Shared coarse pixels, painted grey-brown shading, dark metal, restrained yellow-green light; current HUD and music retained.",
                "reference": copied[0], "captures": copied[1:]}
    (ASSETS / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    REVIEW.write_text(html, encoding="utf-8")
    print(f"STYLE_REVIEW_OK: {len(sources)} actual gameplay captures and original concept preview copied and SHA256-verified.")
    print("Review: concepts/style-review.html; sync after final captures with tools/update_style_review.py")


if __name__ == "__main__":
    main()
