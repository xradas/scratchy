# Weapons and combat

Owner: assigned specialist; coordinator owns shared contracts and final integration.

Model: GPT-6.1 Sol/high for substantial design or difficult integration; Sol/medium for bounded implementation. Do not use Astra. At most three workers alongside coordinator.

Scope: Implement Resource-driven pistol, seven-pellet shotgun and melee fallback. Finite ammo, health and armor. One owned firing event drives ammo, rays, damage, flash, recoil and audio.

Deliverables: Event timeline, implementation and repeated-fire calibration evidence.

Acceptance constraints: No reloads or extra weapons. Rays use physics world geometry. Dry trigger consumes no ammo and causes no damage.

Gate: follow `../PRODUCTION_PLAN.md`; identity selection precedes full asset production, combat exchange review precedes level expansion. Keep changes in your assigned project paths, report evidence and limitations, and hand off reviewable files. Do not overwrite earlier source assets or checkpoint another specialist’s work.

User requirements, 9 October 2026: Resolve the actual contact from the authoritative ray/melee result and emit weapon/material/target/position. Aggregate shotgun feedback per target without dropping pellet damage; misses produce no contact cue.
