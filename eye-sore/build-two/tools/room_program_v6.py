"""Deterministic campaign room-program validation and authoring helpers.

The authored level manifest supplies room functions and physical object recipes.
This module checks progression before any scene is built, then applies only
explicit room data. No random placement or route inference belongs here.
"""
from __future__ import annotations

import json
from pathlib import Path


MANIFEST = Path(__file__).resolve().parents[1] / "docs/room-program-v6/levels.json"


def load_program(path: Path = MANIFEST) -> dict[str, dict]:
    raw = json.loads(path.read_text())
    assert raw["schema_version"] == 1, (path, "unsupported room programme")
    levels = {level["id"]: level for level in raw["levels"]}
    assert len(levels) == 9 and len(raw["levels"]) == 9, (path, "campaign level count")
    return levels


def validate_level_program(stage: dict, programme: dict) -> dict:
    """Match curated room/function inventory to the actual gated stage graph."""
    assert programme["id"] == stage["campaign_level_id"]
    assert programme["theme"] == stage["id"]
    actual_rooms = {room["id"] for room in stage["rooms"]}
    planned_rooms = {room["id"] for room in programme["rooms"]}
    assert len(planned_rooms) == len(programme["rooms"]), (programme["id"], "duplicate room")
    assert planned_rooms == actual_rooms, (programme["id"], "room mismatch", sorted(planned_rooms - actual_rooms), sorted(actual_rooms - planned_rooms))
    object_ids: set[str] = set()
    object_total = 0
    for room in programme["rooms"]:
        assert room["label"] and room["function"] and room["layout_mode"] and room["light_family"]
        if "authored_size_xz" in room:
            dimensions = room["authored_size_xz"]
            assert len(dimensions) == 2 and all(isinstance(value, (int, float)) and value >= 10 for value in dimensions)
            actual = next(item for item in stage["rooms"] if item["id"] == room["id"])
            assert actual["size"][0] == dimensions[0] and actual["size"][2] == dimensions[1], (programme["id"], room["id"], "authored footprint")
        assert room["objects"], (programme["id"], room["id"], "empty room programme")
        for obj in room["objects"]:
            assert obj["id"] not in object_ids, (programme["id"], "duplicate object", obj["id"])
            assert obj["id"].startswith(programme["id"] + "." + room["id"] + ".")
            assert isinstance(obj["count"], int) and obj["count"] > 0
            assert obj["type"] and obj["purpose"] and obj["placement"]
            object_ids.add(obj["id"]); object_total += obj["count"]
    actual_buttons = {button["id"]: button for button in stage["buttons"]}
    actual_keys = {key["id"]: key for key in stage["keys"]}
    actual_gates = {portal["gate"]: portal for portal in stage["portals"] if portal.get("gate")}
    planned = {obj["id"]: obj for obj in programme["progression_objects"]}
    assert len(planned) == len(programme["progression_objects"]) == 8, (programme["id"], "progression inventory")
    assert set(planned) == set(actual_buttons) | set(actual_keys) | {"brass_gate", "red_gate", "exit"}, (programme["id"], "progression ids")
    for id, button in actual_buttons.items():
        item = planned[id]
        assert item["type"] == "switch" and item["room"] == button["room"]
        assert button["sets"] in item["sets"]
        assert "clear_" + button["arena"] in item["requires"]
        assert item["opens"][0] in actual_gates
    for id, key in actual_keys.items():
        item = planned[id]
        assert item["type"] == "key" and item["room"] == key["room"] and id in item["sets"]
        assert item["opens"][0] in actual_gates
    for id in ("brass_gate", "red_gate"):
        item = planned[id]
        assert item["type"] == "gate" and id in actual_gates
        assert set(item["requires"]) == set(actual_gates[id]["requires"]), (programme["id"], id, "gate requirements")
        assert item["leads_to"] == actual_gates[id]["to"]
    assert planned["exit"]["type"] == "exit"
    assert planned["exit"]["room"] == stage["exit"]["room"]
    assert set(planned["exit"]["requires"]) == set(stage["exit"]["requires"])
    solved = validate_progression(stage)
    return {
        "id": programme["id"], "rooms": len(planned_rooms),
        "furnishing_instances": object_total, "furnishing_groups": len(object_ids),
        "progression_objects": len(planned),
        "arena_modes": {room["id"]: room["layout_mode"] for room in programme["rooms"] if room["id"].startswith("arena") or room["id"] == "final_arena"},
        "gated_reachability": solved,
    }


