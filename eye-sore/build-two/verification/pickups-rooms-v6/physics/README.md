# Room pass V6 physical regression

Final frozen source passed the unchanged actual Main lift/exit checker across 12 maps and 8 lifts: zero hazards and zero fixture errors. Every recorded scene SHA matches `resources/campaign/room-program-freeze-v6.json`. Full evidence is `physics-final.json` and `lift-edges-room-v6-final.json` (also retained at `verification/map-safety-v5/lift-edges-room-v6-final.json`).

Command:

```sh
./tools/godot.sh --headless --fixed-fps 60 --script tools/check_lift_edges_v5.gd -- --postfix --include-standalone --automated-input --receipt=lift-edges-room-v6-final
```

This is actual Godot Main/CharacterBody physics and synthetic W/A/S/D/E input at explicit 60 Hz clocks. It checks platform carry, fixed landing calls, straddle refusal, both guarded landings, early departure containment, under-deck emergency egress, and exit-gallery traversal/wall probes. Declared independent initial placements, cleared control flags, and frozen enemy AI isolate geometry; this does not establish combat survival or native visual acceptance.

Independent loaded-scene checks found 1,087 furniture body/mesh pairs with matching resolved dimensions/transforms. Of 146 near-surface representative rays, 144 hit the exact queried body; two hit an adjacent shelf within the same authored rack. All returned actual `hard`/`armor` metadata. No prop overlaps occurred in sampled portal mouths or control-to-inner-ring connectors.

Additional south-ring capsule samples produced 118 contact runs in the rejected initial scene snapshot, versus 8 in the final freeze. The initial Line01 drum contact at approximately `(17.887,-.630,-196.852)` was preserved in `room-clearance-initial-snapshot.json`. The final drum no longer intersects the sampled ring. All eight remaining final contacts passed independent real CharacterBody eastward W crossing and remained grounded; the capsule naturally slid around narrow poles/screens, with less than .23 m lateral deflection. Their scene SHAs, exact body paths, and trajectories appear in `room-connector-walk-candidate.json`. These bounded samples are not an exhaustive walkability claim for every arbitrary room path.

The first Main matrix was launched without `--fixed-fps 60`; its six-awaited-tick W nudge moved only .0467 m, never reaching the guard. Subsequent E calls caused cascading fixture failures. That partial failure and invocation are preserved separately as `lift-edges-room-v6-initial-clock-failure.json`, `lift-edges-room-v6.log`, and `initial-clock-diagnostic.json`. It is not evidence of a containment defect. No frozen checker or runtime code was changed to make the final run pass.

The legacy standalone structure checker initially reported zero contract failures but emitted missing `StubCombat.emit_event` script errors. Only that test stub was corrected to record copied events and emit its existing signal. The clean rerun passes all three standalone stages without script errors. Both logs/receipts are preserved, and historical `resources/stages/state-check.json` was restored byte-for-byte.

No gameplay, art, authored scene, runtime, or old receipt changes were made by this audit. The scoped source changes are the standalone test stub and new clearance/crossing helpers.
