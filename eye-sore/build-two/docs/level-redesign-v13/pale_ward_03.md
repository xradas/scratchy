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

## Structural combat connection — construction revision

`specimens_crossfire_court`: Broad shared ungated mandatory connector after anchor A; offset cover preserves original centre route. Player flanks only; no claim of coordinated enemy navigation.

Constructed geometry remains subject to independent physical, contact, order, checkpoint and gameplay review. Existing objectives, checkpoints and actor budgets/IDs are preserved.

| Aperture | Plane | Horizontal span | Absolute height |
|---|---:|---|---|
| specimens W | 64m | [31, 49]m | [4, 9]m |
| crossfire E | 56m | [31, 49]m | [4, 9]m |

Closed structural volumes and physical cover:
- `CourtFloor`: centre `[60, 3.75, 40]`, size `[8.4, 0.5, 18.4]`m, native floor surfaces.
- `CourtRoof`: centre `[60, 9.15, 40]`, size `[8.8, 0.3, 18.8]`m, native ceiling surfaces.
- `CourtNorth`: centre `[60, 6.5, 30.8]`, size `[8.4, 5, 0.4]`m, native wall surfaces.
- `CourtSouth`: centre `[60, 6.5, 49.2]`, size `[8.4, 5, 0.4]`m, native wall surfaces.
- `OffsetMachinery`: centre `[60, 4.75, 43.25]`, size `[2, 1.5, 4]`m, native panel surfaces.
- `NorthLedge`: centre `[60, 4.625, 32.5]`, size `[16, 1.25, 3]`m, native floor surfaces.
- `CrossfireLedgeStair`: floor `[47, 4, 32.5]` to `[52, 5.25, 32.5]`, width 3m; ten0.125m risers over5m run (0.5m tread). Actual ascent/descent is a separate evidence gate.
- `SpecimensLedgeStair`: floor `[73, 4, 32.5]` to `[68, 5.25, 32.5]`, width 3m; ten0.125m risers over5m run (0.5m tread). Actual ascent/descent is a separate evidence gate.
- Existing actor `pale_ward_03.crossfire.enemy.2` (vessel) moved to `[60, 6.12, 32.5]`; Supported high ledge exposes diagonal into specimens and crossfire;10.44m horizontal to test stance.

Lane contract: `{"offset_cover_bounds": [59, 61, 41.25, 45.25], "south_physical_width": 3.75, "south_usable_capsule_center_width": 3.15, "central_axis_z": 40, "enemy_navigation": "Original centre path physicallyclear; flanks playerchoice only. Machine shrunk depth6\u21924 and offset z43.25 by root-approved navigation fallback."}`.

Risks and unfinished acceptance:
- Fresh contact/stair and real combat tests required; ledge changes ordinary encounter exposure but no mandatory all-clear or actor count.
- No direct new opening into anchor rooms; anchors/checkpoints/return shortcut requirements unchanged.

Exact floor paths, shot/solid test pairs, apertures, closed boxes and actor poses are recorded in `levels.json`, the matching Ward JSON, runtime route and v13 author report. These data are a test contract, not proof that the test passed.

## Spatial construction revision14

Current source keeps design/schema version13 and records `layout_revision: 14`. Plan: [v14 contract](../ward-spatial-v14/plan.json). Actual footprint diagram: [v14 SVG](../ward-spatial-v14/pale_ward_03.svg). The v13 diagrams/images remain historical.

### Landmark footprints

