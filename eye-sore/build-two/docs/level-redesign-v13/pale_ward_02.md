# Containment — v13 design packet

Isolate the culture reservoir feed.

![Annotated floor plan](pale_ward_02-floorplan.svg)

Target: 20–25 minutes human first successful exploration, excluding deaths. No bot timing claim.

## Required objective journey

- Isolate the culture reservoir feed. Requires: arrival; completion flag: `isolation_a`.
- Isolate the surgical-waste reservoir feed. Requires: arrival; completion flag: `isolation_b`.
- Descend into the drained basin and reach specimen transfer. Requires: isolation_a, isolation_b; completion flag: `finished`.

## Checkpoints

- `culture_safe` in isolation_a, after isolation_a.
- `waste_safe` in isolation_b, after isolation_b.

Encounter roster: 76 existing Ward enemies. Main-route ammunition pickups: {'pistol': 180, 'shells': 80, 'rivets': 180, 'rockets': 0}. Optional supplies are separate.

## Rooms and pre-build object list

| Room | Floor | Function | Objects |
|---|---:|---|---|
| Reservoir receiving overlook | 4m | control_room | containment_console, containment_console, containment_console, containment_console, records_cabinet, records_cabinet |
| Culture receiving | 4m | diagnostics | scan_console, scan_console, instrument_bench, instrument_bench, specimen_fridge, specimen_fridge, medical_cabinet, medical_cabinet |
| Sterile culture laboratory | 4m | surgery | surgical_table, surgical_table, surgical_lamp, surgical_lamp, instrument_bench, instrument_bench, specimen_fridge, medical_cabinet, vital_monitor, vital_monitor |
| Culture filtration | 2m | utility | pump_rig, pump_rig, pump_rig, pump_rig, pipe_manifold, pipe_manifold, filter_unit, containment_console |
| Culture isolation control | 2m | control_room | containment_console, containment_console, containment_console, containment_console, records_cabinet, records_cabinet |
| Waste transfer | 4m | utility | pump_rig, pump_rig, pump_rig, pump_rig, pipe_manifold, pipe_manifold, filter_unit, containment_console |
| Surgical waste laboratory | 4m | surgery | surgical_table, surgical_table, surgical_lamp, surgical_lamp, instrument_bench, instrument_bench, specimen_fridge, medical_cabinet, vital_monitor, vital_monitor |
| Thermal sterilizer | 6m | utility | pump_rig, pump_rig, pump_rig, pump_rig, pipe_manifold, pipe_manifold, filter_unit, containment_console |
| Waste isolation control | 6m | control_room | containment_console, containment_console, containment_console, containment_console, records_cabinet, records_cabinet |
| Drained reservoir basin | 0m | reservoir | specimen_tank, specimen_tank, specimen_tank, specimen_tank, pipe_manifold, pipe_manifold |
| Lower outfall | 0m | utility | pump_rig, pump_rig, pump_rig, pump_rig, pipe_manifold, pipe_manifold, filter_unit, containment_console |
| Purge machinery | 0m | utility | pump_rig, pump_rig, pump_rig, pump_rig, pipe_manifold, pipe_manifold, filter_unit, containment_console |
| Discharge control | 2m | control_room | containment_console, containment_console, containment_console, containment_console, records_cabinet, records_cabinet |
| Specimen transfer | 2m | security | intake_desk, security_console, weapon_rack, weapon_rack, ppe_locker, ppe_locker |
| Pump spares (optional) | 4m | utility | pump_rig, pump_rig, pump_rig, pump_rig |
| Culture records (optional) | 4m | records | records_cabinet, records_cabinet, records_cabinet, records_cabinet |
| Decon lockers (optional) | 4m | staff_room | ppe_locker, ppe_locker, ppe_locker, ppe_locker |
| Upper service observation (optional) | 6m | control_room | containment_console, containment_console, containment_console, containment_console |
| Cold archive (secret) | 2m | medical_stores | medical_cabinet, medical_cabinet, medical_cabinet, medical_cabinet |
| Old outfall stores (secret) | 0m | utility | pump_rig, pump_rig, pump_rig, pump_rig |

Machine-readable positions, connections, requirements and inventory: `pale_ward_02.json`.

## Structural combat connection — construction revision

`reservoir_fighting_balconies`: Two accessible upper balconies; firing shutters open only after both feed flags and actual drain. Physical slotted parapets prevent passage; central both-feeds gate unchanged.

Constructed geometry remains subject to independent physical, contact, order, checkpoint and gameplay review. Existing objectives, checkpoints and actor budgets/IDs are preserved.

| Aperture | Plane | Horizontal span | Absolute height |
|---|---:|---|---|
| overlook N | -13m | [-13.0, -4.0]m | [4, 8.3]m |
| overlook N | -13m | [4.0, 13.0]m | [4, 8.3]m |
| reservoir S | -26m | [-13.0, -4.0]m | [4, 8.3]m |
| reservoir S | -26m | [4.0, 13.0]m | [4, 8.3]m |

Closed structural volumes and physical cover:
- `WestParapetBase`: centre `[-8.5, 4.2, -26]`, size `[9, 0.4, 0.3]`m, native trim surfaces.
- `EastParapetBase`: centre `[8.5, 4.2, -26]`, size `[9, 0.4, 0.3]`m, native trim surfaces.
- Existing actor `pale_ward_02.reservoir.enemy.2` (vessel) moved to `[5.25, 0.87, -32]`; After drain: reciprocal ranged attack through actual .4m parapet slot from6.6m horizontal; blocked by shutter beforeboth.
- `ReservoirBalconyWest`: `[-8.5, 6.15, -26.18]`, closed size `[9, 4.3, 0.22]`, open offset `[0, 5, 0]`; auto-open requires both feed flags AND actual `ReservoirLiquid.is_drained()`. Stable snapshot identity `pale_ward_02.shutter.reservoir_balcony_west`. Visual and shot/movement collider are the same moving body.
- `ReservoirBalconyEast`: `[8.5, 6.15, -26.18]`, closed size `[9, 4.3, 0.22]`, open offset `[0, 5, 0]`; auto-open requires both feed flags AND actual `ReservoirLiquid.is_drained()`. Stable snapshot identity `pale_ward_02.shutter.reservoir_balcony_east`. Visual and shot/movement collider are the same moving body.

Root approved real .4m firing slots rather than a full1.4m wall, which blocks actual standing-player enemy LOS. Actual swept .12m enemy/.09m player projectiles then clipped the initial .65m base despite thin ray clearance; lowered visible base to.4m and extended posts down, retaining total1.4m barrier and.4m clear widths. Actual contact and anti-bypass reruns required; no projectile exemptions or invisible body.
Visible base0.4m, posts reach1.4m above gallery floor;0.1m-wide posts at0.5m pitch leave0.4m actual clear slots, below the0.6m player capsule diameter. No invisible anti-bypass plane. Both standing/crouching diagonal and real projectile diameter tests required.

Risks and unfinished acceptance:
- Stand/crouch/diagonal and projectile diameter proofs required; .4m slots are smaller than .6m capsule, but metadata alone does not prove anti-bypass.
- Basin actors are visually submerged until3.5m liquid drains; shutters must block all shots/LOS until actual drain.
- Enemy navigation unchanged; these are firing balconies, never an alternate physical path into gated basin.

Exact floor paths, shot/solid test pairs, apertures, closed boxes and actor poses are recorded in `levels.json`, the matching Ward JSON, runtime route and v13 author report. These data are a test contract, not proof that the test passed.
