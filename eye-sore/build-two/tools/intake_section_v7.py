"""Explicit Intake-only layout; immutable v6 programme remains the fallback.

The JSON object inventory is written before scene construction. This module
contains no randomized placement, runtime changes or source asset generation.
"""
from __future__ import annotations

from copy import deepcopy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LEVEL_ID = "pale_ward_01"


def applies(stage: dict) -> bool:
    return stage.get("campaign_level_id") == LEVEL_ID


def load_layout() -> dict:
    return json.loads((ROOT / "docs/intake-v7/layout.json").read_text())


def apply_stage(stage: dict) -> None:
    """Change only six room shapes and the surgical return leg."""
    if not applies(stage):
        return
    layout = load_layout()
    changes = {room["id"]: room for room in layout["rooms"]}
    for room in stage["rooms"]:
        if room["id"] in changes:
            plan = changes[room["id"]]
            room["center"] = list(plan["center"])
            room["size"] = list(plan["size"])
    # Idempotent: make_stage and the post-v6-footprint hook both call this.
    for portal in stage["portals"]:
        if (portal["from"], portal["to"]) == ("key_wing", "return_store"):
            portal["from"] = "key_console"
        if portal.get("gate") == "shortcut_one":
            portal["requires"] = list(layout["shortcut"]["requires"])
            portal["first_open_normal"] = list(layout["shortcut"]["first_open_normal"])
    stage["intake_section_version"] = 7
    stage["intake_v7_clearance"] = deepcopy(layout["clearance_rectangles_xz"])
    validate_layout(stage)


def prepare_programme(stage: dict, programme: dict) -> dict:
    """Return an Intake-only copy accepted by v6 furnishing/validation code."""
    if not applies(stage):
        return programme
    apply_stage(stage)
    result = deepcopy(programme)
    changes = {room["id"]: room for room in load_layout()["rooms"]}
    for room in result["rooms"]:
        if room["id"] in changes:
            room["authored_size_xz"] = list(changes[room["id"]]["authored_size_xz"])
            room["objects"] = deepcopy(changes[room["id"]]["objects"])
    return result


def validate_layout(stage: dict) -> dict:
    """Check every straight corridor span and reject unrelated-room crossing."""
    rooms = {room["id"]: room for room in stage["rooms"]}
    checked = []
    section = {room["id"] for room in load_layout()["rooms"]}
    for portal in stage["portals"]:
        if not ({portal["from"], portal["to"]} & section):
            continue
        a, b = rooms[portal["from"]], rooms[portal["to"]]
        ac, bc = a["center"], b["center"]
        axis = 0 if abs(ac[0]-bc[0]) > abs(ac[2]-bc[2]) else 2
        cross = 2 if axis == 0 else 0
        width = portal["width"]
        low = max(ac[cross]-a["size"][cross]/2, bc[cross]-b["size"][cross]/2)+width/2
        high = min(ac[cross]+a["size"][cross]/2, bc[cross]+b["size"][cross]/2)-width/2
        assert low <= high, (a["id"], b["id"], "nonoverlapping portal mouths")
        c = max(low, min(high, ac[cross]))
        sign = 1 if bc[axis] > ac[axis] else -1
        start = ac[axis]+sign*a["size"][axis]/2
        end = bc[axis]-sign*b["size"][axis]/2
        assert (end-start)*sign > 0, (a["id"], b["id"], "overlapping rooms")
        for other in rooms.values():
            if other["id"] in (a["id"], b["id"]):
                continue
            # Positive-area overlap, not a harmless shared boundary.
            axis_overlap = min(max(start,end), other["center"][axis]+other["size"][axis]/2)-max(min(start,end), other["center"][axis]-other["size"][axis]/2)
            cross_overlap = min(c+width/2, other["center"][cross]+other["size"][cross]/2)-max(c-width/2, other["center"][cross]-other["size"][cross]/2)
            assert not (axis_overlap > .01 and cross_overlap > .01), (a["id"], b["id"], "crosses", other["id"])
        checked.append({"from": a["id"], "to": b["id"], "length": abs(end-start), "rise": bc[1]-ac[1], "width": width})
    assert any(p["from"] == "key_console" and p["to"] == "return_store" for p in stage["portals"])
    assert not any(p["from"] == "key_wing" and p["to"] == "return_store" for p in stage["portals"])
    return {"id": LEVEL_ID, "checked_section_portals": checked}