# Width, depth and height are the collision footprint of each room fitting.
# Silhouette names select authored subassemblies below; all 58 manifest types
# are covered explicitly so a typo cannot quietly become a generic crate.
SHAPES: dict[str, tuple[str, float, float, float]] = {}
for _type in ("medical_bed", "isolation_bed", "surgical_table", "cot", "sarcophagus"):
    SHAPES[_type] = ("bed", 2.4, 1.1, .9 if _type != "sarcophagus" else 1.2)
for _type in ("waiting_bench", "station_bench", "stone_bench", "choir_stall"):
    SHAPES[_type] = ("bench", 1.9, .65, 1.1)
for _type in ("intake_desk", "instrument_bench", "guard_table", "scribe_desk", "dispatch_desk", "reception_desk", "office_desk", "workbench"):
    SHAPES[_type] = ("desk", 1.9, .95, 1.1)
for _type in ("records_cabinet", "medical_cabinet", "tool_cabinet", "ppe_locker", "specimen_fridge", "file_cabinet", "safety_locker", "relay_cabinet", "server_rack"):
    SHAPES[_type] = ("cabinet", 1.25, .72, 2.35)
for _type in ("sample_rack", "scroll_shelf", "ossuary_rack", "weapon_rack"):
    SHAPES[_type] = ("rack", 1.7, .65, 2.2)
for _type in ("scan_console", "containment_console", "security_console", "broken_console", "signal_panel", "route_display", "vital_monitor"):
    SHAPES[_type] = ("console", 1.4, .72, 1.7)
for _type in ("pump_rig", "chain_winch", "generator", "forklift_station"):
    SHAPES[_type] = ("machine", 1.9, 1.45, 2.45)
for _type in ("specimen_tank", "turbine"):
    SHAPES[_type] = ("cylinder", 1.8 if _type == "specimen_tank" else 2.3, 1.8 if _type == "specimen_tank" else 2.3, 3.2)
for _type in ("forge_hearth", "reliquary", "anvil", "ticket_kiosk"):
    SHAPES[_type] = ("monument", 1.65, 1.15, 2.0)
for _type in ("privacy_screen", "decon_frame", "banner_standard", "barricade"):
    SHAPES[_type] = ("partition", 2.1 if _type != "banner_standard" else .4, .35 if _type != "banner_standard" else .4, 2.7)
for _type in ("supply_cart", "supply_crate", "freight_crate", "cable_drum"):
    SHAPES[_type] = ("cargo", 1.3, 1.1, 1.25)
for _type in ("filter_unit", "pipe_manifold", "surgical_lamp"):
    SHAPES[_type] = ("fixture", 1.4, .62, 2.1)


MODE_WALL_ORDER = {
    "bed_bays": "SNSWEW", "split_isolation": "NSSNWE", "transfer_bays": "SNEWNS",
    "reservoir_ring": "NESWNESW", "surgical_rows": "NSNSWE", "pump_banks": "EWEWNS",
    "tall_silo_clusters": "NESWNESW", "broken_bays": "SNWENS", "excavation_sides": "EWEWNS",
    "cloister_seating": "NESWNESW", "forge_banks": "EWEWNS", "rampart_recesses": "SNESWN",
    "choir_stalls": "NSNSWE", "altar_recesses": "SNEWNS", "bellows_banks": "EWEWNS",
    "reliquary_niches": "WENSWE", "vault_banks": "NSWEWE", "conduit_works": "EWEWNS",
    "platform_furniture": "NSNSWE", "relay_banks": "EWEWNS", "freight_stacks": "SWNENS",
    "public_service_bays": "SNESWN", "security_desks": "NSWEWE", "machine_banks": "EWEWNS",
    "turbine_banks": "NESWNESW", "reactor_banks": "WENSSNEW", "core_service_bays": "SNEWNS",
}


def _candidates(room: dict, mode: str, width: float, depth: float):
    sx, _, sz = room["size"]
    # Alternating fitted perimeter bays retain the visible central crossing.
    # Arena modes change bank orientation and ordering, not just labels.
    walls = MODE_WALL_ORDER.get(mode, "WESN")
    fractions = (-.66, .66, -.34, .34, 0.0, -.84, .84, -.17, .17, -.5, .5)
    for inset in (.75, 3.75, 6.75):
        for rank in range(len(fractions)):
            for wall in walls:
                f = fractions[rank]
                if wall in "NS":
                    x = f * (sx / 2)
                    z = (-1 if wall == "N" else 1) * (sz / 2 - depth / 2 - inset)
                    heading = 0 if wall == "N" else 180
                else:
                    x = (-1 if wall == "W" else 1) * (sx / 2 - depth / 2 - inset)
                    z = f * (sz / 2)
                    heading = 90 if wall == "W" else -90
                yield (x, z, heading)


