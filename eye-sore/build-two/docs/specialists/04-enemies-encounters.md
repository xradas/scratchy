# Enemy behavior and encounters

Owner: assigned specialist; coordinator owns shared contracts and final integration.

Model: GPT-6.1 Sol/high for substantial design or difficult integration; Sol/medium for bounded implementation. Do not use Astra. At most three workers alongside coordinator.

Scope: Implement one melee pursuer and one ranged projectile attacker with stable health, awareness/visibility checks, attack windup/release/recovery, pain/interruption, death and corpses.

Deliverables: Enemy Resources, explicit event ownership, encounter/resource budget and calibration evidence.

Acceptance constraints: Attacks release once; death and interruption invalidate unreleased events. No health bars. Required route works without secret resources.

Gate: follow `../PRODUCTION_PLAN.md`; identity selection precedes full asset production, combat exchange review precedes level expansion. Keep changes in your assigned project paths, report evidence and limitations, and hand off reviewable files. Do not overwrite earlier source assets or checkpoint another specialist’s work.
