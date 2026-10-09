# Resume after bedtime — 9 October 2026

User stopped work for bedtime. Next turn should resume, not restart.

Latest playtest feedback: aiming feels bad; weapon damage separation inadequate; fell through the doorway; playable placeholder graphics fall far short of praised dimensional biotech/Ash Citadel concept art.

Implemented and verified locally:
- Actual one-unit portal floor gap closed by matching AnnexFloor mesh+shape length17 and centerz-9.5; offline generator updated too. Before 3/3 forward paths fell, 9 ray misses. After 6/6 bidirectional/offset paths stayed grounded and 15/15 floor contacts resolved.
- Mouse uses unscaled screen_relative. Camera stays fixed through firing; recoil is cosmetic weapon offset. Drawn crosshair center matches camera ray at three window sizes; actual native test passed.
- Pistol20, shotgun16×7=112 with center pellet and even spread ring (3.4° horizontal,1.3° vertical), melee30. Enemy health80/160. Actual close-range tests: pistol4/8, shotgun1/2, melee3/6 hits to kill.
- Combat regression and actual native30/60/120 fixed-physics timing passed. Native main smoke with captured frames passed. Muzzle flash guarded against melee; hit confirmation from actual damage events.
- HUD/menu review jargon removed and framed native-resolution HUD added.

Evidence: verification/combat/aim-balance.{log,json}, balance-combat-check.log, balance-timing.log, portal-before/after and portal-fix-summary.json, fixes-smoke.log and fixes-gameplay/menu.png.

Latest exported executable remains the earlier d9e8/7d3fe checkpoint: these new fixes have NOT yet been exported or launched for the user. Next export must use a new dated filename and preserve prior binary. Need outside-source launch/smoke and new source/remote checkpoint after final integration.

Visual specialist /root/visual_packets completed only read-only inspection of the approved corrupted-biotech board/prompt and enemy adapter before the bedtime stop. No new enemy source/render files exist yet. Resume representative live Godot Unsealed/Vessel mesh rigs under /home/rikki/Projects/eyesore-build-two-staging/enemy-art-v1. Existing weapon source is staging/combat-art and approved concepts staging/visual-v2. No new enemy art has been integrated. It is representative combat art, not chosen first-level setting or finished production assets. Art configure(kind)/present(state,time,windup,recovery,pain) API has no gameplay/audio ownership. Inspect actual renders and silhouette/hit-volume correspondence before integrating.

Pending optional first-look question: corrupted biotech/The Pale Ward vs fortress/The Ash Citadel. User praised both and biotech strongly; no first-level choice submitted. Do not infer elapsed time as selection. Full level/complete-animation production still follows reviewed combat gate.

Audio remains dry impacts and separate short hurt; latest longer1.55/1.89s death screams. Abelian remains title-only; level music provisional. Existing audio review HTTP server port8764 may still be running. Audio sources/music unchanged by this bugfix. No game process currently running.
