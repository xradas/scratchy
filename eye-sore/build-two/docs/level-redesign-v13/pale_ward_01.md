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
| Patient reception | 0m | triage_reception | intake_desk, waiting_bench, records_cabinet |
| Emergency triage | 0m | triage_ward | medical_bed, medical_bed, medical_bed, medical_bed, vital_monitor, privacy_screen |
| Nurse station | 0m | control_room | containment_console, records_cabinet |
| Utility service | -2m | utility | filter_unit, supply_cart |
| Emergency generator | -2m | utility | filter_unit, supply_cart |
| Diagnostics access | 2m | diagnostics | scan_console, instrument_bench, specimen_fridge |
| Imaging suite | 2m | diagnostics | scan_console, instrument_bench, specimen_fridge |
| Operating theatre | 2m | surgery | surgical_table, instrument_bench, surgical_lamp |
| Sterile supply return | 2m | medical_stores | medical_cabinet, supply_cart, records_cabinet |
| Surgical access | 2m | decontamination | decon_frame, filter_unit, ppe_locker |
| Recovery ward | 2m | triage_ward | medical_bed, medical_bed, medical_bed, medical_bed, vital_monitor, privacy_screen |
| Instrument processing | 2m | medical_stores | medical_cabinet, supply_cart, records_cabinet |
| Sealed decontamination | 2m | decontamination | decon_frame, filter_unit, ppe_locker |
| Patient transfer | 4m | utility | filter_unit, supply_cart |
| Upper transfer landing | 4m | utility | filter_unit, supply_cart |
| Containment receiving | 6m | security | intake_desk, weapon_rack |
| Patient records (optional) | 0m | records | records_cabinet, records_cabinet |
| Staff lockers (optional) | 0m | staff_room | ppe_locker, waiting_bench |
| Pharmacy (optional) | 2m | medical_stores | medical_cabinet, supply_cart, records_cabinet |
| Surgical observation (optional) | 4m | control_room | containment_console, records_cabinet |
| Abandoned filter crawl (secret) | -2m | utility | filter_unit, supply_cart |
| Sealed isolation stores (secret) | 2m | medical_stores | medical_cabinet, supply_cart, records_cabinet |

Machine-readable positions, connections, requirements and inventory: `pale_ward_01.json`.
