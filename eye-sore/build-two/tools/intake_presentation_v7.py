"""Additive, room-relative Intake presentation using existing native materials.

Call decorate(sc) once after ordinary room_program_v6.furnish. This module
never writes files or alters authored room/progression/pickup data.
"""
from __future__ import annotations

import json
import re

ROOMS = ("entry", "service", "arena_one", "key_wing", "key_console", "return_store")
FUNCTIONS = dict(zip(ROOMS, ("patient_intake", "decontamination", "emergency_triage", "diagnostics", "operating_theatre", "sterile_supply")))


def _v(value):
    return "Vector3(" + ", ".join(f"{x:.6g}" for x in value) + ")"


def _fitting_position(sc, room_id, prop_type):
    """Find actual authored fitting, not an assumed original room coordinate."""
    prefix = sc.stage["campaign_level_id"] + "." + room_id + "."
    for node in sc.nodes:
        if 'metadata/prop_type = ' + json.dumps(prop_type) not in node or prefix not in node:
            continue
        match = re.search(r"position = Vector3\(([^)]+)\)", node)
        if match:
            return tuple(float(value.strip()) for value in match[1].split(","))
    return None


def decorate(sc):
    """Return an inspectable placement record; no-op for all other maps.

    Physical parts use Scene.box/cylinder's matching visible and collision
    dimensions. Only small lens inlays are non-solid, nested within housings.
    All coordinates are reconstructed from the final stage on every call.
    """
    if sc.stage.get("campaign_level_id") != "pale_ward_01":
        return {"applied": False, "reason": "Intake only"}
    assert not getattr(sc, "_intake_presentation_v7_applied", False), "decorate(sc) called twice"
    sc._intake_presentation_v7_applied = True
    # Furnish already registered native atlas ShaderMaterials. Do not invoke
    # setup_materials twice, which would duplicate the same sub-resource IDs.
    assert any('id="room_prop_13"' in resource for resource in sc.sub), "call after room fittings"
    rooms = {room["id"]: room for room in sc.stage["rooms"]}
    assert all(key in rooms for key in ROOMS)
    sc.mat("intake_v7_warm_lens", (.72, .61, .43, 1), 1.6)
    sc.mat("intake_v7_cold_lens", (.56, .69, .64, 1), 1.35)
    records = []
    captures = []
    light_count = 0

    for rid in ROOMS:
        room = rooms[rid]
        cx, fy, cz = room["center"]
        sx, height, sz = room["size"]
        assert height >= 5, (rid, "presentation requires at least five metres overhead")
        parent = "IntakePresentation_" + rid
        sc.node(parent, props="position = " + _v((cx, fy, cz)) +
                '\nmetadata/presentation_v7 = true\nmetadata/room_id = ' + json.dumps(rid) +
                '\nmetadata/room_function = ' + json.dumps(FUNCTIONS[rid]))

        def box(name, at, size, mat="steel", solid=True):
            sc.box(name, at, size, mat, solid, parent, hit_material="armor")
            records.append({"room": rid, "name": parent + "/" + name, "kind": "box", "position_local": list(at), "size": list(size), "solid": solid, "material": mat})

        def cylinder(name, at, radius, tall, mat="steel", solid=True):
            sc.cylinder(name, at, radius, tall, mat, solid, parent)
            records.append({"room": rid, "name": parent + "/" + name, "kind": "cylinder", "position_local": list(at), "radius": radius, "height": tall, "solid": solid, "material": mat})

        def lamp(name, at, warm=False, energy=.8, reach=7):
            nonlocal light_count
            tint = (.84, .73, .52, 1) if warm else (.57, .72, .65, 1)
            sc.light(parent + "_" + name, (cx + at[0], fy + at[1], cz + at[2]), tint, energy, reach)
            light_count += 1

        # The original concept's structural depth: actual overhead steel ribs,
        # uneven service runs and clamps. No new vertical player-height posts.
        roof = height - .30
        beam_z = [-sz * .29, sz * .28] if rid != "arena_one" else [-sz * .34, 0, sz * .34]
        for index, z in enumerate(beam_z):
            box("RoofRib" + str(index), (0, roof, z), (sx - .35, .34, .30))
            for side in (-1, 1):
                box("RibShoe" + str(index) + str(side), (side * (sx / 2 - .20), roof - .23, z), (.38, .65, .48), "panel")
        for index, x in enumerate((-sx * .32, -sx * .25)):
            box("ServiceRun" + str(index), (x, height - .62 - index * .16, 0), (.23 + index * .09, .23 + index * .09, sz - .45), "room_prop_7")
            for slot, z in enumerate(beam_z):
                box("PipeClamp" + str(index) + str(slot), (x, height - .62 - index * .16, z), (.37 + index * .09, .35 + index * .09, .16), "trim")

        # Two believable luminaires, rather than a green point-light wash.
        # Lens inlays sit .012m below their corresponding physical casing.
        for index, (x, z, warm) in enumerate(((sx * .19, -sz * .25, False), (-sx * .12, sz * .24, True))):
            ly = height - .85
            box("Luminaire" + str(index), (x, ly, z), (1.75, .16, .42), "recess")
            box("Lens" + str(index), (x, ly - .087, z), (1.53, .012, .29), "intake_v7_warm_lens" if warm else "intake_v7_cold_lens", False)
            # Pool is below casing so it is not hidden by its own metal shell.
            lamp("BayPool" + str(index), (x, min(ly - .2, 4.15), z), warm, 1.0 if rid == "arena_one" else .75, 10 if rid == "arena_one" else 7)

        if rid == "entry":
            # Reception canopy / workflow feature, clear above human reach.
            box("ReceptionCanopy", (sx * .24, 3.72, sz * .27), (sx * .30, .20, 2.3), "panel")
            box("ReceptionCanopyLip", (sx * .24, 3.57, sz * .27 + 1.05), (sx * .30, .10, .10), "intake_v7_warm_lens")
        elif rid == "service":
            # Decontamination air nozzles remain higher than the upper walkway
            # headroom (floor+2.5m platform +1.7m actor). No floor spray gates.
            for side in (-1, 1):
                box("AirPlenum" + str(side), (side * (sx / 2 - .25), 4.63, 0), (.42, .30, sz * .68), "room_prop_8")
                for slot, fraction in enumerate((-.23, 0, .23)):
                    box("AirNozzle" + str(side) + str(slot), (side * (sx / 2 - .39), 4.43, sz * fraction), (.16, .12, .36), "trim")
        elif rid == "arena_one":
            # High medical gantry frames the sunken triage, leaving its real
            # raised gallery/retreat lanes and whole firing volume untouched.
            for side in (-1, 1):
                box("TriageGantry" + str(side), (side * sx * .27, 6.25, 0), (.35, .45, sz * .70), "panel")
                for slot, fraction in enumerate((-.22, 0, .22)):
                    box("GantryHanger" + str(side) + str(slot), (side * sx * .27, (height + 6.25) / 2, sz * fraction), (.16, height - 6.25, .16))
            # Restricted diagnostic-green points make equipment bays readable;
            # the enemy-facing central floor keeps its existing neutral light.
            for side in (-1, 1):
                lamp("TriageBay" + str(side), (side * sx * .35, 3.4, -sz * .10), False, .65, 8)
        elif rid == "key_wing":
            # A suspended scanner carriage reads as diagnostics, not stores.
            box("ScannerTrack", (0, 4.67, 0), (.34, .25, sz * .58), "room_prop_7")
            box("ScannerCarriage", (0, 4.30, -sz * .14), (2.3, .42, .7), "room_prop_5")
            box("ScannerLens", (0, 4.08, -sz * .14), (1.8, .025, .35), "intake_v7_cold_lens", False)
        elif rid == "key_console":
            # Align to the actual surgical table selected by ordinary furnish.
            table = _fitting_position(sc, rid, "surgical_table")
            assert table is not None, "Operating theatre requires its real surgical table"
            lx, lz = table[0] - cx, table[2] - cz
            arm_y = 4.53
            box("SurgicalCeilingMount", (lx, 4.86, lz), (.62, .28, .62), "panel")
            cylinder("SurgicalStem", (lx, 4.25, lz), .085, .95)
            for index, offset in enumerate((-.46, .46)):
                cylinder("SurgicalHead" + str(index), (lx + offset, 3.83, lz), .47, .20, "room_prop_13_cyl")
                cylinder("SurgicalLens" + str(index), (lx + offset, 3.724, lz), .37, .012, "intake_v7_cold_lens", False)
            box("SurgicalArm", (lx, arm_y - .47, lz), (1.15, .12, .13))
            sc.downlight(parent + "_SurgicalPool", (table[0], fy + 3.60, table[2]), 2.2, 6)
            light_count += 1
            captures.append({"room": rid, "purpose": "actual-table-surgical-landmark", "eye": [table[0], fy + 1.65, table[2] + 4.0], "target": [table[0], fy + 2.3, table[2]]})
        elif rid == "return_store":
            # Ceiling trolley rails and labelled existing storage fittings give
            # the sterile return its own workflow without duplicate crates.
            for side in (-1, 1):
                box("SupplyTrack" + str(side), (side * sx * .22, 4.55, 0), (.15, .20, sz * .72))
            box("SupplyCrossbar", (0, 4.36, sz * .20), (sx * .49, .20, .20), "panel")

        captures.append({"room": rid, "purpose": "room-relative-working-view", "eye_local": [0, 1.65, sz * .34], "target_local": [0, 2.3 if rid == "arena_one" else 2.0, -sz * .20], "room_center": list(room["center"])})

    report = {"applied": True, "version": 7, "campaign_level_id": "pale_ward_01", "rooms": list(ROOMS), "physical_parts": sum(part["solid"] for part in records), "lens_inlays": sum(not part["solid"] for part in records), "added_lights": light_count, "parts": records, "capture_targets": captures, "source_policy": "Existing approved production materials only; no new or transformed raster assets"}
    sc.intake_presentation_v7 = report
    return report
