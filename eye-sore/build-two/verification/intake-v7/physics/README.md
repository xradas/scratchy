# Intake v7 independent foundation checks

These are isolated native physics checks, not a continuous combat run, human playtest or artwork approval. The final scene is pinned in each receipt. Production geometry is instantiated and `world.scan(world)` expands the same polygon mesh/collider pairs used by Main. The actual production player script receives physical W/A/S/D input. Each walk begins at an explicit independent position; there is no fall recovery, teleport during a walk, collision disabling, or movement tuning.

`headless-60.json` surveys all nine first-section links (indices 0–6, 14, 15), including portal mouths, at 0.1 m along the link and at most 0.12 m across its usable width. Capsule centres remain 0.32 m inside the physical corridor edges. Forward W and reverse S cross all nine links. Additional A/D trials climb the steep modified triage–diagnostics link in both directions. Both diagonals of the usable former-sump area below the retained raised rim are crossed in both directions, for 26 successful walks.

All access doors, trap entries and trap shutters are opened through their real `activate()` method with declared fixture flags before these probes. Door collision remains active and moves with the visible door. These grants isolate geometry and make no progression or encounter-completion claim.

The 8,181-sample former-pocket survey covers x=4..12, z=−87..−77, including a perimeter around the old recessed footprint. Its downward rays begin at Y=−0.7 and confirm the underlying contiguous floor plane at Y=−1. They do **not** establish empty walking space through the deliberately retained raised rim or its stairs. The separate native diagonal walks establish the usable below-rim passage.

The native inventory checks all 142 furnishing physical parts and all 117 new overhead/presentation parts for visible mesh/shape size and transform parity. Direct local shot-mask rays hit each of the 117 added bodies. Their minimum vertical clearance to a surface below is 3.1 m; the downward clearance survey excludes only other bodies in the same overhead group so a surgical lamp mount does not incorrectly measure its own arm as a floor. Separate capsule queries along corridor centre/edge lanes detect no presentation-body intersections. These are geometric shot queries, not weapon damage or impact-audio tests.

One player start, 36 NPC markers and 57 pickup roots have floor support and no room-prop/presentation intersection with a player-size capsule at the supported floor. This does not establish each enemy's navigation or attack behaviour; the enemy specialist checks those independently.

`render-{30,60,120}.json` use native Compatibility rendering with actual `--max-fps` caps, VSync disabled and the production 60 Hz physics clock. No-focus windows are positioned away from the user's screen. Each runs both directions on four stair links and A/D on the modified steep link. `summary.json` compares traversal tick counts and terminal positions, while each raw report records achieved average FPS. These checks compare movement timing; they do not claim subjective mouse or frame-pacing acceptance.

`lift-matrix.json` is a byte copy of the existing fixture's uniquely named `verification/map-safety-v5/intake-v7-final.json`: all 12 campaign/standalone maps, eight lifts, exit-gallery wall and doorway movement. Its raw log retains an exit warning about four leaked ObjectDB instances and one resource still in use. The process exits 0; there are zero hazards and zero fixture errors. No user game process was changed.

## Retained diagnostics

- `short-pickup-support-ray.*`: a two-metre ray missed unchanged Bait_arena_two's lower floor because the pickup is elevated. The final survey uses eight metres; its production position was not edited.
- `stacked-lamp-clearance-query.*`: a naive downward ray measured surgical lamp pieces against each other. The final floor-clearance query excludes only that same added overhead group; its direct shot rays still test every body independently.
- `peripheral-raised-rim-crossings/*`: deliberately broad exploratory lines crossed the intentional EastRimStairs side/end. Some initial positions overlapped raised steps and some straight paths deflected into walls. Their exact traces and slide colliders are preserved. They are not required walking lanes and were not repaired by removing the elevation feature. All floor support remained present. The final former-pocket diagonals stay in the actual below-rim passage.
- `lifts-before-flat-triage/*`: prior matrix before the coordinator replaced Intake's recessed sump; final matrix was rerun on the final scene.
- `simulated-render-clocks/*`: earlier native `--fixed-fps` checks passed but controlled simulated frame deltas rather than true rendering caps. Final rate acceptance uses `--max-fps` instead.
