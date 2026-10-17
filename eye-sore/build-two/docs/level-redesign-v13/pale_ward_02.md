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

## Spatial construction revision14

Current source keeps design/schema version13 and records `layout_revision: 14`. Plan: [v14 contract](../ward-spatial-v14/plan.json). Actual footprint diagram: [v14 SVG](../ward-spatial-v14/pale_ward_02.svg). The v13 diagrams/images remain historical.

### Landmark footprints

- `overlook` at `[0, 4, 0]`: Clipped central control hub retains both visible basin galleries; local XZ boundary `[[-14, -13], [14, -13], [16, -11], [16, 11], [14, 13], [-14, 13], [-16, 11], [-16, -11]]`. Closed convex floor/roof cells: `[{'kind': 'convex', 'outline_xz': [[-14, -13], [14, -13], [16, -11], [16, 11], [14, 13], [-14, 13], [-16, 11], [-16, -11]]}]`.
- `cultures` at `[-80, 4, 0]`: L-shaped culture suite with a rear work recess; local XZ boundary `[[-16, -14], [16, -14], [16, 14], [-8, 14], [-8, 6], [-16, 6]]`. Closed convex floor/roof cells: `[{'kind': 'box', 'bounds_xz': [-16, -8, -14, 6]}, {'kind': 'box', 'bounds_xz': [-8, 16, -14, 6]}, {'kind': 'box', 'bounds_xz': [-8, 16, 6, 14]}]`.
- `waste_lab` at `[80, 4, 0]`: Mirrored L-shaped surgical-waste suite with distinct branch identity; local XZ boundary `[[-16, -14], [16, -14], [16, 6], [8, 6], [8, 14], [-16, 14]]`. Closed convex floor/roof cells: `[{'kind': 'box', 'bounds_xz': [-16, 8, -14, 6]}, {'kind': 'box', 'bounds_xz': [-16, 8, 6, 14]}, {'kind': 'box', 'bounds_xz': [8, 16, -14, 6]}]`.

Concave L footprints use actual closed box-cell unions; convex chamfers use a single closed convex prism per slab. Every outline edge has a closed textured wall/collider, with real cuts at existing cardinal mouths. Concave footprints are never passed to the convex runtime shape helper. Lowered ceilings follow the same cells. Room metadata publishes the exact local footprint; the HUD map rectangle is only its envelope.

Outline-dependent architecture fits: 13 explicit entries in `resources/campaign/v13/pale_ward_02-author-report.json` (`shell_fits`). These trim ducts/ribs/alcoves or inset boundary columns/growths; named semantic prop types/counts remain fixed. All exposed native material faces remain closed.

### Additional shared connection

`v14_culture_steps` replaces `cultures__filters` between ['cultures', 'filters'], bounds `[-90, -70, -28, -14]`. Already ungated existing pair; no new graph edge; all milestone gates/checkpoints remain unchanged Explicit apertures, floor/roof/side supports, offset cover, stairs and native test floor/shot/solid pairs are in the source/runtime route and author report. Original centre route remains clear; flank movement is player choice, not coordinated enemy navigation.
- Existing ranged `pale_ward_02.cultures.enemy.2` (infected_security) at `[-86, 4.87, -10]`; stable ID/type/count preserved.

### Optional accepted-supply reserve

`pump_store` retains existing `Bonus_pump_store` (12 shells) and unchanged health bonus. Only an accepted reward mutation activates `v14_pump_store_reserve`; full ammo leaves the shell item available and group closed. The physical `Door_v14_pump_store_reserve` is not E-usable; it opens once through the exact stable-ID release contract. No main exit seal, required clear, reward addition or new actor.
Closet side `south`, partition z=46.8, full X span `[-13, 13]`, six-metre door `[-3, 3]`, door height 3.4m, closed roof at y=7.8. Real side partitions/header/upper cap meet the outer room walls and roof; visual/shot/movement bodies match.
- `pale_ward_02.culture_office.enemy.0` (infected_scientist) → `[-2, 4.87, 49]` in actual/activation room `pump_store`, arena `v14_pump_store_reserve`; source-room identity retained in report.
- `pale_ward_02.waste_lab.enemy.2` (infected_security) → `[2, 4.87, 49]` in actual/activation room `pump_store`, arena `v14_pump_store_reserve`; source-room identity retained in report.

Coordinator review found north main entrance entered the unreleased closet. Move closet to south, preserving north entry, reward and retreat.

### Guidance and acceptance

New route signs are static labels. Their flag associations remain explicit source/navigation metadata; existing controls retain their native state indicators. Control/objective text names actual next destinations. Containment second-feed feedback checks both actual feed flags before saying the basin is drained.

Independent real body/crouch/stair/closed-mesh and prop bounds, accepted/full/repeated/restore/reset reward behavior, reciprocal shots/projectiles, real finite combat/retreat, both feed orders and full campaigns remain separately reported evidence. Metadata, controlled views and bot timings do not establish human tactics, exact concept match, navigation comfort or the20–25minute pacing target.