def _overlap(a, b, gap=0.0) -> bool:
    return abs(a[0] - b[0]) < (a[2] + b[2]) / 2 + gap and abs(a[1] - b[1]) < (a[3] + b[3]) / 2 + gap


def rid_is_arena(room_id: str) -> bool:
    return room_id in ("arena_one", "arena_two", "final_arena")


def _portal_reservations(room_id: str, routes: list[dict], stage: dict) -> list[tuple[float, float, float, float]]:
    room = next(r for r in stage["rooms"] if r["id"] == room_id)
    x, _, z = room["center"]
    result = []
    for route in routes:
        if route["from"] != room_id and route["to"] != room_id: continue
        point = route["start"] if route["from"] == room_id else route["end"]
        axis = route["axis"]
        if axis == 0:
            result.append(((point[0] + x) / 2, point[2], abs(point[0] - x) + 1.2, route["width"] + 2.4))
        else:
            result.append((point[0], (point[2] + z) / 2, route["width"] + 2.4, abs(point[2] - z) + 1.2))
    return result


def combat_flanks_for_room(room: dict, theme: str) -> list[list[float]]:
    """The one authored flank contract used by both route JSON and prop clearance."""
    x, y, z = room["center"]
    side_margin = 5 if theme == "pale_ward" and room["id"] == "final_arena" and room["size"][0] < 36 else 7
    outer = room["size"][0] / 2 - side_margin
    return [[x + side*lane, y, z + offset]
            for side in (-1, 1)
            for lane, offset in [(4.3, 0), (outer, 0)] + [(outer, slot) for slot in (-9, -3, 3, 9)]]


