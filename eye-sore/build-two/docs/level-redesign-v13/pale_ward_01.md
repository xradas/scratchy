# Intake — v13 design packet

Restore local power in the utility generator room.

![Annotated floor plan](pale_ward_01-floorplan.svg)

Target: 20–25 minutes human first successful exploration, excluding deaths. No bot timing claim.

## Required objective journey

- Restore local power in the utility generator room. Requires: arrival; completion flag: `local_power`.
- Find the surgical credential in the operating theatre. Requires: local_power; completion flag: `surgical_credential`.
- Reach the surgical wing and survive decontamination. Requires: surgical_credential; completion flag: `decon_clear`.
- Take the transfer lift to Containment. Requires: decon_clear; completion flag: `finished`.

## Checkpoints

- `power_return` in reception, after local_power.
- `credential_return` in sterile, after surgical_credential.

Encounter roster: 64 existing Ward enemies. Main-route ammunition pickups: {'pistol': 220, 'shells': 90, 'rivets': 0, 'rockets': 0}. Optional supplies are separate.

## Rooms and pre-build object list

| Room | Floor | Function | Objects |
|---|---:|---|---|
| Patient reception | 0m | triage_reception | intake_desk, intake_desk, waiting_bench, waiting_bench, waiting_bench, records_cabinet, records_cabinet, containment_console |
| Emergency triage | 0m | triage_ward | medical_bed, medical_bed, medical_bed, medical_bed, medical_bed, medical_bed, medical_bed, medical_bed, vital_monitor, vital_monitor, vital_monitor, vital_monitor, privacy_screen, privacy_screen, privacy_screen, privacy_screen, medical_cabinet, medical_cabinet |
| Nurse station | 0m | control_room | containment_console, containment_console, containment_console, containment_console, records_cabinet, records_cabinet |
| Utility service | -2m | utility | pump_rig, pump_rig, pump_rig, pump_rig, pipe_manifold, pipe_manifold, filter_unit, containment_console |
| Emergency generator | -2m | utility | pump_rig, pump_rig, pump_rig, pump_rig, pipe_manifold, pipe_manifold, filter_unit, containment_console |
| Diagnostics access | 2m | diagnostics | scan_console, scan_console, instrument_bench, instrument_bench, specimen_fridge, specimen_fridge, medical_cabinet, medical_cabinet |
| Imaging suite | 2m | diagnostics | scan_console, scan_console, instrument_bench, instrument_bench, specimen_fridge, specimen_fridge, medical_cabinet, medical_cabinet |
| Operating theatre | 2m | surgery | surgical_table, surgical_table, surgical_lamp, surgical_lamp, instrument_bench, instrument_bench, specimen_fridge, medical_cabinet, vital_monitor, vital_monitor |
| Sterile supply return | 2m | medical_stores | medical_cabinet, medical_cabinet, medical_cabinet, medical_cabinet, medical_cabinet, medical_cabinet, medical_cabinet, medical_cabinet, supply_cart, supply_cart |
| Surgical access | 2m | decontamination | filter_unit, filter_unit, decon_frame, decon_frame, ppe_locker, ppe_locker, pipe_manifold, pipe_manifold |
| Recovery ward | 2m | triage_ward | medical_bed, medical_bed, medical_bed, medical_bed, medical_bed, medical_bed, medical_bed, medical_bed, vital_monitor, vital_monitor, vital_monitor, vital_monitor, privacy_screen, privacy_screen, privacy_screen, privacy_screen, medical_cabinet, medical_cabinet |
| Instrument processing | 2m | medical_stores | medical_cabinet, medical_cabinet, medical_cabinet, medical_cabinet, medical_cabinet, medical_cabinet, medical_cabinet, medical_cabinet, supply_cart, supply_cart |
| Sealed decontamination | 2m | decontamination | filter_unit, filter_unit, decon_frame, decon_frame, ppe_locker, ppe_locker, pipe_manifold, pipe_manifold |
| Patient transfer | 4m | utility | pump_rig, pump_rig, pump_rig, pump_rig, pipe_manifold, pipe_manifold, filter_unit, containment_console |
| Upper transfer landing | 4m | utility | pump_rig, pump_rig, pump_rig, pump_rig, pipe_manifold, pipe_manifold, filter_unit, containment_console |
| Containment receiving | 6m | security | intake_desk, security_console, weapon_rack, weapon_rack, ppe_locker, ppe_locker |
| Patient records (optional) | 0m | records | records_cabinet, records_cabinet, records_cabinet, records_cabinet |
| Staff lockers (optional) | 0m | staff_room | ppe_locker, ppe_locker, ppe_locker, ppe_locker |
| Pharmacy (optional) | 2m | medical_stores | medical_cabinet, medical_cabinet, medical_cabinet, medical_cabinet |
| Surgical observation (optional) | 4m | control_room | containment_console, containment_console, containment_console, containment_console |
| Abandoned filter crawl (secret) | -2m | utility | pump_rig, pump_rig, pump_rig, pump_rig |
| Sealed isolation stores (secret) | 2m | medical_stores | medical_cabinet, medical_cabinet, medical_cabinet, medical_cabinet |

