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
