"""Inventory-preserving, fully authored first-six-room clinical placements.

Hook prepare_programme AFTER intake_section_v7.prepare_programme and BEFORE
room_program_v6.validate_level_program/furnish. The contract is authored before
scene creation. This module never writes scenes, stage data or source assets.
"""
from __future__ import annotations

from copy import deepcopy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONTRACT = ROOT / "docs/production-v9/clinical-layout.json"
LEVEL_ID = "pale_ward_01"
ROOMS = ("entry", "service", "arena_one", "key_wing", "key_console", "return_store")


def load_layout(path=CONTRACT) -> dict:
    plan = json.loads(Path(path).read_text())
    assert plan["schema_version"] == 1 and plan["version"] == 9
    assert plan["campaign_level_id"] == LEVEL_ID
    assert {room["id"] for room in plan["rooms"]} == set(ROOMS)
    return plan


def _inventory(programme) -> list:
    return [(room["id"], obj["id"], obj["type"], obj["count"])
            for room in programme["rooms"] for obj in room["objects"]]


def prepare_programme(stage: dict, programme: dict) -> dict:
    """Return a deep copy, changing only target objects' placement annotations.

    Every target instance gets one explicit position; an invalid placement is
    rejected by the existing furnishing validator rather than falling back.
    Room labels/modes/functions, route metadata and unrelated fields are retained.
    """
    result = deepcopy(programme)
    if stage.get("campaign_level_id") != LEVEL_ID:
        return result
    assert programme["id"] == LEVEL_ID
    plan = load_layout()
    actual = {room["id"]: room for room in stage["rooms"]}
    changes = {room["id"]: room for room in plan["rooms"]}
    for room in result["rooms"]:
        rid = room["id"]
        if rid not in changes:
            continue
        authored = changes[rid]
        assert actual[rid]["center"] == authored["center"] and actual[rid]["size"] == authored["size"], (rid, "clinical room geometry drift")
        groups = {obj["id"]: obj for obj in authored["groups"]}
        assert set(groups) == {obj["id"] for obj in room["objects"]}, (rid, "clinical inventory drift")
        for obj in room["objects"]:
            replacement = groups[obj["id"]]
            assert (obj["type"], obj["count"]) == (replacement["type"], replacement["count"]), obj["id"]
            positions = replacement["authored_positions"]
            assert len(positions) == obj["count"], (obj["id"], "complete explicit placement required")
            for position in positions:
                assert len(position) == 3 and position[2] in (0, 90, 180, -90), (obj["id"], position)
                assert all(isinstance(value, (float, int)) for value in position)
            obj["authored_positions"] = deepcopy(positions)
            obj["placement"] = "Explicit v9 clinical work cell; no fallback. " + authored["workflow"]
    assert _inventory(result) == _inventory(programme), "clinical inventory changed"
    return result


def placement_report(stage: dict, programme: dict) -> dict:
    """Pre-build inspectable object list; actual furnish rejection is separate."""
    if stage.get("campaign_level_id") != LEVEL_ID:
        return {"applied": False, "reason": "first six Intake rooms only"}
    from room_program_v6 import SHAPES

    rooms = {room["id"]: room for room in stage["rooms"]}
    objects = []
    for room in programme["rooms"]:
        rid = room["id"]
        if rid not in ROOMS:
            continue
        center = rooms[rid]["center"]
        for obj in room["objects"]:
            assert len(obj.get("authored_positions", [])) == obj["count"]
            silhouette, width, depth, height = SHAPES[obj["type"]]
            for ordinal, (x, z, heading) in enumerate(obj["authored_positions"], 1):
                w, d = (depth, width) if abs(heading) == 90 else (width, depth)
                objects.append(dict(id=obj["id"] + "." + str(ordinal), room=rid,
                                    type=obj["type"], position_local=[x, z, heading],
                                    position_world=[center[0]+x, center[1], center[2]+z],
                                    footprint_world_xz=[w, d], recipe_height=height,
                                    silhouette=silhouette))
    assert len(objects) == 23
    return dict(schema_version=1, version=9, applied=True, campaign_level_id=LEVEL_ID,
                object_count=23, group_count=18, objects=objects,
                passages={room["id"]: room["passages"] for room in load_layout()["rooms"]},
                status="Pre-build placements; actual furnish/native capsule validation required")


def emit_prop(sc, instance_id: str, object_group: dict, room: dict, pose: tuple,
              materials: dict, layout_mode: str) -> None:
    """Approved Intake theatre table only; every other recipe delegates to v6.

    Solid segmented enamel top, central pedestal and low T-base all remain
    within the existing 2.4 x 1.1 x .9m envelope. No mattress or ward headboard.
    """
    from room_program_v6 import _emit_prop

    if (sc.stage.get("campaign_level_id") != LEVEL_ID or room["id"] != "key_console"
            or object_group["type"] != "surgical_table"):
        return _emit_prop(sc, instance_id, object_group, room, pose, materials, layout_mode)
    lx, lz, heading = pose
    x, y, z = room["center"]
    root = "RoomProp_" + instance_id.replace(".", "_")
    metadata = ("position = Vector3(%s, %s, %s)\nrotation_degrees = Vector3(0,%s,0)"
                "\nmetadata/room_program_object = %s\nmetadata/prop_type = %s"
                "\nmetadata/room_function = %s\nmetadata/layout_mode = %s") % (
                    x+lx, y, z+lz, heading, json.dumps(instance_id), json.dumps("surgical_table"),
                    json.dumps(room["function"]), json.dumps(layout_mode))
    sc.node(root, "Node3D", props=metadata)
    shell = materials["shell"]
    face = materials["by_type"].get("surgical_table", materials["face"])

    def box(name, at, size, material=shell):
        sc.box(name, at, size, material, True, root, hit_material="armor")

    box("TBaseSpine", (0,.07,0), (1.7,.14,.32))
    for side in (-1, 1):
        box("TBaseFoot"+str(side), (side*.65,.06,0), (.20,.12,1.0))
    box("CentralPedestal", (0,.39,0), (.42,.66,.52))
    box("TopSupport", (0,.67,0), (2.4,.10,1.1))
    for index, at_x in enumerate((-.8, 0, .8)):
        box("EnamelSegment"+str(index), (at_x,.81,0), (.76,.18,1.02), face)
