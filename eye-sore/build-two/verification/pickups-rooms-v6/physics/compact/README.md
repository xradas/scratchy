# Compact candidate physical audit

Final result is in `physics-final.json`. Prior candidate evidence outside this directory is preserved.

The native audit covered all 55 changed rooms: 142,260 support rays over center/edge footprints, 432 bidirectional actual CharacterBody W/A/S/D trials, and 522 pickup plus 324 enemy-spawn centres. All centre traversals passed. All placement centres have floor support and zero furnishing overlap; enemy capsules sit .87 m above their supporting floor. The nine unchanged suspended altar baits require the existing adjoining altar approach; a centre support ray alone is not a pickup reachability demonstration.

The initial run found 18 genuinely unsupported edge-foot points at the two Ash02 angled corridor joins. Its complete raw evidence remains `thresholds.json`. The authored fix extends the shared visible/colliding floor and adds two matching mouth floors. Final `angled-final.json` replays all 18 points successfully, verifies all three new/modified floor mesh/shape pairs, and passes 3,150 full-width footprint rays plus six actual bidirectional crossings across centre and ±.86 m lanes. Actual actor radius is .30 m. No scene/runtime fix was made by this worker.

Near-declared-width lanes also produced 58 directional stalls. `blocker-parity.json` demonstrates that all 58 immediate blockers are unchanged existing closet back walls, with exactly matching loaded local transforms and BoxShape sizes. The declared portal width includes portions occupied by those existing closets; it does not establish the usable actor width. The corrected ±.45 m usable lanes passed all 64 actual A/D crossings, recorded in `usable-lanes.json`. Raw stalls remain preserved rather than silently treated as passes.

The unchanged Main lift/exit checker also passed 12 maps/8 lifts, zero hazards or fixture errors, using explicit `--headless --fixed-fps 60`. `lift-edges-final.json` records the tested cohort. This matrix precedes the final Ash02 join fix. All other eleven scene hashes match the final freeze. The native pre-/post-fix comparison in `angled-physics-parity.json` finds only the three corridor floor bodies and their shapes changed; final Ash02 full-width traversal supplements the matrix. The signature tool returns 1 when intentionally comparing unequal physics; the six listed keys are expected authored floor changes, not a test failure concealed by this summary.

Reproduction:

```sh
./tools/godot.sh --headless --fixed-fps 60 --script tools/check_compact_thresholds_v6.gd
./tools/godot.sh --headless --fixed-fps 60 --script tools/check_compact_thresholds_v6.gd -- --usable-lanes
./tools/godot.sh --headless --fixed-fps 60 --script tools/check_compact_thresholds_v6.gd -- --only-diagonal
./tools/godot.sh --headless --fixed-fps 60 --script tools/check_lift_edges_v5.gd -- --postfix --include-standalone --automated-input --receipt=lift-edges-room-v6-compact-final
```

These tests declare independent initial actor placements and legitimate door activation flags, and do not instantiate enemy AI. They establish bounded physical traversal/support, not native visual acceptance or full combat survival. The retained original scene snapshots used for blocker parity are outside the project at `/tmp/eyesore-v6-physics-initial`; the pre-join-fix snapshot is `/tmp/eyesore-pre-angled-floor-v6`.
