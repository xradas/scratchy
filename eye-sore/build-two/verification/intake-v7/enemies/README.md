# Intake v7 existing-enemy validation

Final controlled actual Main fixture: **95 checks passed**, no assertion failures, exit 0. Pinned Godot 4.7.2, headless, fixed 60 Hz.

Run: `tools/godot.sh --headless --fixed-fps 60 --script tools/check_intake_enemies_v7.gd`.

The fixture loads the actual Intake Main scene and production enemy resources. It collects the existing Twin-shot lure through the real collection API, waits for the authored shutters to open, and verifies all five original native actor slots have supported floors, clear capsules, active opaque-anatomy hurt surfaces and consistent feet pivots. Other enemies are frozen for independent movement/attack cases; the stationary player is a controlled setup, not a traversal or balance demonstration.

All four Unsealed physically approach from native alcoves and naturally release melee attacks. The Vessel naturally advances into range and releases one projectile after its production warning. Each warning/release agrees with the production windup within two physics ticks; warning frame 3 changes to release frame 4. The east Unsealed now closes 16.2496 m and attacks near (1.5247, -0.14936, -76.8797).

For each species, genuine accepted pistol rays against production opaque-anatomy hurt geometry interrupt a live windup into pain. Repeated genuine hits lower original health; the terminal hit occurs in a fresh unreleased natural windup. Each target emits one death and never releases the cancelled attack or any later attack. No health/definition/timing override is used.

A separate explicitly synthetic launch uses the real combat projectile constructor and swept projectile physics into an existing hard wall. It produces one impact and does not damage the player beyond that wall. This is a collision test, not a claim of natural ranged AI firing through geometry.

## Found and corrected

The initial east actor pursued diagonally into the existing lift/sump floor opening. It stalled at (6.402457, -0.499059, -79.8997) against arena_one_FloorWest/South. Moving the player to another lane for 300 frames did not free it. The coordinator replaced that opening with visible continuous Intake floor; the original enemy slot and species were retained. The final native approach test passes. Initial failure receipts remain under diagnostic-*; fixture-only event-count scope and stale transform mistakes are also retained and distinguished from the physical defect.

## Limits

This verifies live AI state, physical pursuit, real damage contacts, pose indices, hurt surfaces and pivots. It does not establish human approval of visual readability, listening quality, a complete level route, new eight-direction animation sets, or full encounter balance. Root-owned live campaign/capture checks cover complementary behaviour.

Headless shutdown emits 12 ObjectDB / 5 resource retention warnings despite all 95 checks and process exit 0. The verbose log identifies Ogg audio packet/playback resources for the music, pickup and projectile-impact cues. These are preserved as a fixture teardown limitation; no claim is made that this establishes a runtime memory leak in sustained native gameplay. Production audio was not changed.
