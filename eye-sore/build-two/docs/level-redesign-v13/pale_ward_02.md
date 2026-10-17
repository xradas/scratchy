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
| Reservoir receiving overlook | 4m | control_room | containment_console, records_cabinet |
| Culture receiving | 4m | diagnostics | scan_console, instrument_bench, specimen_fridge |
| Sterile culture laboratory | 4m | surgery | surgical_table, instrument_bench, surgical_lamp |
| Culture filtration | 2m | utility | filter_unit, supply_cart |
| Culture isolation control | 2m | control_room | containment_console, records_cabinet |
| Waste transfer | 4m | utility | filter_unit, supply_cart |
| Surgical waste laboratory | 4m | surgery | surgical_table, instrument_bench, surgical_lamp |
| Thermal sterilizer | 6m | utility | filter_unit, supply_cart |
| Waste isolation control | 6m | control_room | containment_console, records_cabinet |
| Drained reservoir basin | 0m | reservoir | filter_unit, containment_console |
| Lower outfall | 0m | utility | filter_unit, supply_cart |
| Purge machinery | 0m | utility | filter_unit, supply_cart |
| Discharge control | 2m | control_room | containment_console, records_cabinet |
| Specimen transfer | 2m | security | intake_desk, weapon_rack |
| Pump spares (optional) | 4m | utility | filter_unit, supply_cart |
| Culture records (optional) | 4m | records | records_cabinet, records_cabinet |
| Decon lockers (optional) | 4m | staff_room | ppe_locker, waiting_bench |
| Upper service observation (optional) | 6m | control_room | containment_console, records_cabinet |
| Cold archive (secret) | 2m | medical_stores | medical_cabinet, supply_cart, records_cabinet |
| Old outfall stores (secret) | 0m | utility | filter_unit, supply_cart |

Machine-readable positions, connections, requirements and inventory: `pale_ward_02.json`.