Machine-readable positions, connections, requirements and inventory: `pale_ward_01.json`.

## Structural combat connection — construction revision

`triage_nurse_court`: Ungated shared combat court replaces existing ungated connector; no new graph edge. Split ledge preserves3.5m ground axis.

Constructed geometry remains subject to independent physical, contact, order, checkpoint and gameplay review. Existing objectives, checkpoints and actor budgets/IDs are preserved.

| Aperture | Plane | Horizontal span | Absolute height |
|---|---:|---|---|
| triage W | -17m | [-49, -31]m | [0, 5.5]m |
| nurse E | -27m | [-49, -31]m | [0, 5.5]m |

Closed structural volumes and physical cover:
- `CourtFloor`: centre `[-22, -0.25, -40]`, size `[10.4, 0.5, 18.4]`m, native floor surfaces.
- `CourtRoof`: centre `[-22, 5.65, -40]`, size `[10.8, 0.3, 18.8]`m, native ceiling surfaces.
- `CourtNorth`: centre `[-22, 2.75, -49.2]`, size `[10.4, 5.5, 0.4]`m, native wall surfaces.
- `CourtSouth`: centre `[-22, 2.75, -30.8]`, size `[10.4, 5.5, 0.4]`m, native wall surfaces.
- `NorthCover`: centre `[-22, 0.7, -45]`, size `[2.5, 1.4, 1.8]`m, native panel surfaces.
- `SouthCover`: centre `[-22, 0.7, -35]`, size `[2.5, 1.4, 1.8]`m, native panel surfaces.
- `NorthLedge`: centre `[-28.5, 0.625, -44.125]`, size `[3, 1.25, 4.75]`m, native floor surfaces.
- `SouthLedge`: centre `[-28.5, 0.625, -35.875]`, size `[3, 1.25, 4.75]`m, native floor surfaces.
- `NorthStair`: floor `[-28.5, 0, -51.5]` to `[-28.5, 1.25, -46.5]`, width 3m; ten0.125m risers over5m run (0.5m tread). Actual ascent/descent is a separate evidence gate.
- `SouthStair`: floor `[-28.5, 0, -28.5]` to `[-28.5, 1.25, -33.5]`, width 3m; ten0.125m risers over5m run (0.5m tread). Actual ascent/descent is a separate evidence gate.
- Existing actor `pale_ward_01.nurse.enemy.2` (infected_security) moved to `[-28.5, 2.12, -43]`; Supported elevated cross-area angle;13.51m horizontal to triage test stance.

Lane contract: `{"north_south_physical_width_m": 3.1, "actual_capsule_diameter_m": 0.6, "usable_capsule_center_width_m": 2.5, "central_ground_passage_width_m": 3.5, "enemy_navigation": "Existing centre route; flanks are player choices, not coordinated AI lanes."}`.

Risks and unfinished acceptance:
- Ten existing actors may now share early engagement; gameplay fairness and checkpoint safety require fresh evidence.
- No collision-only anti-bypass; every solid is a matching visible closed mesh.

Exact floor paths, shot/solid test pairs, apertures, closed boxes and actor poses are recorded in `levels.json`, the matching Ward JSON, runtime route and v13 author report. These data are a test contract, not proof that the test passed.

## Spatial construction revision14

Current source keeps design/schema version13 and records `layout_revision: 14`. Plan: [v14 contract](../ward-spatial-v14/plan.json). Actual footprint diagram: [v14 SVG](../ward-spatial-v14/pale_ward_01.svg). The v13 diagrams/images remain historical.

### Landmark footprints

