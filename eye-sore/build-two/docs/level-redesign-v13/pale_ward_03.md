# Breach — v13 design packet

Destroy the upper containment anchor.

![Annotated floor plan](pale_ward_03-floorplan.svg)

Target: 20–25 minutes human first successful exploration, excluding deaths. No bot timing claim.

## Required objective journey

- Destroy the upper containment anchor. Requires: arrival; completion flag: `anchor_a`.
- Descend to the middle silo and destroy its anchor. Requires: anchor_a; completion flag: `anchor_b`.
- Destroy the deep containment anchor. Requires: anchor_b; completion flag: `anchor_c`.
- Cross the rupture and enter the buried passage. Requires: anchor_c; completion flag: `finished`.

## Checkpoints

- `upper_anchor_safe` in anchor_a, after anchor_a.
- `middle_anchor_safe` in anchor_b, after anchor_b.

Encounter roster: 84 existing Ward enemies. Main-route ammunition pickups: {'pistol': 160, 'shells': 80, 'rivets': 120, 'rockets': 20}. Optional supplies are separate.

## Rooms and pre-build object list

| Room | Floor | Function | Objects |
|---|---:|---|---|
| Specimen loading bay | 8m | security | intake_desk, security_console, weapon_rack, weapon_rack, ppe_locker, ppe_locker |
| Upper silo intake | 8m | utility | pump_rig, pump_rig, pump_rig, pump_rig, pipe_manifold, pipe_manifold, filter_unit, containment_console |
| Upper specimen gallery | 8m | specimen_silo | specimen_tank, specimen_tank, specimen_tank, specimen_tank, containment_console, pipe_manifold |
| Upper anchor machinery | 8m | utility | pump_rig, pump_rig, pump_rig, pump_rig, pipe_manifold, pipe_manifold, filter_unit, containment_console |
| Transfer maintenance | 6m | utility | pump_rig, pump_rig, pump_rig, pump_rig, pipe_manifold, pipe_manifold, filter_unit, containment_console |
| Specimen preparation | 4m | surgery | surgical_table, surgical_table, surgical_lamp, surgical_lamp, instrument_bench, instrument_bench, specimen_fridge, medical_cabinet, vital_monitor, vital_monitor |
| Middle silo crossing | 4m | specimen_silo | specimen_tank, specimen_tank, specimen_tank, specimen_tank, containment_console, pipe_manifold |
| Middle anchor machinery | 4m | utility | pump_rig, pump_rig, pump_rig, pump_rig, pipe_manifold, pipe_manifold, filter_unit, containment_console |
| Lower silo access | 2m | utility | pump_rig, pump_rig, pump_rig, pump_rig, pipe_manifold, pipe_manifold, filter_unit, containment_console |
| Deep cultivation | 0m | reservoir | specimen_tank, specimen_tank, specimen_tank, specimen_tank, pipe_manifold, pipe_manifold |
| Containment machinery | 0m | utility | pump_rig, pump_rig, pump_rig, pump_rig, pipe_manifold, pipe_manifold, filter_unit, containment_console |
| Lower anchor machinery | 0m | utility | pump_rig, pump_rig, pump_rig, pump_rig, pipe_manifold, pipe_manifold, filter_unit, containment_console |
| Rupture chamber | -4m | specimen_silo | specimen_tank, specimen_tank, specimen_tank, specimen_tank, containment_console, pipe_manifold |
| Rupture crossing | -4m | utility | pump_rig, pump_rig, pump_rig, pump_rig, pipe_manifold, pipe_manifold, filter_unit, containment_console |
| Buried occult threshold | -4m | security | intake_desk, security_console, weapon_rack, weapon_rack, ppe_locker, ppe_locker |
| Security stores (optional) | 8m | security | intake_desk, security_console, weapon_rack, weapon_rack |
| Specimen records (optional) | 4m | records | records_cabinet, records_cabinet, records_cabinet, records_cabinet |
| Lower pump service (optional) | 0m | utility | pump_rig, pump_rig, pump_rig, pump_rig |
| Fissure observation (optional) | -2m | control_room | containment_console, containment_console, containment_console, containment_console |
| Sealed equipment cage (secret) | 8m | utility | pump_rig, pump_rig, pump_rig, pump_rig |
| Buried crypt recess (secret) | -4m | utility | pump_rig, pump_rig, pump_rig, pump_rig |

Machine-readable positions, connections, requirements and inventory: `pale_ward_03.json`.