def _static_reservations(room: dict, stage: dict, routes: list[dict], vertical_routes: dict) -> list[tuple[float, float, float, float]]:
    rid = room["id"]; x, _, z = room["center"]
    reserved = _portal_reservations(rid, routes, stage)
    if stage.get('campaign_level_id') == 'pale_ward_01' and rid == 'arena_one':
        reserved.extend(tuple(rect) for rect in stage.get('intake_v7_clearance', []))
    if rid in ("arena_one", "arena_two", "final_arena"):
        # The two proven combat lanes, raised gallery and enemy closet flanks
        # remain physically traversable while fitted bays occupy the edge.
        for lane in (-4.3, 4.3):reserved.append((x + lane, z, 1.2, 22))
        reserved.append((x - 7, z, 4.8, room["size"][2] - 4))
        for side in (-1, 1):
            for slot in range(4):
                reserved.append((x + side * (room["size"][0]/2 - 2.4), z - 9 + slot*6, 4.5, 4.6))
            reserved.append((x + side*9, z+6, 4.2, 5.5))
        reserved.append((x + 4.5, z - room["size"][2]/2 + 3, 3, 2.2))
        reserved.append((x, z, 4.0, 5.0))
        # The retreat path may leave an altar at either far end before
        # crossing laterally onto the outer flank. The authored route uses
        # these same outer x coordinates; keep its entire longitudinal rail
        # and both staging connectors clear for a CharacterBody radius plus
        # 1.2 m of maneuvering room.
        flanks = combat_flanks_for_room(room, stage["id"])
        for side in (-1, 1):
            flank = next(abs(point[0]-x) for point in flanks if (point[0]-x)*side > 5)
            # The continuous combat driver widens narrow final-arena retreats
            # to twelve metres. Protect both its widened lane and the exact
            # authored combat_flanks coordinate without changing route data.
            for outer in sorted({flank, max(12.0, flank)}):
                reserved.append((x + side*outer, z, 2.4, room["size"][2]-1.0))
                middle = x + side*(4.3 + outer)/2
                for end in (-1, 1):
                    connector_z = z + end*(room["size"][2]/2-2.5)
                    reserved.append((middle, connector_z, outer-4.3+2.4, 2.4))
    else:
        reserved.append((x, z, 3.2, 4.0))
        count = stage["enemy_counts"].get(rid, 0)
        sx = room["size"][0]
        for index in range(count):
            spawn_x = x + ((index % 3) - 1) * min(5, sx / 4)
            spawn_z = z + (index // 3 - 1) * 4.0
            reserved.append((spawn_x, spawn_z, 1.6, 1.6))
    if rid == "entry":reserved.append((x, z + stage["spawn_local"][2], 4, 4))
    if rid in {key["room"] for key in stage["keys"]}:reserved.append((x, z-3, 3, 3))
    if rid == stage["exit"]["room"]:reserved.append((x, z-room["size"][2]/2+2, 3, 3))
    for name, points in vertical_routes.items():
        if not (name.startswith(rid + "_") or rid == "service" and name == "service_balcony"):
            continue
        tread_width = 4.0 if name.endswith("_altar") else 2.4 if name == "service_balcony" else 3.6
        # The manifest route includes the upper walk and both stair feet.
        # Reserve each segment's full projected tread, plus 1.2 m on either
        # side and an extra landing step at each end for real body turns.
        for a, b in zip(points, points[1:]):
            reserved.append(((a[0]+b[0])/2, (a[2]+b[2])/2,
                             abs(a[0]-b[0])+tread_width+2.4,
                             abs(a[2]-b[2])+tread_width+2.4))
        for point in (points[0], points[-1]):
            reserved.append((point[0],point[2],tread_width+2.4,tread_width+6.0))
    return reserved


def setup_materials(sc, theme: str) -> dict[str, str]:
    """Bind all 16 curator-approved native atlas regions without resampling."""
    atlas = Path(__file__).resolve().parents[1] / "assets/materials/room-props-v6" / (theme + "-atlas.png")
    fallback = {
        "shell": "steel" if theme != "ash_citadel" else "wall",
        "face": "panel" if theme != "ash_citadel" else "damaged",
        "soft": "cloth" if theme == "pale_ward" else "recess",
        "dark": "recess", "light": "glow", "hazard": "invasion" if theme == "pale_ward" else "orange",
    }
    if not atlas.exists(): return dict(fallback, by_type={})
    import struct
    data = atlas.read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", atlas
    width, height = struct.unpack(">II", data[16:24])
    atlas_record = json.loads((atlas.parents[3] / "concepts/pickups-rooms-v6/props-generation.json").read_text())
    record = next(item for item in atlas_record["atlases"] if item["theme"] == theme)
    assert record["dimensions"] == [width, height] and len(record["regions"]) == 16
    shader_header = '[ext_resource type="Shader" path="res://shaders/room_prop_local_uv.gdshader" id="room_prop_uv_shader"]'
    if shader_header not in sc.ext:
        sc.ext.append(shader_header)
    names = []
    for index, cell in enumerate(record["regions"]):
        assert cell["slot"] == index
        name = "room_prop_" + str(index)
        # BoxMesh uses six distinct 1/3 x 1/2 UV cells; the dedicated shader
        # normalizes each face before sampling the approved atlas region.
        # Cylinders retain the ordinary native 0..1 mesh UVs.
        ext = "room_prop_atlas_" + theme
        header = '[ext_resource type="Texture2D" path="res://' + str(atlas.relative_to(atlas.parents[3])) + '" id="' + ext + '"]'
        if header not in sc.ext:
            sc.ext.append(header)
        for suffix, box_unwrap in (("", "true"), ("_cyl", "false")):
            sc.sub.append('[sub_resource type="ShaderMaterial" id="' + name + suffix + '"]\n'
                          'shader = ExtResource("room_prop_uv_shader")\n'
                          'shader_parameter/painted_surface = ExtResource("' + ext + '")\n'
                          'shader_parameter/source_region_pixels = Vector4(' + ', '.join(map(str, cell["region"])) + ')\n'
                          'shader_parameter/box_mesh_uv = ' + box_unwrap + '\n')
        names.append(name)
    base_slots = {
        "pale_ward": (0,1,2,7,5,9),
        "ash_citadel": (3,0,2,5,4,15),
        "occupied_line": (0,1,2,7,5,3),
    }
    result = {key:names[index] for key,index in zip(("shell","face","soft","dark","light","hazard"),base_slots[theme])}
    semantic_types = {
        "pale_ward": {1:("medical_cabinet","records_cabinet","tool_cabinet","ppe_locker"),2:("medical_bed","isolation_bed"),3:("privacy_screen",),4:("instrument_bench","sample_rack"),5:("scan_console","containment_console","security_console","vital_monitor"),6:("specimen_tank",),7:("pump_rig","pipe_manifold"),8:("filter_unit","decon_frame"),10:("specimen_fridge",),11:("intake_desk",),13:("surgical_lamp",),14:("broken_console",),15:("surgical_table",)},
        "ash_citadel": {1:("reliquary",),2:("banner_standard",),3:("barricade",),4:("forge_hearth",),5:("stone_bench","cot","guard_table"),6:("weapon_rack",),7:("sarcophagus",),8:("ossuary_rack",),9:("scribe_desk",),10:("chain_winch",),11:("anvil",),12:("choir_stall",),13:("supply_crate",),14:("scroll_shelf",)},
        "occupied_line": {1:("safety_locker",),2:("station_bench",),3:("barricade",),4:("ticket_kiosk",),5:("route_display",),6:("signal_panel",),7:("server_rack",),8:("relay_cabinet",),9:("dispatch_desk","office_desk","reception_desk"),10:("generator",),11:("turbine",),12:("freight_crate",),13:("cable_drum",),14:("file_cabinet",),15:("workbench",)},
    }
    result["by_type"] = {typ:names[index] for index, types in semantic_types[theme].items() for typ in types}
    return result


def _emit_prop(sc, name: str, obj: dict, room: dict, at: tuple[float, float, int], materials: dict[str, str], mode: str) -> None:
    """Create one fitted, collidable 3D object and smaller matched detail parts."""
    typ = obj["type"]
    silhouette, width, depth, height = SHAPES[typ]
    lx, lz, heading = at
    x, y, z = room["center"]
    root = "RoomProp_" + name.replace(".", "_")
    metadata = ("position = Vector3(%s, %s, %s)\nrotation_degrees = Vector3(0,%s,0)"
                "\nmetadata/room_program_object = %s\nmetadata/prop_type = %s"
                "\nmetadata/room_function = %s\nmetadata/layout_mode = %s") % (
                    x + lx, y, z + lz, heading, json.dumps(name), json.dumps(typ),
                    json.dumps(room["function"]), json.dumps(mode))
    sc.node(root, "Node3D", props=metadata)
    shell, _, soft, dark, light, hazard = (materials[k] for k in ("shell", "face", "soft", "dark", "light", "hazard"))
    face = materials["by_type"].get(typ, materials["face"])
    impact = "armor" if silhouette in {"cabinet", "rack", "console", "machine", "cylinder", "fixture"} or typ in {"decon_frame", "medical_bed", "isolation_bed", "surgical_table"} else "hard"
    def box(part, pos, size, mat=shell, solid=True):
        sc.box(part, pos, size, mat, solid, root, hit_material=impact)
    def cylinder(part, pos, radius, tall, mat=shell, solid=True):
        sc.cylinder(part, pos, radius, tall, mat + "_cyl" if mat.startswith("room_prop_") else mat, solid, root)
    if silhouette == "bed":
        box("Frame", (0,.46,0), (width,.34,depth), shell)
        if typ != "sarcophagus":box("Mattress", (0,.68,0), (width-.18,.12,depth-.12), soft, False)
        box("Headboard", (-width/2+.08,.8,0), (.16,.8,depth), shell)
        for side in (-1,1):box("Leg"+str(side), (side*(width/2-.22),.23,0), (.22,.46,depth-.18), dark)
        if typ == "sarcophagus":box("Lid", (0,.96,0), (width-.12,.16,depth-.08), face)
    elif silhouette == "bench":
        box("Seat", (0,.55,0), (width,.22,depth), shell)
        box("SeatCover", (0,.675,0), (width-.1,.025,depth-.08), face, False)
        box("Back", (0,.9,-depth/2+.08), (width,.72,.16), shell)
        for side in (-1,1):box("Leg"+str(side), (side*(width/2-.18),.26,0), (.18,.52,depth-.08), dark)
    elif silhouette == "desk":
        box("Top", (0,.78,0), (width,.18,depth), shell)
        for side in (-1,1):box("CabinetLeg"+str(side), (side*(width/2-.28),.34,0), (.5,.68,depth-.12), shell)
        box("WorkPad", (0,.89,0), (width*.58,.025,depth*.55), face, False)
        if "surgical" in typ or "instrument" in typ:box("InstrumentTray", (width*.28,.95,0), (.45,.08,.48), shell, False)
    elif silhouette == "cabinet":
        box("Body", (0,height/2,0), (width,height,depth), shell)
        for side in (-1,1):
            box("Door"+str(side), (side*width*.24,height*.51,depth/2+.012), (width*.46,height*.86,.025), face, False)
            box("Pull"+str(side), (side*width*.07,height*.53,depth/2+.04), (.055,.26,.035), light, False)
        box("Crown", (0,height-.08,0), (width+.12,.16,depth+.08), dark, False)
    elif silhouette == "rack":
        for side in (-1,1):box("Post"+str(side), (side*(width/2-.06),height/2,0), (.12,height,depth), shell)
        for shelf in range(3):
            level = .4+shelf*.72
            box("Shelf"+str(shelf), (0,level,0), (width,.12,depth), shell)
            box("Contents"+str(shelf), (0,level+.16,depth*.28), (width*.78,.22,depth*.3), face, False)
        if typ == "weapon_rack":
            for slot in (-1,0,1):box("WeaponSilhouette"+str(slot), (slot*.43,1.45,depth/2+.02), (.12,.92,.08), dark, False)
    elif silhouette == "console":
        box("Pedestal", (0,.58,0), (width,1.16,depth), shell)
        box("ControlFace", (0,1.24,depth/2+.05), (width*.82,.54,.1), dark, False)
        box("Screen", (0,1.28,depth/2+.11), (width*.62,.30,.025), face, False)
        for side in (-1,1):box("Key"+str(side), (side*.35,1.17,depth/2+.11), (.11,.07,.03), dark, False)
    elif silhouette == "machine":
        box("MachineBase", (0,.46,0), (width,.92,depth), shell)
        box("MotorHousing", (0,1.52,0), (width*.76,1.35,depth*.75), dark)
        box("InstrumentPanel", (0,1.59,depth*.39), (width*.55,.72,.04), face, False)
        cylinder("Rotor", (0,1.44,depth*.34), min(width,depth)*.24, .24, dark, False)
        for side in (-1,1):box("Pipe"+str(side), (side*(width/2-.2),1.5,0), (.18,1.6,.18), hazard, False)
    elif silhouette == "cylinder":
        cylinder("Vessel", (0,height/2,0), width/2, height, shell)
        box("Window", (0,height*.55,depth/2+.025), (width*.65,height*.55,.05), face, False)
        for band in (.35,height-.35):cylinder("Band"+str(band), (0,band,0), width*.54, .16, dark, False)
        if typ == "turbine":box("PowerBlade", (0,height*.54,depth/2+.04), (width*.68,.26,.12), hazard, False)
    elif silhouette == "monument":
        box("Plinth", (0,.28,0), (width,.56,depth), shell)
        box("Core", (0,1.2,0), (width*.7,1.4,depth*.72), shell)
        box("ReliefFace", (0,1.25,depth*.39), (width*.56,1.1,.045), face, False)
        box("Crest", (0,1.96,0), (width*.83,.22,depth*.86), dark, False)
        if typ == "forge_hearth":box("EmberBed", (0,.67,depth/2+.02), (width*.65,.2,.16), hazard, False)
    elif silhouette == "partition":
        if typ == "decon_frame":
            for side in (-1,1):box("Jamb"+str(side), (side*(width/2-.12),height/2,0), (.24,height,depth), shell)
            box("Lintel", (0,height-.12,0), (width,.24,depth), face)
            box("Indicator", (0,height-.55,depth/2+.04), (.42,.12,.035), light, False)
        elif typ == "banner_standard":
            box("Pole", (0,height/2,0), (.12,height,.12), shell)
            box("Banner", (0,height*.68,.1), (.74,1.2,.055), soft, False)
        else:
            box("Screen", (0,height/2,0), (width,height,depth), face)
            box("EdgeBand", (0,height-.12,0), (width+.08,.24,depth+.04), shell, False)
    elif silhouette == "cargo":
        box("Cargo", (0,height/2,0), (width,height,depth), shell)
        box("FrontPanel", (0,height/2,depth/2+.025), (width*.84,height*.78,.05), face, False)
        for side in (-1,1):box("Strap"+str(side), (side*width*.28,height/2,depth/2+.02), (.09,height,.035), dark, False)
    elif silhouette == "fixture":
        box("Bracket", (0,2.15,-depth*.3), (width*.7,.2,depth*.45), shell)
        box("Fitting", (0,1.78,0), (width,1.05,depth), shell)
        box("Readout", (0,1.9,depth/2+.02), (width*.54,.55,.025), face, False)
    else:
        raise AssertionError((typ, silhouette))


def furnish(sc, stage: dict, programme: dict, routes: list[dict], vertical_routes: dict, obstacles: list[dict]) -> dict:
    """Place typed fittings in checked perimeter bays; report rejected counts."""
    materials = setup_materials(sc, stage["id"])
    by_room = {r["id"]: r for r in stage["rooms"]}
    placed: list[dict] = []; rejected: list[dict] = []; bay_lights: list[dict] = []
    for planned_room in programme["rooms"]:
        room = dict(by_room[planned_room["id"]]); room.update({k:planned_room[k] for k in ("label","function","layout_mode","light_family")})
        x,y,z = room["center"]; sx,_,sz = room["size"]
        reserved = _static_reservations(room,stage,routes,vertical_routes)
        for object_group in planned_room["objects"]:
            typ = object_group["type"]
            assert typ in SHAPES, (programme["id"], typ, "missing physical recipe")
            silhouette,w,d,h = SHAPES[typ]
            for ordinal in range(1,object_group["count"]+1):
                selected = None; reason = "no safe perimeter bay"
                authored = object_group.get('authored_positions', []) if stage.get('campaign_level_id') == 'pale_ward_01' else []
                candidates = [authored[ordinal-1]] if ordinal <= len(authored) else _candidates(room, planned_room["layout_mode"], w, d)
                for lx,lz,heading in candidates:
                    rw,rd = (d,w) if abs(heading)==90 else (w,d)
                    footprint = (x+lx,z+lz,rw,rd)
                    if abs(lx)+rw/2 > sx/2-.35 or abs(lz)+rd/2 > sz/2-.35:
                        reason = "outside room footprint"; continue
                    if any(_overlap(footprint, area) for area in reserved):
                        reason = "reserved portal/nav/mechanism lane"; continue
                    if any(_overlap(footprint, (item["x"],item["z"],item["w"],item["d"]),.28) for item in placed if item["room"]==room["id"]):
                        reason = "occupied furnishing bay"; continue
                    # AABB check against pre-existing authored fixtures, with
                    # vertical separation so wall-mounted fittings can coexist.
                    collision = False
                    for obstacle in obstacles:
                        if obstacle["max_y"] <= y+.02 or obstacle["min_y"] >= y+h-.02:continue
                        if _overlap(footprint,(obstacle["x"],obstacle["z"],obstacle["w"],obstacle["d"]),.08):
                            collision = True;break
                    if collision:
                        reason = "existing physical fixture"; continue
                    selected=(lx,lz,heading,rw,rd);break
                instance_id = object_group["id"] + "." + str(ordinal)
                if selected is None:
                    rejected.append({"id":instance_id,"room":room["id"],"type":typ,"reason":reason})
                    continue
                lx,lz,heading,rw,rd=selected
                _emit_prop(sc,instance_id,object_group,room,(lx,lz,heading),materials,planned_room["layout_mode"])
                placed.append({"id":instance_id,"room":room["id"],"type":typ,
                               "x":x+lx,"z":z+lz,"w":rw,"d":rd,"height":h,
                               "heading":heading})
        # A few unshadowed luminaires belong to the occupied perimeter bays,
        # not to individual objects. This keeps clinical, ember and civic
        # equipment legible from the actual approach while retaining contrast.
        groups: dict[str, list[dict]] = {side: [] for side in "NSEW"}
        for item in placed:
            if item["room"] != room["id"]:continue
            dx = item["x"]-x; dz = item["z"]-z
            side = ("E" if dx > 0 else "W") if abs(dx)/sx >= abs(dz)/sz else ("S" if dz > 0 else "N")
            groups[side].append(item)
        palette = {
            "clinical_sick_green": ((.72, .91, .78, 1), 2.5),
            "ember_warm": ((1.0, .63, .35, 1), 2.7),
            "cold_civic": ((.70, .84, 1.0, 1), 2.6),
        }
        tint, energy = palette[planned_room["light_family"]]
        limit = 4 if rid_is_arena(room["id"]) else 2
        candidates = sorted(((len(items), side, items) for side, items in groups.items() if items), reverse=True)
        for _, side, items in candidates[:limit]:
            mean_x = sum(item["x"] for item in items)/len(items)
            mean_z = sum(item["z"] for item in items)/len(items)
            # Recess toward the walkable bay face; the fitting remains under
            # the pool without hiding the light behind its own tall housing.
            px = mean_x + (.7 if side == "W" else -.7 if side == "E" else 0)
            pz = mean_z + (.7 if side == "N" else -.7 if side == "S" else 0)
            name = "RoomBayLight_" + room["id"] + "_" + side
            sc.light(name, (px, y+3.4, pz), tint, energy, 14)
            bay_lights.append({"room":room["id"],"name":name,"position":[px,y+3.4,pz],"family":planned_room["light_family"]})
    assert len(placed)+len(rejected)==sum(o["count"] for r in programme["rooms"] for o in r["objects"])
    room_counts = []
    for planned_room in programme["rooms"]:
        room_id = planned_room["id"]
        room_placed = [item for item in placed if item["room"] == room_id]
        room_rejected = [item for item in rejected if item["room"] == room_id]
        room_counts.append({
            "room": room_id,
            "function": planned_room["function"],
            "layout_mode": planned_room["layout_mode"],
            "planned": sum(item["count"] for item in planned_room["objects"]),
            "placed": len(room_placed),
            "rejected": len(room_rejected),
            "rejection_reasons": sorted({item["reason"] for item in room_rejected}),
        })
    return {"id":programme["id"],"placed_count":len(placed),"rejected_count":len(rejected),
            "rooms":room_counts,"placements":placed,"rejected":rejected,"bay_lights":bay_lights}

def progression_inventory(stage: dict) -> dict:
    """Describe the physical progression objects already required by a map."""
    return {
        "entry": stage["spawn_room"],
        "keys": [
            {"id": key["id"], "room": key["room"], "label": key["label"]}
            for key in stage["keys"]
        ],
        "controls": [
            {
                "id": button["id"], "room": button["room"],
                "arena": button["arena"], "sets": button["sets"],
                "label": button["label"],
            }
            for button in stage["buttons"]
        ],
        "gates": [
            {
                "id": portal["gate"], "from": portal["from"],
                "to": portal["to"], "requires": list(portal.get("requires", [])),
            }
            for portal in stage["portals"] if portal.get("gate")
        ],
        "arenas": [
            {"id": room["arena_id"], "room": room["id"],
             "enemies": stage["enemy_counts"].get(room["id"], 0)}
            for room in stage["rooms"] if room.get("arena_id")
        ],
        "weapon_caches": [
            {"room": room, "weapon": spec["weapon"], "ammo": spec["ammo"]}
            for room, spec in stage["weapon_cache"].items()
        ],
        "exit": dict(stage["exit"]),
    }


def validate_progression(stage: dict) -> dict:
    """Solve room/key/control reachability without assuming a secret route.

    Entering an arena represents its encounter being clearable. The solver
    collects its clear flag before the corresponding physical control can be
    operated. It never treats a locked portal as open before its flag exists.
    """
    room_ids = {room["id"] for room in stage["rooms"]}
    start = stage["spawn_room"]
    assert start in room_ids, (stage["id"], "missing entry", start)
    for portal in stage["portals"]:
        assert portal["from"] in room_ids and portal["to"] in room_ids, (stage["id"], portal)
    for key in stage["keys"]:
        assert key["room"] in room_ids, (stage["id"], key)
    for button in stage["buttons"]:
        assert button["room"] in room_ids and button["arena"] in room_ids, (stage["id"], button)
    assert stage["exit"]["room"] in room_ids, (stage["id"], "missing exit")

    room_arena = {room["id"]: room.get("arena_id", "") for room in stage["rooms"]}
    flags: set[str] = set()
    visited: set[str] = {start}
    waves: list[dict] = []
    while True:
        new_flags: set[str] = set()
        for key in stage["keys"]:
            if key["room"] in visited: new_flags.add(key["id"])
        for room in visited:
            if room_arena[room]: new_flags.add("clear_" + room_arena[room])
        for button in stage["buttons"]:
            if button["room"] in visited and "clear_" + button["arena"] in flags | new_flags:
                new_flags.add(button["sets"])
        new_flags -= flags
        flags |= new_flags
        reached: set[str] = set()
        for portal in stage["portals"]:
            if portal.get("secret") or not set(portal.get("requires", [])).issubset(flags):
                continue
            if portal["from"] in visited: reached.add(portal["to"])
            if portal["to"] in visited: reached.add(portal["from"])
        reached -= visited
        if not new_flags and not reached: break
        visited |= reached
        waves.append({"new_rooms": sorted(reached), "new_flags": sorted(new_flags)})

    needed = {stage["exit"]["room"]} | {key["room"] for key in stage["keys"]}
    needed |= {button["room"] for button in stage["buttons"]}
    needed |= {room["id"] for room in stage["rooms"] if room.get("arena_id")}
    assert needed.issubset(visited), (stage["id"], "unreachable progression rooms", sorted(needed - visited))
    assert set(stage["exit"].get("requires", [])).issubset(flags), (
        stage["id"], "exit requirements unreachable", sorted(set(stage["exit"].get("requires", [])) - flags)
    )
    return {"inventory": progression_inventory(stage), "reachable_rooms": sorted(visited),
            "obtained_flags": sorted(flags), "waves": waves}
