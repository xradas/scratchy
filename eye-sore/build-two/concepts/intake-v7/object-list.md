# Intake v7 — pre-build object and progression list

This inventory is authored before generating the replacement scene. Counts below reuse v6 furnishings; this pass changes their context and room layout. Later rooms retain their v6 object lists.

## Main route

Reception → decontamination → clear triage bait fight → enable brass access → raised diagnostics → operating theatre/brass key → sterile supply → unlock return hatch from east → decontamination → triage brass gate → unchanged spine.

The theatre–supply hall lies at x=62; the sterile return hall lies at z=−38. Neither passes through diagnostics. The shortcut requires both the breaker and brass key and can first be operated only from its east/supply side.

## Rooms and objects

### Patient intake (`entry`)

Purpose: triage_reception. Centre [0, 0, 0]; width/height/depth [24, 6, 26] metres.

- 1 × intake_desk: Patient intake: intake desk.
- 1 × waiting_bench: Patient intake: waiting bench.
- 1 × records_cabinet: Patient intake: records cabinet.

### Decontamination (`service`)

Purpose: decontamination. Centre [0, 1.5, -38]; width/height/depth [18, 5, 16] metres.

- 1 × decon_frame: Decontamination: decon frame.
- 1 × filter_unit: Decontamination: filter unit.
- 1 × ppe_locker: Decontamination: ppe locker.

### Emergency triage (`arena_one`)

Purpose: triage_ward. Centre [0, -1, -76]; width/height/depth [36, 10, 40] metres.

- 4 × medical_bed: Emergency triage: medical bed.
- 2 × privacy_screen: Emergency triage: privacy screen.
- 2 × vital_monitor: Emergency triage: vital monitor.

### Diagnostics corridor (`key_wing`)

Purpose: diagnostics. Centre [36, 1.5, -76]; width/height/depth [16, 5, 18] metres.

- 1 × scan_console: Diagnostics corridor: scan console.
- 1 × instrument_bench: Diagnostics corridor: instrument bench.
- 1 × specimen_fridge: Diagnostics corridor: specimen fridge.

### Operating theatre (`key_console`)

Purpose: surgery. Centre [62, 1.5, -76]; width/height/depth [18, 5, 20] metres.

- 1 × surgical_table: Operating theatre: surgical table.
- 1 × instrument_bench: Operating theatre: instrument bench.
- 1 × surgical_lamp: Operating theatre: surgical lamp.

### Sterile supply return (`return_store`)

Purpose: medical_stores. Centre [62, 1.5, -38]; width/height/depth [14, 5, 14] metres.

- 1 × medical_cabinet: Sterile supply return: medical cabinet.
- 1 × supply_cart: Sterile supply return: supply cart.
- 1 × records_cabinet: Sterile supply return: records cabinet.

## Required progression objects

- {"id": "breaker", "type": "switch", "room": "arena_one", "requires": ["clear_arena_one"], "sets": ["breaker", "power"], "opens": ["breaker"], "purpose": "Emergency triage power / access control"}
- {"id": "brass_key", "type": "key", "room": "key_console", "requires": ["power"], "sets": ["brass_key"], "opens": ["brass_gate"], "purpose": "Operating theatre access credential"}
- {"id": "brass_gate", "type": "gate", "requires": ["breaker", "brass_key"], "leads_to": "spine"}
- {"id": "release", "type": "switch", "room": "arena_two", "requires": ["clear_arena_two"], "sets": ["release"], "opens": ["release"], "purpose": "Isolation ward onward release"}
- {"id": "red_key", "type": "key", "room": "red_console", "requires": ["power"], "sets": ["red_key"], "opens": ["red_gate"], "purpose": "Pathology office high security credential", "primary_route_access": ["release"], "note": "The primary route is released by the second control. Return shortcuts can expose this key earlier; the final red gate still requires release and red_key."}
- {"id": "red_gate", "type": "gate", "requires": ["release", "red_key"], "leads_to": "final_arena"}
- {"id": "exit_control", "type": "switch", "room": "final_arena", "requires": ["clear_final_arena"], "sets": ["exit_control"], "opens": ["exit_gate"]}
- {"id": "exit", "type": "exit", "room": "exit_gallery", "requires": ["brass_key", "red_key", "exit_control"]}

## Preserved content

Entry side-supply and maintenance branches, their existing secret rewards, all later rooms and all existing pickup amounts remain. Room-relative pickup positions follow resized/moved rooms; their IDs and types remain stable. The secret branch is optional.

Triage retains its physical sump, upper rim/gallery and five-enemy bait fight. Its north stairs descend from decontamination; the diagnostics stairs rise eastward. No invisible floor or teleport is used.

The obsolete decontamination balcony is removed because its legacy stair endpoints extend outside the new 16 m room depth. The triage gallery remains.

## Explicit clinical working groups

Reception desk local (7,7), bench (9,5.8), records cabinet (4,9). The earlier proposed reception positions intersected reserved portal lanes and were rejected before acceptance. Diagnostics has its console/bench/fridge on local z=-6.5, x=4/0/-4. Theatre has table (4.6,-3.5), instruments (4.6,-5.8), lamp (6.8,-3.5). These local X/Z coordinates are defined before scene generation; they retain the central key and both portal lanes. All nine placements pass the same collision/reservation validator; rejection is a build failure, not a silent fallback.
