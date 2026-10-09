#!/usr/bin/env python3
"""Refresh the review's native captures without altering any image pixels."""

import hashlib
import json
from pathlib import Path
import shutil
import struct


ROOT = Path(__file__).resolve().parents[1]
REFERENCES = (
    "concepts/visual-v2/corrupted-biotech/scene.png",
    "concepts/visual-v2/corrupted-biotech/scene_pixel_preview.png",
)
CURRENT = (
    "containment-entry", "containment-stairs", "bio-wing",
    "operating-room", "rear-lab", "exit-gallery",
)
OLDER = ("before-entry", "before-stairs")


def describe(path):
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        raise ValueError(f"Not a PNG with an IHDR header: {path}")
    width, height = struct.unpack(">II", data[16:24])
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest(),
            "width": width, "height": height}


def main():
    sources = [ROOT / name for name in REFERENCES]
    sources += [ROOT / "verification/grit" / f"{name}.png"
                for name in CURRENT + OLDER]
    missing = [str(path.relative_to(ROOT)) for path in sources if not path.is_file()]
    if missing:
        raise SystemExit("Missing required review images: " + ", ".join(missing))
    # Validate all inputs before updating the review. Reference files are read only.
    records = {str(path.relative_to(ROOT)): describe(path) for path in sources}
    destination = ROOT / "concepts/grit-review-assets"
    destination.mkdir(exist_ok=True)
    for name in CURRENT + OLDER:
        source = ROOT / "verification/grit" / f"{name}.png"
        target = destination / source.name
        shutil.copyfile(source, target)
        if describe(target) != records[str(source.relative_to(ROOT))]:
            raise RuntimeError(f"Copy verification failed: {target}")
    manifest = {"note": "Native PNG bytes copied unchanged; concept references preserved in place.",
                "approved_references": {name: records[name] for name in REFERENCES},
                "captures": [{"source": f"verification/grit/{name}.png",
                              "copy": f"concepts/grit-review-assets/{name}.png",
                              "status": "actual current game" if name in CURRENT else "older game",
                              **records[f"verification/grit/{name}.png"]}
                             for name in CURRENT + OLDER]}
    (destination / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"Copied and byte-verified {len(CURRENT) + len(OLDER)} native PNGs.")
    print("Approved concept originals were preserved; review: concepts/grit-review.html")


if __name__ == "__main__":
    main()