- `loading` at `[0, 8, 0]`: L-shaped security intake keeps forward route visible; local XZ boundary `[[-16, -13], [8, -13], [8, -5], [16, -5], [16, 13], [-16, 13]]`. Closed convex floor/roof cells: `[{'kind': 'box', 'bounds_xz': [-16, 8, -13, -5]}, {'kind': 'box', 'bounds_xz': [-16, 8, -5, 13]}, {'kind': 'box', 'bounds_xz': [8, 16, -5, 13]}]`.
- `cultivation` at `[-40, 0, 80]`: L-shaped tank floor wraps pumpwork before the lower feed; local XZ boundary `[[-7, -14], [15, -14], [15, 14], [-15, 14], [-15, -6], [-7, -6]]`. Closed convex floor/roof cells: `[{'kind': 'box', 'bounds_xz': [-15, -7, -6, 14]}, {'kind': 'box', 'bounds_xz': [-7, 15, -14, -6]}, {'kind': 'box', 'bounds_xz': [-7, 15, -6, 14]}]`.
- `rupture` at `[40, -4, 120]`: Octagonal rupture chamber frames the chapter landmark; local XZ boundary `[[-12, -15], [12, -15], [17, -10], [17, 10], [12, 15], [-12, 15], [-17, 10], [-17, -10]]`. Closed convex floor/roof cells: `[{'kind': 'convex', 'outline_xz': [[-12, -15], [12, -15], [17, -10], [17, 10], [12, 15], [-12, 15], [-17, 10], [-17, -10]]}]`.

Concave L footprints use actual closed box-cell unions; convex chamfers use a single closed convex prism per slab. Every outline edge has a closed textured wall/collider, with real cuts at existing cardinal mouths. Concave footprints are never passed to the convex runtime shape helper. Lowered ceilings follow the same cells. Room metadata publishes the exact local footprint; the HUD map rectangle is only its envelope.

Outline-dependent architecture fits: 23 explicit entries in `resources/campaign/v13/pale_ward_03-author-report.json` (`shell_fits`). These trim ducts/ribs/alcoves or inset boundary columns/growths; named semantic prop types/counts remain fixed. All exposed native material faces remain closed.

### Additional shared connection

`v14_lower_feed_hall` replaces `cultivation__machinery` between ['cultivation', 'machinery'], bounds `[-25, -13, 70, 90]`. Already ungated existing pair; no new graph edge; all milestone gates/checkpoints remain unchanged Explicit apertures, floor/roof/side supports, offset cover, stairs and native test floor/shot/solid pairs are in the source/runtime route and author report. Original centre route remains clear; flank movement is player choice, not coordinated enemy navigation.
- Existing ranged `pale_ward_03.cultivation.enemy.2` (vessel) at `[-29, 0.87, 76]`; stable ID/type/count preserved.

### Optional accepted-supply reserve

`security_store` retains existing `Bonus_security_store` (12 shells) and unchanged health bonus. Only an accepted reward mutation activates `v14_security_store_reserve`; full ammo leaves the shell item available and group closed. The physical `Door_v14_security_store_reserve` is not E-usable; it opens once through the exact stable-ID release contract. No main exit seal, required clear, reward addition or new actor.
Closet side `north`, partition z=-6.8, full X span `[-53, -27]`, six-metre door `[-43, -37]`, door height 3.4m, closed roof at y=11.8. Real side partitions/header/upper cap meet the outer room walls and roof; visual/shot/movement bodies match.
- `pale_ward_03.loading.enemy.1` (infected_security) → `[-42.5, 8.87, -7.4]` in actual/activation room `security_store`, arena `v14_security_store_reserve`; source-room identity retained in report.
- `pale_ward_03.loading.enemy.3` (infected_security) → `[-41.5, 8.87, -7.4]` in actual/activation room `security_store`, arena `v14_security_store_reserve`; source-room identity retained in report.

Coordinator approved both existing security actors at[-42.5,8.87,-7.4] and[-41.5,8.87,-7.4] after native live body probes showed the original poses pursued into the right partition. Same six-metre door, original kinds/IDs, no AI change; actual natural aggression/retreat proof required.

### Guidance and acceptance

New route signs are static labels. Their flag associations remain explicit source/navigation metadata; existing controls retain their native state indicators. Control/objective text names actual next destinations. Containment second-feed feedback checks both actual feed flags before saying the basin is drained.

Independent real body/crouch/stair/closed-mesh and prop bounds, accepted/full/repeated/restore/reset reward behavior, reciprocal shots/projectiles, real finite combat/retreat, both feed orders and full campaigns remain separately reported evidence. Metadata, controlled views and bot timings do not establish human tactics, exact concept match, navigation comfort or the20–25minute pacing target.
