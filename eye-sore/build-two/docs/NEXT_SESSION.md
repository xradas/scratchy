# Current review checkpoint — 9 October 2026

Resumed from bedtime fixes. Continue this work; preservation and Git authentication are complete.

Latest user playtest priorities: bad aiming, weak weapon damage separation, falling through the doorway, and playable graphics below the praised biotech/Ash Citadel concepts.

Implemented:
- Doorway floor gap closed in scene and authoring generator. Exact visible/physical service-ramp mesh replaces mismatched decorative stair risers. Grounded bidirectional portal, ramp and wall/door checks pass.
- Unscaled mouse motion, fixed aiming camera, cosmetic weapon recoil, centered crosshair, configurable horizontal FOV. The default 90 now means 90 horizontal degrees.
- Pistol20 damage/0.32s, shotgun16×7=112/0.85s with centered deterministic spread, melee30/0.5s. Enemy80/160HP. Actual integrated near-range tests: pistol4/8, shotgun1/2, melee3/6 hits to kill.
- Original live 3D creature studies integrated: Unsealed and Vessel, chase/windup/recovery/pain/dead poses, persistent corpses, ranged release at actual nozzle marker. Exact posed triangle contacts distinguish flesh/armor; movement capsules are excluded from hitscan. Dead hurt geometry disabled. Player/actor collision now blocks passage.
- Revised dark mesh-rendered weapon poses with matching muzzle anchors. Four representative poses are not complete animation sets.
- Authoritative combat regression, posed mesh/material contact checks and native30/60/120 timing pass. Integrated live AI/mesh room retains6 shots/30 ammo over120 physics ticks at all caps.
- Native audio lifecycle/contact test passes: six weapon×material contacts, separate pain/death, title-only Abelian, freeze on pause, advancing muted playback and clean restart. New isolated game-only stereo output retained with no normalization; sources and cues unchanged.

Evidence: verification/combat/{creature-aim-balance.log,creature-contacts.json,live-room-timing.json,final-combat.log,final-art-geometry.log,remaining-physics-audit.json,art-review-sound-scene.log,art-review-driver-mix.wav}. Controlled actual integrated viewport captures: art-{pistol,shotgun,windup,corpses}.png. These are real game renders with fixed creature placement, not concept overlays or a sustained playtest.

New dated export details and SHA are recorded in verification/INTEGRATION.json. Preserve all old room-only/audio binaries; do not overwrite them. Current source branch: codex/eyesore-build-two. The review prototype is not an accepted complete combat calibration or finished level.

The user explicitly selected **The Pale Ward / corrupted biotech** on 9 October. Selection is recorded in SELECTION.md; Ash Citadel remains a future direction. These biotech models are representative combat studies; the integrated combat review still precedes full level expansion. Remaining art limitation: simplified stony flesh, joints and weapon forms below concept detail; the movement capsule is narrower than outstretched arms. Direct pursuit only. No 5–8 minute route, keys, lift, automap or full campaign yet.

Audio: dry contacts, short hurt, 1.55/1.89 s blood-curdling deaths; Abelian title only; level music still provisional. Music approval was positive; new gameplay/art acceptance must come from actual user review.