- `reception` at `[0, 0, 0]`: L-shaped admissions counter with clear central route and waiting wing; local XZ boundary `[[-16, -14], [8, -14], [8, -6], [16, -6], [16, 14], [-16, 14]]`. Closed convex floor/roof cells: `[{'kind': 'box', 'bounds_xz': [-16, 8, -14, -6]}, {'kind': 'box', 'bounds_xz': [-16, 8, -6, 14]}, {'kind': 'box', 'bounds_xz': [8, 16, -6, 14]}]`.
- `diagnostics` at `[40, 2, -40]`: Angled imaging junction separates consoles from circulation; local XZ boundary `[[-9, -12], [9, -12], [13, -8], [13, 8], [9, 12], [-9, 12], [-13, 8], [-13, -8]]`. Closed convex floor/roof cells: `[{'kind': 'convex', 'outline_xz': [[-9, -12], [9, -12], [13, -8], [13, 8], [9, 12], [-9, 12], [-13, 8], [-13, -8]]}]`.
- `recovery` at `[-40, 2, 40]`: L-shaped recovery ward with orderly paired bed bays; local XZ boundary `[[-16, -13], [8, -13], [8, -5], [16, -5], [16, 13], [-16, 13]]`. Closed convex floor/roof cells: `[{'kind': 'box', 'bounds_xz': [-16, 8, -13, -5]}, {'kind': 'box', 'bounds_xz': [-16, 8, -5, 13]}, {'kind': 'box', 'bounds_xz': [8, 16, -5, 13]}]`.

Concave L footprints use actual closed box-cell unions; convex chamfers use a single closed convex prism per slab. Every outline edge has a closed textured wall/collider, with real cuts at existing cardinal mouths. Concave footprints are never passed to the convex runtime shape helper. Lowered ceilings follow the same cells. Room metadata publishes the exact local footprint; the HUD map rectangle is only its envelope.

Outline-dependent architecture fits: 11 explicit entries in `resources/campaign/v13/pale_ward_01-author-report.json` (`shell_fits`). These trim ducts/ribs/alcoves or inset boundary columns/growths; named semantic prop types/counts remain fixed. All exposed native material faces remain closed.

### Additional shared connection

`v14_clinical_prep` replaces `imaging__theatre` between ['imaging', 'theatre'], bounds `[70, 90, -26, -14]`. Already ungated existing pair; no new graph edge; all milestone gates/checkpoints remain unchanged Explicit apertures, floor/roof/side supports, offset cover, stairs and native test floor/shot/solid pairs are in the source/runtime route and author report. Original centre route remains clear; flank movement is player choice, not coordinated enemy navigation.
- Existing ranged `pale_ward_01.imaging.enemy.2` (infected_security) at `[85, 2.87, -31]`; stable ID/type/count preserved.

### Optional accepted-supply reserve

`records` retains existing `Bonus_records` (12 shells) and unchanged health bonus. Only an accepted reward mutation activates `v14_records_reserve`; full ammo leaves the shell item available and group closed. The physical `Door_v14_records_reserve` is not E-usable; it opens once through the exact stable-ID release contract. No main exit seal, required clear, reward addition or new actor.
Closet side `north`, partition z=-6.8, full X span `[-53, -27]`, six-metre door `[-43, -37]`, door height 3.4m, closed roof at y=3.8. Real side partitions/header/upper cap meet the outer room walls and roof; visual/shot/movement bodies match.
- `pale_ward_01.triage.enemy.1` (infected_scientist) → `[-42, 0.87, -9]` in actual/activation room `records`, arena `v14_records_reserve`; source-room identity retained in report.
- `pale_ward_01.triage.enemy.2` (infected_security) → `[-41.5, 0.87, -7.4]` in actual/activation room `records`, arena `v14_records_reserve`; source-room identity retained in report.

Coordinator approved security-only near-front west pose after actual .38m capsule sweep: prior desired nav line clipped partition; new pose clears same6m physical door. Scientist remains[-42,.87,-9]; no AI/door-width change. Natural pursuit/retreat QA required.

Coordinator-approved route fit: recovery beds `.prop.2/.prop.3` and monitor `.prop.10` use local z=2.3 instead of initial2.0, preserving the earlier capsule lane reserve.

### Guidance and acceptance

New route signs are static labels. Their flag associations remain explicit source/navigation metadata; existing controls retain their native state indicators. Control/objective text names actual next destinations. Containment second-feed feedback checks both actual feed flags before saying the basin is drained.

Independent real body/crouch/stair/closed-mesh and prop bounds, accepted/full/repeated/restore/reset reward behavior, reciprocal shots/projectiles, real finite combat/retreat, both feed orders and full campaigns remain separately reported evidence. Metadata, controlled views and bot timings do not establish human tactics, exact concept match, navigation comfort or the20–25minute pacing target.
